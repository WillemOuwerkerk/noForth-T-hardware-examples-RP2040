\ Small text demo with mirrored 'Pico' string, original WJ this version WO

hex
create LINE  70 allot  align
70           value LINE-LEN
line-len 2/  value LINE-MIDDLE

: MIRROR-LINE   ( ch offset -- )
    line-middle over - >r over  r> line + c!
    line-middle over + >r over  r> line + c!
    2drop ;

: MIRROR-STRING ( offset a u -- )
    bounds ?do
        i c@ over mirror-line  1+
    loop  drop ;

: .FT           ( offset -- )
    s"  -<#Pico#>- " mirror-string
    line line-len type cr ;

: AFT           ( -- )
    cr  line line-len bl fill
    30 0 ?do  i 18 - .ft  20 ms  loop ;

: MAFT          ( -- )
    begin  aft  key? until  cr ;

maft
