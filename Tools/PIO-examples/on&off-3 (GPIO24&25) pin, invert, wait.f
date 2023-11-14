\ Example of: PIN? IF, then toggles a LED using MOV, release check using WAIT,

clean-pio  decimal          \ Empty code space mirror
\ LED on/off using in input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    24 =jmp-pin             \ Input pin for jump
    1 24 1 =inputs          \ Pull-up on input
    25 =in-pin
    25 1 =out-pins
    25 1 =set-pins          \ GPIO 25 for SET

    1 pindirs set,              \ Pin 25 is output
    1 pins set,                 \ Pin 25 LED on
    begin,
        31 []  pin? if,         \ Pin 24 low?
            pins inv pins mov,  \ Invert pin 25, LED on/off
            31 [] high 24 gpio wait, \ Pin released again? With debouncing
        then,
    again,

    0 =exec                 \ Start SM-0 code at address 0
pio}

\ End
