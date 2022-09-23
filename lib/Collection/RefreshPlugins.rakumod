use v6.d;
use RakuConfig;
use Collection::Entities;
use File::Directory::Tree;

unit module Collection::RefreshPlugins;

class NoModes is Exception {
    has $.collection;
    method message {
        "There are no Mode directories in ｢$!collection｣."
    }
}
class NoReleasedDir is Exception {
    has $.release-dir;
    method message {
        "｢$!release-dir｣ is not a valid Collection Released Plugins directory"
    }
}
class GitFail is Exception {
    has $.err;
    method message {
        "Failed to run ｢git pull｣, got ", $.err
    }
}
class MapFail is Exception {
    has $.note;
    method message {
        $.note
    }
}

our proto sub refresh(|) {*}

multi sub refresh(Str:D :$collections!, Bool :$test = False) is export {
    for $collections.split(/\s+ | \,/) {
        if .IO.d {
            say "processing Collection at ｢$_｣" unless $test;
            refresh(:collection($_), :$test)
        }
        else {
            note "｢$_｣ is not a directory"
        }
    }
}
multi sub refresh(Str:D :$collection = $*CWD.Str, Bool :$test = False) is export {
    state Bool $git-pull = True;
    my %plugins;
    try {
        %plugins = get-config(:path("$collection/plugins.rakuon"));
        CATCH {
            when RakuConfig::NoFiles {
                note("Creating ｢plugins.rakuon｣ in ｢$collection｣") unless $test;
                %plugins = create-plugin-conf(:$collection, :$test);
            }
            default {
                .rethrow;
                #exit note("Trying to access ｢$collection/plugins.rakuon｣ but got " ~ .message)
            }
        }
    }
    $release-dir = %plugins<_metadata_><collection-plugin-root>;
    # git actions disabled when testing and on first run
    if !$test and $git-pull {
        my $proc = run('git', '-C', $release-dir, 'pull', '-q', :err);
        my $err = $proc.err.slurp(:close);
        GitFail.new(:$err).throw if $err;
        $git-pull = False;
    }
    my %released = analyse-manifest;
    for %plugins.keys.grep({ .match(/ ^ <plugin-name> $ /) }) -> $mode {
        my %config = get-config("$collection/$mode");
        # get unique plugin names from all milestones
        my @required = (gather for %config<plugins-required>.values { take .list.Slip }).unique;
        my $format = %config<plugin-format>;
        for @required -> $plug {
            with %plugins{$mode}{$plug} {
                my $n-plug = %plugins{$mode}{$plug}<name> // $plug;
                my $n-auth = %plugins{$mode}{$plug}<auth> // 'collection';
                MapFail.new(:note(qq:to/WARN/)).throw unless %released{$format}{$n-plug}{$n-auth};
                    Auth error? No released plugin ｢$n-plug｣_v?_auth_｢$n-auth｣ for ｢$plug｣ in ｢$mode｣
                        If a 'name' key is set in 'plugins.rakuon', has the 'auth' key been set too?
                    WARN

                my $n-v = %plugins{$mode}{$n-plug}<major>
                    // %released{$format}{$n-plug}{$n-auth}<latest>;
                MapFail.new(:note(qq:to/WARN/)).throw unless ($n-v ~~ any(%released{$format}{$n-plug}{$n-auth}<vers>.list));
                    Major part error? No released plugin ｢{ $n-plug }_v{ $n-v }_auth_{ $n-auth }｣ corresponding to ｢$plug｣ in ｢$mode｣
                    WARN

                next if ?(%plugins{$mode}{$plug}<mapped>)
                    and (%plugins{$mode}{$plug}<mapped> eq "{ $n-plug }_v{ $n-v }_auth_$n-auth");
                # Here is where code would be needed for notifying about an update
                %plugins{$mode}{$plug}<mapped> = "{ $n-plug }_v{ $n-v }_auth_$n-auth"
            }
            else {
                # no plugin, so not yet mapped, so there will not be a plugin config
                # no constraint so use default
                %plugins{$mode}{$plug}<mapped> =
                    $plug ~ '_v' ~ %released{$format}{$plug}<collection><latest> ~ '_auth_collection';
            }
            mktree("$collection/$mode/plugins") unless "$collection/$mode/plugins/".IO ~~ :e & :d;
            my $p-ref = "$collection/$mode/plugins/$plug";
            say "Mapping ｢$plug｣ to ｢{ %plugins{$mode}{$plug}<mapped> }｣" unless $test;
            $p-ref.IO.unlink if $p-ref.IO ~~ :e;
            "$release-dir/plugins/{ $format }/{ %plugins{$mode}{$plug}<mapped> }".IO
                .symlink($p-ref);
        }
    }
    write-plugin-conf(%plugins, :$collection)
}
our sub analyse-manifest(--> Associative) {
    my %manifest = get-config(:path("$release-dir/manifest.rakuon"));
    my %released = %manifest<plugins>.map({ .key => %() });
    for %released.keys -> $format {
        for %manifest<plugins>{$format}.keys -> $rp {
            if $rp ~~ / <plugin-name> '_v' $<v> = (\d+) '_auth_' $<auth> = (.+) $ / {
                my ($p, $v, $a) = ~$<plugin-name>, +$<v>, ~$<auth>;
                with %released{$format}{$p} {
                    if $a (elem) $_<auths> {
                        $_{$a}<vers>.append: $v;
                        $_{$a}<latest> = $_{$a}<vers>.max
                    }
                    else {
                        $_<auths>.set($a);
                        $_{$a}<vers> = [$v];
                        $_{$a}<latest> = $v
                    }
                }
                else {
                    %released{$format}{$p} = %(
                        auths => SetHash.new($a),
                        $a => %(
                            vers => [$v],
                            latest => $v
                        ),
                    )
                }
            }
        }
    }
    %released
}

our sub create-plugin-conf(:$collection, :$test --> Associative) {
    my %plugins;
    # test for existence of default released dir
    unless ($release-dir.IO ~~ :d)
        and ("$release-dir/manifest.rakuon".IO ~~ :e & :f) {
        # no released dir found, so ask for a customised one, unless testing
        if $test {
            NoReleasedDir.new(:$release-dir).throw
        }
        else {
            until ($release-dir.IO ~~ :d) and ("$release-dir/manifest.rakuon".IO ~~ :e & :f) {
                $release-dir = prompt(qq:to/PROMPT/);
                    ｢$release-dir｣ is not a Collection released plugin directory.
                    Enter Custom release directory, or Enter to end program.
                    PROMPT
                NoReleasedDir.new(:release-dir('None given')).throw unless $release-dir;
            }
        }
    }
    %plugins = %(
        :_metadata_(%(
            :collection-plugin-root($release-dir),
            :update-behaviour<auto>,
            # other value is forced

        )),
    );
    my @modes = $collection.IO.dir.grep({ .d && .basename ~~ / ^ <plugin-name> $ / });
    NoModes.new(:$collection).throw unless +@modes;
    for @modes -> $mode {
        my %config = get-config(~$mode, :required('plugin-format',));
        %plugins{$mode.basename}<_mode_format> = %config<plugin-format>
    }
    write-plugin-conf(%plugins, :$collection);
    %plugins
}
sub write-plugin-conf(%plugins, :$collection) {
    "$collection/plugins.rakuon".IO.spurt: format-config(%plugins)
}