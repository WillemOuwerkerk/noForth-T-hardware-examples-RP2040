(* 2) Variable length bamboe driver ( 1 to 5) in only 8 PIO-opcodes

\ 6 bitmask   constant OUT  \ Bamboe data out
\ 7 bitmask   constant CLK  \ Bamboe clock
\ 8 bitmask   constant STR  \ Bamboe strobe

*)

\ need pio\     \ Needs the PIO assembler loaded first

clean-pio  decimal              \ Clear PIO
0 0 {pio
    10,000,000 =freq            \ PIO clock = 10 MHz
    6 3 =set-pins               \ Pins for SET is GPIO6 to GPIO8
    6 1 =out-pins               \ Output = GPIO6
    7 2 =side-pins  opt         \ Side-set pins are GPIO7 & GPIO8
    0 =out-dir                  \ OUT opcode shifts left

    WRAP-TARGET                 \ Start of loop
        2 side  7 pindirs set,  \ GPIO6 to GPIO8 = output, strobe high
        0 side  block pull,     \ Wait for number of bamboe's, strobe low
        osr x mov,              \ Number of bamboe's to X
        begin,
            0 side  block pull, \ Get data byte
            7 y set,            \ Set bit counter Y to 7 (8-bits)
            begin,
                0 side 1 pins out, \ Output one data bit, clock low
            1 side y--? until,  \ Count data bits, clock high
        0 side x--? until,      \ Count bamboes, clock low
    WRAP                        \ Loop back
    over =exec
pio}

\ This example limits the number of chained bamboe's to 5
: >BAMBOE   ( bn .. b0 +n -- )
    5 umin  dup 1-  0 >txf          \ Move number of chained bamboes to fifo
    for                             \ Loop +n times
        dm 24 lshift                \ Align byte to the left
        begin  0 tx-depth 3 < until \ Space in fifo?
        0 >txf                      \ Yes, move aligned byte to fifo
    next ;

\ Example: 2 3 7 3 >bamboe  ( Output data to 3 bamboe's )

\ End ;;;
