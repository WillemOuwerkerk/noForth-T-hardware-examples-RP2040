\ Dual UART on state machine 0 & 1 on PIO 0

v: pio also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
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

: *EMIT     ( ch -- )   \ Character to PIO UART-0
    begin  0 tx-depth  3 < until  0 >txf ;

: *TYPE     ( a u -- )  0 ?do  count *emit  loop  drop ;
: ABC       ( -- )      s" ABC " *type ;
: RP2040    ( -- )      s" RP2040 " *type ;


1 0 {pio        \ Uart output on pin 27, 38k4 baud on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    38400 =baud             \ 38k4
    27 1 =side-pins  opt    \ GPIO 27 for optional SIDE
    27 1 =out-pins          \ GPIO 27 for OUT & SET
    27 1 =set-pins
    0 =exec                 \ Start SM-1 at address 0
pio}

: ~EMIT ( ch -- )   \ Character to PIO UART-1
    begin  1 tx-depth  3 < until  1 >txf ;

: ~TYPE     ( a u -- )  0 ?do  count ~emit  loop  drop ;
: BCD       ( -- )      s" BCD " ~type ;
: PICO      ( -- )      s" PICO " ~type ;

\ End 
