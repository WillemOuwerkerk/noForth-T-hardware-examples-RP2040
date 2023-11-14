(* SSD1351 driver, with help from the source of author: N0082

First send a command 5Ch, DC is low, then DC to high and
always send 2Bytes color values.

2 Bytes color coding:
    ___high____|low______|
      00000|000000|00000 |
    __red__|green_|_blue_|
    0...31 |0..63 |0...31|

*)


(* First the SPI-0 driver on GPIO16 to GPIO19

    4003C000    - SPI0_BASE
    40040000    - SPI1_BASE
    40014000    - IO_BANK0_BASE

    SPI is chapter 4.4 from page 503 ff
*)

hex  v: inside also definitions
: KHZ>          ( khz -- div1 div2 )
    0 cfg @ dm 1,000 *  swap /                    \ Calculate divisor
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

v: extra definitions
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value
: DATA          ( -- )          0B bitmask gpio-out **bis ; \ GPIO11 = DC
: COMM          ( -- )          0B bitmask gpio-out **bic ;
: {SPI          ( -- )          0A bitmask gpio-out **bic ; \ GPIO10 = CS
: SPI}          ( -- )
    begin  10 4003C00C bit** 0= until \ SPI no longer busy?
    0A bitmask gpio-out **bis ;

: RESET-OLED    ( -- )
    0C bitmask  gpio-out  2>r
    2r@ **bis  10 ms  2r@ **bic
    4 us  2r> **bis  100 ms ;

\ SPI-0 on GPIO16=RX, 17=CS, 18=SCK, 19=TX  (miso, csn, sck, mosi)
\ GPIO12=RES, 11=DC, 10=CSN ( separate chip select )
: SPI0-ON       ( khz -- )
    1 10 gpio!  5 0A gpio!      \ GPIO16 to 19 for SPI0
    1 12 gpio!  1 13 gpio!
    5 0C gpio!  5 0B gpio!      \ Activate RES & DC
    0A bitmask  gpio-oe **bis   \ Enable CS output -10-
    0B bitmask  gpio-oe **bis   \ Enable DC output -11-
    0C bitmask  gpio-oe **bis   \ Enable RESET output -12-
    0 spi-master  reset-oled  data  spi} ; \ Set in data mode

: >OL           ( b1 -- )
    4003C008 >r
    begin  2 r@ cell+ bit** until  r@ !
    begin  4 r@ cell+ bit** until  r> @ drop ;


(* SSD1351 initialisation
Command  Data
     FD  12
     FD  B1
     AE  --
     B3  F0
     B3  F0
     CA  7F
     A0  74
     A1  00
     A2  00
     B5  00
     AB  01
     A6  --
     C1  FF FF FF
     C7  0F
     B2  A4 00 00
     AF  --
*)

hex
v: extra definitions
: {OL       ( b -- )        {spi  >ol ;             \ Start an oled command/data stream
: OL}       ( b -- )        >ol  spi} ;             \ End an oled stream
: {CMD      ( b -- )        comm  {ol  data ;       \ Start oled command string
: ROW       ( b -- )        5C {cmd  ol} ;          \ Single pixel
: CMD       ( b -- )        {cmd  spi} ;            \ Single byte oled command
: 2CMD      ( b c -- )      {cmd  ol} ;             \ Dual byte oled command
: >BRIGHT   ( b b b -- )    C1 {cmd  >ol >ol ol} ;  \ b = 0 to 255, max. brightness
: ON/OFF    ( flag -- )     1 and  AE or cmd ;      \ Display on/off
: INVERSE   ( flag -- )     1 and  A6 or cmd ;      \ Display black or white

: >COL      ( e s -- )      15 {cmd >ol ol} ;       \ Picture length
: >ROW      ( e s -- )      75 {cmd >ol ol} ;       \ Picture height

0 value O-EMIT
: &EMIT     ( c -- )        o-emit execute ;

0 value X  0 value Y
: XY)       ( -- )
    75 {cmd  y 7F and >ol  7F ol}   \ Set row
    15 {cmd  x 7F and >ol  7F ol} ; \ Set column
: XY        ( x y -- )      to y to x  xy) ; \ Set OLED column and row

: DISPLAY-SETUP ( -- )
    dm 15000 spi0-on        \ Init. 5MHz SPI
    12 FD 2cmd              \ OLED Unlock
    B1 FD 2cmd              \ OLED partley locked
    false on/off            \ Display off
    0 0 xy
    F0 B3 2cmd              \ Set clock devider
    7F CA 2cmd              \ Set mux ratio
    74 A0 2cmd              \ Set remap data format
    00 A1 2cmd              \ Set display start line
    00 A2 2cmd              \ Set display offset
    00 B5 2cmd
    01 AB 2cmd              \ Set 8-bits interface; 0=8bits, 1=16bits, 3=8bits
    false inverse           \ Oled in normal mode
    55 B5 A0 B4 {cmd >ol >ol ol} \ Set segment low voltage
    FF FF FF >bright        \ Set max. brigthtness for each pixel color
    0F C7 2cmd              \ Set master contrast
    32 B1 2cmd              \ Set precharge phase
    00 00 A4 B2 {cmd >ol >ol ol} \ Set display enhance
    17 BB 2cmd              \ Set precharge level
    01 B6 2cmd              \ Set second precharge period
    05 BE 2cmd              \ Set vcomh voltage
    true on/off  150 ms ;   \ Display on

: WAIT      ( -- )
    begin  40 ms  key? while  key drop  repeat ;

F800 constant RED
07E0 constant GREEN
001F constant BLUE
FFFF constant WHITE
0000 constant BLACK
white value LC     \ Letter color
black value BC     \ Background color

: &FILL     ( b +n -- )
    5C {cmd  for  dup b-b >ol >ol  next  spi}  drop ;

: COLOR     ( color -- )        4000 &fill ;


: COLORS    ( delay -- )
    display-setup  dup ms
    begin
        blue  color  dup ms
        green color  dup ms
        red   color  dup ms
    stop? until
    white color  drop ;

\ : S2?       ( -- f )                \ Flag f is true when S2 is pressed
\    3 bitmask GPIO-IN bit** 0= ;

: SQUARES0  ( delay -- )
\   5 3 gpio!                       \ Enable SIO on pin 3
\   5A 3 pads!                      \ Enable pull-up on pin 3
    wait  display-setup  dup ms
    begin
        cr ." 1F"  blue color  dup ms
        cr ." 5F" 5F 00 >col  5F 00 >row  green color  dup ms
        cr ." 3F" 3F 00 >col  3F 00 >row  red color  dup ms
        cr ." 1F" 1F 00 >col  1F 00 >row  white 400 &fill  dup ms
        cr ." 7F" 7F 00 >col  7F 00 >row
    stop? until  black color  drop ;

: SQUARES1  ( delay -- )
\   5 3 gpio!                       \ Enable SIO on pin 3
\   5A 3 pads!                      \ Enable pull-up on pin 3
    wait  display-setup  dup ms
    begin
        cr ." 7F"  blue color  dup ms
        cr ." 5F" 5F 00 >col  5F 00 >row  green color  dup ms
        cr ." 3F" 3F 00 >col  3F 00 >row  red color    dup ms
        cr ." []" 57 28 >col  57 28 >row  white C00 &fill  dup ms
        cr ." Home"  0 0 xy
    stop? until  black color  drop ;

: SHOW1     ( -- )      wait  200 colors ;
: SHOW2     ( -- )      wait  200 squares0 ;
: SHOW3     ( -- )      wait  200 squares1 ;

' show3  to app  ( display-setup )  \ freeze

\ 16-bits karakterset
: >BIT      ( 0|n -- )
    if  lc  else  bc  then  \ Output one colored bit
    5C {cmd  b-b >ol >ol  spi} ;

code REVERSE ( b0 -- b1 )   \ Reverse bit order in byte b0
    day 0 # movs,       \ Init. used registers
    hop 0 # movs,
    sun 8 # movs,
    begin,
        day day adds,   \ Shift bits in DAY to left
        tos 1 # lsrs,   \ Shift out lowest bit to carry
        day hop adcs,   \ Add Lowest bit
        sun 1 # subs,   \ Count done bits
    =? until,
    tos day movs,       \ Result in TOS
    next,
end-code

: >DATA     ( b -- )
    y >r  8 for
        xy) dup 80 and >bit  2*  incr y
    next  drop  r> to y ;

: &EOL      ( +n -- )       \ Fill +n rows with backgound color
    for  bc >data  next ;

: &PAGE     ( -- )      0 0 xy  bc 4000 &fill ;
: &TYPE     ( a +n -- ) for  count &emit  next  drop ;
: &SPACE    ( -- )      bl &emit ;
: &SPACES   ( +n -- )   for  &space  next ;

: .BITROW   ( a +n -- )         \ Output half of +Nx14 (big) character
      x >r  bc >data for
        count >data 1+  incr x  \ Output every second bit row
    next
    drop  bc >data  r> to x ;


\ Partial character set
v: inside definitions
: ||    ( bitrow -- )        \ Read & compile character row
    0  0D parse  10 min bounds
    ?do  2*  i c@ ch X =  -  loop
    b-b  swap reverse c,  reverse c, ;

create 'THIN    \ Start of a character type, original version Albert Nijhof
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
align


: THIN-EMIT ( c -- )            \ Only valid for uppercase characters!
    ch A -  80 x -  dup 9 < if  \ Character does not fit?
      dup &eol                  \ Yes, erase to end Of Line
      x y 1+ xy  dup &eol       \ Erase end of next line too
      0 y 1+ xy                 \ To start of new line
    then  drop
    0E * 'thin +  dup 7 .bitrow \ First half of big char
    x y 8 + xy  1+ 7 .bitrow    \ Second half of big char
    x 09 + y 8 -  xy ;          \ x & y to new char position

v: extra definitions
: THIN      ( -- )      ['] thin-emit to o-emit ;

: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us  \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=         \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;       \ QSPI pin-SS peripheral function again

: DEMO      ( -- )
    display-setup  thin         \ Init. OLED & select char. type
    begin
        &page  FF ms            \ Wipe screen
        red to lc    0  0 xy s" PROJECT" &type 80 ms
        white to lc 18 10 xy s" FORTH"   &type 80 ms
        blue to lc  30 20 xy s" WORKS"   &type 80 ms
        red to lc    0 30 xy s" PROJECT" &type 80 ms
        white to lc 18 40 xy s" FORTH"   &type 80 ms
        blue to lc  30 50 xy s" WORKS"   &type
        10 0 do
            40 ms  bootkey?
            if leave then
         loop
    bootkey? until  &page ;     \ Until a key was pressed

v: fresh
' demo  to app
shield OLED\  \ freeze

\ End

