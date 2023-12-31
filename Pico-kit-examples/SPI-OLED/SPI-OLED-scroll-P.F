(* Primitive SPI OLED text driver with scroll for noForth t

UCA1 = OLED
    (RST=GPIO10, SIMO=GPIO19, CLK=GPIO18, CS=GPIO10, DC=GPIO11)

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
\   begin  2 4003C00C bit** until  4003C008 ! ;
    begin  2 4003C00C bit** until  4003C008 !   \ Space on TX-fifo?
    begin  4 4003C00C bit** until  4003C008 @ drop ; \ RX-fifo not empty?

: {OLED         ( -- )          0A GPIO-BIT **bic ;

: OLED}         ( -- )
    begin  10 4003C00C bit** 0= until \ SPI bus quiet
\   begin  04 4003C00C bit** while 4003C008 @ drop  repeat \ Empty RX-fifo
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
    7 and dup to y                      \ Y is circular
    B0 or {cmd                          \ Yes, set Y line position
    dup to x  2 + dup 0F and spi0-out   \ & set X column (Only for SH1106 = 2 +)
    4 rshift 10 or ol} ;

: OLED-SETUP    ( -- )
    dm 1000 spi0-on          \ 1 MHz SPI
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
   0 0 xy   9 0 do  0 i xy  80 &eol  loop ;

: .BITROW   ( a +n -- )      \ Output half of +Nx14 (big) character
    0 >data for
        count >data 1+       \ Output every second bit row
    next
    drop  0 >data ;

0 value O-EMIT               \ OLED emit vector
: &EMIT         ( c -- )        o-emit execute ;
: &TYPE         ( a u -- )      for  count &emit  next drop ;
: &"            ( -- )          flyer postpone s" postpone &type ; immediate

0 value SCRL                \ Scrolling &CR
: SCROLL    ( +n -- )       \ Rearrange display lines
    D3 {cmd ol} ;           \ ol-2cmd ;

: &PAGE     ( -- )          \ Erase display, line 0 on top
    10 to scrl  0 scroll    \ Reset administration
    &erase  0 0 xy ;        \ Empty display

: &CR       ( -- )          \ New line with scroll functionality
    0 to x  2 +to y         \ To start of next line
    10 +to scrl  scrl 80 >  \ Incr. SCRL is it greater then 80
    if  50 to scrl  then    \ Yes, restore to 50
    scrl 40 > if            \ Screen full?
        0 y 7 and xy  y     \ Keep y in range
        scrl 30 and scroll  \ Rearrange display
        80 &eol  incr y     \ Erase last line
        x y xy  80 &eol  to y \ both rows
    then  x y xy ;          \ Set xy there


\ Partial character set
v: inside definitions
: ||    ( bitrow -- )        \ Read & compile character row
    0  0D parse  10 min bounds
    ?do  2*  i c@ ch X =  -  loop
    b-b  swap c,  c, ;

create 'THIN    \ Start of a character type, original version Albert Nijhof

|| ................
|| ................
|| ................
|| ................
|| ................
|| ................
|| ................

|| ................
|| ................
|| ...X............
|| ..XXX..XXXXXXXXX
|| ...X............
|| ................
|| ................

|| ...........X..X.
|| ............XXXX
|| ..............X.
|| ................
|| ...........X..X.
|| ............XXXX
|| ..............X.

|| .....X...X......
|| ..XXXXXXXXXXXXXX
|| ......X...X.....
|| ......X....X....
|| .......X...X....
|| ..XXXXXXXXXXXXXX
|| ........X...X...

|| .....X.....XX...
|| ....X.....X..X..
|| ...X.....X....X.
|| ..XXXXXXXXXXXXXX
|| ...X.....X....X.
|| ....X...X....X..
|| .....XXX....X...

|| .....X.....XXX..
|| ......X...X...X.
|| .......X...XXX..
|| ........X.......
|| ...XXX...X......
|| ..X...X...X.....
|| ...XXX.....X....

|| ....XXX.........
|| ...X...X....XXX.
|| ..X.....X.XX...X
|| ..X.....XX.....X
|| ..X...XX..X....X
|| ...X.......XXXX.
|| ....X...........

|| ................
|| ................
|| ...........X..X.
|| ............XXXX
|| ..............X.
|| ................
|| ................

|| ................
|| ................
|| ......XXXXXX....
|| ....XX......XX..
|| ...X..........X.
|| ..X............X
|| ................

|| ................
|| ..X............X
|| ...X..........X.
|| ....XX......XX..
|| ......XXXXXX....
|| ................
|| ................

|| ................
|| .......X...X....
|| ........X.X.....
|| .........XXXX...
|| ........X.X.....
|| .......X...X....
|| ................

|| ................
|| .......X........
|| .......X........
|| ....XXXXXXX.....
|| .......X........
|| .......X........
|| ................

|| ................
|| ................
|| X..X............
|| .XXXX...........
|| ...X............
|| ................
|| ................

|| ................
|| .......X........
|| .......X........
|| .......X........
|| .......X........
|| .......X........
|| ................

|| ................
|| ................
|| ...X............
|| ..XXX...........
|| ...X............
|| ................
|| ................

|| ..XX............
|| ....XX..........
|| ......XX........
|| ........XX......
|| ..........XX....
|| ............XX..
|| ..............XX

|| ....XXXXXXXXXX..
|| ...X..........X.
|| ..X....X.......X
|| ..X.....X......X
|| ..X......X.....X
|| ...X..........X.
|| ....XXXXXXXXXX..

|| ..X.........X...
|| ..X..........X..
|| ..X...........X.
|| ..XXXXXXXXXXXXXX
|| ..X.............
|| ..X.............
|| ..X.............

|| ..XXX........X..
|| ..X..X........X.
|| ..X...X........X
|| ..X....X.......X
|| ..X.....X......X
|| ..X......X....X.
|| ..X.......XXXX..

|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ..X............X
|| ..X......X.....X
|| ...X....X.X...X.
|| ....XXXX...XXX..

|| ......XX........
|| ......X.XX......
|| ......X...XXX...
|| ......X......XXX
|| ......X.........
|| ..XXXXXXXXXXXXXX
|| ......X.........

|| ....X.....XXXXXX
|| ...X......X....X
|| ..X.......X....X
|| ..X.......X....X
|| ..X.......X....X
|| ...X.....X.....X
|| ....XXXXX......X

|| ....XXXXXXXXXX..
|| ...X..........X.
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.......
|| ....XXXX........

|| ..XX...........X
|| ....XX.........X
|| ......XX.......X
|| ........XX.....X
|| ..........XX...X
|| ............XX.X
|| ..............XX

|| ....XXXX...XXX..
|| ...X....X.X...X.
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.X...X.
|| ....XXXX...XXX..

|| ..........XXXX..
|| .........X....X.
|| ..X.....X......X
|| ..X.....X......X
|| ..X.....X......X
|| ...X..........X.
|| ....XXXXXXXXXX..

|| ................
|| ................
|| ...X.....X......
|| ..XXX...XXX.....
|| ...X.....X......
|| ................
|| ................
|| ................
|| ................
|| X..X.....X......
|| .XXXX...XXX.....
|| ...X.....X......
|| ................
|| ................

|| .......X........
|| ......X.X.......
|| .....X...X......
|| ....X.....X.....
|| ...X.......X....
|| ..X.........X...
|| ..X.........X...

|| ................
|| .....X...X......
|| .....X...X......
|| .....X...X......
|| .....X...X......
|| .....X...X......
|| ................

|| ..X.........X...
|| ..X.........X...
|| ...X.......X....
|| ....X.....X.....
|| .....X...X......
|| ......X.X.......
|| .......X........

|| .............X..
|| ..............X.
|| ...X...........X
|| ..XXX..XX......X
|| ...X.....X.....X
|| ..........X...X.
|| ...........XXX..

|| ....XXXXXXXXXX..
|| ...X..........X.
|| ..X............X
|| ..X....XXXX....X
|| ..X...X....X...X
|| ..X...X...X...X.
|| ...X...XXXXXXX..

|| ..XXXXXXXXX.....
|| ...........XX...
|| ......X......XX.
|| ......X........X
|| ......X......XX.
|| ......X....XX...
|| ..XXXXXXXXX.....

|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.X...X.
|| ....XXXX...XXX..

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ..X............X
|| ..X............X
|| ...X..........X.

|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X............X
|| ..X............X
|| ...X..........X.
|| ....X........X..
|| .....XXXXXXXX...

|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ..X............X
|| ..X............X

|| ..XXXXXXXXXXXXXX
|| ...............X
|| .........X.....X
|| .........X.....X
|| .........X.....X
|| ...............X
|| ...............X

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ..X......X.....X
|| ...X.....X....X.
|| ....XXXXXX......

|| ..XXXXXXXXXXXXXX
|| ................
|| .........X......
|| .........X......
|| .........X......
|| .........X......
|| ..XXXXXXXXXXXXXX

|| ................
|| ..X............X
|| ..X............X
|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X............X
|| ................

|| ....X...........
|| ...X............
|| ..X............X
|| ...X...........X
|| ....XXXXXXXXXXXX
|| ...............X
|| ...............X

|| ..XXXXXXXXXXXXXX
|| ................
|| ........X.......
|| ........XX......
|| ......XX..XX....
|| ....XX......XX..
|| ..XX..........XX

|| ..XXXXXXXXXXXXXX
|| ..X.............
|| ..X.............
|| ..X.............
|| ..X.............
|| ..X.............
|| ..X.............

|| ..XXXXXXXXXXXXXX
|| ..............X.
|| .............X..
|| ...........XX...
|| .............X..
|| ..............X.
|| ..XXXXXXXXXXXXXX

|| ..XXXXXXXXXXXXXX
|| ...........X....
|| .........XX.....
|| .......XX.......
|| .....XX.........
|| ....X...........
|| ..XXXXXXXXXXXXXX

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ...X..........X.
|| ....X........X..
|| .....XXXXXXXX...

|| ..XXXXXXXXXXXXXX
|| ...............X
|| ........X......X
|| ........X......X
|| ........X......X
|| .........X....X.
|| ..........XXXX..

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X.XXXX.......X
|| ...X..........X.
|| ..X.X........X..
|| .X...XXXXXXXX...

|| ..XXXXXXXXXXXXXX
|| ...............X
|| ........X......X
|| .......XX......X
|| .....XX.X......X
|| ...XX....X....X.
|| ..X.......XXXX..

|| ....X......XXX..
|| ...X......X...X.
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.....X.
|| ....XXXX.....X..

|| ...............X
|| ...............X
|| ...............X
|| ..XXXXXXXXXXXXXX
|| ...............X
|| ...............X
|| ...............X

|| ....XXXXXXXXXXXX
|| ...X............
|| ..X.............
|| ..X.............
|| ..X.............
|| ...X............
|| ....XXXXXXXXXXXX

|| .......XXXXXXXXX
|| .....XX.........
|| ...XX...........
|| ..X.............
|| ...XX...........
|| .....XX.........
|| .......XXXXXXXXX

|| ...XXXXXXXXXXXXX
|| ..X.............
|| ...X............
|| ....XXX.........
|| ...X............
|| ..X.............
|| ...XXXXXXXXXXXXX

|| ................
|| ................
|| ................
|| ................
|| ................
|| ................
|| ................
align

: THIN-EMIT ( c -- )            \ Only valid for uppercase characters!
    BL -  80 x -  dup 9 < if    \ Character does not fit?
      dup &eol                  \ Yes, erase to end Of Line
      x y 1+ xy  dup &eol       \ Erase end of next line too
      0 y 1+ xy                 \ To start of new line
    then  drop
    0E * 'thin +  dup 7 .bitrow \ First half of big char
    x y 1+ xy 1+  7 .bitrow     \ Second half of big char
    x 09 + y 1-  xy ;           \ x & y to new char position

v: extra definitions
: THIN      ( -- )      ['] thin-emit to o-emit ;

: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us  \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=         \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;       \ QSPI pin-SS peripheral function again

: DEMO      ( -- )
    oled-setup  thin        \ Init. OLED & select char. type
    &page  FF ms            \ Wipe screen
    begin
        &cr &" PROJECT"    80 ms
        &cr &"    FORTH"   80 ms
        &cr &"       WORKS"
        10 0 do
            40 ms  bootkey?
            if leave then
         loop
    bootkey? until  &page ; \ Until a key was pressed

v: fresh
\ ' demo  to app
shield SPI-OLED\  \ freeze

\ End ;;;
