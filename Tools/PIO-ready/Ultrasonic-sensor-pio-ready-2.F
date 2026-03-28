(* Ultrasoon afstand meter via PIO, in 15 PIO-opcodes

Works on: HC-SR04, US-100, US-015, RCW-0001, RCWL-1605, etc.

\ Trigger = GPIO29
\ Echo    = GPIO28

\ need pio\     ( Needs to PIO assembler to be loaded first )

clean-pio  decimal          \ Reset PIO control
0 0 {pio                    \ Use SM-0 on PIO-0
    1,000,000 =freq         \ Clock = 1 MHz
    28 2 =set-pins          \ Both used pins for SET
    28 =in-pin              \ Input = GPIO28
    28 =jmp-pin             \ PIN? = GPIO28
    1 28 1 =inputs          \ GPIO28 = Pullup
    29 1 =side-pins         \ Output = GPIO29

    2 pindirs set,              \ GPIO28 = input, GPIO29 = output
    ONE  block pull,            \ Wait for timeout value
    9 [] 1 side  osr x mov,     \ Timeout to X, 10 µs start pulse

    high 28 gpio wait,          \ Input pulse on GPIO28 started?
    begin,                      \ Measure pulse length
        pin? if,                \ GPIO28 low?
            TWO  x inv isr mov, \ (1) Push inverted result
            block push,
            ONE> pio,           \ Result = -1, jump to wait
        then,
    x--? until,                 \ (1) Timeout?
    TWO> pio,                   \ Jump to result
    over =exec                  \ Start program
pio} 

*)

\ need piobase\  ( Needs to PIObase routines to be loaded first )

hex
v: inside also  definitions
: START-US  ( -- )
    00000000 50200000 ! \ Setup PIO machine 0 0 on GPIO28 & 29
    007D0000 502000C8 !
    00000006 400140E4 !
    00000006 400140EC !
    1C01F000 502000CC !
    0000005A 4001C074 !
    280E7780 502000DC !
    0000E082 50200048 ! \ PIO code
    000080A0 5020004C !
    0000B927 50200050 !
    0000209C 50200054 !
    000000C8 50200058 !
    0000A0C9 5020005C !
    00008020 50200060 !
    00000001 50200064 !
    00000044 50200068 !
    00000005 5020006C !
    00000000 502000D8 ! \ Start this PIO program
    00000001 50200000 !
    00000000 =pio ;

: PDISTANCE) ( -- 100us to 32900us ) \ Distance in micro seconds
    true 0 >txf                 \ Start measurement
    begin  dm 10 us  0 rx-depth until  0 rxf> ;

v: extra definitions
: PDISTANCE  ( -- mm )           \ Scale result to millimeter
    pdistance) dm 1000 dm 291 */ ;

: MEASURE3  ( -- )              \ Show distance in mm or a dash
    start-us  base @ >r  decimal
    begin   pdistance dup dm 45000 < if \ 450cm is maximum distance!
                dup 0 <# # # ch . hold #s #> type space  5 ms
            else  ." - " then
            drop
    key? until 
    r> base ! ;

v: fresh
shield PIO-US\  freeze
