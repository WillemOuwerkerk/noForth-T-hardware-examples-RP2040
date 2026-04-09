(* ** 32-bits Marsaglia generator ***************
  generator with good quality and normally distributed random numbers
  32 bit state -> 2^32-1 long cycle
  The shift factors are critical, only use:
        6, 7, 13    or  7, 9, 8 ( used below )
    or  7, 9, 13    or  9, 7, 13
   **********************************************

0 value STEP
: MOVE-CARS         ( -- )
    incr step  cr step 3 .r ." : "\
    #order 0 ?do
        step  i car-order c@ cars speed  mod
        0= if  i .  then
    loop ;

: T1                ( -- )
    0 to step  begin  move-cars  20 ms  key? until ;

*)

\ need WS2812\     ( Load the WS2812B-multi-color-driver.f file first )

hex
2345 value SEED0        \ at least one of the seeds must be seeded with a non-zero number
6789 value SEED1

1 [if]

: RANDOM    ( -- u )                \ 28s
    seed0 seed1 to seed0            \ put seed0 on stack and move value of seed1 to seed0
    dup 0D lshift xor               \ see comments above for the shift-factors
    dup 11 rshift xor
    dup 05 lshift xor
    dup seed1 xor to seed1 ;        \ xor new 16b rando with old value in seed1

[else]

create RANDOM ( -- u )
    adr SEED0 ,
    adr SEED1 ,
code>
    tos  sp -) str,
    w  { tos hop } ldm,     \ Read seed addresses
    day  tos ) ldr,         \ DAY = seed0
    sun  hop ) ldr,         \ SUN = seed1
    sun  tos ) str,         \ seed0 <- seed1
    tos day 0D # lsls.mv,   \ 13 lshift xor
    tos day eors,
    day tos 11 # lsrs.mv,   \ 17 rshift xor
    tos day eors,
    day tos 5 # lsls.mv,    \ 5 lshift xor
    tos day eors,
    day tos movs,           \ TOS = result 'u'
    day sun eors,           \ DAY = xor result & seed1
    day  hop ) str,         \ seed1 <- DAY
    next,
end-code

[then]

\ ---------- Backlight ------------ Car color ------------ Headlight  Pos  Speed
create CAR1   darkred ,     green ,     green ,     green ,  white ,  -1 ,   0 ,
create CAR2   darkred ,    yellow ,    yellow ,    yellow ,  white ,  -1 ,   0 ,
create CAR3   darkred ,   darkred ,   darkred ,   darkred ,  white ,  -1 ,   0 ,
create CAR4   darkred , bluegreen , bluegreen , bluegreen ,  white ,  -1 ,   0 ,
create CAR5   darkred ,    purple ,    purple ,    purple ,  white ,  -1 ,   0 ,
create CAR6   darkred ,    orange ,    orange ,    orange ,  white ,  -1 ,   0 ,
create CAR7   darkred , darkgreen , darkgreen , darkgreen ,  white ,  -1 ,   0 ,
create POLI   darkred ,  darkblue ,  darkblue ,  darkblue ,  white ,  -1 ,   0 ,


\ Motorway simulation, speed = 0 to 8, pos=-1 (not active) pos 0 to +n (road position)

0 value T?
: TRACE     true to T? ;  trace
: NOTRACE   false to T? ;

0 value STEP
0 value #ORDER
: .ROAD     ( +n -- )
    dup 0 > if  dup +to #pos  black over >out  then  drop ;

: CHOOSE    ( u1 - u2 )         random um* nip ;
: 'POSITION ( car -- a )        5 cells + ;
: POSITION  ( car -- n )        'position @ ;
: 'SPEED    ( car -- a )        6 cells + ;
: SPEED     ( car -- +n )       'speed @ ;
: DISTANCE  ( car0 car1 -- +n ) position >r  position  r> - abs 5 - ;
: .START    ( car -- )          position dup 4 > if 4 - .road else drop then ;
: POLI?     ( car -- f )        cell+ @ darkblue = ;

: FLASH     ( car -- car )
    step 2 mod ?exit
    dup poli? if
        dup 2 cells + >r
        r@ @ darkblue =
        if 30 else darkblue then
        r> !
    then ;

: .CAR      ( car -- )
    dup position 4 umin >r   4 r@ - cells  +
    r> 1+ for  @+ 1 >rgb  next  drop ;

create CARS         ( +n -- car )
    car1 ,  car2 ,  car3 ,  car4 ,  car5 ,  car6 ,  car7 ,  poli ,
    does> swap cells + @ ;
create CAR-ORDER    ( +n -- a )
    0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,  align  does> + ;


: ADD-CAR           ( +n -- )
    dup cars position 0< if
        darkred over cars !             \ Normal backlight
        0 over cars 'position !
        9 choose 2 umax over cars 'speed  !
        0 car-order dup 1+ #order move
        0 car-order c!  incr #order
   else drop then ;

: LOCATE    ( +n -- p ) car-order c@ cars position ;
: FARTHEST  ( -- +n )   0  #order for  i locate umax  next ;
: AWAY      ( -- +n )   0 locate ;
: STEP?     ( +n -- f ) step  swap car-order c@ cars speed  mod 0= ;

0 value #BR     \ Brake earlyer at high speed difference
: BRAKE             ( car2 car1 distance -- car2 distance )
    >r  over speed  over speed -    \ c2 c1 spd-diff
    2 > 2 and to #br                \ c2 c1
    r@ 2 6 #br + within if          \ c2 c1
        r@ 2 = if                   \ c2 c1
            over speed              \ c2 c1 s2
            over 'speed !           \ c2 c1
            dup darkred swap !      \ Brakelight off car1
        else
            dup 2000 swap !         \ Brakelight on car1
            over speed 1-           \ c2 c1 s2-1
            over >r r@ speed 1+     \ c2 c1 s2-1 sa1
            umin r> 'speed !        \ c2 c1
        then
        drop  r>  exit              \ c2 dist
    then
    darkred swap !  r>              \ Brakelight off car1
    ;

: MOVE-CARS         ( -- )
    incr step  #order 0 ?do
        i step? if
            1  i car-order c@ cars  flash  'position  +!
        then
    loop ;

v: inside
: .CARS             ( -- )
    #order t? if dup . then  0 ?do
        t? if i car-order c@ cars  dup cell- >nfa @name type then
        i if
            i car-order c@ cars         ( c2 )
            i 1- car-order c@ cars      ( c2 c1 )
            2dup distance               ( c2 c1 dist )
            brake  .road  .car
        else
            i car-order c@ cars  dup .start .car
        then
        t? if #br if ch - else ch : then  emit  speed . then
    loop  ready  clr ;

: .SIM      ( -- )
    #order  dup .  0 ?do
        cr i car-order c@ dup .
        cars  dup position 3 .r space
        dup cell- >nfa @name type
        ." : "  speed .
    loop ;
v: forth

: INI-SIM   ( -- )
    dm 300 >leds  black all
    dm 150 >leds  dm 150 >field
    0 to #order  0 to step
    8 for  i cars 'position -1 swap !  next
    0 car-order 7 0 fill ;

\       cr  20 farthest dup 3 .r space
\       1A / -  dup 2 .r space 0 max ms
: SIM)      ( -- )
    begin
        100  farthest  t? if cr dup 3 .r space then
        10 2E */ -  t? if dup 3 .r space then  dm 100 *  0 max us
        random drop  t? if step 3 .r ." : " then          \ -
        #order 8 = if                           \ -
            away dm 150 > if  ini-sim  then     \ -
        then
        away 20 u> if                           \ -
            30 choose  dup 8 < if               \ +n
                dup add-car                     \ +n
            then  drop
        then
        .cars  move-cars
    stop? until ;

: SIM       ( -- )      ws2812-setup  ini-sim  sim) ;

ws2812-setup  black all  ini-sim

\ End
