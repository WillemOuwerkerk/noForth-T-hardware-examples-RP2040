\ Add noForth specific tests ( Use: 80 ms line delay)

clr-errors
\ *BIS *BIC *BIX BIT*  **BIS **BIC **BIX BIT** BITMASK

variable BITS  0 bits !
T{  80 bits *bis  bits @ -> 80 }T
T{  80 bits *bic  bits @ -> 00 }T
T{  80 bits *bix  bits @ -> 80 }T
T{ 100 bits *bis  bits @ -> 80 }T
T{ 100 bits bit* -> 0 }T
T{  80 bits bit* -> 80 }T

T{ 200 bits **bis  bits @ -> 280 }T
T{ 200 bits **bic  bits @ -> 80 }T
T{ 200 bits **bix  bits @ -> 280 }T
T{ 100 bits **bis  bits @ -> 380 }T
T{ 200 bits bit** -> 200 }T
T{ 100 bits bit** -> 100 }T
T{  80 bits bit** -> 80 }T
T{ 7 bitmask bits bit** -> 80 }T
T{ 20 bitmask bits bit** -> 0 }T


\ B-B B+B  H-H H+H  ><
T{ 123456 b-b -> 56 34 }T
T{ 123456 h-h -> 3456 12 }T
T{ 3456 12 b+b -> 1256 }T
T{ 3456 12 h+h -> 123456 }T
T{ 112233 >< -> 3322 }T


\ FOR NEXT
: FN    for i next ;

T{ 0 fn -> }T
T{ 8 fn -> 7 6 5 4 3 2 1 0 }T


\ HX DM BN DM CH
T{ hx FF -> dm 255 }T
T{ dm 32 -> hx 20 }T
T{ hx FF -> bn 11111111 }T
T{ dn 11 -> bn 10001. }T
T{ ch A ch a -> dm 65 dm 97 }T


\ C@+ H@+ H@ H!
variable TBL  12345678 tbl !
T{ tbl c@+ swap c@+ -> 78  tbl 2 +  56 }T
T{ tbl h@+ swap h@+ -> 5678  tbl cell+  1234 }T
T{ tbl h@ -> 5678 }T
T{ 1234 tbl h!  tbl @ -> 12341234 }T


\ +TO ADR INCR
0 value CNT1
T{ cnt1 -> 0 }T
T{ incr cnt1  cnt1 -> 1 }T
T{ 11 +to cnt1 cnt1 -> 12 }T
T{ adr cnt1 @ -> 12 }T


\ 2NIP 2ROT -2ROT 2TUCK  'RP@' RDROP  BOUNDS -ROT ROLL
need 2rot  need 2tuck  need -2rot
need -rot  need roll

T{ 1. 2. 3. 2nip -> 1. 3. }T
T{ 1. 2. 3. 2rot -> 2. 3. 1. }T
T{ 1. 2. 3. -2rot -> 3. 1. 2. }T
T{ 1. 2. 3. 2tuck -> 1. 3. 2. 3. }T
T{ 1234 5678 2>r rdrop r> -> 1234 }T
T{ 5 6 7 8 3 roll -> 6 7 8 5 }T
T{ 5 6 7 8 1 roll -> 5 6 8 7 }T
T{ 5 6 7 8 0 roll -> 5 6 7 8 }T
T{ 20 10 bounds -> 30 20 }T
T{ 5 6 7 8 -rot -> 5 8 6 7 }T


\ DU2/ ?NEGATE ?DNEGATE DU*S DU/S ARSHIFT 0> D- M+ DLSHIFT DRSHIFT 2LOG
\ Write correct for 16 bits and 32 bits systems
need arshift  need 0>

T{ 123 -1 ?negate -> -123 }T
T{ 123. -1 ?dnegate -> -123. }T
T{ -1. du2/ -> 7FFFFFFFFFFFFFFF. }T
T{ 1,FFFF,FFFF. du2/ -> FFFF,FFFF. }T
T{ FFFF,FFFF. 10 du*s -> F,FFFF,FFF0. }T
T{ F,FFFF,FFFF. 10 du/s -> FFFF,FFFF. 0F }T
T{ dm -123 1 arshift -> dm -62 }T
T{ dm 123 1 arshift -> dm 61 }T
T{ 0 0> -> false }T
T{ 1 0> -> true }T
T{ -1 0> -> false }T

need D-  need M+
T{ 100. 200. d- -> -100. }T
T{ -100. 200. d- -> -300. }T
T{ 100. -200. d- -> 300. }T
T{ 100. -200 m+ -> -100. }T
T{ -100. -200 m+ -> -300. }T
T{ 100. 200 m+ -> 300. }T
T{ -100. 200 m+ -> 100. }T

need DLSHIFT  need DRSHIFT
T{ -1. 20 drshift -> FFFF,FFFF. }T
T{ -1. 20 drshift -> -1 0 }T
T{ -1. 20 dlshift -> FFFF,FFFF,0000,0000. }T
T{ -1. 20 dlshift -> 0 -1 }T

need 2LOG
T{ 0 2log -> 0 }T
T{ 1 2log -> 0 }T
T{ 2 2log -> 100 }T
T{ 20 2log -> 500 }T


\ UVARIABLE UVALUE DIVE ?EXIT D.STR DU.STR
( uvariable V1 ) 0 uvalue V2
T{ V2 -> 0 }T
T{ incr V2  V2 -> 1 }T
T{ 11 +to V2  V2 -> 12 }T
T{ adr V2 @ -> 12 }T

: D1    1  dive  4 ;
: D2    2 ;
: D3    d1 d2 3 ;
T{ D3 -> 1 2 3 4 }T

: E1    ?exit 2 ;
T{ true e1 -> }T
T{ false e1 -> 2 }T

: .D$    d.str 2dup type ;
T{ -100. .d$ nip -> 4 }T
T{ 100. .d$ nip -> 3 }T

: .DU$   du.str 2dup type ;
T{ -100. .du$ nip -> 10 }T
T{ 100. .du$ nip -> 3 }T


\ ON OFF CELL- UPPER UPC >DIG DIG?
need off
variable V3
T{ v3 off v3 @ -> 0 }T
T{ v3 on v3 @ -> -1 }T

T{ 100 cell- -> FC }T
T{ 4 cell- -> 0 }T
T{ 0 cell- -> -4 }T

T{ ch a UPC -> ch A }T
T{ ch A UPC -> ch A }T
T{ ch 1 UPC -> ch 1 }T

create AAP  3 c,  ch a c,  ch a c,  ch p c,  align
T{ aap count swap c@ -> 3 ch a }T
T{ aap count 2dup upper  swap c@ -> 3 ch A }T

T{ 0 >dig -> 30 }T
T{ dm 15 >dig -> 46 }T
T{ ch 9 dm 10 dig? -> 9 true }T
T{ ch A dm 16 dig? -> dm 10 true }T


\ H, M,
create H1  1234 h, 5678 h,
T{ h1 h@+ swap h@ -> 1234 5678 }T
T{ h1 2 + h@ -> 5678 }T

create M1 s" abcdefg" m,  align
T{ M1 c@+ swap c@+ swap c@ -> ch a  ch b  ch c }T
T{ M1 4 + c@+ swap c@+ swap c@ -> ch e  ch f  ch g }T


\ J K CASE CRC PCHAR
need J  need CASE  need CRC
: L1    2 0 do  2 0 do  2 0 do j k loop loop loop ;
T{ L1 -> 0 0 0 0 1 0 1 0 0 1 0 1 1 1 1 1 }T

T{ 10 pchar -> bl }T
T{ 41 pchar -> ch A }T
T{ 80 pchar -> bl }T

T{ AAP c@+ crc -> 2B5FF6D0 }T
T{ M1 7 crc -> F88AC628 }T

: CASE1 ( +n1 -- +n2 )
    case
        0 of  1  endof
        1 of  2  endof
        2 of  3  endof
              0 swap
    endcase ;

T{ 0 case1 -> 1 }T
T{ 1 case1 -> 2 }T
T{ 2 case1 -> 3 }T
T{ 3 case1 -> 0 }T
T{ 4 case1 -> 0 }T


\ S<> $VARIABLE $! $@ $+! $. $C+! -TAIL -HEAD
need $variable  need -head  need -tail

10 $variable STRING

s" noForth" string $!

T{ s" noForth" string $@ s<> -> false }T
T{ s" noforth" string $@ s<> -> true }T

s"  t" string $+!
T{ s" noForth t" string $@ s<> -> false }T
T{ string $@ $. -> }T

need -head  need -tail

T{ string $@ 2 -head $. -> }T
T{ string $@ 2 -head 3 -tail $. -> }T


\ BITARRAY LOC *SET *CLR GET* ZERO COPY COUNT* UP?
need bitarray  need *copy

10 bitarray B1   10 bitarray B2

T{ B1 *zero  B1 @+ swap @ -> 1 0 }T
T{ 0 B1 *set 3 B1 *set -> }T
T{ 0 B1 get* 1 B1 get* 3 B1 get* -> 1 0 8 }T
need count*

T{ B1 count* -> 2 }T
T{ B1 B2 *copy -> }T
need *up?

T{ B1 *up?  B1 *up?  B1 *up? -> 0 true 3 true 0 }T
T{ B2 *up?  B2 *up?  B2 *up? -> 0 true 3 true 0 }T
T{ 0 B1 *set  9 B1 *set -> }T
T{ 0 B1 get* 1 B1 get* 9 B1 get* -> 1 0 2 }T
T{ 0 B1 *clr -> }T
T{ 0 B1 get* 1 B1 get* 9 B1 get* -> 0 0 2 }T

.errors

\ End
