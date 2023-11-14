(* Let core-1 on RP2040 run it's own code

Primitives for activating code on CORE-1 from CORE-0

\ PSM_BASE = 40010000 ( Power-on State Machine )
40010000 = FRC_OFF
40010004 = FRC_OFF
40010008 = WDSEL
4001000C = DONE

\ Watchdog reset = 40058000
00 = CTRL
04 = LOAD
2C = TICK

\ SIO base = D0000000
50 = FIFO status register
54 = FIFO write
58 = FIFO read

: RESET0    ( -- )          \ Reset core 0  (48 bytes)
    8000 40010008 **bis     \ Allow a WD reset of core-0
    1F bitmask 40058000 **bis ; \ Force reset
: RESET1    ( -- )          \ Reset core 1  (48 bytes)
    10000 40010008 **bis    \ Allow a WD reset of core-1
    1F bitmask 40058000 **bis ; \ Force WD reset

When a WFE instruction is executed the current drops about
0,2mA to 2,5mA depending on the used PLL frequency!

*)

v: extra definitions
\ Reset core-1
code RESET1 ( -- )      \ 26 bytes
    40010008 ,          \ Watchdog reset select
    40058000 ,          \ Watchdog control
    00010000 ,          \ Reset core-1 pattern
code>
    w  { hop day sun } ldm, \ Read pool
    sun  hop ) str,     \ Store core-1 reset
    sun 0F # lsls,      \ Make & activate force reset bit
    sun  day ) str,
    next,
end-code

\ : FTX?          ( -- f )    2 D000,0050 bit** 0<> ;
\ : FRX?          ( -- f )    1 D000,0050 bit** 0<> ;
code FRX?       ( -- f )
    D000,0050 ,
code>
    day 1 # movs,       \ 1 - Fifo RX? bit
    tos sp -) str,      \ 3 - Save TOS
    w  w ) ldr,         \ 2 - Read addr. fifo status to W
    tos w ) ldr,        \ 2 - Read fifo status to TOS
    tos day ands,       \ 2 - Test it
    =? no if,           \ 2 - Not zero?
        tos day day subs.mv, \ 1+1 - Build true flag
        tos tos mvns,
    then,
    next,               \ 6
end-code
code FTX?       ( -- f )
    D000,0050 ,
code>
    day 2 # movs,       \ Fifo TX? bit
    ' frx? @ 2 + 77 again,
end-code

v: extra definitions
\ Send data to core-1
code FIFO!      ( x -- )
    D0000050 ,          \ FIFO status register
code>
    w  w ) ldr,
    sun 2 # movs,
    begin,
        hop  w ) ldr,   \ Read status
        hop sun ands,
    =? no until,        \ Space for TX
    tos  w 4 #) str,
    sev,                \ Set event
    sp { tos } ldm,
    next,
end-code

\ Read data from core-1
code FIFO@      ( -- x )
    D0000050 ,          \ FIFO status register
code>
    w  w ) ldr,
    begin,
        hop  w ) ldr,   \ Read status
        sun 1 # movs,
        hop sun ands,
    =? while,           \ Received on RX
        wfe,            \ Wait for event
    repeat,
    tos  sp -) str,
    tos  w 8 #) ldr,    \ Read FIFO
    next,
end-code

: EMPTY-FIFO        ( -- )  \ Empty incoming FIFO completely
    begin  frx? while  fifo@ drop  repeat ;

v: inside also definitions
\ Send & verify a command to core-1 in one word
: >CMD?         ( cmd -- f )    dup fifo!  fifo@ = ;

v: extra definitions
\ Start assembly code routine on core-1
\ Core-1 access sequence: 0, 0, 1, vectortable, sp, pc
: BOOT1         ( code-addr -- )
    1 or >r  reset1         \ Set thumb bit & reset core-1
    begin  begin  begin  begin  begin  begin
        empty-fifo          \ Clear incoming FIFO
    0 >cmd? until           \ Start with access sequence, succeed?
    0 >cmd? until           \ Second step, succeed?
    1 >cmd? until           \ Third step, succeed?
    21000000 >cmd? until    \ Sent interrupt table for core-1, succeed?
    tib/ 100 + >cmd? until  \ Sent stack pointer for core-1, succeed?
    r@ >cmd? until  rdrop ; \ Sent core-1 PC address, succeed?

v: fresh
shield CORE\  freeze

\ End
