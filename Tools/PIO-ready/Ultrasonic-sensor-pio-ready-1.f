(* Ultrasoon afstand meter via PIO, in 15 PIO-opcodes

Works on: HC-SR04, US-100, US-015, RCW-0001, RCWL-1605, etc.

\ Trigger = GPIO29
\ Echo    = GPIO28

\ need pio\     ( Needs to PIO assembler to be loaded first )

clean-pio  decimal          \ Clear PIO
0 0 {pio
    2,000,000 =freq         \ Clock = 2 MHz

    28 2 =set-pins          \ Both used pins for SET
    28 =in-pin              \ Echo = GPIO28
    28 =jmp-pin             \ GPIO28 also for PIN?
    1 28 1 =inputs          \ GPIO28 with pullup

    0 =out-dir              \ OUT opcode shifts left
    29 1 =out-pins          \ Trigger = GPIO29

    2 pindirs set,          \ GPIO28 = input, GPIO29 = output
    ONE  begin, again,      \ Wait for start command

    TWO  1 x set,           \ 1 to X, build timeout value
    x osr mov,              \ Move 1 to OSR
    16 x out,               \ OSR 1 << 16 = 65636, 65,6 ms timeout
    osr x mov,              \ Move OSR to X
    21 [] 2 pins set,       \ Generate 10 µs trigger pulse
    31 [] 0 pins set,       \ Skip glitches

    high 28 gpio wait,      \ Echo pulse on GPIO28 started?
    begin,                  \ Measure echo pulse length
        pin? if,            \ Echo pulse ending (GPIO28 low)?
            THREE  x isr mov, \ Push measured echo pulse
            noblock push,
            ONE> pio,       \ Ready, jump to wait loop
        then,
    x--? until,             \ Timeout on echo?
    THREE> pio,             \ Timeout result = -1, push it
    over =exec
pio} 

*)

\ need piobase\  ( Needs to PIObase routines to be loaded first )

hex
v: inside also  definitions
: START-US  ( -- )
    00000000 50200000 ! \ Setup PIO machine 0 0 on GPIO28 & 29
    003E8000 502000C8 !
    00000006 400140E4 !
    1C01F000 502000CC !
    0000005A 4001C074 !
    00040000 502000D0 !
    081E039D 502000DC !
    00000006 400140EC !
    0000E082 50200048 ! \ PIO program
    00000001 5020004C !
    0000E021 50200050 !
    0000A0E1 50200054 !
    00006030 50200058 !
    0000A027 5020005C !
    0000F502 50200060 !
    0000FF00 50200064 !
    0000209C 50200068 !
    000000C0 5020006C !
    0000A0C1 50200070 !
    00008000 50200074 !
    00000001 50200078 !
    000000CD 5020006C !
    00000049 5020007C !
    0000000A 50200080 !
    00000000 502000D8 ! \ Start PIO-program
    00000001 50200000 !
    00000000 =pio ;

: PDISTANCE) ( -- -1|65536-us ) \ Distance in micro seconds or -1
    2 0 exec-opc                \ Jump to TWO, start measurement!
    begin  dm 10 us  0 rx-depth until  0 rxf> ;

v: extra definitions
: PDISTANCE  ( -- -1|cm )       \ Distance in cm.
    pdistance) dup 0< 0= if
        hx 10000 swap -
        5 dm 291 */ 
    then ;

: MEASURE3  ( -- )              \ Show distance in cm or a dash
    start-us  base @ >r  decimal
    begin   pdistance dup 0< 0= if
                dup 3 u.r space  dm 15 ms
            else  ." - " then
            drop  5 ms
    key? until 
    r> base ! ;

v: fresh
shield PIO-US\  freeze
