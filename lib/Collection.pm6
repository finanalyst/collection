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
                end debug verbose no-cache collection-info>);
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
    my $mode = get-config(:$no-cache, :required('mode',))<mode>;
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
                  :$collection-info = False,
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
        without $full-render {
            $full-render = %config<full-render> // False
        }
    }
    without $no-completion {
        $no-completion = %config<no-completion> // False
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
        if $end ~~ /:i 'Source' /;
    say "Passed Post-Source milestone" if $collection-info;
    # === Source milestone ====================================
    # === no plugins because Mode config not available yet.
    X::Collection::NoMode.new(:$mode).throw
        unless "$*CWD/$mode".IO.d and $mode ~~ / ^ [\w | '-' | '_']+ $ /;
    %config ,= get-config(:$no-cache, :path("$mode/configs"),
        :required<mode-cache mode-sources plugins-required destination>);

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
    my @plugins-used;
    my @output-files;
    # if no cache changes, then no need to run setup
    # if full-render, then setup has to be done for all cache files to ensure pre-processing happens
    # if without-processing was true, and cache-changes, then all files will be listed in any case, so
    # value of full-render is moot.
    @plugins-used.append( %(setup => manage-plugins('setup',
            :with($cache, $mode-cache, $full-render, %config<sources>, %config<mode-sources>),
            :%config, :$mode, :$collection-info) ) )
        if $cache-changes or $full-render;
    return ($cache, $mode-cache) if $end ~~ /:i 'Setup' /;
    # === Setup milestone ==================================================
    say "Passed Setup milestone" if $collection-info;
    rmtree "$*CWD/$mode/%config<destination>" if $full-render;
    unless "$*CWD/$mode/%config<destination>".IO.d {
        "$*CWD/$mode/%config<destination>".IO.mkdir;
        $full-render = True;
    }
    if "$mode/output-files.raku".IO.f {
        @output-files = EVALFILE "$mode/output-files.raku";
    }
    else { $full-render = True }
    # rendering will be done if
    # 1) full-render true & without-processing false
    # 2) one/both caches did not exist prior to this run
    # 3) destination directory did not exist prior to this run
    # 4) output-files.raku doesn't exist
    if $cache-changes or $full-render {
        # Prepare the renderer
        # get the template names
        my @templates = "$*CWD/$mode/{ %config<templates> }".IO.dir(test => / '.raku' /).sort;
        exit note "There must be templates in ｢~/{ "$*CWD/$mode/templates".IO.relative($*HOME) }｣:"
        unless +@templates;
        my ProcessedPod $pr .= new(:$debug, :$verbose);
        $pr.no-code-escape = %config<no-code-escape> if %config<no-code-escape>:exists;
        $pr.templates(~@templates[0]);
        for @templates[1 .. *- 1] { $pr.modify-templates(~$_, :path("$mode/templates")) }
        $pr.add-data('mode-name', $mode );

        @plugins-used.append( %(render => manage-plugins('render', :with($pr), :%config, :$mode, :$collection-info)));
        return ($pr) if $end ~~ /:i 'render' /;
        # ======== Render milestone =============================
        say "Passed Render milestone" if $collection-info;
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
                .pod-file.name = $short;
                .process-pod($cache.pod($fn));
                .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                # collect page components, and links
                %processed{$short} = .emit-and-renew-processed-state
            }
        }

        @plugins-used.append( %(compilation => manage-plugins('compilation', :with($pr,%processed), :%config, :$mode, :$collection-info) ));
        return ($pr,%processed) if $end ~~ / 'compilation' /;
        # ==== compilation Milestone ===================================
        say "Passed Compilation milestone" if $collection-info;
        # Even if the compilation sources have not changed, they are assumed to depend
        # on the collection files, which have changed (at a minimum) in order to get here.
        @files = $mode-cache.sources.list;
        counter(:start(+@files), :header("Rendering $mode content files")) unless $no-status;
        for @files -> $fn {
            counter(:dec) unless $no-status;
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
                .pod-file.name = $short;
                .process-pod($mode-cache.pod($fn));
                .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                #only collect links
                %processed{$short} = .emit-and-renew-processed-state
            }
        }
        @plugins-used.append( %(report => manage-plugins('report',:with(%processed,@plugins-used),:%config,:$mode,:$collection-info) ))
                unless $no-report;
        return (%processed, @plugins-used) if $end ~~ /:i 'report' /;
        # ==== Compilation Milestone ===================================
        say "Passed Report milestone" if $collection-info;
        @output-files = (%processed.keys.sort >>~>> ('.' ~ %config<output-ext>));
        write-config( @output-files, :path($mode), :fn<output-files.raku>
        ) ;
    }

    @plugins-used.append( %(completion => manage-plugins('completion',
            :with(@output-files, "$mode/%config<destination>", "%config<landing-place>\.%config<output-ext>"),
            :$mode,:%config,:$collection-info)
            ))
            unless $no-completion;
    return ( @output-files, "$mode/%config<destination>", "%config<landing-place>\.%config<output-ext>" )
    if $end ~~ /:i 'completion' /;
    # === Report Completion Milestone ================================
    say "Passed Post-Report milestone" if $collection-info;

    @plugins-used
    # inspection point end eq 'all'
    # === All milestone (nothing else must happen) ================================
}

sub plugin-confs(:$mile, :%config, :$mode, :$collection-info = False) {
    my %valid-confs;
    for %config<plugins-required>{$mile}.list -> $plug {
        say "Plugin ｢$plug｣ is listed for milestone ｢$mile｣ " if $collection-info;
        my $path = "$mode/{ %config<plugins> }/$plug/config.raku";
        next unless $path.IO.f;
        my %plugin-conf = get-config(:$path);
        next unless %plugin-conf{$mile}:exists and %plugin-conf{$mile}.defined;
        say "Plugin ｢$plug｣ is valid with keys ｢{%plugin-conf.keys.join(',')}｣" if $collection-info;
        %valid-confs{$plug} = %plugin-conf;
    }
    %valid-confs
}
multi sub manage-plugins(Str:D $mile where * ~~ any( < setup compilation completion>),
                         :$with,
                         :%config, :$mode,
                         :$collection-info = False) {
    my %valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    for %valids.kv -> $plug, %plugin-conf {
        my $path = "$mode/%config<plugins>/$plug/{ %plugin-conf{$mile} }".IO.absolute;
        my &closure = EVALFILE $path;
        &closure.(|$with)
    }
    %valids
}
multi sub manage-plugins(Str:D $mile where *eq 'render', :$with where *~~ ProcessedPod,
                         :%config, :$mode,
                         :$collection-info = False) {
    my %valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    for %valids.kv -> $plug, %plugin-conf {
        my $path = "$mode/%config<plugins>/$plug".IO.absolute;
        # Since the configuration matches what the add-plugin method expects as named parameters
        if %plugin-conf<render> ~~ Str { # as opposed to being a Boolean value, then its a program
            my &closure = EVALFILE "$mode/%config<plugins>/$plug/{ %plugin-conf{$mile} }".IO.absolute;
            &closure.($with);
        }
        $with.add-plugin($plug, :$path, :config(%plugin-conf));
    }
    %valids
}
multi sub manage-plugins(Str:D $mile where *eq 'report', :$with,
                         :%config, :$mode,
                         :$collection-info = False) {
    my %valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    mkdir "$mode/%config<report-path>" unless "$mode/%config<report-path>".IO.d;
    for %valids.kv -> $plug, %plugin-conf {
        my $path = "$mode/%config<plugins>/$plug/{ %plugin-conf{$mile} }".IO.absolute;
        my &closure = EVALFILE $path;
        # a plugin should only affect the report directly
        # so a plugin should not write directly
        my $resp = &closure.(|$with);
        "$mode/{ %config<report-path> }/{ $resp.key }".IO.spurt( $resp.value )
    }
    %valids
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
