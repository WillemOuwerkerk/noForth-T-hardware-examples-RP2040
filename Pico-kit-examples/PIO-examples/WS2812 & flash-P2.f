\ WS2812 driveron GPIO28, demo & LED control on GPIO 25 using state machine 0 to 2

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    3333333 =freq           \ On 3.333.333 Hz frequency
    28 1 =side-pins         \ GPIO 28 for SIDE-SET & SET
    28 1 =set-pins
    0 =out-dir              \ OSR shift left
    1 pindirs set,
    begin,
        isr osr mov,        \ Copy LED color to OSR
        4 x out,            \ Shift left one nibble
        osr x mov,
        x0<>? if,           \ OSR not empty?
            osr isr mov,    \ Save new color in ISR
        else,
            31 x set,       \ OSR empty, start color in ISR
            x isr mov,
        then,
        23 y set,           \ Output 24 bits to WS2812!
        begin,              \ With a specific pattern
\                              One   Zero
            1 x out,        \   0     0
            1 side  x0<>? if, \ 1     1
            1 side  else,   \   1
                nop,        \         0
            then,
        y--? until,         \   0     0

        15 [] 31 x set,     \ Long delay: x = 31
        x osr mov,          \ OSR = 31
        12 x out,           \ OSR = 31 x 4096 = 126976
        osr x mov,          \ Delay = 126796 x 16 = 2028736/3333 ~ .6 sec.
        begin,  15 []  x--? until,
    again,
    0 =exec                 \ Start SM-0 at address 0
pio}

1 0 {pio        \ WS2812 output on pin 23 on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    23 1 =side-pins         \ GPIO 23 for optional SIDE & SET
    23 1 =set-pins
    0 =exec                 \ Start SM-1 at address 0 too
pio}


\ Slow pulses on the LED mounted on GPIO 25
2 0 {pio        \ Use state machine-2 on pio-0
    2200 =freq              \ State machine 2 runs on 2200 Hz
    25 1 =set-pins          \ GPIO 25 for SET
                            \ The program starts behind WS2812 program
    1 pindirs set,          \ Pin is output
    1 pins set,             \ Start with the LED on
    begin, again,           \ Wait loop
    begin,
        15 [] 1 pins set,   \ LED on (pin 25)
        15 [] 31 y set,     \ Max. delay using Y
        begin,
            15 [] nop,      \ Extra delay
            15 [] 0 pins set, \ LED off (pin 25)
        15 [] y--? until,   \ Wait longer
    again,
    over =exec              \ Start SM-1 program at address from stack
pio}

hex
: FLASH    18 2 exec ;              \ Jump to address 24, start flasher
: LED-OFF  17 2 exec  E000 2 exec ; \ Pin 25 & 26 off, jump to wait loop (address 23)
: LED-ON   17 2 exec  F801 2 exec ; \ Pin 25 & 26 on, jump to wait loop (address 23)


0 .sm  1 .sm  2 .sm



0 1 sm-on  200 ms  1 1 sm-on
\ End
