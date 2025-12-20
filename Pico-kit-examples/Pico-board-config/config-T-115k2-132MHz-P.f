(* Changing the configuration of noForth t (solo and duo) (Current use~29.5mA)

    0 CFG  = Used GPIO pin for S? & clock frequency in Hz
    1 CFG  = Used UART ( 40034000 or 40038000 )
    2 CFG  = Baudrate in bits per second
    3 CFG  = Used GPIO input address register
    4 CFG  = Boot method

Valid data for these parameters are:
    Clock    = 12, 30, 60, 120, 125, 132, 200 & 250 MHz
    Uart     = UART0 = 40034000, UART1 = 40038000
    Baudrate = Any baudrate like 9600, 115200 until 921600 was tested ok
    S? pin   = D0000004, but any address may be used
    Boot     = 0 = noForth t solo
               1/-1 = noForth t duo

    FREEZE   = Save bootup images
    FREEZE2  = Save spare images
    COLD     = (Re)load bootup images
    COLD2    = (Re)load spare images
    GROW     = Resize noForth t with the number of bytes from the stack

*)

decimal

03  132     0 cfg !     \ Set switch I/O-bit & frequency in MHz

hx 40034000 1 cfg !     \ Default UART or UART1 = 40038000

115200      2 cfg !     \ Baudrate is 115k2

hx D0000004 3 cfg !     \ GPIO input address register

4 cfg @ abs 4 cfg !     \ Make sure to (re)start the second image if any

hex  config             \ Test new configuration

\ freeze        \ Save new configuration, boots at startup & when you type COLD
\ freeze2       \ Save as spare system, boots when you type COLD2

\ End


