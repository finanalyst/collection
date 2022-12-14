use v6.d;
use Terminal::Spinners;
use RakuConfig;
use Pod::From::Cache;
use ProcessedPod;
use File::Directory::Tree;
use Collection::Exceptions;

unit module Collection;

proto sub collect(|c) is export {
    X::Collection::BadOption.new(:passed(|c.keys.grep(*~~ Str))).throw
    unless all(|c.keys.grep(*~~ Str))
            eq
            any(<no-status no-preserve-state no-refresh recompile full-render
                without-processing without-report without-completion
                before after collection-info
                dump-at debug-when verbose-when with-only>);
    {*}
}

#| The string used by plugins to describe themselves
constant MYSELF = 'myself';
constant PRESERVE = 'processed-state.7z';

#| adds a filter to a cache object
#| Anything that exists in the %!extra hash is returned
#| If the key does not exist, it is as if the Cache does not contain it
#| A filename can be blocked from addressing cache by setting its %extra key to Nil
role Post-cache is export {
    #| contains Pod arrays associated with file names, or a Str if filename associated with an alias
    has %!extra = %();
    #| protect aliases from being overwritten
    has %!aliases = %();
    #| Checks to see if %!extra has non-Nil keys, returns them
    #| returns all underlying cache keys not in Extra
    method sources {
        (%!extra.keys.grep({ %!extra{$_}.so }),
         callsame.grep({ $_ !~~ any(%!extra.keys) })).flat
    }
    #| As sources, but returns list-changed-files of underlying cache
    method list-changed-files {
        (%!extra.keys.grep({ %!extra{$_}.so }),
         callsame.grep({ $_ !~~ any(%!extra.keys) })).flat
    }
    #| checks if filename in extra, returns value or value of alias,
    #| otherwise returns value in underlying cache
    method pod(Str $fn) {
        if %!extra{$fn}:exists {
            my $rv = %!extra{$fn};
            return $rv if $rv ~~ Array;
            # return value if Array
            nextwith($rv) if $rv ~~ Str:D;
            # return underlying alias if Str
            return Nil
            # return Nil otherwise

        }
        nextwith($fn)
    }
    #| adds a filename to be returned as if in cache
    #| effectively masks the filename in cache
    #| returns self so that method can be chained
    multi method add(Str $fn, Array $p --> Pod::From::Cache) {
        %!extra{$fn} = $p;
        self
    }
    #| masks a filename, so it is not returned by sources/list-changed-files
    #| can be chained
    multi method mask(Str $fn --> Pod::From::Cache) {
        %!extra{$fn} = Nil;
        self
    }
    #| creates an alias to an entry
    #| aliases cannot be overwritten
    #| can be chained
    multi method add-alias(Str $fn, Str :$alias! --> Pod::From::Cache) {
        X::Collection::Post-cache-illegal-alias.new(:$fn, :$alias).throw
        if %!extra{$fn} ~~ Array;
        X::Collection::Post-cache-alias-overwrite.new(:$fn, :$alias, :old(%!aliases{$alias})).throw
        if %!aliases{$alias}:exists;
        %!aliases{$alias} = %!extra{$alias} = $fn;
        self
    }
    #| returns the original cache name of the file behind an alias, if an alias was made
    method behind-alias(Str $fn --> Str) {
        if %!aliases{$fn}:exists { %!aliases{$fn} }
        else { $fn }
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
    #| not all items in cache may be used by an individual rakudoc file
    method asset-sources {
        %!data-base.keys
    }
    #| asset-used-list provides a list of all the items that referenced by Content files
    method asset-used-list {
        %!data-base.keys.grep({ %!data-base{$_}<by>.elems })
    }
    #| asset-add adds an item to the data-base, for example, a transformed image
    method asset-add($name, $object, :$by = (), :$type = 'image') {
        %!data-base{$name} = %( :$object, :$by, :$type);
    }
    #| return the data base's name/by/type data
    method asset-db(--> Hash) {
        %( %!data-base.map({ .key => %( type => .value<type>, by => .value<by>) }))
    }
    #| remove the named asset, and return its metadata
    method asset-delete($name --> Hash) {
        %!data-base{$name}:delete
    }
    #| returns the type of the asset
    method asset-type($name --> Str) {
        %!data-base{$name}<type>
    }
    #| if an asset with name and type exists in the database, then it is marked as used by the current file
    #| returns true with success, and false if not.
    method asset-is-used($asset, $type, :$by = $!current-file --> Bool) {
        if %!data-base{$asset}:exists and %!data-base{$asset}<type> eq $type {
            %!data-base{$asset}<by>.append: $by;
            True
        }
        else { False }
    }
    #| brings all assets in directory with given extensions and with type
    #| these are set in the configuration
    multi method asset-slurp($directory,  @extensions, $type) {
        X::Collection::BadAssetDirectory.new(:$!basename, :dir($directory)).throw
        unless "$.basename/$directory".IO.d;
        my @sources = my sub recurse ($dir) {
            gather for dir($dir) {
                take $_ if  .extension ~~ any(@extensions);
                take slip sort recurse $_ if .d;
            }
        }("$.basename/$directory");
        # is the first definition of $dir
        for @sources {
            %!data-base{$_.relative($.basename)} = %(
                :object(.slurp(:bin)),
                :by([]),
                :$type
            )
        }
    }
    #| this just takes the value of the config key in the top-level configuration
    multi method asset-slurp(%asset-paths) {
        for %asset-paths.kv -> $type, %spec {
            self.asset-slurp(%spec<directory>, %spec<extensions>, $type)
        }
    }
    #| with type 'all', all the assets are sent to the same output director
    multi method asset-spurt($directory) {
        X::Collection::BadOutputDirectory.new(:$directory).throw
        unless $directory and $directory.IO.d;
        for self.asset-used-list -> $nm {
            mktree("$directory/$nm".IO.dirname) unless "$directory/$nm".IO.dirname.IO.d;
            "$directory/$nm".IO.spurt(%!data-base{$nm}<object>, :bin)
        }
    }
}

sub update-cache(:$no-status, :$recompile, :$no-refresh,
                 :$doc-source, :$cache-path,
                 :@obtain, :@refresh, :@ignore, :@extensions
        --> Pod::From::Cache) {
    rm-cache($cache-path) if $recompile;
    #removing the cache forces a recompilation

    if !$doc-source.IO.d and @obtain {
        my $proc = run(@obtain.list, :err);
        if $proc.exitcode {
            exit note $proc.err.slurp(:close)
        }
        else {
            say '<' ~ @obtain.join(' ') ~ '> was successful';
        }
    }
    # recompile may be needed for existing, unrefreshed sources,
    #  so recompile != !no-refresh
    elsif !$no-refresh and @refresh {
        my $proc = run(@refresh.list, :err );
        if $proc.exitcode {
            exit note $proc.err.slurp(:close)
        }
        else {
            say '<' ~ @refresh.join(' ') ~ '> was successful';
        }
    }
    print "$doc-source: " unless $no-status;
    Pod::From::Cache.new(
            :$doc-source,
            :$cache-path,
            :@ignore,
            :@extensions,
            :progress($no-status ?? Nil !! &counter)) but Post-cache
}

multi sub collect(:$no-status = False, |c) {
    my $mode = get-config( :required('mode',))<mode>;
    collect($mode, :$no-status, |c)
}
multi sub collect(Str:D $mode,
                  :$no-status is copy,
                  :$without-processing is copy,
                  :$no-refresh is copy,
                  :$recompile is copy,
                  :$full-render is copy,
                  :$without-report is copy,
                  :$without-completion is copy,
                  :$collection-info is copy,
                  :$no-preserve-state is copy,
                  Str :$before = '',
                  Str :$after = 'all',
                  :@dump-at = (),
                  Str :$debug-when = '', Str :$verbose-when = '', Str :$with-only = ''
                  ) {
    my $cache;
    my $mode-cache;
    my @plugins-used;
    my $rv;
    my Bool $ret-before;
    my Bool $ret-after;
    my %config = get-config( :required< sources cache without-processing no-refresh recompile>);
    $no-status = (%config<no-status> // False) without $no-status;
    $without-processing = %config<without-processing> without $without-processing;
    $no-refresh = %config<no-refresh> without $no-refresh;
    $recompile = %config<recompile> without $recompile;

    # make sure $without-processing can proceed
    if $without-processing {
        my %t-config =get-config( :path("$mode/configs" ));
        if "$*CWD/$mode/{ %t-config<destination> }".IO ~~ :e & :d {
            %config ,= %t-config;
        }
        else {
            note "Cannot continue without processing" unless $no-status;
            $without-processing = False;
        }
    }
    unless $without-processing {
        say "Starting ｢Source｣ milestone" if $collection-info;

        $cache = update-cache(
                :cache-path(%config<cache>), :doc-source(%config<sources>),
                :$no-status,
                :$recompile,
                :$no-refresh,
                :obtain(%config<source-obtain> // ()),
                :refresh(%config<source-refresh> // ()),
                :ignore(%config<ignore> // ()),
                :extensions(%config<extensions> // <pod6 rakudoc>)
        );
        $ret-after = ?($after ~~ /:i Source /);
        $ret-before = ?($before ~~ /:i Mode /); # call-plugins False because there are no plugins valid here
        $rv = milestone('Mode', :with($cache), :@dump-at, :$collection-info, :@plugins-used, :!call-plugins );
        return $rv if ($ret-after or $ret-before);
        # === Source / Mode milestone ====================================
        # === no plugins because Mode config not available yet.
        X::Collection::NoMode.new(:$mode).throw
        unless "$*CWD/$mode".IO.d and $mode ~~ / ^ [\w | '-' | '_']+ $ /;
        %config ,= get-config( :path("$mode/configs"),
                :required<mode-cache mode-sources plugins-required destination plugin-options>);
        # include mode level control flags
        $without-completion = ( %config<without-completion> // False ) without $without-completion;
        $without-report = ( %config<without-report> // False ) without $without-report;
        $collection-info = ( %config<collection-info> // False ) without $collection-info;
        $recompile = ( %config<recompile> // False ) without $recompile;
        $full-render = ( %config<full-render> // False ) without $full-render;
        $no-preserve-state = ( %config<no-preserve-state> // False ) without $no-preserve-state;
        if $no-preserve-state {
            $full-render = True; # over-ride full-render if no preserve state
            my $file = "$*CWD/$mode/{ PRESERVE }";
            rmtree $file if $file.IO.e;
        };

        $mode-cache = update-cache(
                :$no-status,
                :$recompile,
                :$no-refresh,
                :obtain(%config<mode-obtain> // ()), :refresh(%config<mode-refresh> // ()),
                :cache-path("$mode/" ~ %config<mode-cache>), :doc-source("$mode/" ~ %config<mode-sources>),
                :ignore(%config<mode-ignore> // ()), :extensions(%config<mode-extensions> // ())
                                                    );
        my Bool $source-changes = ?(+$cache.list-changed-files);
        my Bool $collection-changes = ?(+$mode-cache.list-changed-files);
        my %processed;
        my %symbols;

        rmtree "$*CWD/$mode/%config<destination>" if $full-render;
        unless "$*CWD/$mode/%config<destination>".IO.d {
            "$*CWD/$mode/%config<destination>".IO.mkdir;
            $full-render = True;
        }
        # processed and symbols must exist for partial processing to work
        unless $full-render {
            my $ok;
            ($ok, %processed, %symbols) = restore-processed-state($mode, :$no-status);
            $full-render = !$ok;
        }
        # %processed contains all processed data and is preserved by default after the rendering stage
        $ret-after = ?($after ~~ /:i Mode /);
        $ret-before = ?($before ~~ /:i Setup /);
        #plugins called if (1) ret-before True, (2) Not $ret-after, (3) ( $ret-after = false & $ret-before = False)
        # call if ret-before or ! ret-after or (! ret-after & ! ref-before )
        #  call-pl  ret-after ret-before
        #     F        T        T       (ret-after takes precedence)
        #     F        T        F
        #     T        F        T
        #     T        F        F

        $rv = milestone('Setup',
            :with($cache, $mode-cache, $full-render, %config<sources>, %config<mode-sources>, %config<plugin-options>),
            :@dump-at, :$collection-info, :@plugins-used, :%config, :$mode,
            :call-plugins( !$ret-after )
        );
        return $rv if ($ret-after or $ret-before);
        # if no cache changes, then no need to run setup
        # if full-render, then setup has to be done for all cache files to ensure pre-processing happens
        # === Source / Setup milestone ==================================================
        # The rendering stage occurs if
        # 1) full-render = true
        # 2) one/both caches did not exist prior to this run
        # 3) destination directory did not exist prior to this run
        # 4) PROCESSED-CACHE (& SYMBOL) doesn't exist
        if $source-changes or $collection-changes or $full-render {
            say "Rendering Collection on { now.Date } at { now.DateTime.hh-mm-ss }"
                unless $no-status;
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
                    $ret-after = ?($after ~~ /:i Setup /);
                    $ret-before = ?($before ~~ /:i Render /);
                    $rv = milestone('Render',
                            :with($pr),
                            :@dump-at,
                            :%config,
                            :$mode,
                            :$collection-info,
                            :@plugins-used,
                            :call-plugins( !$ret-after)
                    );
                    return $rv if ($ret-after or $ret-before);
                    # ======== Setup / Render milestone =============================
                    @files = $full-render ?? $cache.sources.list !! $cache.list-changed-files.list;
                    @files .= grep({ $_ ~~ / $with-only / }) if $with-only;
                    counter(:items(@files), :header('Rendering content files'))
                    unless $no-status or !+@files;

                }
                else {
                    # $stage eq mode
                    $ret-after = ?($after ~~ /:i Render /);
                    $ret-before = ?($before ~~ /:i Compilation /);
                    $rv = milestone('Compilation',
                        :with($pr, %processed),
                        :@dump-at,
                        :%config,
                        :$mode,
                        :$collection-info,
                        :@plugins-used,
                        :call-plugins( !$ret-after )
                    );
                    return $rv if ($ret-after or $ret-before);
                    # ==== Render / Compilation Milestone ===================================
                    # All the mode files assumed to depend on the source files, so all mode files are re-rendered
                    # if any source file is changed, or all sources to be rendered.
                    # But if only mode files have changed, then there is only a need to render the mode files.
                    if $source-changes or $full-render {
                        @files = $mode-cache.sources.list
                    }
                    else {
                        # since either source-changes or mode-changes are true to get here, if source-changes is false
                        # then mode-changes must be true
                        @files = $mode-cache.list-changed-files.list
                    }
                    @files .= grep({ $_ ~~ / $with-only / }) if $with-only;
                    counter(:items(+@files), :header("Rendering $mode content files"))
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
                        .debug = ?($debug-when and $fn ~~ / $debug-when /);
                        .verbose = ?($verbose-when and $fn ~~ / $verbose-when /);
                        if $stage eq 'sources' {
                            .pod-file.path = $cache.behind-alias($fn);
                            .process-pod($cache.pod($fn));
                        }
                        else {
                            .pod-file.path = $mode-cache.behind-alias($fn);
                            .process-pod($mode-cache.pod($fn));
                        }
                        .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                        %processed{$short} = .emit-and-renew-processed-state;
                        .debug = .verbose = False;
                    }
                }
            }
            $ret-after = ?($after ~~ /:i Compilation /);
            $ret-before = ?($before ~~ /:i Transfer /);
            $rv = milestone('Transfer', :with($pr, %processed), :@dump-at,
                :%config, :$mode, :$collection-info, :@plugins-used, :call-plugins( !$ret-after )
            );
            return $rv if ($ret-after or $ret-before);
            # ==== Compilation / Transfer Milestone ===================================
            for %config<asset-out-paths>.kv -> $type, $dir {
                mktree $dir unless $dir.IO.d
            }
            $image-manager.asset-spurt("$mode/%config<destination>/%config<asset-out-path>");
            save-processed-state($mode, %processed, %symbols, :$no-status)
                unless $no-preserve-state;
            $ret-after = ?($after ~~ /:i Transfer /);
            $ret-before = ?($before ~~ /:i Report /);
            $rv = milestone('Report', :with(%processed, @plugins-used, $pr), :@dump-at,
                :%config, :$mode, :$collection-info, :@plugins-used, :call-plugins( !$ret-after and !$without-report));
            return $rv if ($ret-after or $ret-before);
            # ==== Transfer / Report Milestone ===================================
        }
    }
    $ret-after = ?($after ~~ /:i Report /);
    $ret-before = ?($before ~~ /:i Completion /);
    $rv = milestone('Completion',
            :with("$mode/{ %config<destination> }".IO.absolute,
                  %config<landing-place>, %config<output-ext>, %config<plugin-options>),
            :$mode, :@dump-at, :%config, :$collection-info, :$no-status,
            :@plugins-used, :call-plugins( !$ret-after and !$without-completion));
    return $rv if ($ret-after or $ret-before);
    # === Report / Completion Milestone ================================
    @plugins-used
    # inspection point after eq 'all'
    # === All milestone (nothing else must happen) ================================
}

sub restore-processed-state($mode, :$no-status --> Array) is export {
    use Archive::Libarchive;
    use Archive::Libarchive::Constants;
    my $file = "$*CWD/$mode/{ PRESERVE }";
    my $ok = $file.IO ~~ :e & :f;
    note "Could not recover the archive with processed state ｢$file｣. Turning on full-render."
        unless $ok or $no-status;
    return [$ok] unless $ok;
    my Archive::Libarchive $arc .= new(
    :operation(LibarchiveExtract),
    :$file
    );
    my %rv;
    use MONKEY-SEE-NO-EVAL;
    my Archive::Libarchive::Entry $e .= new;
    say "Recovering processed state" unless $no-status;
    my $timer = now;
    while $arc.next-header($e) {
        if $e.pathname eq 'processed-state' {
            %rv = EVAL $arc.read-file-content($e)
        }
        else { $arc.data-skip }
    }
    say "Recovery took { now - $timer } secs" unless $no-status;
    [$ok, %rv<processed>, %rv<symbols>]
}
sub save-processed-state($mode, %processed, %symbols, :$no-status) {
    use Archive::Libarchive;
    my Archive::Libarchive $arc;
    say "Saving processed state to archive" unless $no-status;
    my $timer = now;
    my $file = "$*CWD/$mode/{ PRESERVE }";
    try {
        $arc .= new(
                :operation(LibarchiveOverwrite),
                :$file,
                );
        my Buf $buffer .= new: %(:%processed, :%symbols).raku.encode;
        $arc.write-header('processed-state', :size($buffer.bytes), :atime(now.Int), :mtime(now.Int), :ctime(now.Int));
        $arc.write-data($buffer);
        $arc.close;
        CATCH {
            default { say "Exception saving processed state: ", .Str }
        }
    }
    say "Saving state took { now - $timer } secs" unless $no-status;
}
sub plugin-confs(:$mile, :%config, :$mode, :$collection-info) {
    return [] without %config<plugins-required>{$mile};
    my @valid-confs;
    # order of plug-ins is important
    for %config<plugins-required>{$mile}.list -> $plug {
        my $resp  = "Plugin ｢$plug｣ is listed for milestone ｢$mile｣";
        unless "$mode/plugins/$plug".IO.d {
            note "$resp, but does not exist. Ignored.";
            next
        }
        my $path = "$mode/plugins/$plug/config.raku";
        unless $path.IO ~~ :e & :f {
            note "$resp, but does not have a config file. Ignored.";
            next
        }
        my %plugin-conf = get-config(:$path);
        without %plugin-conf{$mile} {
            note "$resp, but has no config key for milestone. Ignored.";
            next
        }
        say "$resp and has keys ｢{ %plugin-conf.keys.join(',') }｣" if $collection-info;
        # check to see if the plugin has Mode level options
        if $plug (elem) %config<plugin-options>.keys {
            %plugin-conf ,= %config<plugin-options>{ $plug }.Hash
        }
        @valid-confs.push: $plug => %plugin-conf;
    }
    @valid-confs
}

multi sub manage-plugins(Str:D $mile where *~~ any(< setup completion >),
                         :$with,
                         :%config, :$mode,
                         :$collection-info,
                         :$no-status
                         --> Array ) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    my %options = %( :$collection-info, :$no-status);
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        # only run callable and closure within the directory of the plugin
        my $path = "$mode/plugins/$plug".IO.absolute;
        my $callable = "$path/{ %plugin-conf{$mile} }".IO.absolute;
        my &closure;
        try {
            &closure = indir($path, { EVALFILE $callable });
            indir($path, { &closure.(|$with, %options) });
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
    }
    @valids
}
multi sub manage-plugins(Str:D $mile where *eq 'render', :$with,
                         :%config, :$mode,
                         :$collection-info,
                         :$no-status
                        --> Array ) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    my %options = %( :$collection-info, :$no-status);
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        my $path = "$mode/plugins/$plug".IO.absolute;
        # ensure plugin callables get config data possibly modified by Mode config
        $with.add-data($plug, %plugin-conf);
        # Since the configuration matches what the add-plugin method expects as named parameters
        if %plugin-conf<render> ~~ Str {
            # as opposed to being a Boolean value, then its a program
            my $callable = "$path/{ %plugin-conf{$mile} }".IO.absolute;
            my &closure;
            try {
                &closure = indir($path, { EVALFILE $callable })
            }
            if $! {
                note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
            }
            # so a plugin should not write directly
            my @asset-files;
            try {
                @asset-files = indir($path, { &closure.($with, %options) });
            }
            if $! {
                note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
            }
            move-files(@asset-files, $mode, $mile, $plug, $path, %config<destination>, $with)
        }
        $with.add-plugin($plug,
            :$path,
            :template-raku(%plugin-conf<template-raku>:delete),
            :custom-raku(%plugin-conf<custom-raku>:delete),
            :config(%plugin-conf),
            :!protect-name
        );
    }
    @valids
}
multi sub manage-plugins(Str:D $mile where *eq 'report', :$with,
                         :%config, :$mode,
                         :$collection-info,
                         :$no-status
                         --> Array ) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    my %options = %( :$collection-info, :$no-status);
    mkdir "$mode/%config<report-path>" unless "$mode/%config<report-path>".IO.d;
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        my $path = "$mode/plugins/$plug".IO.absolute;
        my $callable = "$path/{ %plugin-conf{$mile} }".IO.absolute;
        my &closure;
        try {
            &closure = indir($path, { EVALFILE $callable });
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
        # a plugin should only affect the report directly
        # so a plugin should not write directly
        # a plugin may offer more than one file for a report, $resp is a list of pairs
        my $resp;
        try {
            $resp = indir($path, { &closure.(|$with, %options) });
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
        for $resp.list {
            "$mode/{ %config<report-path> }/{ .key }".IO.spurt( .value )
        }
    }
    @valids
}
multi sub manage-plugins(Str:D $mile where *~~ any(< transfer compilation >),
         :$with,
         :%config, :$mode,
         :$collection-info,
         :$no-status
        --> Array ) {
    my @valids = plugin-confs(:$mile, :%config, :$mode, :$collection-info);
    my %options = %( :$collection-info, :$no-status);
    for @valids -> (:key($plug), :value(%plugin-conf)) {
        my $path = "$mode/plugins/$plug".IO.absolute;
        my $callable = "$path/{ %plugin-conf{$mile} }".IO.absolute;
        my &closure;
        try {
            &closure = indir($path, { EVALFILE $callable })
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
        # so a plugin should not write directly
        my $rv;
        try {
            $rv = indir($path, { &closure.(|$with, %options) });
        }
        if $! {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n" ~ $!.message ~ "\n" ~ $!.backtrace
        }
        move-files($rv, $mode, $mile, $plug, $path, %config<destination>, $with[0])
            if $rv ~~ Positional and $rv[0] ~~ Positional and $rv[0].elems == 3
    }
    @valids
}
sub move-files( @asset-files, $mode, $mile, $plug, $path, $destination, $pp ) {
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
            my $config = $pp.get-data($other-plug);
            # returns Nil if no data
            unless $config {
                note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n"
                    ~ "｢$other-plug｣ is not registered as a plugin in ProcessedPod instance";
                next
                }
            $from = $config<path> ~ '/' ~ $file
        }
        my $to-path = "$mode/$destination/$to".IO;
        mkdir($to-path.dirname) unless $to-path.dirname.IO.d;
        unless $from.IO ~~ :e & :f {
            note "ERROR caught in ｢$plug｣ at milestone ｢$mile｣:\n"
                ~ "｢$from｣ is not a valid file. Skipping.";
            next
            }
        $from.IO.copy($to-path);
    }
}

#| uses Terminal::Spinners to create a progress bar, with items, showing next item with :dec
multi sub counter( Int :$start ) { counter(:items( 1 .. $start )) }
multi sub counter( :@items, :$dec = False, :$header) {
    constant BEG = "\e[0G";
    state $hash-bar = Bar.new(:type<bar>);
    state $inc;
    state $done;
    state $timer;
    state $title = 'Caching files ';
    state $item = -1;
    state @s-items;
    $title = $_.Str with $header;
    @s-items = @items if +@items;
    if $dec and not +@items {
        $done += $inc;
    }
    else {
        $inc = 1 / @s-items.elems * 100;
        $done = 0;
        $timer = now;
        say $title;
    }
    $hash-bar.show: $done;
    if ++$item >= +@s-items {
        my $d = (now - $timer).Int;
        my @t = $d div 3600 , ;
        @t[1] = ($d - @t[0] * 3600) div 60;
        @t[2] = $d - @t[0] * 3600 - @t[1] * 60;
        my $ts = @t[0] > 0 ?? sprintf("%dh:%dm:%ds", @t) !! sprintf("%dm:%ds",@t[1,2]) ;
        say "\n$title took $ts";
        return
    }
    print 'item: ' ~ @s-items[$item] ~ ' ' x 20 ~ BEG;
}

sub milestone($mile, :$with, :@dump-at = (), :$collection-info, :$no-status,
              :%config = {}, :$mode = '',
              :@plugins-used,
              Bool :$call-plugins
              --> Array ) {
    if $mile ~~ /:i Mode/ {
        @plugins-used.append: %( $mile => [:message('No plugins defined'), ] );
    }
    elsif $call-plugins {
        @plugins-used.append:
        %( $mile => manage-plugins($mile.lc, :$with, :%config, :$mode, :$collection-info, :$no-status))
    }
    else {
        @plugins-used.append: %( $mile => [ :message('Plugin calls cancelled'), ] )
    }
    if $mile.lc ~~ any(|@dump-at) {
        my $rv = '';
        for $with.list -> $ds {
            $rv ~= ($ds.raku ~ "\n\n")
        }
        $rv ~= @plugins-used.raku;
        "dumped-{ $mode ?? $mode !! 'mode-unknown' }-at-{ $mile.lc }\.txt".IO.spurt($rv);
    }
    say "Starting ｢$mile｣ milestone" if $collection-info;
    [ $with, @plugins-used ];
}