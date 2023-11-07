\ Single UART on state machine 0 and PIO 0

v: pio also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

clean-pio  decimal          \ Empty code space mirror
\ With optional Side-set
0 0 {pio                    \ Use state machine-0 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
    115200 =baud            \ 115k2
    26 1 =side-pins  opt    \ GPIO 26 for optional SIDE
    26 1 =out-pins          \ GPIO 26 for OUT & SET
    26 1 =set-pins

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

: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;

\ End
