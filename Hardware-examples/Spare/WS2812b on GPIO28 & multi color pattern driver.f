\ Multi color multi WS2812 driver, alternative coding style where
\ X and Y scratch registers are used for color code and the length
\ of the LED string. In only 19 opcodes a flexible WS2812 LED driver,
\ the maximum string length is only limited by the update rate and
\ ofcourse the power supply. Pulse frequency = 740 kHz
\ Note! State machine-0 outputs on GPIO 28
\
\ The assembled program & configuration data:
\
\  0: E081 set  pindirs 1
\  1: 90A0 pull block  side 0
\  2: A047 mov  y osr
\  3: 0070 jmp  y=0 to: 10
\  4: 0085 jmp  y-- to: 5
\  5: 80A0 pull block
\  6: A0C7 mov  isr osr
\  7: A0E6 mov  osr isr
\  8: 6068 out  null 8
\  9: 6001 out  pins 1
\  A: 1ACC jmp  pin to: C  side 1  [2]
\  B: 110D jmp  to: D  side 0  [1]
\  C: B821 mov  x x  side 1
\  D: 12E9 jmp  osrne to: 9  side 0  [2]
\  E: 0087 jmp  y-- to: 7
\  F: 0012 jmp  to: 12
\ 10: E04A set  y A
\ 11: 1791 jmp  y-- to: 11  side 0  [7]
\ 12: 0001 jmp  to: 1   OK.0
\
\ Clk: 6666666 Hz,  Wrap: 0 31  Outsel: 0  Jmp: 28
\ Push: 0  dir: 1  auto: 0  steal: 0
\ Pull: 0  dir: 0  auto: 0  steal: 0
\ Set: 28 1  Side: 28 2 optional  Out: 28 1  In: 0

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                        \ Use state machine-0 on PIO-0
    6666666 =freq               \ On 6.666.666 Hz frequency
    28 1 =side-pins  opt        \ GPIO 25 for SIDE-SET optional
    28 1 =out-pins              \ for OUT & SET
    28 1 =set-pins
    28 =jmp-pin                 \ Pin 28 is input too
    32 0 =autopull  0 =out-dir  \ OSR shift left

    1 pindirs set,
    begin,
        0 side  pull,           \ Number of LEDs in string
        osr y mov,              \ Get length string tp Y
        pull,                   \ Get LED color
        osr isr mov,            \ Save color copy in ISR
        y0<>? if,               \ Length not zero?
            y--? if, then,          \ Decrease Y by 1
            begin,
                isr osr mov,        \ Copy color data to OSR
                8 null out,         \ Shift left one byte
                begin,              \ With a WS2812 specific pattern
\                                         One   Zero
                    1 pins out,             \  1     0     Output highest bit
                    2 []  1 side  pin? if,  \  111   111   Is it low bit?
                    1 []  0 side  else,     \        00    Yes,
                        1 side  nop,        \  1           No,
                    then,
                2 []  0 side  osre? until,  \  000   000   One LED done?
            y--? until,             \ Count number of leds
        else,
           10 y set,                \ Length zero, make reset pulse
           begin,  15 [] 0 side y--? until,
        then,
    again,
    0 =exec                     \ Start SM-0 at address 0
pio}

hex \ Copied from noForth-T more tools
code 2! ( lo hi a -- )
    day  sp 4 #) ldr,               \ lo
    sun  sp ) ldr,   sun tos ) str, \ !hi
    day  tos 4 #) str,              \ !lo
    tos  sp 8 #) ldr,  sp C # adds, \ Pop stack
    next, end-code
code 2@ ( a -- lo hi )
    day  tos 4 #) ldr,       \ @lo
    tos  tos ) ldr,          \ @hi
    day  sp -) str,          \ lo
next, end-code

decimal
730 value #LEDS     \ Number of WS2812 LEDs connected
  0 value #POS      \ Next LED position to address

hex
: CLR       ( -- )          0 to #pos ;
: BLACK     ( -- c )        000000 ;    \ Leds on and off
: WHITE     ( -- c )        101009 ;
: GREEN     ( -- c )        100000 ;
: RED       ( -- c )        001000 ;
: DARKRED   ( -- c )        000800 ;
: BLUE      ( -- c )        000010 ;
: DARKBLUE  ( -- c )        000008 ;
: BLUEGREEN ( -- c )        1A0008 ;
: YELLOW    ( -- c )        181400 ;
: ORANGE    ( -- c )        081000 ;
: PURPLE    ( -- c )        000314 ;
: DARKGREEN ( -- c )        080000 ;
: ICY       ( -- c )        10101F ;
: WARM      ( -- c )        181F10 ;
: HOT       ( -- c )        181C04 ;

: >OUT      ( dc u -- )
    begin  0 tx-depth  3 < until  0 >txf  0 >txf ; \ Data for GPIO 28

: >RGB      ( c +n -- )     1 umax 400 umin  dup +to #pos  >out ; \ Length is minimal 1 LED
: READY     ( -- )          0 0 >out ;  \ Ready signal
: ALL       ( c -- )        clr  #leds >rgb  ready ; \ One color to leds

10 value #FIELD  \ Field length
03 value #DOT    \ Dot length
08 value #WAIT   \ Delay time

\ 0 value 'MEM
\ 0 value 'ACCU
create 'COLORS  8 cells allot
create 'EFFECT  2 cells allot

: >LEDS     ( +n -- )       400 umin  to #leds ;    \ Number of LEDs
: >WAIT     ( +n -- )       200 umin  to #wait ;    \ Set delay time in millisec.
: >FIELD    ( +n -- )       #leds umin  to #field ; \ Set field size
: >DOT      ( +n -- )       #field umin  to #dot ;  \ Set dot size
: >BCOLOR   ( c -- )        'effect ! ;             \ Background color
: >FCOLOR   ( c -- )        'effect cell+ ! ;       \ Foreground color
: >COLOR    ( c +n -- )     7 umin cells 'colors + ! ;    \ One of eight colors
: BCOLOR    ( +n -- )       'effect @ swap >rgb ;        \ +n LEDs with background color
: FCOLOR    ( +n -- )       'effect cell+ @  swap >rgb ; \ +n LEDs with foreground color
: COLOR     ( i +n -- )      >r  cells 'colors + @  r> >rgb ;
: CSWAP     ( -- )          'effect 2@  >fcolor >bcolor ; \ Exchange colors
: WAIT      ( -- )          #wait ms ;

#leds >field    3 >dot      \ Basic size & color settings
red >fcolor     black >bcolor

: .MLINE    ( dot-pos -- )          \ Display one field
    >r  r@ #dot +  #field > 0= if   \ Dot fits in #FIELD
        r> ?dup if  bcolor  then    \ Yes, do background first?
        #dot ?dup if fcolor then    \ If any, then output DOT
        #field  #pos - ?dup         \ Still room for background?
        if  bcolor  then  exit      \ Yes, then fill in
    then
    r> #dot +  #field - dup fcolor  \ No, repeat DOT remainder at start
    #field  #dot - bcolor           \ Do background color?
    negate #dot + fcolor ;          \ and dot remainder

: MLINE     ( dot-pos -- )          \ Repeat fields until all LEDs are done
    begin
        dup #leds u< 0= while       \ Too large value?
        #leds -                     \ Yes, scale back
    repeat  >r
    #leds  begin
        clr  r@ .mline  #field -    \ One field at a time
    dup 1 < until                   \ Whole LED string done?
    r> 2drop  ready ;

: PRISM     ( -- )                  \ Set rainbow colors
    002C00 0 >color     \ Red
    102000 1 >color     \ Orange
    181400 2 >color     \ Yellow
    2C0000 3 >color     \ Green
    1A0008 4 >color     \ Blue-green
    000040 5 >color     \ Blue
    000738 6 >color     \ Deep-purple :)
    001A20 7 >color ;   \ Purple

: SHOW      ( -- )                  \ Show these
    clr  #leds 0 do
        8 0 do  i #field 8 / color loop
        key? if leave then
    #field +loop  ready ;

: ROTATE    ( f -- )                \ Rotate color buffer left = -1 or right = 0
    if  'colors 7 cells + @
        'colors  'colors cell+  7 cells move
        'colors !  exit
    then
    'colors @
    'colors cell+  'colors  7 cells move
    'colors 7 cells + ! ;


\ Demo's:
: MSHIFT    ( -- )                  \ Shift DOT until a key is pressed
    begin
        #field 0 do  i mline  wait  key? if leave then  loop
    key? until  black all ;

: VOLUME    ( -- )                  \ Volume style DOT
    #dot  begin
        #field 0 do  i >dot  0 mline  wait  key? if leave then  loop
        0 #field do  i >dot  0 mline  wait  key? if leave then  -1 +loop
    key? until  >dot  black all ;

: BOUNCE    ( -- )                  \ Bouncing DOT
    #dot  begin
        #field #dot -  dup 0 ?do  i mline  wait  key? if leave then loop
        1 swap ?do  i mline  wait  key? if leave then  -1 +loop
    key? until  >dot  black all ;

: FLAG      ( -- )          \ Dutch flag with banner on all LEDs
    clr  begin
        2000 3 >rgb        \ Red
        101010 3 >rgb      \ White
        30 3 >rgb          \ Blue
        102000 3 >rgb      \ Orange
    key? 0= while
    #pos #leds u< 0= until
    ready  then ;

: PARTY     ( -- )          \ Shift rainbow colors
    prism
    begin
        show  wait  1 rotate
    key? until  black all ;

\ End
