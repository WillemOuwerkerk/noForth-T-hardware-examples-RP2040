(* Separate minimal PIO control 08-march-2023

    SM-ON       = (De)activate state machine  ( f sm -- )
    SET-PIO     = Select PIO 0 or 1           ( n -- )
    TX-DEPTH    = Space on TX fifo of 'sm'    ( sm -- +n )
    RX-DEPTH    = Space on RX fifo            ( sm -- +n )
    >TXF        = Data to TX fifo             ( x sm -- )
    RXF>        = Data from RX fifo           ( sm -- x )
    EXEC        = Execute instruction on 'sm' ( instr sm -- )
    CLOCK-DIV   = Set clock divider on 'sm'   ( u sm -- )
    FREQ        = Set 'sm' to clock freq. 'u' ( u sm -- )
    
    sm's is a bitmask where the bit's 0 to 3 represent state machines
    
    SYNC        = Synchronize state machines  ( sm's -- )
    RESTART     = Restart state machines      ( sm's -- )
 
This program is written for a 32-bits cell size

*)

hex
v: inside also definitions
0 value 'PIO                \ Pointer to current active PIO
: PIO-ADDR  ( offset -- a ) cells  'pio + ; \ Convert to real address
: PIO@      ( offset -- x ) pio-addr @ ;
: PIO!      ( x offset -- ) pio-addr ! ;

create SM-OFFSETS    32 c, 38 c, 3E c, 44 c, align  \ Address SM control blocks
: SM-OFFSET+ ( off1 sm -- off2 ) sm-offsets + c@ + ;

: >FIELD    ( x mask pos -- y ) >r and  r> lshift ; \ Place bitfield
: FIELD!    ( data mask pos offset -- ) \ Replace any bit field with new data
    >r  2dup lshift invert  r@ pio@ and \ Erase bit-field
    >r  >field  r> or  r> pio! ;        \ Set bit-field & show result

: SET-CLOCK ( freq u sm -- )    \ Set clock divider
    >r  over 0 >  over 0=  and ?abort ( Invalid clock divider )
    8 lshift or  FFFFFF 8 0     \ Build clock parameters
    r> sm-offset+  field! ;     \ Replace clock data

v: extra definitions
: SM-ON     ( f sm -- )     1 swap 0 field! ; \ (De)activate a state machine
: SET-PIO   ( pio -- )      0<> 100000 and  50200000 +  to 'pio ;
: TX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * rshift  F and ; \ Fifo depth
: RX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * 4 + rshift  F and ; \ Idem
: >TXF      ( u sm -- )     4 + pio! ;      \ Store TX data in FIFO
: RXF>      ( sm -- u )     8 + pio@ ;      \ Fetch RX data from FIFO
: EXEC      ( instr sm -- ) 4 swap sm-offset+ pio! ; \ Exec. instruction
\ sm's is a bitmask where the bit's 0 to 3 represent state machines
: SYNC      ( sm's -- )     7 8 0 field! ;  \ Sync. clock divider
: RESTART   ( sm's -- )     7 4 0 field! ;  \ Restart state machine

: FREQ      ( u sm -- )
    >r  >r  0 cfg @ F4240 *  r@ /mod    \ Sys-clock/Wanted-clock
    dup FFFF u> ?abort ( Freq. to low ) \ 16-bit overflow?
    swap 100 r> */  swap r> set-clock ; \ Scale fractional part & set clock divider

: CLOCK-DIV ( u sm -- )
    >r  64 /mod >r                      \ Scale & save integer part
    100 64 */  r> r> set-clock ;        \ Scale fractional part

v: fresh
shield PIOBASE\

\ End
