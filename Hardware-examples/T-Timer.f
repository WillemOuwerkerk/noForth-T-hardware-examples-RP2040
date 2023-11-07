(* Using alarms on the timer unit

    Timer base register: 4005,4000
    Setting the alarms:  4005,4010, etc.

Timer is chapter 4.6 from page 436 ff

Functions:
    ALARM00       ( +n -- )   - Print flags until time has elapsed
    ALARM-0       ( +n -- )   - Idem
    ONE           ( -- f )    - Give true flag when time has elapsed
    TWO           ( -- f )    - Idem
    START-ALARM0  ( -- )      - Start timer controlled flashing LED

*)

40054010 constant ALARM0    \ 00 04 08 0C   Four alarm cells 
40054020 constant ARMED     \ 01 02 04 08   Four armed flags
40054028 constant TIMERAWL  \ Low part of 64-bits timer
40054034 constant INTR      \ 01 02 04 08   Four interrupt flags


\ Primitive alarm functions, the first uses the armed flag!
: ALARM00   ( +n -- )       \ Use alarm-0 with ARMED-flag
    timerawl @ +  alarm0 !  \ Set new alarm time
    begin
        armed @ 1 .r        \ Show alarm status
    1 armed bit** 0= until  \ Ready, when alarm gone off
    cr ." Ready " armed @ . ; \ Show off status

\ Alarm with use of the interrupt flag
: ALARM-0   ( +n -- )       \ Use alarm-0 with INTR-flag
    1 intr **bis            \ Reset interrupt flag
    timerawl @ +  alarm0 !  \ Set new alarm time
    begin
        intr @ 1 .r         \ Show alarm status
    1 intr bit** until      \ Ready, when alarm gone off
    cr ." Ready " intr @ . ; \ Show off status


\ Defining word for alarm functions
: ALARM     ( interval alarm -- f ) \ Define timer using the alarm function
    create  
        swap ,  3 umin          \ Alarm interval
        dup cells  alarm0 + ,   \ Used alarm
        bitmask ,               \ Bit masker
    does>
        dup 2 cells + @         \ Read bit mask
        armed bit** 0= dup if   \ Alarm not enabled or triggered?
            drop  @+ timerawl @ +   \ Ok, calc. next alarm time,
            swap @ !  true  true    \ set it and leave true
        then  nip ;             \ Remove data address

1000 1 alarm ONE    \ Define alarm-1 with 1000 cycles
8000 2 alarm TWO    \ Define alarm-2 with 8000 cycles

\ Als f = false, druk . of anders het karakter van de stack
: .CH       ( f ch -- )    and dup 0= if  drop ch .  then emit ;

\ Test alarm
\
\   one ch A .ch many      \ Test alarm-1
\   two ch B .ch many      \ Test alarm-2
\   one ch A .ch two ch B .ch many


\ Timer alarm-0 interrupt example
code INT-ON     ( -- )      cpsie,  next, end-code
code INT-OFF    ( -- )      cpsid,  next, end-code

: IRQ!      ( a +n -- )     \ Set IRQ vector +n
    1F umin cells  40 +  ivecs +  vec! ;

dm 25 bitmask   constant GPIO-OUT   \ GPIO25 mask
1               constant ALARM0#    \ Alarm-0 mask
50000           constant PERIOD     \ Timer alarm period

routine FLASHES ( -- a )
    { w hop day sun lr } push, \ Save used registers
    data>
        period ,    \ Alarm-0 cycle duration
        40054000 ,  \ Timer base addr. ALARM0=10, TIMERAWL=28, INTR=34
        gpio-out ,  \ Output bit mask
        D000001C ,  \ GPIO_OUT_XOR register
    code>
    w { hop day } ldm,  \ HOP=duration, DAY=timer-base
    sun  day 28 #) ldr, \ TIMER_AWL     Read timer low
    sun hop add,        \ Add duration
    sun  day 10 #) str, \ ALARM0        Store next alarm-0 time

    sun alarm0# # movs, \ Reset alarm-0 interrupt flag
    sun  day 34 #) str, \ INTR
    w { hop day } ldm,  \ HOP=GPIO-OUT, DAY=GPIO_XOR
    hop  day ) str,     \ Toggle GPIO-OUT

    { w hop day sun pc } pop, \ Restore used registers
end-code

: START-ALARM0  ( -- )
    int-off                 \ Disable interrupts
    2000000 D0000020 !      \ GPIO_OE       set GPIO25 as output
    flashes  0 irq!         \ TIMER_IRQ_0   Install IRQ vector
    alarm0# 40054034 !      \ INTR          clear alarm-0 interrupt flag
    alarm0# 40054038 !      \ INTE          enable alarm-0 interrupt
    1 E000E100 !  int-on    \ NVIC_ISER     enable timer interrupt 0 in NVIC
    timerawl @ period +  alarm0 ! ; \ Start alarm-0 of timer unit

\ start-alarm0

\ End
