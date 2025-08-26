#lang scribble/manual
@require[@for-label[racket/base examples]]

@title{Compile-time tests}

@author[(author+email "Phil Nguyen" "philnguyen0112@gmail.com")]

@defmodule[examples]

This library allows writing compile-time unit tests,
so that tests provide programmers with instant and prominent feedback similar
to a type system.
IDEs and editors such as DrRacket, Emacs, or VS Code should highlight test failures
the same way they highlight other syntax errors.

@table-of-contents[]

@include-section["quick-start.scrbl"]
@include-section["rackunit.scrbl"]
