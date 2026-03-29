(* Ultrasonic sensor readout with PIO in only 10 PIO-opcodes

Works on: HC-SR04, US-100, US-015, RCW-0001, RCWL-1605, etc.

\ Trigger = GPIO29
\ Echo    = GPIO28

*)

\ need pio\     \ Needs the PIO assembler to be loaded first

clean-pio  decimal          \ Clear PIO
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
            ONE> PIO,           \ Result = -1, jump to wait
        then,
    x--? until,                 \ (1) Timeout?
    TWO> pio,                   \ Jump to result
    over =exec                  \ Start program
pio} 


hex 
v: inside also  definitions
: PDISTANCE) ( -- 100us to 32900us )
    true 0 >txf                 \ Start measurement!
    begin  dm 10 us  0 rx-depth until  0 rxf> ;

v: extra definitions
: PDISTANCE  ( -- mm )          \ Distance in mm.
    pdistance)  dm 1000 dm 291 */ ;

: MEASURE3  ( -- )              \ Show distance in mm or a dash
    base @ >r  decimal
    begin   pdistance dup dm 45000 < if  \ 450cm is maximum distance!
                dup 0 <# # # ch . hold #s #> type space
            else  ." - " then  drop  9 ms
    key? until 
    r> base ! ;

v: fresh
shield PIO-US\  freeze
