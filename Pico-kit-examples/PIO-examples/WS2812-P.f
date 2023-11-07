\ WS2812 driver

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    3333333 =freq           \ On 3.333.333 Hz frequency
    28 1 =side-pins         \ GPIO 28 for SIDE-SET & SET
    28 1 =set-pins  0 =out-dir \ OSR shift left
    1 pindirs set,
    begin,
        isr osr mov,        \ Copy LED color to OSR
        8 x out,            \ Shift left one byte
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

0 .sm
