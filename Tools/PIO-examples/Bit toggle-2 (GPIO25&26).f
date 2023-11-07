\ Bit toggle using Side-set optional & SET. The flash loop is done using wrap!

clean-pio  decimal          \ Empty code space mirror
\ Slow pulse on the LED mounted on GPIO 25 & 26 with wrapping
0 0 {pio        \ Use state machine-0 & pio-0
    2000 =freq              \ On 2000 Hz frequency
    26 1 =side-pins  opt    \ GPIO 25 for SIDE
    25 2 =set-pins          \ GPIO 25 & 26 for SET
\ Program
    3 pindirs set,                  \ Both pins are outputs
    begin, again,                   \ Wait loop
    wrap-target
        1 side  7 [] 1 pins set,    \ LED on (pin 25 & 26 on)
        7 [] 31 y set,              \ Max. delay using Y
        begin,
            7 [] 0 pins set,        \ LED (pin 25 & 26 off)
        7 [] y--? until,            \ Wait longer
    wrap
    0 =exec                 \ Start SM-0 code at address 0
pio}

hex
: FLASH    2 0 exec ;      \ Jump to address 2, start flasher
: LED-OFF  1 0 exec  E000 0 exec ; \ Pin 25 off, jump to wait loop
: LED-ON   1 0 exec  E001 0 exec ; \ Pin 25 on, jump to wait loop
