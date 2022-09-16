use v6.d;
use RakuConfig;

unit module Collection::RefreshPlugins;
#| the location of the released plugins (a github repo)
#| it can be changed when creating a plugin-conf file.
our $release-dir = "$*HOME/.local/share/Collection";

class NoModes is Exception {
    has $.collection;
    method message {
        "There are no Mode directories in ｢$!collection｣."
    }
}
class NoReleasedDir is Exception {
    has $.released-dir;
    method message {
        "｢$!released-dir｣ is not a valid Collection Released Plugins directory"
    }
}
#class BadPluginsConf is Exception {
#    has $!warning;
#    method message
#}
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
    my %plugins;
    try {
        %plugins = get-config(:path("$collection/plugins.rakuon"));
        CATCH {
            when RakuConfig::NoFiles {
                note("Creating ｢plugins.rakuon｣ in ｢$collection｣");
                %plugins = create-plugin-conf(:$collection, :$test);
                .resume
            }
            default {
                exit note("Trying to access ｢$collection/plugins.rakuon｣ but got " ~ .message)
            }
        }
    }
    # Collect a list of plugins that need attention
    # 1) plugins in required plugins without a sub-directory in '<mode>/plugins'
    # 2) plugins in plugins.conf
    my %plugins2b-processed;
    for %plugins.keys.grep({ !.match(/ 'FORMAT' /) }) -> $mode {
        my %config = get-config("$collection/$mode");
        # get unique plugin names from all milestones
        my SetHash $required .= new;
        $required.set($_.values) for %config<plugins-required>;
        my @existing-plugs = "$collection/$mode/plugins"
            .IO.dir(test => { .IO.d })
            .grep({ .match(/ ^ \w /) });
        %plugins2b-processed{ $mode } = $required (<=) @existing-plugs;
        # get from plugins.rakuon
        #### How to verify that that a plugin given by plugins.rakuon is linked properly????
    }
    # make links
}
our sub create-plugin-conf(:$collection, :$test --> Associative) {
    my %plugins;
    unless $test {
        my $resp = prompt "Is the released plugins ｢$release-dir｣ correct (Enter / New release directory)";
        $release-dir = $resp if $resp;
    }
    NoReleasedDir.new(:$release-dir).throw
    unless ($release-dir.IO ~~ :d)
        and ("$release-dir/manifest.rakuon".IO ~~ :e & :f);
    %plugins = :collection-plugin-root($release-dir), ;
    my @modes = $collection.IO.dir(test => { .IO.d }).grep({ .basename ~~ / ^ \w+ / });
    NoModes.new(:$collection).throw unless +@modes;
    for @modes -> $mode {
        my %config;
        try {
            %config = get-config("$collection/$mode", :required<plugin-format>);
            CATCH {
                default { exit note("Trying to access Mode ｢$collection/$mode｣ configuration, but got " ~ .message) }
            }
        }
        %plugins{~$mode}<FORMAT> = %config<plugin-format>
    }
    write-plugin-conf(%plugins, :$collection);
    %plugins
}
sub write-plugin-conf(%plugins, :$collection) {
    "$collection/plugins.rakuon".IO.spurt: format-config(%plugins)
}