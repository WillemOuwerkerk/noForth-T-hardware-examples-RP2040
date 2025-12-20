\ More standard words for noForth t(v)(#)
\ (C) 2015, Albert Nijhof & Willem Ouwerkerk
\ Updated for noForth T march 2023


v: fresh inside also       \ some definitions use inside words
\ trivia
: 0>        ( n -- flag )       0 > ;
: D-        ( dn1 dn2 -- dn3 )  dnegate d+ ;
: M+        ( d n -- d )        s>d d+ ;
: CHAR+     ( n1 -- n2 )        1+ ;
: CHAR-     ( n1 -- n2 )        1- ;
: CHARS     ( n -- n )          ; immediate
: ERASE     ( a u -- )          0 fill ;

create PAD  ( -- a )    20 allot        \ example


: SOURCE    ( -- a u )          ib #ib ;
: SAVE-INPUT    ( -- ib #ib^>in@ source-id )    @input 3 ;
: RESTORE-INPUT ( ib #ib^>in@ source-id 3 -- )  3 ?pair !input ;
: WORD      ( ch -- a )
    >r   parea r@ skip   nip ib - >in !
    r>   parse    >fhere ;

(* Double fetch & store
: 2!    ( lo hi a -- )  tuck ! cell+ ! ;
: 2@    ( a -- lo hi )  dup cell+ @ swap @ ;

hex
code 2! ( lo hi a -- )
    sp  { day sun } ldm,    \ DAY = hi, SUN = lo
    day  tos ) str,         \ !hi
    sun  tos 4 #) str,      \ !lo
    sp  { tos } ldm,        \ Pop stack
next, end-code
code 2@ ( a -- lo hi )
    day  tos 4 #) ldr,       \ @lo
    tos  tos ) ldr,          \ @hi
    day  sp -) str,          \ lo
next, end-code
*)

hex
code 2!     ( lo hi a -- )
    684D h,  680E h,  601E h,  605D h,
    688B h,  310C h,  next,
end-code
code 2@     ( a -- lo hi )
    685D h,  681B h,  1F09 h,  600D h,  next,
end-code


: [COMPILE]  ( "name" -- )  ' ?comp compile, ; immediate

header ABORT"   ' S" @ ,   reveal immediate
:noname if  inls count cr type -2 throw
        then inls drop ; drop

: ROLL  ( i*x u -- j*x )
    dup 1 <
    if drop
    else  swap >r 1- RECURSE r> swap
    then ;

\ symmetric signed division
: SM/REM    ( dn n -- rest quot )
    over >r >r   dabs r@ abs um/mod
    r> r@ xor ?negate swap   r> ?negate swap ;
: /REM      ( x1 x2 -- r q )    >r s>d r> sm/rem ;

code ARSHIFT ( a b -- c )   \ Arithmetic right shift
    D9002B20 ,  1D2320 ,  412BC908 , CA10C804 ,  46C046A7 ,
end-code


0  v: true or
    [if]
only forth 1  constant FORTH-WORDLIST fresh inside
: GET-CURRENT   v0 c@ ;
: SET-CURRENT   v0 c! ;
: GET-ORDER     ( -- wids.. n )
    v0
    dup vp - dup >r                     \ n v0 n
    0 ?do   1- dup c@ swap loop drop r> ;
: SET-ORDER     ( wids.. n -- )
    dup -1 = if drop 0 1 3 1 4 then     \ fresh
    8 over u< ?abort                    \ overflow
    v0 over - to vp
    vp swap 0
   ?do tuck c! 1+ loop drop ;

: SEARCH-WORDLIST   ( adr len wid -- 0 | xt 1 | xt -1 )
    >r
    >fhere
    v0 cell+   dup 1-
    r> over c!      \ mini search-order with 1 wid
    find)
    dup ?exit nip ;
[then]

: THENS         \ close open IFs
    begin postpone then dup 11 <> until ; immediate

\ the never dying CASE
: OF?       over = ;
: CASE      hx 88 ; immediate
: OF        postpone of? postpone if postpone drop ; immediate
: ENDOF     postpone else ; immediate
: ENDCASE   ( x -- )
   postpone drop
   begin postpone then hx 88 of?
   until drop ; immediate

\ : [DEFINED]     ( "name" -- f )     bl-word find nip 0<> ; immediate
\ : [UNDEFINED]   ( "name" -- f )     postpone [defined] 0= ; immediate

v: FRESH

\ <><>
