(* PWM on Pico

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
dm 04                           constant GPIOA      \ PWM base pin 16, etc.
1FF                             constant PWM#       \ PWM wrap value
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
    dm 128 pwma         \ Set default PWM values, 50% & 25%
    dm 064 pwmb ;

pwm-on

: WAVE1 ( -- )   begin  100 for   i pwma  next  key? until ;

\ 3A 111010
\ 20 - 19 18 17 16 - 15 14 13 12 - 11 10 09 08 - 07 06 05 04 - 03 02 01 00
\  1    1  1  0  1
\  1D 00 00 00 00 19

\ --- Waveform memory --------------------------------------------------
create WAVE 100 cells allot     \ 256 16-bit samples

\ --- Fill waveform with simple sawtooth -----------------------------
: FILL-WAVE ( -- )
   100 0 do
      i 2* WAVE i cells + !    \ 16-bit sample
   loop ;

fill-wave

: DMA-MOVE      ( src dst len -- )
    50000008 !          \ DMA0_COUNT
    50000004 !          \ DMA0_WRITE_ADDR
    50000000 !          \ DMA0_READ_ADDR
    001D0019 5000000C ! \ DMA0_CTRL  this triggers it all
\   begin
\       5000000C @ 100,0000 and 0=  \ DMA0_CTRL  wait until finished
\   until ;
    ;

\ wave pwm-pulse 100 dma-move

\ End
