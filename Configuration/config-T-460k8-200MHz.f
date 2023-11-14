(* Changing the configuration of noForth t ( 38.9mA )

    CFG      = Clock frequency in Hz
    CFG 04 + = Used UART ( 0 or 1 ) only 0 is valid for now
    CFG 08 + = Baudrate in bits per second
    CFG 0C + = Used GPIO pin for S?
    CFG 10 + = Boot method

    GROW     = Resize noForth t with the number of bytes from the stack

Valid data for these parameters are:
    Clock    = 12, 30, 60, 120, 125, 132, 200, 250 MHz
    Uart     = 0  (will be upgraded when this version is stable)
    Baudrate = Any baudrate like 9600, 115200 until 921600 was tested ok
    S? pin   = GPIO 24, but any free GPIO pin will do
    Boot     = 0 = Single image noForth t
               1/-1 = noForth t duo

    FREEZE   = Save bootup image
    FREEZE2  = Save spare image
    COLD     = (Re)load bootup image
    COLD2    = (Re)load spare image

*)

decimal  cfg

200     over !  cell+   \ Set maximal valid frequency in MHz

0       over !  cell+   \ Use UART-0

460800  over !  cell+   \ Baudrate is 460k8

24      over !  cell+   \ Use GPIO-24 for S?

4 cfg @ abs 4 cfg ! \ Make sure to (re)start the second image

drop  hex

  cfg config    \ Test new configuration

\ freeze        \ Save new configuration, boots at startup & when you type COLD
\ freeze2       \ Save as spare system, boots when you type COLD2

\ End
