\ noForth library file, about 370 kBytes

chapter COPYRIGHT
cr .(    COPYRIGHT {c} 2024-2026, Willem Ouwerkerk & Albert Nijhof    )
cr .(                          LICENSE                                )
cr .( This program is free software; you can redistribute it and/or   )
cr .( modify it under the terms of version 2 of the GNU General       )
cr .( Public License as published by the Free Software Foundation.    )
cr
cr .( This program is distributed in the hope that it will be useful, )
cr .( but WITHOUT ANY WARRANTY; without even the implied warranty of  )
cr .( MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the    )
cr .( GNU General Public License for more details.                    )
%%

chapter VERSION
cr .(       NEED version 0.52      )
cr .(      Library version 0.50    )
cr .(                              )
cr .( The size is about 370 kBytes )
%%

chapter UART
\ Install UART interface
: UART  ( -- )
    ['] key)    to 'key
    ['] key?)   to 'key?
    ['] emit)   to 'emit ;
%%

chapter USB
\ Install USB interface
v: fresh  inside
: USB   ( -- )
    ['] usb-key?    to 'key?
    ['] usb-key     to 'key
    ['] usb-emit    to 'emit ;
v: fresh
%%

chapter TRY
: TRY       run ;  \ Pseudonym for RUN
%%

chapter ADD
: ADD       need ; \ Pseudonym for NEED
%%

chapter RESTORE-LIB
\ Restore library pointers using adjust
need last\

hex v: inside
: ADJUST        ( -- )
    10081000 dup to lib-org  begin  c@+ FF = until  1- to libhere ;

adjust cr .( Library pointers are set: ) lib-org . libhere .

s" CORE\"       find-chapter 1- to hardware)
s" BIT-TOGGLE1" find-chapter 1- to pio)

cr .( Shortcuts HARDWARE & PIO are also set: ) hardware) . pio) .
v: forth
last\

v: fresh
%%

chapter LOOK
\ A library consists of 09 {tab}, 0D {cr} and ASCII chars
\ ranging from blank to ~ others chars are not allowed
\ LOOK to the code of any chapter in the library
v: inside also  definitions \ Show the library source code of a chapter
: .LINE     ( a1 -- a2 ch ) begin c@+ dup BL < 0= while emit repeat ;
: .DIVIDER  ( -- )          cr  10 for ." -- " next  cr ;

: TYPE-CHAP ( a -- )
    begin
        14 0 do                         \ Max. 20 lines at a time
            cr .line 09 =               \ End of source chapter?
            if  .divider leave  then    \ Show divider & ready
        loop
    dup libhere < while                 \ More library source to be done?
        key BL <> if drop exit then     \ Yes, ask key, stop on non space
    repeat  drop ;

v: extra definitions
: LOOK      ( ccc -- )      bl-word count  find-chapter type-chap ;
v: fresh
%%

chapter DISPLAY
\ A library consists of 09 {tab}, 0D {cr} and ASCII chars
\ ranging from blank to ~ others chars are not allowed
\ DISPLAY the code of any chapter in the library
need LOOK
v: extra definitions
: DISPLAY   ( ccc -- )      LOOK ; \ Pseudonym for LOOK
v: fresh
%%

chapter VIEW
\ A library consists of 09 {tab}, 0D {cr} and ASCII chars
\ ranging from blank to ~ others chars are not allowed
\ VIEW the code of any chapter in the library
need LOOK
v: extra definitions
: VIEW      ( ccc -- )      LOOK ; \ Pseudonym for LOOK
v: fresh
%%

chapter OPEN-LIB
\ Extend or erase a ibrary
(* Open, close, extend and wipe library:
    WIPE-LIB    - Erase current library & reset LIBHERE & open it for writing
    OPEN-LIB    - Open a library for writing
    CHAPTER     - Add a new library chapter
    %%          - End a library chapter
    CLOSE-LIB   - Close a library for writing

Example extend a library with the code for NIP:
    open-lib
    chapter NIP
    : NIP   ( a b -- b )    swap drop ;
    %%
    close-lib

After a library is extended FREEZE noForth to make
the library extension (LIBHERE) permanent!
*)

v: inside also  definitions
  1000,0000 constant XIP        \ Start of XIP memory
  0000,0100 constant SEC        \ Sector size
\ 1008,1000 value LIB-ORG       \ Start of library
\ lib-org   value LIBHERE       \ Library memory pointer
create BUFFER  180 allot        \ Sector buffer with overflow (noForth t)
0           value PTR           \ Buffer index
0           value LIB?          \ True when library is open, false when closed
: LC,       buffer ptr + c!  incr ptr ;  ( b -- )
: LM,       bounds ?do  i c@ lc,  loop ; ( a +n -- )

: ADJUST        ( -- )
    10081000 dup to lib-org  begin  c@+ FF = until  1- to libhere ;

: LIBWRITE      ( +n -- )   \ Write library sector
    libhere xip - buffer SEC write-flash \ Write lib. sector to flash
    dup +to libhere   negate +to ptr    \ To next lib. block & correct pointer
    buffer SEC FF fill                  \ Erase first buffer
    buffer SEC + buffer ptr move ;      \ Move overflow to sector buffer

: BUFFER-FULL   ( -- )      \ Buffer overflow, write & restore
    ptr FF > if  SEC libwrite  then ;

: ADD-LIB       ( text -- ) \ Add library section, save it when a buffer is full
    begin   buffer-full             \ Buffer overflow, write & restore
            refill drop             \ Read new line
    ib 2 s" %%" s<> while           \ No delimiter?
         ib #ib lm,  0D lc,         \ Store line
    repeat  refill drop ;           \ Read next line

: (-BL)         ( -- )
    parea  bl skip nip  ib - >in ! ; \ Skip leading spaces in IB

v: forth definitions
: CHAPTER       ( text -- ) \ Contruct new library section
    lib? 0= ?abort  s" \ " lm,      \ New lib. header but only when a lib is open!
    begin      (-bl)  bl parse      \ Find keywords
    ?dup while 2dup upper lm,  bl lc, \ Store uppercase in buffer
    repeat  drop  0D lc,            \ Add formfeed when done
    add-lib  09 lc, ;

: OPEN-LIB      ( -- )      \ Open a library for writing, read incomplete lib. sector too!
    lib? ?abort  true to lib?       \ Lib opened, ready otherwise open it
    libhere lib-org <> if           \ Lib. not empty?
        buffer SEC FF fill          \ Erase buffer first
        libhere SEC /mod  SEC *     \ Get previous sector & ptr length
        to libhere  to ptr          \ Correct LIBHERE & init. PTR
        libhere buffer ptr move  {w  exit \ Read incomplete sector to buffer, open flash
    then  0 to ptr  {w  09 lc, ;    \ First lib. entry, open flash

: CLOSE-LIB     ( -- )      \ Close library, save unfinshed buffer too
    lib? 0= ?abort  false to lib?
    buffer-full  ptr libwrite  W} ; \ Write last sector if any & close flash

: WIPE-LIB      ( -- )      \ Remove previous stored library from flash
    lib? ?abort  adjust             \ Close library first when it is already open
    lib-org xip -                   \ Convert to start sector address
    7F000                           \ Fixed number for erase ( 520 kByte )
    {W  wipe-flash  W}              \ Erase whole library space
    lib-org to libhere  open-lib ;  \ And reset library pointer
v: fresh
%%

chapter WIPE-LIB
need open-lib
%%

chapter CLOSE-LIB
need open-lib
%%

chapter CHAPTER
need open-lib
%%

chapter .STACK
hex
(*  .STACK "ccc"
    Show stack comment for a library chapter
*)

v: inside also definitions
: .LINE     ( a1 -- a2 ch )
    begin c@+ dup BL < 0= while emit repeat ;

v: extra definitions
: .STACK     ( "ccc" -- )
    bl-word count find-chapter
    dup 80 + swap 0D scan nip 1+
    8 for   cr .line 09 =   \ Number of lines to show, quit at EOF
            if r> 2drop exit then
    next drop ;
v: fresh
%%

chapter ALPHA
hex  v: inside \ Code A.N.
: ALPHA     ( -- ) cr
    7F ch z 1+   ch a  ch !
    2 for
        do  i >r   hor if cr then
            libhere lib-org  \ ahead [ 2>r ]
            begin 9 scan 1+  \ [ 2r> ] then
              2dup >
            while 2 + dup c@ r@ =
                  if  space
                      begin count bl over < while emit repeat
                      drop space 40 hor < if cr then
                  then
            repeat 2drop rdrop  32 us
        loop
    next ;
v: fresh
%%

chapter -CHAPTERS
hex \ backward scan, code A.N.
: -SCAN     ( z a1 ch -- z a2 )    \ a2 = adr behind found char ch
    >r
    begin 2dup <
    while 1-
          dup c@ r@ = if 1+ rdrop exit then
    repeat rdrop ;

v: inside
: -CHAPTERS ( -- )  \ Reverse chapter list
    lib-org libhere 1-  cr
    begin 1- 9 -scan   2dup > 0=
    while dup 2 + space
          begin count bl over < while emit 10 us
          repeat 2drop space 40 hor < if cr then
    repeat 2drop ;
v: fresh
%%

chapter NEED(
\ Note: The words may be over several lines!
\       And must be separated by one or more spaces
\ Use: NEED( name-1 .. name-n )
v: inside
: NEED(     ( ccc0 .. cccn -- )
    begin  bl-word count    \ Read next keyword
           2dup s" )" s<>   \ Not closing paren?
    while  needed  repeat   \ Ok, perform NEEDED on the name
    2drop ;                 \ Ready
v: fresh
%%


chapter PIN
( GPIO -- ) \ Change GPIO pin for S?
need [if]
depth 0= [if]  abort  [then]
dup dm 30 2 within [if]  drop  dm 24  [then] \ Invalid switch pin?
0 cfg c!            \ GPIO-xx for S?
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config
cr .( Test S? ) s? .
%%

chapter LOCK-PIN
2           0 cfg c! \ Use bit 2 for input
origin      3 cfg !  \ Used GPIO input address
4 cfg @ abs 4 cfg !  \ Make sure to (re)start the second image
config
cr .( Test S? ) s? .
%%

chapter 48MHZ
dm 48       0 cfg 2 +  h!   \ Set frequency in MHz
4 cfg @ abs 4 cfg !         \ Make sure to (re)start the second image
config                      \ Test new configuration
%%

chapter 125MHZ
dm 125      0 cfg 2 +  h!   \ Set frequency in MHz
4 cfg @ abs 4 cfg !         \ Make sure to (re)start the second image
config                      \ Test new configuration
%%

chapter 132MHZ
dm 132      0 cfg 2 +  h!   \ Set frequency in MHz
4 cfg @ abs 4 cfg !         \ Make sure to (re)start the second image
config                      \ Test new configuration
%%

chapter 250MHZ
dm 250      0 cfg 2 +  h!   \ Set frequency in MHz
4 cfg @ abs 4 cfg !         \ Make sure to (re)start the second image
config                      \ Test new configuration
%%


chapter 38K4
dm 38400    2 cfg ! \ Baudrate is 38k4
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config              \ Test new configuration
%%

chapter 115K2
dm 115200   2 cfg ! \ Baudrate is 115k2
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config              \ Test new configuration
%%

chapter 460K8
dm 460800   2 cfg ! \ Baudrate is 460k8
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config              \ Test new configuration
%%

chapter 921K6
dm 921600   2 cfg ! \ Baudrate is 921k6
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config              \ Test new configuration
%%

chapter BAUD
( baud -- ) 2 cfg ! \ Baudrate from the stack
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config              \ Test new configuration
%%


chapter [DATA
\ [data  ...  data] -- an/wo 18de2024

: [DATA     ( -- )      postpone ahead  2>r chere 2r>  postpone [ ; immediate
: DATA]     ( -- a )    align  ]  postpone then  postpone literal ;

(*
: T1    [data  1 c, 2 c, 3 c,  data]  c@+ . c@+ . c@ . ;
*)
%%

chapter -ROT
\ extra: code -ROT   ( a b c -- c a b )
\    day  sp 4 #) ldr,   \ 2 - a to DAY
\    tos  sp 4 #) str,   \ 2 - TOS=c to a
\    tos  sp ) ldr,      \ 2 - b to TOS
\    day  sp ) str,      \ 2 - DAY=a to b
\    next,               \ 6
\ end-code
hex  v: extra definitions
code -ROT   ( a b c -- c a b )  \ Inverse rot
    604B684D ,  600D680B ,  CA10C804 ,  FFFF46A7 ,
end-code
v: fresh
%%

chapter ROLL
v: forth definitions
(*
: ROLL  ( i*x u -- j*x )    \ Roll item u to TOS
    dup 1 <
    if      drop
    else    swap >r 1- RECURSE r> swap
    then ;

code ROLL   ( i*x u -- j*x )    \ Roll item u to TOS
    tos 1 # cmp,  <? if,        \ Nothing to roll
        tos sp )+ ldr,          \ Yes, pop TOS
    else,
        day tos 2 # lsls.mv,    \ No, calc. offset to stack item to ROLL
        hop day 4 # subs.mv,    \ And offset to item on top of that
        tos  sp day r) ldr,     \ Read new TOS
        begin,
            sun  sp hop r) ldr, \ Move all items above one place lower
            sun  sp day r) str,
            day 4 # subs,       \ Adjust pointers
            hop 4 # subs,
        <? until,               \ Stop when all done
        sp 4 # adds,            \ Adjust stack pointer
    then,
    next,
end-code
*)
hex
code ROLL   ( i*x u -- j*x )    \ Roll item u to TOS
    DA012B01 ,  E008C908 ,  1F2C009D ,  590E594B ,
    3D04514E ,  DAFA3C04 ,  C8043104 ,  46A7CA10 ,
end-code
%%

chapter 2TUCK
\ Copy top double below second
: 2TUCK   2swap 2over ;     ( x1 x2 x3 x4 -- x3 x4 x1 x2 x3 x4 )
%%

chapter 2ROT
\ Rotate third double to top of stack
: 2ROT    2>r 2swap  2r> 2swap ;
%%

chapter -2ROT
\ Rotate top double to third double position on the stack
: -2ROT   2swap 2>r  2swap 2r> ;
%%

chapter ON
hex \ Set or clear the contents of a cell in the dictionary
v: extra definitions
\ code ON     ( a -- )   \ Store true in 'a'
\    day 0 # movs,
\    day day mvns,
\    begin, 2>r          \ OFF jumps to here!
\    day  tos ) str,
\    tos  sp )+ ldr,
\    next,
\ end-code
code ON   ( a -- )  43ED2500 ,  C908601D ,  CA10C804 ,  409546A7 ,  end-code
v: fresh
%%

chapter OFF
need [if]
hex \ Set or clear the contents of a cell in the dictionary
v: extra definitions
hex \ Set or clear the contents of a cell in the dictionary
\ code OFF    ( a -- )   \ Store false in 'a'
\    day 0 # movs,
\    2r> again,          \ Prepare jump to ON
\ end-code
created cell+ @ 4E4F0283 <> [if] ( ON not right before it, reload ON )
code ON   ( a -- )  43ED2500 ,  C908601D ,  CA10C804 ,  409546A7 ,  end-code
[then]
code OFF  ( a -- )  E7EF2500 ,  end-code
v: fresh
%%

chapter 2!
hex  v: forth definitions
code 2!     ( lo hi a -- )  \ Two cell store
    684D h,  680E h,  601E h,  605D h,
    688B h,  310C h,  next,
end-code
%%

chapter 2@
hex  v: forth definitions
code 2@     ( a -- lo hi )  \ Two cell fetch
    685D h,  681B h,  1F09 h,  600D h,  next,
end-code
%%

chapter 0>
hex
(*
code 0>     ( x -- f )
    day tos movs,
    tos 0 # movs,
    day 0 # cmp,  >? if,
        tos tos mvns,
    then,
    next,
end-code
*)
v: forth definitions
code 0>     ( x -- f )  \ Zero greater
    2300001D ,  DD002D00 ,  C80443DB , 46A7CA10 ,
end-code
%%

chapter ARSHIFT
hex
(*
code ARSHIFT ( a b -- c )
    tos 20 # cmp,  u>? if, \ 3 - 20 UMIN
        tos 20 # movs,  \ 1
    then,
    day tos movs,       \ 1 - +n to DAY
    tos  sp )+ ldr,     \ 2 - pop X1 to TOS
    tos day asrs,       \ 1 - Shift TOS DAY positions left
    next,               \ 6
end-code
*)
v: extra definitions
code ARSHIFT ( a b -- c )   \ Arithmetic right shift
    D9002B20 ,  1D2320 ,  412BC908 , CA10C804 ,  46C046A7 ,
end-code
v: fresh
%%

chapter D-
hex
(*
code D-     ( d1 d2 -- d3 )
    sp { hop day sun } ldm, \ HOP=d2l DAY=d1h SUN=d1l
    sun hop subs,
    day tos sbcs,
    tos day movs,
    sun  sp -) str,
    next,
end-code
*)
v: forth definitions
code D-     ( d1 d2 -- d3 ) \ Double less
    1B36C970 ,  2B419D ,  600E3904 ,  CA10C804 ,  FFFF46A7 ,
end-code
%%

chapter M+
hex
(*
code M+     ( d1 +n -- d2 )
    day tos movs,
    hop day 1F # asrs.mv,
    tos  sp )+ ldr,
    sun  sp ) ldr,
    sun day adds,
    tos hop adcs,
    sun  sp ) str,
    next,
end-code
*)
v: forth definitions
code M+     ( d1 +n -- d2 ) \ Mixed plus
    17EC001D ,  680EC908 ,  41631976 ,  C804600E ,  46A7CA10 ,
end-code
%%

chapter DLSHIFT
hex
(* Shifting doubles
: DLSHIFT ( lo hi n -- lo' hi' )    \ n in [0,32*2]
    tuck lshift >r          \ hi'
    2dup dm 32 -
    2dup   lshift >r        \ lower lo to upper hi
    negate rshift >r        \ upper lo to lower hi
    lshift                  \ lo'
    2r> r> or or   ;        \ compose hi'
*)
v: extra definitions
code DLSHIFT    ( lo hi n -- lo' hi' )
    C908461D ,    2C40AB ,  680E3C20 ,
    40A70037 ,  340143E4 ,  40E20032 ,  433B4313 ,
    600E40AE ,  CA10C804 ,  FFFF46A7 ,
end-code
v: fresh
%%

chapter DRSHIFT
hex
(* Shifting doubles
: DRSHIFT ( lo hi n -- lo' hi' )    \ n in [0,32*2]
    tuck 2dup rshift >r     \ hi'
    dm 32 -
    2dup   rshift >r        \ upper hi to lower lo
    negate lshift >r        \ lower hi to upper lo
    rshift 2r> or or        \ compose lo'
    r> ;                    \ hi'
*)
v: extra definitions
code DRSHIFT    ( lo hi n -- lo' hi' )
    C908461D ,  40EB001C ,  3E20002E ,
    40F70027 ,  360143F6 ,  40B20022 ,  40EE680E ,
    433E4316 ,  C804600E ,  46A7CA10 ,
end-code
v: fresh
%%

chapter SM/REM
v: forth definitions    \ Symmetric signed division
: SM/REM    ( dn n -- rest quot )
    over >r >r   dabs r@ abs um/mod
    r> r@ xor ?negate swap   r> ?negate swap ;
: /REM      ( x1 x2 -- r q )    >r s>d r> sm/rem ;
%%

chapter 2LOG
hex
(* Calculate binary logarithm
: 2LOG ( u -- y )
    [ 8 cells ] literal 0 do                \ #bits/cell
        s>d if  2*
            [ 8 cells 8 - ] literal rshift  \ linear interpolation
            [ 8 cells 1- ]  literal  i -    \ logarithmic class
            8 lshift or leave
        then 2*
    loop ;
*)
v: extra definitions
code 2LOG   ( u -- y )
    2B002500 ,  18DBDA08 ,  261F0E1B ,
    2361B76 ,   C8044333 ,  46A7CA10 ,
    350118DB ,  D1F02D20 ,  CA10C804 ,  FFFF46A7 ,
end-code
v: fresh
%%


chapter CHARS
\ Character address calculation: CHARS CHAR+ CHAR-
hex  v: inside also  forth definitions
header CHAR+    ( n1 -- n2 )    ' 1+  >body ,  reveal
header CHAR-    ( n1 -- n2 )    ' 1-  >body ,  reveal
: CHARS         ( n -- n )      ; immediate
v: fresh
%%

chapter ERASE
hex  v: forth definitions   \ Fill memory area with zeros
: ERASE     ( a u -- )          0 fill ;
%%

chapter J
\ Add extra loop indixes: J and K

\ code J      ( -- j )
\    tos  sp -) str,  tos  rp 0C #) ldr,  next,
\ end-code
\ code K      ( -- k )
\    tos  sp -) str,  tos  rp 18 #) ldr,  next,
\ end-code
hex  v: forth definitions   \ Do loop indexes J & K
code J      ( -- j )   600B3904 ,  C8049B03 ,  46A7CA10 ,  end-code
hex  v: extra definitions
code K      ( -- k )   600B3904 ,  C8049B06 ,  46A7CA10 ,  end-code
v: fresh
%%

chapter PAD
hex  v: forth definitions   \ Scratchpad memory
create PAD  ( -- a )    20 allot        \ example
%%

chapter SOURCE
\ Input source manipilation: SOURCE SAVE-INPUT RESTORE-INPUT
hex  v: inside also  forth definitions   \ Input source manipulation
: SOURCE        ( -- a u )                      ib #ib ;
: SAVE-INPUT    ( -- ib #ib^>in@ source-id )    @input 3 ;
: RESTORE-INPUT ( ib #ib^>in@ source-id 3 -- )  3 ?pair !input ;
v: fresh
%%

chapter CASE
\ The case statement: CASE OF ENDCASE ENDOF
hex  v: forth definitions   \ The never dying CASE
\ : OF?     ( x1 x2 -- x1 f )   over = ;
code OF?    ( x1 x2 -- x1 f )
   1B5B680D ,  3B0142AE ,  C804419B ,  46A7CA10 ,
end-code
: CASE      hx 88 ; immediate
: OF        postpone of? postpone if postpone drop ; immediate
: ENDOF     postpone else ; immediate
: ENDCASE   ( x -- )
   postpone drop
   begin postpone then hx 88 of?
   until drop ; immediate
%%

chapter UNUSED
v: forth definitions    \ Show free memory
: UNUSED    ( -- u )            flybuf here - ;
cr .( Free memory ) unused dm .
%%

chapter WORD
v: inside also  forth definitions
: WORD      ( ch -- a ) \ ANSI standard WORD
    >r   parea r@ skip   nip ib - >in !
    r>   parse    >fhere ;
v: fresh
%%

chapter [COMPILE]
\ Compile the word behind it also when it's immediate
v: inside also  forth definitions
: [COMPILE]  ( "name" -- )  ' ?comp compile, ; immediate
v: fresh
%%

chapter ABORT"
\ Error message with inline string
v: inside also  forth definitions
header ABORT"   ' S" @ ,   reveal immediate
:noname if  inls count  cr type  -2 throw
        then inls drop ; drop
v: fresh
%%

chapter [IF]
\ Interactive control structures: [IF] [ELSE] [THEN]
v: forth definitions
: [ELSE] true
  begin begin begin ?dup 0= ?exit
    [char] [  beyond >in @ 1- dup 0<> + >in ! \ new
    bl-word count 2dup upper
    s" [THEN]" 2over s<> 0= while 2drop 1+ repeat
    s" [ELSE]" 2over s<> 0= while 2drop dup -1 = - repeat
    s" [IF]" s<> 0= if 1- then
  again ; immediate
: [IF] ?exit postpone [else] ; immediate
: [THEN] ; immediate
%%

chapter FORTH-WORDLIST
\ Compilation wordlist manipulation: FORTH-WORDLIST GET-CURRENT SET-CURRENT

v: only definitions  inside also  extra also  forth also
v: 1 constant FORTH-WORDLIST
v: : GET-CURRENT   v0 c@ ;
v: : SET-CURRENT   v0 c! ;
v: fresh
%%

chapter GET-ORDER
\ Manipulate search order: GET-ORDER SET-ORDER

v: only definitions  inside also  extra also  forth also
v: : GET-ORDER     ( -- wids.. n )
v:    v0
v:    dup vp - dup >r                     \ n v0 n
v:    0 ?do   1- dup c@ swap loop drop r> ;
v: : SET-ORDER     ( wids.. n -- )
v:    dup -1 = if drop 0 1 3 1 4 then     \ fresh
v:    8 over u< ?abort                    \ overflow
v:    v0 over - to vp
v:    vp swap 0
v:    ?do tuck c! 1+ loop drop ;
v: fresh
%%

chapter SEARCH-WORDLIST
\ Search for wordname in given wordlist id
v: inside also  forth definitions
v: : SEARCH-WORDLIST   ( adr len wid -- 0 | xt 1 | xt -1 )
v:    >r
v:    >fhere
v:    v0 cell+   dup 1-
v:    r> over c!      \ mini search-order with 1 wid
v:    find)
v:    dup ?exit nip ;
v: fresh
%%

chapter -TRAILING
v: forth definitions    \ Cut trailing spaces from a string
: -TRAILING ( a +n1 -- a +n2 )
    begin  1-  2dup + c@ BL <> until  1+ ;
%%

chapter .S
v: forth definitions
: .S    ( -- )  \ Non-destructive display of data stack
    ?stack (.) space
    depth false
    ?do  depth i - 1- pick
        base @ hx 0A = if . else u. then
    loop ;
%%

chapter [DEFINED]
v: forth definitions    \ Check if a word exist or not exist
: [DEFINED]     ( "name" -- f )     bl-word find nip 0<> ; immediate
%%

chapter [UNDEFINED]
need [defined]
v: forth definitions    \ Check if a word exist or not exist
: [UNDEFINED]   ( "name" -- f )     postpone [defined] 0= ; immediate
%%


chapter CRC
hex  v: extra definitions
create CRC   ( a1 u -- crc ) \ RP2040 CRC generator, design by J.J.Hoekstra
    FFFFFFFF ,  4C11DB7 ,
code>
    461FC920 ,  197FCA18 ,  636782E ,
    22084073 ,  D300005B ,  3A014063 ,  3501D1FA ,
    D1F342BD ,  CA10C804 ,  FFFF46A7 ,
end-code
v: fresh
%%

chapter RANDOM
\ Pseudo random number generation: RANDOM CHOOSE
v: inside also definitions
decimal \ 32-bit pseudo random generator with 2 seeds in values
create SEEDS  2345 , 6789 ,
v: extra definitions
\ : RANDOM    ( -- u )  \ Design by J.J.Hoekstra
\    seeds >r r@ @      \ put seed0 on stack
\    r@ 4 + @  r@ !     \ move value in seed1 to seed0
\    dup 13 lshift xor  \ do three XORs of seed0
\    dup 17 rshift xor  \ with shifted copies of itself
\    dup 5 lshift xor
\    dup r> 4 + **bix ; \ XOR the new random value with
                        \ the old seed1 and update seed1
hex
create RANDOM ( -- u )  \ Assembly version W.O.
    seeds ,
code>
    39046812 ,  6813600B ,  68556854 ,
     35E6015 ,   C5E4073 ,   15E4073 ,
    405C4073 ,  C8046054 ,  46A7CA10 ,
end-code

\ u2 is a pseudo random number between 0 and u1
: CHOOSE    ( u1 - u2 )     random um* nip ;
v: fresh
%%

chapter THENS
hex  v: extra definitions
: THENS         \ Close open IFs
    begin  postpone then  dup 11 <> until ; immediate
v: fresh
%%

chapter .BYTE
\ Print byte number in hexadecimal
v: extra definitions
: .BYTE     ( c -- )        \ Print hex byte
    base @  hex swap 0 <# # # #> type space  base ! ;
v: fresh
%%

chapter .HEX
\ Print number unsigned in hexadecimal
v: extra definitions        \ Additions
: .HEX      ( u -- )        \ Cell wide version of .HEX uses eight digits
    base @  hex  swap 0 <# # # # # # # # # #> type space  base ! ;
v: fresh
%%

chapter PCHAR
hex
v: extra definitions    \ Convert all data to printable characters
: PCHAR ( x -- ch )    dup 7F < and BL max ;
v: fresh
%%

chapter MANY
need STOP?
v: extra definitions    \ Redo current input line until a key was hit
: MANY   ( -- )  ?stack  >in @ stop? and >in ! ;
v: fresh
%%

chapter STOP?
\ Leave flag when a key was pressed, hold on a space, abort on Esc.
hex  v: extra definitions
: STOP? ( -- true/false )
    key? dup 0= ?EXIT
    drop key  bl over =
    if drop key
    then hx 1B over = ?abort
    bl <> ;
v: fresh
%%

chapter RECUR
hex
(*
  1 for ... recur next \ repeat controlled by key
  esc = abort
  space bar = once again
  key 0..9 = n*4 times
  rest = ready
*)
v: inside definitions
: RECUR ( -- )  \ use only within for-next
    2r> over 0=                     \ index & unnest address
    if nip key dup 1B = ?abort      \ abort on esc
        dup bl = if drop 1          \ new index
        else ch 0 - dup 0A u< and   \ 0..9
            2* 2*                   \ new index
        then swap
    then 2>r ;
v: fresh
%%

chapter DMP
v: inside
need recur
need pchar
v: inside also  extra definitions
\ ----- DUMP - 07mar23 an/wo
: DMP ( a -- )                  \ this is a DUMP without count
   hx FF s>d du.str nip 1+      \ column width
   swap    ( colw adr )
   1 for cr base @ hex over 4 u.r ." : " base !
      swap ( adr colw )
      over 8 bounds do i c@ over .r loop ."  |"  8 us
      swap ( colw adr )
      8 false    do count pchar emit loop ." | "  8 us
   recur next 2drop ;
v: fresh
%%

chapter DUMP
need .byte
need .hex
need pchar
need stop?
hex  v: forth also definitions  \ Dumps nothing when u = 0
: DUMPHEX   ( a u -- )      bounds ?do  i c@ .byte  loop  8 us ;
: DUMPTEXT  ( a u -- )      bounds ?do  i c@ pchar emit  loop  8 us ;

: DUMP      ( a u -- )  \ Classic Forth dump tool
    bounds ?do
        cr  i .hex space        \ Print address
        i 10 dumphex
        ch | emit  i 10 dumptext  ." | "
        stop? if leave then     \ Test key to stop or halt
    10 +loop ;                  \ Next line
v: fresh
%%

chapter WORDS
need stop?
v: only definitions  extra also  forth also  inside
hex  ( nieuwe versie 2nov20 + iwords )
: WORDS   ( -- )    \ Show words in top vocabulary
v: (*
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
v:      vp c@ =  (*
        2 r@ execute        (           \ no vocs
*)
        if  dup lfa>n space count 1F and type space  8 us
            48 hor < if cr then
        then lnk@ swap !                \ unlink
    repeat 2drop
v: (*
    rdrop ; : IWORDS ['] = >r           \ no vocs
    [ 2r> ] again           (
*)
;
v: fresh
%%

chapter @NAME
\ Read counted string from a header
hex  v: inside also  definitions
: @NAME     ( a -- a+1 +n )     count 7F and ;
v: fresh
%%

chapter >NFA
\ Try to convert an address to name field address, version-2
hex  v: fresh inside also  definitions
noname      ( a1 -- a2 )    \ <SKIP-FF
    3B012503 ,  2EFF781E ,  3D01D102 ,
    3B01D1F9 ,  CA10C804 ,  FFFF46A7 ,
end-code  >r

: >NFA      ( a -- nfa | 0 )    \ >NFA returns 0 when no header is found!
    dup 3 and 0= if                     \ 32aligned?
        dup origin chere within         \ In noForth code area?
        if  [ r> compile, ]  false      \ Skip-FF count
            begin
                over c@ ch ! 7F within  \ Char. range = 21 7F
            while
                true /string
            dup BL = until              \ String too long?
            then  ( a +n )
            ?dup if
                over c@  7F and  = if   \ count ok?
                    dup 1 and if        \ nfa odd -> ok
                    dup 1- cell- @
                    over < and exit     \ Link pointing backwards?
                then
        then then then
    then  drop false ;
v: fresh
%%

chapter ?TEXT
\ Search for inline text string
v: inside
need @name
hex  v: inside also  definitions
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
v: fresh
%%

chapter ?HEAD
\ Check for a valid header at given address
v: inside
need ?TEXT
hex  v: inside also  definitions
0 value 'SEE
: ?HEAD     ( a -- ta|0 )
        dup c@ 7F and                   \ Read voc. id                  a v1
v:      wid-link cell+ h@ >             \ Invalid voc?                  a f
-v:     4 >                             \ Idem                          a f
        if  dup -  exit  then           \ Yes, leave zero               a|0
        1+ ?text ;
v: fresh
%%

chapter .DATA
\ Print data word as chars and hexadecimal
need pchar

v: extra definitions
false value SHORT?
v: inside also definitions
: .DATA     ( +n -- )
    cr >r  short? 0= if
        'see 0A u.r ." : "               \ .adr
        'see r@ for c@+ pchar emit next drop    \ .4chars
        'see r@ 4 = if @ 0B else h@ 5 then      \ .contents 32/16 bits
        u.r
    then  space space  rdrop ;
v: fresh
%%

chapter SEE
v: inside   \ noForth decompiler: SEE MSEE DECOM
need recur
need pchar
v: inside
need @name
v: inside
need >nfa
v: inside
need ?head
v: inside
need .data
hex  v: fresh inside also  definitions

: .INFO     ( -- f )    \ Show all words data
    'see >nfa ?dup if                   \ Valid header?
        ." --- "
v:      dup 1- c@ 7F and .voc           \ Show vocabulary
        dup @name type                  \ The words name
        c@ 80 and if  ."  imm" then space
        'see @ cell- >nfa ?dup if
            (.) space @name type space  \ made by ..
        else
            'see @  h@+ swap h@ h+h     \ Read doer
            46E7B401 = if               \ Is it unknown DOES part
                (.) ."  DOES> "
            then
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

v: extra definitions
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

v: inside
: MSEE      ( a -- )
    -4 and to 'see
    1 for
        12345 decom
        12345 <> ?abort
        recur
    next ;

v: forth definitions
: SEE           ( <name> -- )       ' msee ;
v: fresh
%%

chapter .VOCS
v: extra definitions  inside
v: : .VOCS         ( -- )  \ Show all present vocabularies
v:    wid-link
v:    cell+     \ c? [if] 2 + [else] cell+ [then]
v:    h@ 1+  0
v:    (.) space
v:    do  i .voc  loop ;
v: fresh
%%

chapter .SHIELDS
v: inside
need >nfa
hex  v: extra definitions  inside
: .SHIELDS      ( -- )  \ Show all present shields
    (.)  ['] noforth\ dup @ here rot
    do  i @ over =
        if  i >nfa ?dup
            if  space count 1F and type space
            then
        then
    cell +loop  drop ;
v: fresh
%%

chapter LARGE-TOOLS\
\ Load basic noForth tool set
need stop?
need many
need .s
need dmp
need words
need see
need [if]
need .vocs
need .shields
need [defined]
v: fresh
shield LARGE-TOOLS\
%%

chapter TOOLS\
need many   \ Load basic noForth tool set
need .s
need dmp
need words
need [if]
need .vocs
need .shields
v: fresh
shield TOOLS\
%%

chapter ALLWORDS
\ 16 times WORDS in noForth tv using kangaroo method
\ an-feb2024: ALLWORDS IMMWORDS VOCWORDS CHWORDS etc.

(*      Overview
ALLWORDS    ( -- )          \ All words
IMMWORDS    ( -- )          \ Immediate words
LENWORDS    ( len -- )      \ Names with length 'len'
VOCWORDS    ( voc# -- )     \ Words in vocabulary nmbr 'voc#'
CHWORDS     ( ch1 -- )      \ Names beginning with 'ch1'
ALFAWORDS   ( -- )          \ Alfabetic on 1st character
WITHWORDS   ( ch -- )       \ Names with the character 'ch' in it
BEFOREWORDS ( adr -- )      \ Before 'adr' compiled words
AFTERWORDS  ( adr -- )      \ After 'adr' compiled words
THREADWORDS ( thread# -- )  \ Words in thread 'thread#' (0..7)
SIMILWORDS  ( xt -- )       \ Words with the same doer as 'xt'
NORMWORDS   ( -- )          \ Normal forth words
CODEWORDS   ( -- )          \ Ordinary assembler words (primitives)
QUIRKWORDS  ( -- )          \ Odd words, like kangoeroos
REDEFWORDS  ( -- )          \ Names that are not unique
*)

hex \ until the end
v: inside also  definitions
' 0= value YES?
0 value #NAMES

: ()WORDS ( xt -- )
    to yes?   0 to #names
    hor if cr then
    hot 8 cells bounds
    do i @
        begin dup lfa>n ( NFA )
            dup yes? execute

            if dup
                count 1F and
                type incr #names
                8 hor 7 and - spaces
                40 hor < if cr then
            then drop

            lnk@ ( lnk@ )
            dup 0=
        until drop
        cell
    +loop #names ?dup if (.) 0 .r then ;

0 value THIS
: NFA> ( nfa -- cfa ) count 1F and + aligned ;

v: forth definitions
: ALLWORDS ( -- ) ['] 0<> ()words ;
create IMMWORDS ( -- )        :noname ( nfa -- 0|80 ) c@ 80 and ; drop        does> ()words ;
create LENWORDS ( len -- )    :noname ( nfa -- flag ) c@ 1F and this = ; drop does> swap to this ()words ;
create VOCWORDS ( voc# -- )   :noname ( nfa -- flag ) 1- c@ 7F and this = ; drop does> swap to this ()words ;
create CHWORDS  ( ch -- )     :noname ( nfa -- flag ) 1+ c@ this = ; drop     does> swap upc to this ()words ;
: ALFAWORDS     ( -- )        7f ch z 1+   ch a ch !   2 for do i chwords loop next ;

create WITHWORDS ( ch -- )    :noname ( nfa -- flag ) count 1F and bounds this scan <> ; drop
    does> swap upc to this ()words ;

create BEFOREWORDS ( adr -- ) :noname ( nfa -- flag ) this < ; drop    does> swap to this ()words ;
create AFTERWORDS  ( adr -- ) :noname ( nfa -- flag ) this > ; drop    does> swap to this ()words ;
create THREADWORDS ( nr -- )  :noname ( -- flag ) count swap c@ xor 7 and this = ; drop  does> swap to this ()words ;
create SIMILWORDS ( xt -- )   :noname ( nfa -- flag ) nfa> @ this = ; drop  does> swap @ to this ()words ;
create NORMWORDS  ( -- )      :noname ( nfa -- flag ) nfa> @+ > ; drop      does> ()words ;
create CODEWORDS  ( -- )      :noname ( nfa -- flag ) nfa> @+ = ; drop      does> ()words ;
create QUIRKWORDS ( -- )      :noname ( nfa -- flag ) nfa> @+ < ; drop      does> ()words ;
create REDEFWORDS ( -- )      :noname ( nfa -- flag ) 1- c@ 80 < ; drop     does> ()words ;

\ enz.
v: fresh
%%


chapter MEMMAP
hex
v: inside also  extra definitions
: U.L ( <i*x> +n -- )
  for  0 du.str dup >r type  0A r> - 0 max spaces  next ;

: MEMMAP    ( -- )  \ Show noForth memory map
    base @ >r  hex
    cr ." ROM:      BOOT      IMAGE     IMAGE-END "
    D000,0000 @ if              \ Second core?
        ."  (Image 2) "
        1000,0100 @  1000,0100 + >r \ End
        r@ ivecs @ +  1000,0000  r> \ End Start
        1000,0000  3
    else
        4 cfg @ if              \ First of dual core?
            ." IMAGE-END2 (DUO)"  1000,0100 >r
            1000,0100 dup @  tuck +  @ + r@ +
            ivecs @ r@ +
            r>  1000,0000  4
        else                    \ No, just single core
            ivecs @ 1000,0100 +  1000,0100  1000,0000  3
        then
    then
    cr dm 10 spaces  u.l  cr cr
    ." RAM:      IVECS     HOT       UHERE ..  ORIGIN    CHERE ..  FLYBUF    (FP)"
    cr dm 10 spaces  fp  flybuf  chere  origin   uhere  hot  ivecs  7 u.l
    cr cr ."           FLYBUF/   R0        S0        TIB       TIB/      RAMBORDER"
    cr dm 10 spaces  ramborder  tib/  tib  s0  r0  flybuf/  6 u.l  cr
    4 cfg @ if cr  ." The second system runs from: " ramborder .  then
    cr ." XRAM:     START     XHERE ..  END"
    cr 0A spaces  xhere FFF or 1+  xhere  xhere FFFFF000 and  3 u.l cr
    r> base ! ;
v: fresh
memmap
%%

chapter .CFG
need [if]
v: inside
need >nfa
v: also inside
    0 cfg @+  H-H  cr .( Clock = ) dm u.  .( MHz )  hx FF and >R
    5 cfg @ ' noop = [if]  ( Default configuration? )
        @+  cr .( UART-) hx 40034000 -  14 RSHIFT .
    [else]
        @+ drop cr .( USB-CDC )
    [then]
    @+          .( at ) dm u.  .( Baud )
    r>          cr .( S? is on GPIO) dm .
    @+          .( & GPIO-address ) hx u.
    @+          cr me count type
    drop       .( , runs on core ) D0000000 @ .
    @           cr .( Config extension word = ) >nfa count type
v: previous
%%

chapter LAST\
\ Remove all code behind the last present shield
v: extra definitions
: LAST\         ( -- )  \ Execute last shield
    ['] noforth\  dup @ swap    \ xt@ adr
    chere over do
        over i @ = if  drop  i  then
    cell +loop  nip
    flyer  postpone literal  postpone execute ; immediate
v: fresh
%%

chapter -FLY
: -FLY      2r> r> 2>r >r ; immediate
cr .( Use -FLY like this: )
cr .( cr flyer  9 for i . next  -fly )
cr .( the result is: 8 7 6 5 4 3 2 1 0 )
%%

chapter COMMACODE
hex  v: extra definitions
: COMMACODE   ( -- )    \ Build assembler less code definitions
    created lfa> @+ >r                  \ body  r: doer
    cr  dup r@ > if                     \ Routine ?
        ." routine "
    else
        dup r@ < if                     \ Create or Code ?
            ." create "
        else  ." code "  then
    then
    created lfa>n count 1F and type  cr space   \ Print name
    begin @+ u. ." , "
          dup r@ = if  cr ." code> " cr then    \ adr = doer ?
          dm 30 hor < if  cr  then  space
    dup here < 0= until
    cr ." end-code"  cr  rdrop drop ;
v: fresh
%%

chapter CM
need commacode
v: extra definitions
: CM  commacode ;
v: fresh
%%

chapter DAS\
here  v: inside \ Complete RP2040 disassembler: DAS MDAS DAS\
need see
need .hex
need -trailing
hex
v: inside also definitions  \ Add register names & addressing modes
v: inside definitions
: .SPECIAL  ( opc -- )
    FF and  dup 0A < if
        5 * s" apsr iapsreapsrxpsr ???  ipsr epsr iepsrmsp  psp  "
        drop  +  5
    else
        dup 10 = if  drop  00  else
        14 = if  8  else  10  then  then
        s" primask control reserved" drop  +  8
    then  -trailing type space ;
: .REG)     ( r -- )                \ Print register names
    0F and  4 *
    s" ip  sp  w   tos hop day sun moonww  xx  yy  zz  doesrp  lr  pc  "
    drop +  4 -trailing type space ;
: .REG      ( opc s m -- )    >r  rshift  r> and .reg) ;  \ Any register field
: .LDREG    ( opc -- )        dup 7 and  swap 80 and 4 rshift or .reg) ; \ Long
: .DSREG    ( opc -- )        dup 0 7 .reg  3 7 .reg ;    \ Decode dest. & src
: @LIT      ( opc s m -- +n ) >r  rshift  r> and ;        \ Any constant field
: .INDIRECT ( opc s m w -- )  >r  @lit  r> * u. ;         \ Constant index
: .CONSTANT ( opc s m w -- )  .indirect ." # " ;          \ Constant type field
: .CONST    ( opc s m -- )    1 .constant ;               \ Simple constant
: .JUMP     ( a o -- )        2*  dup .  ." to " over cell+ +  .hex ; \ Calc. jump
: COMMA     ( -- )            ch , emit  space ;
: CTYPE     ( a +n -- )       type  comma ;
: .REG[]    ( opc w -- )        \ Indexed with offset
    >r  dup 0 7 .reg  dup 3 7 .reg  6 1F r> .indirect  ." #) " ;
: .REGS     ( opc a u f -- )    \ Decode multiple register fields
    ." { "  if  2dup type  then  2drop  \ First special register
    FF and  8 0 do
        dup  i bitmask and  ( 1 i lshift and )
        if  i .reg)  then
    loop  drop  ." } " ;

: .BL       ( a opc -- a )  \ Branch & link
    dup 4000000 and 0= 0= >r        \ Make & save sign
    -1 7FFFFF xor                   \ Extend sign   opc mask
    r@ and   over 7FF and   or      \ Bit 0 to 10   opc bl..
    over 3FF0000 and 5 rshift  or   \ Bit 11 to 21  opc bl..
    swap -1 xor r> xor  2800 and    \ Isolate bit 21 & 22
    dup >r 800 and A lshift  or     \ Add bit 21
    r> 2000 and 9 lshift or .jump ." bl" ; \ & bit 22

: .HINTS    ( opc -- )      \ Hint & breakpoint opcodes
    dup BF00 = if  ." nop"    then
    dup BF10 = if  ." yield"  then
    dup BF20 = if  ." wfe"    then
    dup BF30 = if  ." wfi"    then
    dup BF40 = if  ." sev"    then
    dup FF00 and  BE00 = if
    0 FF .const  ." bkpt"  else  drop  then comma ;

: .SXT      ( opc -- )      \ Sign extend opcodes
    dup .dsreg 1C0 and  6 rshift  4 *  s" sxthsxtbuxthuxtb"
    drop +  4 ctype ;

: .REV      ( opc -- )      \ Invert opcodes
    dup .dsreg  00C0 and >r
    r@ 0=   if  ." rev"     then
    r@ 40 = if  ." rev16"   then
    r> C0 = if  ." revsh"   then  comma ;

: .LOGIC    ( opc -- )      \ Logical opcodes
    dup 3C0 and  6 rshift >r  .dsreg  r@ 9 = if  ." #0 "  then  r> 4 *
    s" andseorslslslsrsasrsadcssbcsrorstst rsbscmp cmn orrsmulsbicsmvns"
    drop +  4 -trailing  ctype ;

: .BX       ( opc -- )      \ Branch using registers
    dup 3 F .reg  80 and if ." blx" else ." bx" then comma ;

: .RSP      ( opc -- )      \ Return stack opcodes with 7-bits number
    dup ." rp "  0 7F .const  80 and if ." sub" else ." add" then  comma ;

: .0XXX     ( opc -- )      \ Shift opcodes with 5-bits number
    dup .dsreg  dup 6 1F .const  800 and if ." lsrs.mv, " else ." lsls.mv, " then ;

: .1XXX     ( opc -- )      \ Shift, add & subtract
    dup 800 and 0= if dup .dsreg  6 1F .const ." asrs.mv, " exit then
    dup E00 and >r
    r@ 800 = if dup .dsreg  6 7 .reg ." adds.mv, " then
    r@ A00 = if dup .dsreg  6 7 .reg ." subs.mv, " then
    r@ C00 = if dup .dsreg  6 7 .const ." adds.mv, " then
    r> E00 = if dup .dsreg  6 7 .const ." subs.mv, " then ;

: .2XXX     ( opc -- )      \ Compare & move using 8-bits number
    dup 8 7 .reg dup 0 FF .const  800 and if ." cmp, " else ." movs, " then ;

: .3XXX     ( opc -- )      \ Subtract & add using 8-bits number
    dup 8 7 .reg dup 0 FF .const  800 and if ." subs, " else ." adds, " then ;

: .4XXX     ( a opc -- a )  \ Bulk of all opcodes are decoded here
    dup 800 and if
        dup 8 7 .reg  0 FF @lit 4 * ." pc " \ Show destination register
        dup u. ." #) ldr, "  over +  cell+  \ Get lit. & calc. address
        dup 4 mod -  @ .hex  ." ##" exit    \ Show inline literal
    then
    dup C00 and 0= if  .logic  exit  then   \ All basic logic opcodes
    dup 300 and  dup 300 = if  drop .bx  exit  then >r \ BX & BLX
    dup .ldreg  3 F .reg  r> 8 rshift  3 *
    s" addcmpmov" drop  +  3 ctype ;        \ All register opcodes

: .5XXX     ( a opc -- a )  \ Load & store using registers
    dup 0 7 .reg  dup 3 7 .reg  dup 6 7 .reg ." r) "
    E00 and  9 rshift  5 *
    s" str  strh strb ldrsbldr  ldrh ldrb ldrsh" drop +
    5 -trailing ctype ;

: .6XXX     ( a opc -- a )  \ Load & store 32-bits using 5-bits offest
    dup 4 .reg[]  800 and if ." ldr" else ." str" then comma ;

: .7XXX     ( a opc -- a )  \ Load & store 8-bits using 5-bits offest
    dup 1 .reg[]  800 and if ." ldrb, " else ." strb, " then ;

: .8XXX     ( a opc -- a )  \ Load & store 16-bits using 5-bits offest
    dup 2 .reg[]  800 and if ." ldrh, " else ." strh, " then ;

: .9XXX     ( a opc -- a )  \ Load & store 32-bits using 5-bits offest
    dup 8 7 .reg  ." rp "  dup 0 FF 4 .indirect ." #) "
    0800 and if ." ldr" else ." str" then  comma ;

: .AXXX     ( a opc -- a )  \ Add 8-bits number to RP & PC
    dup 8 7 .reg  dup 800 and if  ." rp "  0 FF .const ." add"
    else  ." pc "  0 FF .const ." add"
    then  comma ;

: .BXXX     ( opc -- )      \ Miscellaneous opcodes, PUSH, POP, etc.
    dup E00 and >r
    r@ 0=    if  .rsp  then
    r@ 200 = if  .sxt  then
    r@ 400 = if  s" lr " 2 pick 100 and .regs  ." push, "  then
    r@ 600 = if  ." cpsi" 10 and if ." d, " else ." e, "  then  then
    r@ 800 = if  ." udf, "  drop  then
    r@ A00 = if  .rev     then
    r@ C00 = if  s" pc " 2 pick 100 and .regs  ." pop, "  then
    r> E00 = if  .hints   then ;

: .CXXX     ( opc -- )      \ Load & store multiple registers
    dup 8 7 .reg  dup 0 0 0 .regs  800 and if ." ldm" else ." stm" then comma ;

: .DXXX     ( a opc -- a )  \ Branch & test opcodes & supervisor mode
    dup 0F00 and  8 rshift >r  r@ 0D > if  0 FF .const  else
        FF and dup 80 and if  -1 FF xor  or  then  .jump
    then  r> 3 *  s" beqbnebcsbccbmibplbvsbvcbhiblsbgebltbgtbleudfsvc"
    drop +  3 ctype ;

: .EXXX     ( a opc -- )    \ Branch eleven bits
    7FF and  dup 400 and if  -1 7FF xor  or  then  .jump ." b, "  ;

: .Fxxx     ( a1 opc -- a2 ) \ 32-bits opcodes (coupled opcodes) like BL, etc.
    10 lshift  over 2 + h@  or      \ Build 32-bits opcode
    dup F800F000 and  F0008000 = if \ Valid 32-bits opcode?
        dup 3FFFC0 and  3F8F40 = if \ Barrier opcode?
            30 and 4 rshift  3 *    \ Yes, decode
            s" dsbdmbisbudf" drop + 3 ctype
        else
            dup 700000 and >r     \ No, Move special or UDF?
            r@ 700000 = if  drop  ." udf"  then
            r@ 600000 = if  dup 8 F .reg  .special ." mrs"   then
            r> 0= if  dup .special  10 F .reg ." msr"   then
        then  comma  2 +to 'see  2 .data  exit
    then
    dup F800D000 and F000D000 <>
    if  drop  ." udf"  else  .bl   then  comma
    2 +to 'see  2 .data ;

create 'OPC ' .0xxx ,  ' .1xxx ,  ' .2xxx ,  ' .3xxx ,  ' .4xxx ,
            ' .5xxx ,  ' .6xxx ,  ' .7xxx ,  ' .8xxx ,  ' .9xxx ,
            ' .Axxx ,  ' .Bxxx ,  ' .Cxxx ,  ' .Dxxx ,  ' .Exxx ,  ' .Fxxx ,

\ Leave address when a CFA is found with literals behind it
: SKIP-CFA  ( -- 0|a )
    'see 4 mod if  0  exit  then    \ Zero when not aligned
    'see @  'see dup 28 + within if \ Max. 10 cell literals
        'see @+ tuck <              \ Code starts not behind CFA
        if      cell +to 'see  exit \ Yes skip CFA & to literal pool
        then    to 'see             \ Go on after CFA
    then  0 ;                       \ Nothing on other cases

: .HEAD     ( a +n -- )
    >r  dup c@ 7F and 20 < if       \ Yes, show it's a words name
        cr ." name " dup @name 2dup type
        r@ +to 'see
        nip 5 + 1C and +to 'see
    then  r> 2drop ;

: .ONELINE  ( 0|a -- )
    begin
    'see over -2 and < while            \ Until all literals done
        short? 0= if  2 .data
        else  'see 4 mod 0= if 2 .data then
        then  2 +to 'see
        'see 4 mod if  'see 2 - @ .hex  then
    repeat
    dup 1 and if  drop  cr ." code>"    \ Data definition end
    else  if  cr ." data)"  then        \ Inline data field end
    then  2 .data
    'see dup h@  dup F000 and  0C rshift        \ a opc offset
    cells 'opc +  @ execute drop  2 +to 'see ;  \ -

: DATA?     ( -- 0|a )                  \ Show (inline) data pool
    skip-cfa  ?dup 0= if
        'see h@+ 467A =                 \ is it: W PC MOV,
        over h@ FFFF <> and             \ Not FFFF
        swap h@ FC00 and E000 = and if  \ and: AHEAD,
            'see 2 + h@ 7FF and 2* 'see 6 + + \ Yes, calc. end of data block
            0 .oneline  0 .oneline      \ Show preceeding opcodes
            cr ." (data"  exit          \ It's an inline data field
        then  false  exit               \ No, it's something else
    then  1 or ;                        \ Not inline, it's a CFA with data pool

v: forth definitions
: MDAS      ( a -- )
    to 'see
    1 for
        'see cell+ ?head ?dup       \ Check for HEADER too?
        if      4 .head
        else    'see 6 + ?head ?dup \ Aligned header?
                if  'see h@ FFFF =
                    if  dup 6 .head  then drop
                then
        then    data? .oneline
    recur  next ;

: DAS       ( "name" -- )    '  mdas ;

v: fresh
shield DAS\
cr .( DAS size ) here swap - dm .
%%

chapter INSPECT\
need das\

here  hex
v: inside also definitions
\ 0 = niets  1 = andere def.  -1 = create .. code>  -2 = code
: ?CODE     ( -- +n )
    'see cell mod 0= if         \ Aligned cell?
        'see dup @ > if         \ Valid link?
            'see cell+ ?head    \ Valid header?
             ?dup if            \ Yes, decode word type
                @name + aligned >r
                r@ 20 - r@ @ > if \ Primitive jumping far backward?
                    1
                else            \ Code or CREATE type?
                    r@ cell+  r@ @ = 1-
                then  rdrop exit
             then
        then
    then  0 ;                   \ No change

: .HEAD     ( 0|a -- )
    ?dup if
        cr  over -2 = if ." code "      \ Select header type
        else
            over -1 = if ." create "
            else ." name "
            then
        then
        @name tuck type  aligned cell+  \ Print name
    else  cell
    then +to 'see ;

v: extra definitions
: INSPECT    ( "name" -- )
    ' >nfa 5 - to 'see  ?code  ( code or other )
    1 for
        'see cell+ ?head 0= if      \ No header?
            dup 1 = if decom then   \ Decompile machine code
            dup 0< if data? .oneline then   \ Decompile high level
            'see h@ FFFF = 2 and +to 'see   \ Skip code alignment
        else
            ?code nip                       \ Check code type
            'see cell+ ?head .head
        then
    recur  next drop ;

v: fresh
shield INSPECT\     \ freeze
here swap - dm .
%%

chapter ASM\
hex
(*  noForth RP2040 T(humb) assembler, only most used words!

(c) W.O, W.J, J.J.H & A.N. 2023 RP2040 ASM basic opcodes, vsn 0.8: 5752 bytes

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

here  \ noForth additions
v: inside also  assembler also  inside definitions

v: assembler definitions    \ Add register names & addressing modes
8000 constant IP   8001 constant SP   8002 constant W     8003 constant TOS
8004 constant HOP  8005 constant DAY  8006 constant SUN   8007 constant MOON
8008 constant WW   8009 constant XX   800A constant YY    800B constant ZZ
800C constant DOES 800D constant RP   800E constant LR    800F constant PC

( Addressing modes )
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

( 16-bits no operand opcodes )
: NOOP,     ww ww mov, ;
: CPSIE,    B662 h, ;      : CPSID,    B672 h, ;
: WFE,      BF20 h, ;      : SEV,      BF40 h, ;

( Add multi format opcodes: )
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
        dup )+ = if                             \ Optimise )+ separately?
            over WW < if                        \ Yes, ...
                drop swap >reg bitmask  ldm,    \ Yes, replace by LDM
                exit
            then
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


( Compose slightly different opcodes )
: SUB,      B080 sp+imm7, ;             \ RP imm7 # sub
: BX,       ip swap bx) ;     : BLX,      ww swap bx) ;
: POP,      ip swap pop) ;    : PUSH,     ip swap push) ;

v: inside definitions
( .....7FF - 11 bits, bit 0 to 10   ..1FF800 - 10 bits, bit 11 to 20 )
( ..600000 -  2 bits, bit 21 & 22   ..800000 - Sign bit, bit 23 )
: BL)       ( ad ao -- opc ) \ 32-bits branch & link opcode, range is 24-bits
    >dist  dup FFFFFF ?dist         \ Calc. offset & check range
    F000D000  over 7FF and or       \ Add first 11 bits to basic opcode
    over 1FF800 and  5 lshift or    \ Add next 10 bits
    over 0< >r  swap 0A rshift      \ Save sign & get bit 21&22 to bit 11&12
    invert  r@ xor  dup 800 and     \ Invert & add sign to J1 & J2, J2 is ok
    swap 1000 and  2* or  or        \ J1 to bit 13 & add to J2 and to opcode
    r> 4000000 and or ;             \ Add J1, J2 and sign, generate opcode

(* Forth conditionals, structure data & security are marked with an 's'
  Dx00: 0=EQ,  1=NE, 2=CS, 3=CC, 4=Minus (0<), 5=PL (Pos), 6=VS (Overflow)
        7=VC (No overflow), 8=HI (U>), 9=LS (U<=), A=GE (>=), B=LT (<),
        C=GT (>), D=LE (<=), E=AL (Always)
*)
: ?OFFSET   ( n opc -- n )  \ Build 7 or 11-bit branch offset
    E000 =  700 and  FF or >r  dup r@ ?dist  r> and ;

(* 55 constant SYS-CODE      \ Code structure
   66 constant SYS-IF,       \ for then, ahead, repeat,
   77 constant SYS-BEGIN,    \ for until, again, repeat,
   99 constant SYS-POOL      \ Pool structure
   AA constant SYS-COND      \ Conditionals *
*)
: CONDITIONAL   create ,  does> @ AA ; ( -- c s )
v: assembler definitions
    D100 conditional =?     D300 conditional CS?    D500 conditional NEG?
    D700 conditional VS?    D900 conditional U>?    DA00 conditional <?
    DD00 conditional >?

: NO        ( c1 -- c2 )    >r 100 xor r> ;

: IF,       ( c -- s )
    AA <> ?abort  here  swap h,  66 ; \ Compile opcode, leave data
: THEN,     ( s -- )
    66 ?pair >r  here r@ >dist      \ Check structure & calc. offset
    r@ h@ ?offset r@ h@ or  r> h! ; \ Check and add jump forward
: AHEAD,    ( -- s )        E000 AA if, ;
: ELSE,     ( s0 -- s1 )    ahead,  2swap  then, ; \ Jump always, resolve IF,

: UNTIL,    ( s c -- )
    AA <> ?abort >r  77 ?pair           \ Valid test and structure
    here >dist  r@ ?offset r> or h, ;   \ Check & assemble jump backwards
: BEGIN,    ( -- s )            here  77 ;       \ Leave data only
: AGAIN,    ( s -- )            E000 AA until, ; \ Jump to BEGIN,
: WHILE,    ( s0 c -- s1 s0 )   if,  2swap ;     \ Stay in loop on condition
: REPEAT,   ( s1 s0 -- )        again, then, ;   \ Close a BEGIN, WHILE, loop
: BL,       ( a -- )            here bl)  32b, ; \ Jump & link to address 'a'
: NEXT      ( -- )              state @ if  postpone next exit  then  next, ; immediate

v: fresh
shield ASM\
cr .( ASM length ) here swap -  dm .
%%

chapter +ASM\
\ RP2040 assembler extension
( Extended assembler opcodes for RP2040, 1272 bytes. )
need asm\

here  hex
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


( 32-bits no operand opcodes barrier opcodes )
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

v: fresh
shield +ASM\
cr .( ASM extensies ) here swap - dm .
%%

chapter PIO\
\ RP2040 PIO assembly sketch v0.7a, W.O. 12-oct-2022 - 26-jun-2025
\ Main words: PIO PIO\ PDAS {PIO .SM
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
\ Version 0.7a     Added multiple PIO code support, simplyfied EXPORT
\                  Changex EXEC to EXEC-OPC & FREQ to SET-FREQ
\ To-do:           Signalling shortcomings, IRQ control

need [undefined]
need [if]
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
: ONE       ( -- )      phere @  labels c! ;      \ Labels
: TWO       ( -- )      phere @ labels 1+ c! ;
: THREE     ( -- )      phere @ labels 2 + c! ;

v: extra definitions
: ONE>      ( -- pa )   flyer  labels c@  postpone literal ; immediate
: TWO>      ( -- pa )   flyer  labels 1+ c@  postpone literal ; immediate
: THREE>    ( -- pa )   flyer  labels 2 + c@  postpone literal ; immediate

[undefined] asm\ [if]
: =PIO      ( pio -- )      #pio 1- umin  100000 *  50200000 +  to 'pio ; \ Select active pio block
[else]
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
[then]

\ : PIO0      ( -- )          0 =pio ;
\ : PIO1      ( -- )          1 =pio ;

v: inside definitions
: SET-SM    ( sm -- )       3 and to #sm ;
: PIO-ADDR  ( offset -- a ) pcells  'pio + ;    \ Convert to real address
: PIO@      ( offset -- x ) pio-addr p@ ;

: PIO!      ( x offset -- ) pio-addr  p! ;

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
    6 pio? +                    \ Select PIO-0 to PIO-2 for IO-pin (6,7 or 8)
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
shield PIO\

\ More portable disassembler vsn 0.3
\
\ Version 0.2c: Changed factorisation & removed decode bug from .IN
\               Opcode decoding & integrated with PIO-ass!
\ Version 0.2d: Added .PINCONTROL & integrated in vsn 0.3d of PIO-ass
\ Version 0.2e: Added .SM for more complete state machine overview
\ Version 0.2f: Simplyfied structure, thanks to A.N.
\ Version 0.3:  Added mutiple PIO code support

need -trailing

v: inside also definitions
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
: PSEE      ( pio -- )
    =pio  base @ >r  hex
    20 0 do
        cr i 2 .r  ." : "               \ PIO address
        i code@  dup .hex  dup 0D rshift cells \ Get opcode & make index
        'pio-opc + @ execute            \ Decode each opcode from table
        i code@ .side&delay             \ Add side set & delay
        key bl <> if leave then
    loop
    r> base ! ;

: PSEE0     ( -- )          0 psee ;
: PSEE1     ( -- )          1 psee ;

hex  v: inside definitions \ Show state machine data
: .FLD        ( u f msk -- )    >r  rshift r> and . ;

v: extra definitions
: .SM       ( sm -- )
    ."  PIO " pio? 1 and 1 .r
    >r  base @ decimal  1 r@ lshift ." , sm " \ Generate SM-bit mask
    r@ .  0 pio@ and if ." on" else ." off" then  \ Show if SM is active
    0 r> sm-offset+ pcells 'pio + >r        \ Save SM-address
    r@ p@  8 rshift FF and 64 100 */        \ Scale divider fraq. part
    r@ p@  10 rshift  64 *  +  cr ." Clk: " \ Scale divider integer part
    0 cfg 2 + h@ F4240 * 64 rot */ . ." Hz, " \ Calc. & show frequency
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
%%

chapter PIOBASE\
hex
(* Separate minimal PIO control 08-march-2023 - 03-sept-2024

    SM-ON       = (De)activate state machine  ( f sm -- )
    SET-PIO     = Select PIO 0 or 1           ( n -- )
    TX-DEPTH    = Space on TX fifo of 'sm'    ( sm -- +n )
    RX-DEPTH    = Space on RX fifo            ( sm -- +n )
    >TXF        = Data to TX fifo             ( x sm -- )
    RXF>        = Data from RX fifo           ( sm -- x )
    EXEC-OPC    = Execute instruction on 'sm' ( instr sm -- )
    CLOCK-DIV   = Set clock divider on 'sm'   ( u sm -- )
    SET-FREQ    = Set 'sm' to clock freq. 'u' ( u sm -- )

This program is written for a 32-bits cell size

*)

v: inside also definitions
2 constant #PIO                 \ Number of PIO's
0 value 'PIO                \ Pointer to current active PIO

(* PIO internals
: PIO-ADDR  ( offset -- a )     cells  'pio + ; \ Convert to real address
: PIO@      ( offset -- x )     pio-addr @ ;
: PIO!      ( x offset -- )     pio-addr ! ;
: >FIELD    ( x mask pos -- y ) >r and  r> lshift ; \ Place bitfield

create SM-OFFSETS    32 c, 38 c, 3E c, 44 c, align  \ Address SM control blocks
: SM-OFFSET+ ( off1 sm -- off2 ) sm-offsets + c@ + ;

create PIO@ ( offset -- x )
    adr 'pio ,
code>
    w  w ) ldr,  tos 2 # lsls,  tos w adds,
    tos  tos ) ldr,   next,
end-code
create PIO! ( x offset -- )
    adr 'pio ,
code>
    w  w ) ldr,  tos 2 # lsls,  tos w adds,
    hop  sp )+ ldr,  hop  tos ) str,
    tos  sp )+ ldr,  next,
end-code
create SM-OFFSET+ ( off1 sm -- off2 )
    32 c, 38 c, 3E c, 44 c,  align
code>
    hop  sp )+ ldr,
    w  w tos r) ldrb,
    tos w hop adds.mv,
    next,
end-code
code >FIELD ( x mask pos -- y )
    sp { hop day } ldm,
    hop day ands,
    hop tos lsls,
    tos hop movs,
    next,
end-code
*)

create PIO@ ( offset -- x )
   adr 'pio ,
code>
    68126812 ,  189B009B ,  C804681B ,  46A7CA10 ,
end-code
create PIO! ( x offset -- )
   adr 'pio ,
code>
    68126812 ,  189B009B ,  601CC910 ,  C804C908 ,  46A7CA10 ,
end-code
create SM-OFFSET+ ( off1 sm -- off2 )
    443E3832 ,
code>
    5CD2C910 ,  C8041913 ,  46A7CA10 ,
end-code
code >FIELD ( x mask pos -- y )
    402CC930 ,  23409C ,  CA10C804 ,  FFFF46A7 ,
end-code

: FIELD!    ( data mask pos offset -- ) \ Replace any bit field with new data
    >r  2dup lshift invert  r@ pio@ and \ Erase bit-field
    >r  >field  r> or  r> pio! ;        \ Set bit-field & show result

: SET-CLOCK ( freq u sm -- )    \ Set clock divider
    >r  over 0 >  over 0=  and ?abort ( Invalid clock divider )
    8 lshift or  FFFFFF 8 0     \ Build clock parameters
    r> sm-offset+  field! ;     \ Replace clock data

v: extra definitions
: SM-ON     ( f sm -- )     1 swap 0 field! ; \ (De)activate a state machine

(* Set active PIO
: =PIO      ( pio -- )      #pio umin  100000 *  50200000 +  to 'pio ; \ Select active pio block

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
*)

create =PIO ( pio -- )  \ Select active pio block
    50200000 ,  adr 'pio ,
code>
    2B01CA30 ,  2301D900 ,  191B051B ,
    C908602B ,  CA10C804 ,  FFFF46A7 ,
end-code

: PIO0      ( -- )          0 =pio ;   : PIO1   1 =pio ;
: TX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * rshift  F and ; \ Fifo depth
: RX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * 4 + rshift  F and ; \ Idem
: >TXF      ( u sm -- )     4 + pio! ;      \ Store TX data in FIFO
: RXF>      ( sm -- u )     8 + pio@ ;      \ Fetch RX data from FIFO
: EXEC-OPC  ( instr sm -- ) 4 swap sm-offset+ pio! ; \ Exec. instruction
: SYNC      ( sm's -- )     7 8 0 field! ;  \ Sync. clock divider
: RESTART   ( sm's -- )     7 4 0 field! ;  \ Restart state machine

: SET-FREQ  ( u sm -- )
    >r  >r  0 cfg 2 + h@ F4240 *  r@ /mod \ Sys-clock/Wanted-clock
    dup FFFF u> ?abort ( Freq. to low ) \ 16-bit overflow?
    swap 100 r> */  swap r> set-clock ; \ Scale fractional part & set clock divider

: CLOCK-DIV ( u sm -- )
    >r  64 /mod >r                      \ Scale & save integer part
    100 64 */  r> r> set-clock ;        \ Scale fractional part

v: fresh
shield PIOBASE\
%%

chapter -LITERAL
v: also inside
: -LITERAL  ( u1 offset -- u2 )  \ Build number from u1 and an offset leaving u2
    flyer  bl-word count number? 0<> ?abort drop  +  postpone literal ;
v: previous

(* Usage example:
: 'DPRAM    ( "offset" -- a )  5010,0000  -literal ; immediate \ USB dpram address
: 'USBR     ( "offset" -- a )  5011,0000  -literal ; immediate \ USB register address

: STALL>            ( -- )          1 'usbr 68 !  800 'dpram 80 ! ; \ Send stall
*)
%%

chapter $VARIABLE
\ A few words that make string manipulation a little smoother.
: $VARIABLE ( +n "name" -- s )    \ Reserve space for a string buffer
    create  1+ allot  align ;

: C+!   ( n a -- )      >r  r@ c@ +  r> c! ;    \ Incr. byte with n at a
: $@    ( s -- c )      count ;                 \ Fetch string
: $+!   ( c s -- )      >r  tuck  r@ $@ +  swap move  r> c+! ; \ Extend string
: $!    ( c s -- )      0 over c!  $+! ;        \ Store string
: $.    ( c -- )        type ;                  \ Print string
: $C+!  ( char s -- )   dup >r  $@ + c!  1 r> c+! ; \ Add char to string
%%

chapter -TAIL
\ Cut i characters from a string, with underflow protection
\ -TAIL does not store anything.
: -TAIL ( adr len i -- adr len' )   0 max  over min - ;
%%

chapter -HEAD
\ Cut i characters from a string, with underflow protection
\ -HEAD does not store anything.
: -HEAD ( adr len i -- adr' len' )  0 max  over min  tuck - >r + r> ;
%%

chapter BITARRAY
hex \ Bit array for compact noting of precence or on/off state
v: extra definitions
\ : LOC       ( bit-nr a -- bit byte-addr ) \ Bit location in byte-addr
\    cell+ over 3 rshift +  >r \ Convert to byte addresses
\    07 and bitmask  r> ;    \ Convert low nibble to bit mask
code LOC    ( bit-nr a -- bit byte-addr ) \ Calc. bit location in byte-addr
    680C3304 ,  195B08E5 ,  402C2507 ,
    40A52501 ,  C804600D ,  46A7CA10 ,
end-code
                        \ Leave bit & word-adr
: BITARRAY
    create      ( bits "name"-- )  ( exec: -- a )
        20 /mod             \ Calculate length in cells & remainder
        swap 0<> -  dup ,   \ Remember size
        cells allot ;       \ Round length, reserve array

: *SET      ( nr a -- )       loc *bis ; \ Set bit nr in array a
: *CLR      ( nr a -- )       loc *bic ; \ Erase bit nr from array a
: GET*      ( nr a -- 0|msk ) loc bit* ; \ Bit nr set in array a?
: *ZERO     ( a -- )          @+ 2* 2* 0 fill ; \ Erase bit-map a
v: fresh
%%

chapter *COPY
v: extra definitions
\ *COPY any bit array to another, use the length of the shortest array!
: *COPY     ( a1 a2 -- )    \ Copy array a1 to array a2
    >r  r@ *zero            \ Erase the complete target array a2
    @+ r@ @ min             \ Address of array a1 & shortest array length
    2* 2*                   \ Convert this to bytes
    r> cell+ swap move ;    \ Move array a1 to destination array a2
v: fresh
%%

chapter COUNT*
v: extra definitions
\ Leave the number of bits set in bit array a
: COUNT*    ( a -- +n )     \ Counted noted high bits
    0  over @ hx 20 * 0 ?do \ a +n=0
        over i swap get*    \ a +n bit  Bits present?
        if  1+  then        \ a n+1     Add 1 when found
    loop  nip ;             \ +n
v: fresh
%%

chapter *UP?
v: extra definitions
\ Leave the number of the first used bit in a bit-array on stack and erase it
: *UP?      ( a -- false | nr true )
    dup @ hx 20 * 0 ?do         \ Test all bits
        i over get* if          \ Bit set?
            i swap *clr         \ Yes clear bit
            i true unloop exit  \ Leave bit-nr & true, ready
        then
    loop  drop  false ;         \ Nothing found
v: fresh
%%

chapter ?TASK
v: inside also  definitions
: ?TASK     ( task -- task ) \ Valid task, IT checks for A valid R0
    dup main = ?exit                \ Do nothing on MAIN!
    dup his r0 @ [ xorg 1000 + ] literal  xorg  within ?abort ;
v: fresh
%%

chapter (?
hex
(* Debugging through Run-Time Stack Checks, some examples

true to check?
: T1 (? +1) ?dup ;      \ stack is expected to grow with 1 element
: T2 (? +2) ;           \ stack should grow with 2 elements
: T3 (? -3) ;           \ stack should shrink with 3 elements
: T4 (? +0) ;           \ stack depth should not change

( Results when testing )
5 t1 .s 2drop ( 5 5 ) OK.0
0 t1 .s drop
Error in T1 -1
       Msg from STACK.CHECK \ Error # AB29 -54D7
( this means that there is 1 element less than expected on the stack )

t2
Error in T2 -2
     Msg from STACK.CHECK \ Error # AB29 -54D7
( 2 elements less than expected )

t3
Error in T3 3
     Msg from STACK.CHECK \ Error # AB29 -54D7
( 3 elements more than expected )

t4  OK.0
*)

v: inside also  definitions
: STK.CHECK ( stack-growth nfa -- )
    depth
    swap r> 2>r         \ save nfa
    +    r> 2>r         \ save expected depth
    dive                \ finish the main word now
    2r> depth -         \ depth not as expected?
    dup if cr ." Error in "
           over count hx 1F and type space
           dup s>d if ." +" then negate .
           ?abort
    then 2drop ;

0 value CHECK?
v: extra definitions
: (?        ( -- )
    [char] ) parse + 2 -        \ read "n)"
    check?
    if  count swap c@           \ sign and digit
        [char] 0 - swap
        [char] - = if negate then
        postpone literal                \ expected stack growth
        created lfa>n postpone literal  \ nfa of main word
        postpone stk.check
    exit then
    drop ; immediate
v: fresh
%%

chapter TASK
hex
(* To add background tasks only:

This point is the main task Task-Control-Block (TCB) is marked as MAIN

00 TLINK   - 0 cells - Link chain with all tasks
04 TSTATE  - 1 cells - Task status, true = active
08 ERR?    - 2 cells - Error status of task
0C TRP     - 3 cells - Return stack position of this task
10 BASE    - 4 cells - Number base
14 FP      - 5 cells - FLYER pointer
18 FLYBUF  - 6 cells - Pointer to tasks private memory
1C FLYBUF/ - 7 cells - FLYBUF + #FP = FLYBUF/ ( 18 cells or 96 bytes )
20 R0      - 8 cells - Bottom returnstack
24 S0      - 9 cells - Bottom datastack


main task goes on with:
TIB     - Terminal input buffer
TIB/    - TIB end
BORDER  - End of this Forth's memory space


Multitasker built-in words:
HIS         ( "name" -- a ) Prefix to get the address of other tasks
                            values & variables
SLEEP       ( task -- )     Let 'task' sleep, by stopping it
WAKE        ( task -- )     Let 'task' run again by waking it
STOP        ( -- )          Put current task asleep
PAUSE       ( -- )          Do task switch
XHERE       ( -- a )        Leave first free address in XRAM


Multitasker wordset:
START-TASK  ( xt task -- )          Run 'xt' on 'task'
XALLOT      ( n -- )                Reserve 'n'bytes of XRAM
TASK        ( +d +r "name" -- )     Define named task with +d cells D-stack
                                    & +r cells R-stack
TASK:       ( "name" -- )           Define named task with fixed stacks depths,
                                    a 16 cells D-stack and a 32 cells R-stack
LOCK        ( sema -- )             Grab a semaphore when it's free
UNLOCK      ( sema -- )             Free a semaphore when it's mine
TASKS       ( -- )                  Show all defined tasks
TDEPTH      ( task -- +n )          Give stack depth of 'task'
.STK        ( task -- )             Show stack of 'task' like .S
PASS        ( x0 .. xn +n task -- ) Push +n elements to the stack of 'task'
                                    When +n = 0 the stack is emptied
*)

v: inside
need @name
v: inside
need >nfa
v: inside
need ?task

hex \ Multitasker wordset
v: inside also  definitions
' main drop \ This file is for noForth multitask only!

code >TASK  ( ip xt task -- ) \ Set task ready
    B403C950 ,  4630466F ,  46AD6A1D ,
    B41B6A59 ,  60DD466D ,  BC0346BD ,  C804C908 ,
    46A7CA10 ,  end-code
\ code >TASK  ( ip xt task -- )
\    sp  { hop sun } ldm,    \ XT to HOP, IP to SUN
\    { ip sp } push,         \ Save noForth registers
\    moon rp mov,            \ Save RP
\    ip sun mov,             \ Ip to IP
\    day tos 20 #) ldr,      \ Read R0 to DAY
\    rp day mov,             \ Use R0 as tasks RP
\    sp tos 24 #) ldr,       \ Set SP to S0
\    { ip sp tos hop } push, \ Initialise tasks return stack
\    day rp mov,             \ Copy RP to DAY
\    day  tos 0C #) str,     \ Set tasks RP too
\    rp moon mov,            \ Restore noForth registers
\    { ip sp } pop,
\    tos  sp )+ ldr,         \ Pop stack
\    next,
\ end-code

v: extra definitions
: XALLOT    ( n -- )
    xhere over + [ xorg 1000 + ] literal < 0= ?abort  +to xhere ;

create START-TASK  ( xt task -- )   \ Install & start 'task' with 'xt'
    ]  begin  r@ catch to err?  stop  again  [
does>  ( xt task body -- )
    swap ?task >r  false r@ his err? ! \ Reset tasks error flag
    swap r@ >task  r> wake ;        \ Set task ready and start it

: TASK      ( +d +r "name" -- )     \ Build new named task
    here >r  #tcb allot  align      \ Allocate TCB
    r@ #tcb 0 fill                  \ TCB start with all zeros
    TLINK @  r@ !  r@ TLINK !       \ Build this tasks link
    base @  r@ his BASE !           \ Set number base
    xhere  r@ his flybuf !          \ Set start of flyer buffer
    xhere  r@ his FP !   60 xallot  \ Set FP & reserve flyer buffer
    xhere  r@ his flybuf/ !         \ Set FLYBUF end
    cells xallot  xhere r@ his R0 ! \ Reserve R-stack, set R0
    cells xallot  xhere r@ his S0 ! \ Reserve D-stack, set S0
    ['] start-task >body  ['] noop  \ Set tasks IP ready
    r@ >task   r> constant ;        \ Install default task too and name it

: TASK:     ( "name" -- )   10 20 task ;
v: fresh
%%

chapter TASKS
\ Multitasker tools wordset
v: inside
need @name
v: inside
need >nfa
v: inside
need ?task

hex
v: inside also  extra definitions  also inside
' main drop \ This file is for noForth multitask only!

: RDEPTH    ( task -- +n )
    ?task >r  r@ his r0 @       \ Valid task, read R-stack bottom
    r> his trp @ -  cell / ;    \ Read TRP & calculate depth

: TDEPTH    ( task -- +n )
    ?task  >r r@ main =         \ Valid task and is it MAIN?
    if  rdrop depth exit  then  \ Yes, default DEPTH and ready
    r@ his s0 @                 \ Read address stack bottom
    r> his trp @ cell+ @        \ Read current SP from R-stack
    -  cell / ;                 \ Calculate depth

: .STK      ( <i*x> task -- <i*x> )
    ?task  dup main = if drop .s exit then \ Normal .S for main task
    (.) space  >r  r@ tdepth if         \ Data on tasks stack?
        r@ his s0 @ cell-               \ Yes, to bottom of stack
        r@ tdepth 1-  0F umin           \ Elements without TOS
        for  cell- dup @ .  next drop   \ Show them
        r@ his trp @ cell+ cell+ @ .    \ Print TOS too
    then  rdrop ;

: PASS      ( x0 .. xn +n task -- )
    ?task >r  dup 0< ?abort cells   \ Save task & convert n to cells    x0 .. xn n*4
    r@ his s0 @  over -             \ Calc. stack pointer               x0 .. xn n*4 as1
    r@ his trp @ cell+  !           \ Replace stack pointer             x0 .. xn n*4
    ?dup if                         \ More then one cell?
        swap  r@ his trp @ cell+ cell+  ! \ TOS = xn                    x0 .. xn-1 n*4
        r@ his s0 @ over -          \ Calc. stack address               x0 .. xn-1 n*4 as1
        swap cell- bounds           \ Calc. storage range               x0 .. xn-1 as2 as1
        ?do  i !  cell +loop        \ Store remaining stack data there
    then  rdrop ;

v: inside definitions
\ Tasks viewer
: .NAME     ( task -- )     \ Search for task, type name
    >r  hot 8 cells bounds                      \ for 8 threads     a2 a1
        begin
            dup  begin                          \                   a2 a1 a1
            @ dup while                         \ until link=0      a2 a1 a1@
                dup lfa> >body @ r@ = if        \                   a2 a1 a1@
                    lfa>n @name                 \ Print tasks name in a column
                    0C umin  0C rtype
                    rdrop  2drop  exit
                then
            repeat  drop cell+                  \ Next thread       a2 a1+4
        2dup = until  ?abort ;                  \ Task not found?

: .ACTION   ( task -- ) \ Show words name when it's valid
    dup his r0 @ cell- @ >nfa  ?dup \ Valid NFA?
    if  @name type  drop exit  then \ Yes, show name
    his r0 @ cell- @  . ;           \ No, show address

: .DEC      ( u -- )        decimal  0 <# # # # #> type  hex ;

: .DEPTH    ( task -- ) \ Print stack depth, print ?? when it's out of range
    >r  r@ his s0 @  r@ his r0 @ -  cell / .dec  ch / emit
    r@ tdepth  r@ his s0 @  r> his r0 @ -  cell /
    over u> if  .dec  else  drop ." ???"  then  space space ;

: .RDEPTH   ( task -- ) \ Print return stack depth
    >r  r@ his r0 @  r@ his flybuf/ @ -  cell / .dec
    ch / emit  r> rdepth .dec 3 spaces ;

: .ERROR    ( nfa -- )  \ Print error number or name
    his err? @ dup origin > if \ An ?abort error
        @name 9 umin  9 rtype  2    \ Yes, print name
    else  hex  8 .r  3  then  spaces ; \ No, print number

: .TASK     ( task -- )     \ Show all tasks and their status
    base @ >r  ?task >r  r@ .name space space
    r@ his tstate @ if ." wake  " else ." sleep " then
    r@ .depth   r@ .rdepth
    r@ his base @ .dec 2 spaces
    r@ .error
    r@ main = if  ." noForth "  else  r@ .action  then
    rdrop  r> base ! ;

v: extra definitions  also inside
: TASKS     ( -- )      \ Run along chained tasks
    cr ."         Task    ?    Stack    Rstack   BASE   Error    Action"
    cr ."    ------------------------------------------------------------"
    main >r                 \ First TCB
    begin
        cr  r@ .task
        r> @ >r
    r@ main = until  rdrop ; \ All tasks done?
v: fresh
%%

chapter STK
v: inside also extra definitions    \ 0 = TOS, 1 = second of stack, etc.
: STK       ( +n task -- addr )     \ Get stack address '+n' from 'task'
    ?task >r  ?dup if               \ Not TOS?
        cells negate                \ Yes, address of Nth element
        r> his s0 @ cell-  +
    else
        r> his trp @ cell+ cell+    \ No, read address TOS
    then ;
v: fresh
%%

chapter LOCK
\ Semaphores, tools for sharing devices
hex
v: inside also definitions
code TC@    ( -- task )     600B3904 ,  C804465B ,  46A7CA10 ,  end-code
\ code TC@   ( -- task ) \ Get active tasks TCB
\    tos  sp -) str,     \ 3 - Save TOS
\    tos TP mov,         \ 1 - TP to TOS
\    next,               \ 6
\ end-code

v: extra definitions
: LOCK      ( sema -- )
    dup @ TC@ = IF  drop exit  THEN \ Do nothing when i own it
    BEGIN  dup @ WHILE pause REPEAT \ Semaphore not mine, to next task
    TC@ swap ! ;                    \ Grab semaphore!

: UNLOCK    ( sema -- )     dup lock  false swap ! ; \ Free semaphore
v: fresh
%%

chapter SPINLOCK
hex
(* Using spinlocks
A spinlock is a dedicated memory location that can be used
to protect memory access & hardware devices on a multicore system.
When read zero the address or device is locked, when read non zero!
the device is free to use and locked at the same time.
When both cores access the spinlock at the same time core-0 wins.
D0000100    - Spinlock 0

0 yours     - RX spinlock ( 0 mine? )
4 yours     - TX spinlock ( 4 mine? )

Note that, when the dual CDC driver is loaded, spinlock 0 & 4 are in use.

create MINE?    ( +n -- s ) \ Leave s when spinlock +n is free, 0 when occupied
    D000,0100 ,
code>
    w { hop } ldm,
    hop tos adds,
    tos  hop ) ldr,
    next,
end-code

create YOURS    ( +n -- )   \ Free spinlock +n
    D000,0100 ,
code>
    w { hop } ldm,
    hop tos adds,
    tos  sp )+ ldr,
    tos  hop ) str,
    next,
end-code

*)

v: extra definitions
create MINE?    ( +n -- s ) \ Leave 1 when spinlock +n is free, 0 when occupied
    D0000100 ,  code> 18E4CA10 ,  C8046823 ,  46A7CA10 ,  end-code
create YOURS    ( +n -- )   \ Free spinlock +n
    D0000100 ,  code> 18E4CA10 ,  6023C908 ,  CA10C804 ,  FFFF46A7 ,  end-code
v: fresh
%%

chapter MINE?
need spinlock
%%

chapter TASKER\
need task   \ Complete tasker wordset
need tasks
need lock
need spinlock

v: fresh
shield TASKER\
%%

chapter SET-FREQ
hex
(* Generic PLL setter

Not all desired RP2040 frequencies are possible!
Note that the expected life of the RP2040 decreases with a higher freqeuncy.

After multiplier freq: between 750 MHz & 1600 MHz
Valid multiplier = 16 to 320
The PLL dividers are both between 1 & 7, 32xx = /3 & /2 = /6
Next step adjusting the internal core power supply

0x40064000 Core voltage at page 160 (used bits 0 & 4 to 7)

\   0 over 7 > 4 and +  1800,0014 ! \ Change Pico_Flash_SPI_Clkdiv

*)

need [undefined]
need [if]

v: inside also  definitions
create PLL-CLK1  decimal
\     0        1       2       3       4       5       6       7       8       9       A       B
\     12      30      48      60      125     132     200     250     300     360     375     400
     006 c,  015 c,  024 c,  030 c,  062 c,  066 c,  100 c,  125 c,  150 c,  180 c,  187 c,  200 c,
\ Core voltage settings
hex  071 c,  071 c,  071 c,  071 c,  0A1 c,  0A1 c,  0B1 c,  0B1 c,  0C1 c,  0F1 c,  0F1 c,  0F1 c, align
\ Mutiplier & 2 stage divider
    3177 h, 4604 h, 4044 h, 4672 h, 7D62 h, 4261 h, 6461 h, 7D61 h, 4B31 h, 5A31 h, 7D41 h, 6431 h, align

\ This word is secure, uses always a valid frequency
: >PLL1     ( clk -- post mul ) \ Leave data for PLL settings
    dup 2/  0 begin                 \                                           clk clk/ n
        2dup pll-clk1 + c@ <>       \ Invalid clock?                            clk clk/ n f
    while
    1+ dup 0C = until               \ Leave here when MHZ is invalid!           clk clk/ n+1
        drop 2drop   7D dup  4      \ Set default = 125MHz                      clk clk n=4
    then  nip swap false cfg 2 + h! \ Save new clock, keep n                    n = 0 to 11
    4006,4000 >r  dup pll-clk1 0C + + c@ \ Get core voltage                     n cv
    r@ !  begin 1000 r@ bit** until \ Set it & wait until it's stable           n
    rdrop  2*  pll-clk1  dm 24 +  + \ Leave setup data                          a
    h@ b-b >r  0C lshift  r> ;      \ Make PLL-setup factors                    mult div

\    dm 24  dm 125  h+h 0 cfg ! \ GPIO pin number for S? & default system clock
\    hx 40034000        1 cfg ! \ Default UART or 40038000
\    dm 115200          2 cfg ! \ Default baudrate
\    hx D0000004        3 cfg ! \ GPIO input address register
\    0                  4 cfg ! \ Load only noForth for core0 & start
\    ' noop             5 cfg ! \ Token for alternative configuration
: NEW-FREQ  ( f -- )   \ Initialise system clock, etc.
    >pll1                   \ Set frequency, get PLL clock data
    restart-devices         \ All RP2040
    start-xosc
    3000 4000E000 !         \ Resets base register SET alias, reset PLL's
    3000 4000F000 !         \ Clear alias, clear PLL's
    begin
        4000C008 @ 3000 and \ Read resets base,
    3000 = until            \ PLL's ready?
    ( 62000 7D ) init-plls  \ Set PLL clocks
    init-clks               \ Set all system clocks
    100 54 clk-on           \ & USB clock
    100 60 clk-on           \ & ADC clock
    10000 6C clk-on         \ Finally RTC clock

    20C 4005802C !          \ Start WD ticks
    800 40008048 !          \ Peripheral clock
    false 4000C000 !        \ Unreset all

    301 40034030 **bic      \ Uart & transmit disable
    2 cfg @ baud  set-gpio  \ Default baudrate
    301 40034030 !          \ Enable UART
    2 0 gpio!  2 1 gpio!    \ Enable UART on GPIO0 & GPIO1
\ Reboot second core too
[defined] boot1 [if]
    0 cfg 2 + h@ ramborder 10A + h! \ Note new frequency for second core too
    ramborder 4 + @ boot1   \ Restart from second cores reset vector
[then]
[defined] usb-on [if]       \ With usb driver?
    usb-on                  \ Yes, add USB activation
[then] ;


v: extra definitions
\ Gradually switch to a higher frequency, max = 400 MHz
: SET-FREQ  ( freq -- )
    dup dm 200 > if  dm 200 new-freq  FF us  then
    dup dm 300 > if  dm 360 new-freq  FF us  then
    new-freq  20 us ;
v: fresh
%%

chapter TESTER\
hex
(* A simple test program

    Uses the Hayes syntax, but is noForth specific

    T{ 1 2 3 swap -> 1 3 2 }T
    T{ DEPTH -> 0 }T

*)

v: inside also definitions
create RESULTS  20 cells allot  \ Stack results, max: 32
0 value STACK-OUT               \ Stack after test
0 value #ERRORS                 \ Note incorrect results

v: forth definitions
: SOURCE      ( -- a u )        ib #ib ;                \ input stream

v: inside definitions
: CORRECT-STACK ( i*x -- j*x )  \ correct stack depth
    depth 0< if                 \ underflow?
        depth abs for 0 next exit
    then                        \ no, correct overflow
    depth for  drop  next ;

: ERROR     ( c-addr u -- )     \ display an error message
   incr #errors                 \ followed by the line that had the error
   type source type cr          \ display line corresponding to error
   correct-stack ;              \ Restore stack depth

v: extra definitions
: T{          ( i*x -- i*x d )  correct-stack ;         \ Start test
: TESTING     ( -- )            postpone \ ;            \ Test comment
: CLR-ERRORS  ( -- )            0 to #errors ;          \ Reset error counter
: .ERRORS     ( -- )            #errors . ;             \ Show number of errors

: ->        ( i*x -- j*x )      \ Store test result
    depth to stack-out          \ record depth
    depth 0 ?do                 \ save them
        results i cells + !
    loop ;

: }T        ( i*x -- j*x )      \ Compare & show test errors if any
    depth stack-out <> if                           \ depths not match?
        s" Wrong number of results: " error  exit   \ yes, depth mismatch!
    then
    depth 0 ?do                     \ for each stack item
        results i cells + @ <> if   \ is actual value not as expected?
            s" Incorrect results: " \ ok, issue mismatch
            error  leave
        then
    loop ;

v: fresh
shield TESTER\
%%

chapter TRACER\
\ Miniature independent tracer, outputs data over default RS232 interface
\ Based on A.N's example from P.F.W.
need pchar

hex
: .CR       ( -- )      0D emit)  0A emit) ;
: .SPACE    ( -- )      bl emit) ;
: .1HX      ( x -- )    0F and  >dig  emit) ; \ Print last digit of x in hex

create NHX 10 allot
: .NHX ( x n -- )       \ Print last n digits of x in hex
    1 max  10 min >r         \ x r: n
    r@ for  dup nhx i + c!  4 rshift  next  drop
    nhx  r> for  c@+ .1hx  next  drop .space ;

: .B  2 .nhx ;   : .P  3 .nhx ;   : .H  4 .nhx ;   : .W  8 .nhx ;

: .HEXDUMP  ( a u -- )  \ Small dump routine
    .cr  0 ?do
        c@+ .b  i 10 mod 0= if .cr then
    loop  drop ;

: .DUMP     ( a u -- )  \ Small classic dump routine
    .cr  0 ?do
        dup  10 for  c@+ .b  next  drop .space
        10 for  c@+ pchar emit)  next  .cr
    10 +loop  drop ;

v: fresh
shield TRACER\
%%

chapter IMAGE
\ Write current FROZEN version to an Intel-Hex stream
\ The stream can be copied & saved to an ASCII-file.
\ Use: CORE IMAGE  or  CORE+ IMAGE  or  CORE+LIB IMAGE
\ This file can then be converted to a UF2 file using the
\ HEX>UF2 tool, that can be loaded & executed in Win32Forth
\ Usage: HEX>UF2 "filename"

hex v: inside also  definitions
  1000,0000 constant XIP        \ Start of XIP memory
v: forth definitions
: CORE      ( -- end start )    1000,0100 @+ +  xip ; \ Forth core only
: CORE+     ( -- end start )    1004,1000 @+ +  xip ; \ Second Forth core too
: CORE+LIB  ( -- end start )    libhere  xip ;        \ Both cores & library

v: inside definitions
0 value CHKS        \ Hold checksum
20 value B/LINE     \ Number of bytes per line
: .XX   ( n -- )    dup +to chks  0 <# # # #> type  8 us ;
: .XXXX ( n -- )    dup 10 rshift .xx  dup 8 rshift .xx  .xx ;
v: forth definitions
: IMAGE     ( end start -- )    \ Image of noForth
    begin
        cr  2dup - b/line umin  \ enda begina len
    dup while                   \ 1 line
        ." :"  0 to chks        \ record mark
        dup .xx                 \ reclen
        over .xxxx              \ load offset \ address
        0 .xx                   \ rectyp
        0 do count .xx loop     \ data
        chks negate .xx         \ checksum
    repeat
    drop 2drop ." :0000000001FF" cr
    C8 us  config ;             \ To keep USB alive
v: fresh
%%

chapter UNIT
hex
\ Search order after UNIT = only extra forth voc inside inside
\ 'UNIT = Holds the active external vocabulary

v: inside also definitions
' forth value 'UNIT     \ Hold token of EXTERNAL vocabulary
v: extra definitions
: UNIT      ( "voc" -- )    fresh  ' to 'unit  'unit execute also  inside also  definitions ;
: EXTERNAL  ( -- )          'unit execute  definitions ;
: INTERNAL  ( -- )          inside  definitions ;
: END-UNIT  ( -- )          fresh ;
v: fresh
%%

chapter MEASURE\
hex
(* Timing of code parts
create KICKOFF ( -- )
    40054028 ,
    r@ ,
code>
    w  { hop day } ldm,
    w  hop ) ldr,
    w  day ) str,
    next,
end-code

create PASSED ( -- µs )
    40054028 ,
    r> ,
code>
    w  { hop day } ldm,
    tos  sp -) str,
    tos  hop ) ldr,
    sun  day ) ldr,
    tos sun subs,
    next,
end-code
*)

v: inside also definitions
here 0 , >r     \ Storage for timing

create KICKOFF  ( --  )     \ Save timer
   40054028 ,  r@ ,         \ Timer & storage location
code>
    6822CA30 ,  C804602A ,  46A7CA10 ,
end-code

create PASSED   ( -- µs )   \ Calculate time passed in µs
    40054028 ,  r> ,        \ Timer & storage location
code>
    3904CA30 ,  6823600B ,  1B9B682E ,
    CA10C804 ,  FFFF46A7 ,
end-code

: .TIME         ( -- )      \ Print time passed in millisec.
    passed  hx 3E8 /mod  cr
    0 <# #s #> type ." ,"
    0 <# # # # #> type ."  millisec. " ;

v: forth definitions
: MEASURE       ( "name" -- ) \ Time the peace of code "name"
    base @ >r  '  kickoff  catch drop
    decimal .time  r> base ! ;

v: fresh
shield MEASURE\
%%

chapter CDC\
hex
(* USB driver used Leon's & Alex Taradov's code & RP2040 datasheet for documentation
    Henny Luijkx made the overview of Alex's code ( 3256 bytes + 648 for tasker words )
    Willem Jager, Leon Konings & Henny Luijkx did test and document this effort

0000 = R/W, 1000=XOR, 2000=SET, 3000=CLEAR
https://www.beyondlogic.org/usbnutshell/usb1.shtml

This version USB-XS-005 is a neat CDC driver that works with Linux & Windows
using a 1 millisec. line delay and with macOS using character handshake.
*)

here
need TASK

v: inside also definitions \ USB device data structures
here >r     \ Device descriptor (18 bytes)
12 c, 01 c, 00 c, 02 c, ( 2.00 ) EF c, 02 c, 01 c, 40 c, 66 c, 66 c, ( 6666 )
10 c, 66 c, ( 6610 ) 00 c, 01 c, ( vsn 1.00 ) 00 c, 02 c, 00 c, 01 c,  ( align )

here >r     \ Configuration descriptor (9 or 75 bytes)
9 c,  2 c,  4B c,  0 c,  2 c,  1 c,  0 c,  80 c,  FA c, \ Maximum power = 500mA
\ CDC 0
8 c,  0B c,  0 c,  2 c,  2 c,  2 c,  1 c,  0 c,         \ Interface Association Descriptor
9 c,  4 c,  0 c,  0 c,  1 c,  2 c,  2 c,  1 c,  0 c,    \ Interface 1: Control - 1 - 0 -
5 c,  24 c,  0 c,  10 c,  1 c, ( CDC vsn 1.10 )         \ CDC Header functional
5 c,  24 c,  1 c,  0 c,  1 c,                           \ CDC Call management functional
4 c,  24 c,  2 c,  2 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  6 c,  0 c,  1 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  81 c,  3 c,  8 c,  0 c,  10 c,              \ Endpoint 1 IN descriptor
9 c,  4 c,  1 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  82 c,  2 c,  40 c, 0 c,  0 c,               \ Endpoint 2 IN descriptor
7 c,  5 c,  3 c,  2 c,  40 c, 0 c,  0 c,  align         \ Endpoint 3 OUT descriptor

create USB-STATE  0 ,           \ Hold current USB state: 7 = ready, 107 = functional
        4 c, 3 c, 9 c, 4 c,     \ English/US = language ID
        dm 115200 ,  0 c,  0 c,  8 c,  align  \ Line data: 115k2, Stop bits, Parity, Data bits
                                \ Second half word for 900/880 requests

\ Name:    CNT  ORG  PKT  PID   INBUF-CTRL  OUTBUF-CTRL   EPxBUF
\ Offsets: 00   04   08   0C       10            14         18
create EP0   4 cells allot   5010,0080  dup ,   4 + ,    5010,0100 ,
create EP1   4 cells allot   5010,0088  dup ,   4 + ,    5010,0180 ,
create EP2   4 cells allot   5010,0090  dup ,   4 + ,    5010,0200 ,
create EP3   4 cells allot   5010,0098  dup ,   4 + ,    5010,0280 ,

: @VAL      ( -- +n )       5010,0002 h@ ; \ wValue
: @LEN      ( -- +n )       5010,0006 h@ ; \ wLength

(* High level code for documentation
: >UNI      ( a1 u -- a2 )      \ Convert string to unicode format for USB
    dup  2* 302 + fp h!  0      \ String length & notifier
    ?do  c@+  fp i 2* + 2 + h!  loop  drop  fp ;
: >CNT      ; immediate         \ 00 - ep0 >cnt !
: >ORG      cell+ ;             \ 04 - ep1 >org @
: >PKT      2 cells + ;         \ 08
: >PID      3 cells + ;         \ 0C
: >ICTRL    4 cells + ;         \ 10
: >OCTRL    5 cells + ;         \ 14
: >EPBUF    6 cells + ;         \ 18
: EP-IN     ( ep -- org buf pkt )   >r  r@ >org @   r@ >epbuf @   r> >pkt @ ;
: PREPARE   ( a u ep -- )           >r  dup r@ >cnt !  40 min r@ >pkt !  r> >org ! ;
: >NEXT     ( ep -- pkt )           >r  r@ >pkt @   r@ >org @  +  r@ >org !
                                    r@ >pkt @  r@ @  over -  dup r@ !  40 min r> >pkt ! ;
: !PKT      ( pkt ep -- ictrl )     >r  r@ >pid @ or  8000 or   \ pid + pkt + mask
                                    r> >ictrl @  tuck ! ;
: USB-RCV)  ( ep -- )               >r r@ >octrl @   r@ >pid @  40 or  over !
                                    2000 r> >pid **bix  400 swap **bis ;
: GONE?     ( ep -- f )             >ictrl @ @ 400 and 0= ;
: USB?      ( -- +n )               usb-state h@ 3 = ;
: 2+        ( n1 -- n2 )            2 + ;
*)

create >UNI ( a1 u1 -- a2 )     \ Convert string to unicode format for USB (32)
    adr fp ,  300 ,  code>
    6824CA30 ,  C9208025 ,  782F2202 ,  52A73501 ,
    3B013202 ,  7022D1F9 ,  C8040023 ,  46A7CA10 ,  end-code
code >PID       C804330C ,  46A7CA10 ,  end-code
code >EPBUF     C8043318 ,  46A7CA10 ,  end-code
code EP-IN      699D685C ,  3904689B ,  3904600C ,  C804600D ,  46A7CA10 ,  end-code
code PREPARE    601DC920 ,  D9002D40 ,  609D2540 ,
                605DC920 ,  C804C908 ,  46A7CA10 ,  end-code
code >NEXT      685D689C ,  605D192D ,  1B2D681D ,
                2D40601D ,  2540D900 ,  0023609D ,  CA10C804 ,  FFFF46A7 ,  end-code
code !PKT       C92068DC ,  2580432C ,  432C022D ,
                601C691B ,  CA10C804 ,  FFFF46A7 ,  end-code
code USB-RCV)   68DD695C ,  43352640 ,
                26206025 ,  68DF0236 ,  60DF4077 ,  1362640 ,
                60254335 ,  C804C908 ,  46A7CA10 ,  end-code
code GONE?      681B3310 ,  2404681B ,  40230224 ,
                419B3B01 ,  CA10C804 ,  FFFF46A7 ,  end-code
create USB?     usb-state ,  code>  39046812 ,  8813600B ,
                D0002B03 ,  C8042300 ,  46A7CA10 ,  end-code
code 2+         C8043302 ,  46A7CA10 ,  end-code

\ Basic receive & transmit packet handlers
: USB-SEND      ( ep -- )       >r  r@ >next  r@ !pkt  2000 r> >pid **bix  400 swap **bix ;
: USB-RCV       ( pid ep -- )   tuck >pid !  usb-rcv) ;

: SETUP>        ( a u -- )      \ Handle the answer for all setup packages
    2000 ep0 >pid !  ep0 prepare                \ Start with DATA1, setup packet data
    begin
        ep0 ep-in move  ep0 usb-send            \ Send packet
        1 5011,0058                             \ Packet gone?
        begin   pause  2dup bit** until  **bis
    ep0 @ 0= until  2000 ep0 usb-rcv ;          \ Handle ZLP

\ : XTABLE        ( tkn a +n -- )        \ USB execution table handler (148)
\    >r r@ for  2dup @ = if              \ Token found?
\            nip  rdrop  r> cells +      \ Yes, calc. cell with XT
\            @ execute  exit             \ Fetch & execute XT
\        then
\        cell+
\    next  rdrop  2drop                  \ No token found
\    1 5011,0068 !  800 5010,0080 ! ;    \ Send EP0 stall
create XTABLE   ( tkn a +n -- ) \ USB execution table handler (72)
    50110068 ,  50100080 ,
code>
    001FC930 ,  6826009B ,  D10442B5 ,
    C90818E4 ,  CA106822 ,  340446A7 ,
    D1F43F01 ,  2301CAC0 ,  23086033 ,
    603B021B ,  C804C908 ,  46A7CA10 ,
end-code

: ZLP>          ( -- )      here false setup> ;             \ Send EP0 ZLP

:noname     me count 1D min >uni  dup c@ @len min setup> ;  \ 0302 Device name string
:noname     usb-state cell+ 4 setup> ;                      \ 0300 Lang-ID string
:noname     [ r> ] literal  @len 4B min setup> ;            \ 0200 CONF-DESCR>
:noname     [ r> ] literal  12 @len min setup> ;            \ 0100 DEV-DESCR>
create HANDLE-SETUP     ( -- )
    0100 ,     0200 ,      0300 ,     0302 ,
    ( dev ) ,  ( conf ) ,  ( 300 ) ,  ( 302 ) ,
does>   ( tkn a -- )    4 xtable ;

' cold                                       \ 2321 Break, restart noForth t
:noname     @val usb-state c!  zlp> ;        \ 2221 Set control line state
:noname     usb-state cell+ cell+ 7 setup> ; \ 21A1 Get line coding
:noname     2000 ep0 usb-rcv  zlp> ;         \ 2021 Set line coding
:noname     zlp>  @val   usb-state 2+  h! ;  \ 0900 Set USB configuration
:noname     usb-state 2+ 2 setup> ;          \ 0880 Get USB configuration
:noname     @val handle-setup ;              \ 0680 Basic usb SETUP handler
:noname     zlp>  @val 5011,0000 ! ;         \ 0500 Set device address
create HANDLE-REQ
    0500 ,  0680 ,  0880 ,  0900 ,  2021 ,  21A1 ,  2221 ,  2321 ,
    ,       ,       ,       ,       ,       ,       ,       ,
does>   ( a -- )        20000 5011,3050 !  5010,0000 h@  swap  8 xtable ;


\ Ring buffers for safe character I/O
100         constant #L         \ Must be factor of two
\ 5010,0300   constant BUFFERS    \ Usess 2 * #L + 24 bytes  = 536 bytes

create #RX  ( -- +n )   \ Chars in RX buffer (20)
    5010,0300 ,  here >r
code>  600B3904 ,  681BCA08 ,  CA10C804 ,  FFFF46A7 ,  end-code
create #TX  ( -- +n )   r>  here cell- !  5010,0300 #L + 3 cells + , \ Chars in TX buffer
create >RX  ( c -- )    \ Save char. in RX buffer
    5010,0300 ,  #L 1- ,  code>   here >r
    0015CA84 ,  350C6854 ,  3401552B ,  6054403C ,
    35016815 ,  C9086015 ,  CA10C804 ,  FFFF46A7 ,
end-code
create >TX  ( c -- )   r>  here cell- !  5010,0300 #L +  3 cells + ,  #L 1- , \ Save char to send
create RX>  ( -- c )    \ Read char from RX buffer
    5010,0300 ,  #L 1- ,  code>   here >r
    0015CA84 ,  600B3904 ,  350C6894 ,  34015D2B ,
    6094403C ,  3D016815 ,  C8046015 ,  46A7CA10 ,
end-code
create TX>  ( -- c )   r>  here cell- !  5010,0300 #L +  3 cells + ,  #L 1- , \ Read received char

: USB-KEY?  ( -- f )    pause  #rx ;    \ KEY & EMIT with ringbuffer
: USB-KEY   ( -- c )    begin  pause  #rx until  rx> ;
: USB-EMIT  ( c -- )    begin  pause  #L #tx - until  >tx ;

:noname \ BUS-RESET     ( -- )
    80000  5011,3050  !                     \ SIE_STATUS - BUS_RESET (Clear bit)
    false  5011,0000  !  false usb-state !  \ USB-address=0 & USB-state=0, u-config = 0
    false ep3 usb-rcv    false ep2 >pid ! ; \ Allow receiving EP3 & init. transmit EP2
  >r

:noname \ ENDPOINTS ( if0 -- if1 ) \ Handle used endpoints
    5011,0058 @
    dup 04 and if  zlp>  then   \ EP1 active?
    dup 5011,0058 !             \ Clear active flags
    80 and  or ;  >r            \ EP3 active, remember

\ : REQUESTS  ( -- )
\    5011,0098 @ >r ( ints )
\    r@    10 and if  endpoints        then   \    10 = dm 04 bitmask
\    r@  1000 and if  bus-reset        then   \  1000 = dm 12 bitmask
\    r> 10000 and if  handle-requests  then ; \ 10000 = dm 16 bitmask
create REQUESTS
    5011,0098 ,  ( endp ) r> ,  ( bus-rst ) r> ,  ' handle-req ,
code>
    6824CA10 ,  42AC2510 ,  6812D102 ,
    46A7CA10 ,  42AC022D ,  6852D102 ,  46A7CA10 ,
    42AC012D ,  6892D102 ,  46A7CA10 ,  CA10C804 ,
    FFFF46A7 ,  end-code

:noname \ START-USB     ( -- )
    1000000  4000C000           \ Bit-24 mask & Reset register
    2dup **bis  2dup **bic      \ Restart USB
    begin  2dup 8 + bit** until \ Wait until USB is ready
    2drop 5010,0000 1000 0 fill \ Erase USB ram
    0000,0009  5011,0074  !     \ USB_USB_MUXING    Softcon, to PHY
    0000,000C  5011,0078  !     \ USB_USB_PWR       VBUS overide & detect enable
    0000,0001  5011,0040  !     \ USB_MAIN_CTRl     Enable controller
    2000,0000  5011,004C  !     \ USB_SIE_CONTROL   Enable End Point 0 interrupt
    false      5011,0000  !     \ Respond to address 0 on initial setup
    0001,1010  5011,0090  !     \ USB_INTE          Enable 3 interrupts
    AC00,0180  5010,0008  !     \ init COMM endpoint in buffer 1
    A800,0200  5010,0010  !     \ init SEND endpoint in buffer 2
    A800,0280  5010,001C  !     \ init RECV endpoint out buffer 3
    0001,0000  5011,204C  ! ; >r \ USB_SIE_CONTROL   Enable pull up

:noname \ USB-HANDLER       ( -- )  \ Handle USB setup & receiving of chars
    ( start-usb ) [ r> , ]  false usb-state !  false ( if )
    ['] usb-key? to 'key?
    ['] usb-key  to 'key
    ['] usb-emit to 'emit
    begin
        requests  pause
        dup if                      \ Next RX packet wanted?
            5010,009C c@ >r         \ Data bytes arrived in EP3
            #L #tx - r@ >           \ Yes, enough space in TX buffer?
            #L #rx - r@ > and if    \ And next RX packet fits too?
                ep3 >epbuf @  r@    \ Yes, fill RX buffer
                for  c@+ >rx  next
                20 us  2drop  false \ Done
                ep3 usb-rcv)        \ And allow next RX packet
            then  rdrop
        then
    again ;

:noname \ USB-TX            ( -- )
    begin  4 us usb? until  0A ms   \ Connection with driver?
    begin
        begin  pause  usb? until    \ Still connected?
        #tx if                      \ EP2 Any chars to send?
            ep2 gone? if            \ Yes, previous packet gone?
                80 us  ep2 >epbuf @ #tx 40 umin \ Packet place & size
                2dup ep2 prepare  bounds        \ Init. transmit pointers
                ?do  tx> i c!  loop             \ Place data in EP2-buffer
                ep2 usb-send                    \ Send to host
            then
        then
    again ;  >r >r

task: USB1      task: USB2      \ The USB tasks
v: extra definitions
: USB-ON            ( -- )
    ( ['] usb-handler ) [ r> ] literal  usb1 start-task
    ( ['] usb-tx )      [ r> ] literal  usb2 start-task ;

' usb-on  to &config \ Fill configuration vector
v: fresh
shield CDC\  \ freeze
here swap - dm .
%%


chapter CDC0\
hex
(* USB driver used Leon's & Alex Taradov's code & RP2040 datasheet for documentation
    Henny Luijkx made the overview of Alex's code ( ~4412 bytes + 648 for tasker )
    Willem Jager, Leon Konings & Henny Luijkx did test and document this effort

0000 = R/W, 1000=XOR, 2000=SET, 3000=CLEAR
https://www.beyondlogic.org/usbnutshell/usb1.shtml

This version USB-XSD-008 is a CDC driver that works with Linux & Windows
using a 1 millisec. line delay and on macOS using character handshake.
*)

here
need TASK
need SPINLOCK

v: inside also definitions \ USB device data structures
here >r     \ Device descriptor (18 bytes)
12 c,  1 c,  10 c, 1 c, ( 1.10 ) EF c,  2 c,  1 c,  40 c,  09 c, 12 c,
26 c, B1 c,  0 c, 1 c, ( vsn 1.00 )  0 c,  2 c,  0 c,  1 c,  ( noForth PID? )
here >r     \ Configuration descriptor (9 or 75 bytes, dual 9 or 141? )
9 c,  2 c,  8D c,  0 c,  4 c,  1 c,  0 c,  80 c,  FA c,  \ Maximum power = 500mA (4B+CDC1)
\ CDC 0 = 66 bytes
8 c,  0B c,  0 c,  2 c,  2 c,  2 c,  0 c,  0 c,         \ Interface Association Descriptor
9 c,  4 c,  0 c,  0 c,  1 c,  2 c,  2 c,  0 c,  4 c,    \ Interface 1: Control
5 c,  24 c,  0 c,  10 c,  1 c, ( CDC vsn 1.10 )         \ CDC Header functional
5 c,  24 c,  1 c,  0 c,  1 c, ( 2 )                     \ CDC Call management functional
4 c,  24 c,  2 c,  6 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  6 c,  0 c,  1 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  81 c,  3 c,  8 c,  0 c,  10 c,              \ Endpoint 1 IN descriptor
9 c,  4 c,  1 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  82 c,  2 c,  40 c,  0 c,  0 c,              \ Endpoint 2 IN descriptor
7 c,  5 c,  03 c,  2 c,  40 c,  0 c,  0 c, ( align )    \ Endpoint 3 OUT descriptor
\ CDC 1 = 66 bytes
8 c,  0B c,  2 c,  2 c,  2 c,  2 c,  1 c,  0 c,         \ Interface Association Descriptor
9 c,  4 c,  2 c,  0 c,  1 c,  2 c,  2 c,  1 c,  0 c,    \ Interface 1: Control
5 c,  24 c,  0 c,  10 c,  1 c, ( CDC vsn 1.10 )         \ CDC Header functional
4 c,  24 c,  2 c,  6 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  1 c,  0 c,  1 c,                           \ CDC Call management functional
5 c,  24 c,  6 c,  2 c,  3 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  84 c,  3 c,  8 c,  0 c,  10 c,              \ Endpoint 4 IN descriptor
9 c,  4 c,  3 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  85 c,  2 c,  40 c,  0 c,  0 c,              \ Endpoint 5 IN descriptor
7 c,  5 c,  06 c,  2 c,  40 c,  0 c,  0 c, ( align )    \ Endpoint 6 OUT descriptor
here r@ - .  align

5010,0480 constant USB-STATE    \ USB status of both CDC-interfaces
create USB-DATA   0 ,           \ Hold current USB config. data
                                \ Second half word for 900/880 requests
    4 c, 3 c, 9 c, 4 c,         \ English/US = language ID
    dm 115200 ,  0 c,  0 c,  8 c,  align  \ Line data: 115k2, Stop bits, Parity, Data bits

\ Name:    CNT  ORG  PKT  PID   INBUF-CTRL    OUTBUF-CTRL   EPxBUF
\ Offsets: 00   04   08   0C        10            14          18
create EP0   4 cells allot    5010,0080  dup ,   4 + ,     5010,0100 ,
create EP1   4 cells allot    5010,0088  dup ,   4 + ,     5010,0180 , \ CDC 0
create EP2   4 cells allot    5010,0090  dup ,   4 + ,     5010,0200 ,
create EP3   4 cells allot    5010,0098  dup ,   4 + ,     5010,0280 ,
create EP4   4 cells allot    5010,00A0  dup ,   4 + ,     5010,0300 , \ CDC 1
create EP5   4 cells allot    5010,00A8  dup ,   4 + ,     5010,0380 ,
create EP6   4 cells allot    5010,00B0  dup ,   4 + ,     5010,0400 ,

(* High level code for documentation
: 2+        ( n1 -- n2 )            2 + ;
: >UNI      ( a1 u -- a2 )      \ Convert string to unicode format for USB
    dup  2* 302 + fp h!  0      \ String length & notifier
    ?do  c@+  fp i 2* + 2+ h!  loop  drop  fp ;
: >CNT      ; immediate     \ 00 - ep0 >cnt !
: >ORG      cell+ ;         \ 04 - ep1 >org @
: >PKT      2 cells + ;     \ 08
: >PID      3 cells + ;     \ 0C
: >ICTRL    4 cells + ;     \ 10
: >OCTRL    5 cells + ;     \ 14
: >BUF      6 cells + ;     \ 18
: EP-IN     ( ep -- org buf pkt )   >r  r@ >org @   r@ >buf @   r> >pkt @ ;
: PREPARE   ( a u ep -- )           >r  dup r@ >cnt !  40 min r@ >pkt !  r> >org ! ;
: >NEXT     ( ep -- pkt )           >r  r@ >pkt @   r@ >org @  +  r@ >org !
                                    r@ >pkt @  r@ @  over -  dup r@ !  40 min r> >pkt ! ;
: !PKT      ( pkt ep -- ictrl )     >r  r@ >pid @ or  8000 or   \ pid + pkt + mask
                                    r> >ictrl @  tuck ! ;
: USB-RECEIVE   ( ep -- )           >r r@ >octrl @   r@ >pid @  40 or  over !
                                    2000 r> >pid **bix  400 swap **bis ;
: GONE?     ( ep -- f )             >ictrl @ @ 400 and 0= ;
: USB1?     ( -- +n )               usb-state h@ ;
: USB2?     ( -- +n )               usb-state 2+ h@ ;
*)

create >UNI ( a1 u1 -- a2 )     \ Convert string to unicode format for USB (32)
    adr fp ,  300 ,  code>
    6824CA30 ,  C9208025 ,  782F2202 ,  52A73501 ,
    3B013202 ,  7022D1F9 ,  C8040023 ,  46A7CA10 ,  end-code
code >PID       C804330C ,  46A7CA10 ,  end-code
code >BUF       C8043318 ,  46A7CA10 ,  end-code
code EP-IN      699D685C ,  3904689B ,  3904600C ,  C804600D ,  46A7CA10 ,  end-code
code PREPARE    601DC920 ,  D9002D40 ,  609D2540 ,
                605DC920 ,  C804C908 ,  46A7CA10 ,  end-code
code >NEXT      685D689C ,  605D192D ,  1B2D681D ,
                2D40601D ,  2540D900 ,  0023609D ,  CA10C804 ,  FFFF46A7 ,  end-code
code !PKT       C92068DC ,  2580432C ,  432C022D ,
                601C691B ,  CA10C804 ,  FFFF46A7 ,  end-code
code USB-RECEIVE  68DD695C ,  43352640 ,
                26206025 ,  68DF0236 ,  60DF4077 ,  1362640 ,
                60254335 ,  C804C908 ,  46A7CA10 ,  end-code
code GONE?      681B3310 ,  2404681B ,  40230224 ,
                419B3B01 ,  CA10C804 ,  FFFF46A7 ,  end-code
code 2+         C8043302 ,  46A7CA10 ,  end-code
create USB0?    usb-state ,  code> here >r  39046812 ,  8813600B ,  D0002B03 ,  C8042300 ,  46A7CA10 ,  end-code
create USB1?    r> here cell- !  usb-state 2+ ,

\ Basic receive & transmit packet handlers
: USB-SEND   ( ep -- )      >r  r@ >next  r@ !pkt  2000 r> >pid **bix  400 swap **bix ;
: USB-RCV    ( pid ep -- )  tuck >pid !  usb-receive ;

: SETUP>        ( a u -- )      \ Handle the answer for all setup packages
    2000 ep0 >pid !  ep0 prepare                \ Start with DATA1, setup packet data
    begin
        ep0 ep-in move  ep0 usb-send            \ Send setup packet
        1 5011,0058                             \ Packet gone?
        begin   pause  2dup bit** until  **bis
    ep0 @ 0= until  2000 ep0 usb-rcv ;          \ Handle ZLP

\ : XTABLE        ( req a +n -- )        \ USB execution table handler (148)
\    >r r@ for  2dup @ = if              \ Token found?
\            nip  rdrop  r> cells +      \ Yes, calc. cell with XT
\            @ execute  exit             \ Fetch & execute XT
\        then
\        cell+
\    next  rdrop  2drop                  \ No token found
\    1 5011,0068 !  800 5010,0080 ! ;    \ Send EP0 stall
create XTABLE   ( req a +n -- ) \ USB execution table handler (72)
    50110068 ,  50100080 ,
code>
    001FC930 ,  6826009B ,  D10442B5 ,
    C90818E4 ,  CA106822 ,  340446A7 ,
    D1F43F01 ,  2301CAC0 ,  23086033 ,
    603B021B ,  C804C908 ,  46A7CA10 ,
end-code

: @VAL      ( -- +n )       5010,0002 h@ ; \ wValue
: @LEN      ( -- +n )       5010,0006 h@ ; \ wLength
: $DESCR>   ( a u -- )      1D min >uni  dup c@ @len min setup> ; \ Send string descriptors
: ZLP>      ( -- )          here false setup> ;     \ Send EP0 ZLP
:noname     ramborder 428 + c@+ $descr> ;           \ 0304 Device-1 name string
:noname     me count $descr> ;                      \ 0302 Device-0 name string
:noname     usb-data cell+ 4 setup> ;               \ 0300 Lang-ID string
:noname     [ r> ] literal  @len 8D min setup> ;    \ 0200 CONF-DESCR>
:noname     [ r> ] literal  12 @len min setup> ;    \ 0100 DEV-DESCR>
create SETUP-REQ    ( req -- )
    0100 ,     0200 ,      0300 ,     0302 ,     0304 ,
    ( dev ) ,  ( conf ) ,  ( lang ) , ( name ) , ( name2 ) ,
does>   ( req a -- )    5 xtable ;

' cold                                      \ 2321 Break, restart noForth t
:noname     @val 50100004 c@ usb-state + c! \ 2221 Set control line state
            zlp>  0 yours  4 yours ;        \ Free RX & TX ringbuffers
:noname     usb-data cell+ cell+ 7 setup> ; \ 21A1 Get line coding
:noname     2000 ep0 usb-rcv  zlp> ;        \ 2021 Set line coding
:noname     zlp>  @val usb-data h! ;        \ 0900 Set USB configuration
:noname     usb-data 2 setup> ;             \ 0880 Get USB configuration
:noname     @val setup-req ;                \ 0680 Basic usb SETUP handler
:noname     zlp>  @val 5011,0000 ! ;        \ 0500 Set device address
create HANDLE-REQ   ( -- )
    0500 ,  0680 ,  0880 ,  0900 ,  2021 ,  21A1 ,  2221 ,  2321 ,
    ,       ,       ,       ,       ,       ,       ,       ,
does>   ( a -- )        20000 5011,3050 !  5010,0000 h@  swap  8 xtable ;

\ Ring buffers for safe character I/O
        100  constant #L        \ Must be factor of two
\ 5010,0480  constant USB-STATE \ Both driver statuses
\ 5010,0484  constant EMPTY     \ Now free space
\ 5010,0488  constant BUFFERS   \ Usess #L + 12 bytes * 4

create #RX0 ( -- +n )   \ Chars in RX buffer (20)
    5010,0488 ,  here >r  code>  600B3904 ,  681BCA08 ,  CA10C804 ,  FFFF46A7 ,  end-code
create #TX0 ( -- +n )   r@  here cell- !  5010,0488  #L 3 cells +  1 * + , \ Chars in TX buffer
create #RX1 ( -- +n )   r@  here cell- !  5010,0488  #L 3 cells +  2 * + , \ Chars in RX1 buffer
create #TX1 ( -- +n )   r>  here cell- !  5010,0488  #L 3 cells +  3 * + , \ Chars in TX1 buffer

create >RX0 ( c -- )    \ Save char. in RX buffer
    5010,0488 ,  #L 1- ,  code>   here >r
    0015CA84 ,  350C6854 ,  3401552B ,  6054403C ,
    35016815 ,  C9086015 ,  CA10C804 ,  FFFF46A7 ,
end-code
create >TX0 ( c -- )   r@  here cell- !  5010,0488 #L 3 cells +  1 * + ,  #L 1- , \ Save char to send
create >RX1 ( c -- )   r>  here cell- !  5010,0488 #L 3 cells +  2 * + ,  #L 1- , \ Save char to receive1
\ create >TX1 ( c -- )   r>  here cell- !  5010,0488 #L 3 cells +  3 * + ,  #L 1- , \ Save char to send1

create RX0> ( -- c )    \ Read char from RX buffer
    5010,0488 ,  #L 1- ,  code>   here >r
    0015CA84 ,  600B3904 ,  350C6894 ,  34015D2B ,
    6094403C ,  3D016815 ,  C8046015 ,  46A7CA10 ,
end-code
create TX0> ( -- c )   r@  here cell- !  5010,0488 #L 3 cells +  1 * + ,  #L 1- , \ Read received char
\ create RX1> ( -- c )   r@  here cell- !  5010,0488 #L 3 cells +  2 * + ,  #L 1- , \ Read received char
create TX1> ( -- c )   r>  here cell- !  5010,0488 #L 3 cells +  3 * + ,  #L 1- , \ Read received char

: USB-KEY?  ( -- f )    pause  #rx0 ;    \ KEY & EMIT with ringbuffer
: USB-KEY   ( -- c )    begin  pause  #rx0 until  rx0> ;
: USB-EMIT  ( c -- )    begin  pause  #L #tx0 - until  >tx0 ;

:noname \ BUS-RESET     ( -- )
    80000  5011,3050  !                     \ SIE_STATUS - BUS_RESET (Clear bit)
    false  5011,0000  !  false usb-state !  \ USB-address=0 & USB-state=0
    false ep3 usb-rcv    false ep2 >pid !   \ Allow receiving EP3 & init. transmit EP2
    false ep6 usb-rcv    false ep5 >pid ! ; \ Allow receiving EP6 & init. transmit EP5

:noname \ ENDPOINTS ( if0 -- if1 ) \ Handle used endpoints
    5011,0058 @
    dup 04 and if  zlp>  then   \ EP1 active?
    dup 5011,0058 !             \ Clear active flags
    2080 and  or ;  2>r         \ EP3 and/or EP6 active, remember

\ : REQUESTS  ( if0 -- if1 )
\    5011,0098 @ >r ( ints )
\    r@    10 and if  endpoints        then   \    10 = dm 04 bitmask
\    r@  1000 and if  bus-reset        then   \  1000 = dm 12 bitmask
\    r> 10000 and if  handle-requests  then ; \ 10000 = dm 16 bitmask
create REQUESTS
    5011,0098 ,  ( ' endpoints ) r> ,  ( ' bus-reset ) r> ,  ' handle-req ,
code>
    6824CA10 ,  42AC2510 ,  6812D102 ,
    46A7CA10 ,  42AC022D ,  6852D102 ,  46A7CA10 ,
    42AC012D ,  6892D102 ,  46A7CA10 ,  CA10C804 ,
    FFFF46A7 ,  end-code

:noname \ USB-TX1           ( -- )
    begin  4 us  usb1? until  0A ms
    begin
        begin  pause  usb1? until   \ Connected?
        #tx1 if                     \ EP5 Any chars to send?
            ep5 gone? if            \ Yes, previous packet gone?
                40 us  4 mine? if                   \ TX1 buffer free to use
                    ep5 >buf @  #tx1  40 umin       \ Packet place & size
                    2dup ep5 prepare  bounds        \ Init. transmit pointers
                    ?do  tx1> i c! loop  4 yours    \ Place data in EP5-buffer
                    ep5 usb-send                    \ Send data to host
                then
            then
        then
    again ;  >r

:noname \ USB-TX0           ( -- )
    begin  4 us  usb0? until  0A ms
    begin
        begin  pause  usb0? until   \ Connected?
        #tx0 if                     \ EP2 Any chars to send?
            ep2 gone? if            \ Yes, previous packet gone?
                40 us  ep2 >buf @  #tx0 40 umin \ Packet place & size
                2dup ep2 prepare  bounds        \ Init. transmit pointers
                ?do  tx0> i c!  loop            \ Place data in EP2-buffer
                ep2 usb-send                    \ Send data to host
            then
        then
    again ;  >r

:noname \ USB-RX            ( if0 -- if1 )  \ Restart RX after a delayed reception
    dup 80 and if                   \ Delayed reception active?
        5010,009C c@ >r             \ Data bytes arrived in EP3
        #L #tx0 - r@ >              \ Yes, enough space in TX buffer?
        #L #rx0 - r@ >  and if      \ And next RX packet fits too?
            ep3 >buf @  r@          \ Yes, fill RX0 buffer
            for  c@+ >rx0  next
            10 us  drop  80 xor     \ Done
            ep3 usb-receive         \ And allow next RX0 packet
        then  rdrop
    then
    dup 2000 and if                 \ Delayed reception active?
        5010,00B4 c@ >r             \ Data bytes arrived in EP6
        #L #tx1 - r@ >              \ Enough space in TX1 buffer?
        #L #rx1 - r@ >  and if      \ And next RX1 packet fits too?
            0 mine? if              \ Available?
                ep6 >buf @  r@      \ Yes, fill RX1 buffer
                for  c@+ >rx1  next drop
                0 yours  8 us  2000 xor \ Done
                ep6 usb-receive     \ Allow next RX1 packet
            then
        then  rdrop
    then ;  >r

:noname \ START-USB     ( -- )
    1000000  4000C000           \ Bit-24 mask & Reset register
    2dup **bis  2dup **bic      \ Restart USB
    begin  2dup 8 + bit** until \ Wait until USB is ready
    2drop 5010,0000 1000 false fill \ Erase USB ram
    0000,0009  5011,0074  !     \ USB_USB_MUXING    Softcon, to PHY
    0000,000C  5011,0078  !     \ USB_USB_PWR       VBUS overide & detect enable
    0000,0001  5011,0040  !     \ USB_MAIN_CTRl     Enable controller
    2000,0000  5011,004C  !     \ USB_SIE_CONTROL   Enable End Point 0 interrupt
    false      5011,0000  !     \ Respond to address 0 on initial setup
    0001,1010  5011,0090  !     \ USB_INTE          Enable 3 interrupts
\ CDC 0
    AC00,0180  5010,0008  !     \ init COMM endpoint in buffer 1
    A800,0200  5010,0010  !     \ init SEND endpoint in buffer 2
    A800,0280  5010,001C  !     \ init RECV endpoint out buffer 3
\ CDC 1
    AC00,0300  5010,0020  !     \ init COMM endpoint in buffer 4
    A800,0380  5010,0028  !     \ init SEND endpoint in buffer 5
    A800,0400  5010,0034  !     \ init RECV endpoint out buffer 6

    0001,0000  5011,204C  ! ;  >r  \ USB_SIE_CONTROL   Enable pull up

:noname \ HANDLE-USB        ( -- )  \ Handle USB setup & transceiving of chars
    ( start-usb ) [ r> compile, ]  false usb-state !  false  ( if )
    ['] usb-key? to 'key?
    ['] usb-key  to 'key
    ['] usb-emit to 'emit
    begin
        requests  pause  ( usb-rx ) [ r> compile, ]
    again ;  >r

task: USB1      task: USB2    task: USB3    \ The USB tasks
v: extra definitions
: USB-ON            ( -- )
    0 yours  4 yours            \ Free access to RX & TX ringbuffers
    ( ['] handle-usb ) [ r> ] literal  usb1 start-task
    ( ['] usb-tx0 )    [ r> ] literal  usb2 start-task
    ( ['] usb-tx1 )    [ r> ] literal  usb3 start-task ;

' usb-on   to &config   \ Fill additional configuration vector
v: fresh
shield CDC0\  \ freeze
here swap - dm .
%%

chapter CDC1\
hex  here
NEED SPINLOCK
v: inside also  definitions
\ Ring buffers for safe character I/O
  100       constant #L         \ Must be factor of two

create #RX1 ( -- +n )                                           \ Chars in RX buffer (20)
    5010,0488  #L 3 cells +  2 * + ,  here >r
code>  600B3904 ,  681BCA08 ,  CA10C804 ,  FFFF46A7 ,  end-code
create #TX1 ( -- +n )   r>  here cell- !                        \ Chars in TX1 buffer
    5010,0488  #L 3 cells +  3 * + ,

create >TX1 ( c -- )   5010,0488 #L 3 cells +  3 * + ,  #L 1- , \ Store char to send
code>
    0015CA84 ,  350C6854 ,  3401552B ,  6054403C ,
    35016815 ,  C9086015 ,  CA10C804 ,  FFFF46A7 ,
end-code
create RX1> ( -- c )   5010,0488 #L 3 cells +  2 * + ,  #L 1- , \ Read received char
code>
    0015CA84 ,  600B3904 ,  350C6894 ,  34015D2B ,
    6094403C ,  3D016815 ,  C8046015 ,  46A7CA10 ,
end-code

v: extra definitions
: USB-KEY?  ( -- f )    pause  #rx1 ;   \ Data in receive buffer

: USB-KEY   ( -- c )
    begin  pause  #rx1 until    \ Waiting for data in receive buffer
    begin  pause  0 mine? until \ Waiting for access to be granted?
    rx1>  0 yours ;             \ Read key and free receive buffer

: USB-EMIT  ( c -- )
    begin  pause  #L #tx1 - until   \ Waiting for space in send buffer
    begin  pause  4 mine? until     \ Waiting for access to be granted?
    >tx1  4 yours ;                 \ Put char in ring buffer en free transmit buffee

: USB-ON    ( -- )
    begin  pause  #tx1 0= until  20 ms \ Start with empty ringbuffers
    ['] usb-key? to 'key?
    ['] usb-key  to 'key
    ['] usb-emit to 'emit ;

' usb-on   to &config   \ Fill additional configuration vector
v: fresh
shield CDC1\  \ freeze
here swap - dm .
%%


chapter HARDFAULT
\ Replace hard fault handler, 460 bytes
\ To extend the functionality of the one built-in noForth t
\ r0  r1  r2  r3  r12  lr  pc  xPSR
\ IP  SP  W   TOS DOES LR  PC  xPSR
\
\ Array that holdS: PC, IP, TOS & RP at the moment a fault had occurred
\ create FAULT-ADR  -1 , -1 , -1 , -1 ,

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
    drop >r  type  ." address: " r> u. ;         \                               -

: .FAULT ( i*x -- )     \ Search backward for the header using the saved data
    fault-adr @+  s" in " .name              \ PC
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
%%


v: inside
libhere 1-  to hardware)
v: fresh


\ Example of a hardware library, about 96 kBytes

chapter CORE\
hex
(* Let core-1 on RP2040 run it's own code

Primitives for activating CORE-1 from CORE-0

\ PSM_BASE = 40010000 ( Power-on State Machine )
40010000 = FRC_OFF
40010004 = FRC_OFF
40010008 = WDSEL
4001000C = DONE

\ Watchdog reset = 40058000
00 = CTRL
04 = LOAD
2C = TICK

\ SIO base = D0000000
50 = FIFO status register
54 = FIFO write
58 = FIFO read

: RESET0    ( -- )          \ Reset core 0  (48 bytes)
    8000 40010008 **bis     \ Allow a WD reset of core-0
    1F bitmask 40058000 **bis ; \ Force reset
: RESET1    ( -- )          \ Reset core 1  (48 bytes)
    10000 40010008 **bis    \ Allow a WD reset of core-1
    1F bitmask 40058000 **bis ; \ Force WD reset

When a WFE instruction is executed the current drops about
0,2mA to 2,5mA depending on the used PLL frequency!

*)

need asm\

hex
v: extra definitions
\ Reset core-1
create RESET1 ( -- )    \ 26 bytes
    40010008 ,          \ Watchdog reset select
    40058000 ,          \ Watchdog control
    00010000 ,          \ Reset core-1 pattern
code>
    w  { hop day sun } ldm, \ Read pool
    sun  hop ) str,     \ Store core-1 reset
    sun 0F # lsls,      \ Make & activate force reset bit
    sun  day ) str,
    next,
end-code

\ : FTX?          ( -- f )    2 D000,0050 bit** 0<> ;
\ : FRX?          ( -- f )    1 D000,0050 bit** 0<> ;
create FRX?     ( -- f )
    D000,0050 ,
code>
    day 1 # movs,       \ 1 - Fifo RX? bit
    tos sp -) str,      \ 3 - Save TOS
    w  w ) ldr,         \ 2 - Read addr. fifo status to W
    tos w ) ldr,        \ 2 - Read fifo status to TOS
    tos day ands,       \ 2 - Test it
    =? no if,           \ 2 - Not zero?
        tos day day subs.mv, \ 1+1 - Build true flag
        tos tos mvns,
    then,
    next,               \ 6
end-code
create FTX?     ( -- f )
    D000,0050 ,
code>
    day 2 # movs,       \ Fifo TX? bit
    ' frx? @ 2 + 77 again,
end-code

v: extra definitions
\ Send data to core-1
create FIFO!    ( x -- )
    D0000050 ,          \ FIFO status register
code>
    w  w ) ldr,
    sun 2 # movs,
    begin,
        hop  w ) ldr,   \ Read status
        hop sun ands,
    =? no until,        \ Space for TX
    tos  w 4 #) str,
    sev,                \ Set event
    sp { tos } ldm,
    next,
end-code

\ Read data from core-1
create FIFO@    ( -- x )
    D0000050 ,          \ FIFO status register
code>
    w  w ) ldr,
    begin,
        hop  w ) ldr,   \ Read status
        sun 1 # movs,
        hop sun ands,
    =? while,           \ Received on RX
        wfe,            \ Wait for event
    repeat,
    tos  sp -) str,
    tos  w 8 #) ldr,    \ Read FIFO
    next,
end-code

: EMPTY-FIFO        ( -- )  \ Empty incoming FIFO completely
    begin  frx? while  fifo@ drop  repeat ;

v: inside also definitions
\ Send & verify a command to core-1 in one word
: >CMD?         ( cmd -- f )    dup fifo!  fifo@ = ;

v: extra definitions
\ Start assembly code routine on core-1
\ Core-1 access sequence: 0, 0, 1, vectortable, sp, pc
: BOOT1         ( code-addr -- )
    1 or  reset1            \ Set thumb bit & reset core-1
    begin  begin  begin  begin  begin  begin
        empty-fifo          \ Clear incoming FIFO
    0 >cmd? until           \ Start with access sequence, succeed?
    0 >cmd? until           \ Second step, succeed?
    1 >cmd? until           \ Third step, succeed?
    21000000 >cmd? until    \ Sent interrupt table for core-1, succeed?
    tib/ 100 + >cmd? until  \ Sent stack pointer for core-1, succeed?
    dup >cmd? until  drop ; \ Sent core-1 PC address, succeed?

v: fresh
shield CORE\
%%

chapter CORE1\
( gpio -- )
need [if]
need asm\
need core\

depth 0= [if]  dm 25  [then]  >r ( save GPIOxx )

hex
\ Setting up a simple LED flasher for CORE-1
\ Using only CPU registers and one I/O-pin
\ More info on SIO_BASE from address 42 ff.
code BLINKER    ( -- )
(data
    4000F000 ,              \ Reset IO-bank to HOP ( RESETS_BASE )
    40014000 r@ 8 * 4 + + , \ Assign GPIOxx to DAY ( GPIOxx_CTRL )
    D0000000 ,              \ SIO base to SUN ( SIO_BASE )
    01000000 ,              \ Delay value
data)
    w  { hop day sun } ldm,
    moon 20 # movs,         \ Release IO-bank
    moon  hop ) str,
    moon 5 # movs,          \ GPIO25 = SIO
    moon  day ) str,
    moon 1 # movs,          \ Set bit xx
    moon r> # lsls,
    moon  sun 24 #) str,    \ Enable GPIOxx output ( GPIO_OE_SET )
    begin,
        moon  sun 14 #) str,    \ LED on  ( GPIO_OUT_SET )
        day  w ) ldr,           \ Read delay
        begin,  day 1 # subs, =? until,
        moon  sun 18 #) str,    \ LED off ( GPIO_OUT_CLR )
        day  w ) ldr,           \ Read delay
        begin,  day 1 # subs, =? until,
    again,
end-code

: FLASH     ( -- )      ['] blinker >body  boot1 ;

' flash to app
shield CORE1\
%%

chapter CORE0
\ Demo-1a: a counter over two cores
: CORE0         ( -- )      \ Count on core-0 using two cores
    empty-fifo  1 fifo!
    begin
        fifo@ 1+ cr dup . fifo!  50 ms
    key? until
    0 fifo!  empty-fifo ;
%%

chapter CORE1
\ Demo-1b: a counter over two cores
: CORE1         ( -- )      \ Display counter from core-0
    begin
    fifo@ ?dup while
        cr dup .  fifo!
    repeat  empty-fifo ;
%%

chapter BUTTON
\ Demo-2a: Switch a program status on the other core
\          Send the switch data to the other core
: BUTTON        ( -- )
    false  begin
    s? 0= if  invert dup fifo!  1 ms  then
        begin  s? until  10 ms
    key? until  drop  empty-fifo ;
%%

chapter RESPONSE
\ Demo-2b: Switch a program status on the other core
\          Receive switch data to change a demo program
: RESPONSE      ( -- )
    empty-fifo  0  begin
        rxf? if
            fifo@ if  cr ." I am in mode-1 "
            else      cr ." I am in mode-2 "
            then
        then
        1+ dup hx 800 = if  dup -  ch . emit  then  dm 300 us
    key? until  drop  empty-fifo ;
%%

chapter BLINK

(* Simple GPIO demo using bit input & bit output
More on SIO chapter 2.3.1 page 27 ff
More on IO user bank chapter 2.19 page 235 ff
*)
hardware  need BOOTKEY?

hex
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value
: BLINK     ( -- )                  \ 1 Hz flashing led
    5 dm 25 gpio!                   \ Enable SIO on pin 25
    dm 25 bitmask GPIO-OE **bis     \ Bit is output
    begin
        dm 25 bitmask GPIO-OUT **bix  200 ms \ Toggle LED
    bootkey? until                  \ Until the boot key was pressed
    dm 25 bitmask GPIO-OUT **bic ;  \ LED off
%%

chapter ADC
hex \ More on ADC in chapter 4.9 at page 559 ff
4004C000 constant ADC-CS            \ ADC Control and Status
4004C004 constant ADC-RESULT        \ Result of most recent ADC conversion

: ADC           ( +n -- u )
    4 umin >r  3 adc-cs !           \ Enable ADC and temperature sensor
    r@ 4 < if                       \ Normal GPIO?
        80 r@ dm 26 + pads!         \ Yes, disable digital-IO
    then
    begin  100 adc-cs bit** until   \ Wait for READY flag
    r> 0C lshift  7 or adc-cs !     \ Start conversion on channel +n
    begin  100 adc-cs bit** until   \ Wait for READY flag
    adc-result @ ;                  \ Fetch conversion result
%%

chapter BOOTKEY?
\ Reuse BOOTSEL switch for noForth t input
\ More on SIO chapter 2.3.1 page 27 ff
\ More on IO QSPI bank chapter 2.19.2 page 236/287 ff
hex
: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us  \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=         \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;       \ QSPI pin-SS peripheral function again
%%


chapter TEMPERATURE
\ Use the built-in temperature sensor
\ Celsius conversion routine built by Albert Nijhof
\ More on ADC in chapter 4.9 at page 559 ff
hardware  need ADC
hex
dm 180   value #CAL                 \ Calibration value, chip dependent

: TEMPERATURE)  ( -- u )
    3 adc-cs !                      \ Enable ADC and temperature sensor
    begin  100 adc-cs bit** until   \ Wait for READY flag
    4007 adc-cs !                   \ Start conversion on channel 4, temperature sensor
    begin  100 adc-cs bit** until   \ Wait for READY flag
    adc-result @ ;                  \ Fetch conversion result

\ s - in milliVolts
\ c - in hundredths of degrees Celsius
: CELSIUS ( s -- c )
    dm 373 dm 100 */ dm 5333 - negate \ Convert measurement to Celsius
    #cal + ; \ Add chip dependent correction value!

: .TEMPERATURE  ( -- )
    base @ >r  decimal              \ Show in decimal
    temperature) dup .  celsius     \ Show raw voltage & convert temperature
    0 <# # # ch , hold #s #> type   \ Print out
    BA emit  ." C "  r> base ! ;

: CALIBRATE     ( celsius*100 -- )
    0 to #cal  cr ." Before " .temperature  20 ms \ Uncalibrated temperature
    temperature) celsius -  to #cal        \ Celsius*100 - measured temperature = #CAL
    20 ms  cr ." After  " .temperature ;   \ Calibrated temperature

: TEMPERATURE   ( -- )
    begin  cr .temperature  100 ms  key? until ;
%%

chapter PWM-ON
( GPIO -- ) \ PWM is chapter 4.5 from page 524 ff

need [if]

depth 0= [if]  abort  [then] \ Not enough data!
dup 2 mod 0=  over dm 30 <  and [if]
hex     \ PWM base pin 0, 2, 4, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28
( Pin number )                  constant GPIOA      \ PWM base pin 16, etc.
dm 999                          constant PWM#       \ PWM wrap value
gpioa 0F and 2/  14 *  40050000 + constant PWM-CSR  \ PWM control register
pwm-csr 0C +                    constant PWM-PULSE  \ PWM pulsewidth register
pwm-csr 10 +                    constant PWM-TOP    \ PWM wrap register

: PWMA      ( +n -- )   \ Set PWM of first output
    pwm# umin  FFFF0000 pwm-pulse bit**  or  pwm-pulse ! ;

: PWMB      ( +n -- )   \ Set PWM of second output
    pwm# umin  10 lshift  FFFF pwm-pulse bit**  or  pwm-pulse ! ;

: PWM-ON    ( -- )      \ Activate on of the eight PWM units
    4 gpioa gpio!       \ GPIO-A & B = PWM
    4 gpioa 1+ gpio!
    03 pwm-csr !        \ Enable phase correct PWM, both not inverted
    pwm# pwm-top !      \ PWM range (125000000/999+1)/2 = 62.5kHz
    dm 125 pwma         \ Set default PWM values, 25% & 50%
    dm 500 pwmb ;
[else]
    cr .( Invalid port number, valid are 2 to 28: )  dm .
[then]
%%

chapter ALARM
\ Defining word that supports all four alarm registers
\ Usage examples, interval = microseconds
\ dm 10000 0 alarm ZERO  \ Define alarm-0 goes off each 10000 µs
\ dm 8000  3 alarm THREE \ Define alarm-3 goes off each 8000 µs
\ Example: zero ch A and emit  three ch B and emit  many

hex
40054010 constant ALARM0    \ 00 04 08 0C   Four alarm cells
40054020 constant ARMED     \ 01 02 04 08   Four armed flags
40054028 constant TIMERAWL  \ Low part of 64-bits timer
: ALARM     ( interval alarm -- ) \ Define timer using the alarm function
    create                      \ (interval = microseconds)
        swap ,  3 umin          \ Alarm interval
        dup cells  alarm0 + ,   \ Used alarm
        bitmask ,               \ Bit masker
    does>   ( -- f )
        dup 2 cells + @         \ Read bit mask
        armed bit** 0= dup if   \ Alarm not enabled or triggered?
            drop  @+ timerawl @ +   \ Ok, calc. next alarm time,
            swap @ !  true  true    \ set it and leave true
        then  nip ;             \ Remove data address
%%

chapter KHZ>
hex \ Convert spi-clock to divider values
v: inside also definitions
: KHZ>          ( khz -- div1 div2 )
    0 cfg 2 + h@ dm 1,000 *  swap /             \ Calculate divisor
    dup FF < if  7E and  0000  exit  then       \ 254 or smaller
    dup 6000 < if  19 /  1800  exit  then       \ 6000 or smaller
    dup dm 64770 < if  FA /  F900  exit  then   \ 64770 or smaller
    ?abort ;    \ Unable to calculate divider settings!
v: fresh
%%

chapter LOOPBACK
need [undefined]
need [if]

v: inside
[undefined] 'spi [if]           \ No SPI driver loaded
    hardware  dm 16 0 need spi\ \ Load driver for GPIO16 and SPI-0
[then]
v: extra definitions  inside
: LOOPBACK  ( f -- )        \ Loopback mode for spi-0 on/off
    'spi >r  1 and  r@ @ 0E and or r> ! ;
v: fresh
%%

chapter SPI\
( gpio 0|1 -- )
(* spi-0 or spi-1 driver
  Examples:
  dm 1000 spi0-on  true loopback
  44 spi0-i/o .  many
  : T1  -1  begin  1+  dup spi0-i/o drop  key? until  drop ;

  4003C000 = SPI0
  40040000 = SPI1
*)

hex
need [if]

depth 2 < [if]  abort  [then] \ Not enough data!
v: inside

hardware  need KHZ>
hex  v: inside also  definitions
0= [if]
    dup 0 =  over 4 = or  over dm 16 = or [if]
                 constant RX0
        4003C000 constant 'SPI
    [else]
        cr .( Wrong GPIO for SPI-0 valid are 0,4,16: )  dm .  abort
    [then]
[else]
    dup 8 =  over dm 12 = or [if]
                 constant RX0
        40040000 constant 'SPI
    [else]
        cr .( Wrong GPIO for SPI-1 valid are 8,12: )  dm .  abort
    [then]
[then]

hex  v: extra definitions
'spi 4003C000 = [if]

\ SPI-0 on selected GPIO a to b = rx, sck, tx
: SPI0-ON       ( khz -- )
    1 rx0 2dup  gpio!       \ GPIOa to GPIOc for SPI0
\   2dup 1+     gpio!       \ We control CS ourselfs
    2dup 2 +    gpio!
         3 +    gpio!
    khz>  0007 or  'spi !   \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic      \ SSPCR1    Disable SSE
    2 'spi cell+ !          \ SSPCR1    Synchronous master
    'spi 10 + ! ;           \ SSPCPSR   clock prescaler

: SPI0-I/O      ( b1 -- b2 )
    'spi 8 + >r
    begin  2 r@ cell+ bit** until  r@ !
    begin  4 r@ cell+ bit** until  r> @ ;

: SPI0-OUT      ( b -- )        spi0-i/o drop ;
: SPI0-IN       ( -- b )        0 spi0-i/o ;

[else]

\ SPI-1 on selected GPIO a to b = rx, sck, tx
: SPI1-ON       ( khz -- )
    1 rx0 2dup  gpio!       \ GPIOa to GPIOc for SPI0
\   2dup 1+     gpio!       \ We control CS ourselfs
    2dup 2 +    gpio!
         3 +    gpio!
    khz>  0007 or  'spi !   \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic      \ SSPCR1    Disable SSE
    2 'spi cell+ !          \ SSPCR1    Synchronous master
    'spi 10 + ! ;           \ SSPCPSR   clock prescaler

: SPI1-I/O      ( b1 -- b2 )
    'spi 8 + >r
    begin  2 r@ cell+ bit** 0= until  r@ !
    begin  4 r@ cell+ bit** 0= until  r> @ ;

: SPI1-OUT      ( b -- )        spi1-i/o drop ;
: SPI1-IN       ( -- b )        0 spi1-i/o ;

[then]

v: fresh
shield SPI\
%%

chapter I2C\
( clock sda-pin -- ) \ Built-in I2C on all speeds
(* This I2C example is connected to GPIO12 & GPIO13 for I2C0 and
   to GPIO14 & GPIO15 for I2C1. I2C is chapter 4.3 from page 440 ff.
   Look at Project Forth Works for a detailed description
   https://forth-ev.de/wiki/en:pfw:i2c

    SDA0: 00,04,08,12,16,20
    SDA1: 02,06,10,14,18,26

    Use: Clock pin need I2C
          100   4  need I2C

*)

need [if]
need -literal

depth 2 < [if]  abort  [then] \ Not enough data!

hex
v: inside also  definitions
dup dm 20 > [if]  drop  dm 14  [then] ( Default GPIO14 in case of an error )
( gpio )    constant SDA
sda 1+      constant SCL
( clock )   constant CLK

cr .( Clock ) clk dm .  .( kHz, SDA ) sda dm .  .( SCL ) scl dm .

sda 2/ 1 and [if]   \ I2C1
40048000 constant 'I2C      \ I2C1_BASE     I2C register pointer
[else]
40044000 constant 'I2C      \ I2C0_BASE     I2C register pointer
[then]
0 value SUM                 \ Count of bytes to transmit or receive

: 'I2C   ( öffset" -- )      'i2c  -literal ; immediate

: BUS?          ( -- )
    10 us  'i2c 70 @ 2 = ?abort ; \ Abort on not connected bus

: DATA!         ( +n -- )       \ Send data +n
    -1 +to sum  sum 0= 200 and  \ Decrease byte count, Last byte, add
    or  'i2c 10 ! ;             \ stop condition & send

v: extra definitions        \ I2C basic primitive set
: DEVICE!       ( dev -- )
    1  'i2c 6C **bic        \ Disable I2C
    7F and 400 or 'i2c 4 !  \ Set TARget address
    1  'i2c 6C **bis ;      \ Enable I2C

: I2C-ON        ( -- )
    03 sda gpio! 03 scl gpio! \ I2C0 on GPIO12 & GPIO13
    4A sda pads! 4A scl pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    1  'i2c 6C **bic        \ Disable I2C
[ clk dm 50 = ] [if]
    dm 1100  'i2c 1C !      \ Set high & low clock period (~50kHz)
    dm 1300  'i2c 20 !
[else]
[ clk dm 200 = ] [if]
    dm 240  'i2c 1C !       \ Set high & low clock period (~200kHz)
    dm 294  'i2c 20 !
[else]
[ clk dm 400 = ] [if]
    dm 075  'i2c 1C !       \ Set high & low clock period (~400kHz)
    dm 163  'i2c 20 !       \ Fast mode plus 1MHz clock these are: hi=33, low=63
[else]
[ clk dm 1000 = ] [if]
    dm 033  'i2c 1C !       \ Set high & low clock period (~400kHz)
    dm 063  'i2c 20 !       \ Fast mode plus 1MHz clock these are: hi=33, low=63
[else]
    dm 500  'i2c 1C !       \ Set high & low clock period (~100kHz)
    dm 588  'i2c 20 !
[then] [then] [then] [then]
    dm 12   'i2c A0 !       \ Spike suppressing to 100 ns (7 for high speed)
    0065    'i2c 0 !        \ 7-bit master, fast speed, restart & slave off
\   0067    'i2c 0 !        \ 7-bit master, high speed, restart & slave off
    1  'i2c 6C **bis ;      \ Enable I2C

: I2C@          ( -- +n )       'i2c 70 @ ; \ Read I2C status register
: {I2C-WRITE    ( +n -- )       to sum  begin i2c@ 6 = until ; \ Bus free?
: {I2C-READ     ( +n -- )       {i2c-write ;

: BUS!          ( b -- )
    FF and  data!                   \ Send data byte b
    begin   bus?  i2c@
            6  sum if 21 + then     \ Bus ready status or busy status
    = until ;                       \ Ok

: BUS@          ( -- b )
    100 data!                       \ Send dummy byte
    begin   'i2c 2C @  50 = ?abort  \ Abort on invalid read
            bus?  i2c@
            0E  sum if 21 + then    \ Bus ready or busy
    = until                         \ Wait until data is received
    'i2c 10 @  FF and ;             \ Read & mask returned data b

: I2C}          ( -- ) ; immediate  \ Dummy i2c ending

: {DEVICE-OK?}  ( -- f )            \ leave true when address matched a device
    1 {i2c-read  100 data!  true    \ Start dummy read data with stop condition
    begin
        drop  'i2c 2C @ dup 14 =    \ Device present & ready (ACK)?
        over 50 =  or               \ Device not present or busy (NACK)?
    until  14 <>                    \ Device not present?
    if    false  'i2c 54            \ Yes, get abort address
    else  true   'i2c 10            \ Data register
    then  @ drop ;                  \ Dummy read on data or abort register

cr .( I2C basis loaded )

( A set of additional I2C primitives. Waiting for an EEPROM )
( write to succeed is named acknowledge polling with timeout )
: {POLL}        ( -- )
    100  begin
    1- dup while                \ Decrease timeout counter until zero
    {device-ok?} until          \ Not zero, check Ack?
    then  0= ?abort ;           \ Abort when zero

: {I2C-OUT      ( dev +n -- )   swap  device!  {i2c-write ;
: {I2C-IN       ( dev +n -- )   swap  device!  {i2c-read ;
: BUS!}         ( b -- )        bus!  i2c} ;
: BUS@}         ( -- b )        bus@  i2c} ;
: BUS-MOVE      ( a u -- )      for  c@+ bus!  next  drop ; \ Send string of bytes

v: fresh
shield I2C\

cr .( With I2C extensions too )
%%


chapter I2C-SLAVE\
( pin -- )  \ SDA-pin for I2C slave primitives, SCL = SDA+1
(* I2C slave implementation, base: 468 bytes, plus examples: 740 bytes

40044000 I2C0_BASE
40048000 I2C1_BASE

I2C is chapter 4.3 from page 440 ff.
I2C registers from page  465 ff.

00  = IC_CON            Control Register, slave=84, master=65
04  = IC_TAR            Target Address Register
08  = IC_SAR            Slave Address Register
10  = IC_DATA_CMD       Rx/Tx Data Buffer and Command Register
1C  = IC_FS_SCL_HCNT    Fast Mode or Fast Mode Plus I2C Clock
20  = IC_FS_SCL_LCNT
2C  = IC_INTR_STAT      IC_FS_SCL_HCNT
54  = IC_CLR_TX_ABRT    Clear TX abort flag by reading
6C  = IC_ENABLE         Enable Register
70  = IC_STATUS         Status Register
A0  = IC_FS_SPKLEN      Spike suppression (byte)


: COUNTER       ( -- )      \ I2C slave demo
    cr  i2c-on  0  begin
        30 pcf8574> if
            dup .  dup 30 >pcf8574  1+
        else  ." ."  then  20 ms
    key? until  drop ;

*)

need [if]
need -literal

depth 0= [if]  abort  [then] \ Not enough data

hex
v: inside also  definitions
dup dm 20 > [if]  drop  dm 12  [then] ( Default GPIO12 in case of an error )
( gpio )    constant SDA
sda 1+      constant SCL
cr .( SDA ) sda dm .  .( SCL ) scl dm .

sda 2/ 1 and [if]           \ I2C1?
40048000 constant 'I2C      \ I2C1_BASE     I2C register pointer
[else]
40044000 constant 'I2C      \ I2C0_BASE     I2C register pointer
[then]

: 'I2C   ( öffset" -- )      'i2c  -literal ; immediate

: DEVICE-ON     ( mode my-addr -- )
    03 sda gpio! 03 scl gpio! \ I2Cn on GPIOx & GPIOy
    4A sda pads! 4A scl pads! \ Set GPIOx=SDA & GPIOy=SCL with pull up
    1  'i2c 6C **bic    \ Disable I2C
       'i2c 08 !        \ Set SAR (slave) address
       'i2c 00 !        \ Set I2C mode for this device
    1  'i2c 6C **bis ;  \ Enable I2C

: RESET-FLAGS   ( -- )
    'i2c 50             \ Clear interrupt registers base
    @+ drop  @ drop ;   \ Clear read request & TX abort

: I2C-READ?     ( -- 0|x )  20 'i2c 2C bit** ;  \ I2C read request?
: I2C-WRITE?    ( -- 0|x )  08 'i2c 70 bit** ;  \ I2C write request?
: I2C-DATA      ( -- a )    'i2c 10 ;           \ I2C data register

shield I2C-SLAVE\
%%


chapter IO-SLAVE
\ Counter (I2C PCF8574 style slave driver)
hardware  need bootkey?
need [undefined]
need [if]

[undefined] i2c-slave\ [if]  \ Add default I2C slave when not defined yet
    hardware  dm 12 need i2c-slave\
[then]

: IO-SLAVE      ( -- )          \ Send & receive I2C data on MY address
    84 30 device-on  cr         \ I2C slave on addr. 30 active
    begin
        i2c-read? if                    \ Read request?
            bootkey? FF and  i2c-data ! \ Yes , send data
            50 us  reset-flags          \ wait and clear interrupts
        then
        i2c-write? if                   \ Data received?
            i2c-data @  FF and  3 .r    \ Yes, read data & show it
        then
     key? until  65 30 device-on ;      \ I2C slave off
%%

chapter COUNTER
\ I2C slave demo (master code part)

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
     hardware  dm 100 dm 14  need i2c\
[then]

need >pcf8574

: COUNTER       ( -- )      \ I2C slave demo
    cr  i2c-on  0  begin
        30 pcf8574> if
            dup .  dup 30 >pcf8574  1+
        else  ." ."  then  20 ms
    key? until  drop ;
%%


chapter MDMP
\ I2C slave demo (master code part)

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100 dm 14  need i2c\
[then]

v: inside also definitions
: {MADDR        ( ma +n -- )    \ Address buffer
    30 device!  {i2c-write  bus! ;                      \ -addr.

v: extra definitions
\ Byte wide fetch and store in buffer
: NMC@          ( -- b )        1 {i2c-read  bus@ i2c} ; \ Buffer Read next byte
: MC@           ( ma -- b )     1 {maddr i2c}  nmc@ ;    \ Buffer Read byte from address
: MC!           ( b ma -- )     2 {maddr  bus! i2c} ;    \ Buffer Store byte at address
: MC@+          ( ma -- ma+ x ) dup 1+  swap mc@ ;       \ Buffer version of COUNT
: MFILL         ( ea u b -- )   rot rot for  2dup mc!  1+  next  2drop ;

: MDMP          ( ma -- )
    hex  i2c-on  begin
        cr  dup 4 u.r ." : "
        dup   10 for  mc@+ 2 .r space  next  ch | emit  \ Show hex
        drop  10 for  mc@+ pchar emit  next             \ Show Ascii
    key bl <> until  drop ;
v: fresh
%%

chapter MEM-SLAVE
need [undefined]
need [if]

[undefined] i2c-slave\ [if]  \ Add default I2C slave when not defined yet
    hardware  dm 12  need i2c-slave\
[then]

v: inside also definitions
create RAM  100 allot       \ Data buffer
0 value MEM                 \ Pointer

v: extra definitions
: MEM-SLAVE ( -- )                  \ Store & read I2C data on device address
    84 30 device-on  ." on " cr     \ I2C memory slave on address 30 active
    begin
        i2c-read? if                        \ Read request from me?
            mem c@ i2c-data !               \ Yes, read buffer & send data
            incr mem  reset-flags           \ Increase addr. & clear interrupts
        then
        i2c-write? if                       \ Handle first write request?
            i2c-data @ FF and  ram + to mem \ Yes, set memory buffer address

            begin   i2c-write?
                    i2c-read? or until      \ Read or write request received?

            i2c-write? if                   \ Is it another write request?
                i2c-data @  mem c!          \ Yes, fetch data & store in buffer
            then
        then
     key? until  65 30 device-on            \ I2C slave off

v: fresh
%%


chapter >PCF8574
\ PCF8574 driver primitives: >PCF8574 PCF8574>

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100 dm 14  need i2c\
[then]

v: extra definitions
: >PCF8574      ( b dev -- )    device!  1 {i2c-write  bus!} ;
: PCF8574>      ( dev -- b )    device!  1 {i2c-read   bus@} ;
%%


chapter RUNNER
\ A few pcf8574 demo drivers: BLINK RUNNER KEYS etc.

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100 dm 14  need i2c\
[then]
hardware  need >pcf8574

v: extra definitions
: >LEDS         ( b -- )        invert 21 >pcf8574 ;
: INPUT         ( -- b )        20 pcf8574>  FF xor ;
: BLINK         ( -- )          true >leds 100 ms  false >leds 100 ms ;

v: fresh
: RUNNER        ( -- )      \ Show a running light on leds
    i2c-on
    begin
        input 0= if         \ Nothing pressed?
            blink           \ Yes, flash LEDs
        else                \ No, running light
            8 0 do
                i bitmask >leds  input 2* ms
            loop
        then
    key? until  0 >leds ;

: KEYS          ( -- )      \ Show key press on leds
    i2c-on  blink  begin  input >leds  key? until  0 >leds ;
%%

chapter 24C02\
\ Small eeprom code example

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100 dm 14  need i2c\
[then]

v: extra definitions
: {EEADDR       ( ea +n -- )    \ Address EEPROM
    52 device!  {i2c-write  bus! ;                      \ 24C02 EE-addr.

\ Byte wide fetch and store in EEPROM
: NEC@          ( -- b )        1 {i2c-read  bus@ i2c} ;    \ EE Read next byte
: EC@           ( ea -- b )     1 {eeaddr i2c}  nec@ ;      \ EE Read byte from address
: EC!           ( b ea -- )     2 {eeaddr  bus! i2c} {poll} ; \ EE Store byte at address
: EC@+          ( ea -- ea+ x ) dup 1+  swap ec@ ;          \ EE version of COUNT

\ Cell wide read and store operators for 24Cxxx EEPROM
: E@            ( ea -- x )      ec@  nec@  b+b ;       \ EE Read word from address
: E@+           ( ea1 -- ea2 x ) dup 2 +  swap e@ ;     \ EE Read word with auto increase
: E!            ( x ea -- )      >r  b-b r@ 1+ ec!  r> ec! ; \ EE Store word at address
: E+!           ( n ea -- )      >r  r@ e@ +  r> e! ;   \ EE Increase contents of address with n

\ Example: A forth style memory interface with tools
  i2c-on
  0100 constant EESIZE         \ 24C02

\ First cell in EEPROM is used as EHERE, this way it is always up to date
\ We have to take care manually of the forget action on this address pointer
\ Note that EHERE is initialised at address 2 right behind itself!!
0 constant EDP  2 edp e!    \ Define and initialise EHERE
: EHERE         ( -- ea )   edp e@ ;                \ EE dictionary pointer
: EALLOT        ( +n -- )   eesize over ehere + u< throw  edp e+! ; \ EE reserve memory
: EC,           ( b -- )    ehere  1 eallot  ec! ;  \ EE compile byte
: E,            ( x -- )    ehere  2 eallot  e! ;   \ EE 16-bits compile word
: ECREATE       ( -- ea )   ehere  constant ;       \ EE named memory
: EVARIABLE     ( -- ea )   ecreate  2 eallot ;     \ EE 16-bits variable
: EFILL         ( ea u b -- )   rot rot for  2dup ec!  1+  next  2drop ;

v: forth definitions
: EDMP          ( ea -- )
    hex  i2c-on  begin
        cr  dup 4 u.r ." : "
        dup   10 for  ec@+ 2 .r space  next  ch | emit  \ Show hex
        drop  10 for  ec@+ pchar emit  next             \ Show Ascii
    key bl <> until  drop ;

v: extra definitions
: EM,           ( a u -- )  \ This version is more carefull on EEPROM wear
    dup 0 ?do  over i + c@  ehere i + ec!  loop \ EE compile the string a,n
    nip  edp e+! ;                              \ Increase EDP

: ETYPE         ( ea u -- ) \ EE type string
    for  ec@+ emit  next  drop ;
shield 24C02\
%%

chapter EEPROM
hardware  need 24c02\     \ An eeprom code example
hardware  need runner     \ I/O example

v: extra definitions
ecreate STRING  ( -- ea )       \ Store named string in EEPROM
s" Forth"  dup ec, em,

\ Show stored string from EEPROM
v: fresh  inside
: EEPROM        ( -- )
    i2c-on
    begin
        cr ." Project "
        string ec@+ etype
        ."  Works"  blink
    key? until ;
v: forth
%%

chapter DEV?
\ Check if a device is present on the I2C-bus

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100 dm 14  need i2c\
[then]

v: extra definitions
: DEV?          ( dev -- )
    i2c-on  device!  {device-ok?}
    0= if  ." not "  then  ." present " ;
%%

chapter SCAN-I2C
need [undefined]  \ an i2c bus scanner
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100 dm 14  need i2c\
[then]
need .byte

v: inside also definitions
\ I2C bus scanner, after the original sample implementation by J. J. Hoekstra
\ : .BYTE         ( byte -- )         0 <# # # #> type space ;

: .I2C-HEADER   ( -- )
    cr  8 spaces  10 0 do  i 2 .r space  loop ;

: .I2C-ROW      ( dev -- )
    cr  4 spaces  .byte  8 emit  ." : " ;

: .I2C-DEVICE   ( dev -- )
    dup device!  {device-ok?} if  .byte exit  then  drop ." -- " ;

: FIRST-LINE    ( -- )
    0 .i2c-row ." gc cb db fp hs hs hs hs "
    10 8 do  i .i2c-device  loop ;

: LAST-LINE     ( -- )
    70 .i2c-row   78 70 do  i .i2c-device  loop
    ." sw sw sw sw ?? ?? ?? ??" ;

v: forth definitions
: SCAN-I2C      ( -- )      \ Scan for all valid I2C bus addresses
    i2c-on  base @ >r  hex
    .i2c-header  first-line
    7 1 do
        i 10 *  dup .i2c-row
        10 bounds do  i .i2c-device  loop
    loop
    last-line  r> base ! cr ;

v: fresh
%%

chapter PCF8591\
\ I2C analog input & output using a PCF8591
\
\ Note that: 48 = PCF8591 I2C-bus device address 0
\
\ Connections on module YL-40 e.g. at AliExpress:
\  0 ADC - AIN0 = LDR
\  1 ADC - AIN1 = Thermistor
\  2 ADC - AIN2 = Free
\  3 ADC - AIN3 = Potmeter
\  DAC is connected to an output and a green led

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100  dm 14  need i2c\
[then]

hex
v: extra definitions
\ This flag is set when DAC was used. Set to zero
\ when DAC has to be off during ADC conversions!
0 value DAC?  ( -- vlag )   \ Keep DAC active if true

\ Read ADC input '+n', 'u' is the result of the conversion.
: ADC       ( +n -- u )
    4A device!              \ Select ADC
    3 and                   \ Select 1 of four inputs
    dac? 40 and  or         \ (De)activate DAC & add input
    1 {i2c-write  bus! i2c} \ Send address & control byte
    2 {i2c-read  bus@ drop  bus@ i2c} ; \ Get fresh ADC reading

\ Set DAC-output the a value that matches 'u'.
: DAC       ( u -- )
    4A device!              \ Select ADC
    true to dac?            \ DAC active
    1 {i2c-write  bus! i2c} ; \ Send address & control byte


\ Example program
v: fresh
: ANALOG    ( +n -- )       \ Show the use off ADC/DAC
    i2c-on  >r              \ Initialise I2C
    true to dac?            \ DAC is used
    begin
        r@ adc  dup .       \ Read ADC input +n, show result
        invert dac          \ Store inverted to DAC
    key? until  r> drop ;

shield PCF8591\
%%

chapter LM75\

(* I2C temperature measuring temperature with LM75CIM
  AUTHOR      : Willem Ouwerkerk, November 25, 1999
  LAST CHANGE : Willem Ouwerkerk, july 4, 2023, 484/984 bytes
  Added compensation value for the LM75 named #CAL
  Uses a special character 'BA' that displays the degrees sign
*)

need [undefined]
need [if]

[undefined] i2c\ [if]  \ Add default I2C master when not defined yet
    hardware  dm 100  dm 14  need i2c\
[then]

hex
v: inside also  definitions
dm 37 value #CAL    \ Correction value in half degrees please adjust!
: {REGISTER     ( reg +n -- )   4C device!  7 and {i2c-write bus! ; \ Select reg.

: @REG8         ( reg -- b )    \ Read 8-bit register
    1 {register i2c}  1 {i2c-read  bus@ i2c} ;
: @REG16        ( reg -- x )    \ Read 16-bit register
    1 {register i2c}  2 {i2c-read  bus@ bus@ i2c} swap b+b ;
: !REG16        ( t reg -- )    \ Store 16-bit temperature register
    3 {register bus! bus! i2c} ;

v: extra definitions
\ Temperature is given in half degrees for each bit, where zero
\ is 0 degrees celcius, the range goes from -55 tot 125 degrees.
: TEMPERATURE   ( -- n )            \ Read corrected temperature
    0 @reg16  dup 0F rshift         \ Shift 15 bits to right
    if  true  FFFF xor  or  then    \ Convert sign to systems word width
    7 arshift  #cal + ;             \ And adjust for differences

\ The temperature T needs to be given in whole degrees here
: CONFIGURATION ( b  -- )       1 1 {register i2c} ; \ Set LM75 configuration
: >TEMP         ( t -- tl th )  b-b swap ; \ Convert temperature to two bytes
: LOW-LIMIT     ( t -- )        >temp 2 !reg16 ; \ Set thermostat low boundary
: HIGH-LIMIT    ( t -- )        >temp 3 !reg16 ; \ Set thermostat high boundary

\ i2c-on \ Activate I2C
\ Example programs
\ Show temperature in whole degrees celcius
: .CELCIUS1         ( n -- )
    base @ >r  decimal  2/ 3 .r  BA emit ." C "  r> base ! ;

\ Needs Celsius times ten on the stack to calculate the calibration value
: CALIBRATE         ( celcius*10 -- )
    5 /  0 to #cal  temperature drop
    temperature dup cr ." before" .celcius1
    - to #cal cr ." after " temperature .celcius1 ;

: TEMPERATURE1      ( -- )
    i2c-on
    begin
        cr temperature .celcius1  100 ms
    key? until ;

\ Show temperature in half degrees celsius
: .CELCIUS2         ( n -- )
    base @ >r  decimal
    5 * s>d <# # ch . hold #s #> type  BA emit ." C "
    r> base ! ;

: TEMPERATURE2      ( -- )
    i2c-on
    begin
        cr temperature .celcius2  100 ms
    key? until ;

v: fresh
shield LM75\  ( LM75 demo )
%%

chapter WS2812
\ Control two WS2812 LEDs on GPIO23 & GPIO28 separately
hex
: WS2812    ( -- )
    0000 50200000 !
    1F000 502000CC !
    14000000 502000DC !
    258000 502000C8 !
    24007380 502000DC !
    0006 400140E4 !
    40000 502000D0 !
    E081 50200048 !
    A0E6 5020004C !
    6028 50200050 !
    A027 50200054 !
    0020 50200058 !
    A0C7 5020005C !
    0000 50200060 !
    0027 50200058 !
    E03F 50200064 !
    A0C1 50200068 !
    0009 50200060 !
    E057 5020006C !
    6021 50200070 !
    1020 50200074 !
    1000 50200078 !
    102D 50200074 !
    A021 5020007C !
    100E 50200078 !
    008A 50200080 !
    EF3F 50200084 !
    A0E1 50200088 !
    602C 5020008C !
    A027 50200090 !
    0F53 50200094 !
    0001 50200098 !
    0000 502000D8 !
    1F000 502000E4 !
    14000000 502000F4 !
    258000 502000E0 !
    1F000 502000E4 !
    40000 502000E8 !
    24005EE0 502000F4 !
    0006 400140BC !
    0000 502000F0 !

    1 50200000 !    \ sm-0 on
    400 ms
    3 50200000 ! ;  \ sm-0 & sm-1 on
%%

chapter WS2812START\
hardware  need WS2812
' ws2812  to app
shield WS2812START\
%%

chapter WS2812MULTI\
hardware  need WS2812
need task

\ Self starting dual WS2812 PIO driver
task: one
: START     ( -- )      ['] ws2812  one  start-task ;
' start     to app
shield WS2812MULTI\
%%

chapter ||
v: inside also definitions
: ||    ( bitrow -- )        \ Read & compile 16-bit character row
    0  0D parse  10 min bounds
    ?do  2*  i c@ ch X =  -  loop  h, ;
v: fresh
%%


chapter |
hex v: inside also definitions
: |     ( bitrow -- )        \ Read & compile 8-bit character row
    0  0D parse  8 umin bounds
    do  2*  i c@ ch X =  -  loop  c, ;
v: fresh
%%


chapter 'GRAPH
v: inside
hardware  need |

v: inside also  definitions
create 'GRAPH   \ Graphic characters 4 x 8 pixels
| ........    \ B0 - 0
| ........
| ........
| ........

| XXXXXXXX    \ B1 - 1
| XXXXXXXX
| XXXXXXXX
| XXXXXXXX

| ......XX    \ B2 - 2
| ......XX
| ........
| ........

| ........    \ B3 - 3
| ........
| ......XX
| ......XX

| XX......    \ B4 - 4
| XX......
| ........
| ........

| ........    \ B5 - 5
| ........
| XX......
| XX......

| ......XX    \ B6 - 6
| ......XX
| ......XX
| ......XX

| XX......    \ B7 - 7
| XX......
| XX......
| XX......

| ..XXXXXX    \ B8 - 8
| ..XXXXXX
| ........
| ........

| ........    \ B9 - 9
| ........
| ..XXXXXX
| ..XXXXXX

| XXXXXX..    \ B10 - :
| XXXXXX..
| ........
| ........

| ........    \ B11 - ;
| ........
| XXXXXX..
| XXXXXX..

| XXXXXXXX    \ B12 - <
| XXXXXXXX
| ........
| ........

| ........    \ B13 - =
| ........
| XXXXXXXX
| XXXXXXXX

| ....XXXX    \ B14 - >
| ....XXXX
| ....XXXX
| ....XXXX

| XXXX....    \ B15 - ?
| XXXX....
| XXXX....
| XXXX....

| ..XXXXXX    \ B16 - @
| ..XXXXXX
| ..XXXXXX
| ..XXXXXX

| XXXXXX..    \ B17 - A
| XXXXXX..
| XXXXXX..
| XXXXXX..

| ......XX    \ B18 - B
| .......X
| ........
| ........

| ........    \ B19 - C
| ........
| .......X
| ......XX

| XX......    \ B20 - D
| X.......
| ........
| ........

| ........    \ B21 - E
| ........
| X.......
| XX......

| ....XXXX    \ B22 - F
| .....XXX
| ......XX
| .......X

| .......X    \ B23 - G
| ......XX
| .....XXX
| ....XXXX

| XXXX....    \ B24 - H
| XXX.....
| XX......
| X.......

| X.......    \ B25 - I
| XX......
| XXX.....
| XXXX....

| ..XXXXXX    \ B26 - J
| ...XXXXX
| ....XXXX
| .....XXX

| .....XXX    \ B27 - K
| ....XXXX
| ...XXXXX
| ..XXXXXX

| XXXXXX..    \ B28 - L
| XXXXX...
| XXXX....
| XXX.....

| XXX.....    \ B29 - M
| XXXX....
| XXXXX...
| XXXXXX..

| XXXXXXXX    \ B30 - N
| .XXXXXXX
| ..XXXXXX
| ...XXXXX

| ...XXXXX    \ B31 - O
| ..XXXXXX
| .XXXXXXX
| XXXXXXXX

| XXXXXXXX    \ B32 - P
| XXXXXXX.
| XXXXXX..
| XXXXX...

| XXXXX...    \ B33 - Q
| XXXXXX..
| XXXXXXX.
| XXXXXXXX

| X.....XX    \ B34 - R
| XX....XX
| XXX..XXX
| XXXXXXXX

| XXXXXXXX    \ B35 - S
| XXX..XXX
| XX....XX
| X......X

| XXXXXXXX    \ B36 - T
| .XXXXXX.
| ..XXXX..
| ...XX...

| ...XX...    \ B37 - U
| ..XXXX..
| .XXXXXX.
| XXXXXXXX

| ...XX...    \ B38 - V
| ........
| ........
| ........

| ........    \ B39 - W
| ........
| ........
| ...XX...

| XXXX....    \ B40 - X
| .XXX....
| ..XX....
| ...X....

| ...X....    \ B41 - Y
| ..XX....
| .XXX....
| XXXX....

| ....XXXX    \ B42 - Z
| ....XXX.
| ....XX..
| ....X...

| ....X...    \ B43 - [
| ....XX..
| ....XXX.
| ....XXXX

| ........    \ B44 - \
| ...XX...
| ...XX...
| ........

| ....XXXX    \ B45 - ]
| ....XXXX
| ........
| ........

| ........    \ B46 - ^
| ........
| ....XXXX
| ....XXXX

| XXXX....    \ B47 - _
| XXXX....
| ........
| ........

| ........    \ B48 - `
| ........
| XXXX....
| XXXX....

| ..XX....    \ B49 - a
| ..XX....
| ....XX..
| ....XX..

| ....XX..    \ B50 - b
| ....XX..
| ..XX....
| ..XX....

| XX......    \ B51 - c
| XX......
| ..XX....
| ..XX....

| ..XX....    \ B52 - d
| ..XX....
| XX......
| XX......

| ....XX..    \ B53 - e
| ....XX..
| ......XX
| ......XX

| ......XX    \ B54 - f
| ......XX
| ....XX..
| ....XX..

| ....XX..    \ B55 - g
| ....XX..
| ....XX..
| ....XX..

| ..XX....    \ B56 - h
| ..XX....
| ..XX....
| ..XX....

| XX....XX    \ B57 - i
| XX....XX
| XX....XX
| XX....XX

| ....XXXX    \ B58 - j
| ....XXXX
| ......XX
| ......XX

| ......XX    \ B59 - k
| ......XX
| ....XXXX
| ....XXXX

| XXXX....    \ B60 - l
| XXXX....
| XX......
| XX......

| XX......    \ B61 - m
| XX......
| XXXX....
| XXXX....

| ......XX    \ B62 - n
| ......XX
| XX......
| XX......

| XX......    \ B63 - o
| XX......
| ......XX
| ......XX
align
v: fresh
%%


chapter 'SMALL
v: inside
hardware  need |

v: inside also  definitions \ Small characters of 5x8 bits
create 'SMALL
| ........      \ Special tokens-1
| ........
| ........
| ........
| ........

| ........
| ........
| .X..XXXX
| ........
| ........

| ........
| .....XXX
| ........
| .....XXX
| ........

| ...X.X..
| .XXXXXXX
| ...X.X..
| .XXXXXXX
| ...X.X..

| ..X..X..
| ..X.X.X.
| .XXXXXXX
| ..X.X.X.
| ...X..X.

| ..X...XX
| ...X..XX
| ....X...
| .XX..X..
| .XX...X.

| ..XX.XX.
| .X..X..X
| .X.X.X.X
| ..X...X.
| .X.X....

| ........
| ........
| .....X.X
| ......XX
| ........

| ........
| ...XXX..
| ..X...X.
| .X.....X
| ........

| ........
| .X.....X
| ..X...X.
| ...XXX..
| ........

| ...X.X..
| ....X...
| ..XXXXX.
| ....X...
| ...X.X..

| ....X...
| ....X...
| ..XXXXX.
| ....X...
| ....X...

| ........
| ........
| .X.X....
| ..XX....
| ........

| ....X...
| ....X...
| ....X...
| ....X...
| ....X...

| ........
| ........
| .XX.....
| .XX.....
| ........

| ..X.....
| ...X....
| ....X...
| .....X..
| ......X.

| ..XXXXX.      \ Numbers & number tokens
| .X.....X
| .X..X..X
| .X.....X
| ..XXXXX.

| ........
| .X....X.
| .XXXXXXX
| .X......
| ........

| .X....X.
| .XX....X
| .X.X...X
| .X..X..X
| .X...XX.

| ..X....X
| .X.....X
| .X...X.X
| .X..X.XX
| ..XX...X

| ...XX...
| ...X.X..
| ...X..X.
| .XXXXXXX
| ...X....

| ..X..XXX
| .X...X.X
| .X...X.X
| .X...X.X
| ..XXX..X

| ..XXXX..
| .X..X.X.
| .X..X..X
| .X..X..X
| ..XX....

| .......X
| .XXX...X
| ....X..X
| .....X.X
| ......XX

| ..XX.XX.
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX.XX.

| .....XX.
| .X..X..X
| .X..X..X
| ..X.X..X
| ...XXXX.

| ........
| ........
| ..XX.XX.
| ..XX.XX.
| ........

| ........
| ........
| .X.X.XX.
| ..XX.XX.
| ........

| ........
| ....X...
| ...X.X..
| ..X...X.
| .X.....X

| ...X.X..
| ...X.X..
| ...X.X..
| ...X.X..
| ...X.X..

| ........
| .X.....X
| ..X...X.
| ...X.X..
| ....X...

| ......X.
| .......X
| .X.X...X
| ....X..X
| .....XX.

| ..XX..X.
| .X..X..X
| .XXXX..X
| .X.....X
| ..XXXXX.

| .XXXXXX.      \ Capitals
| ....X..X
| ....X..X
| ....X..X
| .XXXXXX.

| .XXXXXXX
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX.XX.

| ..XXXXX.
| .X.....X
| .X.....X
| .X.....X
| ..X...X.

| .XXXXXXX
| .X.....X
| .X.....X
| .X.....X
| ..XXXXX.

| .XXXXXXX
| .X..X..X
| .X..X..X
| .X..X..X
| .X.....X

| .XXXXXXX
| ....X..X
| ....X..X
| ....X..X
| .......X

| ..XXXXX.
| .X.....X
| .X..X..X
| .X..X..X
| ..XXX.X.

| .XXXXXXX
| ....X...
| ....X...
| ....X...
| .XXXXXXX

| ........
| .X.....X
| .XXXXXXX
| .X.....X
| ........

| ..XX....
| .X......
| .X.....X
| ..XXXXXX
| .......X

| .XXXXXXX
| ....X...
| ...X.X..
| ..X...X.
| .X.....X

| .XXXXXXX
| .X......
| .X......
| .X......
| .X......

| .XXXXXXX
| ......X.
| ....XX..
| ......X.
| .XXXXXXX

| .XXXXXXX
| ......X.
| .....X..
| ....X...
| .XXXXXXX

| ..XXXXX.
| .X.....X
| .X.....X
| .X.....X
| ..XXXXX.

| .XXXXXXX
| ....X..X
| ....X..X
| ....X..X
| .....XX.

| ..XXXXX.
| .X.....X
| .X.X...X
| ..X....X
| .X.XXXX.

| .XXXXXXX
| ....X..X
| ...XX..X
| ..X.X..X
| .X...XX.

| .X...XX.
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX...X

| .......X
| .......X
| .XXXXXXX
| .......X
| .......X

| ..XXXXXX
| .X......
| .X......
| .X......
| ..XXXXXX

| ...XXXXX
| ..X.....
| .X......
| ..X.....
| ...XXXXX

| ..XXXXXX
| .X......
| ..XXX...
| .X......
| ..XXXXXX

| .XX...XX
| ...X.X..
| ....X...
| ...X.X..
| .XX...XX

| .....XXX
| ....X...
| .XXX....
| ....X...
| .....XXX

| .XX....X
| .X.X...X
| .X..X..X
| .X...X.X
| .X....XX

| ........     \ Special tokens-2
| .XXXXXXX
| .X.....X
| .X.....X
| ........

| ......X.
| .....X..
| ....X...
| ...X....
| ..X.....

| ........
| .X.....X
| .X.....X
| .XXXXXXX
| ........

| .....X..
| ......X.
| .......X
| ......X.
| .....X..

| X.......
| X.......
| X.......
| X.......
| X.......

| ........
| .......X
| ......X.
| .....X..
| ........

| ..X.....     \ Lower case
| .X.X.X..
| .X.X.X..
| .X.X.X..
| .XXXX...

| .XXXXXXX
| .X..X...
| .X...X..
| .X...X..
| ..XXX...

| ..XXX...
| .X...X..
| .X...X..
| .X...X..
| ..X.....

| ..XXX...
| .X...X..
| .X...X..
| .X..X...
| .XXXXXXX

| ..XXX...
| .X.X.X..
| .X.X.X..
| .X.X.X..
| ...XX...

| ....X...
| .XXXXXX.
| ....X..X
| .......X
| ......X.

| ...XX...
| X.X..X..
| X.X..X..
| X.X..X..
| .XXXXX..

| .XXXXXXX
| ....X...
| .....X..
| .....X..
| .XXXX...

| ........
| .X...X..
| .XXXXX.X
| .X......
| ........

| .X......
| X.......
| X....X..
| .XXXXX.X
| ........

| .XXXXXXX
| ...X....
| ..X.X...
| .X...X..
| ........

| ........
| .X.....X
| .XXXXXXX
| .X......
| ........

| .XXXXX..
| .....X..
| ...XX...
| .....X..
| .XXXX...

| .XXXXX..
| ....X...
| .....X..
| .....X..
| .XXXX...

| ..XXX...
| .X...X..
| .X...X..
| .X...X..
| ..XXX...

| XXXXXX..
| ...X.X..
| ...X.X..
| ...X.X..
| ....X...

| ....X...
| ...X.X..
| ...X.X..
| ...XX...
| XXXXXX..

| .XXXXX..
| ....X...
| .....X..
| .....X..
| ....X...

| .X..X...
| .X.X.X..
| .X.X.X..
| .X.X.X..
| ..X.....

| .....X..
| ..XXXXXX
| .X...X..
| .X......
| ..X.....

| ..XXXX..
| .X......
| .X......
| ..X.....
| .XXXXX..

| ...XXX..
| ..X.....
| .X......
| ..X.....
| ...XXX..

| ..XXXX..
| .X......
| ..XX....
| .X......
| ..XXXX..

| .X...X..
| ..X.X...
| ...X....
| ..X.X...
| .X...X..

| ....XX..
| X..X....
| X..X....
| X..X....
| .XXXXX..

| .X...X..
| .XX..X..
| .X.X.X..
| .X..XX..
| .X...X..

| ........     \ Special tokens-3
| ....X...
| ..XX.XX.
| .X.....X
| ........

| ........
| ........
| XXXXXXXX
| ........
| ........

| ........
| .X.....X
| ..XX.XX.
| ....X...
| ........

| ....X...  \ 7E
| .....X..
| ....X...
| ...X....
| ....X...

| XXXXXXXX  \ 7F
| XXXXXXXX
| XXXXXXXX
| XXXXXXXX
| XXXXXXXX

| ...X.X..  \ 80 = €
| ..XXXXX.
| .X.X.X.X
| .X...X.X
| ..XX..X.

| ......XX  \ 81 = Celcius
| ..XXXX.X
| .X....X.
| .X....X.
| ..X..X..
align
v: fresh
%%


chapter 'THIN
\ Thin character set
v: inside
hardware  need ||

v: inside also definitions
create 'THIN    \ Start of a 16x6 character type, original version Albert Nijhof

|| ................
|| ................
|| ................
|| ................
|| ................
|| ................
|| ................

|| ................
|| ................
|| ...X............
|| ..XXX..XXXXXXXXX
|| ...X............
|| ................
|| ................

|| ...........X..X.
|| ............XXXX
|| ..............X.
|| ................
|| ...........X..X.
|| ............XXXX
|| ..............X.

|| .....X...X......
|| ..XXXXXXXXXXXXXX
|| ......X...X.....
|| ......X....X....
|| .......X...X....
|| ..XXXXXXXXXXXXXX
|| ........X...X...

|| .....X.....XX...
|| ....X.....X..X..
|| ...X.....X....X.
|| ..XXXXXXXXXXXXXX
|| ...X.....X....X.
|| ....X...X....X..
|| .....XXX....X...

|| .....X.....XXX..
|| ......X...X...X.
|| .......X...XXX..
|| ........X.......
|| ...XXX...X......
|| ..X...X...X.....
|| ...XXX.....X....

|| ....XXX.........
|| ...X...X....XXX.
|| ..X.....X.XX...X
|| ..X.....XX.....X
|| ..X...XX..X....X
|| ...X.......XXXX.
|| ....X...........

|| ................
|| ................
|| ...........X..X.
|| ............XXXX
|| ..............X.
|| ................
|| ................

|| ................
|| ................
|| ......XXXXXX....
|| ....XX......XX..
|| ...X..........X.
|| ..X............X
|| ................

|| ................
|| ..X............X
|| ...X..........X.
|| ....XX......XX..
|| ......XXXXXX....
|| ................
|| ................

|| ................
|| .......X...X....
|| ........X.X.....
|| .........XXXX...
|| ........X.X.....
|| .......X...X....
|| ................

|| ................
|| .......X........
|| .......X........
|| ....XXXXXXX.....
|| .......X........
|| .......X........
|| ................

|| ................
|| ................
|| X..X............
|| .XXXX...........
|| ...X............
|| ................
|| ................

|| ................
|| .......X........
|| .......X........
|| .......X........
|| .......X........
|| .......X........
|| ................

|| ................
|| ................
|| ...X............
|| ..XXX...........
|| ...X............
|| ................
|| ................

|| ..XX............
|| ....XX..........
|| ......XX........
|| ........XX......
|| ..........XX....
|| ............XX..
|| ..............XX

|| ....XXXXXXXXXX..
|| ...X..........X.
|| ..X....X.......X
|| ..X.....X......X
|| ..X......X.....X
|| ...X..........X.
|| ....XXXXXXXXXX..

|| ..X.........X...
|| ..X..........X..
|| ..X...........X.
|| ..XXXXXXXXXXXXXX
|| ..X.............
|| ..X.............
|| ..X.............

|| ..XXX........X..
|| ..X..X........X.
|| ..X...X........X
|| ..X....X.......X
|| ..X.....X......X
|| ..X......X....X.
|| ..X.......XXXX..

|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ..X............X
|| ..X......X.....X
|| ...X....X.X...X.
|| ....XXXX...XXX..

|| ......XX........
|| ......X.XX......
|| ......X...XXX...
|| ......X......XXX
|| ......X.........
|| ..XXXXXXXXXXXXXX
|| ......X.........

|| ....X.....XXXXXX
|| ...X......X....X
|| ..X.......X....X
|| ..X.......X....X
|| ..X.......X....X
|| ...X.....X.....X
|| ....XXXXX......X

|| ....XXXXXXXXXX..
|| ...X..........X.
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.......
|| ....XXXX........

|| ..XX...........X
|| ....XX.........X
|| ......XX.......X
|| ........XX.....X
|| ..........XX...X
|| ............XX.X
|| ..............XX

|| ....XXXX...XXX..
|| ...X....X.X...X.
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.X...X.
|| ....XXXX...XXX..

|| ..........XXXX..
|| .........X....X.
|| ..X.....X......X
|| ..X.....X......X
|| ..X.....X......X
|| ...X..........X.
|| ....XXXXXXXXXX..

|| ................
|| ................
|| ...X.....X......
|| ..XXX...XXX.....
|| ...X.....X......
|| ................
|| ................
|| ................
|| ................
|| X..X.....X......
|| .XXXX...XXX.....
|| ...X.....X......
|| ................
|| ................

|| .......X........
|| ......X.X.......
|| .....X...X......
|| ....X.....X.....
|| ...X.......X....
|| ..X.........X...
|| ..X.........X...

|| ................
|| .....X...X......
|| .....X...X......
|| .....X...X......
|| .....X...X......
|| .....X...X......
|| ................

|| ..X.........X...
|| ..X.........X...
|| ...X.......X....
|| ....X.....X.....
|| .....X...X......
|| ......X.X.......
|| .......X........

|| .............X..
|| ..............X.
|| ...X...........X
|| ..XXX..XX......X
|| ...X.....X.....X
|| ..........X...X.
|| ...........XXX..

|| ....XXXXXXXXXX..
|| ...X..........X.
|| ..X............X
|| ..X....XXXX....X
|| ..X...X....X...X
|| ..X...X...X...X.
|| ...X...XXXXXXX..

|| ..XXXXXXXXX.....
|| ...........XX...
|| ......X......XX.
|| ......X........X
|| ......X......XX.
|| ......X....XX...
|| ..XXXXXXXXX.....

|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.X...X.
|| ....XXXX...XXX..

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ..X............X
|| ..X............X
|| ...X..........X.

|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X............X
|| ..X............X
|| ...X..........X.
|| ....X........X..
|| .....XXXXXXXX...

|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ..X............X
|| ..X............X

|| ..XXXXXXXXXXXXXX
|| ...............X
|| .........X.....X
|| .........X.....X
|| .........X.....X
|| ...............X
|| ...............X

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ..X......X.....X
|| ...X.....X....X.
|| ....XXXXXX......

|| ..XXXXXXXXXXXXXX
|| ................
|| .........X......
|| .........X......
|| .........X......
|| .........X......
|| ..XXXXXXXXXXXXXX

|| ................
|| ..X............X
|| ..X............X
|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X............X
|| ................

|| ....X...........
|| ...X............
|| ..X............X
|| ...X...........X
|| ....XXXXXXXXXXXX
|| ...............X
|| ...............X

|| ..XXXXXXXXXXXXXX
|| ................
|| ........X.......
|| ........XX......
|| ......XX..XX....
|| ....XX......XX..
|| ..XX..........XX

|| ..XXXXXXXXXXXXXX
|| ..X.............
|| ..X.............
|| ..X.............
|| ..X.............
|| ..X.............
|| ..X.............

|| ..XXXXXXXXXXXXXX
|| ..............X.
|| .............X..
|| ...........XX...
|| .............X..
|| ..............X.
|| ..XXXXXXXXXXXXXX

|| ..XXXXXXXXXXXXXX
|| ...........X....
|| .........XX.....
|| .......XX.......
|| .....XX.........
|| ....X...........
|| ..XXXXXXXXXXXXXX

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X............X
|| ...X..........X.
|| ....X........X..
|| .....XXXXXXXX...

|| ..XXXXXXXXXXXXXX
|| ...............X
|| ........X......X
|| ........X......X
|| ........X......X
|| .........X....X.
|| ..........XXXX..

|| .....XXXXXXXX...
|| ....X........X..
|| ...X..........X.
|| ..X.XXXX.......X
|| ...X..........X.
|| ..X.X........X..
|| .X...XXXXXXXX...

|| ..XXXXXXXXXXXXXX
|| ...............X
|| ........X......X
|| .......XX......X
|| .....XX.X......X
|| ...XX....X....X.
|| ..X.......XXXX..

|| ....X......XXX..
|| ...X......X...X.
|| ..X......X.....X
|| ..X......X.....X
|| ..X......X.....X
|| ...X....X.....X.
|| ....XXXX.....X..

|| ...............X
|| ...............X
|| ...............X
|| ..XXXXXXXXXXXXXX
|| ...............X
|| ...............X
|| ...............X

|| ....XXXXXXXXXXXX
|| ...X............
|| ..X.............
|| ..X.............
|| ..X.............
|| ...X............
|| ....XXXXXXXXXXXX

|| .......XXXXXXXXX
|| .....XX.........
|| ...XX...........
|| ..X.............
|| ...XX...........
|| .....XX.........
|| .......XXXXXXXXX

|| ...XXXXXXXXXXXXX
|| ..X.............
|| ...X............
|| ....XXX.........
|| ...X............
|| ..X.............
|| ...XXXXXXXXXXXXX

|| ..XX..........XX
|| ....XX......XX..
|| ......XX..XX....
|| ........XX......
|| ......XX..XX....
|| ....XX......XX..
|| ..XX..........XX

|| ..............XX
|| ............XX..
|| ..........XX....
|| ..XXXXXXXX......
|| ..........XX....
|| ............XX..
|| ..............XX

|| ..XX...........X
|| ..X.XX.........X
|| ..X...XX.......X
|| ..X.....XX.....X
|| ..X.......XX...X
|| ..X.........XX.X
|| ..X...........XX

|| ................
|| ..XXXXXXXXXXXXXX
|| ..X............X
|| ..X............X
|| ..X............X
|| ..X............X
|| ................

|| ..............XX
|| ............XX..
|| ..........XX....
|| ........XX......
|| ......XX........
|| ....XX..........
|| ..XX............

|| ................
|| ..X............X
|| ..X............X
|| ..X............X
|| ..X............X
|| ..XXXXXXXXXXXXXX
|| ................

|| ........X.......
|| .........XX.....
|| ...........XX...
|| .............XXX
|| ...........XX...
|| .........XX.....
|| ........X.......

|| .X..............
|| .X..............
|| .X..............
|| .X..............
|| .X..............
|| .X..............
|| .X..............

|| ................
|| ................
|| ..............X.
|| ............XXXX
|| ...........X..X.
|| ................
|| ................

|| ...XX...........
|| ..X..X....X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ...X.....X......
|| ..X.XXXXX.......

|| ..XXXXXXXXXXXXXX
|| ...X............
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X.....X......
|| ....XXXXX.......

|| ....XXXXX.......
|| ...X.....X......
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X.....X......

|| ....XXXXX.......
|| ...X.....X......
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X............
|| ..XXXXXXXXXXXX..

|| ....XXXXX.......
|| ...X.....X......
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X....X..X.....
|| ........XX......

|| ..........X.....
|| ..........X.....
|| ..XXXXXXXXXXXX..
|| ..........X...X.
|| ..........X....X
|| ...............X
|| ...............X

|| .....XXXX.......
|| X...X....X......
|| X..X......X.....
|| X..X......X.....
|| X..X......X.....
|| .X.......X......
|| ..XXXXXXXXX.....

|| ..XXXXXXXXXXXXXX
|| .........X......
|| ..........X.....
|| ..........X.....
|| ..........X.....
|| .........X......
|| ..XXXXXXX.......

|| ................
|| ..X.............
|| ..X..........X..
|| ..XXXXXXXX..XXX.
|| ..X..........X..
|| ..X.............
|| ................

|| X...............
|| X...............
|| X...............
|| .X...........X..
|| ..XXXXXXXX..XXX.
|| .............X..
|| ................

|| ..XXXXXXXXXXXXXX
|| ................
|| ......X.........
|| .....X.X........
|| ....X...X.......
|| ...X.....X......
|| ..X.......X.....

|| ................
|| ................
|| ..X.............
|| ..XXXXXXXXXXXXXX
|| ..X.............
|| ................
|| ................

|| ..XXXXXXXXX.....
|| .........X......
|| ..........X.....
|| ..XXXXXXXXX.....
|| .........X......
|| ..........X.....
|| ..XXXXXXXXX.....

|| ..XXXXXXXXX.....
|| .........X......
|| ..........X.....
|| ..........X.....
|| ..........X.....
|| .........X......
|| ..XXXXXXX.......

|| ....XXXXX.......
|| ...X.....X......
|| ..X.......X.....
|| ..X.......X.....
|| ..X.......X.....
|| ...X.....X......
|| ....XXXXX.......

|| XXXXXXXXXXX.....
|| .........X......
|| ...X......X.....
|| ...X......X.....
|| ...X......X.....
|| ....X....X......
|| .....XXXX.......

|| .....XXXX.......
|| ....X....X......
|| ...X......X.....
|| ...X......X.....
|| ...X......X.....
|| ..........X.....
|| XXXXXXXXXXX.....

|| ..XXXXXXXXX.....
|| ........X.......
|| .........X......
|| ..........X.....
|| ..........X.....
|| ..........X.....
|| .........X......

|| .......XXX......
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ..X...X...X.....
|| ...XXX..........

|| ..........X.....
|| ..........X.....
|| ....XXXXXXXXXX..
|| ...X......X.....
|| ..X.......X.....
|| ..X.............
|| ..X.............

|| ....XXXXXXX.....
|| ...X............
|| ..X.............
|| ..X.............
|| ..X.............
|| ...X............
|| ..XXXXXXXXX.....

|| .....XXXXXX.....
|| ....X...........
|| ...X............
|| ..X.............
|| ...X............
|| ....X...........
|| .....XXXXXX.....

|| ...XXXXXXXX.....
|| ..X.............
|| ...X............
|| ....XX..........
|| ...X............
|| ..X.............
|| ...XXXXXXXX.....

|| ..XX.....XX.....
|| ....X...X.......
|| .....X.X........
|| ......X.........
|| .....X.X........
|| ....X...X.......
|| ..XX.....XX.....

|| X.....XXXXX.....
|| .X...X..........
|| ..X.X...........
|| ...X............
|| ....X...........
|| .....X..........
|| ......XXXXX.....

|| ..XX......X.....
|| ..X.X.....X.....
|| ..X..X....X.....
|| ..X...X...X.....
|| ..X....X..X.....
|| ..X.....X.X.....
|| ..X......XX.....

|| ................
|| .........X......
|| .........X......
|| ........X.X.....
|| ....XXXX...XXX..
|| ...X..........X.
|| ..X............X

|| ................
|| ................
|| ................
|| ..XXXXXXXXXXXXXX
|| ................
|| ................
|| ................

|| ..X............X
|| ...X..........X.
|| ....XXXX...XXX..
|| ........X.X.....
|| .........X......
|| .........X......
|| ................

|| .......X........
|| ........X.......
|| ........X.......
|| .......X........
|| ......X.........
|| ......X.........
|| .......X........

|| XXXXXXXXXXXXXXXX     \ 7F = Cursor block
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX

|| .......X..X.....     \ 80 = €
|| ....XXXXXXXXXX..
|| ...X...X......X.
|| ..X....X..X....X
|| ..X....X..X....X
|| ..X.......X....X
|| ...XX.........X.

|| ..............X.     \ 81 = Celcius
|| .....XXXXXX..X.X
|| ....X......X..X.
|| ...X........X...
|| ..X..........X..
|| ..X..........X..
|| ...X........X...

align
v: fresh
%%

chapter 'BOLD
\ Bold character set
v: inside
hardware  need ||

v: inside also  definitions
create 'BOLD   \ Bold characters 16X8 pixels by J.J. Hoekstra
|| ................    \ BL
|| ................
|| ................
|| ................
|| ................
|| ................
|| ................
|| ................

|| ................    \ !
|| ................
|| ................
|| ..XX.XXXXXXXXXXX
|| ..XX.XXXXXXXXXXX
|| ................
|| ................
|| ................

|| ................    \ "
|| .............XXX
|| .............XXX
|| ................
|| ................
|| .............XXX
|| .............XXX
|| ................

|| ......XX..XX....    \ #
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ......XX..XX....
|| ......XX..XX....
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ......XX..XX....

|| ...XX.....XX....    \ $
|| ...XX....XXXX...
|| ...XX...XX..XX..
|| ..XXXXXXX....XX.
|| ..XXXXXXXXXXXXXX
|| ...XX..X.XXXXXXX
|| ....XXXX.....XX.
|| .....XX......XX.

|| ................    \ %
|| ...XXX......XX..
|| .....XXX....XX..
|| .......XXX......
|| .........XXX....
|| ....XX.....XXX..
|| ....XX.......XXX
|| ................

|| ....XXX...XXXX..    \ &
|| ...XX..XXXXXXXX.
|| ..XX..XXXX....XX
|| ..XX.XXX.XX...XX
|| ...XXXX...XXXXX.
|| ...XXXX....XX...
|| ..XXX.XXX.......
|| ..XX...XX.......

|| ................    \ '
|| ................
|| .............XXX
|| .............XXX
|| ................
|| ................
|| ................
|| ................

|| ................    \ (
|| .......XXXX.....
|| .....XXXXXXXX...
|| ...XXXX....XXXX.
|| ..XXX........XXX
|| ..X............X
|| ................
|| ................

|| ................    \ )
|| ................
|| ..X............X
|| ..XXX........XXX
|| ...XXXX....XXXX.
|| .....XXXXXXXX...
|| .......XXXX.....
|| ................

|| .........X....X.    \ *
|| ..........X..X..
|| ...........XX...
|| ........XXXXXXXX
|| ...........XX...
|| ..........X..X..
|| .........X....X.
|| ................

|| ..........XX....    \ +
|| ..........XX....
|| ..........XX....
|| ......XXXXXXXXXX
|| ......XXXXXXXXXX
|| ..........XX....
|| ..........XX....
|| ..........XX....

|| ................    \ ,
|| ................
|| ................
|| ..X...X.........
|| ..X..XXX........
|| ..XX.XXX........
|| ...XXXX.........
|| ................

|| ................    \ -
|| ..........XX....
|| ..........XX....
|| ..........XX....
|| ..........XX....
|| ..........XX....
|| ..........XX....
|| ................

|| ................    \ .
|| ................
|| ................
|| ...XXX..........
|| ..XXXXX.........
|| ..XXXXX.........
|| ...XXX..........
|| ................

|| ..XX............    \ /
|| ..XXXX..........
|| ....XXXX........
|| ......XXXX......
|| ........XXXX....
|| ..........XXXX..
|| ............XXXX
|| ..............XX

|| ....XXXXXXXXXX..    \ 0
|| ...XXXXXXXXXXXX.
|| ..XXX..XX....XXX
|| ..XX....XX....XX
|| ..XX.....XX...XX
|| ..XXX.....XX..XX
|| ...XXXXXXXXXXXX.
|| ....XXXXXXXXXX..

|| ................    \ 1
|| ................
|| ..XX........XX..
|| ..XX........XX..
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..XX............
|| ..XX............

|| ..XXX........XX.    \ 2
|| ..XXXX........XX
|| ..XX.XX.......XX
|| ..XX..XX......XX
|| ..XX...XX.....XX
|| ..XX....XX....XX
|| ..XX.....XXXXXX.
|| ..XX......XXXX..

|| ...XX........XX.    \ 3
|| ..XX..........XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ...XXXXXXXXXXXX.
|| ....XXX....XXX..

|| ......XXX.......    \ 4
|| ......XXXX......
|| ......XX.XXX....
|| ......XX...XXX..
|| ......XX.....XXX
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ......XX........

|| ...XX....XXXXXXX    \ 5
|| ..XXX....XXXXXXX
|| ..XX.....XX...XX
|| ..XX.....XX...XX
|| ..XX.....XX...XX
|| ..XX.....XX...XX
|| ...XXXXXXX....XX
|| ....XXXXX.....XX

|| .....XXXXXXX....    \ 6
|| ...XXXXXXXXXXX..
|| ..XXX..XX...XXX.
|| ..XX....XX...XX.
|| ..XX....XX....XX
|| ..XXX..XXX....XX
|| ...XXXXXX.....XX
|| ....XXXX........

|| ..............XX    \ 7
|| ..XX..........XX
|| ..XXXX........XX
|| ....XXXX......XX
|| ......XXXX....XX
|| ........XXXX..XX
|| ..........XXXXXX
|| ............XXXX

|| ....XXX....XXX..    \ 8
|| ...XXXXX..XXXXX.
|| ..XXX..XXXX..XXX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XXX..XXXX..XXX
|| ...XXXXX..XXXXX.
|| ....XXX....XXX..

|| ..........XXXX..    \ 9
|| ..XX.....XXXXXX.
|| ..XX....XXX..XXX
|| ..XX....XX....XX
|| ..XXX...XX....XX
|| ...XXX...XX..XXX
|| ....XXXXXXXXXXX.
|| .....XXXXXXXX...

|| ................    \ :
|| ................
|| ................
|| ......X.....X...
|| .....XXX...XXX..
|| .....XXX...XXX..
|| ......X.....X...
|| ................

|| ................    \ ;
|| ................
|| ................
|| ..X...X.....X...
|| ..X..XXX...XXX..
|| ..XX.XXX...XXX..
|| ...XXXX.....X...
|| ................

|| ................    \ <
|| ........X.......
|| .......XXX......
|| ......XX.XX.....
|| .....XX...XX....
|| ....XX.....XX...
|| ...XX.......XX..
|| ..XX.........XX.

|| ................    \ =
|| ......XX..XX....
|| ......XX..XX....
|| ......XX..XX....
|| ......XX..XX....
|| ......XX..XX....
|| ......XX..XX....
|| ......XX..XX....

|| ................    \ >
|| ..XX.........XX.
|| ...XX.......XX..
|| ....XX.....XX...
|| .....XX...XX....
|| ......XX.XX.....
|| .......XXX......
|| ........X.......

|| ................    \ ?
|| ..............XX
|| ..............XX
|| ..XX.XXXX.....XX
|| ..XX.XXXX.....XX
|| .......XX....XX.
|| ........XXXXXX..
|| .........XXX....

|| ....XXXXXXX.....    \ @
|| ...XXXXXXXXXXX..
|| ..XX........XXX.
|| .XX...XXXX...XXX
|| .XX..XX..XX...XX
|| .XX...XXX....XX.
|| ..XX...XXXXXXXX.
|| ........XXXXXX..

|| ..XXXXXX........    \ A
|| ..XXXXXXXXXX....
|| ......XXXXXXXXX.
|| ......XX....XXXX
|| ......XX....XXXX
|| ......XXXXXXXXX.
|| ..XXXXXXXXXX....
|| ..XXXXXX........

|| ..XXXXXXXXXXXXXX    \ B
|| ..XXXXXXXXXXXXXX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ...XXXXX..XXXXX.
|| ....XXX....XXX..

|| .....XXXXXXXX...    \ C
|| ....XXXXXXXXXX..
|| ...XX........XX.
|| ..XX..........XX
|| ..XX..........XX
|| ..XX..........XX
|| ..XX..........XX
|| ...XX........XXX

|| ..XXXXXXXXXXXXXX    \ D
|| ..XXXXXXXXXXXXXX
|| ..XX..........XX
|| ..XX..........XX
|| ..XX..........XX
|| ...XX........XX.
|| ....XXXXXXXXXX..
|| .....XXXXXXXX...

|| ..XXXXXXXXXXXXXX    \ E
|| ..XXXXXXXXXXXXXX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ..XX....XX....XX

|| ..XXXXXXXXXXXXXX    \ F
|| ..XXXXXXXXXXXXXX
|| ........XX....XX
|| ........XX....XX
|| ........XX....XX
|| ........XX....XX
|| ........XX....XX
|| ........XX....XX

|| .....XXXXXXXX...    \ G
|| ....XXXXXXXXXX..
|| ...XX........XX.
|| ..XX..........XX
|| ..XX....XX....XX
|| ..XX....XX....XX
|| ...XXXXXXX...XX.
|| ...XXXXXXX...XX.

|| ..XXXXXXXXXXXXXX    \ H
|| ..XXXXXXXXXXXXXX
|| ........XX......
|| ........XX......
|| ........XX......
|| ........XX......
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX

|| ................    \ I
|| ................
|| ..XX..........XX
|| ..XX..........XX
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..XX..........XX
|| ..XX..........XX

|| ................    \ J
|| ................
|| ...XX.........XX
|| ..XX..........XX
|| ..XX..........XX
|| ...XX.........XX
|| ....XXXXXXXXXXXX
|| .....XXXXXXXXXXX

|| ..XXXXXXXXXXXXXX    \ K
|| ..XXXXXXXXXXXXXX
|| .......XXXX.....
|| ......XXXXXX....
|| .....XXX..XXX...
|| ....XXX....XXX..
|| ...XXX......XXX.
|| ..XXX........XXX

|| ................    \ L
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..XX............
|| ..XX............
|| ..XX............
|| ..XX............
|| ..XX............

|| ..XXXXXXXXXXXXXX    \ M
|| ..XXXXXXXXXXXXXX
|| ............XXX.
|| .........XXXX...
|| .........XXXX...
|| ............XXX.
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX

|| ..XXXXXXXXXXXXXX    \ N
|| ..XXXXXXXXXXXXXX
|| ...........XXX..
|| .........XXX....
|| .......XXX......
|| .....XXX........
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX

|| .....XXXXXXXX...    \ O
|| ....XXXXXXXXXX..
|| ...XX........XX.
|| ..XX..........XX
|| ..XX..........XX
|| ...XX........XX.
|| ....XXXXXXXXXX..
|| .....XXXXXXXX...

|| ..XXXXXXXXXXXXXX    \ P
|| ..XXXXXXXXXXXXXX
|| ........XX....XX
|| ........XX....XX
|| ........XX....XX
|| .........XX..XX.
|| ..........XXXX..
|| ...........XX...

|| ......XXXXXXX...    \ Q
|| .....XXXXXXXXX..
|| ....XX.......XX.
|| ..XXX.........XX
|| .XXXX.........XX
|| .XX.XX.......XX.
|| .XX..XXXXXXXXX..
|| ......XXXXXXX...

|| ..XXXXXXXXXXXXXX    \ R
|| ..XXXXXXXXXXXXXX
|| ........XX....XX
|| ........XX....XX
|| ......XXXX....XX
|| ....XXXX.XX..XX.
|| ..XXXX....XXXX..
|| ..XX.......XX...

|| ...XX.......XX..    \ S
|| ..XX......XXXXX.
|| ..XX.....XX...XX
|| ..XX....XX....XX
|| ..XX...XX.....XX
|| ..XX..XX......XX
|| ...XXXX.......XX
|| ....XX.......XX.

|| ..............XX    \ T
|| ..............XX
|| ..............XX
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..............XX
|| ..............XX
|| ..............XX

|| ....XXXXXXXXXXXX    \ U
|| ...XXXXXXXXXXXXX
|| ..XX............
|| ..XX............
|| ..XX............
|| ..XX............
|| ...XXXXXXXXXXXXX
|| ....XXXXXXXXXXXX

|| ............XXXX    \ V
|| ........XXXXXXXX
|| ....XXXXXXX.....
|| ..XXXX..........
|| ..XXXX..........
|| ....XXXXXXX.....
|| ........XXXXXXXX
|| ............XXXX

|| ....XXXXXXXXXXXX    \ W
|| ..XXXXXXXXXXXXXX
|| ..XXX...........
|| ....XXXX........
|| ....XXXX........
|| ..XXX...........
|| ..XXXXXXXXXXXXXX
|| ....XXXXXXXXXXXX

|| ..XXX........XXX    \ X
|| ..XXXX......XXXX
|| ....XXXX..XXXX..
|| ......XXXXXX....
|| ......XXXXXX....
|| ....XXXX..XXXX..
|| ..XXXX......XXXX
|| ..XXX........XXX

|| ..............XX    \ Y
|| ............XXXX
|| ..........XXXX..
|| ..XXXXXXXXXX....
|| ..XXXXXXXXXX....
|| ..........XXXX..
|| ............XXXX
|| ..............XX

|| ..XX..........XX    \ Z
|| ..XXXX........XX
|| ..XXXXXX......XX
|| ..XX..XXXX....XX
|| ..XX....XXXX..XX
|| ..XX......XXXXXX
|| ..XX........XXXX
|| ..XX..........XX

|| ................    \ [
|| ................
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..XX..........XX
|| ..XX..........XX
|| ................
|| ................

|| .............XXX    \ \
|| ...........XXXXX
|| .........XXXX...
|| .......XXXX.....
|| .....XXXX.......
|| ..XXXXX.........
|| ..XXX...........
|| ................

|| ................    \ ]
|| ................
|| ..XX..........XX
|| ..XX..........XX
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ................
|| ................

|| ................    \ ^
|| ................
|| ...........XXX..
|| ............XXX.
|| .............XXX
|| ............XXX.
|| ...........XXX..
|| ................

|| .XX.............    \ _
|| .XX.............
|| .XX.............
|| .XX.............
|| .XX.............
|| .XX.............
|| .XX.............
|| .XX.............

|| ................    \ `
|| ................
|| ...............X
|| ..............XX
|| .............XXX
|| .............XX.
|| ................
|| ................

|| ................    \ a
|| ...XXX..........
|| ..XXXXX...X.....
|| ..X....X...X....
|| ..X....X...X....
|| ...X..XX..XX....
|| ..XXXXXXXXX.....
|| ..XXXXXXX.......

|| ................    \ b
|| ...XXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..XX.....XX.....
|| ..XX......XX....
|| ..XX......XX....
|| ...XXXXXXXX.....
|| .....XXXXX......

|| ................    \ c
|| .....XXXXX......
|| ...XXXXXXXXX....
|| ..XX......XX....
|| ..XX......XX....
|| ..XX......XX....
|| ..XX......XX....
|| ...XX....XX.....

|| ................    \ d
|| ...XXXXX........
|| ..XXXXXXXXX.....
|| ..XX......XX....
|| ..XX......XX....
|| ...XX....XX.....
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX

|| ................    \ e
|| ....XXXXXX......
|| ...XXXXXXXX.....
|| ..XX...X..XX....
|| ..XX...X..XX....
|| ..XX...X..XX....
|| ..XX...XXXXX....
|| ...XX..XXXX.....

|| ................    \ f
|| .........XX.....
|| .........XX.....
|| ..XXXXXXXXXXX...
|| ..XXXXXXXXXXXXX.
|| .........XX...XX
|| .........XX...XX
|| .............XX.

|| ................    \ g
|| ..XXX.XX.XX.....
|| .XXXXX..XXXX....
|| .XX...X.X...X...
|| .XX...X.X...X...
|| .XX...X.X...X...
|| ..XX.X..X..X....
|| ...XX....XX.X...

|| ................    \ h
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| .........XX.....
|| ..........XX....
|| ..........XX....
|| ..XXXXXXXXX.....
|| ..XXXXXXXX......

|| ................    \ i
|| ................
|| ..XX.......XX...
|| ..XX.......XX...
|| ..XXXXXXXXXXX.XX
|| ..XXXXXXXXXXX.XX
|| ..XX............
|| ..XX............

|| ................    \ j
|| ................
|| ...XX......XX...
|| ..XX.......XX...
|| ..XXXXXXXXXXX.XX
|| ...XXXXXXXXXX.XX
|| ................
|| ................

|| ................    \ k
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ......XXX.......
|| .....XX.XX......
|| ....XX...XX.....
|| ...XX.....XX....
|| ..XX.......XX...

|| ................    \ l
|| ................
|| ..XX..........XX
|| ..XX..........XX
|| ..XXXXXXXXXXXXXX
|| ..XXXXXXXXXXXXXX
|| ..XX............
|| ..XX............

|| ................    \ m
|| ..XXXXXXXXXX....
|| ..XXXXXXXXX.....
|| ..........XX....
|| ..XXXXXXXXX.....
|| ..........XX....
|| ..XXXXXXXXX.....
|| ..XXXXXXXX......

|| ................    \ n
|| ..XXXXXXXXXX....
|| ..XXXXXXXXX.....
|| ..........XX....
|| ..........XX....
|| ..........XX....
|| ..XXXXXXXXX.....
|| ..XXXXXXXX......

|| ................    \ o
|| ....XXXXXX......
|| ...XXXXXXXX.....
|| ..XX......XX....
|| ..X........X....
|| ..XX......XX....
|| ...XXXXXXXX.....
|| ....XXXXXX......

|| ................    \ p
|| .XXXXXXXXXXX....
|| .XXXXXXXXXX.....
|| ...XX......X....
|| ...XX......X....
|| ...XX......X....
|| ....XXXXXXX.....
|| .....XXXXX......

|| ................    \ q
|| .....XXXXX......
|| ....XXXXXXX.....
|| ...XX......X....
|| ...XX......X....
|| ....XX.....X....
|| .XXXXXXXXXXX....
|| .XXXXXXXXXXX....

|| ................    \ r
|| ..XXXXXXXXXX....
|| ..XXXXXXXXX.....
|| ...........X....
|| ...........X....
|| ..........XX....
|| .........XX.....
|| ........XX......

|| ................    \ s
|| ...X....XX......
|| ..X....XXXX.....
|| ..X...XX...X....
|| ..X...XX...X....
|| ..X...XX...X....
|| ...XXXX....X....
|| ....XX....X.....

|| ................    \ t
|| ............XX..
|| ............XX..
|| ....XXXXXXXXXXXX
|| ...XXXXXXXXXXXXX
|| ..XX........XX..
|| ...XX.......XX..
|| ....XX..........

|| ................    \ u
|| ...XXXXXXXXX....
|| ..XXXXXXXXXX....
|| ..X.............
|| ..X.............
|| ..X.............
|| ...XXXXXXXXX....
|| ..XXXXXXXXXX....

|| ................    \ v
|| .........XXX....
|| ......XXXXXX....
|| ....XXXXX.......
|| ..XXXX..........
|| ....XXXXX.......
|| ......XXXXXX....
|| .........XXX....

|| ................    \ w
|| .......XXXXX....
|| ...XXXXXXXXX....
|| ..XX............
|| ...XXXX.........
|| ..XX............
|| ...XXXXXXXXX....
|| .......XXXXX....

|| ................    \ x
|| ..XX......XX....
|| ..XXX....XXX....
|| ....XXXXXX......
|| .....XXXX.......
|| ....XXXXXX......
|| ..XXX....XXX....
|| ..XX......XX....

|| ................    \ y
|| .........XXX....
|| .X......XXX.....
|| .XX...XXXX......
|| .XXXXXXXX.......
|| ..XXXXXXXX......
|| ........XXX.....
|| .........XXX....

|| ................    \ z
|| ..XXX.....XX....
|| ..XXX.....XX....
|| ..XX.X....XX....
|| ..XX..X...XX....
|| ..XX...X..XX....
|| ..XX....X.XX....
|| ..XX.....XXX....

|| ................    \ {
|| ........XX......
|| ......XXXXXX....
|| ....XXXX..XXXX..
|| ...XXX......XXX.
|| ..XX..........XX
|| ..XX..........XX
|| ................

|| ................    \ |
|| ................
|| ................
|| ................
|| .XXXXXXXXXXXXXXX
|| .XXXXXXXXXXXXXXX
|| ................
|| ................

|| ................    \ }
|| ................
|| ..XX..........XX
|| ..XX..........XX
|| ...XXX......XXX.
|| ....XXXX..XXXX..
|| ......XXXXXX....
|| ........XX......

|| ........XX......    \ ~
|| .........XX.....
|| ..........XX....
|| .........XX.....
|| ........XX......
|| .......XX.......
|| ........XX......
|| .........XX.....

|| XXXXXXXXXXXXXXXX    \ Cursor block
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX
|| XXXXXXXXXXXXXXXX

|| .......X..X.....    \ €
|| .....XXXXXXXX...
|| ...XXXXXXXXXXXX.
|| ..XX...X..X...XX
|| ..XX...X..X...XX
|| ..XX...X..X...XX
|| ...XX.....X..XX.
|| ....XX.......X..

align
v: fresh
%%


chapter {OLED
hardware  dm 16 0 need spi\   \ Load driver for GPIO16 and SPI-0

hex ( OLED SPI-driver )
v: inside also definitions
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value

v: extra definitions
: SPI0-ON       ( khz -- )      \ Redefine for OLED purpose
    spi0-on  5 11 gpio!         \ General SPI0-on
    0A bitmask GPIO-OE **bis    \ Bit-10 is CS
    0B bitmask GPIO-OE **bis    \ Bit-11 is DC
    0C bitmask GPIO-OE **bis ;  \ Bit-12 is RES

: {OLED         ( -- )      0A bitmask GPIO-OUT **bic ;

: OLED}         ( -- )
    begin  10 'spi 0C + bit** 0= until \ SPI bus quiet
    0A bitmask GPIO-OUT **bis ;
v: fresh
%%


chapter OLED-SPI\
\ 4 = SPI OLED command set
(* Primitive SPI OLED text driver

UCA1 = OLED
    (RST=GPIO10, SIMO=GPIO19, CLK=GPIO18, CS=GPIO10, DC=GPIO11)
*)

\ OLED primitives
v: inside also  definitions
hex
0 value INV?                \ Partly inverted display?
: INV       ( b1 -- b2 )    inv? invert xor ;
: WHITE     ( -- )          true to inv? ;
: BLACK     ( -- )          false to inv? ;

: COMM      ( -- )          0B bitmask gpio-out **bic ; \ OLED command
: DATA      ( -- )          0B bitmask gpio-out **bis ; \ OLED screen data
: {CMD      ( b -- )        comm  {oled  spi0-out ;  \ Start OLED command stream
: {DATA     ( b -- )        data  {oled  spi0-out ;  \ Start OLED data stream
: >DATA     ( b -- )        inv  {data  oled} ;      \ Output one pixel row
\ : DATA}     ( b -- )        >data  oled} ;
: OL}       ( b -- )        spi0-out oled} ;         \ End an OLED stream
: >BRIGHT   ( b -- )        81 {cmd ol} ;            \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and AE or {cmd oled} ; \ Display on/off
: INVERSE   ( flag -- )     1 and A6 or {cmd oled} ; \ Display black or white
: SCROLL    ( +n -- )       D3 {cmd ol} ;            \ Rearrange display lines

v: extra definitions
: OLED-ON   ( -- )
    dm 1000 spi0-on          \ 1 MHz SPI
    0A bitmask gpio-out **bis      \ P2DIR     Init CS=1
    0B bitmask gpio-out **bis      \ P2DIR     Init DC=1
    0C bitmask gpio-out **bis 2 us \ P2DIR     Init RES=1
    0C bitmask gpio-out **bic 1 ms \ Hardware reset of OLED
    0C bitmask gpio-out **bis
    false on/off             \ Display off
    D5 {cmd  080 spi0-out    \ Set oscillator clock
    A8 spi0-out  3F spi0-out \ Set multiplexer ratio
    D3 spi0-out  00 spi0-out \ Display offset = 0
    40 spi0-out              \ Display starts at line 0
\   8D spi0-out  14 spi0-out \ Charge pump on (not for SH1106)
\   20 spi0-out  02 spi0-out \ Horizontal display mode (not for SH1106)
    A1 spi0-out              \ Mirror X-axis (segment remap)
    C8 spi0-out              \ Mirror Y-axis (COM scan dirction)
    DA spi0-out  12 spi0-out \ Alternate Com pin map  optional: 012 -> 02
    D9 spi0-out  F1 spi0-out \ Set precharge cycles to high cap: F1 was 022
    DB spi0-out  40 spi0-out \ VCOMH voltage to max: 40 mwas 30
    A4 spi0-out  E3 ol}      \ Enable rendering from GDRAM, end stream
    80 >bright               \ Set brightness to 50%
    false inverse  white     \ Oled in normal mode
    true on/off ;            \ Display on

( 5 = OLED screen driver output )

1 value #H  0 value X  0 value Y
: XY        ( x y -- )
    7 and dup to y                      \ Y is circular
    B0 or {cmd                          \ Yes, set Y line position
    dup to x  2 + dup 0F and spi0-out   \ & set X column (Only for SH1106 = 2 +)
    4 rshift 10 or ol} ;

: &FILL         ( +n b -- ) \ Pattern 'b' to +n columns
    swap  data {OLED        \ Start oled-data stream
    begin                   \ Whole screen buffer
        over >data          \ Output pattern
    1- ?dup 0= until OLED}  drop ; \ End stream

: .BITROW   ( a +n -- )      \ Output half of +Nx14 (big) character
    false >data for
        count >data  1+      \ Output every second bit row
    next
    drop  0 >data ;

: .ROWS         ( a +n )        for count >data next drop ;
: .G-ROWS       ( a -- )        4 for count >data  incr x next drop ;
: &EOL          ( +n -- )       false &fill ;       \ Fill +n rows with zero
: &HOME         ( -- )          false dup xy ;      \ To upper left corner
: &ERASE        ( -- )          &home  9 for 0 i xy 80 &eol next ;
\ : &PAGE         ( -- )          &erase  &home ;
\ : &CR           ( -- )          0  y #h +  xy ;     \ Simple CR
0 value O-EMIT  \ OLED emit vector
: &EMIT         ( c -- )        o-emit execute ;
: &SPACE        ( -- )          bl &emit ;
: &SPACES       ( u -- )        for  &space  next ;
: &TYPE         ( a u -- )      for  count &emit  next  drop ;
: &U.           ( n -- )        false <# #s #> &type &space ;
: C>N           ( c -- +n )     bl - ;  \ Convert char to bitmap index number

: &"            ( -- )          \ ." voor OLED
    flyer  postpone s"  postpone &type ;  immediate

: XY"       ( x y ccc -- )      \ XY" voor OLED
    flyer  postpone xy  postpone &" ; immediate
v: fresh
shield OLED-SPI\
%%


chapter I2C-OLED\
need [undefined]    ( I2C OLED command set )
need [if]

[undefined] i2c\ [if]
    hardware  dm 400 dm 14 need I2C\
[then]

\ I2C driver for SSD1306, a 128x64 pixels OLED screen.
\ Add separate files with a small, big, bold & graphic character set.
v: inside also  definitions
hex
0 value INV?                \ Partly inverted display?
: INV       ( b1 -- b2 )    inv? invert xor ;
: WHITE     ( -- )          true to inv? ;
: BLACK     ( -- )          false to inv? ;
: {OL       ( b +n -- )     3C device!  1+      \ Start an oled command: b=00 or oled data: b=40
                            {i2c-write  bus! ;  \ Single byte command: b=80, single byte data: b=C0
: {DATA     ( +n -- )       40 swap {ol ;       \ Start OLED data stream
: DATA}     ( b -- )        inv bus! i2c} ;     \ End OLED data stream
: >DATA     ( b -- )        inv bus! ;          \ Single pixel row
: {CMD      ( +n -- )       0 swap {ol ;        \ Start OLED command stream
: >CMD      ( b -- )        bus! ;              \ Output extra command
: >CMD}     ( b -- )        bus! i2c} ;         \ End an OLED command stream
: CMD       ( b -- )        80 1 {ol >cmd} ;    \ Single byte oled command
: 2CMD      ( b1 b0 -- )    2 {cmd >cmd >cmd} ; \ Dual byte oled command
: >BRIGHT   ( b -- )        81 2cmd ;           \ b = 0 to 255 (max. brightness)
: ON/OFF    ( flag -- )     1 and  AE or cmd ;  \ Display on/off
: INVERSE   ( flag -- )     1 and  A6 or cmd ;  \ Invert whole display to black or white
: SCROLL    ( +n -- )       D3 2cmd ;           \ Rearrange display lines

v: extra definitions
: OLED-ON   ( -- )
    i2c-on                  \ Init. 400kHz I2C
    false on/off            \ Display off
    14 {cmd                 \ Start oled-command stream
    A8 >cmd  3F >cmd        \ Set multiplexer ratio
    D3 >cmd  0 >cmd         \ Display offset = 0
    40 >cmd                 \ Display starts at line 0
    A1 >cmd                 \ Mirror X-axis
    C8 >cmd                 \ Mirror Y-axis
    DA >cmd  12 >cmd        \ Alternate Com pin map
    A4 >cmd                 \ Enable rendering from GDRAM
    D5 >cmd  80 >cmd        \ Set oscillator clock
    8D >cmd  14 >cmd        \ Charge pump on
    D9 >cmd  22 >cmd        \ Set precharge cycles to high cap.
    DB >cmd  30 >cmd        \ VCOMH voltage to max.
    20 >cmd  00 >cmd}       \ Horizontal display mode, end stream
    C0 >bright              \ Set contrast to 75%
    false inverse  white    \ Oled in normal mode
    true on/off ;           \ Display on

( OLED screen driver output )
1 value #H  0 value X  0 value Y
: XY        ( x y -- )          \ Set OLED column and row
    3 {cmd                      \ Command stream
    dup to y  7 and B0 or >cmd  \ Set page
    dup to x  dup 0F and >cmd   \ Set column
    F0 and 4 rshift 10 or >cmd} ;

: &FILL         ( +n b -- )     \ Pattern 'b' to +n columns
    over {data   swap           \ Start oled-data stream
    begin                       \ Whole screen buffer
        over >data              \ Output pattern
    1- ?dup 0= until  i2c}  drop ; \ End stream

: .BITROW   ( a +n -- )     \ Output half of +Nx14 (big) character
    dup 2 + {data  0 >data  for
        count >data  1+     \ Output every second bit row
    next  drop
    0 data} ;

: .ROWS         ( a +n )        dup 1+ {data  for count >data next drop  i2c} ;
: .G-ROWS       ( a -- )        4 {data  4 for count >data  incr x next drop  i2c} ;
: &EOL          ( +n -- )       dup {data  for  0 >data  next  i2c} ;
: &ERASE        ( -- )          480 0 &fill ;       \ Erase screen
: &HOME         ( -- )          0 0 xy ;            \ To upper left corner
\ : &PAGE         ( -- )          &erase  &home ;
\ : &CR           ( -- )          0  y #h +  xy ;   \ Simple CR
0 value O-EMIT  \ OLED emit vector
: &EMIT         ( c -- )        o-emit execute ;
: &SPACE        ( -- )          bl &emit ;
: &SPACES       ( u -- )        for  &space  next ;
: &TYPE         ( a u -- )      for  count &emit  next  drop ;
: &U.           ( n -- )        0 <# #s #> &type &space ;
: C>N           ( c -- +n )     bl - ;  \ Convert char to bitmap index number

: &"            ( -- )          \ ." voor OLED
    flyer  postpone s"  postpone &type ;  immediate

: XY"       ( x y ccc -- )      \ XY" voor OLED
    flyer  postpone xy  postpone &" ; immediate
v: fresh
shield I2C-OLED\
%%


chapter &CR
hex
v: inside also definitions  ( Scrolling display )
0 value SCRL                \ Scrolling &CR
v: extra definitions
: &PAGE     ( -- )          \ Erase display, line 0 on top
    #h 8 * to scrl 0 scroll \ Reset administration
    &erase  0 #h 1- xy ;    \ Empty display

: &CR       ( -- )              \ New line with scroll functionality
    false to x  #h +to y        \ To start of next line
    #h 8 * +to scrl  scrl 80 >  \ Incr. SCRL is it greater then 80
    if 40 #h 8 * + to scrl then \ Yes, restore to 48/50
    scrl 40 > if                \ Screen full?
        false y 7 and xy  y     \ Keep y in range
        scrl 38 and  scroll     \ Rearrange display
        80 &eol                 \ Erase last line
        #h 1- if                \ Previous line too?
            x y 1- xy 80 &eol   \ both rows
        then  to y
    then  x y xy ;              \ Set xy there
v: fresh
%%


chapter THIN
hex
v: inside also definitions
: THIN-EMIT ( c -- )            \ Output 7x16 characters!
    BL -  80 x -  dup 9 < if    \ Character does not fit?
        dup &eol  y             \ Yes, erase to end Of Line
        y 1- 0< 0= if
            x y 1- xy over &eol \ Erase end of next line too
        then
        false swap xy           \ To start of new line
    then  drop
    0E * 'thin +                \ Character address
    dup 1+  7 .bitrow  y 1- >r  \ Lower half of big char
    r@ 0< 0= if                 \ Not off screen?
        x r@ xy  7 .bitrow      \ Yes, do top half of big char
    then
    x 09 +  r> 1+ xy ;          \ x & y to new char position

v: extra definitions
: THIN      ( -- )      ['] thin-emit to o-emit  2 to #h ;
v: fresh
%%


chapter BOLD
hex
v: inside also definitions
: BOLD-EMIT ( c -- )            \ Output 7x16 characters!
    c>n  80 x -  dup 0A < if    \ Character does not fit?
        dup &eol  y             \ Yes, erase to end Of Line
        y 1- 0< 0= if
            x y 1- xy over &eol \ Erase end of next line too
        then
        false swap xy           \ To start of new line
    then  drop
    4 lshift 'bold +            \ Character address
    dup 1+  8 .bitrow  y 1- >r  \ Lower half of big char
    r@ 0< 0= if                 \ Not off screen?
        x r@ xy  8 .bitrow      \ Yes, do top half of big char
    then
    x 0A +  r> 1+ xy ;          \ x & y to new char position

v: extra definitions
: BOLD      ( -- )      ['] bold-emit to o-emit  2 to #h ;
v: fresh
%%


chapter SMALL
v: inside   ( Ouput small characters, 5x8 bits )
hardware  need 'small
v: inside also definitions
: SMALL-EMIT    ( +n -- )
    c>n  hx 80 x - dup 6 < if   \ Line full?
        dup &eol  0 y 1+ xy     \ Yes, fill & to next line
    then  drop
    5 * 'small +  5 .rows       \ Go to wanted char
    0 >data  x 6 + y xy ;       \ To new char position

v: extra definitions
: SMALL     ['] small-emit to o-emit  1 to #h ;
v: fresh
%%


chapter GRAPHIC
hex
v: inside also definitions
create CUSTOM  10 allot  \ Building place for custom graphics chars (p q r s)
v: extra definitions
: EMPTY     ( -- )       custom 10 0 fill ;
: OR!       ( +n a -- )  >r  r@ c@ or  r> c! ;

: >CC       ( +g +c -- )    \ Construct one of four custom patterns
    >r 2* 2* 'graph +  r>   \ Graphic char address
    2* 2* custom +          \ Custom char address
    4 0 do
        over i + c@  over i + or!
    loop  2drop ;

v: inside definitions
: .CUSTOM   ( +n -- )
    base @ >r  2 base !
    2* 2* custom +  4 bounds do
        cr i c@ s>d <# # # # # # # # # #> type space
    loop
    r> base ! ;

: GRAPHIC-EMIT  ( c -- )
    80 x -  4 < if  drop exit  then     \ Line full? Yes stop!
    ch 0 -  dup 0< throw  dup 3F > if   \ Custom char?
        40 -  2* 2* custom +            \ Yes, print custom char
        .g-rows  exit
    then
    2* 2* 'graph + .g-rows ;            \ No, print graphic char

v: extra definitions
: GRAPHIC   ['] graphic-emit  to o-emit  1 to #h ;
v: fresh
%%


chapter SMALL-DEMO
v: inside   ( Small character scrolling demo )
hardware  need 'SMALL
v: inside
hardware  need &cr
v: inside
hardware  need small
hardware  need bootkey?
hex
v: fresh  inside
: SMALL-DEMO    ( -- )          \ Display small token set
    oled-on  small  &page
    dm 30 0 xy" Egel project"   \ Startup message
    dm 36 2 xy" Characters"
    dm 48 4 xy" by W.O."
    300 ms  &page
    8 0 do                      \ Display @ pattern
        &cr  i 3 and  1+ &spaces
        8 0 do
            I 1 and 80 or &emit  bl &emit  40 ms
        loop
        bootkey? if leave then
    loop
    300 ms &cr
    80 bl do
        i f and 0= if &cr then  i &emit \ Show character set
        bootkey? if leave then
    loop  400 ms ;
v: fresh
%%


chapter SCROLL-DEMO
v: inside   ( Thin character scrolling demo )
hardware  need 'thin
v: inside
hardware  need &cr
v: inside
hardware  need thin
hardware  need bootkey?
hex
v: fresh  inside
: SCROLL-DEMO   ( -- )
    oled-on  thin           \ Init. OLED & select char. type
    &page  FF ms            \ Wipe screen
    begin
        &" PROJECT"  &cr  80 ms
        &"    FORTH" &cr  80 ms
        &"       WORKS"
        10 0 do
            40 ms  bootkey? if leave then
         loop  &cr
    bootkey? until  &page ; \ Until a key was pressed
v: fresh
%%


chapter MIXED-DEMO
v: inside   ( Mixed letter size scrolling demo )
hardware  need 'SMALL
v: inside
hardware  need 'thin
v: inside
hardware  need &cr
v: inside
hardware  need thin
v: inside
hardware  need small
hardware  need bootkey?
hex
v: fresh  inside
: MIXED-DEMO  ( -- )            \ Display mixed token set
    oled-on  small  &page
    dm 30 0 xy" Egel project"   \ Startup message
    dm 36 2 xy" Characters"
    dm 48 4 xy" by W.O."
    300 ms  &page
    8 0 do                      \ Display @ pattern
        &cr  i 3 and  1+ &spaces
        8 0 do  i 1 and 80 + &emit  bl &emit  40 ms loop
        bootkey? if leave then
    loop
    300 ms &cr
    82 bl do
        i f and 0= if &cr 80 ms  then  i &emit \ Show character set
        bootkey? if leave then
    loop
    300 ms  thin  &cr &" Hallo "  small &" Willem "  thin ch O &emit
    small &cr &" *******************"
    thin  &cr  small &" HCC "  thin &" Forth gg " 400 ms ;
v: fresh
%%

chapter THIN-DEMO
need j
v: inside   ( Show large thin letter size scrolling demo )
hardware  need 'thin
v: inside
hardware  need &cr
v: inside
hardware  need thin
hardware  need bootkey?
hex
: THIN-DEMO ( -- )              \ Display thin large token set
    oled-on  thin  &page
    &"  Egel project"   &cr     \ Startup message
    &"   Characters"    &cr     \ To line 2
    &"     by A.N."     &cr     \ To line 4
    A00 ms  8 0 do              \ All characters
        &cr  0D 0 do
            j 0D * BL + i +
            81 umin &emit
        loop
        bootkey? if leave then
        300 ms
    loop
    A00 ms &cr  6 0 do          \ Two special characters
        &cr  0C 0 do
            j 1 and 80 or &emit
        loop  100 ms
        bootkey? if leave then
    loop  400 ms ;
%%

chapter BOLD-DEMO
need j
v: inside   ( Show large bold letter size scrolling demo )
hardware  need 'bold
v: inside
hardware  need &cr
v: inside
hardware  need bold
hardware  need bootkey?
: BOLD-DEMO ( -- )              \ Display thin large token set
    oled-on  bold  &page
    &" Egel project"   &cr      \ Startup message
    &"  Characters"    &cr      \ To line 2
    &"   by J.J.H"     &cr      \ To line 4
    A00 ms  8 0 do              \ All characters
        &cr  0C 0 do
            j 0C * BL + i +
            80 umin &emit
        loop
        bootkey? if leave then
        300 ms
    loop
    A00 ms &cr  6 0 do          \ Two special characters
        &cr  0C 0 do
            j 1 and 2* 7E +  &emit
        loop  100 ms
        bootkey? if leave then
    loop  400 ms ;
%%


chapter GRAPHIC-DEMO
v: inside
hardware  need 'graph     \ Graphic characters
v: inside
hardware  need 'thin      \ Large thin characters
v: inside
hardware  need &cr        \ Scrolling CR
v: inside
hardware  need thin       \ Emit for 16-bit thin characters
v: inside
need graphic    \ Graphic character emit
hardware  need bootkey?

v: fresh inside
: GRAPHIC-DEMO ( -- )               \ Display graphic token set
    oled-on  thin  &page
    &" Egel project"                \ Startup message
    0A 3 xy" Characters"            \ To line 2
    18 5 xy" by W.O."               \ To line 4

    800 ms graphic  &page
    ch 0 20 bounds do i &emit loop  \ All graphic characters
    0 1 xy ch P 20 bounds do  i &emit  loop
    0 3 xy 20 0 do  &" UT"  loop   \ Some patterns, build

    empty  dm 58 0 >cc  dm 60 0 >cc \ two custom chars
           dm 59 1 >cc  dm 61 1 >cc \ out of default chars
    0 5 xy 20 0 do  &" pq"  loop  400 ms ; \ Show both custom chars
v: fresh
%%


chapter EGEL-DEMO
v: inside
hardware  need 'graph     \ Graphic characters
v: inside
hardware  need 'thin      \ Large thin characters
v: inside
hardware  need &cr        \ Scrolling CR
v: inside
hardware  need thin       \ Emit for 16-bit thin characters
v: inside
hardware  need graphic    \ Graphic character emit
hardware  need bootkey?

v: inside also definitions
: EGEL      ( y x -- )          \ Print hedgehog at pos y x
    empty                       \ Erase custom characters
    dm 59 0 >cc  dm 52 0 >cc    \ Build four custom characters: p
    dm 58 1 >cc  dm 51 1 >cc    \ q
    dm 53 2 >cc  dm 56 2 >cc  9 2 >cc  \ r
    dm 45 3 >cc  dm 11 3 >cc    \ s
    >r  dup r@ xy" 0000000000W:`8c58050"
    dup r@ 1+  xy" 5700000000o8^^n]WjnXgV0"
    dup r@ 2 + xy" kpigbhhhge;q]^27o6n4[ii0"
    dup r@ 3 + xy" 0036grd700c0ef6hk07335of0"
    dup r@ 4 + xy" 0000000366kbkVk00b3f`46s0"
        r> 5 + xy" 00000000000000000003bf0" ;

v: fresh inside
: EGEL-DEMO ( -- )
    oled-on  graphic  &page   \ Init. and show Hedgehog
    38 00 do
        80 i 2* - 1 egel  10 ms \ Move hedgehog to center screen
        bootkey? if leave then
    loop
    80 ms  thin  4 6 xy" Graphic chars"
    A00 ms  thin &page              \ Wait then show message
     4 1 xy" Project Forth"         \ Startup message
    28 3 xy" Works"                 \ To line 2
    1A 5 xy" Graphics"              \ To line 4
    20 7 xy" by W.O."  400 ms ;     \ To line 6
v: fresh
%%


chapter SPI-OLED-DEMO\
v: inside           \ Add all demos for an SPI OLED screen
hardware  need {oled
v: inside
hardware  need oled-spi\

hardware  need small-demo
hardware  need thin-demo
hardware  need bold-demo
hardware  need mixed-demo
hardware  need scroll-demo
hardware  need graphic-demo
hardware  need egel-demo
shield SPI-OLED-DEMO\
v: fresh
%%


chapter I2C-OLED-DEMO\
v: inside           \ Add all demos for an I2C OLED screen
hardware  need i2c-oled\

hardware  need small-demo
hardware  need thin-demo
hardware  need bold-demo
hardware  need mixed-demo
hardware  need scroll-demo
hardware  need graphic-demo
hardware  need egel-demo
shield I2C-OLED-DEMO\
v: fresh
%%

chapter OLED-APP\
( a u -- )      \ Needs a string as input

need [if]

hardware
2dup upper s" I2C" s<> 0=       \ An I2C or SPI OLED demo wanted?
[if]
    need i2c-oled-demo\
[else]
    need spi-oled-demo\
[then]

: (MS)  ( u -- )
    for  1 ms  bootkey? if rdrop exit then  next ;

: OLED  ( -- )
    begin
        egel-demo  400 (ms)
    bootkey? 0= while
        thin-demo  400 (ms)
    bootkey? 0= while
        bold-demo  400 (ms)
    bootkey? 0= while
        mixed-demo  400 (ms)
    bootkey? until
    then then then ;

cr .( Type: OLED  to start the demo )

' oled  to app
shield OLED-APP\
%%

chapter ST7789\
( gpio -- )     \ Use SPI-0 at GPIO-0, 4 or 16
                \ Use SPI-1 at GPIO-8 or 12

(* LCD ST7789 driver                        Pico-kit connections

    1 - Gnd     Ground
    2 - VCC     3V3
    3 - SCL     Clock, max. 62.5 MHz                GPIO18
    4 - SDA     Data in, setup 7 ns, hold 7 ns      GPIO19
    5 - Reset   Active low 10 µs                    GPIO12
    6 - DC      1 = Data, 0 = Command               GPIO11
    7 - CS      Active low                          GPIO10
    8 - Blk     3V3

Setup commands for setup:

// Format: cmd length (including cmd byte), post delay in units of 5 ms, then cmd payload
// Note the delays have been shortened a little
static const uint8_t st7789_init_seq[] = {
        1, 20, 0x01,                        // Software reset
        1, 10, 0x11,                        // Exit sleep mode
        2, 2, 0x3a, 0x55,                   // Set colour mode to 16 bit
        2, 0, 0x36, 0x00,                   // Set MADCTL: row then column, refresh is bottom to top
        5, 0, 0x2a, 0x00, 0x00, SCREEN_WIDTH >> 8, SCREEN_WIDTH & 0xff,   // CASET: column addresses
        5, 0, 0x2b, 0x00, 0x00, SCREEN_HEIGHT >> 8, SCREEN_HEIGHT & 0xff, // RASET: row addresses
        1, 2, 0x21,                         // Inversion on, then 10 ms delay (supposedly a hack?)
        1, 2, 0x13,                         // Normal display on, then 10 ms delay
        1, 2, 0x29,                         // Main screen turn on, then wait 500 ms
        0                                   // Terminate list
};

Used RP2040 registers:

    4003C000    - SPI0_BASE
    40040000    - SPI1_BASE
    40014000    - IO_BANK0_BASE

SPI is chapter 4.4 from page 503 ff in RP2040 datasheet

*)

need [IF]
hardware  need KHZ>

v: inside also definitions
\ Check for valid SPI start GPIO & select SPI register base address
    dup 00 =      over 04 = or  over dm 16 = or     ( spi-0 )
    over 08 = or  over dm 12 = or [if]              ( spi-1 )
        constant RX0    rx0 8 =  rx0 dm 12 =  or
        [if] 40040000 [else] 4003C000 [then]  constant 'SPI
    [else]
        cr .( Wrong GPIO for SPI valid are 0, 4, 8, 12, 16: )  dm .  abort
    [then]

hex
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value

0 [if]  ( High level code? )

: >LCD      ( b -- )
    [ 'spi 8 + ] literal  >r
    begin  2 r@ cell+ bit** until  r@ !
    begin  4 r@ cell+ bit** until  rdrop ;

: 2>LCD     ( bl bh -- )    >lcd >lcd ;
: FILL)     ( b0 b1 +n --)  for  2dup 2>lcd  next 2drop ;

rx0 dm 16 = [if]  ( Try SPI-0 )

: {SPI          ( -- )      dm 10 bitmask gpio-out **bic ;  \ Allow SPI access
: SPI}          ( -- )      dm 10 bitmask gpio-out **bis ;  \ Close SPI access
: DATA          ( -- )      dm 11 bitmask gpio-out **bis ;  \ Data mode
: COMM          ( -- )      dm 11 bitmask gpio-out **bic ;  \ Command mode

[then]

rx0 04 = [if]  ( Try SPI-0 )

: {SPI          ( -- )      dm 05 bitmask gpio-out **bic ;  \ Allow SPI access
: SPI}          ( -- )      dm 05 bitmask gpio-out **bis ;  \ Close SPI access
: DATA          ( -- )      dm 03 bitmask gpio-out **bis ;  \ Data mode
: COMM          ( -- )      dm 03 bitmask gpio-out **bic ;  \ Command mode

[then]

rx0 00 = [if]  ( Try SPI-0 )

: {SPI          ( -- )      dm 01 bitmask gpio-out **bic ;  \ Allow SPI access
: SPI}          ( -- )      dm 01 bitmask gpio-out **bis ;  \ Close SPI access
: DATA          ( -- )      dm 06 bitmask gpio-out **bis ;  \ Data mode
: COMM          ( -- )      dm 06 bitmask gpio-out **bic ;  \ Command mode

[then]

rx0 08 = [if]  ( Try SPI-1 )

: {SPI          ( -- )      dm 09 bitmask gpio-out **bic ;  \ Allow SPI access
: SPI}          ( -- )      dm 09 bitmask gpio-out **bis ;  \ Close SPI access
: DATA          ( -- )      dm 12 bitmask gpio-out **bis ;  \ Data mode
: COMM          ( -- )      dm 12 bitmask gpio-out **bic ;  \ Command mode

[then]

rx0 12 = [if]  ( Try SPI-1 )

: {SPI          ( -- )      dm 13 bitmask gpio-out **bic ;  \ Allow SPI access
: SPI}          ( -- )      dm 13 bitmask gpio-out **bis ;  \ Close SPI access
: DATA          ( -- )      dm 16 bitmask gpio-out **bis ;  \ Data mode
: COMM          ( -- )      dm 16 bitmask gpio-out **bic ;  \ Command mode

[then]

[else]  ( Low level code )

create DATA
    gpio-out 4 + ,
    rx0 dm 16 = [if]  dm 11  bitmask ,  [then]
    rx0 dm 04 = [if]  dm 02  bitmask ,  [then]
    rx0 dm 00 = [if]  dm 06  bitmask ,  [then]
    rx0 dm 08 = [if]  dm 12  bitmask ,  [then]
    rx0 dm 12 = [if]  dm 16  bitmask ,  [then]
    'spi 0C + ,
code>
    2710CA70 ,  403A6832 ,  6025D1FC ,  CA10C804 ,  FFFF46A7 ,
end-code

create COMM
    gpio-out 8 + ,
    rx0 dm 16 = [if]  dm 11  bitmask ,  [then]
    rx0 dm 04 = [if]  dm 02  bitmask ,  [then]
    rx0 dm 00 = [if]  dm 06  bitmask ,  [then]
    rx0 dm 08 = [if]  dm 12  bitmask ,  [then]
    rx0 dm 12 = [if]  dm 16  bitmask ,  [then]
code>  6025CA30 ,  CA10C804 ,  FFFF46A7 ,  end-code

create {SPI
    gpio-out 8 + ,
    rx0 dm 16 = [if]  dm 10  bitmask ,  [then]
    rx0 dm 04 = [if]  dm 05  bitmask ,  [then]
    rx0 dm 00 = [if]  dm 01  bitmask ,  [then]
    rx0 dm 08 = [if]  dm 09  bitmask ,  [then]
    rx0 dm 12 = [if]  dm 13  bitmask ,  [then]
code>  6025CA30 ,  CA10C804 ,  FFFF46A7 ,  end-code

create SPI}
    gpio-out 4 + ,
    rx0 dm 16 = [if]  dm 10  bitmask ,  [then]
    rx0 dm 04 = [if]  dm 05  bitmask ,  [then]
    rx0 dm 00 = [if]  dm 01  bitmask ,  [then]
    rx0 dm 08 = [if]  dm 09  bitmask ,  [then]
    rx0 dm 12 = [if]  dm 13  bitmask ,  [then]
    'spi 0C + ,
code>
    2710CA70 ,  403A6832 ,  6025D1FC ,  CA10C804 ,  FFFF46A7 ,
end-code

routine >LCD)    ( -- a )   \ DAY = SPI data register, TOS = LCD command or data
    686F h,  2602 h,  4037 h,  D0FB h,  602B h,  4770 h,
end-code

create >LCD      ( b -- )
    'spi 08 + ,
code>
    6815 h,  F7FF h,  FFED h,  C908 h,  C804 h,  CA10 h,  46A7 h,  FFFF h,
end-code

create 2>LCD     ( b0 b1 -- )
    'spi 08 + ,
code>
    6815 h,  F7FF h,  FFDB h,  C908 h,  F7FF h,
    FFD8 h,  C908 h,  C804 h,  CA10 h,  46A7 h,
end-code

create FILL)     ( b0 b1 +n -- )
    'spi 8 + ,
code>
    6815 h,  461C h,  C904 h,  C980 h,  46B9 h,  0013 h,
    F7FF h,  FFC2 h,  464B h,  F7FF h,  FFBF h,  3C01 h,
    D1F7 h,  C908 h,  C804 h,  CA10 h,  46A7 h,  FFFF h,
end-code

[then]

: {CMD      ( c -- )    comm {spi  >LCD  data ;
: CMD       ( c -- )    {cmd  spi} ;                \ Command only
: CMD1      ( d c -- )  {cmd  >LCD  spi} ;          \ Command with one data byte

: CMD+      ( d0 dn +n c -- )   \ Command with +n data bytes
    {cmd  for  >LCD  next  spi} ;


rx0 dm 16 = [if]

: TFT-INIT      ( -- )
    1 rx0 2dup  gpio!               \ GPIOa, GPIOc & GPIOd for SPI
    2dup 2 +    gpio!
         3 +    gpio!
    5 dm 10 gpio!                   \ Enable SIO on pin 10 (CS)
    5 dm 11 gpio!                   \ Enable SIO on pin 11 (DC)
    5 dm 12 gpio!                   \ Enable SIO on pin 12 (RES)
    [ dm 10 bitmask  dm 11 bitmask  \ These bits are outputs
    dm 12 bitmask or or ] literal
    gpio-oe **bis
    [ dm 10 bitmask dm 11 bitmask   \ And all high
    [ dm 12 bitmask or or ] literal
    gpio-out **bis  dm 62500 khz>   \ Clock = 62.5 MHz
    0007 or  'spi !                 \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic              \ SSPCR1    Disable SSE
    2 'spi cell+ !                  \ SSPCR1    Synchronous master
    'spi 10 + ! ;                   \ SSPCPSR   clock prescaler

: RESET         ( -- )              \ Restart the LCD
    dm 12 bitmask gpio-out **bic  20 us
    dm 12 bitmask gpio-out **bis ;

[then]


rx0 dm 04 = [if]

: TFT-INIT      ( -- )
    1 rx0 2dup  gpio!               \ GPIOa, GPIOc & GPIOd for SPI
    2dup 2 +    gpio!
         3 +    gpio!
    5 dm 05 gpio!                   \ Enable SIO on pin 10 (CS)
    5 dm 03 gpio!                   \ Enable SIO on pin 11 (DC)
    5 dm 02 gpio!                   \ Enable SIO on pin 02 (RES)
    [ dm 02 bitmask  dm 03 bitmask  \ These bits are outputs
    dm 05 bitmask or or ] literal
    gpio-oe **bis
    [ dm 02 bitmask dm 03 bitmask   \ And all high
    [ dm 05 bitmask or or ] literal
    gpio-out **bis  dm 62500 khz>   \ Clock = 62.5 MHz
    0007 or  'spi !                 \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic              \ SSPCR1    Disable SSE
    2 'spi cell+ !                  \ SSPCR1    Synchronous master
    'spi 10 + ! ;                   \ SSPCPSR   clock prescaler

: RESET         ( -- )              \ Restart the LCD
    dm 02 bitmask gpio-out **bic  20 us
    dm 02 bitmask gpio-out **bis ;

[then]


rx0 dm 00 = [if]

: TFT-INIT      ( -- )
    1 rx0 2dup  gpio!               \ GPIOa, GPIOc & GPIOd for SPI
    2dup 2 +    gpio!
         3 +    gpio!
    5 dm 01 gpio!                   \ Enable SIO on pin 10 (CS)
    5 dm 06 gpio!                   \ Enable SIO on pin 11 (DC)
    5 dm 07 gpio!                   \ Enable SIO on pin 02 (RES)
    [ dm 01 bitmask  dm 06 bitmask  \ These bits are outputs
    dm 07 bitmask or or ] literal
    gpio-oe **bis
    [ dm 01 bitmask dm 06 bitmask   \ And all high
    [ dm 07 bitmask or or ] literal
    gpio-out **bis  dm 62500 khz>   \ Clock = 62.5 MHz
    0007 or  'spi !                 \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic              \ SSPCR1    Disable SSE
    2 'spi cell+ !                  \ SSPCR1    Synchronous master
    'spi 10 + ! ;                   \ SSPCPSR   clock prescaler

: RESET         ( -- )              \ Restart the LCD
    dm 07 bitmask gpio-out **bic  20 us
    dm 07 bitmask gpio-out **bis ;

[then]


rx0 dm 08 = [if]

: TFT-INIT      ( -- )
    1 rx0 2dup  gpio!               \ GPIOa, GPIOc & GPIOd for SPI
    2dup 2 +    gpio!
         3 +    gpio!
    5 dm 09 gpio!                   \ Enable SIO on pin 10 (CS)
    5 dm 12 gpio!                   \ Enable SIO on pin 11 (DC)
    5 dm 02 gpio!                   \ Enable SIO on pin 02 (RES)
    [ dm 02 bitmask  dm 09 bitmask  \ These bits are outputs
    dm 12 bitmask or or ] literal
    gpio-oe **bis
    [ dm 02 bitmask dm 09 bitmask   \ And all high
    [ dm 12 bitmask or or ] literal
    gpio-out **bis  dm 62500 khz>   \ Clock = 62.5 MHz
    0007 or  'spi !                 \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic              \ SSPCR1    Disable SSE
    2 'spi cell+ !                  \ SSPCR1    Synchronous master
    'spi 10 + ! ;                   \ SSPCPSR   clock prescaler

: RESET         ( -- )              \ Restart the LCD
    dm 02 bitmask gpio-out **bic  20 us
    dm 02 bitmask gpio-out **bis ;

[then]


rx0 dm 12 = [if]

: TFT-INIT      ( -- )
    1 rx0 2dup  gpio!               \ GPIOa, GPIOc & GPIOd for SPI
    2dup 2 +    gpio!
         3 +    gpio!
    5 dm 13 gpio!                   \ Enable SIO on pin 10 (CS)
    5 dm 16 gpio!                   \ Enable SIO on pin 11 (DC)
    5 dm 17 gpio!                   \ Enable SIO on pin 02 (RES)
    [ dm 13 bitmask  dm 16 bitmask  \ These bits are outputs
    dm 17 bitmask or or ] literal
    gpio-oe **bis
    [ dm 13 bitmask dm 16 bitmask   \ And all high
    [ dm 17 bitmask or or ] literal
    gpio-out **bis  dm 62500 khz>   \ Clock = 62.5 MHz
    0007 or  'spi !                 \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 'spi cell+ **bic              \ SSPCR1    Disable SSE
    2 'spi cell+ !                  \ SSPCR1    Synchronous master
    'spi 10 + ! ;                   \ SSPCPSR   clock prescaler

: RESET         ( -- )              \ Restart the LCD
    dm 17 bitmask gpio-out **bic  20 us
    dm 17 bitmask gpio-out **bis ;

[then]


: COLUMNS       ( xs xe -- )    b-b  rot 1- b-b  4 2A cmd+ ;
: ROWS          ( ys ye -- )    b-b  rot 1- b-b  4 2B cmd+ ;

v: extra definitions
: LCD-INIT      ( -- )
    tft-init reset hx A0 ms \ Startup
    01 cmd      dm 150 ms   \ Software reset
    11 cmd      dm 150 ms   \ Exit sleep mode
    55 3A cmd1  dm 010 ms   \ 16-bit color mode
    00 36 cmd1              \ Refresh is bottom to top
    0  dm 240 columns       \ 18 01 00 00 4 2A cmd+   \ Column parameters
    0  dm 280 rows          \ F0 00 00 00 4 2B cmd+   \ Row parameters
    21 cmd      dm 10 ms    \ Inverse screen display
    13 cmd      dm 10 ms    \ Normal display on
    29 cmd      dm 150 ms ; \ Main screen on

: &FILL         ( c +n -- )
    1 dm 240 columns  10 dm 302 rows
    >r  b-b  r>  2C {cmd  fill) spi} ;

: &PAGE         ( -- )      0 dm 72000 &fill ;

v: fresh
shield ST7789\  freeze
%%

chapter ST7789DEMO\
need [undefined]
need [if]

[undefined] ST7789\ [if]
    dm 16  need ST7789\
[then]

v: fresh
: DEMO1
    lcd-init  &page
    begin
        001F dm 72500 &fill  200 ms
        07E0 dm 72500 &fill  200 ms
        F800 dm 72500 &fill  200 ms
        FFF0 dm 72500 &fill  200 ms
        FFFF dm 72500 &fill  200 ms
    key? until
    &page ;

: DEMO2
    lcd-init  &page  0
    begin
        begin
            dup 001F < if  dup dm 72500 &fill  20 ms  1+    else
            dup 07FF < if  dup dm 73250 &fill  20 ms  20 +  else
            dup FFFF < if  dup dm 72500 &fill  20 ms  800 + else
            then  then  then
        dup FFFF = until  key? if &page drop exit then  100 ms
        begin
            dup FFE0 > if  dup dm 72500 &fill  20 ms  1-    else
            dup F800 > if  dup dm 72500 &fill  20 ms  20 -  else
            dup 0000 > if  dup dm 72500 &fill  20 ms  800 - else
            then  then  then
        dup 0= until  100 ms
    key? until
    drop  &page ;

shield ST7789DEMO\
%%

chapter MOVIE\
hex v: inside also
create PICT0  dm 44,000 allot  \ Picture output test buffer

    0 value SIZE
    0 value IDX             \ Compile index

: END0   align  0 to idx  decimal ;
: PH,    idx h!  2 +to idx ;

: -PIC      ( addr -- )
    to idx  hex
    begin 0. bl-word count >number nip nip
    0= while ph,   repeat drop  end0 ;

: TEST0      ( "ccc" -- )    pict0  -pic ; \ Load test picture in RAM buffer


\ ----- 343>565 decompressie rrrg gggb bbnn nnnn
\ rrrg gggb bbnn nnnn -> rrrr rggg gggb bbbb +n
decimal
: C-COMMAS ( -- ) begin 0. bl-word count >number nip nip
                  0= while c,   repeat drop ;
0 [if]

create ROOD3>5  c-commas 0 5 10 15 19 23 27 31 |
\        ( 0 )  c-commas 0 4 8 12 16 20 25 31 |
create GROEN4>6 c-commas 0 5 10 15 19 23 27 31 35 39 43 47 51 55 59 63 |
\        ( 8 )  c-commas 0 4 8 12 16 20 24 28 32 36 40 44 48 53 58 63 |
create BLAUW3>5 c-commas 0 5 10 15 19 23 27 31 |
\        ( 24 ) c-commas 0 4 8 12 16 20 25 31 |
:  DECOMPR ( 16b -- color +n )
    >r r@ 13 rshift  7 and rood3>5  + c@ 11 lshift
    r@     9 rshift 15 and groen4>6 + c@  5 lshift  or
    r@     6 rshift  7 and blauw3>5 + c@  or
    r> 63 and ; ( Number of the same pixels )

[else]

create DECOMPR ( 16b -- color +n ) \ W contains pointer to color tables (35 cycles)
    ( 0 )  c-commas 0 5 10 15 19 23 27 31 |
    ( 8 )  c-commas 0 5 10 15 19 23 27 31 35 39 43 47 51 55 59 63 |
    ( 24 ) c-commas 0 5 10 15 19 23 27 31 |
code>
(* Convert RED (7 cycles)
    day tos dm 13 lsrs.mv,  \ 1 Get 3-bit red color to DAY
    sun 7 # movs,           \ 1 Mask other bits
    day sun ands,           \ 1
    day w adds,             \ 1 Calc. color table
    day  day ) ldrb,        \ 2 Convert red color
    hop day dm 11 lsls.mv,  \ 1 To correct position
\ Convert GREEN (9 cycles)
    day tos dm 09 lsrs.mv,  \ 1 Get 4-bit green color to DAY
    sun hx 0F # movs,       \ 1 Mask other bits
    day sun ands,           \ 1
    day w adds,             \ 1 Calc. color table
    day 8 # adds,           \ 1
    day  day ) ldrb,        \ 2 Convert green color
    moon day dm 5 lsls.mv,  \ 1 To green table
    hop moon orrs,          \ 1 Add to red color
\ Convert BLUE (8 cycles)
    day tos dm 06 lsrs.mv,  \ 1 Get 3-bit blue color to DAY
    sun 7 # movs,           \ 1 Mask other bits
    day sun ands,           \ 1
    day w adds,             \ 1 Calc. color table
    day dm 24 # adds,       \ 1 To blue table
    day  day ) ldrb,        \ 2 Convert blue color
    hop day orrs,           \ 1 Add to other colors
\ Put result on the stack (11 cycles)
    hop  sp -) str,         \ 3
    hop hx 3F movs,         \ 1 Leave +n ( number of the same bits )
    tos hop ands,           \ 1
    next,                   \ 6
*)
hex
    26070B5D ,  18AD4035 ,  2EC782D ,
    260F0A5D ,  18AD4035 ,  782D3508 ,  433C016F ,
    2607099D ,  18AD4035 ,  782D3518 ,  3904432C ,
    243F600C ,  C8044023 ,  46A7CA10 ,
end-code

[then]

: FULLSCREEN    ( -- )
    2A {cmd  0. 2>lcd   F0. 2>lcd  spi}   \ 00 240
    2B {cmd  7. 2>lcd  2C 1 2>lcd  spi} ; \ 07 300

v: inside also
: .ROW      ( color +n -- ) \ Print pixel row
    for  dup b-b 2>lcd  next  drop ;

20 value SPEED
: .FRAME    ( a1 -- a2 )    \ Print next picture frame
    fullscreen  hx 2C {cmd
    h@+ 2/ 0 ?do  h@+ decompr .row  loop  spi}  speed ms ;

: >FRAME    ( a +n -- ) >r  h@+ r> umin for  h@+ +  next  .frame drop ; \ Print from picture 'a' frame +n
: FORW      ( a -- )  h@+ for  .frame  next  drop ;             \ Play movie 'a' once forward
: BACKW     ( a -- )  dup h@ for  dup i >frame  next  drop ;    \ Play movie 'a' once backward
: MOVIE     ( a -- )  lcd-init  &page  begin  dup forw  key? until  drop ;   \ Movie 'a' endlessly
: BACKWARD  ( a -- )  lcd-init  &page  begin  dup backw   key? until  drop ; \ Movie 'a' endlessly backward

: TRY       ( a -- )    \ Test movie frame by frame
    lcd-init  &page
    begin
        cr  dup h@+ 0 ?do
            .frame  cr  dup u.  i .
            key bl <> if unloop 2drop exit then
        loop  drop
    again ;

: DECOM     ( a -- )   \ Show pixel contents of movie 'a' one by one
    h@+ ." Frames " .
    h@+ ." Runs " dup . ." / "  2/ .
    begin
        h@+
        cr ." Code " dup .  decompr
        ." kleur " >r u.  ." pixels " r> u.
        key bl <> if  drop exit  then
    again ;

: TEST      ( a -- )    \ Test movie 'a' on correct structure
    0 to idx  h@+ 0 ?do     \ Read number of frames
        0 to size           \ Measure real pixel size
        h@+ cr dup u.       \ Show frame size
        dup +to idx         \ Add frame
        2/ 0 ?do            \ Handle frame
            h@+ decompr +to size  drop  ( a )
        loop
        size u.             \ Show total nr. of pixels
    loop  drop  cr idx .  end0 ; \ Show size of movie

v: fresh
shield MOVIE\
%%

chapter WRITEMOV\
( flashsize-in-Mbit -- )

(* Build or extend a movies, size: 1312 bytes

Movie writer basic words:

WIPE-MOV    ( Erase movies from flash )
OPEN-MOV    ( Allow adding more movies, execute before sending source! )
CLOSE-MOV   ( Save remaning movie sector and close for writing )
FRAMES      ( Read movie source frames to dedicated Flash memory )
END         ( End of a movie file )
.FREE       ( Free flash size left for next movie )

Each movie gets a constant that hold it's start address
Each movie starts at a 0x1000 rounded border
The first megabyte is for noForth and the libraries so
the minimal space for movies is 1 Mbyte to 16 Mbyte

Usage:
    First check if there is enough space in the Flash memory!

    1) WIPE-MOV when starting anew
    2) NEW-MOV "name" create a new named flash movie
    3) Send file source starting with: FRAMES  #pictures #pixels .. pixel data ..  END
    4) More files go to 2) etc.

*)

need [if]
depth 0= [if]  dm 16  [then]        \ No data take smallest Flash size

dup dm 16 =  [if]
    1020,0000 constant FLASH-END    \ 16 megabit flash
[then]
dup dm 32 =  [if]
    1040,0000 constant FLASH-END    \ 32 megabit flash
[then]
dup dm 64 =  [if]
    1080,0000 constant FLASH-END    \ 64 megabit flash
[then]
    dm 128 = [if]
    1100,0000 constant FLASH-END    \ 128 megabit flash
[else]
    abort
[then]

here  hex
v: inside also  definitions
  1000,0000 constant XIP        \ Start of XIP memory
  1010,0000 constant MOV        \ Start of movie
  mov       value MOVHERE       \ Movie memory pointer
create BUFFER  180 allot        \ Sector buffer with overflow (noForth t)
0           value PTR           \ Buffer index
: LH,       buffer ptr + h!  2 +to ptr ;  ( h -- )

v: forth definitions
: END       ;                   \ Dummy
: .FREE     flash-end movhere - . ;

v: inside definitions
: MOVWRITE      ( +n -- )   \ Write movie sector
    movhere xip - buffer 100 write-flash \ Write mov. sector to flash
    dup +to movhere   negate +to ptr    \ To next mov. block & correct pointer
    buffer 100 FF fill                  \ Erase first buffer
    buffer 100 + buffer ptr move ;      \ Move overflow to sector buffer

: BUFFER-FULL   ( -- )      \ Buffer overflow, write & restore
    ptr FF > if  100 movwrite  then ;

v: forth definitions
: NEW-MOV       ( "name" -- )   \ Create new movie for writing
    movhere  constant           \ Name movie too
    0 to ptr  {w ;              \ First movie entry, open flash

: CLOSE-MOV     ( -- )          \ Close movie, save unfinshed buffer too
    buffer-full  ptr movwrite  W} \ Write last sector if any & close flash
    movhere FFF +  FFFFF000 and \ Round MOVHERE to next 0x1000 erase page
    to movhere ;

: WIPE-MOV      ( -- )          \ Remove previous stored movies from flash
    mov xip -                   \ Convert to start sector address
    movhere mov -  FFF000 and   \ Convert to erase sector length, max. 16 Mbyte
    {W  wipe-flash  W}          \ Erase all used sectors
    mov to movhere ;            \ And reset movie pointer

: FRAMES        ( -- )          \ Read file source with movie data to Flash
    hex  0 to ptr
    begin
        0. bl-word count        \ Read next word
        >number nip nip         \ Convert to number
    0= while                    \ Succeed?
        lh,   buffer-full       \ Save in block & write when full
    repeat  drop  close-mov ;   \ No number? Save & close file

v: fresh
shield WRITEMOV\  freeze
here swap - dm .
%%


chapter BAMBOE\
( pin #bamboe -- )

(* Bamboe is an interface based on the 74HC(T)4094 or CD4094

One or more 4094 shift register chips may be in series with each other.
Thus, the number of output bits is increased by eight with each chip.

*)

need [if]
depth 2 < [if]  .(  Need GPIO-pin and the number of bamboe's )  2drop  [then]
>r  dup dm 20 > [if]  drop 6  [then]  >r

hex  v: inside also  definitions
D0000020    constant GPIO-OE        \ GPIO output enable
D0000010    constant GPIO-OUT       \ GPIO output value

r@      bitmask constant STR        \ Bamboe uses three I/O bits
r@ 1+   bitmask constant OUT
r@ 2 +  bitmask constant CLK

v: extra definitions
: BAMBOE-ON ( -- )
    5A dm [ r@ ] literal      pads! \ Enable strobe output on pin
    5A dm [ r@ 1+ ] literal   pads! \ Enable data output on pin + 1
    5A dm [ r> 2 + ] literal  pads! \ Enable clock output on pin + 2
    [ str out clk or or ]
    literal  gpio-oe **bis ;  bamboe-on

: READY     ( -- )      \ Copy serial clocked in bits to the parallel outputs
    str gpio-out **bis 1 us str gpio-out **bic ;

: >BAMBOE   ( b -- )    \ Shift one byte out
    dm 24 lshift                \ Data to high byte
    8 for                       \ 8 bits
        dup 0< if               \ Highest bit set?
            out gpio-out **bis  \ Data high
        else
            out gpio-out **bic  \ data low
        then
        clk gpio-out **bic      \ Clock low
        clk gpio-out **bis      \ Clock high
        2*                      \ Next bit
    next  drop ;

v: inside definitions
r> constant #B          \ Number of used bamboe's
#B 8 * constant #BITS   \ Total number of I/O bits
v: extra definitions
create BITS  #BITS allot  align \ Bit mirror for bamboe

: >BB       ( -- )      \ Copy mirror to bamboe
    #B for
        bits i + c@ >bamboe
    next  ready ;

v: inside definitions
: LOC       ( +n a1 -- bit a2 ) \ Bit location in byte-address a2
    over 3 rshift +  >r         \ Convert to byte addresses
    07 and bitmask  r> ;        \ Convert low nibble to bit mask

v: extra definitions
: ZERO      ( -- )          bits #B 0 fill ; \ Fill mirror with zeros
: SET       ( +n a -- )     loc *bis ;  \ Set bit +n in the mirror
: CLR       ( +n a -- )     loc *bic ;  \ Clear bit +n in the mirror

v: fresh
shield BAMBOE\
%%


v: inside
libhere 1-  to pio)
v: fresh


\ Extend library with PIO example programs, about 79 kBytes

chapter BIT-TOGGLE1
( sm pio gpio -- ) \ Bit toggle using set. The flash loop is done using wrap!

need [if]
depth 3 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
\ Slow pulse on the LED mounted on GPIO  with wrapping
( sm pio ) {pio             \ Use state machine-a on PIO-b
    2000 =freq              \ On 2000 Hz frequency
    r> 2 =set-pins          \ GPIO pin & pin+1 for SET
    3 pindirs set,          \ Both pins are outputs
    wrap-target
        7 [] 3 pins set,    \ LED on, pin & pin+1 on
        7 [] 31 y set,      \ Max. delay using Y
        begin,
            7 [] 0 pins set, \ LED & pin off
        7 [] y--? until,    \ Wait longer
    wrap
    over =exec              \ Start code at begin address
pio}
%%


CHAPTER BIT-TOGGLE2
( gpio -- ) \ Bit toggle using Side-set optional & SET.
\ The flash loop is done using wrap!

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
\ Slow pulse on the LED mounted on GPIO 25 & 26 with wrapping
0 0 {pio                    \ Use state machine-a on PIO-b
    2000 =freq              \ On 2000 Hz frequency
    r@ 1+ 1 =side-pins  opt \ GPIO pin+1 for SIDE
    r> 2 =set-pins          \ GPIO pin & pin+1 for SET
\ Program
    3 pindirs set,                  \ Both pins are outputs
    begin, again,                   \ Wait loop
    wrap-target
        1 side  7 [] 1 pins set,    \ LED on (pin & pin+1 on)
        7 [] 31 y set,              \ Max. delay using Y
        begin,
            7 [] 0 pins set,        \ LED (pin & pin+1 off)
        7 [] y--? until,            \ Wait longer
    wrap
    0 =exec                 \ Start SM code at address 0
pio}

hex
: FLASH    2 0 exec-opc ;                   \ Jump to address 2, start flasher
: LED-OFF  1 0 exec-opc  E000 0 exec-opc ;  \ Pin 25 off, jump to wait loop
: LED-ON   1 0 exec-opc  E001 0 exec-opc ;  \ Pin 25 on, jump to wait loop
flash
%%


CHAPTER BIT-TOGGLE3
( gpio -- ) \ Bit toggle on GPIO using Side-set & SET both using OPT:
\ This program initialises the IO-pins, then goes into a wait loop
\ Also an example of program control executing opcodes directly!

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
\ Slow pulse on the LED mounted on GPIO 25 and a pulse on GPIO 26
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ 1+ 1 =side-pins  opt \ GPIO+1 for SIDE
    r> 2 =set-pins          \ GPIO & GPIO+1 for SET
\ Program
    3 pindirs set,                  \ Both pins are outputs
    3 pins set,                     \ Start with the LED & pin on
    begin, again,                   \ Wait loop
    begin,
        1 side  7 [] 1 pins set,    \ LED on (pin 25 & 26 on)
        7 [] 31 y set,              \ Max. delay using Y
        begin,
            7 [] 0 pins set,        \ LED (pin 25 & 26 off)
        7 [] y--? until,            \ Wait longer
    again,

    0 =exec                 \ Start SM-0 program at address 0
pio}

hex
: FLASH    3 0 exec-opc ;                   \ Jump to address 3, start flasher
: LED-OFF  2 0 exec-opc  F000 0 exec-opc ;  \ Pin 25 & 26 off, jump to wait loop
: LED-ON   2 0 exec-opc  F801 0 exec-opc ;  \ Pin 25 & 26 on, jump to wait loop
%%


chapter IN&OUT1
( gpio -- ) \ After a key press on GPIO, the LED on GPIO+1 stays on for one second

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Read pin & write pin on sm-0 & PIO-0
    2000 =freq          \ On 2000 Hz frequency
    r@ =in-pin              \ GPIO as input pin base
    r@ 2 =set-pins          \ GPIO & GPIO+1 are used pins
    1 r@ 1 =inputs          \ Pull-up on input

    2 pindirs set,          \ GPIO = input, GPIO+1 = output
    2 pins set,             \ GPIO+1 = (LED) on
    begin,
\       low r> gpio wait,   \ Wait for key on GPIO
        low 0 pin wait,     \ Wait for key on GPIO
        2 pins set,         \ Set GPIO+1 = (LED) high
        31 y set,           \ Delay a while
        begin,
            31 []  nop,
        31 []  y--? until,
        0 pins set,         \ Set GPIO+1 = (LED) off
    again,
    0 =exec
pio}
%%


chapter IN&OUT2
( gpio -- ) \ In/Out program-2: Using MOV only, shortest functional program
\ The LED on GPIO+1 goes on when GPIO goes low, and off when high

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ I/O using sm-0 & PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ =in-pin              \ GPIO as input pin base
    r@ 2 =set-pins          \ GPIO & GPIO+1 are used pins
    r@ 1+ 1 =out-pins       \ GPIO+1 as OUT pin base
    1 r> 1 =inputs          \ Pull-up on input

    2 pindirs set,          \ GPIO is input, GPIO+1 is output
    wrap-target
        31 []  pins inv pins mov, \ Copy GPIO inverted to GPIO+1 & debounce 16 millisec.
    wrap

    0 =exec
pio}
%%


chapter IN&OUT3
( gpio -- ) \ In/Out program-3: Using WAIT for low MOV and WAIT for high
\ The LED on GPIO+1 goes on/off after a key press on GPIO with debouncing

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r  \ Always a valid GPIO pin?

need pio\

\ In/Out program-3: Third program using input & ouput
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ I/O using sm-0 & PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ 1+ =in-pin           \ GPIO+1 as input pin base
    r@ 1+ 1 =out-pins       \ GPIO+1 as OUT pin base
    r@ 2 =set-pins          \ Administer both used pins for SET
    1 r@ 1 =inputs          \ Pull-up on input

    2 pindirs set,          \ GPIO is input, GPIO+1 is output
    wrap-target
        31 []  low r@ gpio wait,  \ Wait for key on GPIO pressed
        31 []  pins inv pins mov, \ Copy GPIO+1 inverted to GPIO+1 & debounce 16 millisec.
        31 []  high r> gpio wait, \ wait for key on GPIO to be released
    wrap

    0 =exec
pio}
%%


chapter IRQ-1
( gpio -- ) \ Example-1 of: Two communicating programs using IRQ
\
\ rel IRQ on sm-1
\    IRQ: 0 off, 1 on,  2 on,  3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\    IRQ: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\
\ Normal IRQ: on sm-1
\    IRQ: 0 off, 1 on,  2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\    IRQ: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
\ IRQ clear using an input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ =jmp-pin             \ GPIO as input pin base
    r@ 1 =set-pins
    1 r@ 1 =inputs          \ Pull-up on input

    0 pindirs set,              \ GPIO is input
    begin,
        31 [] pin? if,          \ GPIO low?
            1 clr irq,          \ Clear interrupt
            31 [] high r@ gpio wait, \ Wait until GPIO high
        then,
    again,

    0 =exec                 \ Start SM-0 code at address 0
pio}

1 0 {pio    \ Toggle LED after an IRQ
    2000 =freq              \ On 2000 Hz frequency
    r@ 1+ =in-pin           \ GPIO+1 as input pin base
    r@ 1+ =out-pins
    r> 1+ =set-pins         \ GPIO+1 for SET
                            \ Program starts here
    1 pindirs set,          \ GPIO+1 is output
    begin,
        1 wait irq,         \ Wait until IRQ 1 is low
        pins inv pins mov,  \ Invert GPIO+1, is LED on/off
    again,

    over =exec              \ Start SM-1 code at address from stack
pio}
%%


chapter IRQ-2
( gpio -- ) \ Example-2 of: Two communicating programs using IRQ, using wrap
\
\ rel IRQ on sm-1
\    IRQ: 0 off, 1 on,  2 on,  3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\    IRQ: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\
\ Normal IRQ: on sm-1
\    IRQ: 0 off, 1 on,  2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\    IRQ: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r  \ Always a valid GPIO pin?

need pio\

clean-pio  decimal          \ Empty code space mirror
\ IRQ clear using an input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ =jmp-pin             \ GPIO as input pin base
    r@ 1 =set-pins
    1 r@ 1 =inputs          \ Pull-up on input

    0 pindirs set,                  \ GPIO is input
    wrap-target
        begin,  31 []  pin? until,  \ GPIO low?
        1 clr irq,                  \ Clear interrupt
        31 []  high r@ gpio wait,   \ Wait until GPIO high
    wrap
    over =exec              \ Start SM-0 code at address from stack
pio}

1 0 {pio    \ Toggle LED after an IRQ
    2000 =freq              \ On 2000 Hz frequency
    r@ 1+ =in-pin           \ GPIO+1 as input pin base
    r@ 1+ 1 =out-pins
    r> 1+ 1 =set-pins       \ GPIO+1 for SET
                            \ Program starts here
    1 pindirs set,          \ GPIO+1 is output
    1 pins set,             \ GPIO+1 LED off
    wrap-target
        1 wait irq,         \ Wait until IRQ 1 is low
        pins inv pins mov,  \ Invert GPIO+1, is LED on/off
    wrap
    over =exec              \ Start SM-1 code at address from stack
pio}
%%


chapter MUSIC-0
( gpio -- ) \ Frequency generation with TIMBRE on GPIO to GPIO+3 using
\ optional side-set. The TIMBRE reference value is stored in ISR
\ Frequency: 8Hz to 20kHz, timbre range: 0 to 100

need [if]
depth 1 < [if] abort [then]
dup dm 27 2 within [if]  drop  dm 26  [then] >r \ Always a valid GPIO pin row

need pio\

decimal
: HZ        ( hz sm -- )        >r  dm 300 *  r> freq ;

clean-pio                   \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    200 0 hz                \ State machine 0 starts on 60kHz
    r@ 1 =side-pins  opt    \ GPIO for side-set
    r@ 1 =set-pins          \ GPIO for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    1 pindirs set,              \ GPIO is output
    25 y set,                   \ Set TIMBRE range first Y
    y isr mov,                  \ Y register to ISR
    2 null in,                  \ ISR = 25 * 4 = 100
    begin,
        0 side  noblock  pull,  \ New timbre width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            1 side  else,
                nop,
            then,
        y--? until,             \ Count one TIMBRE cycle
    again,
    0 =exec                 \ Start SM-0 program at address 0
pio}

1 0 {pio        \ Freq. output on GPIO+1, on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    300 1 hz                \ State machine 0 starts on 90kHz
    r@ 1+ 1 =side-pins  opt \ GPIO+1 for side-set
    r@ 1+ 1 =set-pins       \ GPIO+1 for SET
    0 =in-dir               \ Shift ISR to left!
    0 =exec                 \ Start SM-1 at address 0 too
pio}
2 0 {pio        \ Freq. output on GPIO+2, on sm-2 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-2
    400 2 hz                \ State machine 0 starts on 120kHz
    r@ 2 + 1 =side-pins  opt \ GPIO+2 for side-set
    r@ 2 + 1 =set-pins      \ GPIO+2 for SET
    0 =in-dir               \ Shift ISR to left!
    0 =exec                 \ Start SM-2 at address 0 too
pio}
3 0 {pio        \ Freq. output on GPIO+3, on sm-3 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-3
    500 3 hz                \ State machine 0 starts on 150kHz
    r@ 3 + 1 =side-pins  opt \ GPIO+3 for side-set
    r> 3 + 1 =set-pins      \ GPIO+3 for SET
    0 =in-dir               \ Shift ISR to left!
    0 =exec                 \ Start SM-3 at address 0 too
pio}

\ The TIMBRE range is 0 to 100, 0 is output off, 50 is a square wave.
: TIMBRE    ( +n sm -- )        >r  100 umin  dup 0= +  r> >txf ;

: SWEEP     ( hz step -- )  \ Generate a range of increasing frequencies
    1 0 sm-on  swap         \ Max frequency on top
    20 ?do  i 0 hz  dup ms  50 +loop
    drop  500 ms  0 0 sm-on ;

: SWOOP     ( hz1 step -- )
    1 0 sm-on  1 1 sm-on  swap
    20 ?do  i 0 hz  i 2* 1 hz  dup ms  50 +loop
    drop  500 ms  0 0 sm-on  0 1 sm-on ;
%%


chapter ON&OFF-1
( gpio -- ) \ Example of: PIN? IF, then toggles a LED using MOV
\ Led keeps on flashing when GPIO 24 stays low

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r \ Always a valid GPIO pin row

need pio\

clean-pio  decimal          \ Empty code space mirror
\ LED on/off using in input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ =jmp-pin             \ Input pin for jump
    1 r@ 1 =inputs          \ Pull-up on input
    r@ 1+ =in-pin
    r@ 1+ 1 =out-pins
    r> 2 =set-pins          \ GPIO for SET

    2 pindirs set,              \ GPIO+1 is output
    2 pins set,                 \ GPIO+1 LED on
    begin,
        31 []  pin? if,         \ GPIO low?
            pins inv pins mov,  \ Invert GPIO+1, LED on/off
            31 x set,           \ Delay ~500 millisec.
            begin,
            31 []  x--? until,
        then,
    again,

    0 =exec                 \ Start SM-0 code at address 0
pio}
%%


chapter ON&OFF-2
( gpio -- ) \ Example of: PIN? IF, then toggles a LED using MOV, with debouncing

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r \ Always a valid GPIO pin row

need pio\

clean-pio  decimal          \ Empty code space mirror
\ LED on/off using in input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ =jmp-pin             \ Input pin for jump
    1 r@ 1 =inputs          \ Pull-up on input
    r@ 1+ =in-pin
    r@ 1+ 1 =out-pins
    r> 2 =set-pins          \ GPIO+1 for SET

    2 pindirs set,              \ GPIO+1 is output
    2 pins set,                 \ GPIO+1 LED on
    begin,
        31 []  pin? if,         \ GPIO low?
            pins inv pins mov,  \ Invert GPIO+1, LED on/off
            begin,              \ Pin released again?
            31 []  pin? while,  \ With debouncing
            31 []  repeat,
        then,
    again,

    0 =exec                 \ Start SM-0 code at address 0
pio}
%%


chapter ON&OFF-3
( gpio -- ) \ Example of: PIN? IF, then toggles a LED using MOV, release check using WAIT,

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 24  [then] >r \ Always a valid GPIO pin row

need pio\

clean-pio  decimal          \ Empty code space mirror
\ LED on/off using in input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    r@ =jmp-pin             \ Input pin for jump
    1 r@ 1 =inputs          \ Pull-up on input
    r@ 1+ =in-pin
    r@ 1+ 1 =out-pins
    r@ 1+ 1 =set-pins       \ GPIO+1 for SET

    1 pindirs set,              \ GPIO+1 is output
    1 pins set,                 \ GPIO+1 LED on
    begin,
        31 []  pin? if,         \ GPIO low?
            pins inv pins mov,  \ Invert GPIO+1, LED on/off
            31 [] high r> gpio wait, \ GPIO released again? With debouncing
        then,
    again,

    0 =exec                 \ Start SM-0 code at address 0
pio}
%%


chapter PWM-1
( sm pio gpio -- ) \ Add Low frequency PWM to the desired state machine
\ 1000 Hz PWM, range 0 to 100 on GPIO & GPIO+1 using optional side-set
\ This program stores the PWM reference value in ISR

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r \ Always a valid GPIO pin row
over constant #PWM \ Selected state machine

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ 1 kHz PWM, range 0 to 100
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    300000 =freq            \ State machine sm runs on 300kHz
    r@ 2 =side-pins  opt    \ GPIO & GPIO+1 for side-set
    r> 2 =set-pins          \ GPIO & GPIO+1 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    3 pindirs set,              \ Both pins are outputs
    25 y set,                   \ Set PWM range first Y
    y isr mov,                  \ Y register to ISR
    2 null in,                  \ ISR = 25 * 4 = 100
    begin,
        0 side  noblock  pull,  \ New pulse width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            3 side  else,
                nop,
            then,
        y--? until,             \ Count one PWM cycle
    again,
    over =exec              \ Start SM-0 program at begin address
pio}

\ The PWM range is 0 to 100, 0 is outputs off, 100 is maximal on.
\ Note that the value 0 is corrected to -1, that sets the PWM completely off
: >PWM  ( n -- )    100 umin  dup 0= +  #pwm >txf ;
%%


chapter PWM-2
( sm pio gpio -- ) \ Add Low frequency PWM to the desired state machine
\ 1000 Hz PWM, range 0 to 200 on GPIO & GPIO+1 using optional side-set
\ This program stores the PWM reference value in ISR

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r \ Always a valid GPIO pin row
over constant #PWM \ Selected state machine

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ 1 kHz PWM, range 0 to 200
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    600000 =freq            \ State machine sm runs on 600kHz
    r@ 2 =side-pins  opt    \ GPIO & GPIO+1 for side-set
    r> 2 =set-pins          \ GPIO & GPIO+1 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    3 pindirs set,              \ Both pins are outputs
    25 y set,                   \ Set PWM range first Y
    y isr mov,                  \ Y register to ISR
    3 null in,                  \ ISR = 25 * 8 = 200
    begin,
        0 side  noblock  pull,  \ New pulse width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            3 side  else,
                nop,
            then,
        y--? until,             \ Count one PWM cycle
    again,
    over =exec              \ Start program at address 0
pio}

\ The PWM range is 0 to 200, 0 is outputs off, 200 is maximal on.
\ Note that the value 0 is corrected to -1, that sets the PWM completely off
: >PWM  ( n -- )    200 umin  dup 0= +  #pwm >txf ;
%%


chapter PWM-3
( sm pio gpio -- ) \ Add Low frequency PWM to the desired state machine
\ 1000 Hz PWM, range 0 to 400 on GPIO & GPIO+1 using optional side-set
\ This program stores the PWM reference value in ISR

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r \ Always a valid GPIO pin row
over constant #PWM \ Selected state machine

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ 1 kHz PWM, range 0 to 400
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    1200000 =freq           \ State machine sm runs on 1200kHz
    r@ 2 =side-pins  opt    \ GPIO & GPIO+1 for side-set
    r> 2 =set-pins          \ GPIO & GPIO+1 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    3 pindirs set,              \ Both pins are outputs
    25 y set,                   \ Set PWM range first Y
    y isr mov,                  \ Y register to ISR
    4 null in,                  \ ISR = 25 * 16 = 400
    begin,
        0 side  noblock  pull,  \ New pulse width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            3 side  else,
                nop,
            then,
        y--? until,             \ Count one PWM cycle
    again,
    0 =exec                 \ Start program at address 0
pio}

\ The PWM range is 0 to 400, 0 is outputs off, 400 is maximal on.
\ Note that the value 0 is corrected to -1, that sets the PWM completely off
: >PWM  ( n -- )    400 umin  dup 0= +  #pwm >txf ;
%%


chapter PWM-4
( sm pio gpio -- ) \ Add high frequency PWM to the desired state machine
\ 10000 Hz PWM, range 0 to 400 on GPIO & GPIO+1 using optional side-set
\ This program stores the PWM reference value in ISR

need [if]
depth 1 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 25  [then] >r \ Always a valid GPIO pin row
over constant #PWM \ Selected state machine

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ 10 kHz PWM, range 0 to 400
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    12000000 =freq          \ State machine sm runs on 12MHz
    r@ 2 =side-pins  opt    \ GPIO & GPIO+1 for SIDE-SET
    r> 2 =set-pins          \ GPIO & GPIO+1 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    3 pindirs set,              \ Both pins are outputs
    25 y set,                   \ Set PWM range first Y
    y isr mov,                  \ Y register to ISR
    4 null in,                  \ ISR = 25 * 16 = 400
    begin,
        0 side  noblock  pull,  \ New pulse width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            3 side  else,
                nop,
            then,
        y--? until,             \ Count one PWM cycle
    again,
    0 =exec                 \ Start SM-0 program at address 0
pio}

\ The PWM range is 0 to 400, 0 is outputs off, 400 is maximal on.
\ Note that the value 0 is corrected to -1, that sets the PWM completely off
: >PWM  ( +n -- )    400 umin  dup 0= +  #pwm >txf ;
%%


chapter ROTARY-0
( gpio -- ) \ Rotary encoder on state machine 0 and PIO 0
need [if]
depth 1 < [if] abort [then]
dup dm 28 2 within [if]  drop  dm 26  [then] >r \ Always a valid GPIO pin row
over constant #PWM \ Selected state machine

need pio\

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Encoder readout on sm-0 & PIO-0
    2000 =freq              \ 2 kHz clock
    r@ =in-pin              \ GPIO as input pin base
    1 r@ 3 =inputs          \ Pull-up on all inputs
    r> 3 =set-pins          \ Three pins used
    0 =out-dir

    0 pindirs set,          \ Only GPIO to GPIO+2 are input
    wrap-target
        7 y set,            \ Set no input value
        begin,
            pins osr mov,   \ Read inputs to OSR            .5
            29 null out,    \ Shift result to high 3 bits   .5
            3 x out,        \ Move to low 3 bits of X       .5
        x=y? while,         \ No change?                    .5
        repeat,             \ Read again                    .5
        x isr mov,          \ Change noticed, X to ISR
        push,               \ Output data to RX-fifo
    wrap
    0 =exec
pio}

: ENCODER?  ( -- f )        0 rx-depth  0= 0= ; \ True when encoder is used

\ 0 = Not turned, 1 = forward, -1 = backward, Press = true (Knob pressed)
: ENCODER   ( -- 1|-1 press )
    begin  encoder? until   \ Knob moved
    0 rxf>                  \ Read data, save knob pressed flag
    dup 4 and 0= >r         \ Save press switch
    3 and  dup 3 <> if      \ Knob turned?
        2 <>  -2 and 1+  r> exit \ 1 or -1  and press
    then
    dup -  r> ;             \ 0 and press
%%


chapter ENCODER-DEMO
pio  dm 26 need rotary-0

: DEMO      ( -- )          \ Show pulses up, down & knob pressed
    0  begin                \ Start at zero
        encoder if ." Press " then  + \ Show knob pressed
        dup .               \ Show counted pulses
    key? until ;

: TEST      ( -- )          \ Show generated pin codes
    begin
        begin  encoder? until
        0 rxf> .hex
    key? until ;
%%


chapter SPI-0
( sm pio clock gpio -- ) \ Add spi configuration beforehand!
\ Single 8-bit SPI on state machine 0 and PIO 0, Clock phase = 0
\ SCK  = Side-set pin 0, SPI clock = clock kHz
\ MOSI = OUT pin 0
\ MISO = IN pin 0

need [if]
depth 4 < [if] abort [then]
dup dm 27 2 within [if]  drop  dm 26  [then] \ Always a valid GPIO pin row
     >r >r          ( sm pio clock gpio -- sm pio )
over constant SM#   ( sm pio -- sm pio )

need pio\

( clean-pio ) decimal           \ Empty code space mirror
\ With Side-set for SCK
( sm pio ) {pio                 \ Use state machine-sm on PIO-pio
    r> dm 4000 * =freq          \ State machine frequency = clock * 4 kHz
    8 1 =autopush 8 1 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir       \ OSR & ISR shift left
    r@ 1 =side-pins             \ GPIO for SCK (SIDE)
    r@ 1+ 1 =out-pins           \ GPIO+1 for OUT
    r@ 2 + =in-pin              \ GPIO+2 for IN
    1 r@ 2 + 1 =inputs          \ Pull-up on input
    r> 3 =set-pins              \ Three pins used

    3 pindirs set,                  \ GPIO & GPIO+1 are outputs
    wrap-target
        1 []  0 side  1 pins out,   \ Output one bit, clock low
        1 []  1 side  1 pins in,    \ Input one bit, clock high
    wrap

    over =exec                  \ Start SM-sm at begin address
pio}

: >SPI  ( ch -- )   \ Byte to SPI
    begin  sm# tx-depth  3 < until  \ Space in fifo?
    24 lshift  sm# >txf ;           \ Yes, move data to highest byte & send

: SPI>  ( a u -- )  \ Byte from SPI
    begin  sm# rx-depth until   \ Received data present in fifo?
    SM# rxf> ;                  \ Yes, read out


\ Show SPI transport, connect pin GPIO+1 & GPIO+2 for this demo
: DEMO  ( -- )
    begin
        cr  30 0 ?do  i >spi  spi> .  loop  100 ms
    s? 0= until ;

v: inside
: .PIO      ( -- )          ."  PIO " pio? 1 and 1 .r ;

export
cr sm# .  .pio
%%


chapter SPI-1
( sm pio clock gpio -- ) \ Single 8-bit SPI with CSN on state machine 0 and PIO 0, Clock phase = 0
\ SCK  = Side-set pin 0, SPI clock = 125 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

need [if]
depth 5 < [if] abort [then]
dup dm 27 2 within [if]  drop  dm 26  [then] >r \ Always a valid GPIO pin row
     >r >r          ( sm pio clock gpio -- sm pio )
over constant SM#   ( sm pio -- sm pio )

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ With Side-set for SCK
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    r> dm 6000 * =freq      \ State machine frequency = clock * 6 kHz
    8 1 =autopush 8 0 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir   \ OSR & ISR shift left
    r@ 2 =side-pins         \ GPIO for SCK, GPIO+1 for CSN (SIDE)
    r@ 2 + 1 =out-pins      \ GPIO+2 for OUT
    r@ 3 + =in-pin          \ GPIO+3 for IN
    1 r@ 3 + 1 =inputs      \ Pull-up on input
    r> 4 =set-pins          \ Three pins used

    7 pindirs set,          \ Pin 26 to 28 are outputs
    wrap-target
        0 side  nop,
        begin,
            2 []  0 side  1 pins out,   \ Output one bit, clock low
            1 []  1 side  1 pins in,    \ Input one bit, clock high
        1 side  osre? until,
        0 side  nop,                    \ Gap
        1 []  2 side  pull,             \ CEN high again
    wrap

    over =exec              \ Start at address 0
pio}

: >SPI  ( ch -- )           \ Byte to SPI
    begin  sm# tx-depth  3 < until \ Space in fifo?
    24 lshift  sm# >txf ;   \ Yes, move data to highest byte & send

: SPI>  ( -- )              \ Byte from SPI
    begin  sm# rx-depth until \ Received data present in fifo?
    sm# rxf> ;              \ Yes, read out


\ Show SPI transport, connect GPIO+1 & GPIO+2 for this test
: DEMO  ( u -- )
    0 ?do  cr i .  i >spi  spi> .  loop ;
%%


chapter SPI-2
( sm pio clock gpio -- ) \ Add spi configuration beforehand!
\ Single 8-bit SPI with CSN on state machine sm and PIO pio, Clock phase = 0
\ SCK  = Side-set pin 0, SPI clock = 125 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

need [if]
depth 4 < [if] abort [then]
dup dm 27 2 within [if]  drop  dm 26  [then] \ Always a valid GPIO pin row
     >r >r          ( sm pio clock gpio -- sm pio )
over constant SM#   ( sm pio -- sm pio )

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ With Side-set for SCK
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    r> dm 6000 * =freq      \ State machine frequency = clock * 6 kHz
    8 1 =autopush 8 0 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir   \ OSR & ISR shift left
    r@ 2 =side-pins         \ GPIO for SCK, GPIO+1 for CSN (SIDE)
    r@ 2 + 1 =out-pins      \ GPIO+2 for OUT
    r@ 3 + =in-pin          \ GPIO+3 for IN
    1 r@ 3 + 1 =inputs      \ Pull-up on input
    r> 4 =set-pins          \ Three pins used

    7 pindirs set,          \ GPIO to GPIO+2 are outputs
    wrap-target
        0 side  nop,
        begin,
            2 []  0 side  1 pins out,   \ Output one bit, clock low
            1 []  1 side  1 pins in,    \ Input one bit, clock high
        1 side  osre? until,
        0 side  nop,                    \ Gap
        1 []  2 side  pull,             \ CEN high again
    wrap

    over =exec              \ Start at address 0
pio}

: >SPI  ( b -- )   \ Byte to SPI
    begin  sm# tx-depth  3 < until \ Space in fifo?
    24 lshift  sm# >txf ;   \ Yes, move data to highest byte & send

: SPI>  ( -- b )  \ Byte from SPI
    begin  sm# rx-depth until \ Received data present in fifo?
    sm# rxf> ;              \ Yes, read out

: SPI   ( b1 -- b2 )        >spi  spi> ;


\ Show SPI transport, connect GPIO+2 & GPIO+3 for this test
: DEMO  ( u -- )
    0 ?do  cr i .  i spi .  loop ;
%%


chapter SPI-3
( sm pio clock gpio -- ) \ Add spi configuration beforehand!
\ Single 8-bit SPI on state machine sm and PIO pio, Clock phase = 0
\ The chip select line is constructed using a normal GPIO-bit
\ SCK  = Side-set pin 0, SPI clock = 250 kHz
\ MOSI = OUT pin 0
\ MISO = IN pin 0
\ CSN  = Controlled by Forth software

need [if]
depth 3 < [if] abort [then]
dup dm 27 2 within [if]  drop  dm 26  [then] \ Always a valid GPIO pin row
     >r >r          ( sm pio clock gpio -- sm pio )
over constant SM#   ( sm pio -- sm pio )

need pio\

( clean-pio ) decimal       \ Empty code space mirror
\ With Side-set for SCK
( sm pio ) {pio             \ Use state machine-sm on PIO-pio
    r> dm 4000 * =freq      \ State machine frequency = clock * 4 kHz
    8 1 =autopush 8 1 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir   \ OSR & ISR shift left
    r@ 1 =side-pins         \ GPIO 26 for SCK (SIDE)
    r@ 1+ 1 =out-pins       \ GPIO 27 for OUT
    r@ 2 + =in-pin          \ GPIO 28 for IN
    1 r@ 2 + 1 =inputs      \ Pull-up on input
    r> 3 =set-pins          \ Three pins used

    3 pindirs set,                  \ Pin 26 to 28 are outputs
    wrap-target
        1 []  0 side  1 pins out,   \ Output one bit, clock low
        1 []  1 side  1 pins in,    \ Input one bit, clock high
    wrap

    0 =exec               \ Start at address 0
pio}

: >SPI  ( ch -- )   \ Byte to SPI
    begin  sm# tx-depth  3 < until \ Space in fifo?
    24 lshift  sm# >txf ;   \ Yes, move data to highest byte & send

: SPI>  ( a u -- )  \ Byte from SPI
    begin  sm# rx-depth until \ Received data present in fifo?
    sm# rxf> ;              \ Yes, read out


hex     \ Manual CHIP enable (active low)
D0000000 constant SIO_BASE
SIO_BASE 20 + constant GPIO-OE      \ GPIO output enable
SIO_BASE 10 + constant GPIO-OUT     \ GPIO output

20000000 gpio-out **bis  \ Disable CSN line (high) GPIO 29

\ Show SPI transport, connect pin 27 & 28 for this test
: DEMO  ( u -- )
    20000000 gpio-oe **bis                      \ Enable GPIO 29
    0 ?do
        cr  20000000 gpio-out **bic             \ Enable low
        i 4 over + do  i >spi spi>  i  -1 +loop \ Output SPI data record
        5 us  20000000 gpio-out **bis           \ Enable high
        5 0 do 2 .r space 2 .r 2 spaces  loop   \ Show data
    5 +loop ;
%%


chapter SPI-4
( gpio -- ) \ Single 8-bit SPI with CSN on state machine 0 and PIO 0, Clock phase = 0
\ Chip enable is done using side-set, data is input using pull.
\ The Y-register is used to count if a byte is transmitted.
\ SCK  = Side-set pin 0, SPI clock = 125 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

need pio\

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK & CSN
0 0 {pio                    \ Use state machine-0 on PIO-0
    500000 =freq            \ 500 kHz
    0 =out-dir              \ OSR shifts to left
    26 2 =side-pins  opt    \ GPIO 26 for SCK, 27 for CSN (SIDE)
    28 1 =out-pins          \ GPIO 28 for OUT
    29 =in-pin              \ GPIO 29 for IN
    1 29 1 =inputs          \ Pull-up on input
    26 4 =set-pins          \ Three pins used

    7 pindirs set,                  \ Pin 26 to 28 are outputs
    wrap-target
        1 []  2 side  pull,         \ CEN high, pop Byte No. in SPI record
        0 side  osr x mov,          \ Save in X
        begin,
            1 []  pull,             \ Next byte
            7 y set,
            begin,
                1 []  0 side  1 pins out, \ Output one bit, clock low
            1 []  1 side  y--? until,     \ Clock high
        0 side  x--? until,
    wrap

    0 =exec                         \ Start at address 0
pio}

: >SPI  ( b0..bn +n -- )   \ +n bytes to SPI
    begin  0 tx-depth  3 < until    \ Space in fifo?
    dup 1-  0 >txf
    0 ?do
        begin  0 tx-depth  3 < until
        24 lshift  0 >txf           \ Yes, move data to highest byte & send
    loop ;


\ Show SPI block output
: DEMO  ( u -- )
    cr  >r  0 r@ 1- do  i  i .  -1 +loop  r> >spi ;
%%


chapter SPI-5
\  Multiple 8-bit SPI blocks with CSN on state machine 0 and PIO 0, Clock phase = 0
\ Chip enable is done using side-set, data input is done using pull
\ OSRE? is used to check if a byte is transmitted.

\ SCK  = Side-set pin 0, SPI clock = 250 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

need pio\

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK & CSN
0 0 {pio                    \ Use state machine-0 on PIO-0
    1000000 =freq           \ SM-clock = 1 MHz
    8 0 =autopull           \ 8-bits data records, no auto-pull
    0 =out-dir              \ OSR shifts to left
    26 2 =side-pins  opt    \ GPIO 26 for SCK, 27 for CSN (SIDE)
    28 1 =out-pins          \ GPIO 28 for OUT
    29 =in-pin              \ GPIO 29 for IN
    1 29 1 =inputs          \ Pull-up on input
    26 4 =set-pins          \ Three pins used

    7 pindirs set,                  \ Pin 26 to 28 are outputs
    wrap-target
        2 []  2 side  pull,         \ CEN high, pop Byte No. in SPI record
        0 side  osr x mov,          \ Save in X
        begin,
            pull,                   \ Get next byte
            begin,
                1 []  0 side  1 pins out, \ Output one bit, clock low
            1 []  1 side  osre? until,
        0 side  x--? until,
    wrap

    0 =exec                         \ Start at address 0
pio}

: >SPI      ( x -- )    \ Store data 'x' when there is space in the fifo
    begin  0 tx-depth  3 < until  0 >txf ;

: SPI-TYPE  ( a u -- )              \ Send string of 'u' bytes as one block from addr. 'a'
    dup 1- >spi  bounds ?do
        i c@  24 lshift  >spi       \ Send one byte using SPI
    loop ;

: >ROW      ( b0..bn +n -- )        \ Send +n bytes from stack to SPI
    dup 1- >spi
    0 ?do  24 lshift  >spi  loop ; \ Move data to highest byte & send


\ Show SPI block output
: DEMO1     ( -- )          cr  8 0 do  i .  i  loop  8 >row ;
: DEMO2     ( -- )          s" Forth " 2dup type  spi-type ;
%%


chapter UART-0
\  Single UART on state machine 0 and PIO 0

need pio\

v: pios also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

clean-pio  decimal          \ Empty code space mirror
\ With optional Side-set
0 0 {pio                    \ Use state machine-0 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
    115200 =baud            \ 115k2
    26 1 =side-pins  opt    \ GPIO 26 for optional SIDE
    26 1 =out-pins          \ GPIO 26 for OUT & SET
    26 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap

    0 =exec                 \ Start SM-0 at address 0
pio}

: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;
%%

chapter UART-1
\ Dual UART on state machine 0 & 1 on PIO 0

need pio\

v: pios also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
    115200 =baud            \ 115k2
    26 1 =side-pins  opt    \ GPIO 26 for optional SIDE
    26 1 =out-pins          \ GPIO 26 for OUT & SET
    26 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap

    0 =exec                 \ Start SM-0 at address 0
pio}

: *EMIT     ( ch -- )   \ Character to PIO UART-0
    begin  0 tx-depth  3 < until  0 >txf ;

: *TYPE     ( a u -- )  0 ?do  count *emit  loop  drop ;
: ABC       ( -- )      s" ABC " *type ;
: RP2040    ( -- )      s" RP2040 " *type ;


1 0 {pio        \ Uart output on pin 27, 38k4 baud on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    38400 =baud             \ 38k4
    27 1 =side-pins  opt    \ GPIO 27 for optional SIDE
    27 1 =out-pins          \ GPIO 27 for OUT & SET
    27 1 =set-pins
    0 =exec                 \ Start SM-1 at address 0
pio}

: ~EMIT ( ch -- )   \ Character to PIO UART-1
    begin  1 tx-depth  3 < until  1 >txf ;

: ~TYPE     ( a u -- )  0 ?do  count ~emit  loop  drop ;
: BCD       ( -- )      s" BCD " ~type ;
: PICO      ( -- )      s" PICO " ~type ;
%%

chapter UART-2
\  Single UART, TX on state machine 0 & RX on state machine 1 of PIO 0

need pio\

v: pios also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
    115200 =baud            \ 115k2
    26 1 =side-pins  opt    \ GPIO 26 for optional SIDE
    26 1 =out-pins          \ GPIO 26 for OUT & SET
    26 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

1 0 {pio                    \ Use state machine-1 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
    115200 =baud            \ 115k2
    27 =jmp-pin
    27 =in-pin              \ GPIO 27 for IN & SET
    1 27 1 =inputs          \ Pull-up on input
    27 1 =set-pins

    0 pindirs set,          \ Pin is input!
    wrap-target
        low 0 pin wait,     \ wait for start bit
        10 []  7 x set,     \ Bit counter, delay until bit center
        begin,
            1 pins in,      \ Read next RX bit
        6 []  x--? until,   \ One bit is 8 cycles
        pin? if,            \ Stop bit low?
\           rel 4 irq,      \ Mark error
            high 0 pin wait, \ Restart when RX goes idle again
        else,
            24 null in,     \ Data to low byte
            push,           \ Data ok
        then,
    wrap
    over =exec              \ Start SM-1 UART in program
pio}

\ Send character 'ch' using PIO uart TX
: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;


\ Receive character 'ch' using PIO uart RX
: PKEY? ( -- f )    1 rx-depth 0= 0= ;
: PKEY  ( -- ch )
    begin  pkey? until  1 rxf> ;

: DEMO  ( -- )      \ Send & receive a small string
    abc  1 ms  begin  pkey? while  pkey emit  repeat ;
%%

chapter UART-3
hex
(*
    Creating a simple chat progam using two Pico's with this file
    Single UART, TX on state machine 0 & RX on state machine 1 of PIO 0
*)

need pio\

v: pios also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
    460800 =baud            \ 460k8
    26 1 =side-pins  opt    \ GPIO 26 for optional SIDE
    26 1 =out-pins          \ GPIO 26 for OUT & SET
    26 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

1 0 {pio                    \ Use state machine-1 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
    460800 =baud            \ 460k8
    27 =jmp-pin
    27 =in-pin              \ GPIO 27 for IN & SET
    1 27 1 =inputs          \ Pull-up on input
    27 1 =set-pins

    0 pindirs set,          \ Pin is input!
    wrap-target
        low 0 pin wait,     \ wait for start bit
        10 []  7 x set,     \ Bit counter, delay until bit center
        begin,
            1 pins in,      \ Read next RX bit
        6 []  x--? until,   \ One bit is 8 cycles
        pin? if,            \ Stop bit low?
\           rel 4 irq,      \ Mark error
            high 0 pin wait, \ Restart when RX goes idle again
        else,
            24 null in,     \ Data to low byte
            push,           \ Data ok
        then,
    wrap
    over =exec              \ Start SM-1 UART in program
pio}


\ Send character 'ch' using PIO uart TX
: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;



\ Receive character 'ch' using PIO uart RX
: PKEY? ( -- f )    1 rx-depth 0= 0= ;
: PKEY  ( -- ch )
    begin  pkey? until  1 rxf> ;

create TEXT 64 allot    \ Chat box
: !TEXT     ( c -- )    \ Store charcter in string to send
    text >r
    r@ c@ 1+  r@ + c!   \ Add character
    r@ c@ 1+  r> c! ;   \ Increase count

: .PROMPT   ( c -- )    cr emit space ;

: SHOW      ( -- )
    pkey? if
        pkey dup 13 =       \ Cariage return?
        if    ch : .prompt drop  \ Yes, show prompt
        else  emit  then    \ No, just print character
    then ;

: CHAT  ( -- )              \ Send & receive a small string
    begin pkey? while pkey drop repeat \ Remove junk
    0 text c!  ch > .prompt \ Init.
    begin
        show                \ Print received text
        key? dup if                 \ Key pressed?
            drop  key dup 13 = if   \ CR?
                pemit  text count ptype \ Yes, send string
                ch > .prompt  13 pemit  \ Send CR & print prompt
                0 text c!  0        \ New text string
            else
                dup 27 <> if
                    dup !text  dup emit \ No CR, store & show char.
                then
            then
        then
    27 = until ; \ Stop on escape char
%%

chapter UART-4
hex
(*
    Alternative UART pins on the Picu using this software
    Single UART, TX on state machine 0 & RX on state machine 1 of PIO 0
*)

need pio\

v: pios also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
    460800 =baud            \ 460k8
    26 1 =side-pins  opt    \ GPIO 26 for optional SIDE
    26 1 =out-pins          \ GPIO 26 for OUT & SET
    26 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

1 0 {pio                    \ Use state machine-1 on PIO-0
\   9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
    460800 =baud            \ 460k8
    27 =jmp-pin
    27 =in-pin              \ GPIO 27 for IN & SET
    1 27 1 =inputs          \ Pull-up on input
    27 1 =set-pins

    0 pindirs set,          \ Pin is input!
    wrap-target
        low 0 pin wait,     \ wait for start bit
        10 []  7 x set,     \ Bit counter, delay until bit center
        begin,
            1 pins in,      \ Read next RX bit
        6 []  x--? until,   \ One bit is 8 cycles
        pin? if,            \ Stop bit low?
\           rel 4 irq,      \ Mark error
            high 0 pin wait, \ Restart when RX goes idle again
        else,
            24 null in,     \ Data to low byte
            push,           \ Data ok
        then,
    wrap
    over =exec              \ Start SM-1 UART in program
pio}


\ Send character 'ch' using PIO uart TX
: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;



\ Receive character 'ch' using PIO uart RX
: PKEY? ( -- f )    1 rx-depth 0= 0= ;
: PKEY  ( -- ch )
    begin  pkey? until  1 rxf> ;

: ALT   ( -- )      \ Use GPIO26 & GPIO27 for RS232
    ['] pkey to 'key
    ['] pemit to 'emit
    ['] pkey? to 'key? ;

: ORG   ( -- )      \ Use standard RS232 configuration
    ['] key) to 'key
    ['] emit) to 'emit
    ['] key?) to 'key? ;
%%

chapter UART-5
hex
(*
    Alternative UART pins on the Pico using this software
    Single UART, TX on state machine 0 & RX on state machine 1 of PIO 0
*)

need pio\

v: pios also  definitions
: =BAUD ( b sm -- )    8 * =freq ;
v: previous

\ With optional Side-set
clean-pio  decimal          \ Empty code space mirror
0 1 {pio                    \ Use state machine-0 on PIO-0
    9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
\   460800 =baud            \ 460k8
    8 1 =side-pins  opt     \ GPIO 26 for optional SIDE
    8 1 =out-pins           \ GPIO 26 for OUT & SET
    8 1 =set-pins

    1 pindirs set,              \ Pin is output!
    wrap-target
        7 []  1 side  pull,     \ Stop bit, get data byte
        7 []  0 side 7 x set,   \ Start bit
        begin,
            1 pins out,         \ Shift 8 bits out
        6 []  x--? until,       \ Until 8 bits are done
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

1 1 {pio                    \ Use state machine-1 on PIO-0
    9600 =baud              \ 9600
\   38400 =baud             \ 38k4
\   115200 =baud            \ 115k2
\   460800 =baud            \ 460k8
    9 =jmp-pin
    9 =in-pin               \ GPIO 27 for IN & SET
    1 9 1 =inputs           \ Pull-up on input
    9 1 =set-pins

    0 pindirs set,          \ Pin is input!
    wrap-target
        low 0 pin wait,     \ wait for start bit
        10 []  7 x set,     \ Bit counter, delay until bit center
        begin,
            1 pins in,      \ Read next RX bit
        6 []  x--? until,   \ One bit is 8 cycles
        pin? if,            \ Stop bit low?
\           rel 4 irq,      \ Mark error
            high 0 pin wait, \ Restart when RX goes idle again
        else,
            24 null in,     \ Data to low byte
            push,           \ Data ok
        then,
    wrap
    over =exec              \ Start SM-1 UART in program
pio}


\ Send character 'ch' using PIO uart TX
: PEMIT ( ch -- )   \ Character to PIO UART
    begin  0 tx-depth  3 < until  0 >txf ;

: PTYPE ( a u -- )  0 ?do  count pemit  loop  drop ;
: ABC   ( -- )      s" ABC " ptype ;
: PICO  ( -- )      s" RP2040 " ptype ;



\ Receive character 'ch' using PIO uart RX
: PKEY? ( -- f )    1 rx-depth 0= 0= ;
: PKEY  ( -- ch )
    begin  pkey? until  1 rxf> ;

: ALT   ( -- )      \ Use GPIO26 & GPIO27 for RS232
    ['] pkey to 'key
    ['] pemit to 'emit
    ['] pkey? to 'key? ;

: ORG   ( -- )      \ Use standard RS232 configuration
    ['] key) to 'key
    ['] emit) to 'emit
    ['] key?) to 'key? ;
%%


chapter WS2812-0
( gpio -- ) \ WS2812 driver on any pin

need [IF]
need pio\
dup dm 28 > [if]  drop  dm 23  [then]  >r

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    3333333 =freq           \ On 3.333.333 Hz frequency
    r@ 1 =side-pins         \ GPIO xx for SIDE-SET & SET
    r> 1 =set-pins  0 =out-dir \ OSR shift left
    1 pindirs set,
    begin,
        isr osr mov,        \ Copy LED color to OSR
        8 x out,            \ Shift left one byte
        osr x mov,
        x0<>? if,           \ OSR not empty?
            osr isr mov,    \ Save new color in ISR
        else,
            31 x set,       \ OSR empty, start color in ISR
            x isr mov,
        then,
        23 y set,           \ Output 24 bits to WS2812!
        begin,              \ With a specific pattern
\                              One   Zero
            1 x out,        \   0     0
            1 side  x0<>? if, \ 1     1
            1 side  else,   \   1
                nop,        \         0
            then,
        y--? until,         \   0     0
        15 [] 31 x set,     \ Long delay: x = 31
        x osr mov,          \ OSR = 31
        12 x out,           \ OSR = 31 x 4096 = 126976
        osr x mov,          \ Delay = 126796 x 16 = 2028736/3333 ~ .6 sec.
        begin,  15 []  x--? until,
    again,
    0 =exec                 \ Start SM-0 at address 0
pio}

cr 0 .sm
%%

chapter WS2812-1
( sm pio gpio -- ) \ WS2812 driver, demo & GPIO +a LED control on state machine b & b+1

need [if]
depth 3 < [if] abort [then]
dup dm 29 2 within [if]  drop  dm 23  [then] >r  \ Always a valid GPIO pin?
over 1+ constant SM#   ( sm pio -- sm pio )

need pio\

clean-pio  decimal          \ Empty code space mirror
2dup ( sm pio ) {pio        \ Use state machine-a on PIO-b
    3333333 =freq           \ On 3.333.333 Hz frequency
    r@ 1 =side-pins         \ GPIO n for SIDE-SET & SET
    r> 1 =set-pins
    0 =out-dir              \ OSR shift left
    1 pindirs set,
    begin,
        isr osr mov,        \ Copy LED color to OSR
        4 x out,            \ Shift left one nibble
        osr x mov,
        x0<>? if,           \ OSR not empty?
            osr isr mov,    \ Save new color in ISR
        else,
            31 x set,       \ OSR empty, start color in ISR
            x isr mov,
        then,
        23 y set,           \ Output 24 bits to WS2812!
        begin,              \ With a specific pattern
\                              One   Zero
            1 x out,        \   0     0
            1 side  x0<>? if, \ 1     1
            1 side  else,   \   1
                nop,        \         0
            then,
        y--? until,         \   0     0

        15 [] 31 x set,     \ Long delay: x = 31
        x osr mov,          \ OSR = 31
        12 x out,           \ OSR = 31 x 4096 = 126976
        osr x mov,          \ Delay = 126796 x 16 = 2028736/3333 ~ .6 sec.
        begin,  15 []  x--? until,
    again,
    0 =exec                 \ Start SM-0 at address 0
pio}

\ Slow pulses on the LED mounted on GPIO 25
>r  drop sm#  r>
( sm pio ) {pio             \ Use state machine-a+1 on PIO-b
    2200 =freq              \ State machine 0 runs on 2200 Hz
    25 1 =set-pins          \ GPIO 25 for SET
                            \ The program starts behind WS2812 program
    1 pindirs set,          \ Pin is output
    1 pins set,             \ Start with the LED on
    begin, again,           \ Wait loop
    begin,
        15 [] 1 pins set,   \ LED on (pin 25)
        15 [] 31 y set,     \ Max. delay using Y
        begin,
            15 [] nop,      \ Extra delay
            15 [] 0 pins set, \ LED off (pin 25)
        15 [] y--? until,   \ Wait longer
    again,
    over =exec              \ Start SM-1 program at address from stack
pio}

hex
: FLASH    18 sm# exec-opc ;                    \ Jump to address 24, start flasher
: LED-OFF  17 sm# exec-opc  E000 sm# exec-opc ; \ Pin 25 & 26 off, jump to wait loop (address 23)
: LED-ON   17 sm# exec-opc  F801 sm# exec-opc ; \ Pin 25 & 26 on, jump to wait loop (address 23)

cr sm# 1- .sm
cr sm# .sm
%%

chapter WS2812-2
\  WS2812 driver on GPIO23 & GPIO28
\ Using two state machines on PIO-0 and the clone function

need pio\

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    3333333 =freq           \ On 3.333.333 Hz frequency
    28 1 =side-pins         \ GPIO 28 for SIDE-SET & SET
    28 1 =set-pins  0 =out-dir \ OSR shift left
    1 pindirs set,
    wrap-target
        isr osr mov,        \ Copy LED color to OSR
        8 x out,            \ Shift left one byte
        osr x mov,
        x0<>? if,           \ OSR not empty?
            osr isr mov,    \ Save new color in ISR
        else,
            31 x set,       \ OSR empty, start color in ISR
            x isr mov,
        then,
        23 y set,           \ Output 24 bits to WS2812!
        begin,              \ With a specific pattern
\                              One   Zero
            1 x out,        \   0     0
            1 side  x0<>? if, \ 1     1
            1 side  else,   \   1
                nop,        \         0
            then,
        y--? until,         \   0     0
        15 [] 31 x set,     \ Long delay: x = 31
        x osr mov,          \ OSR = 31
        12 x out,           \ OSR = 31 x 4096 = 126976
        osr x mov,          \ Delay = 126796 x 16 = 2028736/3333 ~ .6 sec.
        begin,  15 []  x--? until,
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

1 0 {pio        \ WS2812 output on pin 23 on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    23 1 =side-pins         \ GPIO 23 for optional SIDE & SET
    23 1 =set-pins
    0 =exec                 \ Start SM-1 at address 0 too
pio}

cr 0 .sm  cr 1 .sm

0 1 sm-on  200 ms  1 1 sm-on \ Start both LED drivers
%%

chapter WS2812-3
\ Multi color multi WS2812 driver, alternative coding style where
\ X and Y scratch registers are used for color code and the length
\ of the LED string. In only 19 opcodes a flexible WS2812 LED driver,
\ the maximum string length is only limited by the update rate and
\ ofcourse the power supply. Pulse frequency = 740 kHz
\ Note! State machine-0 outputs on GPIO 28
\
\ The assembled program & configuration data:
\
\  0: E081 set  pindirs 1
\  1: 90A0 pull block  side 0
\  2: A047 mov  y osr
\  3: 0070 jmp  y=0 to: 10
\  4: 0085 jmp  y-- to: 5
\  5: 80A0 pull block
\  6: A0C7 mov  isr osr
\  7: A0E6 mov  osr isr
\  8: 6068 out  null 8
\  9: 6001 out  pins 1
\  A: 1ACC jmp  pin to: C  side 1  [2]
\  B: 110D jmp  to: D  side 0  [1]
\  C: B821 mov  x x  side 1
\  D: 12E9 jmp  osrne to: 9  side 0  [2]
\  E: 0087 jmp  y-- to: 7
\  F: 0012 jmp  to: 12
\ 10: E04A set  y A
\ 11: 1791 jmp  y-- to: 11  side 0  [7]
\ 12: 0001 jmp  to: 1   OK.0
\
\ Clk: 6666666 Hz,  Wrap: 0 31  Outsel: 0  Jmp: 28
\ Push: 0  dir: 1  auto: 0  steal: 0
\ Pull: 0  dir: 0  auto: 0  steal: 0
\ Set: 28 1  Side: 28 2 optional  Out: 28 1  In: 0

need pio\
need 2@
need 2!

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                        \ Use state machine-0 on PIO-0
    6666666 =freq               \ On 6.666.666 Hz frequency
    28 1 =side-pins  opt        \ GPIO 25 for SIDE-SET optional
    28 1 =out-pins              \ for OUT & SET
    28 1 =set-pins
    28 =jmp-pin                 \ Pin 28 is input too
    32 0 =autopull  0 =out-dir  \ OSR shift left

    1 pindirs set,
    begin,
        0 side  pull,           \ Number of LEDs in string
        osr y mov,              \ Get length string tp Y
        pull,                   \ Get LED color
        osr isr mov,            \ Save color copy in ISR
        y0<>? if,               \ Length not zero?
            y--? if, then,          \ Decrease Y by 1
            begin,
                isr osr mov,        \ Copy color data to OSR
                8 null out,         \ Shift left one byte
                begin,              \ With a WS2812 specific pattern
\                                             One   Zero
                    1 pins out,             \  1     0     Output highest bit
                    2 []  1 side  pin? if,  \  111   111   Is it low bit?
                    1 []  0 side  else,     \        00    Yes,
                        1 side  nop,        \  1           No,
                    then,
                2 []  0 side  osre? until,  \  000   000   One LED done?
            y--? until,             \ Count number of leds
        else,
           10 y set,                \ Length zero, make reset pulse
           begin,  15 [] 0 side y--? until,
        then,
    again,
    0 =exec                     \ Start SM-0 at address 0
pio}

decimal
730 value #LEDS     \ Number of WS2812 LEDs connected
  0 value #POS      \ Next LED position to address

hex
: CLR       ( -- )          0 to #pos ;
: BLACK     ( -- c )        000000 ;    \ Leds on and off
: WHITE     ( -- c )        101009 ;
: GREEN     ( -- c )        100000 ;
: RED       ( -- c )        001000 ;
: DARKRED   ( -- c )        000800 ;
: BLUE      ( -- c )        000010 ;
: DARKBLUE  ( -- c )        000008 ;
: BLUEGREEN ( -- c )        1A0008 ;
: YELLOW    ( -- c )        181400 ;
: ORANGE    ( -- c )        081000 ;
: PURPLE    ( -- c )        000314 ;
: DARKGREEN ( -- c )        080000 ;
: ICY       ( -- c )        10101F ;
: WARM      ( -- c )        181F10 ;
: HOT       ( -- c )        181C04 ;

: >OUT      ( dc u -- )
    begin  0 tx-depth  3 < until  0 >txf  0 >txf ; \ Data for GPIO 28

: >RGB      ( c +n -- )     1 umax 400 umin  dup +to #pos  >out ; \ Length is minimal 1 LED
: READY     ( -- )          0 0 >out ;  \ Ready signal
: ALL       ( c -- )        clr  #leds >rgb  ready ; \ One color to leds

10 value #FIELD  \ Field length
03 value #DOT    \ Dot length
08 value #WAIT   \ Delay time

\ 0 value 'MEM
\ 0 value 'ACCU
create 'COLORS  8 cells allot
create 'EFFECT  2 cells allot

: >LEDS     ( +n -- )       400 umin  to #leds ;    \ Number of LEDs
: >WAIT     ( +n -- )       200 umin  to #wait ;    \ Set delay time in millisec.
: >FIELD    ( +n -- )       #leds umin  to #field ; \ Set field size
: >DOT      ( +n -- )       #field umin  to #dot ;  \ Set dot size
: >BCOLOR   ( c -- )        'effect ! ;             \ Background color
: >FCOLOR   ( c -- )        'effect cell+ ! ;       \ Foreground color
: >COLOR    ( c +n -- )     7 umin cells 'colors + ! ;    \ One of eight colors
: BCOLOR    ( +n -- )       'effect @ swap >rgb ;        \ +n LEDs with background color
: FCOLOR    ( +n -- )       'effect cell+ @  swap >rgb ; \ +n LEDs with foreground color
: COLOR     ( i +n -- )      >r  cells 'colors + @  r> >rgb ;
: CSWAP     ( -- )          'effect 2@  >fcolor >bcolor ; \ Exchange colors
: WAIT      ( -- )          #wait ms ;

#leds >field    3 >dot      \ Basic size & color settings
red >fcolor     black >bcolor

: .MLINE    ( dot-pos -- )          \ Display one field
    >r  r@ #dot +  #field > 0= if   \ Dot fits in #FIELD
        r> ?dup if  bcolor  then    \ Yes, do background first?
        #dot ?dup if fcolor then    \ If any, then output DOT
        #field  #pos - ?dup         \ Still room for background?
        if  bcolor  then  exit      \ Yes, then fill in
    then
    r> #dot +  #field - dup fcolor  \ No, repeat DOT remainder at start
    #field  #dot - bcolor           \ Do background color?
    negate #dot + fcolor ;          \ and dot remainder

: MLINE     ( dot-pos -- )          \ Repeat fields until all LEDs are done
    begin
        dup #leds u< 0= while       \ Too large value?
        #leds -                     \ Yes, scale back
    repeat  >r
    #leds  begin
        clr  r@ .mline  #field -    \ One field at a time
    dup 1 < until                   \ Whole LED string done?
    r> 2drop  ready ;

: PRISM     ( -- )                  \ Set rainbow colors
    002C00 0 >color     \ Red
    102000 1 >color     \ Orange
    181400 2 >color     \ Yellow
    2C0000 3 >color     \ Green
    1A0008 4 >color     \ Blue-green
    000040 5 >color     \ Blue
    000738 6 >color     \ Deep-purple :)
    001A20 7 >color ;   \ Purple

: SHOW      ( -- )                  \ Show these
    clr  #leds 0 do
        8 0 do  i #field 8 / color loop
        key? if leave then
    #field +loop  ready ;

: ROTATE    ( f -- )                \ Rotate color buffer left = -1 or right = 0
    if  'colors 7 cells + @
        'colors  'colors cell+  7 cells move
        'colors !  exit
    then
    'colors @
    'colors cell+  'colors  7 cells move
    'colors 7 cells + ! ;


\ Demo's:
: MSHIFT    ( -- )                  \ Shift DOT until a key is pressed
    begin
        #field 0 do  i mline  wait  key? if leave then  loop
    key? until  black all ;

: VOLUME    ( -- )                  \ Volume style DOT
    #dot  begin
        #field 0 do  i >dot  0 mline  wait  key? if leave then  loop
        0 #field do  i >dot  0 mline  wait  key? if leave then  -1 +loop
    key? until  >dot  black all ;

: BOUNCE    ( -- )                  \ Bouncing DOT
    #dot  begin
        #field #dot -  dup 0 ?do  i mline  wait  key? if leave then loop
        1 swap ?do  i mline  wait  key? if leave then  -1 +loop
    key? until  >dot  black all ;

: FLAG      ( -- )          \ Dutch flag with banner on all LEDs
    clr  begin
        2000 3 >rgb        \ Red
        101010 3 >rgb      \ White
        30 3 >rgb          \ Blue
        102000 3 >rgb      \ Orange
    key? 0= while
    #pos #leds u< 0= until
    ready  then ;

: PARTY     ( -- )          \ Shift rainbow colors
    prism
    begin
        show  wait  1 rotate
    key? until  black all ;
%%

chapter WS2812-4
\ Multi color multi WS2812 driver, alternative coding style where
\ X and Y scratch registers are used for color code and the length
\ of the LED string. In only 19 opcodes a flexible WS2812 LED driver,
\ the maximum string length is only limited by the update rate and
\ ofcourse the power supply. Pulse frequency = 740 kHz
\ Note! State machine-0 outputs on GPIO 28
\
\ The assembled program & configuration data:
\
\  0: E081 set  pindirs 1
\  1: 90A0 pull block  side 0
\  2: A047 mov  y osr
\  3: 0070 jmp  y=0 to: 10
\  4: 0085 jmp  y-- to: 5
\  5: 80A0 pull block
\  6: A0C7 mov  isr osr
\  7: A0E6 mov  osr isr
\  8: 6068 out  null 8
\  9: 6001 out  pins 1
\  A: 1ACC jmp  pin to: C  side 1  [2]
\  B: 110D jmp  to: D  side 0  [1]
\  C: B821 mov  x x  side 1
\  D: 12E9 jmp  osrne to: 9  side 0  [2]
\  E: 0087 jmp  y-- to: 7
\  F: 0012 jmp  to: 12
\ 10: E04A set  y A
\ 11: 1791 jmp  y-- to: 11  side 0  [7]
\ 12: 0001 jmp  to: 1   OK.0
\
\ Clk: 6666666 Hz,  Wrap: 0 31  Outsel: 0  Jmp: 28
\ Push: 0  dir: 1  auto: 0  steal: 0
\ Pull: 0  dir: 0  auto: 0  steal: 0
\ Set: 28 1  Side: 28 2 optional  Out: 28 1  In: 0

need 2@
need 2!

hex
v: inside also definitions
0 value 'PIO                \ Pointer to current active PIO
: PIO-ADDR  ( offset -- a ) cells  'pio + ; \ Convert to real address
: PIO@      ( offset -- x ) pio-addr @ ;
: PIO!      ( x offset -- ) pio-addr ! ;
: >FIELD    ( x mask pos -- y ) >r and  r> lshift ; \ Place bitfield
: FIELD!    ( data mask pos offset -- ) \ Replace any bit field with new data
    >r  2dup lshift invert  r@ pio@ and \ Erase bit-field
    >r  >field  r> or  r> pio! ;        \ Set bit-field & show result
v: extra definitions
: SM-ON     ( f sm -- )     1 swap 0 field! ; \ (De)activate a state machine
: SET-PIO   ( pio -- )      0<> 100000 and  50200000 +  to 'pio ;
: TX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * rshift  F and ; \ Fifo depth
: RX-DEPTH  ( sm -- +n )    3 pio@  swap 8 * 4 + rshift  F and ; \ Idem
: >TXF      ( u sm -- )     4 + pio! ;      \ Store TX data in FIFO
: RXF>      ( sm -- u )     8 + pio@ ;      \ Fetch RX data from FIFO

\ PIO-programs doing dual WS2812 & 115k2 UART on GPIO6 & GPIO7
: PIO-PROG
    0000 50200000 !
    1F000 502000CC !
    14000000 502000DC !
    12C000 502000C8 !
    14007000 502000DC !
    34007000 502000DC !
    4001F000 502000CC !
    54007000 502000DC !
    5400701C 502000DC !
    5410701C 502000DC !
    0006 400140E4 !
    5410739C 502000DC !
    4410739C 502000DC !
    0006 400140E4 !
    5C01F000 502000CC !
    C0000 502000D0 !
    C0000 502000D0 !
    40000 502000D0 !
    E081 50200048 !
    90A0 5020004C !
    A047 50200050 !
    80A0 50200054 !
    A0C7 50200058 !
    0060 5020005C !
    0080 50200060 !
    0087 50200060 !
    A0E6 50200064 !
    6068 50200068 !
    6001 5020006C !
    1AC0 50200070 !
    1100 50200074 !
    1ACC 50200070 !
    B821 50200078 !
    110D 50200074 !
    12E9 5020007C !
    0087 50200080 !
    0000 50200084 !
    0070 5020005C !
    E04A 50200088 !
    1791 5020008C !
    0012 50200084 !
    0001 50200090 !
    0000 502000D8 !
    87A200 502000F8 !       \ UART on SM-2
    34001800 5020010C !
    4001F000 502000FC !
    54101806 5020010C !
    0006 40014034 !
    441018C6 5020010C !
    0006 40014034 !
    E081 5020009C !
    4001FB00 502000FC !
    9FA0 502000A0 !
    F727 502000A4 !
    6001 502000A8 !
    0658 502000AC !
    40019B00 502000FC !
    0015 50200108 !
    1F000 50200114 !
    14000000 50200124 !
    87A200 50200110 !
    40019B00 50200114 !
    C0000 50200118 !
    87A200 50200110 !       \ UART clone on SM-3
    34001C00 50200124 !
    40019B00 50200114 !
    54101C07 50200124 !
    0006 4001403C !
    44101CE7 50200124 !
    0006 4001403C !
    0015 50200120 !
    000D 50200000 !         \ Start all used state machines
    0000 set-pio ;

dm 300 value #LEDS     \ Number of WS2812 LEDs connected
     0 value #POS      \ Next LED position to address

: CLR-POS   ( -- )          0 to #pos ;
: BLACK     ( -- c )        000000 ;    \ Leds on and off
: WHITE     ( -- c )        101009 ;
: GREEN     ( -- c )        100000 ;
: RED       ( -- c )        001000 ;
: DARKRED   ( -- c )        000800 ;
: BLUE      ( -- c )        000010 ;
: DARKBLUE  ( -- c )        000008 ;
: BLUEGREEN ( -- c )        1A0008 ;
: YELLOW    ( -- c )        181400 ;
: ORANGE    ( -- c )        081000 ;
: PURPLE    ( -- c )        000314 ;
: DARKGREEN ( -- c )        080000 ;
: ICY       ( -- c )        10101F ;
: WARM      ( -- c )        181F10 ;
: REDHOT    ( -- c )        181C04 ;

: >OUT      ( dc u -- )
    begin  0 tx-depth  3 < until  0 >txf  0 >txf  pause ; \ Data for GPIO 28

: >RGB      ( c +n -- )     1 umax 400 umin  dup +to #pos  >out ; \ Length is minimal 1 LED
: READY     ( -- )          0 0 >out  clr-pos ; \ Ready signal
: ALL       ( c -- )        clr-pos  #leds >rgb  ready ; \ One color to leds

10 value #FIELD  \ Field length
03 value #DOT    \ Dot length
08 value #WAIT   \ Delay time

\ 0 value 'MEM
\ 0 value 'ACCU
create 'COLORS  8 cells allot
create 'EFFECT  2 cells allot

: >LEDS     ( +n -- )       400 umin  to #leds ;    \ Number of LEDs
: >WAIT     ( +n -- )       200 umin  to #wait ;    \ Set delay time in millisec.
: >FIELD    ( +n -- )       #leds umin  to #field ; \ Set field size
: >DOT      ( +n -- )       #field umin  to #dot ;  \ Set dot size
: >BCOLOR   ( c -- )        'effect ! ;             \ Background color
: >FCOLOR   ( c -- )        'effect cell+ ! ;       \ Foreground color
: >COLOR    ( c +n -- )     7 umin cells 'colors + ! ;    \ One of eight colors
: BCOLOR    ( +n -- )       'effect @ swap >rgb ;        \ +n LEDs with background color
: FCOLOR    ( +n -- )       'effect cell+ @  swap >rgb ; \ +n LEDs with foreground color
: COLOR     ( i +n -- )      >r  cells 'colors + @  r> >rgb ;
: CSWAP     ( -- )          'effect 2@  >fcolor >bcolor ; \ Exchange colors
: WAIT      ( -- )          #wait ms ;

v: extra
: WS2812-SETUP  ( -- )
    pio-prog
    dm 730 >leds    clr-pos         \ Leds & start position
    #leds >field    3 >dot          \ Field  & dot size
    red >fcolor     black >bcolor   \ Color settings & step delay
    8 >wait ;

: .MLINE    ( dot-pos -- )          \ Display one field
    >r  r@ #dot +  #field > 0= if   \ Dot fits in #FIELD
        r> ?dup if  bcolor  then    \ Yes, do background first?
        #dot ?dup if fcolor then    \ If any, then output DOT
        #field  #pos - ?dup         \ Still room for background?
        if  bcolor  then  exit      \ Yes, then fill in
    then
    r> #dot +  #field - dup fcolor  \ No, repeat DOT remainder at start
    #field  #dot - bcolor           \ Do background color?
    negate #dot + fcolor ;          \ and dot remainder

: MLINE     ( dot-pos -- )          \ Repeat fields until all LEDs are done
    begin
        dup #leds u< 0= while       \ Too large value?
        #leds -                     \ Yes, scale back
    repeat  >r
    #leds  begin
        clr-pos  r@ .mline  #field - \ One field at a time
    dup 1 < until                   \ Whole LED string done?
    r> 2drop  ready ;

: PRISM     ( -- )                  \ Set rainbow colors
    002C00 0 >color     \ Red
    102000 1 >color     \ Orange
    181400 2 >color     \ Yellow
    2C0000 3 >color     \ Green
    1A0008 4 >color     \ Blue-green
    000040 5 >color     \ Blue
    000738 6 >color     \ Deep-purple :)
    001A20 7 >color ;   \ Purple

: SHOW      ( -- )                  \ Show these
    clr-pos  #leds 0 do
        8 0 do  i #field 8 / color loop
        key? if leave then
    #field +loop  ready ;

: ROTATE    ( f -- )                \ Rotate color buffer left = -1 or right = 0
    if  'colors 7 cells + @
        'colors  'colors cell+  7 cells move
        'colors !  exit
    then
    'colors @
    'colors cell+  'colors  7 cells move
    'colors 7 cells + ! ;


\ Demo's:
: MSHIFT    ( -- )                  \ Shift DOT until a key is pressed
    begin
        #field 0 do  i mline  wait  key? if leave then  loop
    key? until  black all ;

: VOLUME    ( -- )                  \ Volume style DOT
    #dot  begin
        #field 0 do  i >dot  0 mline  wait  key? if leave then  loop
        0 #field do  i >dot  0 mline  wait  key? if leave then  -1 +loop
    key? until  >dot  black all ;

: BOUNCE    ( -- )                  \ Bouncing DOT
    #dot  begin
        #field #dot -  dup 0 ?do  i mline  wait  key? if leave then loop
        1 swap ?do  i mline  wait  key? if leave then  -1 +loop
    key? until  >dot  black all ;

: FLAG      ( -- )          \ Dutch flag with banner on all LEDs
    ws2812-setup  clr-pos
    begin
        2000 3 >rgb        \ Red
        101010 3 >rgb      \ White
        30 3 >rgb          \ Blue
        102000 3 >rgb      \ Orange
    key? 0= while
    #pos #leds u< 0= until
    ready  then ;

: PARTY     ( -- )          \ Shift rainbow colors
    prism
    begin
        show  wait  1 rotate
    key? until  black all ;


ws2812-setup  v: fresh
shield WS2812\
%%

chapter CARS\
hex
(* Highway simulation

0 value STEP
: MOVE-CARS         ( -- )
    incr step  cr step 3 .r ." : "\
    #order 0 ?do
        step  i car-order c@ cars speed  mod
        0= if  i .  then
    loop ;

: T1                ( -- )
    0 to step  begin  move-cars  20 ms  key? until ;

This code is a sketch and for only eight cars.
Also the police car can not pass other cars yet.

*)

need task
need @name
v: inside
need >nfa
need random
pio need ws2812-4
hex

\ ---------- Backlight ------------ Car color ------------ Headlight  Pos  Speed
create CAR1   darkred ,     green ,     green ,     green ,  white ,  -1 ,   0 ,
create CAR2   darkred ,    yellow ,    yellow ,    yellow ,  white ,  -1 ,   0 ,
create CAR3   darkred ,   darkred ,   darkred ,   darkred ,  white ,  -1 ,   0 ,
create CAR4   darkred , bluegreen , bluegreen , bluegreen ,  white ,  -1 ,   0 ,
create CAR5   darkred ,    purple ,    purple ,    purple ,  white ,  -1 ,   0 ,
create CAR6   darkred ,    orange ,    orange ,    orange ,  white ,  -1 ,   0 ,
create CAR7   darkred , darkgreen , darkgreen , darkgreen ,  white ,  -1 ,   0 ,
create POLI   darkred ,  darkblue ,  darkblue ,  darkblue ,  white ,  -1 ,   0 ,


\ Motorway simulation, speed = 0 to 8, pos=-1 (not active) pos 0 to +n (road position)

0 value T?
: TRACE     true to T? ;  trace
: NOTRACE   false to T? ;

0 value STEP
0 value #ORDER
: .ROAD     ( +n -- )
    dup 0 > if  dup +to #pos  black over >out  then  drop ;

\ : CHOOSE    ( u1 - u2 )         random um* nip ;
: 'POSITION ( car -- a )        5 cells + ;
: POSITION  ( car -- n )        'position @ ;
: 'SPEED    ( car -- a )        6 cells + ;
: SPEED     ( car -- +n )       'speed @ ;
: DISTANCE  ( car0 car1 -- +n ) position >r  position  r> - abs 5 - ;
: .START    ( car -- )          position dup 4 > if 4 - .road else drop then ;
: POLI?     ( car -- f )        cell+ @ darkblue = ;

: FLASH     ( car -- car )
    step 2 mod ?exit            \ Once every second time
    dup poli? if                \ Police car?
        dup 2 cells + >r        \ Save light to flash
        r@ @ darkblue =         \ Is flash light off?
        if 30 else darkblue then \ Yes, make brighter
        r> !                    \ Replace color
    then ;

: .CAR      ( car -- )          \ Display a car
    dup position 4 umin >r   4 r@ - cells  +
    r> 1+ for  @+ 1 >rgb  next  drop ;

create CARS         ( +n -- car )
    car1 ,  car2 ,  car3 ,  car4 ,  car5 ,  car6 ,  car7 ,  poli ,
    does> swap cells + @ ;
create CAR-ORDER    ( +n -- a )
    0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,  align  does> + ;


: ADD-CAR           ( +n -- )   \ Choose next car
    dup cars position 0< if             \ Car not used?
        darkred over cars !             \ Normal backlight
        0 over cars 'position !
        9 choose 2 umax over cars 'speed  !
        0 car-order dup 1+ #order move
        0 car-order c!  incr #order
   else drop then ;

: LOCATE    ( +n -- p ) car-order c@ cars position ;
: FARTHEST  ( -- +n )   0  #order for  i locate umax  next ;
: AWAY      ( -- +n )   0 locate ;
: STEP?     ( +n -- f ) step  swap car-order c@ cars speed  mod 0= ;

0 value #BR     \ Brake earlyer at high speed difference
: BRAKE             ( car2 car1 distance -- car2 distance )
    >r  over speed  over speed -    \ c2 c1 spd-diff
    2 > 2 and to #br                \ c2 c1
    r@ 2 6 #br + within if          \ c2 c1
        r@ 2 = if                   \ c2 c1
            over speed              \ c2 c1 s2
            over 'speed !           \ c2 c1
            dup darkred swap !      \ Brakelight off car1
        else
            dup 2000 swap !         \ Brakelight on car1
            over speed 1-           \ c2 c1 s2-1
            over >r r@ speed 1+     \ c2 c1 s2-1 sa1
            umin r> 'speed !        \ c2 c1
        then
        drop  r>  exit              \ c2 dist
    then
    darkred swap !  r>              \ Brakelight off car1
    ;

: MOVE-CARS         ( -- )
    incr step  #order 0 ?do
        i step? if
            1  i car-order c@ cars  flash  'position  +!
        then
    loop ;

v: inside
: .CARS             ( -- )
    #order t? if dup . then  0 ?do
        t? if i car-order c@ cars  dup cell- >nfa @name type then
        i if
            i car-order c@ cars         ( c2 )
            i 1- car-order c@ cars      ( c2 c1 )
            2dup distance               ( c2 c1 dist )
            brake  .road  .car
        else
            i car-order c@ cars  dup .start .car
        then
        t? if #br if ch - else ch : then  emit  speed . then
    loop  ready  clr-pos ;

: .SIM      ( -- )
    #order  dup .  0 ?do
        cr i car-order c@ dup .
        cars  dup position 3 .r space
        dup cell- >nfa @name type
        ." : "  speed .
    loop ;
v: forth

: INI-SIM   ( -- )
    dm 300 >leds  black all
    dm 150 >leds  dm 150 >field
    0 to #order  0 to step
    8 for  i cars 'position -1 swap !  next
    0 car-order 7 0 fill ;

\       cr  20 farthest dup 3 .r space
\       1A / -  dup 2 .r space 0 max ms
: SIM)      ( -- )
    begin
        100  farthest  t? if cr dup 3 .r space then
        10 2E */ -  t? if dup 3 .r space then  0 max  dm 300 * us
        random drop  t? if step 3 .r ." : " then          \ -
        #order 8 = if                           \ -
            away dm 150 > if  ini-sim  then     \ -
        then
        away 20 u> if                           \ -
            30 choose  dup 8 < if               \ +n
                dup add-car                     \ +n
            then  drop
        then
        .cars  move-cars
    stop? until ;

: SIM       ( -- )      ws2812-setup  ini-sim  notrace  sim) ;

ws2812-setup  black all  ini-sim

task: CARS

: START-CARS ( -- )     ['] sim  cars  start-task ;

' start-cars  to app
shield CARS\
%%

chapter DHT22\
hex ( -- )
(* DHT22 sensor, using PIO: 1556 bytes

    40-bits pulse stream 32-bits data & 8-bits checksum

clean-pio  decimal      \ Empty code space, start at zero
0 0 {pio                \ Use state machine-0 on PIO-0
    160000 =freq        \ On 4 * 40 kHz frequency (6.25 µs ticks)
    05 1 =out-pins      \ GPIO 5 for OUT & SET
    05 1 =set-pins
    05 =in-pin          \ GPIO 5 for IN & JMP
    05 =jmp-pin

    0 =in-dir           \ Shift left
    32 1 =autopush

    0 pindirs set,              \ Pin is input
    wrap-target
        4 [] begin, again,      \ Wait for start command
    one ( Sensor readout )
        1 pindirs set,          \ Pin is output
        3 y set,  begin,        \ Generate start pulse low .8 ms
            31 [] 0 pins set,
        y--? until,
        6 [] 1 pins set,        \ 44 µs start pulse high

        6 [] 0 pindirs set,     \ Now input, wait 44 µs, skip response low
        6 [] high 0 pin wait,   \ Wait for response high 44 µs

        31 y set,               \ Now read the 32-bits answer 6.25 µs
        begin,                  \ This contains the sensor data
            low 0 pin wait,
            5 [] high 0 pin wait, \ Wait for high bit 37.5 µs
            1 pins in,          \ Shift in low or high bit 6.25 µs ( autopush
        y--? until,             \ Count all 32 bits 6.25 µs)
        7 y set,                \ Read 8-bit checksum 6.25 µs
        begin,
            low 0 pin wait,
            5 [] high 0 pin wait, \ Wait for high bit 37.5 µs
            1 pins in,          \ Shift in checksum bit 6.25 µs
        y--? until,             \ Count 8 bits 6.25 µs
        push,                   \ Result 8-bits to fifo 6.25 µs
    wrap
    0 =exec                     \ Start with wait loop
pio}

*)

chere
need arshift

v: inside also  definitions
2 constant #PIO              \ Number of PIO's
0 value 'PIO                 \ Pointer to current active PIO
: PIO@      ( offset -- x )  cells 'pio + @ ;
: PIO!      ( x offset -- )  cells 'pio + ! ;

v: extra definitions
: =PIO      ( pio -- )       #pio 1- umin  100000 *  50200000 +  to 'pio ; \ Select active pio block

: RX-DEPTH  ( sm -- +n )     3 pio@  swap 8 * 4 + rshift  F and ; \ Idem
: RXF>      ( sm -- u )      8 + pio@ ;      \ Fetch RX data from FIFO

v: inside definitions
create SM-OFFSETS    32 c, 38 c, 3E c, 44 c, align  \ Address SM control blocks
: SM-OFFSET+ ( off1 sm -- off2 ) sm-offsets + c@ + ;

v: extra definitions
: EXEC-OPC  ( instr sm -- )  4 swap sm-offset+ pio! ; \ Exec. instruction

hex
: PIO-PROG
    00000000 50200000 !
\   0001F000 502000CC !
\   14000000 502000DC !
    030D4000 502000C8 !
\   14000005 502000DC !
\   14100005 502000DC !
\   00000006 4001402C !
\   141000A5 502000DC !
\   041000A5 502000DC !
    00000006 4001402C !
    041280A5 502000DC !
\   0501F000 502000CC !
\   00080000 502000D0 !
\   00090000 502000D0 !
    00090000 502000D0 !
    0000E080 50200048 !
\   0501F080 502000CC !
    00000401 5020004C !
    0000E081 50200050 !
    0000E043 50200054 !
    0000FF00 50200058 !
    00000084 5020005C !
    0000E601 50200060 !
    0000E680 50200064 !
    000026A0 50200068 !
    0000E05F 5020006C !
    00002020 50200070 !
    000025A0 50200074 !
    00004001 50200078 !
    0000008A 5020007C !
    0000E047 50200080 !
    00002020 50200084 !
    000025A0 50200088 !
    00004001 5020008C !
    0000008F 50200090 !
    00008020 50200094 !
    05013080 502000CC !
    00000000 502000D8 !
    00000001 50200000 !
    00000000 =pio ;
pio-prog

v: inside definitions
: DHT22>    ( -- x chk )
    0002 0 exec-opc             \ Start new measurement
    begin  0 rx-depth 1- until  \ Fifo minimal two deep?
    0 rxf>   0 rxf> ;           \ 32-bits data & 8-bits checksum

: CHECKSUM  ( h -- chks )       \ Calculate checksum
    h-h  b-b +  swap            \ Split & calc checksum
    b-b +  +  b-b drop ;

v: extra definitions
: .DHT      ( h -- )            \ Show scaled result
    10 lshift  10 arshift       \ Extend sign bit
    s>d tuck  dabs
    <# # ch . hold #s rot sign #>
    type space ;

: DHT22@    ( -- h t )
    0  begin   dht22>       \ Read sensor
    over checksum <> while  \ Checksum not ok?
        drop  1+            \ Drop reading, count retries
        dup 1- ?abort       \ More then one retry, abort
        dm 2000 ms
    repeat
    nip  h-h ;              \ Split in hum. & temp.

: DHT22     ( -- )
    base @  decimal
    dht22@  .dht ." %rel, " .dht ." Celcius " \ Show scaled result
    base ! ;

: START     ( -- )
    pio-prog  begin  cr dht22  800 ms  key? until ;

v: fresh
' start  to app
shield DHT22\

hex  chere swap - dm .
%%

chapter PIO-US\
( sm pio gpio -- )  \ When no GPIO is given, GPIO20 & GPIO21 are used
                    \ also sm 0 on pio-0 is selected

(* Ultrasonic sensor readout with PIO in only 10 PIO-opcodes

Works on: HC-SR04, US-100, US-015, RCW-0001, RCWL-1605, etc.

\ Trigger = GPIOx+1
\ Echo    = GPIOx

*)

need pio\     ( Load the pio assembler & disassembler first )
need [if]
depth 3 < [if]  0  0  dm 20  [then]  >r

clean-pio  decimal          \ Clear PIO
{pio                        \ Use SM-sm on PIO-pio
    1,000,000 =freq         \ Clock = 1 MHz
    r@ 2 =set-pins          \ Both used pins for SET
    r@ =in-pin              \ Input = GPIOx
    r@ =jmp-pin             \ PIN? = GPIOx
    1 r@ 1 =inputs          \ GPIOx = Pullup
    r> 1+ 1 =side-pins      \ Output = GPIOx+1

    2 pindirs set,              \ GPIOx = input, GPIOx+1 = output
    ONE  block pull,            \ Wait for timeout value
    9 [] 1 side  osr x mov,     \ Timeout to X, 10 µs start pulse

    high 28 gpio wait,          \ Input pulse on GPIO28 started?
    begin,                      \ Measure pulse length
        pin? if,                \ GPIO28 low?
            TWO  x inv isr mov, \ (1) Push inverted result
            block push,
            ONE> PIO,           \ Result = -1, jump to wait
        then,
    x--? until,                 \ (1) Timeout?
    TWO> pio,                   \ Jump to result
    over =exec                  \ Start program
pio} 


hex 
v: inside also  definitions
: PDISTANCE) ( -- 100us to 32900us )
    true 0 >txf                 \ Start measurement!
    begin  dm 10 us  0 rx-depth until  0 rxf> ;

v: extra definitions
: PDISTANCE  ( -- mm )          \ Distance in mm.
    pdistance)  dm 1000 dm 291 */ ;

(*
: MEASURE3  ( -- )              \ Show distance in mm or a dash
    base @ >r  decimal
    begin   pdistance dup dm 45000 < if  \ 450cm is maximum distance!
                dup 0 <# # # ch . hold #s #> type space
            else  ." - " then  drop  9 ms
    key? until 
    r> base ! ;
*)

v: fresh
shield PIO-US\  freeze
%%

chapter SHOW-US

' pio-us\ drop

: SHOW-US   ( -- )              \ Show distance in mm or a dash
    base @ >r  decimal
    begin   pdistance dup dm 45000 < if  \ 450cm is maximum distance!
                dup 0 <# # # ch . hold #s #> type space
            else  ." - " then  drop  9 ms
    key? until 
    r> base ! ;
%%

chapter >BAMBOE
( sm pio gpio -- )  \ Add bamboe driver to GPIOx x+1 & x+2 on SM-sm & PIO-pio
\ Usage example:  2 3 7  3 >bamboe  ( Output data to 3 chained bamboe's )

(* Variable length bamboe driver (1 to 8) in only 8 PIO-opcodes

\ 6 bitmask   constant OUT  \ Bamboe data out
\ 7 bitmask   constant CLK  \ Bamboe clock
\ 8 bitmask   constant STR  \ Bamboe strobe

*)

need pio\     ( Load the pio assembler & disassembler first )
need [if]
depth 3 < [if]  0  0  dm 20  [then]  >r

clean-pio  decimal              \ Clear PIO
{pio                            \ SM-sm & PIO-pio
    10,000,000 =freq            \ PIO clock = 10 MHz
    r@ 3 =set-pins              \ Pins for SET is GPIOx to GPIOx2
    r@ 1 =out-pins              \ Output = GPIOx
    r> 1+ 2 =side-pins  opt     \ Side-set pins are GPIOx+1 & GPIOx+2
    0 =out-dir                  \ OUT opcode shifts left

    WRAP-TARGET                 \ Start of loop
        2 side  7 pindirs set,  \ GPIO6 to GPIO8 = output, strobe high
        0 side  block pull,     \ Wait for number of bamboe's, strobe low
        osr x mov,              \ Number of bamboe's to X
        begin,
            0 side  block pull, \ Get data byte
            7 y set,            \ Set bit counter Y to 7 (8-bits)
            begin,
                0 side 1 pins out, \ Output one data bit, clock low
            1 side y--? until,  \ Count data bits, clock high
        0 side x--? until,      \ Count bamboes, clock low
    WRAP                        \ Loop back
    over =exec
pio}

\ This example limits the number of chained bamboe's to 8
: >BAMBOE   ( bn .. b0 +n -- )
    8 umin  dup 1-  0 >txf          \ Move number of chained bamboes to fifo
    for                             \ Loop +n times
        dm 24 lshift                \ Align byte to the left
        begin  0 tx-depth 3 < until \ Space in fifo?
        0 >txf                      \ Yes, move aligned byte to fifo
    next ;
%%

chapter PSERVO\
( sm pio -- )   \ Use GPIO4 to gPIO13 for RCservo pulse outputs
                \ When no data is given SM0 &  SM1 on PIO0 are used

need pio\     ( Load the pio assembler & disassembler first )
need [if]
depth 2 < [if]  0  0  [then]  >r

(* 10 servo pulse width control, W.0. april 2026

    Only 7 PIO instructions are needed 
    The pulse width is from about .5ms to 2.5ms 
    It may be adjusted by a combination of 
    the state machine freqency and the number range
    wich goes from decimal 0 to 96 because of the
    maximum delay of 0 to 31 for each PIO-opcode

    Note that; The PIO opcode table length is set to 32 bytes
    The next size is 64 bytes so when you want more resolution
    for the servo control you may add another PIO opcode to 
    the table below, like this:

    FF01 h,  FF01 h,  EE01 h,           \ Servo 0, 3 PIO opcodes
    FF01 h,  FF01 h,  EE01 h,  FF01 h,  \ Servo 0, 4 PIO opcodes

    Now adjust the table to 64 bytes and change to PIO clock
    in such a way that you get the desired pulse range
    Ofcourse you have to change the word SERVO a little too

*)

clean-pio  decimal          \ Empty code space mirror
dup r@ {pio     \ Servo output on GPIO4 etc. on sm-x & pio-y

    40000 =freq             \ State machine-x runs on 40kHz
    4 5 =set-pins           \ GPIO4 to GPIO8 for SET
    0 =out-dir              \ Shift OSR to left!

    31 pindirs set,         \ All 5 pins output
    begin,
        wrap-target         \ Begin of wrap loop
            block pull,     \ 1
            16 exec out,    \ 1 + 1 + []
        wrap                \ End
      ONE                   \ Delay
        0 pins set,         \ All outputs off
        9 x set,            \ Wait a while
        begin,
        31 [] x--? until,
    again,                  \ Back to wrap loop
    0 =exec                 \ Jump to start
pio}

1+ r> {pio      \ Five more servo's on GPIO9 to GPIO13
    0 clone                 \ Copy SMx setup
    40000 =freq             \ State machine 1 runs on 40kHz
    9 5 =set-pins           \ GPIO9 to GPIO13 for SET
    0 =out-dir              \ Shift OSR to left!
    0 =exec                 \ Jump to start
pio}


hex
\ The 16 half-words opcode buffer must be 32-byte aligned!
here 20 mod negate 20 + allot

\ The two opcode buffers (16 half-words)
here    \ First 5 servos
    FF01 h,  FF01 h,  EE01 h,   \ Servo 0
    FF02 h,  E102 h,  E102 h,   \ Servo 1
    EC04 h,  E004 h,  E004 h,   \ Servo 2
    FF08 h,  E108 h,  E108 h,   \ Servo 3
    FF10 h,  E110 h,  E110 h,   \ Servo 4
    one> h,                     \ Pause
here    \ Next 5 servos
    FF01 h,  FF01 h,  EF01 h,   \ Servo 5
    FF02 h,  E102 h,  E102 h,   \ Servo 6
    EC04 h,  E004 h,  E004 h,   \ Servo 7
    FF08 h,  E108 h,  E108 h,   \ Servo 8
    FF10 h,  E110 h,  E110 h,   \ Servo 9
    one> h,                     \ Pause
constant OPCODES2
constant OPCODES1
create RELOAD  10 ,     \ TRANS_COUNT0 reload

(* DMA control & Trigger register
0       = Enable
2:3     = Data size, 0=Byte, 1=Halfword, 2=Word
4       = Incr. read
5       = Incr, write
6:9     = Ring size 1=2, 15=32768
10      = Ring read = 0, write=1
11:14   = Chain to other DMA
15:20   = Transfer request select; 0 to 3A = DREQ, 3B=Timer0, etc.
*)
: SET-DMA       ( ctrl cnt wr rd +n -- )    \ Set DMA control registers for DMA +n
    40 *  5000,0000 +  10 bounds do  i !  4 +loop ;

\ DMA0 CTRL = DREQ=0, Ring=32, CHAIN=1
\ DMA1 CTRL = CHAIN=0
\ DMA2 CTRL = DREQ=1, Ring=32, CHAIN=3
\ DMA3 CTRL = CHAIN=2
: START         ( -- )
    0955 10 5020,0010 opcodes1  0 set-dma   \ DMA 0 for state machine 0
    0009 01 5000,001C reload    1 set-dma   \ DMA 1 for state machine 0
    9955 10 5020,0014 opcodes2  2 set-dma ; \ DMA 2 for state machine 1
    1009 01 5000,009C reload    3 set-dma   \ DMA 3 for state machine 1


\ Modify the code in the PIO-opcodes array. It calculates
\ the three servo index address. Then it calculates how
\ many opcodes get the maximum delay en sets these. Now
\ it stores the remainder delay and/or zero delays.
: SERVO     ( +n servo -- )     \ valid +n = 13 to 93
    9 umin >r   r@ 6 *  opcodes1 +      \ +n addr     Address of opcode row for 'servo'
    r> 4 >  2 and +  swap               \ addr +n     Correct for pause call
    dm 80 umin  dm 13 +                 \ addr +n+13  Scale servo pulse range
    hx 1F /mod 2>r                      \ addr        Get delay values for opcodes
    r@ for  hx FF over 1+ c!  2 +  next \ addr        Store maximum delays
    2r>  3 swap - for                   \ addr mod    Calc. remainder opc. to adjust
        hx E0 or  over 1+ c!  2 +   0   \ addr 0      Store mod or zero delay
    next  2drop ;

shield PSERVO\
%%

chapter MOVES
\ Small background demo for two servos on GPIO12 & GPIO13

' pservo\ drop
need task
need tasks

task: SERVOS
: MOVES     ( -- )
    begin
        dm 80 0 do 
            i 8 servo
            dm 80 i -  5 umax  9 servo  40 ms
        loop
        dm 80 0 do 
            dm 80 i - 8 servo
            i  5 umax  9 servo  40 ms
        loop
    again ;

: DEMO      ( -- )    start  ['] moves  servos start-task ;
%%

chapter PIOSERVO\
( sm pio gpio +n -- )   \ Use GPIOx to GPIOX+n for RCservo pulse outputs

need pio\     ( Load the pio assembler & disassembler first )
need [if]
depth 4 < [if]  abort  [then]  \ Not enough data
dup 5 1 within [if]  abort  [then]  >r \ Invalid nr. of servo's


\ 50 Hz PWM, range 0 to 200 on GPIO8 to 11 using optional side-set, in 11 opcodes
\ This program stores the pulse reference value in ISR
\ The pulsewidth is ~500µs to 2500µs alrigth for most small RC-servo's

\ need pio\     ( Load the pio assembler & disassembler first )

decimal  

\ The range is 0 to 200, 0 outputs a .5ms pulse, 200 gives a 2.5ms pulse
: SERVO ( +n s -- )
    [ r@ 1- ] literal umin >r  200 umin  50 +  r> >txf ;

200 0 servo ( Is 1.5ms output pulse, this is the center pulse for most servos )

r> 1- >r    ( first servo )  
>r          ( GPIO )
clean-pio                   \ Empty code space mirror
2dup {pio           \ Servo output on GPIOx on sm-y & pio-z
    300000 =freq            \ State machine 0 runs on 300kHz
    r@ 1 =side-pins  opt    \ GPIOx for side-set
    r@ 1 =set-pins          \ GPIOx for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    1 pindirs set,          \ Pin is output
    15 y set,               \ Build servo cycle using Y
    y isr mov,              \ Y register to ISR
    7 null in,              \ ISR = 15 * 128 = 1920µs
    WRAP-TARGET
    0 side  noblock  pull,  \ Output low, pulse X to OSR when empty
    osr x mov,              \ Copy OSR to X
    isr y mov,              \ Copy ISR to Y
    begin,
        x=y? if,            \ (1) Output high when X = Y
        1 side  else,       \ (1)
            nop,            \ (1) Balance execution time of loop
        then,
    y--? until,             \ (1) Count one servo cycle
    WRAP
    0 =exec                 \ Start SM program at address 0
pio}
r> ( GPIO ) 


r@ [if]

150 1 servo ( Is 1.25ms output pulse )

r> 1- >r    ( second servo )  
1+ >r       ( GPIO+1 )
over 1+ over {pio   \ Servo output on GPIOx+1 on sm-y+1 & pio-z
    0 clone                 \ Copy sm-registers from sm-0 to sm-y+1
    r@ 1 =side-pins  opt    \ GPIOx+1 for optional SIDE
    r@ 1 =set-pins
    0 =exec                 \ Start SM at address 0
pio}
r> ( GPIO+1 )

[then]


r@ [if]

100 2 servo ( Is 1.00ms output pulse )

r> 1- >r    ( third servo )  
1+ >r       ( GPIO+2 )
over 2 + over {pio  \ Servo output on GPIOx+2 on sm-y=2 & pio-z
    0 clone                 \ Copy sm-registers from sm-0 to sm-y+2
    r@ 1 =side-pins  opt    \ GPIOx+2 for optional SIDE
    r@ 1 =set-pins
    0 =exec                 \ Start SM at address 0
pio}
r> ( GPIO+1 )

[then]


r> [if] ( fourth servo )

050 3 servo ( Is 0.75ms output pulse )

1+ >r   ( GPIO+3 )
over 3 + over {pio  \ Servo output on GPIOx+3 on sm-y=3 & pio-z
    0 clone                 \ Copy sm-registers from sm-0 to sm-y+3
    r@ 1 =side-pins  opt    \ GPIOx+3 for optional SIDE
    r@ 1 =set-pins
    0 =exec                 \ Start SM at address 0
pio}
r>

[then]
drop  2drop \ Remove data

shield PIOSERVO\
%%

close-lib

v: inside
libhere  lib-org - dm .
v: fresh
