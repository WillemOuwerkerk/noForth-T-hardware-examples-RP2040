\ Miniature independent tracer, outputs data over RS232.
\ Using it's own conversion buffer, based on A.N's example on P.F.W.
\ Prints 2, 3, 4 or 8 digits

hex v: inside also definitions
: .CR       ( -- )      0D emit)  0A emit) ;
: .SPACE    ( -- )      bl emit) ;
: .1HX      ( x -- )    0F and  >dig  emit) ; \ Print last digit of x in hex

create NHX 10 allot
: .NHX ( x n -- )       \ Print last n digits of x in hex
    1 max  10 min >r         \ x r: n
    r@ for  dup nhx i + c!  4 rshift  next  drop
    nhx  r> for  c@+ .1hx  next  drop .space ;

v: extra definitions
: .B  2 .nhx ;   : .P  3 .nhx ;   : .H  4 .nhx ;   : .W  8 .nhx ;

: .HEXDUMP  ( a u -- )  \ Small dump routine
    .cr  0 ?do
        c@+ .b  i 10 mod 0= if .cr then
    loop  drop ;

: .DUMP     ( a u -- )  \ Small classic dump routine
    .cr  0 ?do
        dup  10 for  c@+ .b  next  drop .space
        10 for
            c@+ dup 7F < and BL max emit)
        next  .cr
    10 +loop  drop ;

v: fresh
