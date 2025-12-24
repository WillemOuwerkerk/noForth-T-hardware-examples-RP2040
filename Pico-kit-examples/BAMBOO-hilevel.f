\ ==============================================================
\ [TITLE]     RP2040 BAMBOO target library.
\ [FILE]      BAMBOO-hilevel.f
\ [CATEGORY]  Library ... bytes
\ [VSN]       2.00
\ [CREATED]   january 16, 1994, Willem Ouwerkerk
\ [LASTCHNGD] december 24, 2025, Willem Ouwerkerk
\ [COPYRIGHT] Dutch Forth Users Group (C) 1994-2025
\ [COMPILE]   original, AVR ByteForth Environments
\ [AUTHOR]    Willem Ouwerkerk
\ [PURPOSE]   8 bits I/O, Bamboo using 3 io-port bits on port D
\             Example of converting serial to parallel outputs
\             Bamboo is based on the 74HC(T)4094 IC
\ ==============================================================

hex
D0000020    constant GPIO-OE    \ GPIO output enable
D0000010    constant GPIO-OUT   \ GPIO output value

6 bitmask   constant STR        \ Bamboo I/O bits
7 bitmask   constant OUT
8 bitmask   constant CLK
5           constant #B         \ Number of used bamboo's

: INIT      ( -- )
    5A dm 6 pads!                  \ Enable output on pin 6
    5A dm 7 pads!                  \ Enable output on pin 7
    5A dm 8 pads!                  \ Enable output on pin 8
    [ str out clk or or ]
    literal  gpio-oe **bis ;  init

: READY     ( -- )      str gpio-out **bis 1 us str gpio-out **bic ;

: >BAMBOO   ( b -- )
    dm 24 lshift                \ Data to high byte
    8 for                       \ 8 bits
        dup 0< if               \ Highest bit set?
            out gpio-out **bis  \ Data high
        else
            out gpio-out **bic  \ data low
        then
        clk gpio-out **bic      \ Clock low
        clk gpio-out **bis      \ Clock high
        2*                      \ Next bit
    next  drop ;

create BITS  #B 8 * allot  align
: >BB       ( -- )
    #B for
        bits i + c@ >bamboo
    next  ready ;

: LOC       ( +n a1 -- bit a2 ) \ Bit location in byte-address a2
    over 3 rshift +  >r         \ Convert to byte addresses
    07 and bitmask  r> ;        \ Convert low nibble to bit mask

: ZERO      ( -- )          bits 5 0 fill ;
: SET       ( +n a -- )     loc *bis ;
: CLR       ( +n a -- )     loc *bic ;

: RUNNER    ( -- )  \ Running light on 40 bamboo outputs
    init  0  begin
        dup zero  bits set  >bb  20 ms
        1+  #B 8 *  over = if  dup -  then
    key? until  drop ;

\ End ;;;
