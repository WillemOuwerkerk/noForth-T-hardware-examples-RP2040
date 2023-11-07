(* Changing the configuration of noForth T (duo) (Current use~29.5mA)

    0 CFG  = Clock frequency in Hz
    1 CFG  = Used UART ( 0 or 1 ) only 0 is valid for now
    2 CFG  = Baudrate in bits per second
    3 CFG  = Used GPIO pin for S?
    4 CFG  = Boot method

    GROW   = Resize noForth with the number of bytes from the stack

Valid data for these parameters are:
    Clock    = 12, 30, 60, 120, 125, 132, 200 & 250 MHz
    Uart     = 0  (will be upgraded when this version is stable)
    Baudrate = Any baudrate like 9600, 115200 until 921600 was tested ok
    S? pin   = GPIO 24, but any free GPIO pin will do
    Boot     = 1 = Single image noForth t
               2 = noForth t duo

    FREEZE   = Save bootup images
    FREEZE2  = Save spare images
    COLD     = (Re)load bootup images
    COLD2    = (Re)load spare images

*)

decimal

132     0 cfg !     \ Set frequency in MHz

0       1 cfg !     \ Use UART-0

460800  2 cfg !     \ Baudrate is 460k8

03      3 cfg !     \ Use GPIO-3 for S?

4 cfg @ 0< [if]     \ Is it noForth duo?

2       4 cfg !     \ Yes, also make sure to (re)start the second image

[then]

hex  config         \ Test new configuration

\ freeze        \ Save new configuration, boots at startup & when you type COLD
\ freeze2       \ Save as spare system, boots when you type COLD2

\ End
