(* Primitive SPI OLED text driver

UCA1 = OLED
    (RST=GPIO10, SIMO=GPIO19, CLK=GPIO18, CS=GPIO10, DC=GPIO11)

*)

\ OLED primitives
v: inside also  definitions
hex
0 value INV?                \ Partly inverted display?
: INV       ( b1 -- b2 )    inv? invert xor ;
: WHITE     ( -- )          true to inv? ;
: BLACK     ( -- )          false to inv? ;

: COMM      ( -- )          0B GPIO-BIT **bic ;      \ OLED command
: DATA      ( -- )          0B GPIO-BIT **bis ;      \ OLED screen data
: {CMD      ( b -- )        comm  {spi0  spi0-out ;  \ Start OLED command stream
: {DATA     ( b -- )        data  {spi0  spi0-out ;  \ Start OLED data stream
: >DATA     ( b -- )        inv  {data  spi0} ;      \ Output one pixel row
\ : DATA}     ( b -- )        >data  spi0} ;
: OL}       ( b -- )        spi0-out spi0} ;         \ End an OLED stream
: >BRIGHT   ( b -- )        81 {cmd ol} ;            \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and AE or {cmd spi0} ; \ Display on/off
: INVERSE   ( flag -- )     1 and A6 or {cmd spi0} ; \ Display black or white
v: extra definitions

0 value X  0 value Y
: XY        ( x y -- )
    7 and dup to y                      \ Y is circular
    B0 or {cmd                          \ Yes, set Y line position
    dup to x  2 + dup 0F and spi0-out   \ & set X column (Only for SH1106 = 2 +)
    4 rshift 10 or ol} ;

: DISPLAY-SETUP    ( -- )
    dm 4000 spi0-on          \ 4 MHz SPI
    0A GPIO-BIT **bis        \ P2DIR     Init CS=1
    0B GPIO-BIT **bis        \ P2DIR     Init DC=1
    0C GPIO-BIT **bis 2 us   \ P2DIR     Init RES=1
    0C GPIO-BIT **bic  1 ms  0C GPIO-BIT **bis \ Hardware reset of OLED
    false on/off             \ Display off
    D5 {cmd  080 spi0-out    \ Set oscillator clock
    A8 spi0-out  3F spi0-out \ Set multiplexer ratio
    D3 spi0-out  00 spi0-out \ Display offset = 0
    40 spi0-out              \ Display starts at line 0
\   8D spi0-out  14 spi0-out \ Charge pump on (not for SH1106)
\   20 spi0-out  02 spi0-out \ Horizontal display mode (not for SH1106)
    A1 spi0-out              \ Mirror X-axis (segment remap)
    C8 spi0-out              \ Mirror Y-axis (COM scan dirction)
    DA spi0-out  12 spi0-out \ Alternate Com pin map  optional: 012 -> 02
    D9 spi0-out  F1 spi0-out \ Set precharge cycles to high cap: F1 was 022
    DB spi0-out  40 spi0-out \ VCOMH voltage to max: 40 mwas 30
    A4 spi0-out  E3 ol}      \ Enable rendering from GDRAM, end stream
    80 >bright               \ Set brightness to 50%
    false inverse  white     \ Oled in normal mode
    true on/off ;            \ Display on

: &FILL     ( +n b -- )      \ Fill +n rows with 'b'
    swap for  dup >data  next  drop ;

: .BITROW   ( a +n -- )      \ Output half of +Nx14 (big) character
    0 >data for
        count >data 1+       \ Output every second bit row
    next
    drop  0 >data ;

: &ERASE        ( -- )       \ Empty whole screen
   0 0 xy   9 0 do  0 i xy  80 0 &fill  loop ;

: &EOL          ( +n -- )       for  0 >data  next ;
: &PAGE         ( -- )          &erase  0 0 xy ; \ To upper left corner
0 value O-EMIT               \ OLED emit vector
: &EMIT         ( c -- )        o-emit execute ;
: &SPACE        ( -- )          bl &emit ;
: &SPACES       ( u -- )        0 do  &space  loop ;
: &TYPE         ( a u -- )      for  count &emit  next drop ;
: &U.           ( n -- )        0 <# #s #> &type &space ;
: C>N           ( c -- +n )     bl - ;  \ Convert char to bitmap index number
: &"            ( -- )          flyer  postpone s"  postpone &type ; immediate


: XY"       ( x y ccc -- )      \ XY" voor OLED
    flyer  postpone xy  postpone &" ; immediate


v: fresh
shield SSD1306-SPI\  \ freeze

\ End ;;;
