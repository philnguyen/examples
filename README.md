Statically checked unit tests
===========

```console
raco pkg install examples
```

This library lets Racket programmers write unit tests executed at compile time,
in the same file as the source code, providing interactive feedback similar to a type system.
All editors (e.g. DrRacket, Emacs, VS Code, etc.) will highlight test failures the same way they have
been highlighting other syntax errors.
It is inspired by [`#guard`](https://github.com/leanprover/lean4/blob/8e828216e53de9a676ba6bd3486a96e1eb87de9e/src/Init/Guard.lean)
commands in [Lean](https://lean-lang.org).

![Demo of statically checked examples for `factorial`][demo]

[demo]: https://github.com/philnguyen/examples/blob/main/demo.gif "Demo for `factorial`"

## Example

```racket
#lang racket/base
(require examples)
         
(define (factorial n)
  (if (< n 2) 1 (* n (factorial (- n 1)))))
  
(with-examples (factorial)
  (check-equal? (factorial 4) (* 1 2 3 4)))

```

The `with-examples` form takes the list of names in the same files that it's referring to,
followed by arbitrary Racket expressions.
Forms such as `check-equal?` come from the `examples` package, *not* `rackunit`, although this package
mirrors many of `rackunit`'s [basic checks](https://docs.racket-lang.org/rackunit/api.html#%28part._rackunit~3abasic-checks%29).

Exceptions and timeouts within the `with-examples` block are also caught and raised as syntax errors,
with source locations as specific as possible. By default, each example block has a timeout of 1 second,
applied to the entire block. To customize the timeout, say, to 4.5 seconds, pass `#:timeout 4.5`.

## Reminder on semantics involving mutable state

Behind the scene, `with-examples` opens a throw-away "pocket sub-module" that at its compile time,
imports the enclosing module and executes arbitrary Racket code (including modifying states
and performing IO).

But it's not a thing for the *compile*-time tests to "modify" the (yet initialized!) *runtime* state.
A static test that seems to modify and tests the enclosing state is just testing its own
instantiation "in a separate timeline".

In the following example, each example block has its own version of the enclosing `state`
at compile time, which is also distinct from the actual `state` printed at runtime.

```racket
(define state (box 0))

;; Test suite 1
(with-examples (state)
  (check-equal? (unbox state) 0)
  (set-box! state 1)
  (check-equal? (unbox state) 1))

;; Test suite 2
(with-examples (state)
  (check-equal? (unbox state) 0)
  (set-box! state 2)
  (check-equal? (unbox state) 2))

(printf "Init state: ~a~n" (unbox state)) ; 0
```

## TODO

- [x] Possible to remove the need to explicitly require `(for-syntax racket/base examples)`?
- [ ] Scribblings
- [ ] Other forms of traditional run-time tests (e.g.
[`contract-exercise`](https://docs.racket-lang.org/reference/Random_generation.html#%28def._%28%28lib._racket%2Fcontract..rkt%29._contract-exercise%29%29),
[Redex's Testing](https://docs.racket-lang.org/redex/Testing.html#:~:text=Other%20Relations4.6%C2%A0-,Testing,-4.7%C2%A0GUI4.8)?)
- [ ] Rhombus?
