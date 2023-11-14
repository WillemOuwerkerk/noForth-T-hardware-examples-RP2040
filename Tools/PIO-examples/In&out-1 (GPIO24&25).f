\ In/Out program-1: WAIT and a long delay
\ After a key press on pin 24, the LED on pin 25 stays on one second

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Read pin & write pin on sm-0 & PIO-0
    2000 =freq          \ On 2000 Hz frequency
    24 =in-pin              \ GPIO 24 as input pin base
    24 2 =set-pins          \ GPIO 24 & 25 are used pins
    1 24 1 =inputs          \ Pull-up on input

    2 pindirs set,          \ Pin 24 input, pin 25 output
    2 pins set,             \ Pin 25 (LED) on
    begin,
\       low 24 gpio wait,   \ Wait for key on pin 24
        low 0 pin wait,     \ Wait for key on pin 24
        2 pins set,         \ Set pin 25 (LED) high
        31 y set,           \ Delay a while
        begin,
            31 []  nop,
        31 []  y--? until,
        0 pins set,         \ Set pin 25 (LED) off
    again,
    0 =exec
pio}

