(* Timing of code parts

40054028 constant TIMERAWL  \ Low part of 64-bits timer
0 value T-START

: KICKOFF   ( -- )      timerawl @  to T-start ;
: PASSED    ( -- 탎 )   timerawl @  t-start - ;

here 0 , >r
create KICKOFF  ( -- )
    40054028 ,
    r@ ,
code>
    w  { hop day } ldm,
    w  hop ) ldr,
    w  day ) str,
    next,
end-code

create PASSED   ( -- 탎 )
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

hex
v: inside also definitions
here 0 , >r     \ Storage for timing

create KICKOFF  ( --  )     \ Save timer
   40054028 ,  r@ ,         \ Timer & storage location
code>
    6822CA30 ,  C804602A ,  46A7CA10 ,
end-code

create PASSED   ( -- 탎 )   \ Calculate time passed in 탎
    40054028 ,  r> ,        \ Timer & storage location
code>
    3904CA30 ,  6823600B ,  1B9B682E ,
    CA10C804 ,  FFFF46A7 ,
end-code

: .TIME         ( -- )      \ Print time passed in millisec.
    passed  hx 3E8 /mod  cr
    0 <# #s #> type ." ."
    0 <# # # # #> type ."  millisec. " ;

v: forth definitions
: MEASURE       ( "name" -- ) \ Time the peace of code "name"
    base @ >r  '  kickoff  catch drop
    decimal .time  r> base ! ;

v: fresh
shield TIMING\

\ End
