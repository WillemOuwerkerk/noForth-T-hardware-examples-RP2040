(* NEED vsn 0.52 a library mechanism with multiple "files", 1092 bytes

There are tools to add a library (part) to noForth:

1) WIPE-LIB     (-- )           Erase current library
2) OPEN-LIB     ( -- )          Open flash for writing to the library
3) CHAPTER      ( "name" -- )   Add new code section to library
                                "name" is the keyword
                                ending with %% at the last line
4) CLOSE-LIB    ( -- )          Write incomplete sector buffer
                                & close flash for writing
An example:

open-lib
chapter ROLL
v: forth definitions
: ROLL  ( i*x u -- j*x )    \ Roll item u to TOS
    dup 1 <
    if      drop
    else    swap >r 1- RECURSE r> swap
    then ;
%%
close-lib

NEED is made up out of few parts and a list tool:

01) FIND-CHAPTER   ( a +n -- sa )     Find name a b, leave source address sa when found
02) REFILL-CHAPTER ( s-id -- f )      Tailor made REFILL for library
03) LOAD-CHAP      ( sa -- )          Load library section
04) NEEDED         ( a b -- i*x )     Find string a b and add the source chapter
05) NEED           ( "ccc" -- i*x )   Find "ccc" and add the source chapter
06) CHAPTERS       ( -- )             Show all labelled source parts

In the library:
07) LOOK           ( "name" -- )      Show all code parts from "name" onwards a space
                                      shows more or the next chapter, any other key stops
08) WIPE-LIB       ( -- )             Erase current selected library completely
09) OPEN-LIB       ( -- )             Open current selected library for writing
0A) CLOSE-LIB      ( -- )             Close current selected library for writing

There are three new word internal words:
    XIP         Constant of XIP (external Flash) base address
    LIB-ORG     Lbrary start adress
    LIBHERE     Actual end address of library until now

Basic function is to search a string in a memory area from 10081000.
This is the basic structure of this library mechanism:

1) Start of a new source section:       09 \ BL "name"
2) End of that line:                    0D
3) End of source section:               09
4) End of library:                      LIBHERE

*)

hex  here
v: inside also definitions
\ 1000,0000 constant XIP    \ Start of XIP memory
  1008,1000 value LIB-ORG   \ Default LIB start address
  lib-org   value LIBHERE   \ Actual end address of library until now
  0 value HARDWARE)         \ Speedup points
  0 value PIO)
  0 value #CHAP             \ Chapter counter

v: inside also definitions
: LIBSTART  ( -- )      [ lib-org ] literal  to lib-org ;

create FC   ( a u -- a f )      \ Find chapter name in curent library
   adr lib-org ,  adr libhere , \ Leave chapter start address & false when found
code>                           \ Otherwise the address 'libhere' & true
    6824CA30 ,  680E682D ,  469946B0 ,
    34017822 ,  D1FB2A09 ,  DD1642A5 ,  340246A2 ,
    34017822 ,  464F4646 ,  36017833 ,  D10B4293 ,
    34017822 ,  D1F73F01 ,  D1052A20 ,  600C4654 ,
    C8042300 ,  46A7CA10 ,  600CE7E2 ,  43DB2300 ,
    CA10C804 ,  FFFF46A7 ,
end-code

: FIND-CHAPTER ( a b -- sa )
    >fhere count 2dup upper \ Place as counted string a,b at FP, make uppercase
    fc  libstart  ?abort ;  \ Issue error when not found!

: LOAD-CHAPTER ( a b -- )   \ a,b=name, load a source section
    find-chapter
    @input >r 2>r           \ Save current input source
    to source-id            \ Set new input source
    #ib >in !  interpret    \ Force a REFILL when loading source section
    2r> r> !input ;         \ ib #ib,>in@ source-id restore input source

: REFILL-CHAPTER ( s-id -- f ) \ Get next line from a source section
    to ib  false            \ Start of new line
    ib c@ 09 = ?exit        \ End of source section, ready
    ib FF + ib  0D scan     \ Find 0D (end of current line)
    dup ib - to #ib         \ Calc. & save line length
    1+ to source-id  drop   \ Save start of next line (behind 0D)
    >in !  true  ;          \ Refill succeeded

v: extra definitions
: NEEDED    ( a u -- )          \ Add library word when it's not present
    2dup >fhere  find nip 0=    \ in the current forth search order
    if   load-chapter
    else 2drop libstart then ;  \ Restore library start

: RUN       ( i*x ccc -- j*x )      bl-word count  load-chapter ;
: NEED      ( i*x ccc -- j*x )      bl-word count  needed ;

0 value SGR?
v: inside definitions
: SGR       ( +n -- )
    sgr? if                             \ Use graphic rendition?
        hor >r  dm 27 emit  ch [ emit   \ CSI
        base @ hex  over  0 .r  base !  \ ASCII values of SGR parameters
        ch m emit  r> to hor            \ Close & correct HOR
    then  drop ;

v: extra definitions
: CHAPTERS  ( -- )      \ Show all chapters in current library
    base @  decimal  0 sgr
    libhere lib-org                 \ library address range
    cr  0 to #chap
    begin
        space  9 scan 3 + 2dup >    \ Still within range?
    while
        2dup                        \ Save range
        0D scan dup 1+ c@ ch ( =    \ Any stack comment?
        if 96 sgr ." ()" 0 sgr then \ Yes, mark chapter name
        2drop  begin
            count bl over <         \ Header not done?
        while  emit  repeat         \ Print next char.
        drop  space
        40 hor < if cr then  10 us  \ Line full?
        incr #chap
    repeat
    2drop  libstart
    cr space  #chap .  ." code chapters "  base ! ;

: HARDWARE  ( -- )      hardware)   to lib-org ;
: PIO       ( -- )      pio)        to lib-org ;

' refill-chapter  to &refill \ Add REFILL for library chapters
100A5000 to libhere \ Temporary LIBHERE for restauration

v: fresh
shield NEED\

here swap - dm . ( size )

\ End
