(*  Alternative UART pins on the Pico using this software
    Single UART, TX on state machine 0 & RX on state machine 1 of PIO 0
*)

\ need piobase\     ( Load the piobase.f file first )

: PIO-PROG      ( -- )
    0000 50300000 !
    1F000 503000CC !
    14000000 503000DC !
    65B9A00 503000C8 !
    34002000 503000DC !
    4001F000 503000CC !
    54102008 503000DC !
    0007 40014044 !
    44102108 503000DC !
    0007 40014044 !
    E081 50300048 !
    4001F080 503000CC !
    9FA0 5030004C !
    F727 50300050 !
    6001 50300054 !
    0643 50300058 !
    40004080 503000CC !
    0000 503000D8 !
    1F000 503000E4 !
    14000000 503000F4 !
    65B9A00 503000E0 !
    901F000 503000E4 !
    14048000 503000F4 !
    005A 4001C028 !
    4048120 503000F4 !
    0007 4001404C !
    E080 5030005C !
    901F300 503000E4 !
    2020 50300060 !
    EA27 50300064 !
    4001 50300068 !
    0648 5030006C !
    00C0 50300070 !
    20A0 50300074 !
    0000 50300078 !
    00CD 50300070 !
    4078 5030007C !
    8020 50300080 !
    000F 50300078 !
    900E300 503000E4 !
    0005 503000F0 !
    0003 50300000 !
    true =pio ;

pio-prog


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
    pio-prog
    ['] pkey to 'key
    ['] pemit to 'emit
    ['] pkey? to 'key? ;

: ORG   ( -- )      \ Use standard RS232 configuration
    ['] key) to 'key
    ['] emit) to 'emit
    ['] key?) to 'key? ;

shield BLUE\  freeze

\ End
