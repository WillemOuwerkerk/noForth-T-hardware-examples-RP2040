(* Basic nRF24 bidirectional test routines

Transmit T & receive a count as answer

\ Extra words: MS
\ *BIS    ( mask addr -- )    Set the bits represented by mask at address
\ *BIC    ( mask addr -- )    Clear the bits represented by mask at address
\ B+B     ( bl bh -- 16-bit ) Combine two bytes to a 16-bit word

*)

v: inside also
value WAIT      \ Hold on/off period time
: KICK-NRF24    ( -- )
    5 to #me  55 to #ch  1 to rf
    spi-setup  5 ms  setup24L01
    7 >len  9 set-dest  7 nrf@ .  troff ;

: TRANSMIT1     ( delay -- )
    kick-nrf24  to wait
    23 portb-odr *bis               \ Outputs off
    ." Transmitter " #me . space
    begin
        cr  ch T xemit  #me 1 .r    \ Transmit T, show myself
        response  ack? if           \ Wait for an answer
            xkey emit               \ Get it & show
            space 5 pay> 6 pay> b+b u. \ Fetch counter, show & wait
            wait ms
        then
    key? until ;

: TEST1     50 transmit1 ;

' test1  to app  v: fresh
shield TRANSMIT\
freeze
