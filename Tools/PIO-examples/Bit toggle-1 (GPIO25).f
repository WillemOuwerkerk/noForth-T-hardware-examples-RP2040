\ Bit toggle using set. The flash loop is done using wrap!

clean-pio  decimal          \ Empty code space mirror
\ Slow pulse on the LED mounted on GPIO 25 & 26 with wrapping
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    25 2 =set-pins          \ GPIO 25 & 26 for SET
    3 pindirs set,              \ Both pins are outputs
    wrap-target
        7 [] 3 pins set,        \ LED on, pin 25 & 26 on
        7 [] 31 y set,          \ Max. delay using Y
        begin,
            7 [] 0 pins set,    \ LED & pin off
        7 [] y--? until,        \ Wait longer
    wrap
    0 =exec                 \ Start code at address 0
pio}

