\ Print the 5 cells noForth-T configuration

need >nfa

V: fresh inside
: .CFG      ( -- )
    base @  decimal
    0 cfg @+  H-H  cr ." Clock = "  u.  ." MHz "  hx FF and >r
    5 cfg @ ['] noop = if     ( Default configuration? )
        @+  cr ." UART-" hx 40034000 -  14 rshift .
    else
        @+ drop cr ." USB-CDC "
    then
    @+          ." at " dm u.  ." Baud "
    r>          cr ." S? is on GPIO" dm .
    @+          ." & GPIO-address " hex u.
    @+          cr me count type
    drop       ." , runs on core " hx D0000000 @ .
    @           cr ." Config extension word = " >nfa count type
    base ! ;

v: fresh
.cfg

\ End
