# Raku Collection Module
> **Description** A collection of subroutines to collect, cache, render, and output content files written in POD6. Output can a CRO app creating a website available in a browser at localhost:3000, or an epub.

> **Author** Richard Hainsworth aka finanalyst


----
----
## Table of Contents
[Installation](#installation)  
[Usage](#usage)  
[Life cycle of processing](#life-cycle-of-processing)  
[Milestones](#milestones)  
[Zeroth](#zeroth)  
[Source](#source)  
[Setup](#setup)  
[Render](#render)  
[Compilation](#compilation)  
[Report](#report)  
[Completion](#completion)  
[Cleanup](#cleanup)  
[Distribution Structure](#distribution-structure)  
[Content](#content)  
[Cache](#cache)  
[Mode](#mode)  
[Templates](#templates)  
[Configuration](#configuration)  
[Top level configuration](#top-level-configuration)  
[Second-level configuration](#second-level-configuration)  
[Control flags](#control-flags)  
[Plugin management](#plugin-management)  
[Setup](#setup)  
[Render](#render)  
[Compilation](#compilation)  
[Report](#report)  
[Completion](#completion)  

----
This module is used by Collection-Raku-Documentation, but is intended to be more general, such as building a blog site.

# Installation
```
zef install Collection
```
# Usage
The Collection module expects there to be a `config.raku `file in the root of the collection, which provides information about how to obtain the content (Pod6/rakudoc> sources, a default Mode to render and output the collection. All the configuration, template, and plugin files described below are **Raku** programs that evaluate to a Hash. They are described in the documentation for the `RakuConfig` module.

A concrete example of `Collection` is the [Collection-Raku-Documentation](https://github.com/finanalyst/collection-raku-documentation.git) module. It provides the `Raku-Doc` executable, which copies a `config.raku` file and a mode called `Website`. The configuration describes how to get the **Raku Doc** files from the **Raku.org** repository, and the **Website** mode contains default templates and plugins to create a website that shows the collection, using a `Cro` app.

The `Collection` module provides the infrastructure, whilst `Collection-Raku-Documentation` provides the concrete configuration and specifies how files are rendered. However, `Collection` has been designed so that **Templates** and **Plugins** for `Collection-Raku-Documentation` can be used for other collections, while other Collection distributions that only provide **Plugins** and/or **Templates**. Once the Raku-Documentation collection has been initialised, Raku-Doc calls `collect`, which is the entry point for `Collection`.

# Life cycle of processing
After initialisation, which should only occur once, then the content files are processed in several stages separated by milestones. At each milestone, the content files, or the intermediary data can be inspected and reprocessed using plugins.

`collect` can be called with option flags, which have the same effect as configuration options. The run-time values of the [Control flags](Control flags.md) take precedence over the configuration options.

In **Collection-Raku-Documentation** `Raku-Doc` is an Command Line Interface for giving run time options to `collect`.

`collect` can also be called with a [Mode](Mode.md). A **Mode** is the name of a set of configuration files, templates, and plugins that control the way the source files are processed and rendered. The main configuration file must contain a key called `mode`, which defines the default mode that `collect` uses if called with no explicit mode.

For example, the **Collection-Raku-Documentation** is set up with a default `mode` called **Website**. `Raku-Doc` just calls `collect` and passes on to `collect` all of its arguments, with the exception of the string **Init**, which `Raku-Doc` traps so that processing can stop before calling `collect`.

If `Raku-Doc` is called with a string other than 'Init' or 'Website', then the string is interpreted as another **Mode**, with its own sub-directory and [Configuration](Configuration.md) for the collection. For example,

```
Raku-Doc Book
```
would create the collection output defined by the configuration in the sub-directory `Book/config/`. This design is to allow for the creation of different Collection outputs to be defined for the same content files.

# Milestones
The `collect` sub can **only** be called cnce the collection directory contains a `config.raku`, which in turn contains the location of a directory, which must contain recursively at least on source.

The process of collecting, rendering and outputting the collection has a number of defined milestones. A milestone will have an inspection point, at which the processing can be stopped and the intermediate data inspected, eg.

```
my $rv = collect(:end<post-cache>);
```
The `end` option is set to a (case-insensitive) name of the inspection point for the milestone.

A milestone may also be where plugins (aka call-backs) can be defined. Plugins are described in more detail in [Plugin management](Plugin management.md).

The return value of `collect` at a milestone is the object provided to the plugins after all the plugins have been evaluated. The aim of this design is to give to developers the ability to test the effect of plugins at each stage on the object to be modified by the plugins.

Processing occurs during a stage named by the milestone which starts it. Each stage is affected by a set of [Control flags](Control flags.md). Certain flags will be passed to the underlying objects, eg. `RakuConfig` and `ProcessedPod` (see `Raku::Pod::Render`.

The milestone name is the name of the inspection point, and the plugin type.

## Zeroth
Since this is the start of the processing, no plugins are defined as there are no objects for them to operate on.

The `config.raku` file must exist and must contain a minumum set of keys. It may optionally contain keys for the control flags that control the stage, see below. The intent is to keep the options for the root configuration file as small as possible and only refer to the source files. Most other options are configured by the Mode.

During the subsequent **Source** stage, the source files in the collection are brought in, if the collection has not been fully initiated, using the `source-obtain` configaturation list. Alternatively, any updates are brought in using the `source-refresh` list. Commonly, sources will be in a _git_ repository, which has separate commands for `clone` and `pull`. If the `source-obtain` and `source-refresh` options are not given (for example during a test), no changes will be made to the source directory.

Any changes to the source files are cached by default.

The control flags for the subsequent process are:

*  **no-status** (default False)

The compilation and caching of source files is slow, so a progress bar is provided by default. This is not useful when testing or batch processing, so `:no-status` prevents the progress bar.

*  **no-refresh** (default False)

Prevents source file updates from being brought in.

An explicit configuration or run-time **no-refresh** = False is over-ridden by an explicit run-time or configuration **without-processing** = True.

*  **without-processing** (default False)

This option is used to skip every stage upto the **Completion**, for example starting the document server without checking for documentation updates or re-rendering templates.

**without-processing** implies **no-refresh**, and over-rides any configuration option, but with the caveat that the caches must exist.

*  **recompile**

Forces all the source files to be recompiled into the cache.

**without-processing** over-rides **recompile**.

## Source
At this milestone, the source files have been cached. The **mode** sub-directory has not been tested, and the configuration for the mode has not been used. Since plugin management is dependent on the mode configuration, no plugins can be called.

The **return value** of `collect` with inspection _source_ inspection points is a single `Pod::From::Cache` object that does a `Post-Cache` role.

A `Pod::From::Cache` object provides a list of updated files, and a full set of source files. It will provide a list of Pod::Blocks contained in each content files, using the filename as the key.

A **source** plugin can associate a `Pod::Block` with a key, interpreted as a source filename. Thus the Pod lists can be processed, eg. looking for search keys, and new pod files can be created that can then be rendered. The filtering is done with the `Pod-Cache` role. For example,

```
for $cache.list-files {
    my $pod-tree = $cache.pod($_);
    # process pod-tree
    my Pod::Block $processed = something($pod-tree);
    $cache.add("$_\-processed", [ $processed ]); # must be an Array
    $cache.add($_); # omit this step if the unprocessed file is to be rendered
}

```
When pod is extracted from the cache in the rendering phase, the `$_-processed` files will be available, but the `$_` files will return an undefined (False in Bool context) and not be rendered.

The next, Mode, stage is when the source files for the Mode are obtained, compiled and cached. The process is controlled by the same options as the Source stage.

If a sub-directory with the same name as _mode_ does not exist, or there are no config files in the `<mode>/config` directory, `collect` will throw an `X::Collection::NoMode` exception during this stage.

Mode source files are stored under the mode sub-directory and cached there. If the mode source files are stored remotely and updated independently of the collection, then the `mode-obtain` and `mode-refresh` keys are used.

## Setup
If **setup** plugins are defined and in the mode's plugins-required<setup> list, then the cache objects for the sources and the mode's sources (and the **full-render** value) are passed to the program defined by the plugin's **setup** key.

The purpose of this milestone is to allow for content files to be pre-processed, perhaps to creates several sub-files from one big file, or to combine files in some way, or to gather information for a search algorithm.

During the setup stage,

*  the `ProcessedPod` object is prepared,

*  templates specified in the `templates` directory are added

*  the key **mode-name** is added to the `ProcessedPod` object's plugin-data area and given the value of the mode.

The Setup stage depends on the following options:

*  **no-status** as before, turns off a progress bar

*  **without-processing** skips the **setup** stage, unless the caches did not previously exist.

*  **full-render**

By default, only files that are changed are re-rendered, which includes an assumption that if any source file is changed, then all the **mode** sources must be re-rendered as well.

When **full-render** is True, the output directory is emptied of content, forcing all files to be rendered.

**full-render** may be combined with **no-refresh**, for example when templates or plugins are changed and the aim is to see what effect they have on exactly the same sources. In such a case, the cache will not be changed, but the cache object will not contain any files generated by **setup** plugins.

**without-processsing** takes precedence over **full-render**, unless there is no output directory.

## Render
At this milestone `render` plugins are supplied to the `ProcessedPod` object. New Pod::Blocks can be defined, and the templates associated with them can be created.

The source files (by default only those that have been changed) are rendered. 

The stage is controlled by the same options as _Setup_. So, it can be skipped by setting **without-processing**.

## Compilation
At this milestone plugins are provided to add compiled data to the `ProcessedPod` object, so that the sources in the mode's directory can function.

During the **Render** stage, the `%processed` hash is constructed whose keys are the filenames of the output files, and whose values are a hash of the page components of each page.

The `compilation` plugins could, eg, collect page component data (eg., Table of Contents, Glossaries, Footnotes), and write them into the `ProcessedPod` object separately so there is a TOC, Glossary, etc structure whose keys are filenames.

The return value of `collect` at the inspection point is a list of `ProcessedPod`, `%process`, with the `ProcessedPod` already changed by the `compilation` plugins.

## Report
Once a collection has been rendered, all the links between files, and to outside targets can be subject to various tests. It is also possible to subject all the rendered files to tests. This is accomplished using `report` plugins.

In addition, all the plugins that have been used at each stage (except for the Report stage itself) are available.

The report stage is intended for testing the outputs and producing reports on the tests.

## Completion
Once the collection has been tested, it can be activated. For example, a collection could be processed into a book, or a `Cro` App run that makes the rendered files available on a browser. This is done using `completion` plugins.

The **no-completion** option allows for the completion phase to be skipped.

Setting **without-processing** to True and **no-completion** to True should have no effect unless

*  there are no caches, which will be the case the first time `collect` is run

*  the destination directory is missing, which will be the case the first time `collect` is run

Note that the **no-report** option is False by default, and will take effect even if **without-processing** is True, but processing is forced because caches or destination directories are missing.

So this combination is useful to set up the collection and to get a report on the processing.

## Cleanup
Cleanup comes after `collect` has finished, so is not a part of `collect`.

Currently, `collect` just returns with the value of the @plugins-used object.

# Distribution Structure
A distribution contains content files, which may be updated on a regular basis, a cache, templates, and one or more modes.

## Content
The content of the distribution is contained in **POD6** files. In addition to the source files, there are Collection content files which express things like the Table of Contents for the whole collection.

Collection content are held separately to the source content, so that each mode may have different pages.

This allows for active search pages for a Website, not needed for an epub, or publisher data for an output formation that will be printed.

## Cache
The **cache** is a Precomp structure into which the content files are pre-preprocessed.

## Mode
The **Mode** is the collection of templates and configuration for some output.

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
`config.raku` **must** contain the following keys:

*  the **cache** directory, relative to the root directory of the collection

	*  `Collection-Raku-Documentation` default: 'doc-cache',

*  the **sources** directory, relative to the root of the collection and must contain at least one content file

	*  `Collection-Raku-Documentation` default: 'raku-docs'

*  **mode** is the default mode for the collection, and must be a sub-directory, which must exist and contain a `configs` sub-directory (note the plural ending).

	*  `Collection-Raku-Documentation` default: 'Website'

The following are optional keys, together with the defaults 

*  the allowed **extensions** for content files. These are provided to the `Pod::From::Cache` object.

	*  < rakudoc pod pod6 p6 pm pm6 >

*  no-status This option controls whether a progress bar is provided in the terminal

	*  False

*  **source-obtain** is the array of strings sent to the OS by `run` to obtain sources, eg git clone and assumes CWD is set to the directory of collection. Without this key, there must already be files in `sources`.

	*  ()

*  **source-refresh** is the array of strings run to refresh the sources, assumes CWD set to the directory of sources. No key assumes the sources never change.

	*  ()

*  **ignore** is a list of files in the **sources** directory that are not cached.

	*  ()

*  **no-status** as described in Milestones

	*  False

*  **without-processing** as described in Milestones

	*  False

*  **no-refresh** as described in Milestones

	*  False

*  **recompile** as described in Milestones

	*  False

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

	*  **report** plugins to test and report on the rendering process

	*  **completion** plugins that define what happens after rendering

	*  **cleanup** plugins if cleanup is needed.

*  **landing-place** is the name of the file that comes first during the completion stage. For example, in a Website, the landing file is usually called `index.html`

*  **output-ext** is the extension for the output files

The following are optional as they are control flags that are False by default.

*  recompile

*  no-refresh

*  full-render

*  no-report

*  without-processing

*  no-cache

*  no-completion

*  debug

*  verbose

*  **no-code-escape**

`ProcessedPod` has a special flag for turning off escaping in code sections when a highlighter is used to pre-process code. In some cases, the highlighter also does HTML escaping, so RPR has to avoid it.

This has to be done at the Mode level and not left to `render` plugins.

# Control flags
The control flags have mostly been described in [Milestones](Milestones.md). They are summarised here again, with some extra information.

*  **recompile**

Controls the updating and caching of the content files. If true, then all files will be recompiled and cached.

A True value is over-ridden by **without-processing**

Normally False, which allows for only changed files to be processed.

*  **no-refresh**

Prevents the updating of content files, so no changes will be made.

*  **full-render**

Forces all files to be rendered. Even if there are no changes to source files, plugins or templates may be added/changed, thus changing the output, so all files need to be re-rendered.

A True value is over-ridden by **without-processing**

*  **no-report**

Normally, report plugins report on the final state of the output files. No-report prevents report plugins from being loaded or run.

If **without-processing** is set, then the **Report** stage is skipped. If, however, the caches do not exist (deleted or first run), then the value of **without-processing** is ignored and the value of **no-report** is observed.

*  **without-processing**

Unless the caches do not exist, setting **without-processing** to True will skip all the stages except **Completion**

*  **no-cache**

RakuConfig will cache the previous configuration data by default. When testing a module, this is not desirable, so no-cache = True prevents caching.

*  **debug & verbose**

ProcessedPod uses both debug and verbose, so these flags are passed if set.

*  **collection-info**

Causes collect to produce information about milestones and valid and invalid plugins

# Plugin management
Plugins are **Raku** programs that are executed at specific milestones in the rendering process. The milestone are given in [Milestones](Milestones.md) above.

The **plugins-required** key in the Mode's configuration contains a hash with keys whose names are the milestone names. Each key points to a list of plugin names, which are called in the order given.

All plugins must reside within the mode directory given by `plugins`, but this directory may belong to another Collection so that plugins can and should be shared between collections & modes.

All plugin names must be the name of a sub-directory of the **plugins** path. Within each plugin sub-directory, there must be a `config.raku` file containing information for the plugin, and for `Collection`.

With the exception of 'render' plugins, the config file contains a key for the type, which points to the program to be called.

Plugin's may need other configurable data, which should be kept in the config file for the plugin.

The plugin types are as follows.

## Setup
Config hash must contain **setup** which is a path, relative to the plugin's sub-directory, to the Raku program. It must evaluate to a sub that takes a list of five items, eg.,

```
sub ( $source-cache, $mode-cache, Bool $full-render,  $source-root, $mode-root ) { ... }
```
> **$source-cache**  
A Pod::From::Cache object containing the pod of the sources files

> **$mode-cache**  
Like the above for the mode content files

> **$full-render**  
If True, then the sub should process the cache objects with the .sources method on the cache objects, otherwise with the .list-files method on the cache objects (the .list-files method only provides the files that have changed).

> **$source-root**  
This path must be prepended to any sources added (see below) to the cache, otherwise they will not be added to the destination file.

> **$mode-root**  
Likewise for the mode sources.

New files can be added to the cache object inside the sub using the `.add` method, see [Sources](Sources.md).

## Render
This is the exception to the rule that the config provides a callable. The Collection plugin-manager calls the `ProcessedPod.add-plugin` method with the config keys and the path modified to the plugin's subdirectory.

So the config file must have:

*  render (True)

*  name-space => a string that can be used to store data in the `ProcessedPod` object

*  custom-raku => a Raku program that evaluates to an array of custom blocks

*  template-raku => a Raku program that evaluates to a hash of RakuClosure templates

*  data-raku => a Raku program that evaluates to an object assigned to the `ProcessedPod` object's `.plugin-data<name-space> `, where 'name-space' is set above.

It is possible to specify `path` but it must be relative to the plugin's sub-directory.

These plugins provide three sets of configuration programs that alter the templates, custom blocks and plugin space of the `ProcessPod` object. These are evaluated by the `ProcessedPod` object.

## Compilation
The `compilation` key must point to a Raku program that delivers a sub object

```
sub ( $pr, %processed) { ... }
```
> **$pr**  
is the ProcessedPod object rendering the content files.

> **%processed**  
is a hash whose keys are source file names with a hash values containing TOC, Glossary, Links, Metadata, Footnotes, Templates-used structures produced by B<ProcessedPod>.

## Report
The `report` key points to a Raku file that evaluates to a

```
sub (%processed, @plugins-used, $report-path) {...}
```
> **@plugins-used**  
is an array of Pairs whose key is the milestone and value is a hash of the plugins used and their config parameters.

> **$report-path**  
is the path name relative to the C<mode> directory where report files are produced. The output format of the files is determined by the report plugin.

> **%processed**  
as in Compilation

## Completion
The `report` key points to a Raku file that evaluates to a `sub (@output-files, $destination, $landing-place, $extension) {...}` object.

> **$destination**  
is the name of the output path (defined in the mode configuration)

> **@filenames**  
is a list of the output files (with paths relative to the output path) that are to be presented, in order of evaluation, if this is important. Eg. for a book, the entire order is important, for a website ony the first page is important.

> **$landing-place**  
is the first file to be processed since, eg., for a website, order is not sufficient. name is relative to the destination directory.

**LICENSE** Artistic-2.0







----
Rendered from README at 2021-02-03T11:13:52Z