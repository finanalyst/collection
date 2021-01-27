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
            end debug verbose no-cache>;
    method message {
        "Possible options are: { @.good-options.join(', ') }\nOptions passed were: {@.passed.join(', ')}"
    }
}