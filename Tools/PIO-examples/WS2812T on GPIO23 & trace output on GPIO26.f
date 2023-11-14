\ WS2812 driver on GPIO 23 & tracer output on GPIO 26

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    3333333 =freq           \ SM-0 on 3.333.333 Hz frequency
    23 4 =side-pins         \ GPIO 23 for SIDE-SET & SET
    23 4 =set-pins  0 =out-dir \ OSR shift left

    9 pindirs set,
    wrap-target
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
            9 side  x0<>? if, \ 1     1
            9 side  else,   \   1
                nop,        \         0
            then,
        y--? until,         \   0     0
        1 [] 31 x set,      \ Long delay: x = 31
        x osr mov,          \ OSR = 31
        15 x out,           \ OSR = 31 x 32768 = 1015808
        osr x mov,          \ Delay = 1015808 x 2 = 2031616/3333 ~ .6 sec.
        begin,  1 []  x--? until,
    wrap
    0 =exec                 \ Start SM-0 at address 0
pio}

