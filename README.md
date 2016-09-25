# CodeTools.jl

[![Build Status](https://travis-ci.org/JunoLab/CodeTools.jl.svg?branch=master)](https://travis-ci.org/JunoLab/CodeTools.jl)

CodeTools.jl is a collection of tools for handling Julia code – evaluation, autocompletion etc. – designed to be used as a backend library for IDE support.

It handles things such as:

* Extensible autocompletion
* Pulling code blocks out of files (given a cursor position)
* Finding relevant documentation or method definitions at the cursor
* Detecting the module a file belongs to
* Evaluation of code blocks with correct file, line and module data

If you want any info on using this package as support for another IDE feel free to drop me a line.
