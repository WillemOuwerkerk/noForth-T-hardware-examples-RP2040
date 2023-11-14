\ Bit toggle on GPIO 25 & 26 using Side-set & SET both using OPT:
\ This program initialises the IO-pins, then goes into a wait loop
\ Also an example of program control executing opcodes directly!

clean-pio  decimal          \ Empty code space mirror
\ Slow pulse on the LED mounted on GPIO 25 and a pulse on GPIO 26
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    26 1 =side-pins  opt    \ GPIO 25 for SIDE
    25 2 =set-pins          \ GPIO 25 & 26 for SET
\ Program
    3 pindirs set,                  \ Both pins are outputs
    3 pins set,                     \ Start with the LED & pin on
    begin, again,                   \ Wait loop
    begin,
        1 side  7 [] 1 pins set,    \ LED on (pin 25 & 26 on)
        7 [] 31 y set,              \ Max. delay using Y
        begin,
            7 [] 0 pins set,        \ LED (pin 25 & 26 off)
        7 [] y--? until,            \ Wait longer
    again,

    0 =exec                 \ Start SM-0 program at address 0
pio}

hex
: FLASH    3 0 exec ;               \ Jump to address 3, start flasher
: LED-OFF  2 0 exec  F000 0 exec ;  \ Pin 25 & 26 off, jump to wait loop
: LED-ON   2 0 exec  F801 0 exec ;  \ Pin 25 & 26 on, jump to wait loop

\ End
