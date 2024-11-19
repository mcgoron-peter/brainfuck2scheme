# Brainfuck2Scheme

A simple compiler from Brainfuck to R5RS. The compiler will output a Scheme
list that is a lambda with three arguments:

* `data`: The data vector.
* `dptr`: The initial data pointer.
* `debugger`: Debugger function

To turn the list into an executable Scheme function, just give it to
`eval`. `(execute scheme len)` will run the Scheme code in `scheme`
with a data vector of length `len`.

This dialect of Brainfuck supports `#` to call the `debugger` procedure
with `data` and `dptr` as arguments.

Since Brainfuck programs become Scheme procedures, you can modularize
Brainfuck code and (ab)use the debugger for things like procedure calls
and foreign libraries.

## How It Works

Brainfuck is a very simple Harvard architecture computer. The data is
stored as a vector `data` and the data pointer is an integer `dptr`.
The big idea is that all the code is compiled to a big lambda form, but
there are some wrinkles due to jumps.

Data access brainfuck instructions are translated like

* `+` -> `(vector-set! data dptr (+ 1 (vector-ref data dptr)))`
* `-` -> `(vector-set! data dptr (+ -1 (vector-ref data dptr)))`
* `>` -> `(set! dptr (+ dptr 1))`
* `<` -> `(set! dptr (- dptr 1))`
* `.` -> `(display (vector-ref data dptr))`
* `,` -> `(vector-set! data dptr (read-char))`
* `#` -> `(debugger data dptr)`

Branches are trickier. Basically, all code that will be executed in a block
is in a lambda. Given `[code...]`, the `code...` will be compiled to a
lambda in a `letrec`, with a conditional at the end that will tail-call the
lambda if the current data pointer is not zero.

The transformation then goes like

`[ CODE ... ] REST ...` ->

    (letrec ((between (lambda ()
                        (TRANSLATE CODE ...)
                        (if (not (zero? (vector-ref data dptr)))
                            (between)))))
      (if (not (zero? (vector-ref data dptr)))
          (between)))
    (TRANSLATE REST ...)

where `(TRANSLATE CODE ...)` translates `CODE` to Scheme instructions
like above.
