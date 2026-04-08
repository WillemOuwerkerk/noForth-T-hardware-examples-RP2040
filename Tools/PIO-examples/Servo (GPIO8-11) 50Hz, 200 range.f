\ 50 Hz PWM, range 0 to 200 on GPIO8 to 11 using optional side-set, in 11 opcodes
\ This program stores the pulse reference value in ISR
\ The pulsewidth is ~500µs to 2500µs alrigth for most small RC-servo's

\ need pio\     ( Load the pio assembler & disassembler first )

decimal 

\ The range is 0 to 200, 0 outputs a .5ms pulse, 200 gives a 2.5ms pulse
: PULSE ( +n s -- )   3 and >r  200 umin  50 +  r> >txf ;

200 0 pulse ( Is 1.5ms output pulse, this is the center pulse for most servos )
150 1 pulse ( Is 1.25ms output pulse )
100 2 pulse ( Is 1.00ms output pulse )
050 3 pulse ( Is 0.75ms output pulse )

clean-pio  decimal          \ Empty code space mirror
0 0 {pio        \ Servo output on GPIO8 on sm-0 & pio-0
    300000 =freq            \ State machine 0 runs on 300kHz
    08 1 =side-pins  opt    \ GPIO9 for side-set
    08 1 =set-pins          \ GPIO9 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    1 pindirs set,          \ Pin is output
    15 y set,               \ Build servo cycle using Y
    y isr mov,              \ Y register to ISR
    7 null in,              \ ISR = 15 * 128 = 1920µs
    WRAP-TARGET
    0 side  noblock  pull,  \ Output low, pulse X to OSR when empty
    osr x mov,              \ Copy OSR to X
    isr y mov,              \ Copy ISR to Y
    begin,
        x=y? if,            \ (1) Output high when X = Y
        1 side  else,       \ (1)
            nop,            \ (1) Balance execution time of loop
        then,
    y--? until,             \ (1) Count one servo cycle
    WRAP
    0 =exec                 \ Start SM-0 program at address 0
pio}

1 0 {pio        \ Servo output on GPIO9 on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    9 1 =side-pins  opt     \ GPIO9 for optional SIDE
    9 1 =set-pins
    0 =exec                 \ Start SM-1 at address 0
pio}

2 0 {pio        \ Servo output on GPIO10 on sm-2 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-2
    10 1 =side-pins  opt    \ GPIO10 for optional SIDE
    10 1 =set-pins
    0 =exec                 \ Start SM-2 at address 0
pio}

3 0 {pio        \ Servo output on GPIO11 on sm-3 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-3
    11 1 =side-pins  opt    \ GPIO11 for optional SIDE
    11 1 =set-pins
    0 =exec                 \ Start SM-3 at address 0
pio}

\ End ;;;
