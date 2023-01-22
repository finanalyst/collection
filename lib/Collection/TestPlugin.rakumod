use v6.d;
use Test;
use RakuConfig;
use License::SPDX;
use Collection::Entities;

unit module Collection::TestPlugin;

# several subs are taken from Jonathan Stowe's Test::Meta module.
our $TESTING = False;

sub test-plugin is export {
    my %config;
    my @required = <name version auth license authors>;

    plan 11;

    like $*CWD.basename, / <plugin-name> /, 'plugin directory name matches naming rule';
    ok check-file('README.rakudoc'), 'README exists';
    if check-file('config.raku') {
        pass 'got ｢config.raku｣';
        lives-ok { %config = get-config(:@required) }, 'config exists with mandatory keys';
        bail-out('Could not get configuration') unless +%config.keys;
        ok check-name(%config), 'name is valid';
        ok check-license(%config), 'license confirmed';
        ok check-authors(%config), 'authors included';
        ok check-version(%config), 'plugin version acceptible';
        ok check-auth(%config), 'auth field looks fine';
        ok check-milestone(%config, :relaxed), 'milestone definition seems ok';
        ok check-otherkey(%config), 'other keys, if they exist, are consistent';
    }
    else
    {
        flunk 'no ｢config.raku｣';
        skip-rest 'no config file'
    }
    done-testing
}

sub my-diag(Str $mess) {
    diag $mess unless $TESTING;
}

our sub check-name(%config --> Bool) {
    with %config<name> {
        unless .match(/ <plugin-name> /) {
            my-diag("Plugin name ｢$_｣ is not a valid Collection plugin name");
            return False
        }
    }
    else {
        my-diag("No name field in config");
        return False
    }
    return True
}
our sub check-authors(%config --> Bool) {
    with %config<authors> {
        if .elems == 0 {
            my-diag "No authors are listed, there should be at least one.";
            return False
        }
    }
    else {
        my-diag("No authors field in config");
        return False
    }
    True
}

our sub check-license(%config --> Bool) {
    with %config<license> {
        my $licence-list = License::SPDX.new;
        my $licence = $licence-list.get-license(%config<license>);
        if !$licence.defined {
            if %config<license> eq any('NOASSERTION', 'NONE') {
                my-diag "NOTICE! License is %config<license>. This is valid, but licenses are prefered.";
                return True;
            }
            else {
                my-diag qq:to/END/;
                    license ‘%config<license>’ is not one of the standardized SPDX license identifiers.
                    please use use one of the identifiers from https://spdx.org/licenses/
                    END

                return False;
            }
        }
        elsif $licence.is-deprecated-license {
            my-diag qq:to/END/;
                the licence ‘%config<license>()’ is valid but deprecated, you may want to use another license.
                END

            return True
        }
    }
    else {
        my-diag("No license field in config");
        return False
    }
    True
}
our sub check-version(%config --> Bool) {
    with %config<version> {
        unless .match(/ ^ \d+ \. \d+ \. \d+ $ /) {
            my-diag('version must be in three parts dd.dd.dd but got '
                ~ %config<version>);
            return False
        }
    }
    else {
        my-diag("No version field in config");
        return False
    }
    True
}
our sub check-auth(%config --> Bool) {
    with %config<auth> {
        unless %config<auth> ~~ Str:D {
            my-diag("The auth key of the config must be a String");
            return False
        }
    }
    else {
        my-diag("No auth field in config");
        return False
    }
    True
}
our sub check-render-reqs(Str:D $component where *~~ one(<custom-raku template-raku>), %config --> Str ) {
    return "Plugin config must contain a ｢$component｣ key because it contains a ｢render｣ key."
        unless $component ~~ any(%config.keys);
    if %config{$component} !~~ Str:D {
        return qq:to/ERROR/ unless %config{$component} ~~ Empty;
            ｢config\< $component \>｣ should point to () or a string.
            Instead got ｢{ %config{$component}.raku }｣.
            ERROR
    }
    else {
        if %config{$component}.IO ~~ :e & :f {
            my $retval;
            try {
                $retval = EVALFILE %config{$component};
                CATCH {
                    default {
                        return qq:to/ERROR/;
                            ｢config\< $component \>｣ points to ｢{ %config{$component} }｣ which should run as a Raku program.
                            Instead got compiler exception ｢{ .message }｣
                            ERROR
                    }
                }
                if $component eq 'custom-raku' and $retval !~~ Positional {
                    return qq:to/ERROR/;
                        ｢config\< $component \>｣ points to ｢{ %config{$component} }｣ which should return an Array.
                        Instead got ｢{ $retval.raku }｣.
                        ERROR
                }
                if $component eq 'template-raku' and $retval !~~ Associative {
                    return qq:to/ERROR/;
                        ｢config\< $component \>｣ points to ｢{ %config{$component} }｣ which should return an Hash.
                        Instead got ｢{ $retval.raku }｣.
                        ERROR
                }
            }
        }
        else {
            return qq:to/ERROR/ unless %config<information>.defined and ($component ~~ any(%config<information>.list));
                ｢config\< $component \>｣ points to ｢{ %config{$component} }｣ which should be a file in the plugin directory
                Have you misspelt the filename, or missed out a \:information key?
                ERROR
        }
    }
    ''
}
our sub check-milestone(%config, Bool :$relaxed = False --> Bool) {
    my Bool $rc = True;
    # the valid milestones are:
    # setup must return a callable
    # render may exist as a Boolean, if has a filename then must return a callable
    # compilation must return a callable
    # transfer must return a callable
    # report must return a callable
    # completion must return a callable
    my @required = <setup render compilation transfer report completion>;
    # at least one must exist
    unless any(%config.keys) ~~ any(@required) {
        my-diag("The config file must contain one of the keys ｢{ @required.join('｣,｢') }｣");
        return False
    }
    for %config.keys.grep(any(@required)) {
        when 'render' {
            unless <custom-raku template-raku> (<) %config.keys {
                # uses Set semantics is left a subset of right
                my-diag(qq:to/ERROR/);
                    Config contains ｢:render｣ but does not contain both ｢:custom-raku｣ and ｢:template-raku｣
                    ERROR
                return False
            }
            my $err = check-render-reqs('custom-raku', %config);
            if $err {
                my-diag($err);
                return False
            }
            $err = check-render-reqs('template-raku', %config);
            if $err {
                my-diag($err);
                return False
            }
            next if %config<render> ~~ Bool;
            # render requisites met and render key should point to a file
            #     sub ( $pr, %options --> Array ) {...}
            $rc = check-callable($_, %config,
                / 'sub' \s+ \(
                \s* '$pr' \s* \,
                \s* '%options' \s*
                \s* '--> Array' \s*
                \) /, :$relaxed)
        }
        when 'setup' {
            # sub ( $source-cache, $mode-cache, Bool $full-render, $source-root, $mode-root, %options ) { ... }
            $rc = check-callable($_, %config,
                /'sub' \s+ \(
                \s* '$source-cache' \s* \,
                \s* '$mode-cache' \s* \,
                \s* 'Bool $full-render' \s* \, \s* '$source-root' \s* \,
                \s* '$mode-root' \s* \,
                \s* '%options' \s*
                \) /, :$relaxed);
        }
        when 'compilation' {
            # sub ( $pr, %processed, %options) { ... }
            $rc = check-callable($_, %config,
                /'sub' \s+ \(
                \s* '$pr' \s* \,
                \s* '%processed' \s* \,
                \s* '%options' \s*
                \) /, :$relaxed);
        }
        when 'transfer' {
            # sub ($pr, %processed, %options --> Array ) {...}
            $rc = check-callable($_, %config,
                /'sub' \s+ \(
                \s* '$pr' \s* \,
                \s* '%processed' \s* \,
                \s* '%options' \s*
                \s* '--> Array' \s*
                \) /, :$relaxed);
        }
        when 'report' {
            # sub (%processed, @plugins-used, $pr, %options --> Array ) {...}
            $rc = check-callable($_, %config,
                /'sub' \s+ \(
                \s* '%processed' \s* \,
                \s* '@plugins-used' \s* \,
                \s* '$pr' \s* \,
                \s* '%options' \s*
                \s* '--> Array' \s*
                \) /, :$relaxed);
        }
        when 'completion' {
            # sub ($destination, $landing-place, $output-ext, %completion-options, %options) {...}
            $rc = check-callable($_, %config,
                /'sub' \s+ \(
                \s* '$destination' \s* \,
                \s* '$landing-place' \s* \,
                \s* '$output-ext' \s* \,
                \s* '%completion-options' \s* \,
                \s* '%options' \s*
                \) /, :$relaxed);
        }
    }
    $rc
}
our sub check-callable($key, %config, $regex, Bool :$relaxed) {
    my $rc = check-file(%config{$key}, :extra("in key ｢$key｣"));
    return False unless $rc;
    my $call;
    try {
        $call = EVALFILE %config{$key};
        CATCH {
            default {
                my-diag(qq:to/ERROR/);
                ｢config\< $key \>｣ points to ｢{ %config{$key} }｣ which should run as a Raku program.
                Instead got compiler exception ｢{ .message }｣
                ERROR

                return False
            }
        }
    }
    unless $call ~~ Callable {
        my-diag("｢config\< $key \>｣ points to ｢{ %config{$key} }｣ which does not evaluate to a callable");
        return False
    }
    return True if $relaxed;
    # look in file for sub definition line
    $rc = False;
    for %config{$key}.IO.lines {
        ($rc = True and last) if .match($regex);
        LAST {
            unless $rc {
                my-diag(qq:to/ERROR/);
                ｢config\< $key \>｣ points to ｢{ %config{$key} }｣ which should contain a line matching ｢{ $regex.raku }｣.
                If the callable uses a different naming convention, call check-plugin with ｢:relaxed｣.
                ERROR

            }
        }
    }
    $rc
}
our sub check-otherkey(%config --> Bool) {
    my Bool $rc = True;
    my @specified = <
        setup render compilation transfer report completion
        name version auth authors license
        custom-raku template-raku information
    >;
    for %config.keys.grep(none(@specified)) {
        next if %config<information> and $_ ~~ any(%config<information>.list);
        $rc &&= check-file(%config{$_}, :extra("in key ｢$_｣"));
    }
    $rc
}
our sub check-file($fn, :$extra = '' --> Bool) {
    unless $fn ~~ Str:D and $fn {
        my-diag("Filename $extra must be Str, but got { $fn.raku }");
        return False
    }
    return True if ($fn.IO ~~ :e & :f);
    my-diag("a file called ｢$fn｣ { $extra ?? "($extra) " !! '' }is expected in the directory");
    return False
}

