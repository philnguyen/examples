#lang scribble/manual
@require[@for-label[racket/base racket/match racket/contract examples]]

@title{Checks mirroring RackUnit}

Compared to their counterparts from RackUnit, the checks are all macros instead of procedures.
They have been reimplemented instead of a wrapping RackUnit's utils, in order to
provide fine-grained syntax error locations.

@defform[(check-eq? expr1 expr2)]{
Checks that @racket[expr1] is equal to @racket[expr2], using @racket[eq?].
}

@defform[(check-not-eq? expr1 expr2)]{
Checks that @racket[expr1] is not equal to @racket[expr2], using @racket[eq?].
}

@defform[(check-eqv? expr1 expr2)]{
Checks that @racket[expr1] is equal to @racket[expr2], using @racket[eqv?].
}

@defform[(check-not-eqv? expr1 expr2)]{
Checks that @racket[expr1] is not equal to @racket[expr2], using @racket[eqv?].
}

@defform[(check-equal? expr1 expr2)]{
Checks that @racket[expr1] is equal to @racket[expr2], using @racket[equal?].
}

@defform[(check-not-equal? expr1 expr2)]{
Checks that @racket[expr1] is not equal to @racket[expr2], using @racket[equal?].
}

@defform[(check-= expr1 expr2 epsilon)]{
Checks that @racket[expr2] and @racket[expr2] are numbers within @racket[epsilon] of one another.
It is also an error if @racket[expr1], @racket[expr2], or @racket[epsilon] does not evaluate to a number.
}

@defform[(check-pred pred v)]{
Checks that @racket[pred] returns a value that is not @racket[#f] when applied to @racket[v].
It is also an error if @racket[pred] does not evaluate to a procedure that accepts one argument.
}

@defform[(check-true v)]{
Checks that @racket[v] is @racket[#t].
}

@defform[(check-false v)]{
Checks that @racket[v] is @racket[#f].
}

@defform[(check-not-false v)]{
Checks that @racket[v] is not @racket[#f].
}

@defform[(check-not-exn thunk)]{
Checks that @racket[thunk] does not raise any exception.
It is also an error if @racket[thunk] does not evaluate to a procedure that accepts zero argument.
}

@defform[(check-regexp-match regexp string)]{
Checks that @racket[regexp] matches the @racket[string].
It is also an error if @racket[regexp] is does not evaluate to a value satisfying
@racket[(or/c regexp? byte-regexp? string? bytes?)],
or @racket[string] does not evaluate to a value satisfying
@racket[(or/c string? bytes? path? input-port?)].
}

@defform*[((check-match expr pattern)
           (check-match expr pattern guard))]{
Checks that value produced by @racket[expr] matches against @racket[pattern] as a @racket[match] clause.
If expression @racket[guard] is provided, it is evaluated with the bindings from the matched @racket[pattern].
If it produces a true value, the entire check succeeds, otherwise it fails.
}
