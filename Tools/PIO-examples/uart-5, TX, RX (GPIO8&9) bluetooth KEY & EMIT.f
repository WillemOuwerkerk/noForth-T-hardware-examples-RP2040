(*  Alternative UART pins on the Picu using this software
    Single UART, TX on state machine 0 & RX on state machine 1 of PIO 0
*)

v: pio also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
0 1 {pio                    \ Use state machine-0 on PIO-0
    9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
\   460800 =baud            \ 460k8
    8 1 =side-pins  opt     \ GPIO 26 for optional SIDE
    8 1 =out-pins           \ GPIO 26 for OUT & SET
    8 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

1 1 {pio                    \ Use state machine-1 on PIO-0
    9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
\   460800 =baud            \ 460k8
    9 =jmp-pin
    9 =in-pin               \ GPIO 27 for IN & SET
    1 9 1 =inputs           \ Pull-up on input
    9 1 =set-pins

    0 pindirs set,          \ Pin is input!
    wrap-target
        low 0 pin wait,     \ wait for start bit
        10 []  7 x set,     \ Bit counter, delay until bit center
        begin,
            1 pins in,      \ Read next RX bit
        6 []  x--? until,   \ One bit is 8 cycles
        pin? if,            \ Stop bit low?
\           rel 4 irq,      \ Mark error
            high 0 pin wait, \ Restart when RX goes idle again
        else,
            24 null in,     \ Data to low byte
            push,           \ Data ok
        then,
    wrap
    over =exec              \ Start SM-1 UART in program
pio}


\ Send character 'ch' using PIO uart TX
: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;



\ Receive character 'ch' using PIO uart RX
: PKEY? ( -- f )    1 rx-depth 0= 0= ;
: PKEY  ( -- ch )
    begin  pkey? until  1 rxf> ;

: ALT   ( -- )      \ Use GPIO26 & GPIO27 for RS232
    ['] pkey to 'key
    ['] pemit to 'emit
    ['] pkey? to 'key? ;

: ORG   ( -- )      \ Use standard RS232 configuration
    ['] key) to 'key
    ['] emit) to 'emit
    ['] key?) to 'key? ;

\ End
