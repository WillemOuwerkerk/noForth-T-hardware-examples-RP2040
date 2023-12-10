(* SSD1351 driver, with a little help from the source of author N0082

First send a command 5Ch, DC is low, then DC to high and
always send 2Bytes color values.

2 Bytes color coding:
    ___high____|low______|
      00000|000000|00000 |
    __red__|green_|_blue_|
    0...31 |0..63 |0...31|

8410 = 16 + 32 + 16 = Lichtgrijs        light-gray
4208 =  8 + 16 +  8 = Staalgrijs        steel-grey
2104 =  4 +  8 +  4 = Leigrijs          Slate-gray
18C3 =  3 +  6 +  3 = Antracietgrijs    antracit-gray

SIO special offsets

0   D0000010 = Out
4   D0000014 = Set
8   D0000018 = Clear
C   D000001C = Xor

First the SPI-0 driver on GPIO16 to GPIO19

    4003C000    - SPI0_BASE
    40040000    - SPI1_BASE
    40014000    - IO_BANK0_BASE

    SPI is chapter 4.4 from page 503 ff

Current use by the display while active, 4 mA (black), to 60 mA (white)

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
F800 constant RED           \ Colors to work with
07E0 constant GREEN
001F constant BLUE
FFFF constant WHITE
8410 constant GRAY
4208 constant STEEL-GRAY
2104 constant SLATE-GRAY
18C3 constant ANTRACIT-GRAY
0000 constant BLACK
07FF constant CYAN
F81F constant MAGENTA
FFE0 constant YELLOW
EE00 constant DARK-YELLOW
E400 constant ORANGE
8000 constant DARK-RED
0400 constant DARK-GREEN
0010 constant DARK-BLUE

WHITE value LC     \ Letter color
BLACK value BC     \ Background color
: >BC           ( c -- )    to bc ;
: >LC           ( c -- )    to lc ;

D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value

: INV           ( -- )          BC  LC  to BC  to LC ;

v: inside definitions
0 [if]

: COMM          ( -- )          0B bitmask gpio-out **bic ; \ GPIO11 = DC

: DATA          ( -- )
    begin  10 4003C00C bit** 0= until \ OLED command sent?
    0B bitmask gpio-out **bis ; \ GPIO11 = DC

: {SPI          ( -- )          0A bitmask gpio-out **bic ; \ GPIO10 = CS

: SPI}          ( -- )
    begin  10 4003C00C bit** 0= until \ OLED data all sent?
    0A bitmask gpio-out **bis ; \ GPIO10 = CS

: >OL           ( b -- )
    begin  2 4003C00C bit** until  4003C008 !
    begin  4 4003C00C bit** until  4003C008 @ drop ;

: 2>OL          ( b0 b1 -- )    >ol >ol ;

: >PIX      ( 0|n -- )
    if  lc  else  bc  then  \ Output one colored bit
    5C {cmd  b-b 2>ol  spi} ;

[else]

code DATA
    gpio-out 4 + ,
    0B bitmask ,
    4003C00C ,
code>
    w  { hop day sun } ldm,
    moon 10 # movs,
    begin,
        w  sun ) ldr,
        w moon ands,
    =? until,
    day  hop ) str,
    next,
end-code

code COMM
    gpio-out 8 + ,
    0B bitmask ,
code>
    w  { hop day } ldm,
    day  hop ) str,
    next,
end-code

code {SPI
    gpio-out 8 + ,
    0A bitmask ,
code>
    w  { hop day } ldm,
    day  hop ) str,
    next,
end-code

code SPI}
    gpio-out 4 + ,
    0A bitmask ,
    4003C00C ,
code>
    w  { hop day sun } ldm,
    moon 10 # movs,
    begin,
        w  sun ) ldr,
        w moon ands,
    =? until,
    day  hop ) str,
    next,
end-code

routine >OL)    ( -- a )    \ DAY = SPI data register, W = OLED command or data
    begin,  moon  day 4 #) ldr,
            tos 2 # movs,
            moon tos ands,
    =? no until,  w  day ) str,
    lr bx,
end-code

routine OL>)    ( -- a )    \ DAY = SPI data register, W = OLED command or data
    begin,  w  day 4 #) ldr,
            moon 4 # movs,
            w moon ands,
    =? no while,  w  day ) ldr,
    repeat,
    lr bx,
end-code

code >OL        ( b -- )
    4003C008 ,
code>
    day  w ) ldr,
    w tos movs,
    >ol) bl,
    ol>) bl,
    tos sp )+ ldr,
    next,
end-code

code 2>OL        ( b0 b1 -- )
    4003C008 ,
code>
    day  w ) ldr,
    w tos movs,
    >ol) bl,
    w sp )+ ldr,
    >ol) bl,
    tos sp )+ ldr,
    ol>) bl,
    next,
end-code

code >PIX   ( 0|n -- )
    adr lc ,    \ Letter color
    adr bc ,    \ Backgound color
    gpio-out ,  \ Control line ouput address
    4003C008 ,  \ SPI-0 data register
code>
    w  { hop day } ldm,     \ HOP = letter color, DAY = background color
    tos 0 # cmp,
    =? if,                  \ SUN contains 16-bits color
        sun  day ) ldr,
    else,
        sun  hop ) ldr,
    then,
\ Activate SPI to OLED
    w  { hop day } ldm,     \ HOP = GPIO-out, DAY = SPI-0 data register, SUN = color
    w 1 # movs,             \ Activate SPI
    w 0A # lsls,
    w  hop 8 #) str,
\ Activate command mode & send command
    w 1 # movs,             \ Activate command mode
    w 0B # lsls,
    w  hop 8 #) str,
    w 5C # movs,            \ Send data command
    >OL) bl,
\ Activate data mode after command is sent
    moon 10 # movs,         \ Command sent?
    begin,
        w   day 4 #) ldr,
        w moon ands,
    =? until,
    w 1 # movs,             \ Activate data mode
    w 0B # lsls,
    w  hop 4 #) str,
\ Send data
    w sun 8 # lsrs.mv,      \ Send data high byte
    >OL) bl,
    w sun movs,             \ Send data low byte
    >OL) bl,
    OL>) bl,                \ Empty receive fifo
\ Close SPI when data is sent
    moon 10 # movs,         \ Data sent?
    begin,
        w   day 4 #) ldr,
        w moon ands,
    =? until,
    w 1 # movs,             \ Close SPI
    w 0A # lsls,
    w  hop 4 #) str,
    tos  sp )+ ldr,         \ Pop bit type
    next,
end-code

[then]

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


(* SSD1351 initialisation
Command  Data           Alt           Reset
     FD  12             --              12
     FD  B1             --              -- Access to all commands
     AE  --             --              -- Sleep mode on
     B3  F0             F1              D1 Higher clock freq.
     CA  7F             --              7F MUX from 15 to 127
     A2  00             --              60 Vertical scroll
     A1  00             --              00 RAM scroll
     A0  74             B4              60
     B5  00             --              0A
     AB  01             --              01
\    B4  A0 B5 55                       A0 B5 55
     C1  FF FF FF       C8 80 C8        8A 51 8A
     C7  0F             --              0F
\    B8  02 03 etc.     .....           -- 64 values
\    B1  32                             82
     B2  A4 00 00       --              00 00 00
\    BB  17                             17 Pre charge voltage
\    B6  01                             08 Second pre charge period
\    BE  05                             05
     A6  --             --              A6 Normal display
     AF  --             --              -- Sleep mode off
*)

hex
v: extra definitions
: {OL       ( b -- )        {spi  >ol ;             \ Start an oled command/data stream
: OL}       ( b -- )        >ol  spi} ;             \ End an oled stream
: {CMD      ( b -- )        comm  {ol  data ;       \ Start oled command string
: CMD       ( b -- )        {cmd  spi} ;            \ Single byte oled command
: 2CMD      ( b c -- )      {cmd  ol} ;             \ Dual byte oled command
: >BRIGHT   ( b b b -- )    C1 {cmd  >ol >ol ol} ;  \ b = 0 to 255, max. brightness
: ON/OFF    ( flag -- )     1 and  AE or cmd ;      \ Display on/off
: INVERSE   ( flag -- )     1 and  A6 or cmd ;      \ Display black or white

0 value X   0 value Y
0 value 'X  0 value 'Y
0 value WX  0 value WY

inside also  forth also

(*
code XLIM   ( -- x )        \ Calc. window X-limit
    adr WX ,
    adr 'X ,
code>
    tos  sp -) str,
    w  { tos hop } ldm,
    hop  hop ) ldr,
    tos  tos ) ldr,
    tos hop adds,
    next,
end-code

code YLIM   ( -- y )        \ Calc. window Y-limit
    adr WY ,
    adr 'Y ,
code>
    tos  sp -) str,
    w  { tos hop } ldm,
    hop  hop ) ldr,
    tos  tos ) ldr,
    tos hop adds,
    next,
end-code
*)


(* ONSCR? tests on all window limits!

: ONSCR?    ( -- f )        \ Pixel position before box starts?
    wx x +  wx <  wy y +  wy <  or 0= ;

: ONSCR?    ( -- f )        \ Pixel position on current screen?
    x 0<  y 0<  or 0=       \ Border underflow
    'x x <  'y y < or 0=    \ Border overflow
    and ;

: ONSCR?    ( -- f )        \ Pixel position on current screen?
    x 0>=  y 0>=  and       \ Within lower border
    'x x >=  'y y >= and    \ Wihin upper border
    and ;

*)


1 [if]
: ONSCR?    ( -- f )        \ Pixel position on current screen?
    x 0<  y 0<  or          \ Border underflow
    'x x <  'y y < or       \ Border overflow
    or 0= ;
[else]
code ONSCR? ( -- f )
    adr x ,  adr y ,        \ TOS = X,  HOP = Y
    adr wy ,  adr y ,       \ HOP = 'X, DAY = 'Y
code>
    tos  sp -) str,         \ Make TOS free
    w  { tos hop } ldm,
    day  tos ) ldr,         \ X to DAY
    hop  hop ) ldr,         \ Y to HOP
    tos 0 # movs,           \ -1 to TOS
    tos tos mvns,
    day 0 # cmp, <? if,     \ X < 0
        tos 0 # movs,
    then,
    hop 0 # cmp,  <? if,    \ Y < 0
        tos 0 # movs,
    then,
    w  {  sun moon } ldm,
    sun  sun ) ldr,         \ 'X to SUN
    moon  moon ) ldr,       \ 'Y to MOON
    day sun cmp, >? if,     \ X > 'X
        tos 0 # movs,
    then,
    hop moon cmp, >? if,    \ Y > 'Y
        tos 0 # movs,
    then,
    next,
end-code
[then]

: SLOT      ( 'x 'y -- )
    y wy + 7F and  75 {cmd  dup >ol  +  >ol  spi}   \ Slot height
    x wx + 7F and  15 {cmd  dup >ol  +  >ol  spi} ; \ Slot width

: BOX       ( 'x 'y x y -- )
    to wy  to wx  0 to x  0 to y
    1- to 'y  1- to 'x  'x 'y slot ;

: (XY)      ( xe xs ye ys -- )
    75 {cmd  7F and  2>ol  spi}
    15 {cmd  7F and  2>ol  spi} ;

 : &FILL    ( b +n -- )
    5C {cmd  for  dup b-b 2>ol  next  spi}  drop ;

: XY        ( x y -- )
    to y  to x
    wx 'x +  wx x +
    wy 'y +  wy y +  (xy) ;

: &PAGE     ( -- )               0 0 xy  bc  'x 1+  'y 1+ *  &fill ;

: WINDOW    ( 'x 'y x y -- )    \ Remember X Y window start
    box  &page ;

: &EOL      ( 'x 'y -- )        \ Fill 'x rows with backgound color of 'y height
    >r  dup 1-  r> 1- slot
    for  0 >pix  next ;

: WHOLE     ( -- )              80 dup  0 dup window ; \ Use whole screen again was SCREEN


0 value O-EMIT
: &EMIT     ( c -- )        o-emit execute ;

: DISPLAY-SETUP ( -- )
    dm 15000 spi0-on        \ Init. 15MHz SPI
    12 FD 2cmd              \ OLED Unlock
    B1 FD 2cmd              \ OLED partley locked
    false on/off            \ Display off
    F1 B3 2cmd              \ Set clock devider
    7F CA 2cmd              \ Set mux ratio
    75 A0 2cmd              \ Set remap data format (74)
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
    true on/off  10 ms      \ Display on
    whole ;


: COLORS    ( delay -- )
    white >bc  &page dup ms
    begin
        blue >bc  &page  dup ms
        green >bc &page  dup ms
        red >bc   &page  dup ms
    stop? until
    black >bc  &page  drop ;

: SQUARES0  ( delay -- )
    &page  dup ms
    begin
        blue >bc    whole   dup ms
        green >bc   60 60 0 0 window    dup ms
        red >bc     40 40 0 0 window    dup ms
        white >bc   20 20 0 0 window    dup ms
    stop? until
    black >bc  whole  drop ;

: SQUARES1  ( delay -- )
    &page  dup ms
    begin
        blue >bc    whole   dup ms
        green >bc   60 60 10 10 window  dup ms
        red >bc     40 40 20 20 window  dup ms
        white >bc   20 20 30 30 window  dup ms
        black >bc   0C 0C 3A 3A window  dup 2* ms
    stop? until
    black >bc  whole  drop ;

: WAIT-KEY  ( -- )
    begin  40 ms  key? while  key drop  repeat ;

: SHOW1     ( -- )      wait-key  200 colors ;
: SHOW2     ( -- )      wait-key  200 squares0 ;
: SHOW3     ( -- )      wait-key  200 squares1 ;


\ 16-bits character set

: &EOL      ( 'x 'y -- )    \ Fill 'x rows with backgound color of 'y height
    >r  dup 1-  r> slot
    for  0 >pix  next ;

: &TYPE     ( a +n -- ) for  count &emit  next  drop ;
: &SPACE    ( -- )      bl &emit ;
: &SPACES   ( +n -- )   for  &space  next ;
: &U.       ( n -- )    0 <# #s #> &type &space ;
: C>N       ( c -- +n ) bl - ;  \ Convert char to bitmap index number
: &"        ( -- )      flyer  postpone s"  postpone &type ; immediate

: XY"       ( x y ccc -- )      \ XY" voor OLED
    flyer  postpone xy  postpone &" ; immediate



\ Partial character set
v: inside definitions
: ||    ( bitrow -- )        \ Read & compile character row
    0  0D parse  10 min bounds
    ?do  2*  i c@ ch X =  -  loop  h, ;

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

|| ..XX..........XX
|| ....XX......XX..
|| ......XX..XX....
|| ........XX......
|| ......XX..XX....
|| ....XX......XX..
|| ..XX..........XX

|| ..............XX
|| ............XX..
|| ..........XX....
|| ..XXXXXXXX......
|| ..........XX....
|| ............XX..
|| ..............XX

|| ..XX...........X
|| ..X.XX.........X
|| ..X...XX.......X
|| ..X.....XX.....X
|| ..X.......XX...X
|| ..X.........XX.X
|| ..X...........XX

|| ................
|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X............X
|| ..X............X
|| ..X............X
|| ................

|| ..............XX
|| ............XX..
|| ..........XX....
|| ........XX......
|| ......XX........
|| ....XX..........
|| ..XX............

|| ................
|| ..X............X
|| ..X............X
|| ..X............X
|| ..X............X
|| ..XXXXXXXXXXXXXX
|| ................

|| ........X.......
|| .........XX.....
|| ...........XX...
|| .............XXX
|| ...........XX...
|| .........XX.....
|| ........X.......

|| .X..............
|| .X..............
|| .X..............
|| .X..............
|| .X..............
|| .X..............
|| .X..............

|| ................
|| ................
|| ..............X.
|| ............XXXX
|| ...........X..X.
|| ................
|| ................

|| ...XX...........
|| ..X..X....X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ...X.....X......
|| ..X.XXXXX.......

|| ..XXXXXXXXXXXXXX
|| ...X............
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X.....X......
|| ....XXXXX.......

|| ....XXXXX.......
|| ...X.....X......
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X.....X......

|| ....XXXXX.......
|| ...X.....X......
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X............
|| ..XXXXXXXXXXXX..

|| ....XXXXX.......
|| ...X.....X......
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X....X..X.....
|| ........XX......

|| ..........X.....
|| ..........X.....
|| ..XXXXXXXXXXXX..
|| ..........X...X.
|| ..........X....X
|| ...............X
|| ...............X

|| .....XXXX.......
|| X...X....X......
|| X..X......X.....
|| X..X......X.....
|| X..X......X.....
|| .X.......X......
|| ..XXXXXXXXX.....

|| ..XXXXXXXXXXXXXX
|| .........X......
|| ..........X.....
|| ..........X.....
|| ..........X.....
|| .........X......
|| ..XXXXXXX.......

|| ................
|| ..X.............
|| ..X..........X..
|| ..XXXXXXXX..XXX.
|| ..X..........X..
|| ..X.............
|| ................

|| X...............
|| X...............
|| X...............
|| .X...........X..
|| ..XXXXXXXX..XXX.
|| .............X..
|| ................

|| ..XXXXXXXXXXXXXX
|| ................
|| ......X.........
|| .....X.X........
|| ....X...X.......
|| ...X.....X......
|| ..X.......X.....

|| ................
|| ................
|| ..X.............
|| ..XXXXXXXXXXXXXX
|| ..X.............
|| ................
|| ................

|| ..XXXXXXXXX.....
|| .........X......
|| ..........X.....
|| ..XXXXXXXXX.....
|| .........X......
|| ..........X.....
|| ..XXXXXXXXX.....

|| ..XXXXXXXXX.....
|| .........X......
|| ..........X.....
|| ..........X.....
|| ..........X.....
|| .........X......
|| ..XXXXXXX.......

|| ....XXXXX.......
|| ...X.....X......
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X.....X......
|| ....XXXXX.......

|| XXXXXXXXXXX.....
|| .........X......
|| ...X......X.....
|| ...X......X.....
|| ...X......X.....
|| ....X....X......
|| .....XXXX.......

|| .....XXXX.......
|| ....X....X......
|| ...X......X.....
|| ...X......X.....
|| ...X......X.....
|| ..........X.....
|| XXXXXXXXXXX.....

|| ..XXXXXXXXX.....
|| ........X.......
|| .........X......
|| ..........X.....
|| ..........X.....
|| ..........X.....
|| .........X......

|| .......XXX......
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ...XXX..........

|| ..........X.....
|| ..........X.....
|| ....XXXXXXXXXX..
|| ...X......X.....
|| ..X.......X.....
|| ..X.............
|| ..X.............

|| ....XXXXXXX.....
|| ...X............
|| ..X.............
|| ..X.............
|| ..X.............
|| ...X............
|| ..XXXXXXXXX.....

|| .....XXXXXX.....
|| ....X...........
|| ...X............
|| ..X.............
|| ...X............
|| ....X...........
|| .....XXXXXX.....

|| ...XXXXXXXX.....
|| ..X.............
|| ...X............
|| ....XX..........
|| ...X............
|| ..X.............
|| ...XXXXXXXX.....

|| ..XX.....XX.....
|| ....X...X.......
|| .....X.X........
|| ......X.........
|| .....X.X........
|| ....X...X.......
|| ..XX.....XX.....

|| X.....XXXXX.....
|| .X...X..........
|| ..X.X...........
|| ...X............
|| ....X...........
|| .....X..........
|| ......XXXXX.....

|| ..XX......X.....
|| ..X.X.....X.....
|| ..X..X....X.....
|| ..X...X...X.....
|| ..X....X..X.....
|| ..X.....X.X.....
|| ..X......XX.....

|| ................
|| .........X......
|| .........X......
|| ........X.X.....
|| ....XXXX...XXX..
|| ...X..........X.
|| ..X............X

|| ................
|| ................
|| ................
|| ..XXXXXXXXXXXXXX
|| ................
|| ................
|| ................

|| ..X............X
|| ...X..........X.
|| ....XXXX...XXX..
|| ........X.X.....
|| .........X......
|| .........X......
|| ................

|| .......X........
|| ........X.......
|| ........X.......
|| .......X........
|| ......X.........
|| ......X.........
|| .......X........

|| XXXXXXXXXXXXXXXX    \ Cursor block
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX

|| .......X..X.....    \ €
|| ....XXXXXXXXXX..
|| ...X...X......X.
|| ..X....X..X....X
|| ..X....X..X....X
|| ..X.......X....X
|| ...XX.........X.
align


: .LARGE    ( a +n -- )         \ Display one character in it's own window
    x y 2>r                     \ Remember X Y pos.
    for
        r@ to y  h@+  10 for    \ Print first column
            onscr? if           \ Valid position?
                dup 1 and >pix
            then  2/  incr y    \ To next vertical pixel position
        next  drop  incr x      \ To next column
    next  drop  2r> to y to x ; \ Restore X Y position

0 [if]

: THIN-EMIT ( c -- )                    \ Only valid for uppercase characters!
    c>n  xlim 1+ wx x + -  dup 9 < if   \ Character does not fit?
        dup 0F &eol                     \ Yes, erase to end Of Line
        0  y 10 +  'y over - 0F < if    \ To start of new line
            drop  0
        then  xy
    then  drop  6 0F slot           \ Set character box size
    0E * 'thin +  7 .large          \ Big char
    x 9 +  y  xy ;                  \ To next char

[else]

0 value STRIP?
v: extra definitions
: WRAP      false to strip? ;
: STRIP     true  to strip? ;
v: inside definitions
: THIN-EMIT ( c -- )                    \ Valid for all characters!
    onscr? 0= if  drop exit  then       \ Offscreen do nothing
    c>n  'x 1+  x -  dup 9 < if         \ Character does not fit (overflow)?
        dup 0F &eol                     \ Yes, erase to end Of Line
        strip? if  2drop exit  then     \ Suppress character overflow?
        0  y 10 +  'y over -  0F < if   \ To start of new line
            drop  0
        then  xy
    then  drop  6 0F slot               \ Set character box size
    0E * 'thin +  7 .large              \ Big char
    x 9 +  y  xy ;                      \ To next char

[then]

v: extra definitions
: THIN      ( -- )      ['] thin-emit to o-emit ;

: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us  \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=         \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;       \ QSPI pin-SS peripheral function again

: THINDEMO  ( -- )              \ Display thin large token set
    thin  orange >bc  white >lc
    2 for  &page
        08 10 xy" Egel project" \ Startup message
        10 20 xy" Characters"   \ To line 2
        20 40 xy" by A.N."      \ To line 4
        400 ms  black >lc
    next
    400 ms  yellow >bc  &page
    81 bl do  i 80 min &emit  loop
    800 ms  slate-gray >bc  white >lc
    &page
    2 for
        40 0 do  80 &emit  bl &emit  loop
        magenta >lc  400 ms
    next
    400 ms  black >bc  &page ;

create GREYS
    steel-gray , slate-gray , antracit-gray , black ,

: PFW       ( -- )
    0  begin
        &page  FF ms         \ Wipe screen
        red >lc      0  0 xy s" PROJECT" &type 80 ms
        white >lc   18 10 xy s" FORTH"   &type 80 ms
        blue >lc    30 20 xy s" WORKS"   &type 80 ms
        orange >lc   0 38 xy s" PROJECT" &type 80 ms
        orange >lc  18 48 xy s" FORTH"   &type 80 ms
        orange >lc  30 58 xy s" WORKS"   &type
        10 0 do
            40 ms  key?
            if leave then
        loop
        dup cells greys + @ >bc  1+ 3 and
    key? until                  \ Until a key was pressed
    drop  black >bc  &page ;

: DEMO      ( -- )        \ Init. OLED & select char. type
    wait-key display-setup  thin  pfw ;

v: fresh
' demo  to app
shield OLED\  \ freeze

\ End

