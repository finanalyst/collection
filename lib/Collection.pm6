use v6.*;
use Terminal::Spinners;
use RakuConfig;
use Pod::From::Cache;
use ProcessedPod;
use File::Directory::Tree;
use PrettyDump;
use X::Collection;

unit module Collection;

proto sub collect(|c) is export {
    X::Collection::BadOption.new(:passed(|c.keys.grep(*~~ Str))).throw
    unless all(|c.keys.grep(*~~ Str))
            eq
            any(<no-status without-processing no-refresh recompile full-render no-report no-completion no-cleanup
                end debug verbose no-cache>);
    {*}
}

#| adds a filter to a cache object
#| Anything that exists in the %!extra hash is returned
#| If the key does not exist, it is as if the Cache does not contain it
#| A filename can be blocked from addressing cache by setting its %extra key to Nil
role Post-cache {
    has %!extra = %();
    method sources {
        (%!extra.keys.grep({ %!extra{$_}.so }),
         callsame.grep({ $_ !~~ any(%!extra.keys) })).flat
    }
    method list-files {
        (%!extra.keys.grep({ %!extra{$_}.so }),
         callsame.grep({ $_ !~~ any(%!extra.keys) })).flat
    }
    method pod(Str $fn) {
        return %!extra{$fn} if %!extra{$fn}:exists;
        nextwith($fn)
    }
    multi method add(Str $fn, Array $p) {
        %!extra{$fn} = $p;
    }
    multi method add(Str $fn) {
        %!extra{$fn} = Nil
    }
}

sub update-cache(:$no-status, :$recompile, :$no-refresh,
                 :$doc-source, :$cache-path,
                 :@obtain, :@refresh, :@ignore, :@extensions
        --> Pod::From::Cache) {

    rm-cache($cache-path) if $recompile;
    #removing the cache forces a recompilation

    if !$doc-source.IO.d and @obtain {
        my $proc = run @obtain.list, :err, :out;
        my $proc-rv = $proc.err.get;
        exit note $proc-rv if $proc-rv
    }
    # recompile may be needed for existing, unrefreshed sources,
    #  so recompile != !no-refresh
    elsif !$no-refresh and @refresh {
        my $proc = run @refresh.list, :err, :out;
        my $proc-rv = $proc.err.get;
        exit note $proc-rv if $proc-rv;
    }
    print "$doc-source: " unless $no-status;
    Pod::From::Cache.new(
            :$doc-source,
            :$cache-path,
            :@ignore,
            :@extensions,
            :progress($no-status ?? Nil !! &counter)) but Post-cache
}

multi sub collect(:$no-cache = False, |c) {
    my $mode = get-config(:$no-cache :required('mode',))<mode>;
    collect($mode, :$no-cache, |c)
}

multi sub collect(Str:D $mode, :$no-status,
                  :$without-processing is copy,
                  :$no-refresh is copy,
                  :$recompile is copy,
                  :$full-render is copy,
                  :$no-report is copy,
                  :$no-completion is copy,
                  :$no-cleanup is copy,
                  Str :$end = 'all',
                  :$debug = False, :$verbose = False,
                  Bool :$no-cache = False) {
    my %config = get-config(:$no-cache, :required< sources cache >);
    without $without-processing {
        $without-processing = %config<without-processing> // False
    }
    if $without-processing {
        $recompile = False;
        $no-refresh = True;
        $full-render = False;
    }
    else {
        without $recompile {
            $recompile = %config<recompile> // False
        }
        without $no-refresh {
            $no-refresh = %config<no-refresh> // False
        }
        without $no-refresh {
            $full-render = %config<full-render> // False
        }
    }
    my $cache = update-cache(
            :cache-path(%config<cache>), :doc-source(%config<sources>),
            :no-status($no-status // %config<no-status> // False),
            :$recompile,
            :$no-refresh,
            :obtain(%config<source-obtain> // ()),
            :refresh(%config<source-refresh> // ()),
            :ignore(%config<ignore> // ()),
            :extensions(%config<extensions> // <pod6 rakudoc>)
                                          );
    return $cache
    if $end ~~ /:i 'Post-Source' | 'Pre-Mode' /;
    # === Post-Source / Pre-Mode milestone ====================================
    # === no plugins because Mode config not available yet.
    X::Collection::NoMode.new(:$mode).throw
    unless "$*CWD/$mode".IO.d and $mode ~~ / ^ [\w | '-' | '_']+ $ /;
    %config ,= get-config(:$no-cache, :path("$mode/configs"),
            :required<mode-cache mode-sources plugins-required>);

    my $mode-cache = update-cache(
            :no-status($no-status // %config<no-status>),
            :recompile($recompile // %config<recompile>),
            :no-refresh($no-refresh // %config<no-refresh>),
            :obtain(%config<mode-obtain> // ()), :refresh(%config<mode-refresh> // ()),
            :cache-path("$mode/" ~ %config<mode-cache>), :doc-source("$mode/" ~ %config<mode-sources>),
            :ignore(%config<mode-ignore> // ()), :extensions(%config<mode-extensions> // ())
                                               );
    # if at this stage there are any cache changes
    # then without-processing must be over-ridden
    # because had it was True, and changes bubble to here, then the caches were empty and had to
    # be recreated
    my Bool $cache-changes = (?(+$cache.list-files) or ?(+$mode-cache.list-files));
    my %plugins-used;
    my @output-files;
    # if no cache changes, then no need to run setup
    # if full-render, then setup has to be done for all cache files to ensure pre-processing happens
    # if without-processing was true, and cache-changes, then all files will be listed in any case, so
    # value of full-render is moot.
    %plugins-used<setup> = manage-plugins('setup', :with($cache, $mode-cache, $full-render), :%config, :$mode, :$debug)
        if $cache-changes or $full-render;
    return ($cache, $mode-cache) if $end ~~ /:i 'post-cache' | 'pre-setup'/;
    # === Post-Cache | Pre-Setup milestone ==================================================

    rmtree "$*CWD/$mode/%config<destination>" if $full-render;
    unless "$*CWD/$mode/%config<destination>".IO.d {
        "$*CWD/$mode/%config<destination>".IO.mkdir;
        $full-render = True;
    }
    unless $cache-changes or $full-render {
        # Prepare the renderer
        # get the template names
        my @templates = "$*CWD/$mode/{ %config<templates> }".IO.dir(test => / '.raku' /).sort;
        exit note "There must be templates in ｢~/{ "$*CWD/$mode/templates".IO.relative($*HOME) }｣:"
        unless +@templates;
        my ProcessedPod $pr .= new(:$debug, :$verbose);
        $pr.templates(~@templates[0]);
        for @templates[1 .. *- 1] { $pr.modify-templates(~$_, :path("$mode/templates")) }

        %plugins-used<render> = manage-plugins('render', :with($pr), :%config, :$mode, :$debug);
        return ($pr) if $end ~~ /:i 'pre-render' /;
        # ======== Post-Setup | Pre-Render milestone =============================
        $pr.no-code-escape = %config<no-code-escape> if %config<no-code-escape>:exists;

        my @files = $full-render ?? $cache.sources.list !! $cache.list-files.list;
        my %processed;
        counter(:start(+@files), :header('Rendering content files')) unless $no-status;
        # sort files so that longer come later, meaning sub-directories appear after parents
        # when creating the sub-directory
        for @files.sort -> $fn {
            counter(:dec) unless $no-status;
            # files are cached with the relative path from Collection route & extension
            # output file names are needed with output extension and relative to output directory
            # there is a possibility of a name clash when filename differs only by extension.
            my $short = $fn.IO.relative(%config<sources>).IO.extension('').Str;
            if %processed{$short}:exists {
                $short ~= '-1';
                $short++ while %processed{$short}:exists;
                # bump name if same name exists
            }
            with "$mode/%config<destination>/$short".IO.dirname {
                .IO.mkdir unless .IO.d
            }
            with $pr {
                .name = $short;
                .process-pod($cache.pod($fn));
                .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                # collect page components, and links
                %processed{$short} = %( .emit-and-renew-processed-state
                        .grep({ .key ~~ / 'raw-' | 'links' | 'templates-used' / }));
            }
        }
        # %processed containing Filename-> hash of raw-* and links
        # We want to add to pr.plugin-data, the name-space raw-* links, with $fn-> raw-*.value
        create-collection-data(:name-space($_), :key("raw-$_"), :data(%processed), :$pr)
        for <toc footnotes glossary meta>;

        @files = $mode-cache.sources.list;
        counter(:start(+@files), :header("Rendering $mode content files"));
        for @files -> $fn {
            counter(:dec);
            my $short = $fn.IO.relative("$mode/%config<mode-sources>").IO.extension('').Str;
            if %processed{$short}:exists {
                $short ~= '-1';
                $short++ while %processed{$short}:exists;
                # bump name if same name exists
            }
            with "$mode/%config<destination>/$short".IO.dirname {
                .IO.mkdir unless .IO.d
            }
            with $pr {
                .name = $short;
                .process-pod($mode-cache.pod($fn));
                .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                #only collect links
                %processed{$short} = %(.emit-and-renew-processed-state
                        .grep({ .key ~~ / 'links' / }));
            }
        }
        return (%processed, %plugins-used) if $end ~~ /:i 'post-compilation' | 'pre-report' /;
        %plugins-used<report> = manage-plugins('report',:with(%processed,%plugins-used),:%config,:$mode,:$debug)
                unless $no-report;
        # ==== Post-Render / Pre-Report Milestone ===================================
        write-config( @output-files = %processed.keys, :path($mode), :fn<output-files.raku>) ;
    }
    without @output-files {
        @output-files = EVALFILE "$mode/output-files.raku"
    }
    # === Post-Report / Pre-Completion Milestone ================================

    return (:files(@output-files),:output(%config<output>),:landing(%config<landing-place>) )
        if $end ~~ /:i 'post-report' | 'pre-completion' /;
    %plugins-used<completion> = manage-plugins('completion',
            :with(:files(@output-files),:output(%config<output>),:landing(%config<landing-place>) ),
            :%config,:$debug)
            unless $no-completion;

    #return %plugins-used if $end ~~ /:i 'post-completion' | 'pre-cleanup' /;
    # === Post-Completion / Pre-Cleanup Milestone =============================

    %plugins-used
    # inspection point end eq 'all'
    # === All milestone (nothing else must happen) ================================
}

sub plugin-confs(:$mile, :%config, :$mode, :$debug = False) {
    my %valid-confs;
    for %config<plugins-required>{$mile}.list -> $pl {
        my $path = "$mode/{ %config<plugins> }/$pl/config.raku";
        next unless $path.IO.f;
        my %plugin-conf = get-config(:$path);
        next unless %plugin-conf{$mile};
        note "Plugin ｢$pl｣ is valid for milestone ｢$mile｣ " if $debug;
        %valid-confs{$pl} = %plugin-conf;
    }
    %valid-confs
}
multi sub manage-plugins(Str:D $mile where * ~~ any(<setup report completion>),
                         :$with,
                         :%config, :$mode,
                         :$debug = False) {
    my %valids = plugin-confs(:$mile, :%config, :$mode, :$debug);
    for %valids.kv -> $plug, %plugin-conf {
        my $name = %plugin-conf<processor>;
        my $path = "$mode/%config<plugins>/$plug/$name".IO.absolute;
        my &closure = EVALFILE $path;
        &closure.($with)
    }
    %valids
}
multi sub manage-plugins(Str:D $mile where *eq 'render', :$with where *~~ Raku::Pod::Render, :%config, :$mode,
                         :$debug = False) {
    my %valids = plugin-confs(:$mile, :%config, :$mode, :$debug);
    for %valids.kv -> $plug, %plugin-conf {
        %plugin-conf<path> = "$mode/%config<plugins>/$plug".IO.absolute;
        $with.add-plugin($plug, |%plugin-conf)
        # Since the configuration matches what the add-plugin method expects as named parameters
    }
    %valids
}
#multi sub manage-plugins(Str:D $mile where *eq 'cleanup', :$with, :%config, :$mode, :$debug = False) {
#
#}

#| places plugin data for collection page components, filtered by filename
#| makes available to plugins Page component structures for whole collection
sub create-collection-data(:$name-space, :$key, ProcessedPod :$pr, :%data) {
    # %data contains keys for each source and sub-keys for each page component
    # what is required is to make the structure pointed to by $key available
    # to a collection structure with sub-keys of filenames
    $pr.plugin-data{"collection-$name-space"} =
            %( |gather for %data.keys {
                take $_ => %data{$_}{$key} })
}


#| uses Terminal::Spinners to create a progress bar, with a starting value, that is decreased by 1 after an iteration.
sub counter(:$start, :$dec, :$header = 'Caching files ') {
    state $hash-bar = Bar.new(:type<bar>);
    state $inc;
    state $done;
    if $start {
        # also fails if $start = 0
        $inc = 1 / $start * 100;
        $done = 0;
        say $header;
        $hash-bar.show: 0
    }
    if $dec {
        $done += $inc;
        $hash-bar.show: $done;
    }
}
