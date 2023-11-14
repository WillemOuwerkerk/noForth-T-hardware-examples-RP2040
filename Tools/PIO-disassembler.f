\ More portable disassembler vsn 0.2f for noForth t
\
\ Version 0.2c: Changed factorisation & removed decode bug from .IN
\               Opcode decoding & integrated with PIO-ass!
\ Version 0.2d: Added .PINCONTROL & integrated in vsn 0.3d of PIO-ass
\ Version 0.2e: Added .SM for more complete state machine overview
\ Version 0.2f: Simplyfied structure, thanks to A.N.

v: inside also definitions
: -TRAILING ( a +n1 -- a +n2 )  \ Cut trailing spaces from a string
    begin  2dup + 1- c@ bl = while  1-  repeat ;

\ a = string start Address, p = Position in string, b = string Block size
: /TYPE     ( a p b -- )        \ Type string part without alignment spaces
    >r  r@ * +  r> -trailing    \ Choose string part & cut spaces
    ?dup if  type space  0  then  drop ;

\ The data of field 2 & 3 are read only once
: FIELD0    ( opc -- +n )       1F and ;            \ Data for field-0
: FIELD1    ( opc -- +n )       5 rshift 7 and ;    \ Data for field-1

: .WAIT     ( opc -- )          \ Decode WAIT arguments & data
    ." wait " dup field1  >r  r@ 4 / \ First polarity
    s" low high" drop  swap 4 /type \ Show pin level
    s" gpiopin irq     " drop   \ Then argument
    r> 3 and >r  r@ 4 /type
    field0                      \ Read pin or Irq number
    r> 2 = if                   \ Irq?
        dup F and . space       \ Irq number
        10 and if ." rel " then \ Irq number type
    else
        . space                 \ Pin number or offset
    then ;

: .IN/OUT   ( opc -- )      field0 ?dup 0= if 20 then  . space ;
: .OUT$     ( opc -- )
    s" pins   x      y      null   pindirspc     isr    exec   " drop
    over field1 7 /type  .in/out ;
: .OUT      ( opc -- )      ." out  "  .out$ ;
: .IN       ( opc -- )          \ Decode in arguments & data
    ." in   " dup field1 4 < if \ Low 4 arguments identical to OUT
        .out$
    else
        dup field1 dup 6 < ?type \ Invalid arguments?
        6 -  s" isrosr" drop    \ OUT specific arguments
        swap 3 /type  field0  .in/out
    then ;
: .PP       ( opc -- )          \ Decode PUSH & PULL arguments
    field1 dup 2 = >r  dup 4 and \ Is it pull?
    if    ." pull "  r> if ." ifempty " then \ Yes, it's pull
    else  ." push "  r> if ." iffull "  then \ No, it's push
    then  1 and 0= if  ." no"  then ." block  " ;

: MOV$      ( -- a )
    s" pinsx   y   nullexecpc  isr osr " drop ;
: .MOV      ( opc -- )          \ Decode MOV arguments
    ." mov  "  dup field1 dup 3 = \ Destination
    ?abort  mov$  swap 4 /type
    field0 >r  r@ 3 rshift      \ Operation
    dup 3 = ?abort
    s"    invrev" drop  swap 3 /type
    r> 7 and dup 4 = ?abort     \ Source
    dup 5 = if  drop ." status "
    else  mov$  swap 4 /type  then  space ;
: .IRQ      ( opc -- )          \ Decode IRQ arguments & number
    ." irq  "
    dup field1 dup 1 and if  ." wait " then \ Arguments
    2 and if ." clear " else ." set " then
    field0  dup 7 and . space
    10 and if ." rel " then ;   \ Irq number type
: .SET      ( opc -- )          \ Decode SET arguments & data
    ." set  " >r  r@ field1 dup 3 = ?type \ Destination argument 3 is invalid!
    dup 4 = if  drop ." pindirs "       \ Decode argument 4
    else  dup 4 > ?type                 \ Argument 5 etc. identical to MOV
         mov$  swap 4 /type
    then
    r> field0 . space ;                 \ Data

: .SIDE&DELAY ( opc -- )        \ Decode general Side Set data & Delay clock ticks
    8 rshift 1F and                     \ Field-2 data
    #side if
        optional? 0= if
            dup  5 #side -              \ No, side set everywhere?
            ." side "  rshift . space   \ Show data
        else
            dup 10 and if               \ Optional side set used?
                dup 0F and  4 #side -   \ Yes, get side set data
                ." side "  rshift . space \ Show data
            then
        then
    then
    mask and ?dup if                    \ Delay used?
        ." [" 1 .r ." ] "               \ Yes, show it
    then ;

: .JMP      ( opc -- )          \ Decode JUMP arguments & data
    s"      x=0  x--  y=0  y--  x<>y pin  osrne" drop
    ." jmp  "  over 5 rshift 7 and  5 /type
    field0 ." to: "  . space ;

create 'PIO-OPC ( -- a )
    ' .jmp , ' .wait , ' .in ,  ' .out ,
    ' .pp ,  ' .mov , ' .irq , ' .set ,


\ Less primitive decompiler
v: extra definitions
: MPSEE     ( pioaddr -- )
    1F and  base @ >r  hex
    phere swap do
        cr i 2 .r  ." : "               \ PIO address
        i code@  dup .hex  dup 0D rshift cells \ Get opcode & make index
        'pio-opc + @ execute            \ Decode each opcode from table
        i code@ .side&delay             \ Add side set & delay
        key bl <> if leave then
    loop
    r> base ! ;

: PSEE      ( -- )          0 mpsee ;

hex  v: inside definitions \ Show state machine data
: .FLD        ( u f msk -- )    >r  rshift r> and . ;

v: extra definitions
: .SM       ( sm -- )
    >r  base @ decimal  1 r@ lshift ." sm " \ Generate SM-bit mask
    0 pio@ and if ." on" else ." off" then  \ Show if SM is active
    0 r> sm-offset+ pcells 'pio + >r        \ Save SM-address
    r@ p@  8 rshift FF and 64 100 */        \ Scale divider fraq. part
    r@ p@  10 rshift  64 *  +  cr ." Clk: " \ Scale divider integer part
    0 cfg @ F4240 * 64 rot */ . ." Hz, "    \ Calc. & show frequency
    ."  Wrap: " r@ 4 + p@  dup 7 1F .fld    \ Show EXEC control
    dup 0C 1F .fld ."  Outsel: "
    dup 13 1F .fld ."  Jmp: " 18 1F .fld
    cr ." Push: " r@ 8 + p@  dup 14 1F .fld \ Show SHIFT control
    ." dir: " dup 12 1 .fld  ." auto: " dup 10 1 .fld
    ." steal: " 1F 1 .fld
    cr ." Pull: "  r@ 8 + p@  dup 19 1F .fld
    ." dir: " dup 13 1 .fld  ." auto: " dup 11 1 .fld
    ." steal: " 1E 1 .fld
    cr ." Set: " r@ 14 + p@  dup 5 1F .fld  \ Show PIN control
    dup 1A 7 .fld  ."  Side: " dup A 1F .fld
    dup 1D 7 .fld  r> 4 + p@ 40000000 and if ." optional " then
    ."  Out: " dup 0 1F .fld  dup 14 7 .fld
    ."  In: " F 1F .fld
    base ! ;

v: fresh
shield PDAS\

\ End
