(* Ultrasonic sensor readout with PIO using 15 PIO-opcodes

Works on: HC-SR04, US-100, US-015, RCW-0001, RCWL-1605, etc.

\ Trigger = GPIO29
\ Echo    = GPIO28

*)

\ need pio\     ( Load the pio assembler & disassembler first )

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


hex 
v: inside also  definitions
: PDISTANCE) ( -- -1|65536-us ) \ Distance in micro seconds or -1
    2 0 exec-opc                \ Jump to TWO, start measurement!
    begin  dm 10 us  0 rx-depth until  0 rxf> ;

v: extra definitions
: PDISTANCE  ( -- -1|cm )       \ Distance in cm.
    pdistance) dup 0< 0= if     \ Valid measurement?
        hx 10000 swap -         \ Yes, convert to cm
        5 dm 291 */ 
    then ;

: MEASURE3  ( -- )              \ Show distance in cm or a dash
    base @ >r  decimal
    begin   pdistance dup 0< 0= if  \ Valid measurement?
                dup 3 u.r space     \ Yes, show result
            else  ." - " then       \ No, print dash
            drop  9 ms
    key? until 
    r> base ! ;

v: fresh
shield PIO-US\  freeze
