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
[2021-02-04](#2021-02-04)  
[2021-02-05](#2021-02-05)  
[2021-02-06](#2021-02-06)  
[2021-02-08](#2021-02-08)  
[2021-02-10 v0.1.9](#2021-02-10-v019)  
[2021-02-14 v0.1.10](#2021-02-14-v0110)  
[2021-02-18 v0.2.0](#2021-02-18-v020)  
[Bead1](#bead1)  
[2021-02-20 v0.2.2](#2021-02-20-v022)  
[2021-02-22 v0.3.0](#2021-02-22-v030)  

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

*  ensure that plugins are called in the order specified. manage-plugins uses an array of pairs, not a Hash

# 2021-02-04
*  add dump-at functionality

*  addd test of dump-at

# 2021-02-05
*  improve min-templates

# 2021-02-06
*  added cro-run plugin, added %config<completion-options> to completion plugin signature.

# 2021-02-08
*  remove dependency on PrettyDump

*  add updater script for Containerising Collection.

# 2021-02-10 v0.1.9
*  add to description of Configuration

*  enforce action of without processing on caches

# 2021-02-14 v0.1.10
*  getting without processing logic right.

# 2021-02-18 v0.2.0
*  added functionality for storage and processing of non-Pod6 content files

*  added tests of functionality, tests passing.

# bead1

2021-02-19 v0.2.1

*  mode level control options in config should be enforced

*  extra test in report completion

# 2021-02-20 v0.2.2
*  make sure asset output paths synchronise

*  add new debug-when/verbose-when options to command-line check

# 2021-02-22 v0.3.0


*  changed the return value from a render plugin to a list of triples, not a list of pairs

*  changed the tests accordingly





----
Rendered from CHANGELOG at 2021-02-22T19:06:00Z