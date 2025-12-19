\ INSPECT\

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
                    r@ cell+
                    r@ @ = 1-
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
