(*  .STACK "ccc"

    Show stack comment for a library chapter

*)

: .LINE     ( a1 -- a2 ch )
    begin c@+ dup BL < 0= while emit repeat ;

v: inside
: .STACK     ( "ccc" -- )
    bl-word count find-chapter
    dup 80 + swap 0D scan nip 1+
    4 for   cr .line 09 =   \ Number of lines to show, quit at EOF
            if r> 2drop exit then
    next drop ;
v: forth

