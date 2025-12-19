(*  noForth T(humb) smaller assembler - 05dec2025
Not all instructions are implemented here.
The missing instructions are in the file 'noforth-t-asm-ext.f'

(c) W.O, W.J, J.J.H & A.N. 2023 RP2040 ASM basic opcodes, vsn 0.8: 5720 bytes

With Forth literal pool, ITC & argument macro's & most opcodes
Rewritten paren argument macro handler for LDR, etc. smaller & correct!

Immediate:
    Opcod ddd iiiiiiii      8-bit immediate, 1 register, low
    Opcode.... iiiiiii      7-bit immediate, RP implicit
    Opcod iiiii mmm ddd     5-bit immediate, 2 registers, low
    Opcode. iii nnn ddd     3-bit immediate, 2 registers, low
Register:
    Opcode.. d .... ddd     1 register, all
    Opcode....  mmm ...     1 register, low
    Opcode....  mmm ddd     2 registers, low
    Opcode. mmm nnn ddd     3 registers, low
    Opcode.. d mmmm ddd     2 registers, all
    Opcode...  mmmm ...     1 register, all
Push, Pull:
    Opcode.  M rrrrrrrr     R0 to R7 & LI/PC (special case of 8-bit imm)
Various:
    Opcode..   ...i....     CPS (Whole 16-bits pattern)
    Opcode..   iiiiiiii     BKP & SVC (Special case of 8-bit imm)
    Opcode..   ........     Whole 16-bits pattern
Branches:
    Opco cccc  bbbbbbbb    Conditional branch
    Opcod   bbbbbbbbbbb    Branch
    Opcode.. x mmmm 000    BX & BLX (Special case of 2 register, all)
32-bit opcodes:
    Opcode...... nnnn ........ rrrrrrrr     2 registers, all
    Opcode.. ........ ........ ........     Whole 32-bits pattern
    Opcod S .......... .J.J ...........     Branch & link

*)

here  hex \ noForth additions
v: inside also  assembler also  inside definitions

v: assembler definitions    \ Add register names & addressing modes
8000 constant IP   8001 constant SP   8002 constant W     8003 constant TOS
8004 constant HOP  8005 constant DAY  8006 constant SUN   8007 constant MOON
8008 constant WW   8009 constant XX   800A constant YY    800B constant ZZ
800C constant DOES 800D constant RP   800E constant LR    800F constant PC
\ 8000 constant R0   8001 constant R1   8002 constant R2    8003 constant R3

\ Addressing modes
9003 constant )    9004 constant -)    9005 constant )+

v: inside definitions
: LIT?      ( x -- x f )    dup IP u< ;             \ Literal argument

v: assembler definitions
: R)        ( x -- x )
    dup ww u< ?exit             \ Low registers, all ok
    dup PC =  over RP = or      \ PC or RP, are ok too
    ?exit  true ?abort ;        \ All other registers are invalid!

    : #)        ( x -- x )      lit? 0= ?abort ;    \ Not a literal index?
v:  : #         ( x -- x )      #) ;                \ Not a literal?
-v: : #  state @ if  postpone #  exit  then  #) ; immediate

v: inside definitions
: 32B,      ( opc -- )      h-h  h, h, ;            \ For 32-bits opcodes
: >REG      ( r -- +n )     8000 xor ;              \ Convert reg. to number
: ?REG      ( r# -- )       <> ?abort ;             \ Invalid register used
: ?REGS     ( r r# -- +n )  >r >reg dup r> u> false ?reg ; \ 0 to R#
: ?RANGE-U  ( x xr -- x )   >r dup r> 1+ u< 0= ?abort ; \ Range control unsigned
: ?DIST     ( x xr -- )     1+ tuck 2/ + swap u< 0= ?abort ; \ Jump out of range
: >DIST     ( ad ao -- o )  cell+ - 2/ ;            \ Calc. jump distance
: DEST-REG  ( r x1 -- x2 )  swap 7 ?regs or ;       \ Only low registers
: PLACE-REG ( r +n -- x )   >r 7 ?regs  r> lshift ; \ Idem

: 2LOW-REG  ( opc -- )      \ Rd Rn OPC,
    create ,  does> @ >r    \ Base opcode
      3 place-reg  dest-reg \ Origin & destination register
      r> or  h, ;           \ Construct & assemble opcode

v: assembler definitions
4000 2low-reg ANDS,   4040 2low-reg EORS,   4140 2low-reg ADCS,
4180 2low-reg SBCS,   41C0 2low-reg RORS,   4200 2low-reg TST,
4240 2low-reg NEG,    42C0 2low-reg CMN,    4300 2low-reg ORRS,
4340 2low-reg MULS,   4380 2low-reg BICS,   43C0 2low-reg MVNS,
\ B200 2low-reg SXTH,   B240 2low-reg SXTB,   B280 2low-reg UXTH,
\ B2C0 2low-reg UXTB,   BA00 2low-reg REV,    BA40 2low-reg REV16,
\ BAC0 2low-reg REVSH,

v: inside definitions
4080 2low-reg LSLS)   40C0 2low-reg LSRS)   4100 2low-reg ASRS)
0000 2low-reg MOVS)   4280 2low-reg CMP)  \ MOVS) = LSLS#5 with 0 shift value

: 2ALL-REG  ( opc -- )      \ Rd Rn OPC,  ( all registers )
    create ,  does> @ >r        \ Base opcode
      0F ?regs  3 lshift        \ Origin register
      swap 0F ?regs  dup 7 and  \ Add destination register
      swap 8 and  4 lshift or   \ Add highest dest. bit too
      or  r> or  h, ;           \ Construct & assemble opcode

4400 2all-reg ADDL)     v: assembler definitions
4600 2all-reg MOV,      v: inside definitions
4500 2all-reg CMPL)     4700 2all-reg BX)

: 3LOW-REG  ( opc -- )      \ Rd Rn Rm OPC,
    create ,  does> @ >r
      6 place-reg  swap 3 place-reg or  \ Make M & N-origin register
      dest-reg  r> or h, ;  \ Add destination register & assemble opcode
5000 3low-reg STR3)     5400 3low-reg STRB3)    5200 3low-reg STRH3)
5C00 3low-reg LDRB3)    5A00 3low-reg LDRH3)    5800 3low-reg LDR3)
\ 5600 3low-reg LDRSB3)   5E00 3low-reg LDRSH3)
v: assembler definitions
1800 3low-reg ADDS.MV,  1A00 3low-reg SUBS.MV,

: 2REG+IMM5 ( opc -- )      \ Rd Rn imm-5 # OPC,
    create ,  does> @ >r
      #)  1F ?range-u  6 lshift >r      \ Handle 5-bit literal
      3 place-reg  dest-reg             \ Origin & destination register
      2r> or or h, ;                    \ Construct & assemble opcode
6000 2reg+imm5 STR#5   7000 2reg+imm5 STRB#5   8000 2reg+imm5 STRH#5
6800 2reg+imm5 LDR#5   7800 2reg+imm5 LDRB#5   8800 2reg+imm5 LDRH#5

: SP+IMM7,  ( i*x opc -- )  \ RP imm-7 # OPC,
    >r  #)  2/ 2/  swap RP ?reg  7F ?range-u  r> or h, ;

: 1REG+IMM8 ( opc -- )      \ Rd imm-8 # OPC,
    create ,  does> @ >r
      #)  r@ A000 = if 2/ 2/ then       \ ADR, convert to cell offset
      dup 100 and  dup if               \ Literal? check for LR/PC data
          r@ BC00 = r@ B400 = or 0= ?abort \ These are only valid for PUSH & POP!
      then
      swap FF and  FF ?range-u or       \ Check & add 8-bit literal
      swap 8 place-reg or  r> or h, ;   \ Add dest. register & assemble opcode

v: assembler definitions
0000 2reg+imm5 LSLS.MV,  0800 2reg+imm5 LSRS.MV,  1000 2reg+imm5 ASRS.MV,

333 constant {                  \ Control number, for '}'
: }   ( ... -- bitmasker )      \ works in definitions too
    false  true >r              \ Start mask at zero
    begin   swap dup 8000 and   \ Is it a register?
    while   0F ?regs dup        \ Valid register arg?
            8 0E within ?abort  \ Invalid register range?
            r> over u< ?abort   \ New mask not smaller?
            8 min  dup >r       \ R0 to R7 plus PC or LR
            bitmask  or         \ Convert to new bitmask & add
    repeat  rdrop  drop ;       \ Leave arguments

v: inside definitions
3000 1reg+imm8 ADDS#8   3800 1reg+imm8 SUBS#8
2000 1reg+imm8 MOVS#8   2800 1reg+imm8 CMP#8
9000 1reg+imm8 STRSP#8  9800 1reg+imm8 LDRSP#8
4800 1reg+imm8 LDR#8    A800 1reg+imm8 ADDSP#8
B400 1reg+imm8 PUSH)    BC00 1reg+imm8 POP)
v: assembler definitions
A000 1reg+imm8 ADR,  C000 1reg+imm8 STM,  C800 1reg+imm8 LDM,

\ 16-bits no operand opcodes ( -- )
: NOOP,     ww ww mov, ;
: CPSIE,    B662 h, ;      : CPSID,    B672 h, ;
: WFE,      BF20 h, ;      : SEV,      BF40 h, ;

\ Add multi format opcodes:
: ADD,      ( i*x -- )  ( 172 bytes )
    lit? 0= if  addl) exit  then    \ Register data: Rd Rn add
    >r  over >reg 8 < if            \ Save imm. check low destination?
        dup PC = if                 \ Yes, source is PC?
            drop  r> adr,  exit     \ Ok, Rd PC imm8 # add
        then
        RP = if                     \ No, source is RP?
            r> 2/ 2/ addsp#8  exit  \ Ok, Rd RP imm8 # add
        then
    then   r> B000 sp+imm7, ;       \ RP imm7 # add
: ADDS,     ( i*x -- )
    lit? if  adds#8  exit  then     \ Rd imm-8 # adds
    over swap adds.mv, ;            \ Register data: Rd Rn adds
: SUBS,     ( i*x -- )
    lit? if                         \ Literal data?
        2>r  dup RP <> if  2r> subs#8 exit then \ Yes, RP only? Rd imm-8 # subs
        r> r> swap B080 sp+imm7,  exit \ No; RP imm-7 # subs
    then  over swap subs.mv, ;      \ Register data: Rd Rn subs
: MOVS,     ( i? -- )       \ Rd imm-8 # movs | Rd Rn movs
    lit? if  movs#8 exit  then  movs) ;
: CMP,      ( i*x -- )
    lit? if  cmp#8 exit  then       \ Rd imm-8 # cmp
    2dup max  >reg 8 <              \ Largest register less then 8
    if  cmp) exit  then  cmpl) ;    \ Low or all: Rd Rn cmp
: LSLS,     ( i*x -- )      lit? if >r dup r> lsls.mv, exit then lsls) ;
: LSRS,     ( i*x -- )      lit? if >r dup r> lsrs.mv, exit then lsrs) ;
: ASRS,     ( i*x -- )      lit? if >r dup r> asrs.mv, exit then asrs) ;

v: inside definitions
: PAREN?    ( i*x -- f )    lit?  over PC u> or ;   \ Lit or: ) )+ -)
0 value +P  \ Hold register for PAREN+ (macro arguments)
: PAREN     ( reg arg +n -- reg arg )       \ Handle: ) )+ -)
    >r  lit? if  rdrop  0 to +p exit  then  \ Do nothing on a literal!
    dup )+ = if over r@ h+h else false then to +p   \ Post increment
    dup -) = if  drop  dup r> subs,  false  \ Pre decrement
    else  rdrop  drop false  then ;         \ Just an offset
: PAREN+    ( -- )
    +p if
        +p h-h over RP =
        if    over swap add,  exit  \ RP used?
        then  adds,                 \ No, other registers
    then ;

v: assembler definitions
: STR,      ( i*x -- )  \ rs rb rm ) str/ldr - rs rb imm #) str/ldr     ra rb +n
    paren? if
        cell paren  2/ 2/ >r  dup RP = if   \ Using RP? also ) )+ -)    ra rb +n/4
            drop  r> strsp#8                \ Rs RP imm8 #) str
        else  r> str#5  then paren+ exit    \ Rs Rb imm5 #) str
    then  str3) ;                           \ Rs Rb Rm str

: LDR,      ( i*x -- )  \ rd rn <x> LDR,
    paren? if
( )     dup )+ = if                             \ Optimise )+ separately?
( )         over WW < if                        \ Yes, ...
( )             drop swap >reg bitmask  ldm,    \ Yes, replace by LDM
( )             exit
( )         then
        then
        cell paren  2/ 2/ >r dup PC =       \ Using PC? also ) )+ -)
        if  drop  r> ldr#8 exit then        \ Rd pc imm8 # ldr
        dup RP = if  drop  r> ldrsp#8       \ RP?   Rd RP imm8 # ldr
        else  r> ldr#5  then  paren+  exit  \ No,   Rd Rn imm5 # ldr
    then  ldr3) ;                           \ Rd Rn Rm ldr

: STRB,     ( i*x -- )
    paren? 0= if  strb3) exit  then     \ Rs Rb Rm strb
    1 paren  strb#5  paren+ ;           \ Rs Rb imm5 #) strb, also ) )+ -)
: LDRB,     ( i*x -- )
    paren? 0= if  ldrb3) exit  then     \ Rs Rb Rm ldrb
    1 paren  ldrb#5  paren+ ;           \ Rs Rb imm5 #) ldrb, also ) )+ -)

: STRH,     ( i*x -- )
    paren? 0= if  strh3) exit then      \ Rs Rb Rm strh
    2 paren  2/  strh#5  paren+ ;       \ Rs Rb imm5 #) strh, also ) )+ -)
: LDRH,     ( i*x -- )
    paren? 0= if  ldrh3) exit then      \ Rs Rb Rm ldrh
    2 paren  2/  ldrh#5  paren+ ;       \ Rs Rb imm5 #) ldrh, also ) )+ -)


\ Compose slightly different opcodes
: SUB,      B080 sp+imm7, ;             \ RP imm7 # sub
\ : RSBS,     false ?range-u  neg, ;      \ Rd Rn 0 # rsbs
: BX,       ip swap bx) ;     : BLX,      ww swap bx) ;
: POP,      ip swap pop) ;    : PUSH,     ip swap push) ;

v: inside definitions
\ .....7FF - 11 bits, bit 0 to 10   ..1FF800 - 10 bits, bit 11 to 20
\ ..600000 -  2 bits, bit 21 & 22   ..800000 - Sign bit, bit 23
: BL)       ( ad ao -- opc ) \ 32-bits branch & link opcode, range is 24-bits
    >dist  dup FFFFFF ?dist         \ Calc. offset & check range
    F000D000  over 7FF and or       \ Add first 11 bits to basic opcode
    over 1FF800 and  5 lshift or    \ Add next 10 bits
    over 0< >r  swap 0A rshift      \ Save sign & get bit 21&22 to bit 11&12
    invert  r@ xor  dup 800 and     \ Invert & add sign to J1 & J2, J2 is ok
    swap 1000 and  2* or  or        \ J1 to bit 13 & add to J2 and to opcode
    r> 4000000 and or ;             \ Add J1, J2 and sign, generate opcode

\ Forth conditionals, structure data & security are marked with an 's'
\ Dx00: 0=EQ,  1=NE, 2=CS, 3=CC, 4=Minus (0<), 5=PL (Pos), 6=VS (Overflow)
\       7=VC (No overflow), 8=HI (U>), 9=LS (U<=), A=GE (>=), B=LT (<),
\       C=GT (>), D=LE (<=), E=AL (Always)
: ?OFFSET   ( n opc -- n )  \ Build 7 or 11-bit branch offset
    E000 =  700 and  FF or >r  dup r@ ?dist  r> and ;

\ 55 constant SYS-CODE      \ Code structure
\ 66 constant SYS-IF,       \ for then, ahead, repeat,
\ 77 constant SYS-BEGIN,    \ for until, again, repeat,
\ 88 constant SYS-COND      \ Conditionals
: CONDITIONAL   create ,  does> @ 88 ; ( -- c s )

v: assembler definitions
    D100 conditional =?     D300 conditional CS?    D500 conditional NEG?
    D700 conditional VS?    D900 conditional U>?    DA00 conditional <?
    DD00 conditional >?

: NO        ( c1 -- c2 )    >r 100 xor r> ;

: IF,       ( c -- s )
    88 <> ?abort  here  swap h,  66 ; \ Compile opcode, leave data
: THEN,     ( s -- )
    66 ?pair >r  here r@ >dist      \ Check structure & calc. offset
    r@ h@ ?offset r@ h@ or  r> h! ; \ Check and add jump forward
: AHEAD,    ( -- s )        E000 88 if, ;
: ELSE,     ( s0 -- s1 )    ahead,  2swap  then, ; \ Jump always, resolve IF,

: UNTIL,    ( s c -- )
    88 <> ?abort >r  77 ?pair           \ Valid test and structure
    here >dist  r@ ?offset r> or h, ;   \ Check & assemble jump backwards
: BEGIN,    ( -- s )            here  77 ;       \ Leave data only
: AGAIN,    ( s -- )            E000 88 until, ; \ Jump to BEGIN,
: WHILE,    ( s0 c -- s1 s0 )   if,  2swap ;     \ Stay in loop on condition
: REPEAT,   ( s1 s0 -- )        again, then, ;   \ Close a BEGIN, WHILE, loop
: BL,       ( a -- )            here bl)  32b, ; \ Jump & link to address 'a'
: NEXT      ( -- )              state @ if  postpone next exit  then  next, ; immediate

: (DATA   ( -- datasys )    here cell mod if noop, then  w pc mov, ahead, ;
: DATA)   ( datasys -- )    align  then, ;

(* In target file:

: NONAME   ( -- cfa cfa 55 )    here dup  cell+ ,  dup 55  assembler ;
: CODE     ( <name> -- cfa 55 ) header  noname  nip ;
: ROUTINE  ( <name> -- cfa 55 ) create  here cell-  55  assembler ;
: END-CODE ( cfa 55 -- )        previous also  55 ?pair  drop  reveal  align ;

: CODE>   ( ?? -- cfa 55 )
    created lfa> dup @ over > ?abort \ CFA already rewritten?
    align here over ! 55 assembler ; \ Fill CFA with code address

*)

v: fresh
hex
shield ASM\
here swap -  dm .

