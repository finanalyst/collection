use v6.*;
use Terminal::Spinners;
use RakuConfig;
use Pod::From::Cache;
use ProcessedPod;
use File::Directory::Tree;
use PrettyDump;

unit module Collection;

proto sub collect(|) is export {*}
proto sub refresh( | --> Pod::From::Cache ) {*}

multi sub refresh(:$no-status, :$recompile, :$no-refresh ) {
    # ==== Set options =======
    # both recompile and no-refresh are set in mode-level configurations, so only appear in collect called in a mode call.
    my %config = get-config(:required< no-status cache sources source-obtain source-refresh mode ignore >);
    my Bool $no-st = $no-status // %config<no-status>;

    rm-cache(%config<cache>) if $recompile;
    #removing the cache forces a recompilation

    # recompile may be needed for existing, unrefreshed sources, so recompile != !no-refresh
    unless $no-refresh or ! %config<source-refresh> {
        my $proc = run %config<source-refresh>.list, :err, :out;
        my $proc-rv = $proc.err.get;
        exit note $proc-rv if $proc-rv;
    }
    print "Collection sources: " unless $no-st;
    Pod::From::Cache.new(
            :doc-source(%config<sources>),
            :cache-path(%config<cache>),
            :ignore(%config<ignore>),
            :progress($no-st ?? Nil !! &counter));
}
multi sub refresh(Str:D :$mode, :$no-status, :$recompile ) {
    my %config = get-config(:path("$mode/config"), :required< mode-cache mode-sources recompile >);
    # if there are no mode collection sources, then do not instantiate Pod::To::Cache, as it will thow an Exception
    return Pod::From::Cache unless +( "$mode/%config<mode-sources>".IO.dir(test=> /:i '.rakudoc' $ | '.pod6' /) );
    my Bool $no-st = $no-status // %config<no-status>;

    rm-cache(%config<mode-cache>) if $recompile;
    #removing the cache forces a recompilation
    # assume that mode files are local, so refresh is not needed

    print "$mode\: " unless $no-st;
    Pod::From::Cache.new(
            :doc-source("$mode/%config<mode-sources>"),
            :cache-path("$mode/%config<mode-cache>"),
            :progress($no-st ?? Nil !! &counter));
}

multi sub collect(:$no-refresh, :$recompile, :$no-status, :$no-rerender, :$full-render) {
    my $mode = get-config(:required('mode', ))<mode>;
    collect($mode, :$no-refresh, :$recompile, :$no-status, :$no-rerender, :$full-render)
}

multi sub collect(Str $mode, :$no-refresh, :$recompile, :$no-status, :$no-rerender, :$full-render) {
    return refresh(:$no-refresh, :$no-status, :$no-rerender, :$full-render)
        if $mode eq 'Refresh';
    exit note "$mode is not a direct sub-directory of the oollection"
        unless "$*CWD/$mode".IO.d and $mode ~~ / ^ [\w | '-' | '_']+ $ /;
    my %config = get-config(:required< no-status mode>);
    %config  ,= get-config(:path("$mode/config"), :required< no-refresh recompile no-rerender full-render plugins>);

    my $noreren = $no-rerender // %config<no-rerender>;
    my $fullren = $full-render // %config<full-render>;
    # verify output directory exists, and set to fill.
    rmtree "$*CWD/$mode/%config<destination>" if $fullren;
    unless "$*CWD/$mode/%config<destination>".IO.d {
        "$*CWD/$mode/%config<destination>".IO.mkdir;
        $fullren = True;
    }

    my $cache = refresh(
        :no-status($no-status // %config<no-status>),
        :recompile($recompile // %config<recompile>),
        :no-refresh($no-refresh // %config<no-refresh>)
    );
    my $mode-cache = refresh( :$mode,
        :no-status($no-status // %config<no-status>),
        :recompile($recompile // %config<recompile>)
    );

    unless $noreren {
        # Prepare the renderer
        # get the template names
        my @templates = "$*CWD/$mode/templates".IO.dir(test => / '.raku' /).sort;
        exit note "There must be templates in ｢~/{ "$*CWD/$mode/templates".IO.relative($*HOME) }｣:"
            unless +@templates;
        my ProcessedPod $pr .= new;
        $pr.templates(~@templates[0]);
        for @templates[1 .. *- 1] { $pr.modify-templates(~$_, :path("$mode/templates")) }
        # add plugins if any
        for %config<plugins>.kv -> $plug, %conf {
            %conf<path> = "$mode/plugins/" ~ ( %conf<path> // $plug );
            $pr.add-plugin($plug, |%conf)
            # Since the configuration matches what the add-plugin method expects as named parameters
        }
        $pr.no-code-escape = %config<no-code-escape> if %config<no-code-escape>:exists;

        my @files = $fullren ?? $cache.sources.list !! $cache.list-files.list;
        my %processed;
        counter(:start(+@files), :header('Rendering content files'));
        # sort files so that longer come later, meaning sub-directories appear after parents
        # when creating the sub-directory
        for @files.sort -> $fn {
            counter(:dec);
            # files are cached with the relative path from Collection route & extension
            # output file names are needed with output extension and relative to output directory
            # there is a possibility of a name clash when filename differs only by extension.
            say $fn;
            my $short = $fn.IO.relative( %config<sources> ).IO.extension('').Str;
            if %processed{$short}:exists {
                $short ~= '-1';
                $short++ while %processed{$short}:exists ; # bump name if same name exists
            }
            with "$mode/%config<destination>/$short".IO.dirname {
                .IO.mkdir unless .IO.d
            }
            with $pr {
                .name = $short;
                .process-pod($cache.pod($fn));
                .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                # collect page components, and links
                %processed{ $short } = %( .emit-and-renew-processed-state
                        .grep({ .key ~~ / 'raw-' | 'links' /}) );
            }
        }
        # %processed containing Filename-> hash of raw-* and links
        # We want to add to pr.plugin-data, the name-space raw-* links, with $fn-> raw-*.value
        create-collection-data(:name-space($_), :key("raw-$_"), :data(%processed), :$pr )
            for <toc footnotes glossary meta>;

        @files = $mode-cache.sources.list;
        counter(:start(+@files), :header("Rendering $mode content files"));
        for @files -> $fn {
            counter(:dec);
            my $short = $fn.IO.relative( "$mode/%config<mode-sources>" ).IO.extension('').Str;
            if %processed{$short}:exists {
                $short ~= '-1';
                $short++ while %processed{$short}:exists ; # bump name if same name exists
            }
            with "$mode/%config<destination>/$short".IO.dirname {
                .IO.mkdir unless .IO.d
            }
            with $pr {
                .name = $short;
                .process-pod($mode-cache.pod($fn));
                .file-wrap(:filename("$mode/%config<destination>/$short"), :ext(%config<output-ext>));
                #only collect links
                %processed{ $short } = %(.emit-and-renew-processed-state
                        .grep({ .key ~~ / 'links' /}) );
            }
        }
        create-collection-data(:name-space<links>, :key<links>,:data(%processed), :$pr );
    }
}
#| places plugin data for collection page components, filtered by filename
#| makes available to plugins Page component structures for whole collection
sub create-collection-data(:$name-space, :$key, ProcessedPod :$pr, :%data) {
    # %data contains keys for each source and sub-keys for each page component
    # what is required is to make the structure pointed to by $key available
    # to a collection structure with sub-keys of filenames
    $pr.plugin-data{ "collection-$name-space" } =
        %( |gather for %data.keys {
            take $_ => %data{ $_ }{$key} } )
}


#| uses Terminal::Spinners to create a progress bar, with a starting value, that is decreased by 1 after an iteration.
sub counter(:$start, :$dec, :$header = 'Caching files ' ) {
    state $hash-bar = Bar.new(:type<bar>);
    state $inc;
    state $done;
    if $start { # also fails if $start = 0
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
