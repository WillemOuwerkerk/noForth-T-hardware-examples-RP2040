\ Setting up a simple LED flasher for CORE-1
\ Using only CPU registers and one I/O-pin
\ More info on SIO_BASE from address 42 ff.
code BLINK      ( -- )
data>
    4000F000 ,          \ Reset IO-bank to HOP ( RESETS_BASE )
    400140CC ,          \ Assign GPIO25 to DAY ( GPIO25_CTRL )
    D0000000 ,          \ SIO base to SUN ( SIO_BASE )
    01000000 ,          \ Delay value
code>
    w  { hop day sun } ldm,
    moon 20 # movs,         \ Release IO-bank
    moon  hop ) str,
    moon 5 # movs,          \ GPIO25 = SIO
    moon  day ) str,
    moon 1 # movs,          \ Set bit 25
    moon 19 # lsls,
    moon  sun 24 #) str,    \ Enable GPIO25 output ( GPIO_OE_SET )
    begin,
        moon  sun 14 #) str,    \ LED on  ( GPIO_OUT_SET )
        day  w ) ldr,           \ Read delay
        begin,  day 1 # subs, =? until,
        moon  sun 18 #) str,    \ LED off ( GPIO_OUT_CLR )
        day  w ) ldr,           \ Read delay
        begin,  day 1 # subs, =? until,
    again,
end-code

: FLASH     ( -- )      ['] blink >body  boot1 ;

' flash to app
shield CORE1\  freeze

\ End
