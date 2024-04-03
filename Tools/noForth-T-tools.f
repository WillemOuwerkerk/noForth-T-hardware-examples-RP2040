(* noForth T(v) tools -- 1feb2023 2576 bytes, original A.N. this version W.O.

[IF] ... [ELSE] ... [THEN]  Interactive control structures
STOP?                       Stop, pause or continue
MANY                        Interactive loop
.S                          Print stack
DMP                         Dump memory from given address
WORDS                       Show words (in current vocabulary)
MSEE                        Decompile from address on stack
SEE                         Decompile word from given name
.VOCS                       Show all defined wordlists & vocabularies
.SHIELDS                    Show all defined shields
[DEFINED]                   Leave true if the words name behind it exists
[UNDEFINED]                 Leave true if the words name behind it does not exists

*)

hex  here   \ until the end, 32aligned 32wide doers

v: fresh extra definitions inside also
: STOP? ( -- true/false )
    key? dup 0= ?EXIT
    drop key  bl over =
    if drop key
    then hx 1B over = ?abort
    bl <> ;

v: inside definitions
: RECUR ( -- )  \ use only within for-next
    2r> over 0=                     \ index & unnest address
    if nip key dup 1B = ?abort      \ abort on esc
        dup bl = if drop 1          \ new index
        else ch 0 - dup 0A u< and   \ 0..9
            2* 2*                   \ new index
        then swap
    then 2>r ;

(*
  1 for ... recur next \ repeat controlled by key
  esc = abort
  space bar = once again
  key 0..9 = n*4 times
  rest = ready
*)

hex
v: extra definitions
: PCHAR ( x -- ch )    dup 7F < and bl max ;

v: extra definitions
: MANY   ( -- )  ?stack  >in @ stop? and >in ! ;

v: forth definitions
: .S ( -- )
    ?stack (.) space
    depth false
    ?do  depth i - 1- pick
        base @ 0A = if . else u. then
    loop ;

v: extra definitions
\ ----- DUMP - 07mar23 an/wo
: DMP ( a -- )
    base? swap  hex
    1 for
        cr dup 5 .r ." : "
        8 for  count 3 .r  next  8 -  ."  |"
        8 for  count pchar emit  next ." | "
    recur next  drop  to base? ;

v: only definitions  extra also  forth also  inside
\ nieuwe versie 2nov20 + iwords
: WORDS   ( -- )  v:  (*
 ['] <> >r begin [ 2>r ]   (            \ no vocs
*)
    hot flybuf 20 move cr
    begin false dup                     \ voor threada en lfa
        flybuf
        8 for 2dup @ u<
            if  dup @ 2nip over
            then cell+
        next drop
        dup stop? 0= and
    while                               \ threada lfa
        dup @voc
v:      vp c@ = (*
        2 r@ execute        (           \ no vocs
*)
        if  dup lfa>n space count 1F and type space
            48 hor < if cr then
        then compile@ swap !            \ unlink
    repeat 2drop
v:  (*
    rdrop ; : IWORDS ['] = >r           \ no vocs
    [ 2r> ] again           (
*)
;

v: fresh inside definitions
: @NAME     ( a -- a+1 +n )     count 7F and ;

: >NFA      ( a -- nfa | 0 )    \ >NFA returns 0 when no header is found!
    dup 3 and 0= if                     \ 32aligned?
        dup origin here within          \ In noForth code area?
        if  dup 2 - h@ FFFF = 2* +      \ Skip 2byte alignment
            dup 1- c@ FF = +            \ skip 1byte alignment
            1-  false                   \ count
            begin
                over c@
                dup ch ! ch a within    \ Char range = 21 61
                swap ch { 7F within or  \ Char range = 7B 7F
            while
                -1 /string              \ walk backwards through name
            20 over < until
            then  ( a +n )
            ?dup if
                over c@  7F and  =      \ count ok? \ v
                if  dup 1 and ?exit     \ nfa odd -> ok
        then then then
    then  false and ;

: ?TEXT     ( a -- ta|0 )               \ Search for text string
    dup c@ 7F and  1 33 within if       \ 1 to 51 chars?                a
        dup @name                       \ No, check string              a
        for
            count 7F BL within if       \ Not ASCII?                    a a+
                r> 2drop  dup -  exit   \ Leave for-next and exit       0
            then
        next                            \                               a a+
        count FF = if  drop exit  then  \ Aligned string?               a|a a+
        1 and ?exit                     \ No, in CFA, then ready
    then  dup - ;

: ?HEAD     ( a -- ta|0 )
        dup c@ 7F and                   \ Read voc. id                  a v1
v:      wid-link cell+ h@ >             \ Invalid voc?                  a f
-v:     4 >                             \ Idem                          a f
        if  dup -  exit  then           \ Yes, leave zero               a|0
        1+ ?text ;


0 value 'SEE
: .DATA     ( +n -- )
    cr >r  'see 0A u.r ." : "               \ .adr
    'see r@ for c@+ pchar emit next drop    \ .4chars
    'see r> 4 = if @ 0B else h@ 5 then      \ .contents 32/16 bits
    u.r space space ;

: .INFO     ( -- f )    \ Show all words data
    'see >nfa ?dup if                   \ Valid header?
        ." --- "
v:      dup 1- c@ 7F and .voc           \ Show vocabulary
        dup @name type                  \ The words name
        c@ 80 and if  ."  imm" then space
        'see @ cell- >nfa ?dup if
            (.) space @name type space  \ made by ..
        then
        false exit                      \ ----
    then  true ;

: .CFA      ( -- )      \ Decode CFA contents
    'see compile@  >nfa ?dup if         \ contents = nfa ?
        @name type exit                 \ .compiled word
    else                                \ compile@ = body?
        'see compile@ cell- >nfa ?dup if
            (.) space @name type space  \ made by ..
            exit
        then
    then ;

: .RAM      ( -- )                      \ Decode RAM location?
    'see @ dup hot uhere within
    swap 1 and 0= and  if               \ even RAM location?
        'see @ origin ( ra ca )
        begin
            begin
                4 + here over u<        \ Not in dictionary?
                if  2drop exit  then    \ Yes, ready
            2dup @ = until              \ No, RAM address equal?
            dup cell- >nfa ?dup if      \ Ok, show it's name!
                @name type space (.) ." RAM location"
                2drop exit
            then
        again
    then ;

\ : .LINK     ( -- )
\    'see @ origin 'see within if    \ Valid link?
\        ."    linked to "           \ Yes,
\        'see compile@ lfa>n @name type \ Show words name
\    then ;

: DECOM     ( -- )
    'see ?text ?dup if          \ Inline string found?
        space ch " emit         \ Yes, show
        count type  ch " emit
    then
    'see cell+ ?head ?dup if    \ Check for HEADER too?
        dup c@ 7F and 20 < if   \ Yes, show it's a words name
            cr   ." Name " dup
            @name type  \ .link
        then drop
    then
    4 .data  .info if .cfa then
    .ram  4 +to 'see ;

v: fresh inside
: MSEE      ( a -- )
    -4 and to 'see
    1 for
        12345 decom
        12345 <> ?abort
        recur
    next ;

: SEE           ( <name> -- )       ' msee ;


v: extra definitions  inside
v: : .VOCS         ( -- )  \ Show all present vocabularies
v:    wid-link
v:    c? [if] 2 + [else] cell+ [then]
v:    h@ 1+  0
v:    (.) space
v:    do  i .voc  loop ;

v: extra definitions  inside
: .SHIELDS      ( -- )  \ Show all present shields
    (.)  ['] noforth\ dup @ here rot
    do  i @ over =
        if  i >nfa ?dup
            if  space count 1F and type space
            then
        then
    cell +loop  drop ;

v: forth definitions
: [DEFINED]     ( "name" -- f )     bl-word find nip 0<> ; immediate
: [UNDEFINED]   ( "name" -- f )     postpone [defined] 0= ; immediate

v: fresh
shield TOOLS\
here swap -  dm .

\ End
