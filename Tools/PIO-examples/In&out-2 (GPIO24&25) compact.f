\ In/Out program-2: Using MOV only, shortest functional program
\ The LED on pin 25 goes on when pin 24 goes low, and off when high

\ In/Out program-3: Third program using input & ouput
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ I/O using sm-0 & PIO-0
    2000 =freq              \ On 2000 Hz frequency
    24 =in-pin              \ GPIO 24 as input pin base
    24 2 =set-pins          \ GPIO 24 & 25 are used pins
    25 1 =out-pins          \ GPIO 25 as OUT pin base
    1 24 1 =inputs          \ Pull-up on input

    2 pindirs set,          \ Pin 24 is input, Pin 25 is output
    wrap-target
        31 []  pins inv pins mov, \ Copy Pin-24 inverted to Pin-25 & debounce 16 millisec.
    wrap

    0 =exec
pio}
