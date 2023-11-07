\ 1000 Hz PWM, range 0 to 200 on GPIO 25 & 26 using optional side-set
\ This program stores the PWM reference value in ISR

clean-pio  decimal          \ Empty code space mirror
\ 1 kHz PWM, range 0 to 200
0 0 {pio                    \ Use state machine-0 on PIO-0
    600000 =freq            \ State machine 0 runs on 600kHz
    25 2 =side-pins  opt    \ GPIO 25 for side-set
    25 2 =set-pins          \ GPIO 25 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    3 pindirs set,              \ Both pins are outputs
    25 y set,                   \ Set PWM range first Y
    y isr mov,                  \ Y register to ISR
    3 null in,                  \ ISR = 25 * 8 = 200
    begin,
        0 side  noblock  pull,  \ New pulse width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            3 side  else,
                nop,
            then,
        y--? until,             \ Count one PWM cycle
    again,
    0 =exec                 \ Start program at address 0
pio}

\ The PWM range is 0 to 200, 0 is outputs off, 200 is maximal on.
\ Note that the value 0 is corrected to -1, that sets the PWM completely off 
: >PWM  ( n -- )    200 umin  dup 0= +  0 >txf ;

\ End
