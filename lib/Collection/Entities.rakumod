use v6.d;
unit module Entities;

our $release-dir is export = "$*HOME/.local/share/Collection";
our %collection-defaults is export = %(
    :version<0.1.0>,
    :auth<collection>,
    :authors('finanalyst',),
    :license('Artistic-2.0'),
);
my token plugin-name is export {
    <.alpha> <[\w] + [\-] - [\_]>+
};
