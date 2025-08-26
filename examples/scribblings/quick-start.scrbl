#lang scribble/manual
@require[@for-label[racket/base racket/match racket/contract examples]]

@title{Defining a test suite}

@defform*[((with-examples (name:id ...) body ...)
           (with-examples (name:id ...) #:timeout timeout:number body ...))]{
Opens a fresh compile-time test suite that can refer to the @racket[name]s from the enclosing module,
even private helpers not meant to be provided publically.

The @racket[(body ...)] can run arbitrary code. Runtime errors and timeout within the body will be handled as syntax
errors. The default timeout applied for each entire suite is one second, and can be customized with
@racket[timeout] as a positive real number.

For example, the following program raises a syntax error on the faulty @racket[factorial] implementation,
highlighting the first failing test case.
@racketmod[
racket/base
(require examples)

(define (factorial n)
  (if (< n 2) 1 (* n (- n 1))))

(with-examples (factorial)
  (check-equal? (factorial 0) (*))
  (check-equal? (factorial 1) (* 1))
  (check-equal? (factorial 2) (* 1 2))
  (check-equal? (factorial 3) (* 1 2 3))
  (check-equal? (factorial 4) (* 1 2 3 4)))
]

Note that while test suites can appear to "modify state", they are merely modifying their own
instantiations "in a separate timeline". In the following example, each test suite observes its
own version of the state, which is also distinct from the @racket[state] initialized at runtime.

@racketmod[
racket/base
(require examples)

(define state (box 0))

(with-examples (state)
  (check-equal? (unbox state) 0)
  (set-box! state 1)
  (check-equal? (unbox state) 1))

(with-examples (state)
  (check-equal? (unbox state) 0)
  (set-box! state 2)
  (check-equal? (unbox state) 2))

(module+ main
  (printf "Init state: ~a~n" (unbox state)))
]
}
