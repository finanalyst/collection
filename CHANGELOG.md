# Changlog

----
----
## Table of Contents
[2021-01-22 Collection spun out of Raku-Alt-Documentation](#2021-01-22-collection-spun-out-of-raku-alt-documentation)  
[2021-01-24 Adding tests](#2021-01-24-adding-tests)  
[2021-01-27 Redesign](#2021-01-27-redesign)  
[2021-01-31](#2021-01-31)  
[2021-02-02](#2021-02-02)  
[2021-02-3](#2021-02-3)  

----
# 2021-01-22 Collection spun out of Raku-Alt-Documentation
*  this had been planned.

*  tests are needed for Collection.pm6

# 2021-01-24 Adding tests
*  t/01-sanity only has use-ok

*  meta-ok in xt

*  other tests

# 2021-01-27 Redesign
*  plugin management made constistent

*  rewritten README to include new design

*  test written for process upto milestone pre-render, passing

*  Exceptions spun into separate file

# 2021-01-31
*  Compilation milestone adds plugins to convert collected data into compiled data.

*  All tests working

*  API mostly complete

*  TODO add a sorting key to config where the order of the files to be completed is important.

# 2021-02-02
*  extra test in compilation, routine plugin

*  changes needed after Pod::Render refactoring

*  now render will also call a program with $pr, this is so that it can interogate the config files of other plugins to see if they provide css, scripts, etc, as these need to be included in files to be included in a template.

# 2021-02-3


*  add mode-name key to ProcessedPod object

*  defined functionality of the return value of a render closure.

*  ensure that plugins are colled in the order specified. manage-plugins uses an array of pairs, not a Hash





----
Rendered from CHANGELOG at 2021-02-04T13:19:59Z