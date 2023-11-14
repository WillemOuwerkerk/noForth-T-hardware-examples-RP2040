(* Primitive SPI OLED text driver with scroll

UCA1 = OLED
    (RST=GPIO10, SIMO=GPIO19, CLK=GPIO18, CS=GPIO10, DC=GPIO11)

: T1
    &page  0  begin
        dup &u.  &cr 1+ .s
    key bl <> until  drop ;

*)

hex
v: inside also definitions
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value

: GPIO-BIT  ( gpio -- msk adr ) bitmask GPIO-OUT ;

: KHZ>          ( khz -- div1 div2 )
    0 cfg @ dm 1,000 *  swap /                  \ Calculate divisor
    dup FF < if  7E and  0000  exit  then       \ 254 or smaller
    dup 6000 < if  19 /  1800  exit  then       \ 6000 or smaller
    dup dm 64770 < if  FA /  F900  exit  then   \ 64770 or smaller
    ?abort ;    \ Unable to calculate divider settings!

: 'SPI          ( 0|1 -- a )    \ Select SPI base address
    1 = 4000 and  4003C000 + ;

: SPI-MASTER    ( khz 0|1 -- )
    'spi >r                 \ Select SPI hardware
    khz>  0007 or  r@ !     \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 r@ cell+ **bic        \ SSPCR1    Disable SSE
    2 r@ cell+ !            \ SSPCR1    Synchronous master
    r> 10 + ! ;             \ SSPCPSR   clock prescaler

\ SPI-0 on GPIO 17 to 19  (rx, csn, sck, tx)
: SPI0-ON       ( khz -- )
    5 11 gpio!              \ GPIO17 to 19 for SPI0
    1 12 gpio!  1 13 gpio!
    0A bitmask GPIO-OE **bis \ Bit-10 is CS
    0B bitmask GPIO-OE **bis \ Bit-11 is DC
    0C bitmask GPIO-OE **bis \ Bit-12 is RES
    0 spi-master ;

: SPI0-OUT      ( b1 -- )
    begin  2 4003C00C bit** until  4003C008 !   \ Space on TX-fifo?
    begin  4 4003C00C bit** until  4003C008 @ drop ; \ RX-fifo not empty?

: {OLED         ( -- )          0A GPIO-BIT **bic ;

: OLED}         ( -- )
    begin  10 4003C00C bit** 0= until \ SPI bus quiet
    0A GPIO-BIT **bis ;


v: fresh


\ OLED primitives
v: inside also  definitions
: COMM      ( -- )          0B GPIO-BIT **bic ;      \ OLED command
: DATA      ( -- )          0B GPIO-BIT **bis ;      \ OLED screen data
: {CMD      ( b -- )        comm  {OLED  spi0-out ;  \ Start OLED command stream
: {DATA     ( b -- )        data  {OLED  spi0-out ;  \ Start OLED data stream
: OL}       ( b -- )        spi0-out OLED} ;         \ End an OLED stream
: >BRIGHT   ( b -- )        81 {cmd ol} ;            \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and AE or {cmd OLED} ; \ Display on/off
: INVERSE   ( flag -- )     1 and A6 or {cmd OLED} ; \ Display black or white
: >DATA     ( b -- )        {data  OLED} ;           \ Output one pixel row
v: extra definitions
: &EOL      ( +n -- )       for  0 >data  next ;     \ Fill +n rows with zero

0 value X  0 value Y
: XY        ( x y -- )
    7 and dup to y                      \ Y is circular &
    B0 or {cmd                          \ Set Y line position
    dup to x  2 + dup 0F and spi0-out   \ set X column (Only for SH1106 = 2 +)
    4 rshift 10 or ol} ;

: OLED-SETUP    ( -- )
    dm 1000 spi0-on          \ 4 MHz SPI
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
    false inverse            \ Oled in normal mode
    true on/off ;            \ Display on

: &ERASE        ( -- )       \ Empty whole screen
   0 0 xy   8 for  0 i xy  80 &eol  next ;

: .BITROW   ( a +n -- )      \ Output half of +Nx14 (big) character
    0 >data for
        count >data 1+       \ Output every second bit row
    next
    drop  0 >data ;

0 value O-EMIT               \ OLED emit vector
: &EMIT         ( c -- )        o-emit execute ;
: &TYPE         ( a u -- )      for  count &emit  next drop ;
: &"            ( -- )          flyer postpone s" postpone &type ; immediate
: &U.           ( n -- )        0 <# #s #> &type bl &emit ;

0 value SCRL                \ Scrolling &CR
: SCROLL    ( +n -- )       \ Rearrange display lines
    D3 {cmd ol} ;           \ ol-2cmd ;

: &PAGE     ( -- )          \ Erase display, line 0 on top
    8 to scrl  0 scroll     \ Reset scroll administration
    &erase  0 0 xy ;        \ Empty display

: &CR       ( -- )          \ New line with scroll functionality
    0 to x  incr y          \ To start of next line
    8 +to scrl  scrl 80 >   \ Incr. SCRL is it greater then 88
    if  48 to scrl  then    \ Yes, restore to 58
    scrl 40 > if            \ Screen full?
        0 y xy  y           \ New line, save Y
        scrl 38 and scroll  \ Rearrange display
        80 &eol  to y       \ Erase scrolled line
    then  x y xy ;          \ Set xy there


v: inside definitions
: |     ( bitrow -- )
    0  0D parse  8 umin bounds
    do  2*  i c@ ch X =  -  loop  c, ;

\ Small tokens of 5x8 bits
create TINY
| ........      \ Special tokens-1
| ........
| ........
| ........
| ........

| ........
| ........
| .X..XXXX
| ........
| ........

| ........
| .....XXX
| ........
| .....XXX
| ........

| ...X.X..
| .XXXXXXX
| ...X.X..
| .XXXXXXX
| ...X.X..

| ..X..X..
| ..X.X.X.
| .XXXXXXX
| ..X.X.X.
| ...X..X.

| ..X...XX
| ...X..XX
| ....X...
| .XX..X..
| .XX...X.

| ..XX.XX.
| .X..X..X
| .X.X.X.X
| ..X...X.
| .X.X....

| ........
| ........
| .....X.X
| ......XX
| ........

| ........
| ...XXX..
| ..X...X.
| .X.....X
| ........

| ........
| .X.....X
| ..X...X.
| ...XXX..
| ........

| ...X.X..
| ....X...
| ..XXXXX.
| ....X...
| ...X.X..

| ....X...
| ....X...
| ..XXXXX.
| ....X...
| ....X...

| ........
| ........
| .X.X....
| ..XX....
| ........

| ....X...
| ....X...
| ....X...
| ....X...
| ....X...

| ........
| ........
| .XX.....
| .XX.....
| ........

| ..X.....
| ...X....
| ....X...
| .....X..
| ......X.

| ..XXXXX.      \ Numbers & number tokens
| .X.....X
| .X..X..X
| .X.....X
| ..XXXXX.

| ........
| .X....X.
| .XXXXXXX
| .X......
| ........

| .X....X.
| .XX....X
| .X.X...X
| .X..X..X
| .X...XX.

| ..X....X
| .X.....X
| .X...X.X
| .X..X.XX
| ..XX...X

| ...XX...
| ...X.X..
| ...X..X.
| .XXXXXXX
| ...X....

| ..X..XXX
| .X...X.X
| .X...X.X
| .X...X.X
| ..XXX..X

| ..XXXX..
| .X..X.X.
| .X..X..X
| .X..X..X
| ..XX....

| .......X
| .XXX...X
| ....X..X
| .....X.X
| ......XX

| ..XX.XX.
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX.XX.

| .....XX.
| .X..X..X
| .X..X..X
| ..X.X..X
| ...XXXX.

| ........
| ........
| ..XX.XX.
| ..XX.XX.
| ........

| ........
| ........
| .X.X.XX.
| ..XX.XX.
| ........

| ........
| ....X...
| ...X.X..
| ..X...X.
| .X.....X

| ...X.X..
| ...X.X..
| ...X.X..
| ...X.X..
| ...X.X..

| ........
| .X.....X
| ..X...X.
| ...X.X..
| ....X...

| ......X.
| .......X
| .X.X...X
| ....X..X
| .....XX.

| ..XX..X.
| .X..X..X
| .XXXX..X
| .X.....X
| ..XXXXX.

| .XXXXXX.      \ Capitals
| ....X..X
| ....X..X
| ....X..X
| .XXXXXX.

| .XXXXXXX
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX.XX.

| ..XXXXX.
| .X.....X
| .X.....X
| .X.....X
| ..X...X.

| .XXXXXXX
| .X.....X
| .X.....X
| .X.....X
| ..XXXXX.

| .XXXXXXX
| .X..X..X
| .X..X..X
| .X..X..X
| .X.....X

| .XXXXXXX
| ....X..X
| ....X..X
| ....X..X
| .......X

| ..XXXXX.
| .X.....X
| .X..X..X
| .X..X..X
| ..XXX.X.

| .XXXXXXX
| ....X...
| ....X...
| ....X...
| .XXXXXXX

| ........
| .X.....X
| .XXXXXXX
| .X.....X
| ........

| ..XX....
| .X......
| .X.....X
| ..XXXXXX
| .......X

| .XXXXXXX
| ....X...
| ...X.X..
| ..X...X.
| .X.....X

| .XXXXXXX
| .X......
| .X......
| .X......
| .X......

| .XXXXXXX
| ......X.
| ....XX..
| ......X.
| .XXXXXXX

| .XXXXXXX
| ......X.
| .....X..
| ....X...
| .XXXXXXX

| ..XXXXX.
| .X.....X
| .X.....X
| .X.....X
| ..XXXXX.

| .XXXXXXX
| ....X..X
| ....X..X
| ....X..X
| .....XX.

| ..XXXXX.
| .X.....X
| .X.X...X
| ..X....X
| .X.XXXX.

| .XXXXXXX
| ....X..X
| ...XX..X
| ..X.X..X
| .X...XX.

| .X...XX.
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX...X

| .......X
| .......X
| .XXXXXXX
| .......X
| .......X

| ..XXXXXX
| .X......
| .X......
| .X......
| ..XXXXXX

| ...XXXXX
| ..X.....
| .X......
| ..X.....
| ...XXXXX

| ..XXXXXX
| .X......
| ..XXX...
| .X......
| ..XXXXXX

| .XX...XX
| ...X.X..
| ....X...
| ...X.X..
| .XX...XX

| .....XXX
| ....X...
| .XXX....
| ....X...
| .....XXX

| .XX....X
| .X.X...X
| .X..X..X
| .X...X.X
| .X....XX

| ........     \ Special tokens-2
| .XXXXXXX
| .X.....X
| .X.....X
| ........

| ......X.
| .....X..
| ....X...
| ...X....
| ..X.....

| ........
| .X.....X
| .X.....X
| .XXXXXXX
| ........

| .....X..
| ......X.
| .......X
| ......X.
| .....X..

| X.......
| X.......
| X.......
| X.......
| X.......

| ........
| .......X
| ......X.
| .....X..
| ........

| ..X.....     \ Lower case
| .X.X.X..
| .X.X.X..
| .X.X.X..
| .XXXX...

| .XXXXXXX
| .X..X...
| .X...X..
| .X...X..
| ..XXX...

| ..XXX...
| .X...X..
| .X...X..
| .X...X..
| ..X.....

| ..XXX...
| .X...X..
| .X...X..
| .X..X...
| .XXXXXXX

| ..XXX...
| .X.X.X..
| .X.X.X..
| .X.X.X..
| ...XX...

| ....X...
| .XXXXXX.
| ....X..X
| .......X
| ......X.

| ...XX...
| X.X..X..
| X.X..X..
| X.X..X..
| .XXXXX..

| .XXXXXXX
| ....X...
| .....X..
| .....X..
| .XXXX...

| ........
| .X...X..
| .XXXXX.X
| .X......
| ........

| .X......
| X.......
| X....X..
| .XXXXX.X
| ........

| .XXXXXXX
| ...X....
| ..X.X...
| .X...X..
| ........

| ........
| .X.....X
| .XXXXXXX
| .X......
| ........

| .XXXXX..
| .....X..
| ...XX...
| .....X..
| .XXXX...

| .XXXXX..
| ....X...
| .....X..
| .....X..
| .XXXX...

| ..XXX...
| .X...X..
| .X...X..
| .X...X..
| ..XXX...

| XXXXXX..
| ...X.X..
| ...X.X..
| ...X.X..
| ....X...

| ....X...
| ...X.X..
| ...X.X..
| ...XX...
| XXXXXX..

| .XXXXX..
| ....X...
| .....X..
| .....X..
| ....X...

| .X..X...
| .X.X.X..
| .X.X.X..
| .X.X.X..
| ..X.....

| .....X..
| ..XXXXXX
| .X...X..
| .X......
| ..X.....

| ..XXXX..
| .X......
| .X......
| ..X.....
| .XXXXX..

| ...XXX..
| ..X.....
| .X......
| ..X.....
| ...XXX..

| ..XXXX..
| .X......
| ..XX....
| .X......
| ..XXXX..

| .X...X..
| ..X.X...
| ...X....
| ..X.X...
| .X...X..

| ....XX..
| X..X....
| X..X....
| X..X....
| .XXXXX..

| .X...X..
| .XX..X..
| .X.X.X..
| .X..XX..
| .X...X..

| ........     \ Special tokens-3
| ....X...
| ..XX.XX.
| .X.....X
| ........

| ........
| ........
| XXXXXXXX
| ........
| ........

| ........
| .X.....X
| ..XX.XX.
| ....X...
| ........

| ....X...
| .....X..
| ....X...
| ...X....
| ....X...

| ........
| ........
| ........
| ........
| ........
align

v: inside also
: SEMIT   ( +n -- )
    BL -  80 x - dup 6 < if     \ Line full?
        dup &eol  0 y 1+ xy     \ Yes, fill & to next line
    then  drop
    5 * tiny +  ( 6 {data )        \ Go to wanted char
    0  begin
        2dup + c@ >data  1+     \ Display bit row
    dup 5 = until  2drop
    0 >data  x 6 + y xy ;       \ To new char position

v: extra definitions
: SMALL     ['] semit to o-emit ;


\ Example
: SMALLDEMO     ( -- )          \ Display small token set
    oled-setup  small  &page
    dm 30 0 xy &" Egel project"   \ Startup message
    dm 36 2 xy &" Characters"
    dm 48 4 xy &" by W.O."
    key drop  &page
    80 bl do  i &emit  loop     \ Show character set
    key drop  &page
    8 0 do                      \ Display @ pattern
        0 i xy  ( new line )
        i 3 and  1+ for  bl &emit  next
        8 for  ch @ &emit  bl &emit  next
    loop ;


: .BYTE         ( b -- )
    0 <# # # #> &type ;

: DEMO      ( -- )
    oled-setup  small       \ Init. OLED & select char. type
    &page  FF ms  0         \ Wipe screen
    begin
        &cr dup .byte
        &"  PROJECT"         80 ms
        &cr &"       FORTH"  80 ms
        &cr &"          WORKS"
        1+ FF and
        10 0 do
            40 ms  key?
            if leave then
         loop
    key? until  drop  &page ; \ Until a key was pressed

: &CHECK)       ( -- )  \ Check for carrier on selected channel
    [char] -  carrier?  \ Test for carrier on used frequency
    dup ?led            \ Led on when a carrier is seen
    if  A -  then &emit \ Show dash or sharp
    write-mode ;        \ Back to write mode

: &CHECK        ( -- )          \ Check for carriers on all valid channels
    spi-setup  setup24L01       \ Init. 24L01
    oled-setup  small  &page    \ Init. OLED
    &" nRF24" 7 nrf@ 0E <> if  &"  not" then  &"  ok"
    7E 0 do
        i 8 mod 0= if           \ Check key each 8 lines
            key bl <> if leave then \ No space, ready
        then
        i >channel              \ Select channel number 0 to 7D
        &cr  i .byte            \ Show tested channel
        13 for  &check)  next   \ Test #19 times
    loop  setup24l01  read-mode \ Restore nRF24 setup
    key drop  &page ;           \ Clear screen

v: fresh
\ ' demo  to app
shield SPI-OLED\  freeze

\ End ;;;
