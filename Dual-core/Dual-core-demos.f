(* Demo's that demonstrate programs that are running on two cores

    1) Counter
    2) Switch

*)

\ Demo-1: a counter over two cores
: CORE0         ( -- )      \ Count on core-0 using two cores
    empty-fifo  1 fifo!
    begin
        fifo@ 1+ cr dup . fifo!  50 ms
    key? until
    0 fifo!  empty-fifo ;


: CORE1         ( -- )      \ Display counter from core-0
    begin
    fifo@ ?dup while
        cr dup .  fifo!
    repeat  empty-fifo ;



\ Demo-2: Switch a program status on the other core
: SWITCH        ( -- )
    false  begin
    s? 0= if  invert dup fifo!  1 ms  then
        begin  s? until  10 ms
    key? until  drop  empty-fifo ;


: RESPONSE      ( -- )
    empty-fifo  0  begin
        rxf? if
            fifo@ if  cr ." I am in mode-1 "
            else      cr ." I am in mode-2 "
            then
        then
        1+ dup 800 = if  dup -  ch . emit  then  3 /ms
    key? until  drop  empty-fifo ;

\ End
