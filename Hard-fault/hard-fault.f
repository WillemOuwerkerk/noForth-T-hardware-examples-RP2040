\ HARDFAULT, W.O.  15-10-2025
\ Patch hard fault handler, 260 bytes
\ To extend the functionality of the one built-in noForth t
\ r0  r1  r2  r3  r12  lr  pc  xPSR
\ IP  SP  W   TOS DOES LR  PC  xPSR
\
\ Array that holdS: PC, IP, TOS & RP at the moment a fault had occurred
\ create FAULT-ADR  label-AMSTERDAM  -1 , -1 , -1 , -1 ,

chere
v: inside
need @name
v: inside
need >nfa

v: inside also  definitions
: INTERPRET?    ( a -- f )      \ 'a' within INTERPRET
    ['] interpret  [ ' ms >nfa 1- cell- ] literal  within ;

: .NAME ( a1 a u -- )       \ Search backward for the header starting a1
    rot  aligned  dup       \ Maximum word length 80 cells, start aligned!       a u a1 a1
    80 for
        dup >nfa ?dup if                         \                               a u a1 a2 nfa
            >r 2>r  2dup type  2r> r> @name type \                               a u a1 a2
            2drop  2drop  rdrop  exit            \                               -
        then
        cell-                                    \                               a u a1 a2
    next
    drop >r  type  ." address: " r> u. ;

: .FAULT ( i*x -- )     \ Search backward for the header using the saved data
    fault-adr @+  s" " .name                 \ PC
    @+ dup s"  used in " .name               \ IP
    swap @ ."   TOS: " u.                    \ TOS
    interpret? 0= if                         \ Not INTERPRET ?
        rp@ @ interpret? 0= if               \ Yes, is it a nested execution?
            cr ." Called by: "               \ Yes, browse R-stack
            rp@ cell+  10 0 ?do
                dup @ s" " .name
                dup @ interpret? if leave then \ Ready when INTERPRET is found
                ."  <- "  cell+
            loop  drop
        then
    then  ;

' .fault  to &fault
chere swap - dm .
v: fresh

\ (* Test

: t1 noop 2 @ ;
: t2 noop t1 ;
: t3 noop t2 ;
: t4 noop t3 ;
: t5 3 @ ;

: t6 noop 2 >r ;
: t7 noop t6 ;
: t8 noop t7 ;
: t9 noop t8 ;
: tA 8 >r ;
\ *)
