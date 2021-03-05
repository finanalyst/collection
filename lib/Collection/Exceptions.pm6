use v6.*;

class X::Collection::NoSources is Exception {
    has $.path;
    method message {
        "No source files in $.path"
    }
}
class X::Collection::NoMode is Exception {
    has $.mode;
    method message {
        "Expecting a sub-directory $.mode, not found"
    }
}
class X::Collection::BadOption is Exception {
    has @.passed;
    has @.good-options = <no-status without-processing no-refresh recompile full-render no-report no-completion no-cleanup
            end debug-when verbose-when no-cache collection-info dump-at with-only>;
    method message {
        "Possible options are: { @.good-options.join(', ') }\nOptions passed were: {@.passed.join(', ')}"
    }
}
class X::Collection::Mandatory is Exception {
    has @.got;
    has @.required;
    method message {
        "A mandatory config option, eg. ({ @.required.join(',') }) is missing,\n"
            ~ "Actually got: " ~ @.got.join(',')
    }
}
class X::Collection::BadAssetDirectory is Exception {
    has $.dir;
    has $.basename;
    method message { "Expecting, but did not get, a directory with ｢$.basename｣ and part ｢$.dir｣" }
}
class X::Collection::BadAssetOutputDirectory is Exception {
    has $.directory;
    method message { "Expecting, but did not get, a directory with ｢$.directory｣" }
}