#lang racket/base
(require racket/string
         racket/match
         racket/function
         syntax/parse/define
         (for-syntax racket/base)
         )

(provide check-eq?     check-eqv?     check-equal?
         check-not-eq? check-not-eqv? check-not-equal?
         check-=
         check-pred
         check-true check-false check-not-false
         #;check-exn check-not-exn
         check-regexp-match
         check-match
         check
         )

(provide with-time-limit)

(struct stx-err (msg site sub-site msg-more) #:transparent)

(define last-check #f)
(define last-check-finished? #t)

;; Run `thunk`, tracking the last check launched, and whether it finished gracefully
(define (track site thunk)
  (set! last-check site)
  (set! last-check-finished? #f)
  (thunk)
  (set! last-check-finished? #t))
(define-syntax-parser ↓ [(_ stx e) #'(track #'stx (λ () e))])

(define (exn-msg-for-stx-err e)
  (string-replace (exn-message e) "\n" "\n                 "))

;; Run `suite` within the time limit, raising timeout as a syntax error
(define (with-time-limit timeout site suite)
  (define c (make-channel))
  (define work-thread (thread (λ ()
                                (with-handlers ([(λ _ #t) (λ (e) (channel-put c e))])
                                  (suite)
                                  (channel-put c 'finished)))))
  (define timing-thread (thread (λ () (sleep timeout) (channel-put c 'timeout))))
  (define result
    (begin0 (channel-get c)
      (kill-thread work-thread)
      (kill-thread timing-thread)))
  (match result
    ['finished (void)]
    ['timeout
     (raise-syntax-error
      #f
      (format "Timeout after ~a second(s)" timeout)
      site
      last-check
      '()
      (if (and last-check last-check-finished?)
          "\n    The highlighted check finished. Timeout happens after it, before any next check."
          ""))]
    [(stx-err msg site sub-site msg-more)
     (raise-syntax-error #f msg site sub-site '() msg-more)]
    [(? exn? e)
     (raise-syntax-error
      #f
      "Exception raised"
      site
      last-check
      '()
      (format "~a~n    Exn message: ~a"
              (if (and last-check last-check-finished?)
                  "\n    The highlighted check finished. Error happens after it, before any next check."
                  "")
              (exn-msg-for-stx-err e)))]
    [_
     (raise-syntax-error #f "Unhandled internal problem" site #f '() (format "~n    Result: ~a" result))]))

;; Only caring about message, site, and extended message for errors
(define (fail msg site sub-site [msg-more ""])
  (raise (stx-err msg site sub-site msg-more)))

;; Wrap any "runtime" error during compile-time tests as compile-time error
(define (handle-as-syntax-error site thunk [sub-site #f])
  (with-handlers ([(λ _ #t)
                   (λ (e)
                     (fail "Exception raised"
                           site
                           sub-site
                           (format "~n    Exn message: ~a" (exn-msg-for-stx-err e))))])
    (thunk)))
(define-syntax-parser ! [(_ e) #'(handle-as-syntax-error #'e (λ () e))])

(define (do-check-equal site =? actual expected)
  (unless (=? actual expected)
    (fail "Not equal" site #f (format "~n    Actual: ~a~n    Expected: ~a" actual expected))))

(define (do-check-nequal site =? lhs rhs)
  (when (=? lhs rhs)
    (fail "Actually equal" site #f (format "~n    1st value: ~a~n    2nd value: ~a" lhs rhs))))

(define (name f) (or (object-name f) f))

(define (guard-procedure-arity n site pred-site pred)
  (unless (procedure? pred)
    (fail "Not a procedure" site pred-site
          (format "~n    Expected: procedure supporting ~a argument(s)~n    Actual: ~a" n (name pred))))
  (define arity (procedure-arity pred))
  (unless (arity-includes? arity n)
    (fail "Wrong arity" pred-site #f (format "~n    Expected supported arity: ~a~n    Actual arity: ~a" n arity))))

(define do-check-pred
  (case-lambda
    [(site pred-site pred v)
     (guard-procedure-arity 1 site pred-site pred)
     (unless (handle-as-syntax-error site (λ () (pred v)))
       (fail "Failed" site #f (format "~n    Predicate: ~a~n    Value: ~a" (name pred) v)))]
    [(site pred-site pred v₁ v₂)
     (guard-procedure-arity 2 site pred-site pred)
     (unless (handle-as-syntax-error site (λ () (pred v₁ v₂)))
       (fail "Failed" site #f (format "~n    Predicate: ~a~n    1st value: ~a~n    2nd value: ~a" (name pred) v₁ v₂)))]))

(define (guard-real site v-site v)
  (unless (real? v)
    (fail "Not real number" site v-site (format "~n    Value: ~a" v))))

(define (do-check-= site v₁-site v₂-site ε-site v₁ v₂ ε)
  (guard-real site v₁-site v₁)
  (guard-real site v₂-site v₂)
  (guard-real site  ε-site ε )
  (unless (<= (abs (- v₁ v₂)) ε)
    (fail "Failed" site #f (format "~n    Actual: ~a~n    Expected: ~a~n    Tolerance: ~a" v₁ v₂ ε))))

(define (do-check-value msg expected? site v-site v)
  (unless (expected? v)
    (fail msg site v-site (format "~n    Value: ~a" v))))

(define (is-true-literal? v) (eq? #t v))

(define (do-check-not-exn site thunk-site thunk)
  (guard-procedure-arity 0 site thunk-site thunk)
  (handle-as-syntax-error site thunk thunk-site))

(define (do-check-regexp-match site regexp-site string-site regexp string)
  (unless (or (regexp? regexp)
              (byte-regexp? regexp)
              (string? regexp)
              (bytes? regexp))
    (fail "Not a regexp" site regexp-site (format "~n    Supposed regexp: ~a" regexp)))
  (unless (or (string? string)
              (bytes? string)
              (path? string))
    (fail "Not a string" site string-site (format "~n    Supposed string: ~a" string)))
  (unless (regexp-match? regexp string)
    (fail "Regexp not matched" site #f (format "~n    Regexp: ~a~n    String: ~a" regexp string))))

(begin-for-syntax
  (define (equal-check =?)
    (syntax-parser
      [(~and stx (_ actual:expr expected:expr))
       #`(↓ stx (do-check-equal #'stx #,=? (! actual) (! expected)))]))

  (define (nequal-check =?)
    (syntax-parser
      [(~and stx (_ v₁:expr v₂:expr))
       #`(↓ stx (do-check-nequal #'stx #,=? (! v₁) (! v₂)))]))

  (define (value-check msg check)
    (syntax-parser
      [(~and stx (_ v:expr)) #`(↓ stx (do-check-value #,msg #,check #'stx #'v (! v)))])))

(define-syntax check-eq?    (equal-check #'eq?))
(define-syntax check-eqv?   (equal-check #'eqv?))
(define-syntax check-equal? (equal-check #'equal?))

(define-syntax check-not-eq?    (nequal-check #'eq?))
(define-syntax check-not-eqv?   (nequal-check #'eqv?))
(define-syntax check-not-equal? (nequal-check #'equal?))

(define-syntax check-true      (value-check "Not literal #t" #'is-true-literal?))
(define-syntax check-false     (value-check "Not false" #'not))
(define-syntax check-not-false (value-check "Actually false" #'values))

(define-syntax-parser check-=
  [(~and stx (_ v₁:expr v₂:expr ε:expr))
   #`(↓ stx (do-check-= #'stx #'v₁ #'v₂ #'ε (! v₁) (! v₂) (! ε)))])

(define-syntax-parser check-pred
  [(~and stx (_ pred:expr v:expr))
   #`(↓ stx (do-check-pred #'stx #'pred (! pred) (! v)))])

(define-syntax-parser check
  [(~and stx (_ pred:expr v₁:expr v₂:expr))
   #`(↓ stx (do-check-pred #'stx #'pred (! pred) (! v₁) (! v₂)))])

(define-syntax-parser check-not-exn
  [(~and stx (_ thunk:expr))
   #`(↓ stx (do-check-not-exn #'stx #'thunk thunk))])

(define-syntax-parser check-regexp-match
  [(~and stx (_ regexp:expr string:expr))
   #`(↓ stx (do-check-regexp-match #'stx #'regexp #'string (! regexp) (! string)))])

(define-syntax-parser check-match
  [(~and stx (_ v:expr pattern (~optional guard #:defaults ([guard #'#t]))))
   #`(↓ stx
        (match (! v)
          [pattern
           (unless (! guard)
             (fail "Guard failed" #'stx #'guard))]
          [value
           (fail "Pattern not matched" #'stx #'pattern (format "~n    Pattern: ~a~n    Value: ~a" 'pattern value))]))])

;; TODO `check-within`
;; TODO `check-exn` not working
