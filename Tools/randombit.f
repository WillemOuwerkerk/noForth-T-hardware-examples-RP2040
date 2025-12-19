(* Use of Randombit register

    4006,0000   = 0FAB0FA5
    4006,001C   = Bit 0

*)

: RND1          ( -- u )
    0FAB,0FA5 4006,0000 !  0
    10000 for
        4006,001C @ +
    next
    0D1E,0FA5 4006,0000 ! ;

create RND2     ( -- u )
    0FAB,0FA5 ,
    4006,0000 ,
    0D1E,0FA5 ,
code>
    tos  sp -) str,
    w  { hop day sun } ldm,
    hop  day ) str,
    tos 0 # movs,
    moon 1 # movs,
    moon 10 # lsls,
    begin,
        w  day 1C #) ldr,
        tos w adds,
        moon 1 # subs,
    =? until,
    sun  day ) str,
    next,
end-code

