#!/usr/bin/env raku
use v6.d;
unit class Build;
method build($dist-path) {
    my $git-run = run 'git', '--version', :out;
    my $git-return = $git-run.out.get;
    exit note "Can not continue without git" unless $git-return;
    my $released-dir = "$*HOME/.local/share/Collection";
    $released-dir = $_ with %*ENV<PluginPath>;
    if $released-dir.IO ~~ :e & :d {
        note "Released plugin directory exists at ｢$released-dir｣"
    }
    else {
        $released-dir.IO.mkdir;
        note "Released plugin directory created as ｢$released-dir｣";
    }
    if "$released-dir/.git".IO ~~ :e & :d {
        indir $released-dir, {
            run 'git', 'pull'
        }
    } else {
        run 'git', 'clone', 'https://github.com/finanalyst/collection-plugins', $released-dir;
    }
}