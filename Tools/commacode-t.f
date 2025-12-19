(* wo/an 6apr25, comma code for noForth t

    This version is correct for both literal POOL uses.

*)

hex
: COMMACODE   ( -- )     \ assembler code, not using the assembler
    created lfa> @+ swap                    \ doer body
    cr   2dup = if ." code "                \ Normal CODE word?
    else 2dup chere within if ." create "   \ Word with data?
    else over ['] create >body              \ No, (sub)routine?
         <> ?abort  ." routine "
    then then
    created lfa>n count hx 1F and type      \ .name
    begin cr 4 0
        do  dup chere < 0=                  \ End range?
            if drop 0 leave then
            @+ u. ." , "
            2dup = if cr ." code> " then    \ adr = doer?
        loop ?dup 0=
    until drop ." end-code " cr ;

: CM    commacode ;


(* Test commacode

code aap     noop, noop, next, end-code                COMMACODE
create noot  1234 , code> noop, next, end-code   COMMACODE
create mies  1234 h, code> noop, next, end-code  COMMACODE
routine wim  noop,  lr bx, end-code              COMMACODE
code ina     wim  dup bl,  bl,  end-code         COMMACODE
0 value tel
create ron  adr tel , code> w { hop } ldm, next end-code cm

*)
