\ Single 8-bit SPI on state machine 0 and PIO 0, Clock phase = 0
\ The chip select line is constructed using a normal GPIO-bit
\ SCK  = Side-set pin 0, SPI clock = 250 kHz
\ MOSI = OUT pin 0
\ MISO = IN pin 0
\ CSN  = Controlled by Forth software

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK
0 0 {pio                    \ Use state machine-0 on PIO-0
    1000000 =freq           \ 1 MHz
    8 1 =autopush 8 1 =autopull \ 8-bits data records
    0 =out-dir  0 =in-dir   \ OSR & ISR shift left
    26 1 =side-pins         \ GPIO 26 for SCK (SIDE)
    27 1 =out-pins          \ GPIO 27 for OUT
    28 =in-pin              \ GPIO 28 for IN
    1 28 1 =inputs          \ Pull-up on input
    26 3 =set-pins          \ Three pins used

    3 pindirs set,                  \ Pin 26 to 28 are outputs
    wrap-target
        1 []  0 side  1 pins out,   \ Output one bit, clock low
        1 []  1 side  1 pins in,    \ Input one bit, clock high
    wrap

    0 =exec               \ Start at address 0
pio}

: >SPI  ( ch -- )   \ Byte to SPI
    begin  0 tx-depth  3 < until \ Space in fifo?
    24 lshift  0 >txf ;     \ Yes, move data to highest byte & send

: SPI>  ( a u -- )  \ Byte from SPI
    begin  0 rx-depth until \ Received data present in fifo?
    0 rxf> ;                \ Yes, read out


hex     \ Manual CHIP enable (active low)
D0000000 constant SIO_BASE
SIO_BASE 20 + constant GPIO-OE      \ GPIO output enable
SIO_BASE 10 + constant GPIO-OUT     \ GPIO output

20000000 gpio-out **bis  \ Disable CSN line (high) GPIO 29

\ Show SPI transport, connect pin 27 & 28 for this test
: DEMO  ( u -- )
    20000000 gpio-oe **bis                      \ Enable GPIO 29
    0 ?do
        cr  20000000 gpio-out **bic             \ Enable low
        i 4 over + do  i >spi spi>  i  -1 +loop \ Output SPI data record
        5 us  20000000 gpio-out **bis           \ Enable high
        5 0 do 2 .r space 2 .r 2 spaces  loop   \ Show data
    5 +loop ;

\ End
