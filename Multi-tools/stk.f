(* Read Nth element of background task

: MTOS      ( task -- u|n )
    ?task  his trp @ cell+ cell+ @ ;

\ Demo
task: ONE
: TELLER  0 begin  1+ 100 ms  again ;
' teller  one start-task

1 one stk @ . many  \ Read secon stack element (counter)
0  1 one stk  !     \ Clear second stack element

*)

v: inside also extra definitions
: STK       ( +n task -- addr )
    ?task >r  ?dup if               \ Not TOS?
        cells negate                \ Yes, address of Nth element
        r> his s0 @ cell-  +
    else
        r> his trp @ cell+ cell+    \ No, read address TOS
    then ;
v: fresh

\ End
