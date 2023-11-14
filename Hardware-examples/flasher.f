\ My first PIO LED control on GPIO 25, adjustable flasher
\ Code generated with the noForth t Forth style PIO assembler
\
\ 0: E081 set  pindirs 1
\ 1: 0001 jmp  to: 1
\ 2: FF01 set  pins 1     [1F]
\ 3: FF50 set  y 10       [1F]
\ 4: FF00 set  pins 0     [1F]
\ 5: 1F84 jmp  y-- to: 4  [1F]

hex
: PIO-FLASH     ( -- )
    F4240000 502000C8 ! \ Clock = 2000 Hz
    6 400140CC !        \ Enable PIO on pin 25
    4000320 502000DC !  \ Only pin 25 for SET
    0 50200000 !        \ All SM's off

    E081 50200048 !     \ Pindirs = 1
    0001 5020004C !     \ Wait loop
    FF01 50200050 !     \ LED on
    FF50 50200054 !     \ y = 16
    FF00 50200058 !     \ LED off
    1F84 5020005C !     \ Y-- until

    6100 502000CC !     \ Set wrap loop
    0001 50200000 ! ;   \ Start SM0

: LED-OFF   E000 502000D8 !  1 502000D8 ! ; \ Pin 25 off, jump to address 1
: LED-ON    E001 502000D8 !  1 502000D8 ! ; \ Pin 25 on, jump to address 1

: FLASH         ( +n -- )   \ Starts flasher with adjustable tempo!
    led-off  1F and  1F swap -          \ Stop flasher & build new delay
    FF40 or 50200054 !  2 502000D8 ! ;  \ Change opcode & jump to address 2

: START         ( -- )  \ Start PIO flasher as startup
    pio-flash  1 ms  10 flash ;

' start to app  ( freeze )

\ End
