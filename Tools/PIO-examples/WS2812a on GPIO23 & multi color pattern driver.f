\ Multi color multi WS2812 driver, alternative coding style where 
\ X and Y scratch registers are used for color code and the length
\ of the LED string. In only 15 opcodes a flexible WS2812 LED driver,
\ the maximum string length is only limited by the update rate and
\ ofcourse the power supply. Pulse frequency = 740 kHz
\ Note! State machine-0 outputs on GPIO 23, SM-1 outputs on GPIO 22
\
\ The assembled program & configuration data:
\
\ 0: E081 set  pindirs 1
\ 1: 90A0 pull block  side 0
\ 2: A047 mov  y osr
\ 3: 0084 jmp  y-- to: 4
\ 4: 80A0 pull block
\ 5: A0C7 mov  isr osr
\ 6: A0E6 mov  osr isr
\ 7: 6068 out  null 8
\ 8: 6001 out  pins 1
\ 9: 1ACB jmp  pin to: B  side 1  [2]
\ A: 110C jmp  to: C  side 0  [1]
\ B: B821 mov  x x  side 1
\ C: 12E8 jmp  osrne to: 8  side 0  [2]
\ D: 0086 jmp  y-- to: 6
\ E: 0001 jmp  to: 1
\
\ Clk: 6666666 Hz,  Wrap: 0 31  Outsel: 0  Jmp: 23
\ Push: 0  dir: 1  auto: 0  steal: 0
\ Pull: 0  dir: 0  auto: 0  steal: 0
\ Set: 23 1  Side: 23 2 optional  Out: 23 1  In: 0

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                        \ Use state machine-0 on PIO-0
    6666666 =freq               \ On 6.666.666 Hz frequency
    23 1 =side-pins  opt        \ GPIO 23 for SIDE-SET optional
    23 1 =out-pins              \ for OUT & SET
    23 1 =set-pins  
    23 =jmp-pin                 \ Pin 23 is input too
    32 0 =autopull  0 =out-dir  \ OSR shift left

    1 pindirs set,
    begin, 
        0 side  pull,           \ Number of LEDs in string
        osr y mov,              \ Get length string tp Y
        y--? if, then,          \ Decrease Y by 1
        pull,                   \ Get LED color
        osr isr mov,            \ Save color copy in ISR
        begin,
            isr osr mov,        \ Copy color data to OSR
            8 null out,         \ Shift left one byte
            begin,              \ With a WS2812 specific pattern
\                                         One   Zero
                1 pins out,             \  1     0     Ouput highest bit
                2 []  1 side  pin? if,  \  111   111   Is it low bit?
                1 []  0 side  else,     \        00    Yes,
                    1 side  nop,        \  1           No,
                then,
            2 []  0 side  osre? until,  \  000   000   One LED done?
        y--? until,             \ Count number of leds
    again,
    0 =exec                     \ Start SM-0 at address 0
pio}

1 0 {pio                        \ Use state machine-1 on PIO-0
    6666666 =freq               \ On 6.666.666 Hz frequency
    22 1 =side-pins  opt        \ GPIO 22 for SIDE-SET optional & SET
    22 1 =out-pins              \ for OUT & SET
    22 1 =set-pins  
    22 =jmp-pin                 \ Pin 22 is input too
    32 0 =autopull  0 =out-dir  \ OSR shift left
    0 =exec                     \ Start SM-1 at address 0 too
pio}

hex \ Copied from noForth-T more tools
code 2! ( lo hi a -- )
    day  sp 4 x) ldr,               \ lo
    sun  sp ) ldr,   sun tos ) str, \ !hi
    day  tos 4 x) str,              \ !lo
    tos  sp 8 x) ldr,  sp C # adds, \ Pop stack
    next, end-code
code 2@ ( a -- lo hi )
    day  tos 4 x) ldr,       \ @lo
    tos  tos ) ldr,          \ @hi
    day  sp -) str,          \ lo
next, end-code

decimal
10 constant #LEDS   \ Number of WS2812 LEDs connected
0 value #POS        \ Current LED position

hex
: BLACK     ( -- dc )       000000 ;    \ Leds on and off
: WHITE     ( -- dc )       202012 ;
: GREEN     ( -- dc )       200000 ;
: RED       ( -- dc )       002000 ;
: BLUE      ( -- dc )       000020 ;
: ICY       ( -- dc )       20203F ;
: WARM      ( -- dc )       303F20 ;
: HOT       ( -- dc )       303808 ;

: >LEDS     ( c +n -- )
    1 umax  2dup   dup +to #pos  \ Length is minimal 1 LED
    begin  1 tx-depth  3 < until  1 >txf  1 >txf   \ Data for GPIO 22
    begin  0 tx-depth  3 < until  0 >txf  0 >txf ; \ Data for GPIO 23

: ALL       ( c -- )        #leds >leds ;

0A value #FIELD  \ Field length
03 value #DOT    \ Dot length
30 value #WAIT   \ Delay time

\ 0 value 'MEM
\ 0 value 'ACCU
create 'COLORS  8 cells allot
create 'EFFECT  2 cells allot

: >WAIT     ( +n -- )       200 umin  to #wait ;    \ Set delay time in millisec.
: >FIELD    ( +n -- )       #leds umin  to #field ; \ Set field size
: >DOT      ( +n -- )       #field umin  to #dot ;  \ Set dot size
: >BCOLOR   ( c -- )        'effect ! ;             \ Background color
: >FCOLOR   ( c -- )        'effect cell+ ! ;       \ Foreground color
: >COLOR    ( c +n -- )     7 umin cells 'colors + ! ;    \ One of eight colors
: BCOLOR    ( +n -- )       'effect @ swap >leds ;        \ +n LEDs with background color
: FCOLOR    ( +n -- )       'effect cell+ @  swap >leds ; \ +n LEDs with foreground color
: COLOR     ( i +n -- )      >r  cells 'colors + @  r> >leds ;
: CSWAP     ( -- )          'effect 2@  >fcolor >bcolor ; \ Exchange colors
: WAIT      ( -- )          #wait ms ;

#leds >field    3 >dot      \ Basic size & color settings
red >fcolor    black >bcolor

: .MLINE    ( dot-pos -- dot-pos )
    dup >r  0 to #pos               \ Save DOT position
    r@ #dot +  #field > 0= if       \ Dot fits?
        r> ?dup if  bcolor  then    \ Yes, background first?
        #dot ?dup if fcolor then    \ Then DOT
        #field  #pos - ?dup         \ Still room for background?
        if  bcolor  then  exit      \ Yes, then fill in
    then
    r> #dot +  #field - dup fcolor  \ No, repeat DOT remainder at start
    #field  #dot - bcolor           \ Background color?
    negate #dot + fcolor ;          \ Dot remainder

: MLINE     ( dot-pos -- )          \ Display one line with DOT
    begin
        dup #leds u< 0= while       \ Too large value?
        #leds -                     \ Yes, scale back 
    repeat
    begin
        .mline
    #pos #leds u< 0= until drop ;   \ Whole LED string done?

: PRISM     ( -- )                  \ Rainbow colors
    002C00 0 >color     \ Red
    102000 1 >color     \ Orange
    181400 2 >color     \ Yellow
    2C0000 3 >color     \ Green
    1A0008 4 >color     \ Blue-green
    000040 5 >color     \ Blue
    000738 6 >color     \ Deep-purple :)
    001A20 7 >color ;   \ Purple

: SHOW      ( -- )                  \ Show these
    #leds 0 do
        8 0 do  i #field 8 / color  loop
    loop ;

: ROTATE    ( f -- )                \ Rotate color buffer left = -1 or right = 0
    if  'colors 7 cells + @
        'colors  'colors cell+  7 cells move
        'colors !  exit
    then
    'colors @
    'colors cell+  'colors  7 cells move
    'colors 7 cells + ! ;


\ Demo's:
: MSHIFT    ( -- )                  \ Shift DOT until a key was pressed
    begin
        #field 0 do  i mline  wait  loop
    key? until  black all ;

: VOLUME    ( -- )                  \ Volume style DOT
    #dot  begin
        #field 0 do  i >dot  0 mline  wait  loop
        0 #field do  i >dot  0 mline  wait  -1 +loop
    key? until  >dot  black all ;

: BOUNCE    ( -- )                  \ Bouncing DOT
    #dot  begin
        #field #dot -  dup 0 ?do  i mline  wait  loop
        1 swap ?do  i mline  wait  -1 +loop
    key? until  >dot  black all ;

: FLAG      ( -- )          \ Dutch flag with banner on all LEDs
    begin
        2000 3 >leds        \ Red
        101010 3 >leds      \ White
        30 3 >leds          \ Blue
        102000 1 >leds      \ Orange
     #pos #leds u< 0= until ;

: PARTY     ( -- )          \ Shift rainbow colors
    prism
    begin
        show  wait  1 rotate
    key? until  black all ;

\ End
