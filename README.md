# Raku Collection Module
>A collection of subroutines to collect, cache, render, and output content files written in POD6. Output can a CRO app creating a website available in a browser at localhost:3000, or an epub.


----
## Table of Contents
[Liscense](#liscense)  
[Head](#head)  
[Head](#head)  

----
# LISCENSE

Artist 2.0

This module is used by Raku-Alt-Documentation, but is intended to be more general, such as builing a blog site.

# head

Installation

```
zef install Document-Collection
```
# head

Usage

The Raku-Alt-Documentation module should be viewed for a concrete example.

The Collection module expects there to be a config.raku file in the root of the collection, which provides information about how to obtain the Pod6 sources, a default Mode to render and output the collection.

If no 'config.raku' file exists in the current directory, then it will call MAIN('init'). So a collection module would be used by a program that has a `multi sub MAIN('Init', @*)` defined.








----
Rendered from README at 2021-01-22T19:12:35Z