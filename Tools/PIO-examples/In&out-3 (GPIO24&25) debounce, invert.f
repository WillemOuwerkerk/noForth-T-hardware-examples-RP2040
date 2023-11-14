\ In/Out program-3: Using WAIT for low MOV and WAIT for high
\ The LED on pin 25 goes on/off after a key press on pin 24 with debouncing

\ In/Out program-3: Third program using input & ouput
clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ I/O using sm-0 & PIO-0
    2000 =freq              \ On 2000 Hz frequency
    25 =in-pin              \ GPIO 24 as input pin base
    25 1 =out-pins          \ GPIO 25 as OUT pin base
    24 2 =set-pins          \ Administer both used pins for SET
    1 24 1 =inputs          \ Pull-up on input

    2 pindirs set,          \ Pin 24 is input, Pin 25 is output
    wrap-target
        31 []  low 24 gpio wait,  \ Wait for key on pin 24 pressed
        31 []  pins inv pins mov, \ Copy Pin-25 inverted to Pin-25 & debounce 16 millisec.
        31 []  high 24 gpio wait, \ wait for key on pin 24 released
    wrap

    0 =exec
pio}
