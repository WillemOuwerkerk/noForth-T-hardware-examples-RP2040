(* E60a - For noForth C&V 200202: I2C driver for SSD1306 
   The SSD1306 is a 0.96 inch 128x64 pixels oled screen using USCI I2C routines. 
   Separate files with a small, big, bold & graphic character set.
*)

hex
: {ol       ( +n -- )       3C device!  {i2write ;  \ Start an oled command: b=00 or old data: b=40
                                                    \ Single byte command: b=80, single byte data: b=C0 
: ol}       ( b -- )        bus!} ;                 \ End an oled stream
: ROW       ( b -- )        C0 1 {ol  ol} ;         \ Single pixel row
: CMD       ( b -- )        80 1 {ol  ol} ;         \ Single byte oled command
: 2CMD      ( b1 b0 -- )    00 2 {ol  bus! ol} ;    \ Dual byte oled command
: >BRIGHT   ( b -- )        81 2cmd ;               \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and  AE or cmd ;      \ Display on/off
: INVERSE   ( flag -- )     1 and  A6 or cmd ;      \ Display black or white

value X  value Y
: XY        ( x y -- )          \ Set OLED column and row
    00 {ol                      \ Command stream
    dup to y  7 and B0 or bus! \ Set page
    dup to x  dup 0F and bus!  \ Set column
    F0 and 4 rshift 10 or ol} ;

: DISPLAY-SETUP ( -- )
    setup-i2c               \ Init. 400kHz USCI I2C
    false on/off            \ Display off
    00 {ol                  \ Start oled-command stream
    0A8 bus!  03F bus!    \ Set multiplexer ratio
    0D3 bus!  000 bus!    \ Display offset = 0
    040 bus!               \ Display starts at line 0
    0A1 bus!               \ Mirror X-axis
    0C8 bus!               \ Mirror Y-axis
    0DA bus!  012 bus!    \ Alternate Com pin map
    0A4 bus!               \ Enable rendering from GDRAM
    0D5 bus!  080 bus!    \ Set oscillator clock
    08D bus!  014 bus!    \ Charge pump on
    0D9 bus!  022 bus!    \ Set precharge cycles to high cap.
    0DB bus!  030 bus!    \ VCOMH voltage to max.
    020 bus!  000 ol}      \ Horizontal display mode, end stream
    C0 >bright              \ Set contrast to 75%
    false inverse           \ Oled in normal mode
    true on/off ;           \ Display on

: &FILL         ( +n b -- ) \ Pattern 'b' to +n columns
    40 {ol   swap           \ Start oled-data stream
    begin                   \ Whole screen buffer
        over bus!          \ Output pattern
    1- ?dup 0= until  i2stop}  drop ;   \ End stream

: .BITROW   ( a +n -- )     \ Output half of +Nx14 (big) character
    0 row  for
        count row  1+       \ Output every second bit row
    next  drop
    0 row ;

: &EOL          ( +n -- )       0 &fill ;

: &ERASE        ( -- )          480 0 &fill ;       \ Erase screen
: &HOME         ( -- )          0 0 xy ;           \ To upper left corner
: &PAGE         ( -- )          &erase  &home ;
: &CR           ( -- )          0 y 2 + xy ;
value O-EMIT                \ OLED emit vector
: &EMIT         ( c -- )        o-emit execute ;
: &SPACE        ( -- )          bl &emit ;
: &SPACES       ( u -- )        for  &space  next ;
: &TYPE         ( a u -- )      bounds ?do  i c@ &emit  loop ;
: &U.           ( n -- )        0 d.str &type &space ;

: &"            ( -- )          \ ." voor OLED
    flyer  postpone s"  postpone &type ;  immediate

: XY"       ( x y ccc -- )      \ XY" voor OLED
    flyer  postpone xy  postpone &" ; immediate

code C>N        ( c -- +n )     \ Convert char to bitmap index number
    9037 ,  80 ,  2802 ,
    4037 ,  80 ,  8037 ,  20 ,  next
end-code

shield SSD1306\  freeze

\ End
