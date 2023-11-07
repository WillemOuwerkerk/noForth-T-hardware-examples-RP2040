\ Code to test for busy channels and nRF24 range checks
\
\   CHECK   = Test all avialable 2.4GHz channels
\   CARRIER = Test only given channel
\   WAVE    = Send carrier on channel with a given power
\   PULSE   = Idem but also a 50/100 pulse length in millisec.
\
\ Extra words: MS

                            ( nRF24L01 RF test )

v: inside also
: ?LED      ( f -- )    if  led-on  else  led-off  then ;

: CARRIER?      ( -- 0|1 )  \ Check for carrier
    flush-rx  read-mode     \ Free receiver, receive mode on
    9 nrf@  write-mode ;    \ Test for carrier on used frequency

\ The program puts the led on & prints a number sign '#'
\ when a carrier is detected and a dash '-' otherwise.
: CHECK)        ( -- )  \ Check for carrier on selected channel
    [char] -  carrier?  \ Test for carrier on used frequency
    dup ?led            \ Led on when a carrier is seen
    if  A -  then  emit \ Show dash or sharp
    write-mode ;        \ Back to write mode

v: extra definitions
\ Test if other 2.4GHz transmitters are active on selected frequency
\ Busy channels at my place: 0D, 30 to 4C at night there are more
: CHECK         ( -- )
    spi-setup  setup24L01  7 nrf@ . \ Init.
    7E 0 do
        i >channel          \ Select channel number 0 to 7D
        cr  i 2 .r space    \ Show tested channel
        40 0 do             \ Test #64 times
            key? if leave then
            check)
        loop
        key? if leave then  \ Ready when a key is pressed
    loop  setup24l01  read-mode ; \ Restore chosen channel


\ Show carriers on the channel number from the stack
: CARRIER   ( channel -- )  \ #CH = default channel
    spi-setup  setup24L01  7 nrf@ . \ Initialise
    >channel                \ Set channel to be checked
    begin check) key? until \ Check carrier on 'channel'
                            \ Show presence
    setup24l01  read-mode ; \ Restore chosen channel

: WAVE      ( channel power -- ) \ #CH = default channel
    2E and >r               \ Keep power & bitrate settings in range
    spi-setup  ." on "      \ Init SPI
    2 0 nrf!  15 /ms   \ Power up for constant carrier
    r> 90 or  6 nrf!   \ Activate carrier, bitrate & power
    >channel  ce-high       \ Set channel
    begin  key? until       \ Wait for key
    setup24l01  read-mode ; \ Then stop carrier

0 value PL                  \ Pulselength for on/off rhythm
: PULSE     ( channel power pulselength -- ) \ #CH = default channel
    to pl  2E and >r        \ Keep power & bitrate settings in range
    begin
        spi-setup           \ Init. nRF24 SPI
        2 0 nrf!  15 /ms   \ Power up for constant carrier
        r@ 90 or  6 nrf!   \ Activate carrier, bitrate & power
        dup >channel  ce-high   \ Set channel
        pl ms               \ Carrier for PL ms
        setup24l01  pl ms   \ Then stop carrier for PL ms
    key? until              \ Wait for key
    r> 2drop  read-mode ;

v: fresh
shield CHECK\  freeze

\ End ;;;
