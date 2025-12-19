(* Changing the configuration of noForth T (Current use~8.3mA)

    0 CFG  = Switch S? and clock frequency in Hz
    1 CFG  = Used UART address
    2 CFG  = Baudrate in bits per second
    3 CFG  = GPIO input address register
    4 CFG  = Boot method

    GROW   = Resize noForth with the number of bytes from the stack

Valid data for these parameters are:
    Clock       = 12, 30, 48, 60, 120, 125, 132, 200 & 250 MHz
    Uart        = Used UART address
    Baudrate    = Any baudrate like 9600, 115200 until 921600 was tested ok
    S? pin      = GPIO 24, but any free GPIO pin will do
    S? address  = GPIO input address register
    Boot        = 0 = noForth t solo
                  1/-1 = noForth t duo

    FREEZE   = Save bootup images
    FREEZE2  = Save spare images
    COLD     = (Re)load bootup images
    COLD2    = (Re)load spare images

*)

decimal

24  12 h+h  0 cfg ! \ Set switch I/O-bit & frequency in MHz

hx 40034000 1 cfg ! \ Default UART or UART1 = 40038000

460800      2 cfg ! \ Baudrate is 460k8

hx D0000004 3 cfg ! \ GPIO input address register

4 cfg @ abs 4 cfg ! \ (Re)start the second image, if any


hex  config         \ Test new configuration

\ freeze        \ Save new configuration, boots at startup & when you type COLD
\ freeze2       \ Save as spare system, boots when you type COLD2

\ End
