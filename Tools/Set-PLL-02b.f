(* Generic PLL setter

Not all desired RP2040 frequencies are possible!
Note that the expected life of the RP2040 decreases with a higher freqeuncy.

After multiplier freq: between 750 MHz & 1600 MHz
Valid multiplier = 16 to 320
The PLL dividers are both between 1 & 7, 32000 = /3 & /2 = /6
Next step adjusting the internal core power supply

0x40064000 Core voltage at page 160 (used bits 0 & 4 to 7)

\   0 over 7 > 4 and +  1800,0014 ! \ Change Pico_Flash_SPI_Clkdiv

*)

need [defined]
need [if]

v: inside also  definitions
create PLL-CLK1  decimal
\     0        1       2       3       4       5       6       7       8       9       A       B
\     12      30      48      60      125     132     200     250     300     360     375     400
     006 c,  015 c,  024 c,  030 c,  062 c,  066 c,  100 c,  125 c,  150 c,  180 c,  187 c,  200 c,
\ Core voltage settings
hex  071 c,  071 c,  071 c,  071 c,  0A1 c,  0A1 c,  0B1 c,  0B1 c,  0C1 c,  0F1 c,  0F1 c,  0F1 c, align
\ Mutiplier & 2 stage divider
    3177 h, 4604 h, 4044 h, 4672 h, 7D62 h, 4261 h, 6461 h, 7D61 h, 4B31 h, 5A31 h, 7D41 h, 6431 h, align

\ This word is secure, uses always a valid frequency
: >PLL1     ( clk -- post mul ) \ Leave data for PLL settings
    dup 2/  0 begin                 \                                           clk clk/ n
        2dup pll-clk1 + c@ <>       \ Invalid clock?                            clk clk/ n f
    while
    1+ dup 0C = until               \ Leave here when MHZ is invalid!           clk clk/ n+1
        drop 2drop   7D dup  4      \ Set default = 125MHz                      clk clk n=4
    then  nip swap false cfg 2 + h! \ Save new clock, keep n                    n = 0 to 11
    4006,4000 >r  dup pll-clk1 0C + + c@ \ Get core voltage                     n cv
    r@ !  begin 1000 r@ bit** until \ Set it & wait until it's stable           n
    rdrop  2*  pll-clk1  dm 24 +  + \ Leave setup data                          a
    h@ b-b >r  0C lshift  r> ;      \ Make PLL-setup factors                    mult div

\ decimal                    \ Only five cells are needed
\    125        0 cfg !      \ Default system clock
\    0  24 b+b  1 cfg !      \ Default UART (0 or 1) & GPIO pin number for S?
\    115200     2 cfg !      \ Default baudrate
\    $D0000004  3 cfg !      \ GPIO input address register
\    0          4 cfg !      \ Load only noForth for core0 & start
\ hex
: NEW-FREQ  ( f -- )   \ Initialise system clock, etc.
    >pll1                   \ Set frequency, get PLL clock data
    restart-devices         \ All RP2040
    start-xosc
    3000 4000E000 !         \ Resets base register SET alias, reset PLL's
    3000 4000F000 !         \ Clear alias, clear PLL's
    begin
        4000C008 @ 3000 and \ Read resets base,
    3000 = until            \ PLL's ready?
    ( 62000 7D ) init-plls  \ Set PLL clocks
    init-clks               \ Set all system clocks
    100 54 clk-on           \ & USB clock
    100 60 clk-on           \ & ADC clock
    10000 6C clk-on         \ Finally RTC clock

    20C 4005802C !          \ Start WD ticks
    800 40008048 !          \ Peripheral clock
    false 4000C000 !        \ Unreset all

    301 40034030 **bic      \ Uart & transmit disable
    2 cfg @ baud  set-gpio  \ Default baudrate
    301 40034030 !          \ Enable UART
    2 0 gpio!  2 1 gpio!    \ Enable UART on GPIO0 & GPIO1
\ Reboot second core too
[defined] boot1 [if]
    0 cfg @ ramborder 108 + ! \ Note new frequency for second core too
    ramborder 4 + @ boot1   \ Restart from second cores reset vector
[then]
[defined] usb-on [if]
     usb-on
[then]
    ;

v: extra definitions
\ Gradually switch to a higher frequency, max = 400 MHz
: SET-FREQ  ( freq -- )
    dup dm 200 > if  dm 200 new-freq  FF us  then
    dup dm 300 > if  dm 360 new-freq  FF us  then
    new-freq  20 us ;

\ End
