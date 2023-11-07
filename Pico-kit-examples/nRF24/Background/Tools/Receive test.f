(* Basic nRF24 bidirectional test routines (noForth R versie)

Recieve T, increase counter & transmit : and counter back

\ Extra words: MS
\ *BIS    ( mask addr -- )    Set the bits represented by mask at address
\ *BIC    ( mask addr -- )    Clear the bits represented by mask at address
\ *BIX    ( mask addr -- )    XOR the bits represented by mask with the bits at address
\ B-B     ( 16-bit -- bl bh ) Split 16-bit to a low byte & high byte

*)

v: inside also
: KICK-NRF24    ( -- )
    5 to #me  55 to #ch  1 to rf
    spi-setup  5 ms  setup24L01
    7 >len  9 set-dest  7 nrf@ .  troff ;

\ Trace info: <cr> #me - T=" - counter
\         or: <cr> #me - "xXfault "
: RECEIVER   ( -- )
    kick-nrf24  ." Receiver " #me .
    23 portb-odr *bic  100 ms       \ PBODR   Outputs on 
    100 ms  23 portb-odr *bis   00  \ PBODR   and off, init. counter
    read-mode
    begin
        response  ack? if           \         Action on nRF24? 
          cr  #me 1 .r              \         Yes, show node number
          xkey dup [char] T = if    \         Char 'T' received?
            emit  ." = "            \         Yes, show
            3 portb-odr *bix        \ P2OUT   Toggle power mosfet output
            dup b-b 6 >pay  5 >pay  \         Counter as payload
            [char] : xemit          \         Send ':'  & counter back
            dup u.  1+              \         Show & increase counter
          else
            drop  ." RXfault "
          then
        then
        led-off
    key? until                      \         Key pressed?
    drop  3 portb-odr *bis ;        \         Yes, remove counter, output off

' receiver  to app  v: fresh
shield RECEIVER\  freeze
