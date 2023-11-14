\ Single 8-bit SPI on state machine 0 and PIO 0, Clock phase = 0
\ SCK  = Side-set pin 0, SPI clock = 125 kHz
\ MOSI = OUT pin 0
\ MISO = IN pin 0

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK
0 0 {pio                    \ Use state machine-0 on PIO-0
    500000 =freq            \ 500 kHz
    8 1 =autopush 8 1 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir   \ OSR & ISR shift left
    26 1 =side-pins         \ GPIO 26 for SCK (SIDE)
    27 1 =out-pins          \ GPIO 27 for OUT
    28 =in-pin              \ GPIO 28 for IN
    1 28 1 =inputs          \ Pull-up on input
    26 3 =set-pins          \ Three pins used

    3 pindirs set,                  \ Pin 26 & 27 are outputs
    wrap-target
        1 []  0 side  1 pins out,   \ Output one bit, clock low
        1 []  1 side  1 pins in,    \ Input one bit, clock high
    wrap

    0 =exec                 \ Start SM-0 at address 0
pio}

: >SPI  ( ch -- )   \ Byte to SPI
    begin  0 tx-depth  3 < until \ Space in fifo?
    24 lshift  0 >txf ;     \ Yes, move data to highest byte & send

: SPI>  ( a u -- )  \ Byte from SPI
    begin  0 rx-depth until \ Received data present in fifo?
    0 rxf> ;                \ Yes, read out


\ Show SPI transport, connect pin 27 & 28 for this test
: DEMO  ( u -- )
    0 ?do  cr i .  i >spi  spi> .  loop ;

\ End
