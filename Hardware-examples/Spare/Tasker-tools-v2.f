(* To add background tasks only:

This point is the main task Task-Control-Block (TCB) is marked as MAIN

00 TLINK   - 0 cells - Link chain with all tasks
04 TSTATE  - 1 cells - Link chain with active tasks
08 ERR?    - 2 cells - Error status of task
0C TRP     - 3 cells - Return stack position of this task
10 BASE    - 4 cells - Number base
14 FP      - 5 cells - FLYER pointer
18 FLYBUF  - 6 cells - Pointer to tasks private memory
1C FLYBUF/ - 7 cells - FLYBUF + #FP = FLYBUF/
20 R0      - 8 cells - Bottom returnstack
24 S0      - 9 cells - Bottom datastack


main task goes on with:
TIB     - Terminal input buffer
TIB/    - TIB end
BORDER  - End of this Forth's memory space


Multitasker built-in words:
HIS         ( "name" -- a ) Prefix to get the address of other tasks
                            values & variables
SLEEP       ( task -- )     Let 'task' sleep, by stopping it
WAKE        ( task -- )     Let 'task' run again by waking it
STOP        ( -- )          Put current task asleep
PAUSE       ( -- )          Do task switch
XHERE       ( -- a )        Leave first free address in XRAM


Multitasker wordset:
START-TASK  ( xt task -- )          Run 'xt' on 'task'
XALLOT      ( n -- )                Reserve 'n'bytes of XRAM
TASK        ( "name" +d +r -- )     Define named task with +d cells D-stack
                                    & +r cells R-stack
TASK:       ( "name" -- )           Define named task with fixed stacks depths,
                                    a 16 cells D-stack and a 32 cells R-stack
LOCK        ( sema -- )             Grab a semaphore when it's free
UNLOCK      ( sema -- )             Free a semaphore when it's mine
TASKS       ( -- )                  Show all defined tasks
TDEPTH      ( task -- +n )          Give stack depth of 'task'
.STK        ( task -- )             Show stack of 'task' like .S
PASS        ( x0 .. xn +n task -- ) Push +n elements to the stack of 'task'
                                    When +n = 0 the stack is emptied

*)

hex \ Multitasker wordset
v: inside also  definitions
' main drop \ This file is for noForth multitask only!

: ?TASK     ( task -- task ) \ Valid task, checks for valid R0
    dup main = ?exit                \ Do nothing on MAIN!
    dup his r0 @ [ xorg 1000 + ] literal  xorg  within ?abort ;

code >TASK  ( ip xt task -- ) \ Set task ready
    B403C950 ,  4630466F ,  46AD6A1D ,
    B41B6A59 ,  60DD466D ,  BC0346BD ,  C804C908 ,
    46A7CA10 ,  end-code
\ code >TASK  ( ip xt task -- )
\    sp  { hop sun } ldm,    \ XT to HOP, IP to SUN
\    { ip sp } push,         \ Save noForth registers
\    moon rp mov,            \ Save RP
\    ip sun mov,             \ Ip to IP
\    day tos 20 #) ldr,      \ Read R0 to DAY
\    rp day mov,             \ Use R0 as tasks RP
\    sp tos 24 #) ldr,       \ Set SP to S0
\    { ip sp tos hop } push, \ Initialise tasks return stack
\    day rp mov,             \ Copy RP to DAY
\    day  tos 0C #) str,     \ Set tasks RP too
\    rp moon mov,            \ Restore noForth registers
\    { ip sp } pop,
\    tos  sp )+ ldr,         \ Pop stack
\    next,
\ end-code

v: extra definitions
: XALLOT    ( n -- )
    xhere over + [ xorg 1000 + ] literal < 0= ?abort  +to xhere ;

create START-TASK  ( xt task -- )   \ Install & start 'task' with 'xt'
    ]  begin  r@ catch to err?  stop  again  [
does>  ( xt task body -- )
    swap ?task >r  false r@ his err? ! \ Reset tasks error flag
    swap r@ >task  r> wake ;        \ Set task ready and start it

: TASK      ( "name" +d +r -- )     \ Build new named task
    here >r  #tcb allot  align      \ Allocate TCB
    r@ #tcb 0 fill                  \ TCB start with all zeros
    TLINK @  r@ !  r@ TLINK !       \ Build this tasks link
    base @  r@ his BASE !           \ Set number base
    xhere  r@ his flybuf !          \ Set start of flyer buffer
    xhere  r@ his FP !   20 xallot  \ Set FP & reserve flyer buffer
    xhere  r@ his flybuf/ !         \ Set FLYBUF end
    cells xallot  xhere r@ his R0 ! \ Reserve R-stack, set R0
    cells xallot  xhere r@ his S0 ! \ Reserve D-stack, set S0
    ['] start-task >body  ['] noop  \ Set tasks IP ready
    r@ >task   r> constant ;        \ Install default task too and name it

: TASK:     ( "name" -- )   10 20 task ;


\ Multitasker tools wordset
v: extra definitions
: RDEPTH    ( task -- +n )
    ?task >r  r@ his r0 @       \ Valid task, read R-stack bottom
    r> his trp @ -  cell / ;    \ Read TRP & calculate depth

: TDEPTH    ( task -- +n )
    ?task  >r r@ main =         \ Valid task and is it MAIN?
    if  rdrop depth exit  then  \ Yes, default DEPTH and ready
    r@ his s0 @                 \ Read address stack bottom
    r> his trp @ cell+ @        \ Read current SP from R-stack
    -  cell / ;                 \ Calculate depth

: .STK      ( <i*x> task -- <i*x> )
    ?task  dup main = if drop .s exit then \ Normal .S for main task
    (.) space  >r  r@ tdepth if         \ Data on tasks stack?
        r@ his s0 @ cell-               \ Yes, to bottom of stack
        r@ tdepth 1-  0F umin           \ Elements without TOS
        for  cell- dup @ .  next drop   \ Show them
        r@ his trp @ cell+ cell+ @ .    \ Print TOS too
    then  rdrop ;

: PASS      ( x0 .. xn +n task -- )
    ?task >r  dup 0< ?abort cells   \ Save task & convert n to cells    x0 .. xn n*4
    r@ his s0 @  over -             \ Calc. stack pointer               x0 .. xn n*4 as1
    r@ his trp @ cell+  !           \ Replace stack pointer             x0 .. xn n*4
    ?dup if                         \ More then one cell?
        swap  r@ his trp @ cell+ cell+  ! \ TOS = xn                    x0 .. xn-1 n*4
        r@ his s0 @ over -          \ Calc. stack address               x0 .. xn-1 n*4 as1
        swap cell- bounds           \ Calc. storage range               x0 .. xn-1 as2 as1
        ?do  i !  cell +loop        \ Store remaining stack data there
    then  rdrop ;

v: inside definitions
\ Tasks viewer
: .NAME     ( task -- )     \ Search for task, type name
    >r  hot 8 cells bounds                      \ for 8 threads     a2 a1
        begin
            dup  begin                          \                   a2 a1 a1
            @ dup while                         \ until link=0      a2 a1 a1@
                dup lfa> >body @ r@ = if        \                   a2 a1 a1@
                    lfa>n @name                 \ Print tasks name in a column
                    0C umin  0C rtype
                    rdrop  2drop  exit
                then
            repeat  drop cell+                  \ Next thread       a2 a1+4
        2dup = until  ?abort ;                  \ Task not found?

: .ACTION   ( task -- ) \ Show words name when it's valid
    dup his r0 @ cell- @ >nfa  ?dup \ Valid NFA?
    if  @name type  drop exit  then \ Yes, show name
    his r0 @ cell- @  . ;           \ No, show address

: .DEC      ( u -- )        decimal  0 <# # # # #> type  hex ;

: .DEPTH    ( task -- ) \ Print stack depth, print ?? when it's out of range
    >r  r@ his s0 @  r@ his r0 @ -  cell / .dec  ch / emit
    r@ tdepth  r@ his s0 @  r> his r0 @ -  cell /
    over u> if  .dec  else  drop ." ???"  then  space space ;

: .RDEPTH   ( task -- ) \ Print return stack depth
    >r  r@ his r0 @  r@ his flybuf/ @ -  cell / .dec
    ch / emit  r> rdepth .dec 3 spaces ;

: .ERROR    ( nfa -- )  \ Print error number or name
    his err? @ dup origin > if \ An ?abort error
        @name 9 umin  9 rtype  2    \ Yes, print name
    else  hex  8 .r  3  then  spaces ; \ No, print number

: .TASK     ( task -- )     \ Show all tasks and their status
    base @ >r  ?task >r  r@ .name space space
    r@ his tstate @ if ." wake  " else ." sleep " then
    r@ .depth   r@ .rdepth
    r@ his base @ .dec 2 spaces
    r@ .error
    r@ main = if  ." Forth "  else  r@ .action  then
    rdrop  r> base ! ;

v: extra definitions
: TASKS     ( -- )      \ Run along chained tasks
    cr ."  --- Task ---------- Stack -- Rstack - base - $error - Action ----"
    main >r                 \ First TCB
    begin
        cr  r@ .task
        r> @ >r
    r@ main = until  rdrop ; \ All tasks done?


\ Semaphores
v: inside definitions
code TC@    ( -- task )     600B3904 ,  C804465B ,  46A7CA10 ,  end-code
\ code TC@   ( -- task ) \ Get active tasks TCB
\    tos  sp -) str,     \ 3 - Save TOS
\    tos TP mov,         \ 1 - TP to TOS
\    next,               \ 6
\ end-code

v: extra definitions
: LOCK      ( sema -- )
    dup @ TC@ = IF  drop exit  THEN \ Do nothing when i own it
    BEGIN  dup @ WHILE pause REPEAT \ Semaphore not mine, to next task
    TC@ swap ! ;                    \ Grab semaphore!

: UNLOCK    ( sema -- )     dup lock  false swap ! ; \ Free semaphore



v: inside also  extra definitions
\ TDONE? / TREADY? / TCOMPLETE? / TFINISHED?  Is a task done with his previous tasks action?
: TREADY?   ( task -- f )       ?task  his tstate @ 0= ;
v: fresh


v: fresh
shield TASKER\

\ End
