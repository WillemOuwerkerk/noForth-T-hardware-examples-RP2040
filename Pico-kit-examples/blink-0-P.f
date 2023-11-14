(* Pico-kit GPIO example for noForth t

More on SIO chapter 2.3.1 page 27 ff
More on IO user bank chapter 2.19 page 235 ff

*)

hex
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value

dm 2 bitmask  dm 29 bitmask  or     \ Build LEDs control mask
    constant #LEDS

: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us      \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=             \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;           \ QSPI pin-SS peripheral function again

: BLINK     ( -- )                  \ 1 Hz flashing led
    5 dm 29 gpio!   5 dm 2 gpio!    \ Enable SIO on pin 2 & 29
    #leds GPIO-OE **bis             \ Bits are output
    2 bitmask GPIO-OUT **bix        \ Toggle red LED
    begin
        #leds GPIO-OUT **bix 200 ms \ Toggle both LEDs
    bootkey? until                  \ Until the boot key was pressed
    #leds GPIO-OUT **bic ;          \ LEDs off

\ End
