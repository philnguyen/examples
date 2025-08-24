#lang racket/base
(require syntax/parse/define
         (for-syntax racket/base
                     racket/syntax
                     (only-in "check.rkt" with-time-limit)))

(provide with-examples)

(begin-for-syntax
  (define-syntax-class timeout
    #:description "Positive real number of seconds (non-integer ok)"
    [pattern n:number #:when (let ([v (syntax->datum #'n)]) (and (real? v) (> v 0)))]))

(define-syntax-parser with-examples
  [(~and
    suite
    (with-examples
      (names:id ...)
      (~optional (~seq #:timeout t:timeout) #:defaults ([t #'1]))
      body:expr ...))
   #:with (names*:id ...) (map (λ (name) (format-id #'with-examples "~a" name)) (syntax->list #'(names ...)))
   #:with suite-name (format-id #f "~a" (gensym 'suite-))
   #'(begin
       (provide (rename-out [names names*] ...))
       (module* suite-name #f
         (require (for-syntax racket
                              (rename-in (submod "..")
                                         [names* names] ...)))
         (begin-for-syntax
           (with-time-limit t #'suite (λ () body ...)))))])
