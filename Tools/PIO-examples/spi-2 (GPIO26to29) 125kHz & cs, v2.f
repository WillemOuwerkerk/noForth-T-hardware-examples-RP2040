\ Single 8-bit SPI with CSN on state machine 0 and PIO 0, Clock phase = 0
\ SCK  = Side-set pin 0, SPI clock = 125 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK & CSN
0 0 {pio                    \ Use state machine-0 on PIO-0
    750000 =freq            \ 750 kHz
    8 1 =autopush 8 0 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir   \ OSR & ISR shift left
    26 2 =side-pins         \ GPIO 26 for SCK, 27 for CSN (SIDE)
    28 1 =out-pins          \ GPIO 28 for OUT
    29 =in-pin              \ GPIO 29 for IN
    1 29 1 =inputs          \ Pull-up on input
    26 4 =set-pins          \ Three pins used

    7 pindirs set,          \ Pin 26 to 28 are outputs
    wrap-target
        0 side  nop,
        begin,
            2 []  0 side  1 pins out,   \ Output one bit, clock low
            1 []  1 side  1 pins in,    \ Input one bit, clock high
        1 side  osre? until,
        0 side  nop,                    \ Gap
        1 []  2 side  pull,             \ CEN high again
    wrap

    0 =exec                 \ Start at address 0
pio}

: >SPI  ( b -- )   \ Byte to SPI
    begin  0 tx-depth  3 < until \ Space in fifo?
    24 lshift  0 >txf ;     \ Yes, move data to highest byte & send

: SPI>  ( -- b )  \ Byte from SPI
    begin  0 rx-depth until \ Received data present in fifo?
    0 rxf> ;                \ Yes, read out

: SPI   ( b1 -- b2 )        >spi  spi> ;


\ Show SPI transport, connect pin 27 & 28 for this test
: DEMO  ( u -- )
    0 ?do  cr i .  i spi .  loop ;

\ End
