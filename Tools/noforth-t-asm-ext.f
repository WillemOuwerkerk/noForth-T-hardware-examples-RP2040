( Extended assembler opcodes for RP2040, 1272 bytes. )

here
v: inside also  assembler also definitions
10000 constant APSR     10001 constant IAPSR    10002 constant EAPSR
10003 constant XPSR     10005 constant IPSR     10006 constant EPSR
10007 constant IEPSR    10008 constant MSP      10009 constant PSP
10010 constant PRIMASK  10014 constant CONTROL


v: inside definitions
: ?SPECIAL  ( r -- +n )     10000 xor  dup 14 u> ?abort ; \ 0 to 14 valid

BE00 1reg+imm8 BKPT)    DE00 1reg+imm8 UDF)     DF00 1reg+imm8 SVC)

: 2REG+IMM3, ( opc -- )         \ Rd Rn imm-3 # OPC,
    >r  #)  7 ?range-u  6 lshift >r     \ Handle 3-bit literal
    3 place-reg  dest-reg               \ Origin & destination register
    2r> or or h, ;                      \ Construct & assemble opcode

v: assembler definitions \ Hint instructions!
: NOP,      BF00 h, ;      : YIELD,    BF10 h, ;
: WFI,      BF30 h, ;


\ 32-bits no operand opcodes barrier opcodes
: DSB,      F3BF8F4F 32b, ;  : DMB,      F3BF8F5F 32b, ;
: ISB,      F3BF8F6F 32b, ;


( 32-bits 2 operand opcodes, special register opcodes )
: MSR,      ( spr Rn -- )   \ <spec> Rn msr
    0F ?regs 10 lshift  F3808800 or  swap ?special  or 32b, ;
: MRS,      ( rd spr -- )   \ Rd <spec> mrs
    ?special  F3EF8000 or  swap 0F ?regs 08 lshift  or 32b, ;


( Compose slightly different opcodes, supervisor & breakpoint )
B200 2low-reg SXTH,   B240 2low-reg SXTB,   B280 2low-reg UXTH,
B2C0 2low-reg UXTB,   BA00 2low-reg REV,    BA40 2low-reg REV16,

5600 3low-reg LDRSB3) 5E00 3low-reg LDRSH3)
: LDRSB,    ( i*x -- )      ldrsb3) ;
: LDRSH,    ( i*x -- )      ldrsh3) ;

: RSBS,     #)  false ?range-u  neg, ; \ Rd Rn 0 # rsbs

BAC0 2low-reg REVSH,          : SVC,      moon swap svc) ;
: BKPT,     ip swap bkpt) ;   : UDF,      ip swap udf) ;

: ADDS.MV,  (  r r # -- )   1C00 2reg+imm3, ; \ Rd Rn imm-3 # adds.mv
: SUBS.MV,  (  r r # -- )   1E00 2reg+imm3, ; \ Rd Rn imm-3 # subs.mv

shield +ASM\
here swap - dm .
v: fresh

\ End
