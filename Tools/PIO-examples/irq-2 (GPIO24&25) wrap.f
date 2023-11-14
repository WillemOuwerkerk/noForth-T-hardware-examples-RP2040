\ Example-1 of: Two communicating programs using IRQ
\
\ rel IRQ on sm-1
\    IRQ: 0 off, 1 on,  2 on,  3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\    IRQ: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\
\ Normal IRQ: on sm-1
\    IRQ: 0 off, 1 on,  2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\    IRQ: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,
\ IRQ-ON: 0 off, 1 off, 2 off, 3 off, 4 off, 5 off, 6 off, 7 off,

clean-pio  decimal          \ Empty code space mirror
\ IRQ clear using an input
0 0 {pio                    \ Use state machine-0 on PIO-0
    2000 =freq              \ On 2000 Hz frequency
    24 =jmp-pin             \ GPIO 24 as input pin base
    24 1 =set-pins
    1 24 1 =inputs          \ Pull-up on input

    0 pindirs set,                  \ Pin 24 is input
    wrap-target
        begin,  31 []  pin? until,  \ Pin 24 low?
        1 clr irq,                  \ Clear interrupt
        31 []  high 24 gpio wait,   \ Wait until pin 24 high
    wrap
    over =exec              \ Start SM-0 code at address from stack
pio}

1 0 {pio    \ Toggle LED after an IRQ
    2000 =freq              \ On 2000 Hz frequency
    25 =in-pin              \ GPIO 25 as input pin base
    25 1 =out-pins
    25 1 =set-pins          \ GPIO 25 for SET
                            \ Program starts here
    1 pindirs set,          \ Pin 25 is output
    1 pins set,             \ Pin 25 LED off
    wrap-target
        1 wait irq,         \ Wait until IRQ 1 is low
        pins inv pins mov,  \ Invert pin 25, LED on/off
    wrap
    over =exec              \ Start SM-1 code at address from stack
pio}

\ End
