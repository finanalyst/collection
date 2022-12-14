# Changlog
>Changes in the Collection distribution


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
[2021-02-23 v0.3.1](#2021-02-23-v031)  
[2021-02-25 v0.3.2](#2021-02-25-v032)  
[2021-03-02 v0.3.3](#2021-03-02-v033)  
[2021-03-03 v0.3.4](#2021-03-03-v034)  
[2021-03-05 v0.3.5](#2021-03-05-v035)  
[2021-03-05 v0.3.6](#2021-03-05-v036)  
[2021-03-10 v0.3.7](#2021-03-10-v037)  
[2021-03-14 v0.4.0](#2021-03-14-v040)  
[2021-03-23 v0.4.1](#2021-03-23-v041)  
[2021-03-30 v0.4.2](#2021-03-30-v042)  
[2021-04-02 v0.5.0](#2021-04-02-v050)  
[2022-07-17 v.0.7.0](#2022-07-17-v070)  
[2022-07-22 v0.7.1](#2022-07-22-v071)  
[2022-07-24 v0.8.0](#2022-07-24-v080)  
[2022-07-29 v0.8.1](#2022-07-29-v081)  
[2022-08-03 v0.8.2](#2022-08-03-v082)  
[2022-08-11 v0.8.3](#2022-08-11-v083)  
[2022-08-22 v0.9.0](#2022-08-22-v090)  
[2022-09-07 v0.9.1](#2022-09-07-v091)  
[2022-10-30 v 0.10.0](#2022-10-30-v-0100)  
[2022-13-06 v0.10.1](#2022-13-06-v0101)  
[2022-13-06 v 0.11.0](#2022-13-06-v-0110)  
[2022-11-14 v0.11.1](#2022-11-14-v0111)  
[2022-11-15 v0.11.2](#2022-11-15-v0112)  
[2022-12-13 v0.12.0](#2022-12-13-v0120)  
[2022-12-14 v0.12.1](#2022-12-14-v0121)  

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

# 2021-02-23 v0.3.1
*  refactor to ensure that only changed files are re-rendered, but information of non-rendered files is cached

*  change the input type of completion plugin

# 2021-02-25 v0.3.2
*  add in a progress statement about rendered files in place of a spinner

*  correct error about where processed/symbol structures are stored.

# 2021-03-02 v0.3.3
*  META6 path changes to reflect repository name

# 2021-03-03 v0.3.4
*  Change of storing cache, using Libarchive.

*  Added timing information when !no-status

# 2021-03-05 v0.3.5
*  Added method add(fn,:alias) to Post-Cache role.

*  allows for the change in the name of the filename without affecting the underlying Cache

*  added tests & modified README

*  fixed output of timing information

# 2021-03-05 v0.3.6
*  Added :with-only<filename> that runs the whole of Collect but with only one file

*  added tests for :debug-when and :with-only

# 2021-03-10 v0.3.7
*  add backtrace to plugin error response.

# 2021-03-14 v0.4.0
*  remove %processed as input to completion plugin. Intermediate data not needed at completion. Hence it is not necessary to cache intermediate data except for rendering collection documents.

# 2021-03-23 v0.4.1
*  correct without-processing logic

# 2021-03-30 v0.4.2
*  add anti-alias method to Post-cache

*  remove trace statement

*  make it possible for a report plugin to return a Pair with '' key.

*  add asset-db method to return the whole database for analysis

# 2021-04-02 v0.5.0
*  enforce no-status (= quiet) and collection-info (= verbose) on plugins

*  change README (and some editing) to reflect this

*  change logic for rendering collection content when there is change to sources, but no change to collection

*  added date/time output when starting

*  change counter to put heading into state

# 2022-07-17 v.0.7.0
*  prepare for fez

*  change to github workflow testing

*  remove Docker implementation

*  refactor tests

	*  rename raku files, change tests to reflect this too

	*  test post-cache role separately

	*  add clean up test

	*  add preserve-state archive test

*  Refactor Post-cache Role

	*  rename methods to better reflect their actions,

	*  add inline documentation

*  rewrite README to only provide a reference to Raku-Documentation

*  add no-preserve-state option to prevent archiving if need be

# 2022-07-22 v0.7.1
*  move up test for without-processing so no checking of caches

*  revise no-preserve-state test.

# 2022-07-24 v0.8.0
*  revise report plugin spec so that one plugin can produce multiple report files

*  report plugin returns an Array of Pairs, not just a Pair

*  change test accordingly

*  revise post-cache documentation

*  change no-report & no-completion to without-* to be consistent with without-processing

*  remove no-cache, as its not in get-config

*  Revise milestone handling

*  collect process can be stopped before AND after each stage

*  change :end to :after to be compatible with :before

*  :after implies no plugins triggered for a milestone, before implies plugins triggered

*  dump-at implies plugins triggered

*  change tests to reflect new specifications

*  milestone information object includes plugins-used array of hashes

*  revise README documentation

# 2022-07-29 v0.8.1
*  Do not fail if plugin misspelt / doesnt exist

*  writes name to STDERR and continues

*  Ignore milestone if it is not a key 'plugins-required'

# 2022-08-03 v0.8.2
*  small changes in no-preserve-state and full render logic

*  remove preserve-state archive if it exists and if no-preserve-state

# 2022-08-11 v0.8.3
*  move some config logic to after mode config loaded

# 2022-08-22 v0.9.0
*  create transfer plugin type for transfer milestone

*  modify README about Transfer milestone

*  add tests for transfer plugins

*  error: Exceptions options made consistent with module.

*  changed config for test suite so that no-preserve-state is True

# 2022-09-07 v0.9.1
*  distinguish between 'plugin' and 'callable' at a milestone for that plugin.

*  remove references to Cleanup milestone, which was never used.

*  add a list of milestones towards the top.

*  add Collection::RefreshPlugins

*  add collection-refresh-plugins

*  remove **plugins** key for mode config (The ability to add arbitrary names was designed to allow for the multiple use of plugins. This specification has changed. Now plugins are released with semantic versioning, and plugins are released for each Major version. Updating is done via the plugins.conf file.

*  plugin-format is now added as a mandatory key for Mode configuration

*  honour no-status in preserve-state

*  finished refresh-plugins, finalised format for 'plugins.rakuon'

*  tests added

*  define Modes to be named like plugins without '_', thus allowing sub-directories within a collection not to be Modes, use-case, _local_raku_docs as a git repo.

*  change METADATA key in plugins.rakuon to _metadata_ to take advantage of this

*  include check for default released dir before asking for new one in Refresh

*  fixed the anomalous exit after git cloning

# 2022-10-30 v 0.10.0
*  review to ensure compliance with Render::Pod v 4

# 2022-13-06 v0.10.1
*  change to error report

*  minor change to xt/75*

*  improve error handling in Mode

*  make RefreshPlugin observe :no-refresh config option

# 2022-13-06 v 0.11.0
*  allow for plugin-specific config data to be contained in Mode configs, by generalising completion-options

*  change all plugin requirements to need %plugin-options

*  rename completion-options to plugin-options in Completion milestone

*  change the README to reflect this

*  fix all tests to comply with new plugin requirements

*  add a test to check this

*  allow for :no-refresh to be passed from CLI to sub refresh

*  make :no-refresh & without-processing & recompile to be mandatory Level-one options

# 2022-11-14 v0.11.1
*  change implementation of passing options to plugins.

	*  instead of passing a Hash to plugin callables, the data from the plugin's config is already stored in the data section, and so is available from the instance of ProcessedPod that is passed to each plugin (except for Completion plugins).

	*  when a plugin is added to the ProcessedPod instance, the Mode config data is checked and overides the plugin config keys, when needed.

*  change README & tests

*  add test to see whether a Mode configured plugin option is picked up

# 2022-11-15 v0.11.2
*  move add-plugin to top of plugin processing so that plugin config is available to render milestone callable

*  add test to ensure Mode config transferred to a render plugin

# 2022-12-13 v0.12.0
*  fix templates in tests to match Raku::Pod::Render v 4.2

*  allow for asset transfers from compilation callables if the return value is an array of triples.

# 2022-12-14 v0.12.1


*  make counter nicer with times over 1min.

*  fix call to counter in rendering section





----
Rendered from CHANGELOG at 2022-12-14T21:43:51Z