\ RP2040 PIO assembly sketch v0.7a, W.O. 12-oct-2022 - 26-jun-2025
\
\ This version is for noForth T.
\
\ Version 0.2:     An improved addressing format; SIM PIO0 & PIO1
\                  New internal words CODE@ @ CODE! because stored instructions
\                  can not be read back! Removed separate 'PIO memory. The word
\                  'PIO is now an address vector.
\ Version 0.3d(+)  Added TX-DEPTH & RX-DEPTH compressed PIN-COUNT, debugged PCODE
\                  Renamed OPTION? to OPTIONAL? That word captures the meaning
\                  better. Also renamed SAMPLE to MEMO it's just a memory!
\                  (+) Renaming, rearranging & small improvements, added COPY:
\ Version 0.3e     Refactored PIO0 & PIO1, renamed PCODE, CLEAN-UP, etc.
\ Version 0.3f     Added IN-ON: ( pin #pins -- )  instead of IN-PIN: ( pin -- )
\ Version 0.3g     Structure simplified and thus removed a pin assignment bug
\                  and updated source. .SM is now .FLAGS
\ Version 0.3h     Added INPUTS: and STRENGTH: in doing so removed pin type
\                  initialisation from JMP-PIN: and IN-ON: now renamed to IN-PIN:
\ Version 0.4a     Renaming & rearranging code, changed *AUTOPUSH & *AUTOPULL
\
\ Version 0.5      Added HEX-ON HEX-OFF & PIO-HEX for saving PIO drivers
\ Version 0.6      Changed >EXEC, added: EXEC  FREQ  CLOCK-DIV  SM-ON
\ Version 0.6a     Updated CLEAN-UP a minor restart error
\ Version 0.7      Added multiple PIO code support, simplyfied EXPORT
\ Version 0.7a     Changed programming tools EXEX to EXEC-OPC & FREQ to SET-FREQ
\                  Moved ONE> etc to EXTRA words to make them available outside PIO code
\ To-do:           Signalling shortcomings, IRQ control

need .hex

v: forth definitions
v: vocabulary PIOS     \ Active words

\ Hold copy's of PIO's internal data & address pointers
HEX  v: inside also definitions
2 constant #PIO                 \ Number of PIO's
0 value HEX?                    \ Debug on/off flag
0 value PDP                     \ PIO actions pointer
create PIO-ACTIONS  800 cells allot \ Enough for complex programs?
    pio-actions  800 cells  FF fill
: (!)       ( x a -- x a )
    hex? 0= ?exit
\ ) cr over .hex  dup .hex ." ! "
    over pio-actions pdp + !  4 +to pdp  \ Store data
    dup pio-actions pdp + !  4 +to pdp ; \ Store address

: PCELLS    ( u1 -- u2 )        cells ; \ ** 32-bits memory operators **
: P!        ( x a -- )          (!) ! ; \ ** This is a 32-bit write **
: P@        ( a -- x )          @ ;     \ ** This is a 32-bit read **

0 value #SM                     \ Select state machine
0 value #SIDE                   \ Hold side set functionality, number of pins
0 value OPTIONAL?               \ When 1, side-set is optional on instructions
0 value SIDE?                   \ Side set levels ( max. 5 bits & flag )
0 value MEMO                    \ Data memory
0 value DELAY                   \ Add 0 to 31 delay cycles to an instruction
0 value 'PIO                    \ Pointer to current active PIO
create 'PHERE #pio cells allot  \ Define empty memory pointers
    'phere #pio cells 0 fill
create 'SIM  #pio 20 *  pcells allot align  \ Simulated PIO memory
    'sim  #pio 20 * pcells  0 fill
create LABELS  3 allot  align   \ Space for three labels

\ 0 = PIO0, 1 = PIO-1, 2 = PIO-2
: PIO?      ( -- +n )   'pio 5020,0000 - 14 rshift ; \ Zero if PIO-0 is selected
: SIMA      ( -- a )    pio? 80 *  'sim + ;   \ Address of PIO 0 or +n code area
: PHERE     ( -- a )    pio? 4 *   'phere + ; \ Address pointer of PIO 0 or +n

v: pios also definitions
: ONE       ( -- )      phere @ labels c! ;   \ Labels
: TWO       ( -- )      phere @ labels 1+ c! ;
: THREE     ( -- )      phere @ labels 2 + c! ;

v: extra definitions
: ONE>      ( -- pa )   flyer  labels c@  postpone literal ; immediate
: TWO>      ( -- pa )   flyer  labels 1+ c@  postpone literal ; immediate
: THREE>    ( -- pa )   flyer  labels 2 + c@  postpone literal ; immediate

need [defined]
need [if]

[defined] asm\ [if]
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
[else]
: =PIO      ( pio -- )      #pio 1- umin  100000 *  50200000 +  to 'pio ; \ Select active pio block
[then]

\ : PIO0      ( -- )          0 =pio ;
\ : PIO1      ( -- )          1 =pio ;

v: inside definitions
: SET-SM    ( sm -- )       3 and to #sm ;
: PIO-ADDR  ( offset -- a ) pcells  'pio + ;    \ Convert to real address
: PIO@      ( offset -- x ) pio-addr p@ ;

: PIO!      ( x offset -- ) pio-addr p! ;

: CODE@     ( offset -- x ) pcells  sima + p@ ; \ Read always from simulated area
: CODE!     ( x offset -- )
    2dup 12 + pio!              \ Store in targeted PIO code area
    pcells  sima + ! ;          \ Copy in simulated PIO area

v: pios definitions
: PIO,      ( x -- )            \ PIO assemble action
    phere @ code!  1 phere +!
    phere @ 1F > ?abort ( PIO memory full )
    0 to delay  0 to side? ;

v: inside definitions
: MASK      ( -- mask )         1F #side optional? + rshift ; \ Leave adjusted delay mask
: ?TYPE     ( flag -- )         ?abort ( Argument? ) ; \ When true issue error message
: =TYPE     ( t0 t1 -- )        <> ?type ;          \ Check argument type
: >FIELD    ( x mask pos -- y ) >r and  r> lshift ; \ Place bitfield
: ADD-DELAY ( x1 -- x2 )        delay mask 8 >field or ; \ Add delay to x1 giving x2
: SIDE>     ( -- +n )           side? 1F and ;      \ Leave Side-set bit pattern
: FIELD!    ( data mask pos offset -- ) \ Replace any bit field of current PIO with new data
    >r  2dup lshift invert  r@ pio@ and \ Erase bit-field
    >r  >field  r> or  r> pio! ;        \ Set bit-field & show result


\ Add optional clock ticks and/or Side-set bits
: SIDE/DELAY ( x1 -- x2 )       \ Add side set bits to high bits of delay/side-set & delay
    optional? side? 0 > and if  \ Side-set OPT?
        side> #side bitmask 1- and \ Yes, get used bits only
        #side bitmask or        \ Add extra option marker
        0C #side - lshift  or   \ Add to Side-set/delay bitfield
        add-delay  exit         \ Add delay bits
    then
    #side if                    \ Side-set used everywhere?
        side>  #side bitmask 1- and \ Yes, build mask
        0D #side - lshift  or   \ Yes, add SIDE> bit(s)
    then  add-delay ;           \ Finally add delay bits

: OPCODE,   ( arg opc -- )      or  side/delay  pio, ; \ Compile opcode with arguments

: CLAIM-PIN ( pin -- )          \ Claim GPIO pin for PIO
    8 *  40014004 + >r          \ Build correct CTRL-pin register address
    6 pio?  +                   \ Select PIO-0 to PIO-2 for IO-pin (6,7 or 8)
    'pio 'sim <> if             \ Real pio selected?
        r@ p@  1F invert and    \ Yes, read & clear bitfield-0
        over or  r@ p!          \ Claim for PIO IO-function
        r> 2drop  exit
    then
    r> 2drop ;

\ Change of direction with pull-up, pull-down or float
: INPUTS        ( n pin #p -- )     \ Select float, pullup or pulldown for inputs
    2>r  dup if  0< if 4 else 8 then  then  \ res
    2r> 0 ?do                               \ res pin
        2dup i + pcells 4001C004 + >r       \ res pin res
        r@ p@ -0D and  or r> p!             \ res pin
    loop  2drop ;

: STRENGTH      ( +n pin #p -- )    \ Set drive strength of outputs
    2>r  3 and 4 lshift  2r>
    0 ?do
        2dup i + pcells 4001C004 + >r       \ res pin res
        r@ p@ -31 and  or  r> p!
    loop  2drop ;


create SM-OFFSETS    32 c, 38 c, 3E c, 44 c, align   \ Address state machine control blocks
: SM-OFFSET+ ( off1 sm -- off2 ) sm-offsets + c@ + ;
: SM-FIELD! ( data mask pos offset -- ) \ Replace any bit field of current SM with new data
    #sm sm-offset+  field! ;

: SET-CLOCK ( freq u -- )       \ Set clock divider
    over 0 >  over 0=  and ?abort ( Invalid clock divider )
    8 lshift or  FFFFFF 8 0 sm-field! ; \ Replace clock data

\ Set GPIO pin field at (pos)ition on offset for current state machine
: SET-PIN   ( pin pos offset -- )    2>r  1F  2r> sm-field! ; \ Replace PIN field


\ Secured argument types, datastack: code type in short is: ct
: ARGUMENT  ( type code -- ct )     create , , does> dup @ swap cell+ @ ;

\ Format: <addr> <jumptype> JMP
: JMP,      ( addr jt -- )
    7 5 >field >r  1F and  r> opcode, ; \ Check jump condition & place in correct field

\ Special arguments
v: pios definitions
: []        ( +n -- )   mask and  to delay ; \ Set secured delay
: SIDE      ( +n -- )   80 or to side? ;     \ Set side-set pins high or low

-1 00 argument PINS     \ Type-1 arguments for IN, OUT & MOV
-1 01 argument X
-1 02 argument Y
-1 03 argument NULL
-1 06 argument ISR
-1 07 argument OSR
\ Format: <bitcount> <arg> IN
: IN,       ( bit-count ct -- )
    -1 =type  7 5 >field  over 21 1 within
    ?abort ( Shift count? ) or   4000 opcode, ;

-2 04 argument PINDIRS  \ Type-2 arguments for OUT & MOV
-2 05 argument PC
-2 07 argument EXEC
\ Format: <bitcount> <arg> OUT
: OUT,      ( bit-count ct -- )
    dup -1 = if                         \ Type-1 argument
        drop  dup 7 = ?type             \ Yes, only 7 = valid
    else  -2 =type                      \ No, type-2 argument
    then  7 5 >field  over 21 1 within  \ Place data & check bit count
    ?abort ( Shift count? ) or  6000 opcode, ; \ add fields & compile

-3 01 argument BLOCK    \ Type-3 & 4 arguments for PUSH/PULL
-3 00 argument NOBLOCK
-4 01 argument IFFULL
\ Format: ?iffull ?(no)block PUSH
: PUSH,     ( ct? -- )
    dup -3 = if  drop  1 5 >field       \ Optional (NO)BLOCK
    else  20  then  >r                  \ Default is NOBLOCK!
    dup -4 = if drop 1 =type 40 else 0 then \ Optional IFFULL
    r> or 8000 opcode, ;

-4 02 argument IFEMPTY
\ Format: ?ifempty ?(no)block PULL
: PULL,     ( ct? -- )
    dup -3 = if  drop  1 5 >field       \ Optional (NO)BLOCK
    else  20  then  >r                  \ Default is NOBLOCK!
    dup -4 = if drop 2 =type 40 else 0 then \ Optional IFEMPTY
    r> or  8080 opcode, ;

-4 05 argument STATUS   \ Type-4 & 5 arguments for MOV
-5 00 argument NORM     \ Superfluous
-5 01 argument INV      \ ! or ~
-5 02 argument REV      \ ::
\ Format: <src-arg> ?op? <dest-arg> MOV
: MOV,      ( cts cto ctd -- )
    dup -2 = if             \ Destination Type-2 arguments?
        drop  dup 4 = ?type \ Yes, PINDIRS is invalid
        dup 7 = 3 and -     \ Handle EXEC & PC
    else
        -1 =type  dup 3 = ?type \ Type-1 argument,  NULL is invalid
    then
    7 5 >field >r
    dup -5 = if             \ Optional operation?
        drop  3 3 >field    \ Yes, add it
    else  0  then  r> or >r \ No, default no action
    dup -4 = if             \ Source Type-4 argument?
        drop  dup 5 =type   \ Yes, only STATUS is valid
    else  -1 =type  then    \ No, Is it Type-1 argument
    7 0 >field              \ Source to field-0
    r> or A000 opcode, ;    \ Add fields & opcode together

: NOP,      ( -- )          x x mov, ;

-4 06 argument REL      \ Type-6 arguments for IRQ
-6 00 argument SET
-6 01 argument WAIT
-6 02 argument CLR
-6 04 argument NOWAIT
\ Format: <number> ?type? IRQ
\ Note that: Interrupt 0 to 3 may be changed when two statemachines using
\ the same interrupt, a mod 4 addition on the state machine number is done
\ Interrupt 4 to 7 are not bothered by this.
: IRQ,      ( irq ct? -- )
    dup -6 = if  drop 3 5 >field    \ Type-6 argument
    else  drop 0  then  to memo    \ Save data
    >r  dup -4 = if                 \ Type-4 argument?
        drop  6 =type               \ Yes, is it REL?
        r> 10 or                    \ Calculate REL code
    else  r>  then
    memo or  C000 opcode, ;

\ Format: <value> <dest> SET
: SET,      ( pins ct -- )
    dup -2 = if                 \ Type-2 argument
        drop  dup 4 =type       \ Only PINDIRS is valid!
    else
        -1 =type  dup 2 > ?type \ Low 3 of type-1 arguments are valid!
    then
    7 5 >field  swap 1F 0 >field \ Save pins
    or  E000 opcode, ;

-7 00 argument GPIO     \ Type-7 arguments for WAIT
-7 20 argument PIN
-7 40 argument IRQ
-8 00 argument LOW      \ Polarity arguments for WAIT
-8 01 argument HIGH
\ Format: <pol> <pin> <arg> WAIT
: WAIT,     ( ctp ct pin -- )
    -7 =type  swap 1F 0 >field  or >r
    -8 =type  1 7 >field  r> or  2000 opcode, ;

\ Type-9 condition arguments for IF, UNTIL, & WHILE,
-9 00 argument NEVER?   \ Jump conditionals for IF, WHILE, UNTIL,
-9 01 argument X0<>?    \ X not zero
-9 02 argument X--?     \ X not zero & decrease
-9 03 argument Y0<>?    \ Y not zero
-9 04 argument Y--?     \ Y not zero & decrease
-9 05 argument X=Y?     \ X & Y are equal
-9 06 argument PIN?     \ Pin status
-9 07 argument OSRE?    \ Output Shift Register Empty

\ Format: <addr> <test> IF,  ELSE,  THEN,
\ pio-address security ... is shortened to ps in the stack comments
: THEN,     ( ps -- )
    -A <> ?abort ( Structure? ) phere @ \ Check correct structure
    swap 1- >r  r@ code@ or  r@ code!   \ Update stored opcode with jump address
    r> drop ;
: IF,       ( ct -- ps )    -9 =type 0 swap JMP,  phere @ -A ;
: ELSE,     ( ps0 -- ps1 )  0 0 jmp,  then,  phere @ -A ;

\ Format: BEGIN,  ... AGAIN,        Format: BEGIN,  ... <tst> UNTIL,
\ Format: BEGIN,  ... <tst> WHILE, ... REPEAT,
\ ps = pio-addr & security number
: UNTIL,    ( ps ct -- )
    -9 =type >r  -B <> ?abort ( Structure? ) r> jmp, ;
: BEGIN,    ( -- ps )               phere @ -B ;
: AGAIN,    ( ps -- )               never? until, ;
: WHILE,    ( ps0 ct -- ps1 ps0 )   if,  2swap ;
: REPEAT,   ( ps1 ps0 -- )          again,  then, ;

\ PIO directives
v: inside definitions
: .FLAGS    ( x +n -- )         \ Show SM bits on or off
    0 ?do
        i .  dup  i bitmask and if ." on,  " else ." off, " then
    loop  drop ;

v: extra definitions
: .FIFO     ( -- )      \ Show problem state of all state machine's FIFO's
    2 pio@ >r
    cr ." RX stall ... " r@ 04 .flags
    cr ." RX underflow " r@ 04 rshift 4 .flags
    cr ." TX stall ... " r@ 18 rshift 4 .flags
    cr ." TX overflow  " r> 10 rshift 4 .flags ;

: TX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * rshift  0F and ;       \ Fifo depth
: RX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * cell+ rshift  0F and ; \ Idem
: >TXF      ( u sm -- )     cell+ pio-addr ! ; \ Store TX data in FIFO of state machine
: RXF>      ( sm -- u )     2 pcells + pio@ ; \ Fetch RX data from FIFO of state machine

: CLEAN-PIO ( -- )                      \ PIO cleanup function
    'sim #pio 20 * pcells 0 fill        \ Erase code mirror
    'phere #pio 4 * 0 fill  0 to pdp    \ Start code from address zero
    #pio for  i =pio  0 0 pio-addr !  next ;  \ Stop all state machines
clean-pio
: SM        ( f -- )        1 #sm 0 field! ;         \ (De)activate current SM
v: pios definitions
: CLOCK     ( f -- )        #sm 2 cells +  1 swap 0 field! ; \ Restart clock divider
: RESTART   ( f -- )        #sm cell+  1 swap 0 field! ; \ Restart state machine
: =ORG      ( pa -- )       1F and  phere ! ;        \ Set program start address
: =EXEC     ( instr -- )    4 #sm sm-offset+ pio! ;  \ Execute instr. on sm
: =SET-PINS ( pin #p -- )
    dup 5 > ?abort ( Pin limit )            \ Check used pins
    over 5 5 set-pin dup 7 1A 5 sm-field!   \ Set basic GPIO pin & pins for SET
    0 ?do  dup i + claim-pin  loop  drop ;  \ Add additional pins
: =OUT-PINS ( pin #p -- )
    2dup + 1E > ?abort ( Pin limit )        \ Check used pins
    over 0 5 set-pin dup 3F 14 5 sm-field!  \ Set basic GPIO pin #pins for OUT
    0 ?do  dup i + claim-pin  loop  drop ;  \ Add additional pins
: =SIDE-PINS ( pin #p -- )
    swap 0A 5 set-pin                       \ Set basic GPIO pin for Side-set
    5 optional? - umin to #side             \ Set & save number pins for SIDE-SET
    #side optional? + 7 1D 5 sm-field! ;    \ Set number of used SIDE bits
: OPT       ( -- )
    1 to optional?  1 1 1E 1 sm-field!      \ Side-Set optional
    #side optional? + 7 1D 5 sm-field! ;    \ Increase used bits for SIDE with one
: =IN-PIN   ( pin -- )  0F 5 set-pin ;      \ Set GPIO pin for PIN IN
: =JMP-PIN  ( pin -- )  18 1 set-pin ;      \ Set GPIO pin for PIN JMP
: SIDE-PINDIRS ( -- )      1 1 1D 1 sm-field! ; \ Side-set on PINDIRS
: =INPUTS   ( n pin #p -- )     inputs ;    \ Set input type to 'pin' & +n pins
: =STRENGTH ( +n pin #p -- )    strength ;  \ Set output strength to 'pin' & +n pins
: WRAP-TARGET ( -- )    phere @ 1F 07 1 sm-field! ; \ Wrap start address
: WRAP      ( -- )      phere @ 1-  1F 0C 1 sm-field! ; \ Wrap end addres
\ 0 = No steal, 1 = TX steals RX fifo , 2 = RX steals TX fifo
: =STEAL    ( +n -- )
    dup 2 > ?abort ( Invalid steal ) 3 1E 2 sm-field! ; \ Steal fifo space
: =AUTOPUSH ( +n f -- ) 1 10 2 sm-field!  1F 14 2 sm-field! ; \ Auto push on/off
: =AUTOPULL ( +n f -- ) 1 11 2 sm-field!  1F 19 2 sm-field! ; \ Auto pull on/off
: =IN-DIR   ( f -- )    1 12 2 sm-field! ;  \ Shift direction 1 = right
: =OUT-DIR  ( f -- )    1 13 2 sm-field! ;  \ Shift direction 1 = right
: CLONE     ( sm -- )   \ Copy sm data from state machine 'sm' to current sm
    3 0 do
        i over sm-offset+ pio@          \ Read data from state machine 'sm'
        i #sm sm-offset+ pio!           \ Copy to current state machine
    loop  drop ;

\ Set clock divider for current state machine
\ Divider of: 251 gives a frequency of 125MHz (sysclock) : 2,51 = 49,80 MHz
: =CLOCK-DIV ( u -- )                   \ Set clock divider
    64 /mod >r                          \ Scale & save integer part
    100 64 */  r> set-clock ;           \ Scale fractional part

\ Set clock frequency for current state machine, 'u' is in Hz
: =FREQ     ( u -- )
    >r  0 cfg 2 + h@ F4240 *  r@ /mod   \ Sys-clock/Wanted-clock
    dup FFFF u> ?abort ( Freq. to low ) \ 16-bit overflow?
    swap 100 r> */  swap set-clock ;    \ Scale fractional part & set clock divider

v: extra definitions  inside
: SM-ON     ( f sm -- )     set-sm  sm ;    \ Enable/disable SM on active PIO
: SET-FREQ  ( u sm -- )     set-sm  =freq ; \ Freq. on SM on active PIO
: CLOCK-DIV ( u sm -- )     set-sm  =clock-div ; \ Clock. div. on sm ...
: EXEC-OPC  ( opc sm -- )   set-sm  =exec ;  \ Exec. instr. on sm of ...

v: pios definitions  inside
: PIO}      ( pa s -- )
v:  previous
    -C <> ?abort ( Structure? )
    drop  1 sm   false to hex? ;        \ Copy code & start state machine

v: extra definitions  inside
: {PIO      ( sm pio -- pa s )
    =pio   set-sm  0 to delay           \ Select PIO & state machine
    0 to optional?  0 to #side          \ Clear global variables
    true to hex?   0 sm                 \ Current SM off
    0001F000 -1 0 1 sm-field!           \ Reset EXECCTRL function,
    14000000 -1 0 5 sm-field!           \ Reset PINCNTRL function,
v:  also pios                           \ Select PIO voc. & security
    phere @  -C ;

: EXPORT    ( -- )                      \ Save standalone pio data
    cr ." : PIO-PROG "                  \ Start with header
    pio-actions  pdp 0 ?do              \ Data range
      cr 4 spaces @+ .hex  @+ .hex  ." !" \ One PIO line
    8 +loop                             \ Next record
    cr 4 spaces  pio? .hex ." =pio ;"   \ Set PIO address
    drop  cr cr ." pio-prog  " cr ;     \ Install PIO program

v: fresh
shield PIO\  \ freeze

\ End

