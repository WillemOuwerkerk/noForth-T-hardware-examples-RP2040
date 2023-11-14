\ Rotary encoder on state machine 0 and PIO 0

clean-pio  decimal          \ Empty code space mirror
0 0 {pio                    \ Encoder readout on sm-0 & PIO-0
    2000 =freq              \ 2 kHz clock
    26 =in-pin              \ GPIO 26 as input pin base
    1 26 3 =inputs          \ Pull-up on all inputs
    26 3 =set-pins          \ Three pins used
    0 =out-dir

    0 pindirs set,          \ Only 26 to 28 are  input
    wrap-target
        7 y set,            \ Set no input value
        begin,
            pins osr mov,   \ Read inputs to OSR            .5
            29 null out,    \ Shift result to high 3 bits   .5
            3 x out,        \ Move to low 3 bits of X       .5
        x=y? while,         \ No change?                    .5
        repeat,             \ Read again                    .5
        x isr mov,          \ Change noticed, X to ISR
        push,               \ Output data to RX-fifo
    wrap
    0 =exec
pio}

: ENCODER?  ( -- f )        0 rx-depth  0= 0= ; \ True when encoder is used

\ 0 = Not turned, 1 = forward, -1 = backward, Press = true (Knob pressed)
: ENCODER   ( -- 1|-1 press )
    begin  encoder? until   \ Knob moved
    0 rxf>                  \ Read data, save knob pressed flag
    dup 4 and 0= >r         \ Save press switch
    3 and  dup 3 <> if      \ Knob turned?
        2 <>  -2 and 1+  r> exit \ 1 or -1  and press
    then
    dup -  r> ;             \ 0 and press

: DEMO      ( -- )          \ Show pulses up, down & knob pressed
    0  begin                \ Start at zero
        encoder if ." Press " then  + \ Show knob pressed
        dup .               \ Show counted pulses
    key? until ;

: TEST      ( -- )          \ Show generated pin codes
    begin
        begin  encoder? until
        0 rxf> .hex
    key? until ;

\ End
