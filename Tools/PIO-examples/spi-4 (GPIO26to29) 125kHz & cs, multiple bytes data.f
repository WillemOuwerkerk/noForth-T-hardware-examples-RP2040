\ Single 8-bit SPI with CSN on state machine 0 and PIO 0, Clock phase = 0
\ Chip enable is done using side-set, data is input using pull. 
\ The Y-register is used to count if a byte is transmitted.
\ SCK  = Side-set pin 0, SPI clock = 125 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK & CSN
0 0 {pio                    \ Use state machine-0 on PIO-0
    500000 =freq            \ 500 kHz
    0 =out-dir              \ OSR shifts to left
    26 2 =side-pins  opt    \ GPIO 26 for SCK, 27 for CSN (SIDE)
    28 1 =out-pins          \ GPIO 28 for OUT
    29 =in-pin              \ GPIO 29 for IN
    1 29 1 =inputs          \ Pull-up on input
    26 4 =set-pins          \ Three pins used

    7 pindirs set,                  \ Pin 26 to 28 are outputs
    wrap-target
        1 []  2 side  pull,         \ CEN high, pop Byte No. in SPI record
        0 side  osr x mov,          \ Save in X
        begin,
            1 []  pull,             \ Next byte
            7 y set,
            begin,
                1 []  0 side  1 pins out, \ Output one bit, clock low
            1 []  1 side  y--? until,     \ Clock high
        0 side  x--? until,
    wrap

    0 =exec                         \ Start at address 0
pio}

: >SPI  ( b0..bn +n -- )   \ +n bytes to SPI
    begin  0 tx-depth  3 < until    \ Space in fifo?
    dup 1-  0 >txf
    0 ?do
        begin  0 tx-depth  3 < until
        24 lshift  0 >txf           \ Yes, move data to highest byte & send
    loop ;


\ Show SPI block output
: DEMO  ( u -- )
    cr  >r  0 r@ 1- do  i  i .  -1 +loop  r> >spi ;

\ End
