\ Write current FROZEN version to an Intel-Hex stream
\ The stream can be copied & saved to an ASCII-file.
\ Use: CORE IMAGE  or  CORE+ IMAGE  or  CORE+LIB IMAGE
\ This file can then be converted to a UF2 file using the
\ HEX>UF2 tool, that can be loaded & executed in Win32Forth
\ Usage: HEX>UF2 "filename"
\ Write current FROZEN version to an Intel-Hex stream
\ The stream can be copied & saved to an ASCII-file.
\ Use: CORE IMAGE  or  CORE+ IMAGE  or  CORE+LIB IMAGE
\ This file can then be converted to a UF2 file using the
\ HEX>UF2 tool, that can be loaded & executed in Win32Forth
\ Usage: HEX>UF2 "filename"

hex v: inside also  definitions
  1000,0000 constant XIP        \ Start of XIP memory
v: forth definitions
: CORE      ( -- end start )    \ Boot image only!
    1000,0100 dup @ +   \ noForth first core
    4 cfg @ if          \ noForth dual core?
        dup @ +         \ Yes, add second core too
    then  xip ;

: CORE+     ( -- end start )    \ Boot & auxillary image too
    1008,1000 dup @ +   \ noForth first core
    4 cfg @ if          \ noForth dual core?
        dup @ +         \ Yes, add second core too
    then  xip ;

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
        0 ?do count .xx loop    \ data
        chks negate .xx         \ checksum
    repeat
    drop 2drop ." :0000000001FF" cr
    40 ms  config ;             \ To keep USB & data alive
v: fresh

\ end ;;;   10000100 10000000 image
