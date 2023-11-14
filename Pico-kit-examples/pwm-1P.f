(* Pico-kit PWM on GPIO26 & 27 for noForth t

This code uses two consecutive pins as pulse width outputs
it's the way the PWM hardware works! So 16,17 or 18,19, etc.

    0x40014000 = IO_BANK0_BASE
    0x40050000 = PWM_BASE

PWM is chapter 4.5 from page 524 ff

One PWM register block takes up 5 cells, there are 8 identical PWM blocks.
00 = CSR, 04=DIV, 08=CTR, 0C=CC, 10=TOP, etc.

00 = CSR = Settings for PWM output
04 = DIV = Extra divider, divides sysclock, default = 1
08 = CTR = PWM counter
0C = CC  = Compare values, two 16-bit values!
10 = TOP = Counter wrap value ( only low 16-bit are valid! )

The formula, PH = Phase correct bit, noted as 0 or 1
PWM frequency = ((sysclock/div)/pwm-top+1)/PH+1

*)

hex     \ PWM base pin 0, 2, 4, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28
dm 26                           constant GPIOA      \ PWM base pin 26, etc.
dm 999                          constant PWM#       \ PWM wrap value
gpioa 0F and 2/  14 *  40050000 + constant PWM-CSR  \ PWM control register
pwm-csr 0C +                    constant PWM-PULSE  \ PWM pulsewidth register
pwm-csr 10 +                    constant PWM-TOP    \ PWM wrap register

: PWMA      ( +n -- )   \ Set PWM of first output
    pwm# umin  FFFF0000 pwm-pulse bit**  or  pwm-pulse ! ;

: PWMB      ( +n -- )   \ Set PWM of second output
    pwm# umin  10 lshift  FFFF pwm-pulse bit**  or  pwm-pulse ! ;

: PWM-ON    ( -- )      \ Activate on of the eight PWM units
    4 gpioa gpio!       \ GPIO-A & B = PWM
    4 gpioa 1+ gpio!
    03 pwm-csr !        \ Enable phase correct PWM, both not inverted
    pwm# pwm-top !      \ PWM range (125000000/999+1)/2 = 62.5kHz
    dm 025 pwma         \ Set default PWM values, 2.5% & 5%
    dm 050 pwmb ;

pwm-on

: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us      \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=             \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;           \ QSPI pin-SS peripheral function again

: DEMO      ( -- )      \ Show PWM cycle until a key is hit
    pwm-on
    begin
        cr  dm 250 for
            i pwma  8 ms  r@ .
            bootkey? if  rdrop 0 >r  then
        next
        100 ms
    bootkey? until
    0 pwma ;

' demo  to app
shield PWM\

\ End
