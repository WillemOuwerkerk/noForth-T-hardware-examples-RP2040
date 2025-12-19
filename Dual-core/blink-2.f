\ Setting up a simple LED flasher on GPIO2 for CORE-1
\ Using only CPU registers and one I/O-pin
\ More info on SIO_BASE from address 42 ff.
routine BLINK      ( -- )
(data
    4000F000 ,          \ Reset IO-bank to HOP ( RESETS_BASE ) = HOP
    40014014 ,          \ Assign GPIO2 to DAY ( GPIO2_CTRL ) = DAY
    D0000000 ,          \ SIO base to SUN ( SIO_BASE ) = SUN
    01000000 ,          \ Delay value
data)
    w  { hop day sun } ldm,
    moon 20 # movs,         \ Release IO-bank
    moon  hop ) str,
    moon 5 # movs,          \ GPIO2 = SIO
    moon  day ) str,
    moon 1 # movs,          \ Set bit 2
    moon 2 # lsls,
    moon  sun 24 #) str,    \ Enable GPIO2 output ( GPIO_OE_SET )
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

\ ' flash to app
shield CORE1\  freeze

\ End
