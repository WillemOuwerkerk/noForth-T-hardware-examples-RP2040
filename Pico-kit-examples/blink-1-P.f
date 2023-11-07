(* GPIO

More on SIO chapter 2.3.1 page 27 ff
More on IO user bank chapter 2.19 page 235 ff

*)

hex
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value
D0000004 constant GPIO-IN           \ GPIO input value

: S2?       ( -- f )                \ Flag f is true when S2 is pressed
    3 bitmask GPIO-IN bit** 0= ;

: BLINK     ( -- )                  \ 1 Hz flashing LEDs
    5 dm 29 gpio!                   \ Enable SIO on pin 29
    5 2 gpio!                       \ Enable SIO on pin 2
    5 3 gpio!                       \ Enable SIO on pin 3
    5A 3 pads!                      \ Enable pull-up on pin 3
    [ dm 29 bitmask 2 bitmask or ]  \ LEDs bitmask
    literal  dup GPIO-OE **bis      \ Bits 2 & 29 are output
    2 bitmask GPIO-OUT **bix        \ Toggle red LED
    begin
        dup GPIO-OUT **bix  200 ms  \ Toggle both LEDs
    s2? until                       \ Until the S2 key was pressed
    GPIO-OUT **bic ;                \ LEDs off

\ End
