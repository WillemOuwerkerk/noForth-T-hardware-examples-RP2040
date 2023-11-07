\ Frequency generation with TIMBRE on GPIO 26 to 29 using
\ optional side-set. The TIMBRE reference value is stored in ISR
\ Frequency: 8Hz to 20kHz, timbre range: 0 to 100

decimal
: HZ        ( hz sm -- )        >r  dm 300 *  r> freq ;

clean-pio                   \ Empty code space mirror
0 0 {pio                    \ Use state machine-0 on PIO-0
    200 0 hz                \ State machine 0 starts on 60kHz
    26 1 =side-pins  opt    \ GPIO 26 for side-set
    26 1 =set-pins          \ GPIO 26 for SET
    0 =in-dir               \ Shift ISR to left!
\ Program
    1 pindirs set,              \ Pin is output
    25 y set,                   \ Set TIMBRE range first Y
    y isr mov,                  \ Y register to ISR
    2 null in,                  \ ISR = 25 * 4 = 100
    begin,
        0 side  noblock  pull,  \ New timbre width (X to OSR when empty)
        osr x mov,              \ Copy OSR to X
        isr y mov,              \ Restore Y
        begin,
            x=y? if,            \ Output high when X = Y
            1 side  else,
                nop,
            then,
        y--? until,             \ Count one TIMBRE cycle
    again,
    0 =exec                 \ Start SM-0 program at address 0
pio}

1 0 {pio        \ Freq. output on pin 27, on sm-1 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-1
    300 1 hz                \ State machine 0 starts on 90kHz
    27 1 =side-pins  opt    \ GPIO 27 for side-set
    27 1 =set-pins          \ GPIO 27 for SET
    0 =in-dir               \ Shift ISR to left!
    0 =exec                 \ Start SM-1 at address 0 too
pio}
2 0 {pio        \ Freq. output on pin 28, on sm-2 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-2
    400 2 hz                \ State machine 0 starts on 120kHz
    28 1 =side-pins  opt    \ GPIO 28 for side-set
    28 1 =set-pins          \ GPIO 28 for SET
    0 =in-dir               \ Shift ISR to left!
    0 =exec                 \ Start SM-2 at address 0 too
pio}
3 0 {pio        \ Freq. output on pin 29, on sm-3 & pio-0
    0 clone                 \ Copy sm-registers from sm-0 to sm-3
    500 3 hz                \ State machine 0 starts on 150kHz
    29 1 =side-pins  opt    \ GPIO 29 for side-set
    29 1 =set-pins          \ GPIO 29 for SET
    0 =in-dir               \ Shift ISR to left!
    0 =exec                 \ Start SM-3 at address 0 too
pio}

\ The TIMBRE range is 0 to 100, 0 is output off, 50 is a square wave.
: TIMBRE    ( +n sm -- )        >r  100 umin  dup 0= +  r> >txf ;

: SWEEP     ( hz step -- )  \ Generate a range of increasing frequencies
    1 0 sm-on  swap         \ Max frequency on top
    20 ?do  i 0 hz  dup ms  50 +loop
    drop  500 ms  0 0 sm-on ;

: SWOOP     ( hz1 step -- )
    1 0 sm-on  1 1 sm-on  swap
    20 ?do  i 0 hz  i 2* 1 hz  dup ms  50 +loop
    drop  500 ms  0 0 sm-on  0 1 sm-on ;

\ End 
