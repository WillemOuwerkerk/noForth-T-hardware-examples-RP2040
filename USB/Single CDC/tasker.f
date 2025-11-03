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
