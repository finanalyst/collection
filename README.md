![github-tests-passing-badge](https://github.com/finanalyst/collection/actions/workflows/test.yaml/badge.svg)
# Raku Collection Module
>
> **Description** A subroutine to collect content files written in Rakudoc (aka POD6). A distinction is made between the Rakudoc files for the main content (sources) and the Rakudoc files that describe the whole collection of sources (mode-sources), eg. the landing page (index.html) of a website, or the Contents page of the same sources in book form. The collection process is in stages at the start of which plugins (Raku programs) can be added that transform intermediate data or add templates, or add new Pod::Blocks for the rendering.

> **Author** Richard Hainsworth aka finanalyst


----
## Table of Contents
[Installation](#installation)  
[Usage](#usage)  
[Life cycle of processing](#life-cycle-of-processing)  
[Milestones](#milestones)  
[Stopping or dumping information at milestones](#stopping-or-dumping-information-at-milestones)  
[Source Milestone](#source-milestone)  
[Mode Milestone](#mode-milestone)  
[Setup Milestone](#setup-milestone)  
[Render Milestone](#render-milestone)  
[Compilation Milestone](#compilation-milestone)  
[Transfer Milestone](#transfer-milestone)  
[Report Milestone](#report-milestone)  
[Completion Milestone](#completion-milestone)  
[Cleanup Milestone](#cleanup-milestone)  
[Collection Structure](#collection-structure)  
[Collection Content](#collection-content)  
[Extra assets (images, videos, etc)](#extra-assets-images-videos-etc)  
[Cache](#cache)  
[Mode](#mode)  
[Templates](#templates)  
[Configuration](#configuration)  
[Top level configuration](#top-level-configuration)  
[Second-level configuration](#second-level-configuration)  
[Control flags](#control-flags)  
[Plugin management](#plugin-management)  
[Disabling a plugin](#disabling-a-plugin)  
[Plugin types](#plugin-types)  
[Setup](#setup)  
[Render](#render)  
[Compilation](#compilation)  
[Transfer](#transfer)  
[Report](#report)  
[Completion](#completion)  
[Problems and TODO items](#problems-and-todo-items)  
[Archiving and Minor Changes](#archiving-and-minor-changes)  
[Plugin development](#plugin-development)  
[Dump file formatting](#dump-file-formatting)  
[Post-cache methods](#post-cache-methods)  
[multi method add(Str $fn, Array $p --&gt; Pod::From::Cache )](#multi-method-addstr-fn-array-p----podfromcache-)  
[multi method mask(Str $fn --&gt; Pod::From::Cache)](#multi-method-maskstr-fn----podfromcache)  
[multi method add-alias(Str $fn, Str :alias! --&gt; Pod::From::Cache)](#multi-method-add-aliasstr-fn-str-alias----podfromcache)  
[method behind-alias(Str $fn --&gt; Str )](#method-behind-aliasstr-fn----str-)  
[method pod(Str $fn)](#method-podstr-fn)  
[Asset-cache methods](#asset-cache-methods)  
[Copyright and License](#copyright-and-license)  

----
This module is used by Collection-Raku-Documentation, but is intended to be more general, such as building a blog site.

# Installation
```
zef install Collection
```
# Usage
The Collection module expects there to be a `config.raku `file in the root of the collection, which provides information about how to obtain the content (Pod6/rakudoc> sources, a default Mode to render and output the collection. All the configuration, template, and plugin files described below are **Raku** programs that evaluate to a Hash. They are described in the documentation for the `RakuConfig` module.

A concrete example of `Collection` is the [Collection-Raku-Documentation (CRD)](https://github.com/finanalyst/collection-raku-documentation.git) module. _CRD_ contains a large number of plugins (see below). Some plugin examples are constructed for the extended tests. Since the test examples files are deleted by the final test, try:

```
prove6 -I. xt/1* xt/2* xt/3* xt/4* xt/5*
```
and then look at `xt/test-dir`.

The main subroutine is `collect`. It requires a file `config.raku` to be in the `$CWD` (current working directory). In _CRD_ the executable `Raku-Doc` initiates the collection by setting up sources and installing a `config.raku` file. It is then simply a command line interface to `collect`.

# Life cycle of processing
The content files are processed in several stages separated by milestones. At each milestone, intermediary data can be processed using plugins, the data after the plugins can be dumped, or the processed halted.

`collect` can be called with option flags, which have the same effect as configuration options. The run-time values of the [Control flags](Control flags.md) take precedence over the configuration options.

`collect` should be called with a [Mode](Mode.md). A **Mode** is the name of a set of configuration files, templates, and plugins that control the way the source files are processed and rendered. The main configuration file must contain a key called `mode`, which defines the default mode that `collect` uses if called with no explicit mode, so if `collect` is called without a **Mode**, the default will be used.

# Milestones
The `collect` sub can be called once the collection directory contains a `config.raku`, which in turn contains the location of a directory of rakudoc source files, which must contain recursively at least one source.

Processing occurs during a stage named by the milestone which starts it. Each stage is affected by a set of [Control flags](Control flags.md). Certain flags will be passed to the underlying objects, eg. `RakuConfig` and `ProcessedPod` (see `Raku::Pod::Render`).

Plugins may be called at each milestone (except 'Source' and 'Mode', where they are not defined). Plugins are described in more detail in [Plugin management](Plugin management.md). Plugins are milestone specific, with the call parameters and return values depending on the milestone.

## Stopping or dumping information at milestones
Intermediate data can be dumped at the milestone **without stopping** the processing, eg.,

```
collect(:dump-at<source render>);
```
Alternatively, the processing can be **stopped** and intermediate data inspected, EITHER after the stage has run, but before the plugins for the next stage have been triggered, eg.,

```
my $rv = collect(:after<setup>);
```
OR after the previous stage has run and after the plugins for the milestone have been triggered, eg.,

```
my $rv = collect(:before<render>);
```
The return value `$rv` is an array of the objects provided to plugins at that milestone, and an array of the plugins triggered (note the plugins used will be a difference between the `:before` and `:after` stop points). The plugins-used array is not provided to all plugins, except at the Report milestone.

The return value `$rv` at `:after` will contain the object provided by the milestone after the named milestone. For example, milestone milestone 'Setup' is followed by milestone 'Render'. The return object for `:after<setup>` will be the return object for milestone 'Render'. See Milestones for more information.

The object returned by `:before<render>` may be affected by the plugins that are triggered before the named stage.

The `:before`, `:after` and `:dump-at` option values are the (case-insensitive) name(s) of the inspection point for the milestone. `:before` and `:after` only take one name, but `:dump-at` may take one or all of them in a space-delimited unordered list.

The `dump-at` option calls `.raku` [TODO pretty-dump, when it handles BagHash and classes] on the same objects as above and then outputs them to a file(s) called `dump-at-<milestone name>.txt`.

## Source Milestone
(Skipped if the `:without-processing` flag is True)

Since this is the start of the processing, no plugins are defined as there are no objects for them to operate on.

The `config.raku` file must exist and must contain a minimum set of keys. It may optionally contain keys for the control flags that control the stage, see below. The intent is to keep the options for the root configuration file as small as possible and only refer to the source files. Most other options are configured by the Mode.

During the subsequent **Source** stage, the source files in the collection are brought in, if the collection has not been fully initiated, using the `source-obtain` configaturation list. Alternatively, any updates are brought in using the `source-refresh` list. Commonly, sources will be in a _git_ repository, which has separate commands for `clone` and `pull`. If the `source-obtain` and `source-refresh` options are not given (for example during a test), no changes will be made to the source directory.

Any changes to the source files are cached by default.

The control flags for this stage are:

*  **no-refresh** (default False)

Prevents source file updates from being brought in.

*  **recompile**

Forces all the source files to be recompiled into the cache.

## Mode Milestone
(Skipped if the `:without-processing` flag is True)

Collection makes a distinction between Rakudoc source files that are the main content, and the source files needed to integrate the main content into a whole. The integration sources will differ according to the final output. For example, a book may have a Foreward, a Contents, a Glossary, etc, whilst a website will have a landing page (eg., _index.html_), and perhaps other index pages for subsections. A book may also organise content into sections that depend on metadata in the source files. A book will have a defined order of sections, but a website has no order. A website will require CSS files and perhaps jQuery scripts to be associated with Blocks. A book will have different formating requirements for pages.

These differences are contained in the **mode** configuration, and the plugins and templates for the mode.

At this milestone, the source files have been cached. The **mode** sub-directory has not been tested, and the configuration for the mode has not been used. Since plugin management is dependent on the mode configuration, no plugins can be called.

The **return value** of `collect` with `:after<source>` is a single `Pod::From::Cache` object that does a `Post-Cache` role (see below for `Post-Cache` methods).

A `Pod::From::Cache` object provides a list of updated files, and a full set of source files. It will provide a list of Pod::Blocks contained in each content files, using the filename as the key.

During the stage the source files for the Mode are obtained, compiled and cached. The process is controlled by the same options as the _Source_ stage. For example, the **Mode** for `Collection-Raku-Documentation` is _Website_.

If a sub-directory with the same name as _mode_ does not exist, or there are no config files in the `<mode>/config` directory, `collect` will throw an `X::Collection::NoMode` exception at the start of the stage.

Mode source files are stored under the mode sub-directory and cached there. If the mode source files are stored remotely and updated independently of the collection, then the `mode-obtain` and `mode-refresh` keys are used.

## Setup Milestone
(Skipped if the `:without-processing` flag is True)

If **setup** plugins are defined and in the mode's plugins-required<setup> list, then the cache objects for the sources and the mode's sources (and the **full-render** value) are passed to the program defined by the plugin's **setup** key.

The purpose of this milestone is to allow for content files to be pre-processed, perhaps to creates several sub-files from one big file, or to combine files in some way, or to gather information for a search algorithm.

During the setup stage,

*  the `ProcessedPod` object is prepared,

*  templates specified in the `templates` directory are added

*  the key **mode-name** is added to the `ProcessedPod` object's plugin-data area and given the value of the mode.

The Setup stage depends on the following options:

*  **full-render**

By default, only files that are changed are re-rendered, which includes an assumption that if any source file is changed, then all the **mode** sources must be re-rendered as well. (See the Problems section below for a caveat.)

When **full-render** is True, the output directory is emptied of content, forcing all files to be rendered.

**full-render** may be combined with **no-refresh**, for example when templates or plugins are changed and the aim is to see what effect they have on exactly the same sources. In such a case, the cache will not be changed, but the cache object will not contain any files generated by **setup** plugins.

## Render Milestone
(Skipped if the `:without-processing` flag is True)

At this milestone `render` plugins are supplied to the `ProcessedPod` object. New Pod::Blocks can be defined, and the templates associated with them can be created.

The source files (by default only those that have been changed) are rendered. 

The stage is controlled by the same options as _Setup_.

## Compilation Milestone
(Skipped if the `:without-processing` flag is True)

At this milestone plugins are provided to add compiled data to the `ProcessedPod` object, so that the sources in the mode's directory can function.

During the **Render** stage, the `%processed` hash is constructed whose keys are the filenames of the output files, and whose values are a hash of the page components of each page.

The `compilation` plugins could, eg, collect page component data (eg., Table of Contents, Glossaries, Footnotes), and write them into the `ProcessedPod` object separately so there is a TOC, Glossary, etc structure whose keys are filenames.

The return value of `collect` at the inspection point is a list of `ProcessedPod`, `%process`, with the `ProcessedPod` already changed by the `compilation` plugins.

## Transfer Milestone
(Skipped if the `:without-processing` flag is True)

Plugins may refer to assets provided by a distribution. This is the stage to ensure they are referenced so that they are moved from the distribution directory to the output directory from which they are used at the completion stage.

## Report Milestone
(Skipped if the `:without-processing` flag is True)

Once a collection has been rendered, all the links between files, and to outside targets can be subjected to tests. It is also possible to subject all the rendered files to tests. This is accomplished using `report` plugins.

In addition, all the plugins that have been used at each stage (except for the Report stage itself) are listed. The aim is to provide information for debugging.

The report stage is intended for testing the outputs and producing reports on the tests.

## Completion Milestone
Once the collection has been tested, it can be activated. For example, a collection could be processed into a book, or a `Cro` App run that makes the rendered files available on a browser. This is done using `completion` plugins.

The **without-completion** option allows for the completion phase to be skipped.

Setting **without-processing** to True and **without-completion** to True should have no effect unless

*  there are no caches, which will be the case the first time `collect` is run

*  the destination directory is missing, which will be the case the first time `collect` is run

## Cleanup Milestone
Cleanup comes after `collect` has finished, so is not a part of `collect`.

Currently, `collect` just returns with the value of the @plugins-used object.

[This API may change if a use is found for Cleanup]

# Collection Structure
A distribution contains content files, which may be updated on a regular basis, a cache, templates, extra assets referenced in a content file (such as images), and one or more modes.

## Collection Content
The content of the distribution is contained in **rakudoc** files. In addition to the source files, there are Collection content files which express things like the Table of Contents for the whole collection.

Collection content are held separately to the source content, so that each mode may have different pages.

This allows for active search pages for a Website, not needed for an epub, or publisher data for an output formation that will be printed.

## Extra assets (images, videos, etc)
Assets such as images, which are directly referenced in content file, but exist in different formats, eg, png, are held apart from content Pod6 files, but are processed with content files.

The reasoning for this design is that Pod6 files are compiled and cached in a manner that does not suit image files. But when an image file is processed for inclusion in a content file, the image may need to be processed by the template (eg., image effects specified in a Pod Block config).

The assets are all held in the same directory, specified by the configuration key `asset-basenamme`, but each asset may exist in subdirectories for each type of asset, specified by the `asset-paths` key.

(Asset files relating to the rendering of a content file, such as css, javascript, etc, are managed by plugins, see below for more on plugins.)

A class to manage asset files is added to the `ProcessedPod` object with a role, so the assets can be manipulated by plugins and templates. Assets that are in fact used by a Pod content file are marked as used. The aim of this functionality is to allow for report-stage plugins to detect whether all images have been used.

Plugins can also transform the assets, and create new files in the ProcessedPod object for inclusion in the output.

At the end of the compilation stage, all the assets that have been used are written to a directory specified in the Mode configuration file. It is the task of the template rendering block to ensure that the path where the asset is stored is the same as the path the final output (eg. the browser rendering html files) processor requests.

In keeping with the principle that collection level meta data is kept in the top-level config file, and output data is associated with the specific mode, there are two asset-path definitions.

*  Collection level assets. The source of assets is kept in the top-level `config.raku` file. In order to have each asset in its own directory, the following is possible:

```
...
:asset-basename<assets>,
asset-paths => %(
    image => %(
        :directory<images>,
        :extensions<png jpeg jpeg svg>,
    ),
    video-clips => %(
        :directory<videos>,
        :extensions<mp4 webm>,
    ),
),
...
```
Notice that the `type`, eg. _image_ and _video-clips_ above, are arbitrary and not dependent on the actual format.

*  Output configuration. The output destination is kept in the mode configuration, eg., `Website/configs/03-images.raku` contains

```
%(
    :asset-out-path<html/assets>
    ),
)
```
For more see [Asset-cache methods](Asset-cache methods.md)

## Cache
The **cache** is a Precomp structure into which the content files are pre-preprocessed.

## Mode
The **Mode** is the collection of templates and configuration for some output. A collection may contain multiple Modes, each in their own subdirectory.

The default Mode for **Collection-Raku-Documentation** is **Website**, for example.

The string defining `mode` must refer to an immediate directory of the root of the collection, so it is compared to `/ ^ \W+ (\w+) '/'? .* $ /` and only the inner `\w` chars are used.

The templates, configuration, output files, and other assets used by a Mode are associated with the Mode, and should reside beneath the Mode sub-directory.

## Templates
The **templates**, which may be any format (currently RakuClosure or Mustache) accepted by `ProcessedPod`, define how the following are expressed in the output:

*  the elements of the content files, eg. paragraphs, headers

*  the files as entities, eg, whether as single files, or chapters of a book

*  the collective components of content files, viz, Table of Contents, footnotes, Glossary, Meta data

*  All the templates may be in one file, or distributed between files.

	*  If there are no templates in the directory, the default files in `ProcessedPod` are used.

	*  If there are multiple files in the directory, they will all be evaluated in alphanumeric order. Note that existing keys will be over-written if they exist in later templates. This is **not** the same behaviour as for Configuration files.

# Configuration
There are two levels of configuration. The top-level resides in `config.raku` in the root directory of the Collection. The `collect` sub will fail without this file.

## Top level configuration
In the descriptions below, simple illustrative names are given to files with configuration, templates, callables. These files are generally **Raku** programs, which are compiled and run. They will almost certainly contain errors during development and the **Rakudo** compiler will provide information based on the filename. So it is good practice to name the files that make them easier to locate, such as prefixing them with the plugin name.

`config.raku` **must** contain the following keys:

*  the **cache** directory, relative to the root directory of the collection

	*  `Collection-Raku-Documentation` default: 'doc-cache',

*  the **sources** directory, relative to the root of the collection and must contain at least one content file

	*  `Collection-Raku-Documentation` default: 'raku-docs'

*  **mode** is the default mode for the collection, and must be a sub-directory, which must exist and contain a `configs` sub-directory (note the plural ending).

	*  `Collection-Raku-Documentation` default: 'Website'

The following are optional keys, together with the defaults 

*  the allowed **extensions** for content files. These are provided to the `Pod::From::Cache` object.

	*  default: < rakudoc pod pod6 p6 pm pm6 >

*  no-status This option controls whether a progress bar is provided in the terminal

	*  default: False

*  **source-obtain** is the array of strings sent to the OS by `run` to obtain sources, eg git clone and assumes CWD is set to the directory of collection. Without this key, there must already be files in `sources`.

	*  default: ()

*  **source-refresh** is the array of strings run to refresh the sources, assumes CWD set to the directory of sources. No key assumes the sources never change.

	*  default: ()

*  **ignore** is a list of files in the **sources** directory that are not cached.

	*  default: ()

*  **no-status** as described in Milestones

	*  default: False

*  **without-processing** as described in Milestones

	*  default: False

*  **no-refresh** as described in Milestones

	*  default: False

*  **recompile** as described in Milestones

	*  default: False

## Second-level configuration
The second-level configuration resides in one or more **files** that are under the **configs/** sub-directory of the `mode` directory. This arrangement is used to allow for configuration to be separated into different named files for ease of management.

The following rules apply:

*  If the **configs** directory for a mode does not exist or is empty, **Raku-Doc** (`collect` sub) will fail.

*  The Configuration consists of one or more `Raku` files that each evaluate to a hash.

	*  Each Config file in the **Configs** directory will be evaluated in alphabetical order.

	*  Configuration keys may not be over-written. An `X::RakuConfig::OverwriteKey` exception will be thrown if an attempt is made to redefine a key.

All the following keys are mandatory. Where a key refers to a directory (path), it should normally be relative to the `mode` sub-directory.

*  **mode-sources** location of the source files for the Collection pages, eg., TOC.

*  **mode-cache** location of the cache files

*  the **templates** subdirectory, which must contain raku files as described in `ProcessedPod`. These are all passed at the **Render** milestone directly to the `ProcessedPod` object.

*  **destination** directory where the output files are rendered

*  **plugins** is a string with the location of the plugins directory, either relative to root of the mode directory, or an absolute path. It is possible for the plugins directory to contain unused plugins. See [Plugin management](Plugin management.md)

*  **report-path** is the path to which `report` plugins should output their reports.

*  **plugins-required** points to a hash whose keys are milestone names where plugins can be applied

	*  **setup** a list of plugin names, see [Plugin management](Plugin management.md), for pre-processing cache contents

	*  **render** plugins used to render Pod::Blocks

	*  **compilation** plugins prepare the `ProcessedPod` object for collection pages.

	*  **assets** plugins that mark assets created in previous milestones

	*  **report** plugins to test and report on the rendering process

	*  **completion** plugins that define what happens after rendering

	*  **cleanup** plugins if cleanup is needed.

*  **landing-place** is the name of the file that comes first during the completion stage. For example, in a Website, the landing file is usually called `index.html`

*  **output-ext** is the extension for the output files

All optional control flags are False by default. They are:

*  no-status

*  recompile

*  no-refresh

*  full-render

*  without-completion

*  without-report

*  without-processing

*  no-preserved-state

*  debug-when

*  verbose-when

*  no-code-escape

# Control flags
The control flags are also covered in [Milestones](Milestones.md). Control flags by default are False.

*  **no-status**

No progress status is output at any time.

*  **without-processing**

Setting **without-processing** to True will skip all the stages except **Completion**, so long as the destination directories exist.

*  **no-preserved-state**

In order to allow for changes in some source files, or in only mode files, after all the sources have been processed once, the processing state must be archived. This may not be needed in testing or if the archiving takes too long.

Setting no-preserved-state = True prevents storage of state, but also forces **without-processing** to False, and **recompile** to True.

*  **recompile**

Controls the updating and caching of the content files. If true, then all files will be recompiled and cached.

A True value is over-ridden by **without-processing**

Normally False, which allows for only changed files to be processed.

*  **no-refresh**

Prevents the updating of content files, so no changes will be made.

*  **full-render**

Forces all files to be rendered. Even if there are no changes to source files, plugins or templates may be added/changed, thus changing the output, so all files need to be re-rendered.

This flag is set to False if **without-processing** is True.

*  **without-report**

Normally, report plugins report on the final state of the output files. This flag prevents report plugins from being loaded or run.

If **without-processing** is set, then the **Report** stage is skipped. If, however, the caches do not exist (deleted or first run), then the value of **without-processing** is ignored and the value of **without-report** is observed.

*  **debug-when & verbose-when**

ProcessedPod uses `debug` and `verbose`, which provide information about which blocks are processed (debug), and the result after the application of the template (verbose). This is a lot of information and generally, it is only one file that is of interest.

These two flags take a string, eg., `:debug-when<Introduction.pod6> `, and when the filename matches the string, then the debug/verbose flag is set for that file only. (verbose is only effective when debug is True).

*  **collection-info**

Causes collect to produce information about milestones and valid and invalid plugins

*  **with-only** filename

Collect is run only with that filename, which must be in the sources or mode-sources, and is specified like `debug-when`.

The option takes a string containing the filename. An empty string means all filenames in sources and mode-sources.

*  **no-code-escape**

`ProcessedPod` has a special flag for turning off escaping in code sections when a highlighter is used to pre-process code. In some cases, the highlighter also does HTML escaping, so RPR has to avoid it.

This has to be done at the Mode level and not left to `render` plugins.

# Plugin management
Plugins are **Raku** programs that are executed at specific milestones in the rendering process. The milestone names are given in [Milestones](Milestones.md) above.

The **plugins-required** key in the Mode's configuration contains a hash with keys whose names are the milestone names. Each key points to a list of plugin names, which are called in the order given.

All plugins must reside within the mode directory given by `plugins`, but this directory may belong to another Collection so that plugins could be shared between collections & modes. [TODO Revise plugin management so that common plugins can be maintained and developed separately to Collections].

All plugin names **must** be the name of a sub-directory of the **plugins** path. Within each plugin sub-directory, there must be a `config.raku` file containing information for the plugin, and for `Collection`. If _no_ `config.raku` files exists, the plugin is not valid and will be skipped.

With the exception of 'render' plugins, the config file must contain a key for the milestone type, which points to the program to be called, and when the file is evaluated, it yields a subroutine that takes the parameters needed for the plugin of that milestone. If no key exists with the name of the milestone, then the plugin is not valid.

Plugin's may need other configurable data, which should be kept in the config file for the plugin.

All plugins are expected to adhere to `no-status` and `collection-info`, which are interpretted as

*  `no-status` if true means 'no output at all', equivalent to a **quiet** flag

*  `collection-info` if true means 'output extra information' (if need be), equivalent to a **verbose** flag.

## Disabling a plugin
When it's necessary to disable a plugin, this can be done by:

*  Removing the plugin name from the `plugins-required` key of the Mode's config file;

*  Renaming / removing the `config.raku` file name inside the plugin directory

*  Renaming / removing the milestone key inside the plugin's `config.raku` file.

## Plugin types
The plugin types are as follows.

### Setup
Config hash must contain **setup** which is the name of a Raku program (a callable) that evaluates to a sub that takes a list of five items, eg.,

```
sub ( $source-cache, $mode-cache, Bool $full-render, $source-root, $mode-root, %options ) { ... }
```
> **$source-cache**  
A C<Pod::From::Cache+PostCache> object containing the pod of the sources files

> **$mode-cache**  
Like the above for the mode content files

> **$full-render**  
If True, then the sub should process the cache objects with the .sources method on the cache objects, otherwise with the .list-files method on the cache objects (the .list-files method only provides the files that have changed).

> **$source-root**  
This path must be prepended to any sources added (see below) to the cache, otherwise they will not be added to the destination file.

> **$mode-root**  
Likewise for the mode sources.

> **%options**  
Has the values of 'collection-info' and 'no-status' flags.

New files can be added to the cache object inside the sub using the `.add` method, see [Sources](Sources.md).

### Render
The Collection plugin-manager calls the `ProcessedPod.add-plugin` method with the config keys and the path modified to the plugin's subdirectory.

If the `render` key is True, no callable is provided, and the plugin name will be added via the **.add-plugin** method of the `ProcessedPod` object. See `ProcessedPod` documentation.

If the `render` key is a Str, then it is the filename of a Raku callable of the form

```
sub ( $pr, %options --> Array ) {...}
```
where

*  **$pr** is a <ProcessedPod> object,

*  **%options** is the same as for Setup, and

*  the callable **returns** a list of triples, with the form (to, from-plug, file)

	*  **to** is the destination under the `%config<destination> ` directory where the asset will be looked for, eg., an image file to be served.

	*  **plugin** is the name of the plugin in whose directory the asset is contained, where the value `myself` means the path of the plugin calling the render callable. Actually, 'myself' is the value of Collection::MYSELF.

	*  **file** is the filename local to the source plugin's subdirectory that is to be copied to the destination. This may contain a path relative to the plugin's subdirectory.

Since a render plugin is to be added using the `ProcessedPod` interface, it must have the `custom-raku` and `template-raku` keys defined, even if they evaluate to blank (eg. `:custom-raku()` ).

So the config file must have:

*  render (True | name of callable)

*  custom-raku => a Raku program that evaluates to an array of custom blocks (must be set to `()` if no Raku program )

*  template-raku => a Raku program that evaluates to a hash of RakuClosure templates (must be set to `()` if no Raku program)

It is possible to specify `path` but it must be relative to the plugin's sub-directory.

More information about these plugins can be found in the documentation in the `Raku::Pod::Render` distribution.

### Compilation
The `compilation` key must point to a Raku program that delivers a sub object

```
sub ( $pr, %processed, %options) { ... }
```
> **$pr**  
is the ProcessedPod object rendering the content files.

> **%processed**  
is a hash whose keys are source file names with a hash values containing TOC, Glossary, Links, Metadata, Footnotes, Templates-used structures produced by B<ProcessedPod>.

> **%options**  
as for setup

### Transfer
The `transfer` key points to a Raku file that evaluates to a

```
sub (%processed, $pr, %options ) {...}
```
> **%processed**  
as in Compilation

> **$pr**  
as in Compilation

> **%options**  
as for Setup

## Report
The `report` key points to a Raku file that evaluates to a

```
sub (%processed, @plugins-used, $pr, %options --> Array ) {...}
```
> **%processed**  
as in Compilation

> **@plugins-used**  
is an array of Pairs whose key is the milestone and value is a hash of the plugins used and their config parameters.

> **$pr**  
as in Compilation

> **%options**  
as for Setup

The plugin should return an Array of Pair, where for each Pair .key = (path/)name of the report file with extension, and .value is the text of the report in the appropriate format

The `collect` sub will write the file to the correct directory.

### Completion
The `completion` key points to a Raku file that evaluates to a `sub ($destination, $landing-place, $output-ext, %completion-options, %options) {...}` object.

*  **$destination**

is the name of the output path from the mode directory (defined in the mode configuration)

*  **$landing-place**

is the first file to be processed since, eg., for a website, order is not sufficient. name is relative to the destination directory.

*  **%completion-options** (actually specified as %config<completion-options>)

is the set of options that the completion plugin will require from the Mode-level configuration. For example, the very simple `cro-run` plugin requires the path to the static html files, the hostname, and the port on which the files are served. More complex plugins will require more options.

*  **%options**

As for Setup

There is no return value specified for this plugin type.

# Problems and TODO items
## Archiving and Minor Changes
In principle, if a small change is made in a source file of a Collection, only the rendered version of that file should be changed, and the Collection pages (eg., the index and the glossaries) updated. The archiving method chosen here is based on `Archive::Libarchive` and a `.7z` format. It works in tests where a small quantity of data is stored.

**However**, when there are many source files (eg., the Raku documentation), the process of restoring state information is **significantly** longer than re-rendering all the cached files. Consequently, the option `no-preserve-state` prevents the archiving of processed state. (TODO understanding and optimising the de-archiving process.)

## Plugin development
The aim is to have plugins developed and maintained separately. This may require some change to the Collection API.

## Dump file formatting
The aim is to use `PrettyDump` instead of <.raku> to transform information into text. However, <PrettyDump> does not handle `Bags` properly.

# Post-cache methods
Post-cache is a role added to a `Pod::From::Load` object so that Setup plugins can act on Cache'd content by adding pod files to the Cache (perhaps pre-processing primary source files) that will be rendered, masking primary pod files so that they are not rendered, or aliasing primary pod files.

If a secondary source file in the Cache is given a name that is the same as a primary source file, then if the underlying cache object should remain visible, another name (alias) should be given to the file in the Post-cache database.

The Post-cache methods `sources`, `list-files`, and `pod` have the same function and semantics as `Pod::From::Cache` except that the post-cache database is searched first, and if contents are found there, the contents are returned (which is why post-cache file names hide primary file names). If there is no name in the Post-cache database, then it is passed on to the underlying cache.

## multi method add(Str $fn, Array $p --&gt; Pod::From::Cache )
Adds the filename $fn to the cache. $p is expected to be an array of Pod::Blocks, but no check is made. This is intentional to allow the developer flexibility, but then a call to `pod( $fn )` will yield an array that is not POD6, which might not be expected.

The invocant is returned, thus allowing add to be chained with mask and alias.

## multi method mask(Str $fn --&gt; Pod::From::Cache)
This will add only a filename to the database, and thus mask any existing filename in the underlying cache.

Can be chained.

## multi method add-alias(Str $fn, Str :alias! --&gt; Pod::From::Cache)
This will add a filename to the database, with the value of a key in the underlying cache. Chain with mask to prevent the original spelling of the filename in the underlying cache being visible.

Can be chained.

If the alias is already taken, an exception is thrown. This will even occur if the same alias is used for the same cached content file.

## method behind-alias(Str $fn --&gt; Str )
Returns the original name of the cached content file, if an alias has been created, otherwise returns the same filename.

## method pod(Str $fn)
Will return

*  an array of Pod::Block (or other content - beware of adding other content) if the underlying Cache or database have content,

*  the array of Pod::Block in an underlying filename, spelt differently

*  `Nil` if there is no content (masking an underlying file in Cache)

*  throw a NoPodInCache Exception if there is no pod associated with either the database or the underlying cache. If the original filename is used after an alias have been generated, the Exception will also be thrown.

# Asset-cache methods
Asset-cache handles content that is not in Pod6 form. The instance of the Asset-cache class is passed via the plugin-data interface of `ProcessedPod`, so it is available to all plugins after the setup milestone, for example in the plugin callable:

```
sub render-plugin( $pp ) {
    my $image-manager = $pp.get-data('image-manager');
    ...
    $pp.add-data('custom-block', $image-manager);
}
```
By creating a name-space in the plugin data section and assigning it the value of the image-manager, the plugin callable can make the image-manager available to templates that get that data, which is a property in parameters called by the name-space.

`ProcessedPod` provides data from the name-space of a Block, if it exists, as a parameter to the template called for the Block. Note that the default name-space for a block is all lower-case, unless a `name-space` config option is provided with the Pod Block in the content file.

If a plugin provides an asset (eg., image, jquery script), it needs to provide a `render` callable that returns the triple so that Collect moves the asset from the plugin directory to the output directory where it can be served. This needs to be done separately if a CSS contains a url for local image.

`$image-manager` is of type Asset-cache, which has the following methods:

```
    #| the directory base, not included in filenames
    has Str $.basename is rw;
    #| the name of the file being rendered
    Str $.current-file
    #| asset-sources provides a list of all the items in the cache
    method asset-sources
    #| asset-used-list provides a list of all the items that referenced by Content files
    method asset-used-list
    #| asset-add adds an item to the data-base, for example, a transformed image
    method asset-add( $name, $object, :$by = (), :$type = 'image' )
    #| returns name / type / by information in database (not the object blob)
    method asset-db
    #| remove the named asset, and return its metadata
    method asset-delete( $name --> Hash )
    #| returns the type of the asset
    method asset-type( $name --> Str )
    #| if an asset with name and type exists in the database, then it is marked as used by the current file
    #| returns true with success, and false if not.
    method asset-is-used( $asset, $type --> Bool )
    #| brings all assets in directory with given extensions and with type
    #| these are set in the configuration
    multi method asset-slurp( $directory,  @extensions, $type )
    #| this just takes the value of the config key in the top-level configuration
    multi method asset-slurp( %asset-paths )
    #| with type 'all', all the assets are sent to the same output directory
    multi method asset-spurt( $directory, $type = 'all' )
    #| the value of the config key in the mode configuration
    multi method asset-spurt( %asset-paths )

```
# Copyright and License
(c) Copyright, 2021-2022 Richard Hainsworth

**LICENSE** Artistic-2.0







----
Rendered from README at 2022-07-29T09:24:59Z