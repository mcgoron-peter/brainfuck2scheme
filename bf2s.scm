;;; Brainfuck->Scheme compiler.
;;; 
;;; Copyright 2024 Peter McGoron
;;; 
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;; 
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;; 
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.

;;; Turn a reversed list of Scheme commands into a thunk.
(define (assemble-function ins)
  `(lambda ()
     ,@(reverse ins)))

;;; Compile all brainfuck instructions in LST, coming after the Scheme
;;; commands in INS.
(define (compile lst ins)
  (if (null? lst)
      (assemble-function ins)
      (case (car lst)
        ((#\>) (compile (cdr lst)
                        (cons '(set! dptr (+ dptr 1)) ins)))
        ((#\<) (compile (cdr lst)
                        (cons '(set! dptr (- dptr 1)) ins)))
        ((#\+) (compile (cdr lst)
                        (cons
                         '(vector-set! data dptr
                                       (+ (vector-ref data dptr) 1))
                         ins)))
        ((#\-) (compile (cdr lst)
                        (cons
                         '(vector-set! data dptr
                                       (- (vector-ref data dptr) 1))
                         ins)))
        ((#\.) (compile (cdr lst)
                        (cons '(display (integer->char (vector-ref data dptr))) ins)))
        ((#\,) (compile (cdr lst)
                        (cons '(vector-set! data dptr
                                            (char->integer (read-char))) ins)))
        ((#\#) (compile (cdr lst)
                        (cons '(debugger data dptr) ins)))
        ((#\[) (let ((rest (compile (cdr lst) '())))
                 (if (not (pair? rest))
                     (error "unmatched [")
                     (let ((between (car rest))
                           (after-uncompiled (cdr rest)))
                       (compile after-uncompiled
                                (cons `(letrec ((between ,between))
                                         (if (not (zero? (vector-ref data dptr)))
                                             (between)))
                                      ins))))))
        ((#\]) (cons (assemble-function
                      (cons '(if (not (zero? (vector-ref data dptr)))
                                 (between))
                            ins))
                     (cdr lst)))
        (else (compile (cdr lst) ins)))))

(define (brainfuck->scheme str)
  `(lambda (data dptr debugger)
     (,(compile (string->list str) '()))))

(define (brainfuck->scheme-from-file filename)
  (brainfuck->scheme
   (call-with-port (open-input-file filename)
     (lambda (port)
       (let loop ((str ""))
         (if (eof-object? (peek-char port))
             str
             (loop (string-append str (read-line port)))))))))

(define (execute scheme len)
  ((eval scheme) (make-vector len) 0
                   (lambda (data dptr)
                     (display (list data dptr))
                     (newline))))
