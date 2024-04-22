        # Raku Collection Module
>
> **DESCRIPTION** # DESCRIPTION
Software to collect content files written in Rakudoc (aka POD6) and render them in a chosen format. Extensive use is made of plugins to customise the rendering. A distinction is made between the Rakudoc files for the main content (sources) and the Rakudoc files that describe the whole collection of sources (mode-sources), eg. the landing page (_index.html_) of a website, or the Contents page of the same sources in book form. The collection process is in stages at the start of which plugin callables (Raku programs) can be added that transform intermediate data or add templates, or add new Pod::Blocks for the rendering.

> **AUTHOR** # AUTHOR
Richard Hainsworth aka finanalyst


----
## Table of Contents
[Installation](#installation)  
[Usage](#usage)  
[Life cycle of processing](#life-cycle-of-processing)  
[Modes](#modes)  
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
[Collection Structure](#collection-structure)  
[Collection Content](#collection-content)  
[Extra assets (images, videos, etc)](#extra-assets-images-videos-etc)  
[Cache](#cache)  
[Mode](#mode)  
[Templates](#templates)  
[Configuration](#configuration)  
[Top level configuration](#top-level-configuration)  
[Mode-level configuration](#mode-level-configuration)  
[Plugin level configuration](#plugin-level-configuration)  
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
[Plugin development](#plugin-development)  
[Collection plugin specification](#collection-plugin-specification)  
[Collection plugin tests](#collection-plugin-tests)  
[Plugin updating](#plugin-updating)  
[Mapping released plugins to mode directories](#mapping-released-plugins-to-mode-directories)  
[Released plugins directory](#released-plugins-directory)  
[Refresh process](#refresh-process)  
[CLI Plugin Management System](#cli-plugin-management-system)  
[Problems and TODO items](#problems-and-todo-items)  
[Archiving and Minor Changes](#archiving-and-minor-changes)  
[Dump file formatting](#dump-file-formatting)  
[Post-cache methods](#post-cache-methods)  
[multi method add(Str $fn, Array $p --&gt; Pod::From::Cache )](#multi-method-addstr-fn-array-p----podfromcache-)  
[multi method mask(Str $fn --&gt; Pod::From::Cache)](#multi-method-maskstr-fn----podfromcache)  
[multi method add-alias(Str $fn, Str :alias! --&gt; Pod::From::Cache)](#multi-method-add-aliasstr-fn-str-alias----podfromcache)  
[method behind-alias(Str $fn --&gt; Str )](#method-behind-aliasstr-fn----str-)  
[method pod(Str $fn)](#method-podstr-fn)  
[multi method last-version( @version-data )](#multi-method-last-version-version-data-)  
[Head](#head)  
[Asset-cache methods](#asset-cache-methods)  
[Copyright and License](#copyright-and-license)  

----
This module is used by the module **Collection-Raku-Documentation**, but is intended to be more general, such as building a personal site.

# Installation
To install the distribution, a refresh utility (see [Plugin refreshing](Plugin refreshing.md)), and the default plugin directory (see [Released plugin directory](Released plugin directory.md)), use

```
zef install Collection
```
For those who really want to have a non-default plugin directory, it is possible. But **warning**: extra user input will be needed for other utilities, so read the whole of this file), eg, to have a hidden directory `.Collection` in the home directory (under *nix), use

```
PluginPath=~/.Collection zef install Collection
```
# Usage
The Collection module expects there to be a `config.raku` file in the root of the collection, which provides information about how to obtain the content (Pod6/rakudoc> sources, a default Mode to render and output the collection. All the configuration, template, and plugin files described below are **Raku** programs that evaluate to a Hash. They are described in the documentation for the `RakuConfig` module.

A concrete example of `Collection` is the [Collection-Raku-Documentation (CRD)](https://github.com/finanalyst/collection-raku-documentation.git) module. _CRD_ contains a large number of plugins (see below). Some plugin examples are constructed for the extended tests. Since the test examples files are deleted by the final test, try:

```
NoDelete=1 prove6 -I. xt
```
and then look at eg., `xt/test-dir`.

The main subroutine is `collect`. It requires a file `config.raku` to be in the `$CWD` (current working directory). In _CRD_ the executable `Raku-Doc` initiates the collection by setting up sources and installing a `config.raku` file. It is then simply a command line interface to `collect`.

# Life cycle of processing
The content files are processed in several stages separated by milestones. At each milestone, intermediary data can be processed using plugin callables, the data after the plugin callables can be dumped, or the processed halted.

`collect` can be called with option flags, which have the same effect as configuration options. The run-time values of the [Control flags](Control flags.md) take precedence over the configuration options.

`collect` should be called with a [Mode](Mode.md). A **Mode** is the name of a set of configuration files, templates, and plugins that control the way the source files are processed and rendered. The main configuration file must contain a key called `mode`, which defines the default mode that `collect` uses if called with no explicit mode, so if `collect` is called without a **Mode**, the default will be used.

# Modes
A Mode:

*  is the name of the process by which a _Collection_ is rendered and presented. At present, only `Website` is implemented, but it is planned to have Modes for `epub` and `pdf` formats. The presentation may be serving HTML files locally, or the creation of a single epub file for publishing.

*  is the name of a sub-directory under the Collection directory.

*  may not be named with any '_' in it. This allows for sub-directories in a Collection folder that are not modes, eg., a Raku documentation repository

*  A Mode sub-directory must contain:

	*  a sub-directory `configs`, and/or a `config.raku` file.

# Milestones
The `collect` sub can be called once the collection directory contains a `config.raku`, which in turn contains the location of a directory of rakudoc source files, which must contain recursively at least one source.

Processing occurs during a stage named by the milestone which starts it. Each stage is affected by a set of [Control flags](Control flags.md). Certain flags will be passed to the underlying objects, eg. `RakuConfig` and `ProcessedPod` (see `Raku::Pod::Render`).

Plugin callables may be called at each milestone (except 'Source' and 'Mode', where they are not defined). Plugins are described in more detail in [Plugin management](Plugin management.md). plugin callables are milestone specific, with the call parameters and return values depending on the milestone.

The milestones are:

*  Source

*  Mode

*  Setup

*  Render

*  Compilation

*  Transfer

*  Report

*  Completion

## Stopping or dumping information at milestones
Intermediate data can be dumped at the milestone **without stopping** the processing, eg.,

```
collect(:dump-at<source render>);
```
Alternatively, the processing can be **stopped** and intermediate data inspected, EITHER after the stage has run, but before the plugin callables for the next stage have been triggered, eg.,

```
my $rv = collect(:after<setup>);
```
OR after the previous stage has run and after the plugin callables for the milestone have been triggered, eg.,

```
my $rv = collect(:before<render>);
```
The return value `$rv` is an array of the objects provided to plugin callables at that milestone, and an array of the plugin callables triggered (note the plugin callables used will be a difference between the `:before` and `:after` stop points). The plugins-used array is not provided to all plugin callables, except at the Report milestone.

The return value `$rv` at `:after` will contain the object provided by the milestone after the named milestone. For example, milestone milestone 'Setup' is followed by milestone 'Render'. The return object for `:after<setup>` will be the return object for milestone 'Render'. See Milestones for more information.

The object returned by `:before<render>` may be affected by the plugin callables that are triggered before the named stage.

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

At this milestone, the source files have been cached. The **mode** sub-directory has not been tested, and the configuration for the mode has not been used. Since plugin management is dependent on the mode configuration, no plugin callables can be called.

The **return value** of `collect` with `:after<source>` is a single `Pod::From::Cache` object that does a `Post-Cache` role (see below for `Post-Cache` methods).

A `Pod::From::Cache` object provides a list of updated files, and a full set of source files. It will provide a list of Pod::Blocks contained in each content files, using the filename as the key.

During the stage the source files for the Mode are obtained, compiled and cached. The process is controlled by the same options as the _Source_ stage. For example, the **Mode** for `Collection-Raku-Documentation` is _Website_.

If a sub-directory with the same name as _mode_ does not exist, or there are no config files in the `<mode>/config` directory, `collect` will throw an `X::Collection::NoMode` exception at the start of the stage.

Mode source files are stored under the mode sub-directory and cached there. If the mode source files are stored remotely and updated independently of the collection, then the `mode-obtain` and `mode-refresh` keys are used.

## Setup Milestone
(Skipped if the `:without-processing` flag is True)

If **setup** plugin callables are defined and in the mode's plugins-required<setup> list, then the cache objects for the sources and the mode's sources (and the **full-render** value) are passed to the program defined by the plugin's **setup** key.

The purpose of this milestone is to allow for content files to be pre-processed, perhaps to creates several sub-files from one big file, or to combine files in some way, or to gather information for a search algorithm.

During the setup stage,

*  the `ProcessedPod` object is prepared,

*  templates specified in the `templates` directory are added

*  the key **mode-name** is added to the `ProcessedPod` object's plugin-data area and given the value of the mode.

The Setup stage depends on the following options:

*  **full-render**

By default, only files that are changed are re-rendered, which includes an assumption that if any source file is changed, then all the **mode** sources must be re-rendered as well. (See the Problems section below for a caveat.)

When **full-render** is True, the output directory is emptied of content, forcing all files to be rendered.

**full-render** may be combined with **no-refresh**, for example when templates or plugins are changed and the aim is to see what effect they have on exactly the same sources. In such a case, the cache will not be changed, but the cache object will not contain any files generated by **setup** plugin callables.

## Render Milestone
(Skipped if the `:without-processing` flag is True)

At this milestone `render` plugins are supplied to the `ProcessedPod` object. New Pod::Blocks can be defined, and the templates associated with them can be created.

The source files (by default only those that have been changed) are rendered. 

The stage is controlled by the same options as _Setup_ and

*  with-only - affects which Documents are rendered, see Configuration for more

*  ignore - prevents docs from being Cached, see Configuration for more

## Compilation Milestone
(Skipped if the `:without-processing` flag is True)

During the stage after this milestone, the structure documents are rendered. They can have Pod-blocks which use data included by templates and plugins during the render stage. They can also add to data, which means that the order in which a plugin is called may be important.

At this milestone plugin callables are provided to add compiled data to the `ProcessedPod` object, so that the sources in the mode's directory can function.

During the **Render** stage, the `%processed` hash is constructed whose keys are the filenames of the output files, and whose values are a hash of the page components of each page.

The `compilation` plugin callables could, eg, collect page component data (eg., Table of Contents, Glossaries, Footnotes), and write them into the `ProcessedPod` object separately so there is a TOC, Glossary, etc structure whose keys are filenames.

The return value of `collect` at the inspection point is a list of `ProcessedPod`, `%process`, with the `ProcessedPod` already changed by the `compilation` plugin callables.

The stage is controlled by the same options as _Setup_ and

*  with-only - same as include but for structure documents

*  ignore-mode - as for ignore above

## Transfer Milestone
(Skipped if the `:without-processing` flag is True)

Plugins may generate assets that are not transfered by them, or it is important to ensure that a plugin runs after all other plugins.

In addition, render plugins may create files that are transfered at the render stage, but should be removed after all plugins have run. So a transfer milestone plugin can be created to clean up the plugin's local directory.

## Report Milestone
(Skipped if the `:without-processing` flag is True)

Once a collection has been rendered, all the links between files, and to outside targets can be subjected to tests. It is also possible to subject all the rendered files to tests. This is accomplished using `report` plugin callables.

In addition, all the plugin callables that have been used at each stage (except for the Report stage itself) are listed. The aim is to provide information for debugging.

The report stage is intended for testing the outputs and producing reports on the tests.

## Completion Milestone
Once the collection has been tested, it can be activated. For example, a collection could be processed into a book, or a `Cro` App run that makes the rendered files available on a browser. This is done using `completion` plugin callables.

The **without-completion** option allows for the completion phase to be skipped.

Setting **without-processing** to True and **without-completion** to True should have no effect unless

*  there are no caches, which will be the case the first time `collect` is run

*  the destination directory is missing, which will be the case the first time `collect` is run

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

A class to manage asset files is added to the `ProcessedPod` object with a role, so the assets can be manipulated by plugins and templates. Assets that are in fact used by a Pod content file are marked as used. The aim of this functionality is to allow for report-stage plugin callables to detect whether all images have been used.

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
There are three levels of configuration:

*  The top-level configuration resides in `config.raku` in the root directory of the Collection. The `collect` sub will fail without this file.

*  The Mode configuration typically resides in the `configs` directory, in several files (the names are not important).

*  Each plugin has its own config, in the `config.raku` file of its directory.

## Top level configuration
In the descriptions below, simple illustrative names are given to files with configuration, templates, callables. These files are generally **Raku** programs, which are compiled and run. They will almost certainly contain errors during development and the **Rakudo** compiler will provide information based on the filename. So it is good practice to name the files that make them easier to locate, such as prefixing them with the plugin name.

`config.raku` **must** contain the following keys:

*  the **cache** directory, relative to the root directory of the collection

	*  `Collection-Raku-Documentation` default: 'doc-cache',

*  the **sources** directory, relative to the root of the collection and must contain at least one content file

	*  `Collection-Raku-Documentation` default: 'raku-docs'

*  **mode** is the default mode for the collection, and must be a sub-directory, which must exist and contain a `configs` sub-directory (note the plural ending). See Mode level configuration below.

	*  `Collection-Raku-Documentation` default: 'Website'

*  **without-processing** as described in Milestones

	*  default: False

*  **no-refresh** as described in Milestones

	*  default: False

*  **recompile** as described in Milestones

	*  default: False

The following are optional keys, together with the defaults

*  the allowed **extensions** for content files. These are provided to the `Pod::From::Cache` object.

	*  default: < rakudoc pod pod6 p6 pm pm6 >

*  no-status This option controls whether a progress bar is provided in the terminal

	*  default: False

*  **source-obtain** is the array of strings sent to the OS by `run` to obtain sources, eg git clone and assumes CWD is set to the directory of collection. Without this key, there must already be files in `sources`.

	*  default: ()

*  **source-refresh** is the array of strings run to refresh the sources, assumes CWD set to the directory of sources. No key assumes the sources never change.

	*  default: ()

*  **ignore** is a list of files in the **sources** directory that are not cached. This is a Collection level configuration. The option **include-only** is Mode level configuration, see below.

	*  default: ()

*  **no-status** as described in Milestones

	*  default: False

*  **without-report** as described in Milestones

	*  default: False

*  **full-render** as described in Milestones

	*  default: False

*  **asset-basename** as described in [Asset-cache methods](Asset-cache methods.md)

	*  `Collection-Raku-Documentation` default: 'asset_base'

## Mode-level configuration
The mode-level configuration resides in one or more **files** that are under the **configs/** sub-directory of the `mode` directory. This arrangement is used to allow for configuration to be separated into different named files for ease of management.

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

*  **report-path** is the path to which `report` plugins should output their reports.

*  **plugin-format** defines the format the plugins relate to. Each Mode is specified to produce output in a specific format, and the plugins, which include templates, are related to the format. Published plugins are stored for a particular format.

*  **plugins-required** points to a hash whose keys are milestone names where plugin callables can be applied

	*  **setup** a list of plugin names, see [Plugin management](Plugin management.md), for pre-processing cache contents

	*  **render** plugins used to render Pod::Blocks

	*  **compilation** plugins prepare the `ProcessedPod` object for collection pages.

	*  **assets** plugins that mark assets created in previous milestones

	*  **report** plugins to test and report on the rendering process

	*  **completion** plugins that define what happens after rendering

	*  **cleanup** plugins if cleanup is needed.

*  **landing-place** is the name of the file that comes first during the completion stage. For example, in a Website, the landing file is usually called `index.html`

*  **output-ext** is the extension for the output files

*  **plugin-options** is mandatory, see [Plugin level configuration](Plugin level configuration.md) for more information

All optional control flags are False by default. For the Mode configuration they are:

*  no-status

*  full-render

*  without-completion

*  without-report

*  no-preserved-state

*  debug-when

*  verbose-when

*  no-code-escape

## Plugin level configuration
Each plugin has its own configuration (more information in the sections on Plugins). In addition to the mandatory keys, a plugin may have its own configuration data. The configuration data in the plugin directory will be over-written each time a plugin is updated.

In order to provide for preservation of configuration data at the Mode level, the key `plugin-options` (typically kept in a separate config file) is used. The value of `plugin-options` is a Hash whose keys are the names of plugins. Each plugin-name key has a value that is a Hash of the keys required by the plugin.

For example, the `Collection-Raku-Documentation` plugin `cro-app` has the configuration options `:port` and `:host`. The default `Collection-Raku-Documentation` configuration contains the snippet:

```
plugin-options => %(
    cro-app => %(
        :port<30000>,
        :host<localhost>,
    ),
),
```
in a file under the Mode's `configs/` directory. These values will over-ride the plugin's default config values.

The plugin should therefore take configuration data from the ProcessedPod instance and not from the config file it is distributed with. This means that if a new plugin is intended to be used in place of an pre-existing one (see [Refresh process](Refresh process.md)), then the developer needs to check the configuration information from the namespace of the replaced name.

The Setup and Completion plugins are passed `plugin-options` directly because the ProcessedPod instance is out of scope.

`plugin-options` is a mandatory option in the Mode configuration. It may be set to Empty, viz.,

```
plugin-options()
```
in which case, all plugins will use their default options.

The ProcessPod instance is only modified by `Render` plugins, so if there is plugin configuration data that is needed by another Milestone callable, the plugin should call a blank callable, with empty block and templates.

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

Normally, report plugin callables report on the final state of the output files. This flag prevents report plugin callables from being loaded or run.

If **without-processing** is set, then the **Report** stage is skipped. If, however, the caches do not exist (deleted or first run), then the value of **without-processing** is ignored and the value of **without-report** is observed.

*  **debug-when & verbose-when**

ProcessedPod uses `debug` and `verbose`, which provide information about which blocks are processed (debug), and the result after the application of the template (verbose). This is a lot of information and generally, it is only a few files that are of interest.

These two flags take a string, eg., `:debug-when<Introduction.pod6> ` or `:debug-when<101 about> `, and when the string matches the filename, then the debug/verbose flag is set for that file only.

Note `verbose` is **only** effective when `debug` is True.

*  **collection-info**

Causes collect to produce information about milestones and valid and invalid plugins

*  **with-only** filename

Collect is run only with that filename, which must be in the sources or mode-sources, and is specified like `debug-when`.

The option takes a string containing the filename. An empty string means all filenames in sources and mode-sources.

*  **no-code-escape**

`ProcessedPod` has a special flag for turning off escaping in code sections when a highlighter is used to pre-process code. In some cases, the highlighter also does HTML escaping, so RPR has to avoid it.

This has to be done at the Mode level and not left to `render` plugin callables.

# Plugin management
Plugin callables are **Raku** programs that are executed at specific milestones in the rendering process. The milestone names are given in [Milestones](Milestones.md) above.

The **plugins-required** key in the Mode's configuration contains a hash with keys whose names are the milestone names. Each key points to a list of plugin names, which are called in the order given.

All plugins must reside within the mode **plugins**.

All plugin names **must** be the name of a sub-directory under the **plugins** subdirectory. Within each plugin sub-directory, there must be a `config.raku` file containing information for the plugin, and for `Collection`. If _no_ `config.raku` files exists, the plugin is not valid and will be skipped.

With the exception of 'render' plugin callables, the config file must contain a key for the milestone type, which points to the program to be called, and when the file is evaluated, it yields a subroutine that takes the parameters needed for the plugin of that milestone. If no key exists with the name of the milestone, then the plugin is not valid.

Plugin's may need other configurable data, which should be kept in the config file for the plugin.

All plugin callables are expected to adhere to `no-status` and `collection-info`, which are interpretted as

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
sub ( $source-cache, $mode-cache, Bool $full-render, $source-root, $mode-root, %plugin-options, %options ) { ... }
```
*  **$source-cache**

A `Pod::From::Cache+PostCache` object containing the pod of the sources files New files can be added to the cache object inside the sub using the `.add` method, see [Sources](Sources.md).

*  **$mode-cache**

Like the above for the mode content files

*  **$full-render**

If True, then the sub should process the cache objects with the .sources method on the cache objects, otherwise with the .list-files method on the cache objects (the .list-files method only provides the files that have changed).

*  **$source-root**

This path must be prepended to any sources added (see below) to the cache, otherwise they will not be added to the destination file.

*  **$mode-root**

Likewise for the mode sources.

*  **%plugin-options**

Has the values of plugin options that over-ride a plugin's own defaults. See [Plugin level configuration](Plugin level configuration.md) for more information.

*  **%options**

Has the values of 'collection-info' and 'no-status' flags.

### Render
The Collection plugin-manager calls the `ProcessedPod.add-plugin` method with the config keys and the path modified to the plugin's subdirectory. The ProcessPod instance is only modified by `Render` plugins, so if there is plugin configuration data that is needed by another Milestone callable, the plugin should call a blank callable, with empty block and templates.

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

	*  **from-plug** is the name of the plugin in whose directory the asset is contained, where the value `myself` means the path of the plugin calling the render callable. Actually, 'myself' is the value of Collection::MYSELF.

	*  **file** is the filename local to the source plugin's subdirectory that is to be copied to the destination. This may contain a path relative to the plugin's subdirectory.

	*  For example for an HTML file, this would be the relative URL for the `src` field. Eg., `to = 'asset/image'`, `file = 'new-image.png'`, `from-plug = 'myself'` and the html would be `<img src="asset/image/new-image.png" /> `.

Since a render plugin is to be added using the `ProcessedPod` interface, it must have the `custom-raku` and `template-raku` keys defined, even if they evaluate to blank (eg. `:custom-raku()` ).

So the config file must have:

*  render (True | name of callable)

*  custom-raku => a Raku program that evaluates to an array of custom blocks (must be set to `()` if no Raku program )

*  template-raku => a Raku program that evaluates to a hash of RakuClosure templates (must be set to `()` if no Raku program)

It is possible to specify `path` but it must be relative to the plugin's sub-directory.

### Compilation
Note that the structure files are rendered after the `compilation` stage, BUT the information for rendering the structure files, that is the custom blocks and the templates must accompany a `render ` plugin. Compilation plugin callables are to process the data accumulated during the rendering of the content files, and to make it available for the custom blocks / templates that will be invoked when the structure documents are rendered.

The `compilation` key must point to a Raku program that delivers a sub object

```
sub ( $pr, %processed, %options ) { ... }
```
> **$pr**  
is the ProcessedPod object rendering the content files.

> **%processed**  
is a hash whose keys are source file names with a hash values containing TOC, Glossary, Links, Metadata, Footnotes, Templates-used structures produced by B<ProcessedPod>.

> **%options**  
as for setup

If the return value of the callable is an Array of triplets (as for a Render callable), then assets are transferred from the plugin directory. Any other type of return value is ignored.

### Transfer
The `transfer` key points to a Raku file that evaluates to a

```
sub ($pr, %processed, %options --> Array ) {...}
```
> **%processed**  
as in Compilation

> **$pr**  
as in Compilation

> **%options**  
as for Setup

> **return object**  
as for the compilation plugin

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
The `completion` key points to a Raku file that evaluates to a

```
sub ($destination, $landing-place, $output-ext, %plugin-options, %options) {...}
```
*  **$destination**

is the name of the output path from the mode directory (defined in the mode configuration)

*  **$landing-place**

is the first file to be processed since, eg., for a website, order is not sufficient. name is relative to the destination directory.

*  **$output-ext**

is the output extension.

*  **%plugin-options**

As for Setup

*  **%options**

As for Setup

There is no return value specified for this plugin type.

# Plugin development
There is a separate development distribution `raku-collection-plugin-development`, which contains several tools for adding and testing plugins. However, a single plugin can be tested using the module `Collection::TestPlugin`, which is included in this distribution.

## Collection plugin specification
All Collection plugins must conform to the following rules

*  The plugin name must:

	*  start with a letter

	*  followed by at least one \w or \-

	*  not contain \_ or \.

	*  thus a name matches / <alpha> <[\w] + [\-] - [\_]>+ /

*  The plugin directory contains

	*  `config.raku`, which is a file that evaluates to a Raku hash.

	*  README.rakudoc

	*  t/01-basic.rakutest

*  The `config.raku` file must contain the following keys

	*  `name`. This is the released name of the plugin. It will be possible for a new plugin to have the same functionality as another, while extending or changing the output. For more detail, see [Collection plugin management system](Collection plugin management system.md). Typically, the name of the plugin will match the name of the sub-directory it is in.

	*  `version`. This point to a Str in the format \d+\.\d+\.\d+ which matches the semantic version conventions.

	*  `auth`. This points to a Str that is consistent with the Raku 'auth' conventions.

	*  `license`. Points to a SPDX license type.

	*  `authors`. This points to a sequence of names of people who are the authors of the plugin.

	*  one or more of `render setup report compilation completion`

		*  If render then

			*  the render key may be a boolean

			*  or the render key is a Str which must

				*  be a filename in the directory

				*  be a raku program that evaluated to a callable

				*  the callable has a signature defined for render callables

			*  the key `custom-raku`

				*  must exist

				*  must either be empty, viz. `custom-raku()`

				*  or must have a Str value

				*  if it has a Str value and the key `:information` does contain `custom-raku` then it is treated as if `custom-raku` is empty

				*  if it has a Str value and the key `:information` does NOT contain `custom-raku` then the Str value should

					*  point to a file name in the current directory

					*  and the filename should contain a Raku program that evaluates to an Array.

			*  the key `template-raku`

				*  must exist

				*  must either be empty, viz. `template-raku()`

				*  or must have a Str value

				*  if it has a Str value and the key `:information` does contain `template-raku` then it is treated as if `template-raku` is empty

				*  if it has a Str value and the key `:information` does NOT contain `template-raku` then the Str value should

					*  point to a file name in the current directory

					*  and the filename should contain a Raku program that evaluates to a Hash.

		*  If not render, then the value must point to a Raku program and evaluate to a callable.

	*  _Other key names_. If other keys are present, they must point to filenames in the current directory.

	*  `information`. This key does not need to exist.

		*  If it exists, then it must contain the names of other keys.

		*  If a key named in the `:information` list contains a Str, the filename will NOT exist in the plugin directory, but will be generated by the plugin itself, or is used as information by the plugin.

		*  This config key is intended only for plugin testing purposes.

## Collection plugin tests
This distribution contains the module `Collection::TestPlugin` with a single exported subroutine `plugin-ok`. This subroutine verifies that the plugin rules are kept for the plugin.

Additional plugin specific tests should be included.

# Plugin updating
The local computer may contain

*  More than one collection, eg. a personal website and a Raku documentation collection

*  Each Collection may have more than one Mode, eg., a HTML website, an epub producer.

*  A collection/mode combination may rely on a previous API of a plugin, which may be broken by a later API.

*  A new plugin may have been written as a drop-in replacement for an older version, and the new plugin may have a different name, or auth, or version.

In order to implement this flexibility, the following are specified:

*  There is a released plugins directory (see [Released plugins directory](Released plugins directory.md)) to contain all Collection plugins.

*  The semantic versioning scheme is mandated for Collection plugins. A version is `v<major>.<minor>,<patch>`. Changes at the `<patch> ` level do not affect the plugin's functionality. Changes at the `<minor> ` level introduce new functionality, but are backward compatible. Changes at the `<major> ` level break backward compatibility.

*  Each distributed plugin is contained in the release directory in a subdirectory named by the plugin name, the auth field, and the major version number (minor and patch numbers are not included because they should not by definition affect the API).

*  Each Mode configuration only contains the name of the plugin (without the auth, or version names).

*  The developer may define which name/version/auth of a released plugin is to be mapped to the plugin required in the Mode configuration. Thus

	*  changes in API can be frozen to earlier versions of the plugin for some concrete Mode.

	*  different plugin versions can be used for different collection/modes

	*  a differently named plugin can be mapped to a plugin required by a specific collection/mode.

		*  **Note** an alternate plugin, as given by `name` may also have a non-default `auth`, so `auth` may need to be added to `plugins.rakuon` as well.

*  Consequently, all released plugins are defined for

	*  a **format** (eg. html)

	*  a **major** version

	*  an **auth** name

*  The mapping information from a released plugin to a Mode is contained in a file in the root of a Collection.

*  When the plugins are updated

	*  all the latest versions for each Format/Name/Version/Auth are downloaded.

	*  a symlink is generated (or if the OS does not allow symlink, the whole directory is copied) from the released version to the directory where each mode expects its plugins to be located.

*  Each Collection root directory (the directory containing the topmost `config.raku` file) will contain the file `plugins.rakuon`.

*  The plugin management tool (PMT)

	*  checks if a `plugins.rakuon` exists. If not, it generates a minimal one.

	*  runs through the plugins-required of each **Mode** in the collection.

	*  for each distinct plugin verifies whether

		*  the plugin has an entry in `plugins.rakuon`, in which case

			*  the PMT maps (or remaps if the constraint is new) the released plugin name/auth/ver to the plugin-required name using the rules of `plugins.rakuon` as given in [Mapping released plugins to mode directories](Mapping released plugins to mode directories.md)

		*  the plugin does not have an entry, which means it has not yet been mapped, and there are no constraints on the plugin, so the default name/auth/version are used.

## Mapping released plugins to mode directories
The file `plugins.rakuon` contains a hash with the following keys:

*  `_metadata_`. Contains a hash with data for the `refresh` functionality.

	*  `collection-plugin-root` This contains the name of a directory reachable from the Collection root directory with the released plugins are downloaded.

	*  `update-behaviour` Defines what happens when a new released plugin has an increased Major number. Possible values are:

		*  _auto_ All relevant plugin names are updated to the new version, a message is issued

		*  _conserve_ Plugins are not updated to the new version, a warning is issued, updating is then plugin by plugin with a `-force` flag set.

		*  **Note** The update behaviour is not initially implemented.

*  Every other toplevel key that meets the plugin naming convenstion is interpreted as a Mode. This means a mode cannot be named `_metadata_`.

*  The Mode key will point to a hash with the keys:

	*  `_mode_format` Each mode may only contain plugins from one Format, eg., _html_.

	*  By the plugin naming rules, a _plugin_ may not be named `_mode_format`.

	*  Every other key in a mode hash must be a plugin name contained in the Mode's plugins-required configuration.

	*  There may be zero plugin keys

	*  If a plugin in the plugins-required configuration list does not have an entry at this level, then it has not been mapped to a sub-directory of the `released-directory`.

	*  A plugin key that exists must point to a Hash, which must at least contain:

		*  mapped => the name of the released plugin

	*  The plugin hash may also point to one or more of:

		*  name => the name of the alternate released plugin

			*  the default name (if the key is absent) is the plugin-required's name

			*  if a different name is given, a released plugin is mapped to the required directory in the mode sub-directory

		*  major => the major number preceeded by 'v'

			*  the default value (if the key is absent) is the greatest released major value

			*  A major value is the maximum major value of the full version permitted, thus freezing at that version

		*  auth => the auth value

			*  the default value (if the key is absent) is 'collection'

	*  If there is no distributed plugin for a specified `auth | major | name `, then an error is thrown.

Some examples:

*  The Raku-Collection-Raku-Documentation, Website mode, requires the plugin `Camelia`. The plugin exists as a HTML format. It has version 1.0.0, and an auth 'collection'. It is distributed as `html/camelia_v1_auth_collection`. Suppose a version with a new API is created. Then two versions of the plugin will be distributed, including the new one `html/camelia_v2_auth_collection`.

If the key for camelia in the hash for mode Website only contains an empty `version` key, then the defaults will be implied and a link (or copy) will be made between the released directory `html/camelia_v2_auth_collection` and `Website/plugins/camelia`

*  If plugins.rakuon contains the following: `Website =` %( :FORMA"> \{\{\{ contents }}}

, :camelia( %( :major(1), ) ) > then the link will be between `html/camelia_v1_auth_collection` and `Website/plugins/camelia`

*  Suppose there is another valid `auth` string **raku-dev** and there is a distributed plugin _html/camelia_v2_auth_raku-dev_, and suppose `plugins.rakuon` contains the following: `Website =` %( :FORMA"> \{\{\{ contents }}}

, :camelia( %( :auth<raku-dev>, ) ) > then the link will be made between `html/camelia_v2_auth_raku-dev` and `Website/plugins/camelia`

*  Suppose a different icon is developed called `new-camelia` by `auth` **raku-dev**, then `plugins.rakuon` may contain the following: `Website =` %( :FORMA"> \{\{\{ contents }}}

, camelia( %( :name<new-camelia>, :auth<raku-dev>, ) ) > then a link (copy) is made between `html/new-camelia_v2_auth_raku-dev` and `Website/plugins/camelia`

	*  Note how the auth must be given for a renaming if there is not a `collection` version of the plugin

## Released plugins directory
When Collection is installed, a directory called (by default) `$*HOME/.local/share/Collection` is created (on a Linux system this will be the same as `~/.local/share/Collection`).

If the Environment variable `PluginPath` is set to a valid path name upon installation, then that will be used instead. But when `refresh-collection-plugins` is first used, then the non-default name must be supplied.

The directory is initialised to point at the `https://github.com/finanalyst/collection-plugins` repo and the `manifest.rakuon` file is downloaded.

If another release directory location is desired, then

*  it can be specified when `refresh-collection-plugins` is first run for each collection, in which case the file `plugin.rakuon` is given the value for the `:collection-plugin-root`.

*  a custom Raku program for refreshing Collection files can be written, eg., the github repo is to be located in `~/.my_own_collection`

```
use v6.d;
use Collection::RefreshPlugins;
sub MAIN(|c) {
    $Collection::RefreshPlugins::release-dir = "$*HOME/.my_own_collection";
    refresh( |c );
}

```
## Refresh process
The intent is for the released plugins to be held in a single directory (called the _released plugins_ directory), and for the references in a Collection-Mode `plugins` directory to be links (OS dependent) to the _released plugins_ directory.

The _released plugins_ directory is a Github repository, so doing a `git pull` will pull in the most recent versions of the plugins. Consequently, each Collection-Mode plugin reference will automatically be updated.

A `git pull` is therefore one form of a refresh. (TODO if an OS does not have directory links, then this form of refresh will need to be enhanced with a copy operation).

Refresh needs to deal with other situations

*  A new plugin name is added to the Collection-Mode's `plugins-required` list.

	*  A link needs to be added to the Collections-Mode's `plugins` directory.

*  A new entry exists for the plugin name in the `plugins.rakuon`

	*  An entry changes the release name associated with the Collection-Mode plugin.

		*  If the desired released plugin does not exist, then an Exception is thrown. Default behaviour might lead to an infinite loop.

*  A released plugin major version has increased since the last refresh.

	*  The default is for a Collection-Mode plugin initially to be linked to the most recent version of the plugin

	*  Several behaviours are possible:

		*  The default _update-behaviour_ is given in the `_metadata_` hash of `plugins.rakuon`

		*  _force_ Leave the existing links in place, issue a warning, update to latest only when forced. Include suggestion to change plugins.rakuon file to suppress warnings.

		*  _auto_ (default) Automatically update to the latest version, issuing a message

## CLI Plugin Management System
Collection contains the utility `collection-refresh-plugins` as a (PMS). It is called as follows:

```
collection-refresh-plugins [-collection=<path>] [-collections='path1 path2 path3']
```
`-collection` is the path to a Collection directory. By default it is the Current Working Directory.

`-collections` is a space delimited list of paths to Collections

When a Collection directory contains a file `plugins.rakuon`, then the utility will inspect the release directory, updates it, and maps (copy) the most recent plugins according this file. See below for more detail about the specification of `plugins.rakuon`.

When a Collection does not contain a file <plugins.rakuon>, it generates one from the `plugin-required` key of each of the `config.raku` files in each Mode. During this process, the user is prompted for the directory name (relative to the current working directory) of released plugin directory.

# Problems and TODO items
## Archiving and Minor Changes
In principle, if a small change is made in a source file of a Collection, only the rendered version of that file should be changed, and the Collection pages (eg., the index and the glossaries) updated. The archiving method chosen here is based on `Archive::Libarchive` and a `.7z` format. It works in tests where a small quantity of data is stored.

**However**, when there are many source files (eg., the Raku documentation), the process of restoring state information is **significantly** longer than re-rendering all the cached files. Consequently, the option `no-preserve-state` prevents the archiving of processed state. (TODO understanding and optimising the de-archiving process.)

## Dump file formatting
The aim is to use `PrettyDump` instead of <.raku> to transform information into text. However, <PrettyDump> does not handle `Bags` properly.

# Post-cache methods
Post-cache is a role added to a `Pod::From::Load` object so that Setup plugin callables can act on Cache'd content by adding pod files to the Cache (perhaps pre-processing primary source files) that will be rendered, masking primary pod files so that they are not rendered, or aliasing primary pod files.

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

## multi method last-version( @version-data )
The `@version-data` contains an array of strings to be given to a `run` sub. Typically it is a call to `git revparse`. The return value is the result of the command to the Operating System.

# head

multi method last-version( @per-file-version, $fn, $doc-source, :debug)

The `@per-file-version` array of strings is appended by the value of $fn, changed to the underlying source if it is an alias.

Typically, the string is a git command. However, the git command in particular runs on a directory, but the source file may be in a sub-directory, which needs to be stripped, so `$doc-source` is provided to enable the correct filename.

`:debug` generates information about the `run` command, if true.

# Asset-cache methods
Asset-cache handles content that is not in Pod6 form. The instance of the Asset-cache class is passed via the plugin-data interface of `ProcessedPod`, so it is available to all plugin callables after the setup milestone, for example in the plugin callable:

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

The basename for the assets is set in the Top level configuration in the option `asset-basename`

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
Rendered from README at 2024-04-22T12:38:14Z