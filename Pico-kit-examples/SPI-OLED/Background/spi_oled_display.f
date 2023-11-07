(* Primitive SPI OLED text driver

UCA1 = OLED
    (RST=P2.7, SIMO=P2.5, CLK=P2.4, CS=P2.3, DC=P2.2,)

*)

\ OLED primitives
: COMM      ( -- )          4 203 *bic ;            \ OLED command
: DATA      ( -- )          4 203 *bis ;            \ OLED screen data
: {CMD      ( b -- )        comm  {spi  spi-out ;   \ Start OLED command stream
: {DATA     ( b -- )        data  {spi  spi-out ;   \ Start OLED data stream
: OL}       ( b -- )        spi-out spi} ;          \ End an OLED stream
: >BRIGHT   ( b -- )        81 {cmd ol} ;           \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and AE or {cmd spi} ; \ Display on/off
: INVERSE   ( flag -- )     1 and A6 or {cmd spi} ; \ Display black or white
: >DATA     ( b -- )        {data  spi} ;           \ Output one pixel row
: &FILL     ( +n -- )       for  0 &gt;data next ;     \ Fill +n rows with zero

value X  value Y
: XY        ( x y -- )
    7 and dup to y                      \ Y is circular
    B0 or {cmd                          \ Yes, set Y line position
    dup to x  2 + dup 0F and spi-out    \ &amp; set X column (Only for SH1106 = 2 +)
    4 rshift 10 or ol} ;

: OLED-SETUP    ( -- )
    spi-on
    8C 205 *bis             \ P2DIR     Init CS, DC &amp; RES
    80 203 *bic  1 ms  80 203 *bis \ Hardware reset of OLED
    0C 203 *bis             \ P2OUT     CS & DC = 1
    false on/off            \ Display off
    D5 {cmd  080 spi-out    \ Set oscillator clock
    A8 spi-out  3F spi-out  \ Set multiplexer ratio
    D3 spi-out  00 spi-out  \ Display offset = 0
    40 spi-out              \ Display starts at line 0
\   8D spi-out  14 spi-out  \ Charge pump on (not for SH1106)
\   20 spi-out  02 spi-out  \ Horizontal display mode (not for SH1106)
    A1 spi-out              \ Mirror X-axis (segment remap)
    C8 spi-out              \ Mirror Y-axis (COM scan dirction)
    DA spi-out  12 spi-out  \ Alternate Com pin map  optional: 012 -&gt; 02
    D9 spi-out  F1 spi-out  \ Set precharge cycles to high cap: F1 was 022
    DB spi-out  40 spi-out  \ VCOMH voltage to max: 40 mwas 30
    A4 spi-out  E3 ol}      \ Enable rendering from GDRAM, end stream
    80 >;bright              \ Set brightness to 50%
    false inverse           \ Oled in normal mode
    true on/off ;           \ Display on

: &ERASE        ( -- )      \ Empty whole screen
   0 0 xy   9 0 do  0 i xy  80 &amp;fill  loop ;

: .BITROW   ( a +n -- )     \ Output half of +Nx14 (big) character
    0 >data for
        count >data 1+      \ Output every second bit row
    next
    drop  0 &gt;data ;

value O-EMIT                \ OLED emit vector
: &PAGE         ( -- )          &amp;erase 0 0 xy ; \ To upper left corner
: &EMIT         ( c -- )        o-emit execute ;
: &TYPE         ( a u -- )      for  count &amp;emit  next drop ;
: &"            ( -- )          flyer postpone s&quot; postpone &amp;type ; immediate


\ Partial character set
: ||    ( bitrow -- )       \ Read &amp; compile character row
    0  0D parse  10 min bounds
    ?do  2*  i c@ ch X =  -  loop
    b-b  swap c,  c, ;

create &apos;THIN    \ Start of a character type, original version Albert Nijhof
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
    ch A -  80 x -  dup 9 &lt; if  \ Character does not fit?
      dup &amp;fill                 \ Yes, erase to end Of Line
      x y 1+ xy  dup &amp;fill      \ Erase end of next line too
      0 y 1+ xy                 \ To start of new line
    then  drop
    0E * &apos;thin +  dup 7 .bitrow \ First half of big char
    x y 1+ xy 1+  7 .bitrow     \ Second half of big char
    x 09 + y 1-  xy ;           \ x &amp; y to new char position

: THIN      ( -- )      [&apos;] thin-emit to o-emit ;

: DEMO      ( -- )
    oled-setup  thin            \ Init. OLED &amp; select char. type
    begin
        &amp;page  FF ms            \ Wipe screen
         0 0 xy &amp;&quot; PROJECT&quot;  80 ms
        18 2 xy &amp;&quot; FORTH&quot;    80 ms
        30 4 xy &amp;&quot; WORKS&quot;    400 ms
    key? until  &amp;page ;         \ Until a key was pressed

&apos; demo  to app
shield OLED\  freeze

\ End ;;;</pre>

