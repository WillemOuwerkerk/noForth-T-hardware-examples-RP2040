(* Build or extend a library, size: 1356 bytes

library source example:

"libname"   ( Select library to act on )
WIPE-LIB    ( Erase library from flash , allow adding too )

CHAPTER UNUSED
Leave available memory space

v: forth definitions
: UNUSED    ( -- u )            flybuf here - ;
%%

CHAPTER 125MHZ
change clock frequency

dm 125      0 cfg ! \ Set frequency in MHz
4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image
config              \ Test new configuration
%%

CLOSE-LIB ( Save remaning library sector and close library for writing )

Flash memory map:
    1000,0000   = Boot sector
    1000,0100   = Start of bootable noForth system
    1004,1000   = Start of noforth system-2 ( FREEZE2 & COLD2)
    1008,1000   = Start of library ( LIB-ORG )
    100D,26C9   = Used part of library ( LIBHERE )
    1010,0000   = Limit for library
    1020,0000   = End of smallest Flash memory ( max = 1100,0000 )
*)

here  hex
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

create ADJUST   ( -- )  \ ADJUST library pointer; 28 bytes
    10081000 ,  adr libhere ,
code>
    7826CA30 ,  2EFF3401 ,  3C01D1FB ,  C804602C ,  46A7CA10 ,
end-code

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
    lib? ?abort  true to lib?       \ Abort when lib is open?, otherwise open it
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
    lib? ?abort  adjust             \ Abort when library is open, otherwise adjust LIBHERE
    lib-org xip -                   \ Convert to start sector address
\   libhere lib-org -  1000 +       \ Calculate lib size
\   FF000 and                       \ Round to next 1000
    7F000                           \ Take a 508 kByte block
    {W  wipe-flash  W}              \ Erase whole library space
    lib-org to libhere  open-lib ;  \ And reset library pointer

v: fresh
here swap - dm .

\ End
