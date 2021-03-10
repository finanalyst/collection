use v6.*;
use Terminal::Spinners;
use RakuConfig;
use Pod::From::Cache;
use ProcessedPod;
use File::Directory::Tree;
use X::Collection;
use Archive::Libarchive;

unit module Collection;

proto sub collect(|c) is export {
    X::Collection::BadOption.new(:passed(|c.keys.grep(*~~ Str))).throw
    unless all(|c.keys.grep(*~~ Str))
            eq
            any(<no-status without-processing no-refresh recompile full-render no-report no-completion no-cleanup
                end no-cache collection-info dump-at debug-when verbose-when with-only>);
    {*}
}

#| The string used by plugins to describe themselves
constant MYSELF = 'myself';
#| Name of file where the contents of %processed is cached
constant PROCESSED-CACHE = 'cache.7z';
#| entity name in cache
constant CACHENAME = 'render-cache';

#| adds a filter to a cache object
#| Anything that exists in the %!extra hash is returned
#| If the key does not exist, it is as if the Cache does not contain it
#| A filename can be blocked from addressing cache by setting its %extra key to Nil
role Post-cache is export {
    has %!extra = %();
    #| Checks to see if %!extra has non-Nil keys, returns them
    #| returns all underlying cache keys not in Extra
    method sources {
        (%!extra.keys.grep({ %!extra{$_}.so }),
         callsame.grep({ $_ !~~ any(%!extra.keys) })).flat
    }
    #| As sources, but returns list-files of underlying cache
    method list-files {
        (%!extra.keys.grep({ %!extra{$_}.so }),
         callsame.grep({ $_ !~~ any(%!extra.keys) })).flat
    }
    #| checks if filename in extra, returns value or value of alias,
    #| otherwise returns value in underlying cache
    method pod(Str $fn) {
        if %!extra{$fn}:exists {
            my $rv = %!extra{$fn};
            return $rv if $rv ~~ Array; # return value if Array
            nextwith($rv) if $rv ~~ Str:D; # return underlying alias if Str
            return Nil # return Nil otherwise
        }
        nextwith($fn)
    }
    multi method add(Str $fn, Array $p) {
        %!extra{$fn} = $p;
    }
    multi method add(Str $fn) {
        %!extra{$fn} = Nil
    }
    multi method add(Str $fn, Str :$alias! ) {
        %!extra{$fn} = Nil;
        %!extra{$alias} = $fn
    }
}

#| Class to provide access to other collection resources, such as images, which are common to the collection,
#| and referenced in the pod files, but which need to be in a separate cache.
class Asset-cache {
    has %!data-base = %();
    #| the directory base, not included in filenames
    has Str $.basename is rw;
    #| the file currently being processed
    has Str $.current-file is rw = '';
    #| asset-sources provides a list of all the items in the cache
    method asset-sources { %!data-base.keys }
    #| asset-used-list provides a list of all the items that referenced by Content files
    method asset-used-list { %!data-base.keys.grep( { %!data-base{$_}<by>.elems } ) }
    #| asset-add adds an item to the data-base, for example, a transformed image
    method asset-add( $name, $object, :$by = (), :$type = 'image' ) {
        %!data-base{$name} = %( :$object, :$by, :$type );
    }
    #| remove the named asset, and return its metadata
    method asset-delete( $name --> Hash ) {
        %!data-base{$name}:delete
    }
    #| returns the type of the asset
    method asset-type( $name --> Str ) {
        %!data-base{$name}<type>
    }
    #| if an asset with name and type exists in the database, then it is marked as used by the current file
    #| returns true with success, and false if not.
    method asset-is-used( $asset, $type --> Bool ) {
        if %!data-base{ $asset }:exists and %!data-base{ $asset }<type> eq $type {
            %!data-base{$asset}<by>.append: $!current-file;
            True
        }
        else { False }
    }
    #| brings all assets in directory with given extensions and with type
    #| these are set in the configuration
    multi method asset-slurp( $directory,  @extensions, $type ) {
        X::Collection::BadAssetDirectory.new(:$!basename, :dir($directory)).throw
            unless "$.basename/$directory".IO.d;
        my @sources = my sub recurse ($dir) {
            gather for dir($dir) {
                take $_ if  .extension ~~ any( @extensions );
                take slip sort recurse $_ if .d;
            }
        }("$.basename/$directory"); # is the first definition of $dir
        for @sources {
            %!data-base{ $_.relative($.basename) } = %(
                :object( .slurp(:bin) ),
                :by( [] ),
                :$type
            )
        }
    }
    #| this just takes the value of the config key in the top-level configuration
    multi method asset-slurp( %asset-paths ) {
        for %asset-paths.kv -> $type, %spec {
            self.asset-slurp( %spec<directory>, %spec<extensions>, $type)
        }
    }
    #| with type 'all', all the assets are sent to the same output director
    multi method asset-spurt( $directory ) {
        X::Collection::BadAssetOutputDirectory.new(:$directory).throw
            unless $directory and $directory.IO.d;
        for self.asset-used-list -> $nm {
            mktree( "$directory/$nm".IO.dirname ) unless "$directory/$nm".IO.dirname.IO.d;
            "$directory/$nm".IO.spurt( %!data-base{$nm}<object>, :bin )
        }
    }
}

sub update-cache(Bool:D :$no-status is copy, Bool:D :$recompile, Bool:D :$no-refresh, Bool:D :$without-processing,
                 :$doc-source, :$cache-path,
                 :@obtain, :@refresh, :@ignore, :@extensions
        --> Pod::From::Cache) {

    if $without-processing and $cache-path.IO.d { # non-existence of a cache over-rides without-processing
        $no-status = True
    } # enforce silence if without processing and cache exists
    else {
        rm-cache($cache-path) if $recompile;
        #removing the cache forces a recompilation

        if !$doc-source.IO.d and @obtain {
            my $proc = Proc::Async.new( @obtain.list );
            my $proc-rv;
            $proc.stdout.tap( -> $d {} );
            $proc.stderr.tap( -> $v { $proc-rv = $v });
            await $proc.start;
            exit note $proc-rv if $proc-rv
        }
        # recompile may be needed for existing, unrefreshed sources,
        #  so recompile != !no-refresh
        elsif !$no-refresh and @refresh {
            my $proc = Proc::Async.new( @refresh.list);
            my $proc-rv;
            $proc.stdout.tap( -> $d {} );
            $proc.stderr.tap( -> $v { $proc-rv = $v });
            await $proc.start;
            exit note $proc-rv if $proc-rv;
        }
        print "$doc-source: " unless $no-status;
    }
    Pod::From::Cache.new(
        :$doc-source,
        :$cache-path,
        :@ignore,
        :@extensions,
        :progress($no-status ?? Nil !! &counter)) but Post-cache
}

multi sub collect(Str:D :$dump-at, |c ) {
    collect(:dump-at([$dump-at, ]), |c )
}
multi sub collect(:$no-cache = False, |c) {
    my $mode = get-config(:$no-cache, :required('mode',))<mode>;
    collect($mode, :$no-cache, |c)
}

multi sub collect(Str:D $mode,
                  :$no-status,
                  :$without-processing is copy,
                  :$no-refresh is copy,
                  :$recompile is copy,
                  :$full-render is copy,
                  :$no-report is copy,
                  :$no-completion is copy,
                  :$collection-info is copy,
                  Str :$end = 'all',
                  :@dump-at = (),
                  :$debug-when = '', :$verbose-when = '', :$with-only = '',
                  Bool :$no-cache = False
          ) {
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
    my $cache = update-cache(
        :cache-path(%config<cache>), :doc-source(%config<sources>),
        :no-status($no-status // %config<no-status> // False),
        :$recompile,
        :$no-refresh,
        :$without-processing,
        :obtain(%config<source-obtain> // ()),
        :refresh(%config<source-refresh> // ()),
        :ignore(%config<ignore> // ()),
            :extensions(%config<extensions> // <pod6 rakudoc>)
    );
    my $rv = milestone('Source', :with($cache), :@dump-at, :$collection-info);
    return $rv if $end ~~ /:i Source /;
    # === Source milestone ====================================
    # === no plugins because Mode config not available yet.
    X::Collection::NoMode.new(:$mode).throw
    unless "$*CWD/$mode".IO.d and $mode ~~ / ^ [\w | '-' | '_']+ $ /;
    %config ,= get-config(:$no-cache, :path("$mode/configs"),
            :required<mode-cache mode-sources plugins-required destination completion-options>);
    # include mode level control flags
    without $no-completion {
        $no-completion = %config<no-completion> // False
    }
    without $no-report {
        $no-report = %config<no-report> // False
    }
    without $no-completion {
        $no-completion = %config<no-completion> // False
    }
    without $collection-info {
        $collection-info = %config<collection-info> // False
    }
    my $mode-cache = update-cache(
        :no-status($no-status // %config<no-status>),
        :recompile($recompile // %config<recompile>),
        :no-refresh($no-refresh // %config<no-refresh>),
        :$without-processing,
        :obtain(%config<mode-obtain> // ()), :refresh(%config<mode-refresh> // ()),
        :cache-path("$mode/" ~ %config<mode-cache>), :doc-source("$mode/" ~ %config<mode-sources>),
        :ignore(%config<mode-ignore> // ()), :extensions(%config<mode-extensions> // ())
    );
    # if at this stage there are any cache changes
    # then without-processing must be over-ridden
    # because had it was True, and changes bubble to here, then the caches were empty and had to
    # be recreated
    my Bool $source-changes = ?(+$cache.list-files);
    my Bool $collection-changes = ?(+$mode-cache.list-files);
    my @plugins-used;
    my %processed;
    my %symbols;
    my Archive::Libarchive $arc;
    # if no cache changes, then no need to run setup
    # if full-render, then setup has to be done for all cache files to ensure pre-processing happens
    # if without-processing was true, and cache-changes, then all files will be listed in any case, so
    # value of full-render is moot.
    $rv = milestone('Setup',
            :with($cache, $mode-cache, $full-render, %config<sources>, %config<mode-sources>),
            :@dump-at, :$collection-info, :@plugins-used, :%config,
            :$mode, :call-plugins($source-changes or $collection-changes or $full-render));
    return $rv if $end ~~ /:i Setup /;
    # === Setup milestone ==================================================
    rmtree "$*CWD/$mode/%config<destination>" if $full-render;
    unless "$*CWD/$mode/%config<destination>".IO.d {
        "$*CWD/$mode/%config<destination>".IO.mkdir;
        $full-render = True;
    }
    # both processed and symbols must exist for without-processing or partial processing to work
    if ! $full-render and "$mode/{PROCESSED-CACHE}".IO.f  {
        say "Recovering state from cache" unless $no-status;
        my $timer = now;
        $arc .= new(:operation(LibarchiveRead), :file( "$*CWD/$mode/{PROCESSED-CACHE}" ) );
        my %rv;
        use MONKEY-SEE-NO-EVAL;
        my Archive::Libarchive::Entry $e .= new;
        while $arc.next-header( $e ) {
            if $e.pathname eq CACHENAME {
                %rv = EVAL $arc.read-file-content( $e)
            }
            else { $arc.data-skip }
        }
        %processed = %rv<processed>;
        %symbols = %rv<symbols>;
        say "Recovery took { now - $timer } secs" unless $no-status
    }
    else { $full-render = True }
    # %processed contains all processed data and is cached after the rendering stage
    # The rendering stage occurs if
    # 1) full-render = true & without-processing = false
    # 2) one/both caches did not exist prior to this run
    # 3) destination directory did not exist prior to this run
    # 4) PROCESSED-CACHE (& SYMBOL) doesn't exist
    if $source-changes or $collection-changes or $full-render {
        # Prepare the renderer
        # get the template names
        my @templates = "$*CWD/$mode/{ %config<templates> }".IO.dir(test => / '.raku' /).sort;
        exit note "There must be templates in ｢~/{ "$*CWD/$mode/templates".IO.relative($*HOME) }｣:"
        unless +@templates;
        my ProcessedPod $pr .= new;
        $pr.no-code-escape = %config<no-code-escape> if %config<no-code-escape>:exists;
        $pr.templates(~@templates[0]);
        for @templates[1 .. *- 1] { $pr.modify-templates(~$_, :path("$mode/templates")) }
        $pr.add-data('mode-name', $mode);
        my Asset-cache $image-manager .= new(:basename(%config<asset-basename>));
        $image-manager.asset-slurp(%config<asset-paths>);
        $pr.add-data('image-manager', %(:manager($image-manager), :dest-dir(%config<asset-out-path>)));
        my @files;
        for <sources mode> -> $stage {
            if $stage eq 'sources' {
                $rv = milestone('Render', :with($pr), :@dump-at, :%config, :$mode, :$collection-info, :@plugins-used,
                        :call-plugins);
                return $rv if $end ~~ /:i Render /;
                # ======== Render milestone =============================
                @files = $full-render ?? $cache.sources.list !! $cache.list-files.list;
                @files .= grep( { $_ ~~ / $with-only / }) if $with-only;
                counter(:start(+@files), :header('Rendering content files'))
                unless $no-status or !+@files;

            }
            else {
                # $stage eq mode
                $rv = milestone('Compilation',
                        :with($pr, %processed),
                        :@dump-at,
                        :%config,
                        :$mode, :$collection-info, :@plugins-used,
                        :call-plugins);
                return $rv if $end ~~ /:i Compilation /;
                # ==== Compilation Milestone ===================================
                # All the mode files assumed to depend on the source files, So all mode files are re-rendered
                # if any source file is changed.
                # But if only mode files have changed, then there is only a need to render the mode files.
                if !$source-changes {
                    @files = $mode-cache.sources.list
                }
                else {
                    # since either source-changes or mode-changes are true to get here, if source-changes is false
                    # then mode-changes must be true
                    @files = $mode-cache.list-files.list
                }
                @files .= grep( { $_ ~~ / $with-only / }) if $with-only;
                counter(:start(+@files), :header("Rendering $mode content files"))
                unless $no-status or !+@files;
            }
            # sort files so that longer come later, meaning sub-directories appear after parents
            # when creating the sub-directory
            for @files.sort -> $fn {
                counter(:dec) unless $no-status;
                # files are cached with the relative path from Collection route & extension
                # output file names are needed with output extension and relative to output directory
                # there is a possibility of a name clash when filename differs only by extension.
                my $short;
                # $fn is guaranteed to be unique by the filesystem
                # $short may not be unique because a file many have the same name, but different extensions
                # only changed files are rendered, so old data needs to be removed
                if %symbols{$fn}:exists {
                    # if this is true, then the render stage is being run with changed files and fn has changed
                    $short = %symbols{$fn};
                    %processed{$short}:delete;
                }
                else {
                    # this is a first run, or full-render so populate the symbol table
                    if $stage eq 'sources' {
                        $short = $fn.IO.relative(%config<sources>).IO.extension('').Str
                    }
                    else {
                        $short = $fn.IO.relative("$mode/%config<mode-sources>").IO.extension('').Str
                    }
                    while %processed{$short}:exists {
                        FIRST { $short ~= '-1' }
                        $short++
                        # bump name if same name exists
                    }
                    %symbols{$fn} = $short;
                }
                with "$mode/%config<destination>/$short".IO.dirname {
                    .IO.mkdir unless .IO.d
                }
                $image-manager.current-file = $short;
                with $pr {
                    .pod-file.name = $short;
                    .pod-file.path = $fn;
                    .debug = ?($debug-when and $fn ~~ / $debug-when /);
                    .verbose = ?($verbose-when and $fn ~~ / $verbose-when /);
                    if $stage eq 'sources' {
                        .process-pod($cache.pod($fn));
                    }
                    else {
                        .process-pod($mode-cache.pod($fn));
                    }
                    .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                    %processed{$short} = .emit-and-renew-processed-state;
                    .debug = .verbose = False;
                }
            }
        }
        $rv = milestone('Report', :with(%processed, @plugins-used, $pr), :@dump-at,
                :%config, :$mode, :$collection-info, :@plugins-used, :call-plugins(!$no-report));
        return $rv if $end ~~ /:i Report /;
        # ==== Report Milestone ===================================
        # Save state , move assets
        # @output-files = (%processed.keys.sort >>~>> ('.' ~ %config<output-ext>));
        for %config<asset-out-paths>.kv -> $type, $dir {
            mktree $dir unless $dir.IO.d
        }
        try {
            $arc .= new(
                    :operation(LibarchiveOverwrite),
                    :file("$*CWD/$mode/{PROCESSED-CACHE}"),
                    );
            my Buf $buffer .= new: %(:%processed, :%symbols).raku.encode;
            $arc.write-header(CACHENAME, :size($buffer.bytes), :atime(now.Int), :mtime(now.Int), :ctime(now.Int));
            $arc.write-data($buffer);
            $arc.close;
            CATCH {
                default { say "Exception getting processed cache: ", .Str}
            }
        }
        $image-manager.asset-spurt("$mode/%config<destination>/%config<asset-out-path>")
    }
    $rv = milestone('Completion',
            :with(%processed, "$mode/%config<destination>".IO.absolute,
                  %config<landing-place>, %config<output-ext>, %config<completion-options>),
            :$mode, :@dump-at, :%config, :$collection-info,
            :@plugins-used, :call-plugins(!$no-completion));
    return $rv if $end ~~ /:i Completion /;
    # === Completion Milestone ================================
    @plugins-used
    # inspection point end eq 'all'
    # === All milestone (nothing else must happen) ================================
}

sub plugin-confs(:$mile, :%config, :$mode, :$collection-info = False) {
    my @valid-confs;
    # order of plug-ins is important
    for %config<plugins-required>{$mile}.list -> $plug {
        say "Plugin ｢$plug｣ is listed for milestone ｢$mile｣ " if $collection-info;
        my $path = "$mode/{ %config<plugins> }/$plug/config.raku";
        next unless $path.IO.f;
        my %plugin-conf = get-config(:$path);
        next unless %plugin-conf{$mile}:exists and %plugin-conf{$mile}.defined;
        say "Plugin ｢$plug｣ is valid with keys ｢{ %plugin-conf.keys.join(',') }｣" if $collection-info;
        @valid-confs.push: $plug => %plugin-conf;
    }
    @valid-confs
}
multi sub manage-plugins(Str:D $mile where *~~ any(< setup compilation completion>),
                         :$with,
                         :%config, :$mode,
                         :$collection-info = False) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        # only run callable and closure within the directory of the plugin
        my $callable = "$mode/%config<plugins>/$plug/{ %plugin-conf{$mile} }".IO.absolute;
        my $path = $callable.IO.dirname;
        my &closure;
        try {
            &closure = indir($path, { EVALFILE $callable });
            indir($path, { &closure.(|$with) });
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
    }
    @valids
}
multi sub manage-plugins(Str:D $mile where *eq 'render', :$with where *~~ ProcessedPod,
                         :%config, :$mode,
                         :$collection-info = False) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        my $path = "$mode/%config<plugins>/$plug".IO.absolute;
        # Since the configuration matches what the add-plugin method expects as named parameters
        if %plugin-conf<render> ~~ Str {
            # as opposed to being a Boolean value, then its a program
            my $callable = "$mode/%config<plugins>/$plug/{ %plugin-conf{$mile} }".IO.absolute;
            my $path = $callable.IO.dirname;
            my &closure;
            try {
                &closure = indir($path, { EVALFILE $callable })
            }
            if $! {
                note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
            }
            # a plugin should only affect the report directly
            # so a plugin should not write directly
            my @asset-files;
            try {
                @asset-files = indir($path, { &closure.($with) });
            }
            if $! {
                note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
            }
            for @asset-files -> ($to, $other-plug, $file) {
                # copy the files returned - the use case for this is css and script files to be
                # served with html files. The sub-directory paths are needed local to the output files
                # they will be named in the templates provided by the plugins
                # the simplest case is when a plugin asks for a plugin from its own
                # directory. But there is also the case of moving files from other
                # directories. How to do this securely? We can allow transfers from a plugin directory
                # so the plugin-data space will contain a path for each registered plugin.
                # consequently, we have a three element copy
                my $from;
                if $other-plug eq MYSELF {
                    $from = "$path/$file";
                }
                else {
                    my $config = $with.get-data($other-plug); # returns Nil if no data
                    unless $config {
                        note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n"
                                ~ "｢$other-plug｣ is not registered as a plugin in ProcessedPod instance";
                        next
                    }
                    $from = $config<path> ~ '/' ~ $file
                }
                my $to-path = "$mode/%config<destination>/$to".IO;
                mkdir($to-path.dirname) unless $to-path.dirname.IO.d;
                unless $from.IO.f {
                    note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n"
                            ~ "｢$from｣ is not a valid file. Skipping.";
                    next
                }
                $from.IO.copy($to-path);
            }
        }
        $with.add-plugin($plug,
            :$path,
            :template-raku(%plugin-conf<template-raku>:delete),
            :custom-raku(%plugin-conf<custom-raku>:delete),
            :config(%plugin-conf)
        );
    }
    @valids
}
multi sub manage-plugins(Str:D $mile where *eq 'report', :$with,
                         :%config, :$mode,
                         :$collection-info = False) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    mkdir "$mode/%config<report-path>" unless "$mode/%config<report-path>".IO.d;
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        my $callable = "$mode/%config<plugins>/$plug/{ %plugin-conf{$mile} }".IO.absolute;
        my $path = $callable.IO.dirname;
        my &closure;
        try {
            &closure = indir($path, { EVALFILE $callable });
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
        # a plugin should only affect the report directly
        # so a plugin should not write directly
        my $resp;
        try {
            $resp= indir($path, { &closure.(|$with) });
            "$mode/{ %config<report-path> }/{ $resp.key }".IO.spurt($resp.value)
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
    }
    @valids
}

#| uses Terminal::Spinners to create a progress bar, with a starting value, that is decreased by 1 after an iteration.
sub counter(:$start, :$dec, :$header = 'Caching files ') {
    state $hash-bar = Bar.new(:type<bar>);
    state $inc;
    state $done;
    state $timer;
    state $final;
    if $start {
        # also fails if $start = 0
        $inc = 1 / $start * 100;
        $done = 0;
        $timer = now;
        $final = $start;
        say $header;
        $hash-bar.show: 0
    }
    if $dec {
        $done += $inc;
        $hash-bar.show: $done;
        say "$header took { now - $timer } secs" unless --$final;
    }
}

sub milestone($mile, :$with, :@dump-at = (), :$collection-info,
              :%config = {}, :$mode = '', :@plugins-used = (), Bool :$call-plugins = False) {
    @plugins-used.append(%( $mile => manage-plugins($mile.lc, :$with, :%config, :$mode, :$collection-info)))
        if $call-plugins;
    if $mile.lc ~~ any( |@dump-at ) {
        my $rv = '';
        for $with.list -> $ds {
            $rv ~= ($ds.raku ~ "\n\n")
        }
        "dumped-{ $mode ?? $mode !! 'mode-unknown' }-at-{ $mile.lc }\.txt".IO.spurt($rv);
    }
    say "Passed \<$mile> milestone" if $collection-info;
    $with
}