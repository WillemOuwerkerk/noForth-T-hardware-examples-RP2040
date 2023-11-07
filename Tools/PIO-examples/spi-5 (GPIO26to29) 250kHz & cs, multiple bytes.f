\ Multiple 8-bit SPI blocks with CSN on state machine 0 and PIO 0, Clock phase = 0
\ Chip enable is done using side-set, data input is done using pull
\ OSRE? is used to check if a byte is transmitted.

\ SCK  = Side-set pin 0, SPI clock = 250 kHz
\ CSN  = Side-set pin 1
\ MOSI = OUT pin 0
\ MISO = IN pin 0

clean-pio  decimal          \ Empty code space mirror
\ With Side-set for SCK & CSN
0 0 {pio                    \ Use state machine-0 on PIO-0
    1000000 =freq           \ SM-clock = 1 MHz
    8 0 =autopull           \ 8-bits data records, no auto-pull
    0 =out-dir              \ OSR shifts to left
    26 2 =side-pins  opt    \ GPIO 26 for SCK, 27 for CSN (SIDE)
    28 1 =out-pins          \ GPIO 28 for OUT
    29 =in-pin              \ GPIO 29 for IN
    1 29 1 =inputs          \ Pull-up on input
    26 4 =set-pins          \ Three pins used

    7 pindirs set,                  \ Pin 26 to 28 are outputs
    wrap-target
        2 []  2 side  pull,         \ CEN high, pop Byte No. in SPI record
        0 side  osr x mov,          \ Save in X
        begin,
            pull,                   \ Get next byte
            begin,
                1 []  0 side  1 pins out, \ Output one bit, clock low
            1 []  1 side  osre? until,
        0 side  x--? until,
    wrap

    0 =exec                         \ Start at address 0
pio}

: >SPI      ( x -- )    \ Store data 'x' when there is space in the fifo
    begin  0 tx-depth  3 < until  0 >txf ;

: SPI-TYPE  ( a u -- )              \ Send string of 'u' bytes as one block from addr. 'a'
    dup 1- >spi  bounds ?do
        i c@  24 lshift  >spi       \ Send one byte using SPI
    loop ;

: >ROW      ( b0..bn +n -- )        \ Send +n bytes from stack to SPI
    dup 1- >spi
    0 ?do  24 lshift  >spi  loop ; \ Move data to highest byte & send


\ Show SPI block output
: DEMO1     ( -- )          cr  8 0 do  i .  i  loop  8 >row ;
: DEMO2     ( -- )          s" Forth " 2dup type  spi-type ;

\ End
