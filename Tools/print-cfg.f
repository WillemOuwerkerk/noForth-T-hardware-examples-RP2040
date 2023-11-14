\ Print the 5 cells noForth-t configuration

: .CFG      ( -- )
    base? >r  decimal
    0 cfg @+    cr ." Clock = " .  ." MHz "
    @+          cr ." UART-" .
    @+          ." at " .  ." Baud "
    @+          cr ." S? is GPIO" .
    @           cr me count type ." , boot = " .
    r> to base? ;

.cfg

\ End
