(* A simple test program

    Uses the Hayes syntax, but is noForth specific

    T{ 1 2 3 swap -> 1 3 2 }T
    T{ DEPTH -> 0 }T

*)

hex
v: inside also definitions
create RESULTS  20 cells allot  \ Stack results, max: 32
0 value STACK-OUT               \ Stack after test
0 value #ERRORS                 \ Note incorrect results

v: forth definitions
: SOURCE      ( -- a u )        ib #ib ;                \ input stream

v: inside definitions
: CORRECT-STACK ( i*x -- j*x )  \ correct stack depth
    depth 0< if                 \ underflow?
        depth abs for 0 next exit
    then                        \ no, correct overflow
    depth for  drop  next ;

: ERROR     ( c-addr u -- )     \ display an error message
   incr #errors                 \ followed by the line that had the error
   type source type cr          \ display line corresponding to error
   correct-stack ;              \ Restore stack depth

v: extra definitions
: T{          ( i*x -- i*x d )  correct-stack ;         \ Start test
: TESTING     ( -- )            postpone \ ;            \ Test comment
: CLR-ERRORS  ( -- )            0 to #errors ;          \ Reset error counter
: .ERRORS     ( -- )            #errors . ;             \ Show number of errors

: ->        ( i*x -- j*x )      \ Store test result
    depth to stack-out          \ record depth
    depth 0 ?do                 \ save them
        results i cells + !
    loop ;

: }T        ( i*x -- j*x )      \ Compare & show test errors if any
    depth stack-out <> if                           \ depths not match?
        s" Wrong number of results: " error  exit   \ yes, depth mismatch!
    then
    depth 0 ?do                     \ for each stack item
        results i cells + @ <> if   \ is actual value not as expected?
            s" Incorrect results: " \ ok, issue mismatch
            error  leave
        then
    loop ;

v: fresh
shield TESTER\

\ End
