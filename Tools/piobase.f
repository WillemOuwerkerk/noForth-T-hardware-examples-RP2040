\ PIOBASE\
(* Separate minimal PIO control 08-march-2023 - 03-sept-2024

    SM-ON       = (De)activate state machine  ( f sm -- )
    =PIO        = Select PIO 0 or 1           ( n -- )
    TX-DEPTH    = Space on TX fifo of 'sm'    ( sm -- +n )
    RX-DEPTH    = Space on RX fifo            ( sm -- +n )
    >TXF        = Data to TX fifo             ( x sm -- )
    RXF>        = Data from RX fifo           ( sm -- x )
    EXEC-OPC    = Execute instruction on 'sm' ( instr sm -- )
    CLOCK-DIV   = Set clock divider on 'sm'   ( u sm -- )
    SET-FREQ    = Set 'sm' to clock freq. 'u' ( u sm -- )

This program is written for a 32-bits cell size

*)

hex
v: inside also definitions
2 constant #PIO                 \ Number of PIO's
0 value 'PIO                \ Pointer to current active PIO

(* PIO internals
: PIO-ADDR  ( offset -- a )     cells  'pio + ; \ Convert to real address
: PIO@      ( offset -- x )     pio-addr @ ;
: PIO!      ( x offset -- )     pio-addr ! ;
: >FIELD    ( x mask pos -- y ) >r and  r> lshift ; \ Place bitfield

create SM-OFFSETS    32 c, 38 c, 3E c, 44 c, align  \ Address SM control blocks
: SM-OFFSET+ ( off1 sm -- off2 ) sm-offsets + c@ + ;

create PIO@ ( offset -- x )
    adr 'pio ,
code>
    w  w ) ldr,  tos 2 # lsls,  tos w adds,
    tos  tos ) ldr,   next,
end-code
create PIO! ( x offset -- )
    adr 'pio ,
code>
    w  w ) ldr,  tos 2 # lsls,  tos w adds,
    hop  sp )+ ldr,  hop  tos ) str,
    tos  sp )+ ldr,  next,
end-code
create SM-OFFSET+ ( off1 sm -- off2 )
    32 c, 38 c, 3E c, 44 c,  align
code>
    hop  sp )+ ldr,
    w  w tos r) ldrb,
    tos w hop adds.mv,
    next,
end-code
code >FIELD ( x mask pos -- y )
    sp { hop day } ldm,
    hop day ands,
    hop tos lsls,
    tos hop movs,
    next,
end-code
*)

create PIO@ ( offset -- x )
   adr 'pio ,
code>
    68126812 ,  189B009B ,  C804681B ,  46A7CA10 ,
end-code
create PIO! ( x offset -- )
   adr 'pio ,
code>
    68126812 ,  189B009B ,  601CC910 ,  C804C908 ,  46A7CA10 ,
end-code
create SM-OFFSET+ ( off1 sm -- off2 )
    443E3832 ,
code>
    5CD2C910 ,  C8041913 ,  46A7CA10 ,
end-code
code >FIELD ( x mask pos -- y )
    402CC930 ,  23409C ,  CA10C804 ,  FFFF46A7 ,
end-code

: FIELD!    ( data mask pos offset -- ) \ Replace any bit field with new data
    >r  2dup lshift invert  r@ pio@ and \ Erase bit-field
    >r  >field  r> or  r> pio! ;        \ Set bit-field & show result

: SET-CLOCK ( freq u sm -- )    \ Set clock divider
    >r  over 0 >  over 0=  and ?abort ( Invalid clock divider )
    8 lshift or  FFFFFF 8 0     \ Build clock parameters
    r> sm-offset+  field! ;     \ Replace clock data

v: extra definitions
: SM-ON     ( f sm -- )     1 swap 0 field! ; \ (De)activate a state machine

(* Set active PIO
: =PIO      ( pio -- )      #pio umin  100000 *  50200000 +  to 'pio ; \ Select active pio block

create =PIO ( pio --)
    50200000 ,   adr 'pio ,
code>
    w  { hop day } ldm,             \ Read addresses
    tos #pio 1- # cmp,  u>? if,
        tos #pio 1- # movs,
    then,
    tos 14 # lsls,                  \ Generate PIO 1 offset
    tos hop adds,  tos  day ) str,  \ Calc & save PIO address
    tos sp )+ ldr,  next,           \ Pop stack
end-code
*)

create =PIO ( pio -- )  \ Select active pio block
    50200000 ,  adr 'pio ,
code>
    2B01CA30 ,  2301D900 ,  191B051B ,
    C908602B ,  CA10C804 ,  FFFF46A7 ,
end-code

: PIO0      ( -- )          0 =pio ;   : PIO1   1 =pio ;
: TX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * rshift  F and ; \ Fifo depth
: RX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * 4 + rshift  F and ; \ Idem
: >TXF      ( u sm -- )     4 + pio! ;      \ Store TX data in FIFO
: RXF>      ( sm -- u )     8 + pio@ ;      \ Fetch RX data from FIFO
: EXEC-OPC  ( instr sm -- ) 4 swap sm-offset+ pio! ; \ Exec. instruction
: SYNC      ( sm's -- )     7 8 0 field! ;  \ Sync. clock divider
: RESTART   ( sm's -- )     7 4 0 field! ;  \ Restart state machine

: SET-FREQ  ( u sm -- )
    >r  >r  0 cfg @ F4240 *  r@ /mod    \ Sys-clock/Wanted-clock
    dup FFFF u> ?abort ( Freq. to low ) \ 16-bit overflow?
    swap 100 r> */  swap r> set-clock ; \ Scale fractional part & set clock divider

: CLOCK-DIV ( u sm -- )
    >r  64 /mod >r                      \ Scale & save integer part
    100 64 */  r> r> set-clock ;        \ Scale fractional part

v: fresh
shield PIOBASE\
