\ This version-00, SPI0 runs on noForth RCV version 201030 & later.
\
\ Hardware or BitBang SPI on GD32VF103 using bits of port-A, port-B & port-C.
\ SPI0 i/o interfacing the nRF24L01 
\
\ Connect the SPI lines of USCIB PA5=CLOCKPULSE, PA6=DATA-IN, PA7=DATA-OUT
\ PC0=CSN, PC1=CE, PC2=IRQ of the nRF24L01. On the Egel kit it's just putting 
\ the module in the connector marked nRF24L01!!
\
\ Note that decoupling is very important right near the nRF24l01 module. The
\ Egel kit vsn-2 has an extra 22uF near the power connections. The Launchpad
\ and the Egel kit vsn-1 need an extra 10uF or more for decoupling!!
\
\ SPI0 master
\
\                     GD32VF103
\              ^  -----------------
\             /|\|              XIN|- Optional 32.768 kHz xtal
\              | |                 |
\              --|RST          XOUT|- Idem
\                |                 |
\          IRQ ->|PC2           PA7|-> Data Out (MOSI0)
\                |                 |
\           CE <-|PC1           PA6|<- Data In (MISO0)
\                |                 |
\          CSN <-|PC3           PA5|-> Serial Clock Out (CLK0)
\                |                 |
\          LED <-|PB5         PB0&1|-> Power out
\
\ Concept: Willem Ouwerkerk & Jan van Kleef, october 2014
\ Current version: Willem Ouwerkerk, 25 februari 2022
\
\ SEEED GD32VF103 board documentation for SPI0, etc.
\
\ PA & PC are used for interfacing the nRF24L01+
\ PC0  - CE flash mem.           \ SPI enable low      x1=Select
\ PC1  - CE nRF24                \ Device enable high  x1=Enable
\ PC2  - IRQ                     \ Active low output   x0=Interrupt
\ PC3  - CSN                     \ SPI enable low      x1=Select
\ PA5  - CLOCKPULSE              \ Clock               x1=Clock
\ PA6  - DATA-IN                 \ Data bitstream in   x0=Miso
\ PA7  - DATA-OUT                \ Data bitstream out  x1=Mosi
\ PB5  - Led red                 \ XEMIT led
\ PB0  - Power led               \ Power output
\ PC13 - Switch SW1              \ Default
\ Pxy  - Analog input            \ Optional
\
\ nRF basic timing:
\    Max. SPI clock:         8 MHz
\    Powerdown to standby:   1,5 ms
\    Standby to TX/RX:       0,13 ms
\    Transmit pulse CE high: 0,01 ms
\
\ Sensitivity: 2Mbps – -83dB, 1Mbps – 87dB, 250kbps – -96dB.
\ Receiving current: 2Mbps – 15mA, 1Mbps – 14.5mA, 250kbps – 14mA
\
\ On board PCB antenna, transmission distance reach 240M in open area, but
\ 2.4G frequency is not good to pass through walls, also interfere by
\ 2.4G wifi signal significantly.
\
\ Software parts to adjust for different clock speeds:
\ 1) SPI-ON       - SPI clock speed
\ 2) #IRQ         - Software timing loop to wait for ACK
\ 3) WRITE-DTX?   - Transmit pulse CE (10 µsec software timing)
\
\ Dynamic payload length
\
\ 1) SPI-commands 60  - Reads length of received payload, which is in the second byte
\                 A8  - Set length of payload on pipe 0 to 7 and 1 to 32 data bytes (LSB first)
\ 2) Registers    1C  - Activate the dynamic payload for one or more data pipes
\                 1D  - Dynamic payload configuration on/off
\
\ Dynamic payload format from 1 to 32 bytes:
\ |   0   |  1  |  2  |    3   |  4  |  5 to 31   |
\ |-------|-----|-----|--------|-----|------------|
\ |Command|Dest.|Orig.|Sub node|Admin|d00| to |d1A|
\
\ 0 pay>  = Command for destination      1 pay>       = Destination node
\ 2 pay>  = Origin node                  3 pay>       = Address of sub node
\ 4 pay>  = Administration byte          5 to 31 pay> = Data 0x1A (#26) bytes
\
\ Extra routines needed:
\
\ /MS     ( u -- )            Wait in steps of 100 µsec.
\ *BIS    ( mask addr -- )    Set the bits represented by mask at address
\ *BIC    ( mask addr -- )    Clear the bits represented by mask at address
\ BIT*    ( mask addr -- b )  Leave the bits b from mask that were high at address
\ B+B     ( bl bh -- 16-bit ) Combine two bytes to a 16-bit word
\ B-B     ( 16-bit -- bl bh ) Split 16-bit to a low byte & high byte
\
\ : /MS       ( u -- )    0 ?do  1E00 0 do loop  loop ;
\

hex inside also  definitions
: INC=      ( +n ref -- n+1 f ) \ Incr +n, true when +n = ref
    >r  1+  dup r> = ;

\ PB0 0x03 = Power out simulation, PB5 0x20 = signal LED
40010C00 constant PORTB-CRL \ Port-B ontrol Register for pins 0 to 7
40010C0C constant PORTB-ODR \ Port-B Output Data Register

\ Redefine {SPI SPI}
code {SPI        ( -- )
    sun 4001100C li     \ PORTC_ODR  Port-C output address
    w sun ) .mov        \ Read Port-C
    w -9 .andi          \ Clear bit-3
    sun ) w .mov        \ Write Port-C
    next
end-code

code SPI}        ( -- )
    sun 4001100C li     \ PORTC_ODR  Port-C output address
    day 8 .li           \ Bit-1 mask
    w sun ) .mov        \ Read Port-C
    w day .or           \ Set bit-3
    sun ) w .mov        \ Write Port-C
    next
end-code

\ NOTE: This value must be adjusted for different clock speeds & MPU's!!!
\ It is the timeout for receiving an ACK handshake after a transmit!!
  2000 constant #IRQ     \ Delay loops for XEMIT (104 MHz)
\ 1000 constant #IRQ     \ 72 MHz

value T?                \ Tracer on/off
: TEMIT     t? if  dup emit  then  drop ;  \ Show copy of char
extra definitions
: TRON      true to t? ;        : TROFF     false to t? ;
inside definitions
: LED-ON    20 portb-odr *bic ; : LED-OFF   20 portb-odr *bis ;
: POWER-ON  3 portb-odr *bic ;  : POWER-OFF  3 portb-odr *bis ;
: POWER-BIP 3 portb-odr *bix ;
: /MS       ( u -- )    ms#  [ ms# 0A / ] literal to ms#  swap ms  to ms# ;

value ACK?              \ Remember IRQ flag
\ Later on assembly code for speed up:
: IRQ?      ( -- flag )     4 40011008 bit* 0=  dup to ack? ;


: RESPONSE  ( -- )      \ Leave true when an IRQ was received
    #irq 0 do  irq? if  leave  then  loop ;

                    ( USCI-B0 SPI interface to nRF24L01+ )

code CE-LOW      ( -- )
    sun 4001100C li     \ PORTC_ODR  Port-C output address
    w sun ) .mov        \ Read Port-C
    w -3 .andi          \ Clear bit-1
    sun ) w .mov        \ Write Port-C
    next
end-code

code CE-HIGH     ( -- )
    sun 4001100C li     \ PORTC_ODR  Port-C output address
    day 2 .li           \ Bit-1 mask
    w sun ) .mov        \ Read Port-C
    w day .or           \ Set bit-1
    sun ) w .mov        \ Write Port-C
    next
end-code

: SPI-SETUP     ( -- )
    spi-on  23 portb-odr *bis   \ Activate SPI0 & leds
    44244422 portb-crl !        \ Port_B CRL  Set PB0, PB1 & PB5 as output (Reset $44444444)
    0000FFFF 40011000 **bic     \ Port_C CRL  Clear pin PC0 to PC2, CSN CE & IRQ
    00001811 40011000 **bis     \ Port_C CRL  Set pin PC0 to PC3
    5 4001100C **bis  ce-low ;  \ Port_C out  CSN high, IRQ pullup


                ( Read and write to and from nRF24L01+ )

value #CH             \ Used channel number
extra definitions
value #ME             \ Later contains node number
inside definitions
: {SPI-OUT      ( c -- )    {spi spi-out ;
: NRF@          ( c -- b )  {spi-out spi-in spi} ;
: NRF!          ( b r -- )  {spi-out spi-out spi} ;

\ Write the communication addresses, of pipe-0 default: E7E7E7E7E7
: WRITE-ADDR   ( trxa -- )
    {spi-out spi-out spi-out spi-out spi-out spi-out spi} ;

: SET-MY-ADDR   ( -- )      F0 F0 F0 F0 #me 2B write-addr ; \ Set ME own receive address


                ( nRF24L01+ control commands and setup )

\ Empty RX or TX data pipe
: FLUSH-RX      ( -- )      E2 {spi-out spi} ;  \ Remove received data
: FLUSH-TX      ( -- )      E1 {spi-out spi} ;  \ Remove transmitted data
: RESET         ( -- )      70 27 nrf! ;        \ Reset IRQ flags
: PIPES-ON      ( mask -- ) 3F and  22 nrf! ;   \ Set active pipes
: >CHANNEL      ( +n -- )   25 nrf! ;           \ Change RF-channel 7-bits

value RF              \ Contains nRF24 RF setup
chere to rf  \ Bitrate conversion table: 0=250 kbit, 1=1 Mbit, 2=2 Mbit, 3=250 kBit.
    20 c, 00 c, 08 c,  20 c, align  \ 250 kbit, 1 Mbit, 2 Mbit
: RF!   ( db bitrate -- )   b+b to rf ; \ Save RF-settings
: RF@   ( -- db bitrate )   rf b-b ;    \ Get RF-settings

\ db:  0 = -18db, 1 = -12db, 2 = -6db, 3 = 0db )
\ bitrate:  0 = 250 kbit, 1 = 1 Mbit, 2 = 2 Mbit
: >RF           ( db bitrate -- )   \ Change nRF24 RF settings
    3 and  [ rf ] literal           \ Address of conversion table
    + c@ >r  3 and 2*  r> or  26 nrf! ;

3 1 rf! \ Initialise RF settings


\ Dynamic payload additions
20 constant #LEN            \ Payload size max. 32 bytes
value LEN                   \ Contains current length of the payload
value MLEN                  \ Remember length of received payload
: >LEN      ( +n -- )       to len ; \ Set dynamic payload length
: NORM      ( -- )          3 >len ; \ Default payload length

\ Elementary command set for the nRF24L01+
: START24L01    ( -- )  \ Reinitialise nRF24
    #ch >channel        \ channel #CH to start with
    reset  led-off      \ Enable CRC, 2 bytes & reset flags
    flush-rx flush-tx ; \ Start empty

: SETUP24L01    ( -- )
    norm  3 3C nrf!     \ Allow dynamic payload on Pipe 0 & 1
    4 3D nrf!           \ Enable dynamic payload, ACK payload on!
    0C 20 nrf!          \ Enable CRC, 2 bytes
     3 21 nrf!          \ Auto Ack pipe 0 & 1
     2 pipes-on         \ Pipe 1 on
    set-my-addr         \ Set receive address
     3 23 nrf!          \ Five byte address
    1F 24 nrf!          \ Retry after 500 us & 15 retry's
    rf@ >rf  start24l01 \ 1 Mbps, max. power
    0E 20 nrf!  0F /ms ; \ Power up


\ Format: Command, Dest.node, Org.node, Sub.node, Aux, Data-0, Data-1, .. to Data-x
create 'READ    #len allot  \ Receive buffer
create 'WRITE   #len allot  \ Transmit buffer
: '>PAY     ( +n -- a )     'write + ;  \ Leave address of TX payload
: >PAY      ( b +n -- )     '>pay c! ;  \ Store byte for TX payload
: 'PAY>     ( +n -- a )     'read + ;   \ Leave address of RX payload
: PAY>      ( +n -- b )     'pay> c@ ;  \ Read byte from RX payload


                    ( Send and receive commands for nRF24L01+ )

: WRITE-MODE    ( -- )          \ Power up module as transmitter
    ce-low  0E 20 nrf!          \ Receive off, wakeup transmitter
    1 pipes-on  reset  2 /ms ;  \ Reset flags & pipe-0 active, wait 200 microsec.

: READ-MODE     ( -- )
    0F 20 nrf!  2 pipes-on      \ Power up module as receiver, activate pipe-1
    reset  ce-high  2 /ms ;     \ Enable receive mode, wait 200 microsec.

: BUSY          ( -- )      \ Wait while a channel is busy
    0  begin
        read-mode  2 /ms    \ Listen
    9 nrf@ while            \ Carrier found?
        ch . temit          \ Yes, show
    40 inc= until           \ Timeout!
    then  drop write-mode ; \ No, ready

: WRITE-DTX? ( c -- 0|20 )          \ Send #len bytes payload & leave 20 if an ACK was received
    0 >pay  A0 {spi-out  'write  0  \ Carrier check, store TX payload
    begin
        2dup + c@ spi-out
    len inc= until  spi}  2drop  busy
    ce-high  30 for next  ce-low    \ Transmit 10µs pulse on CE
    response  7 nrf@ 20 and ;       \ Wait for ACK

8 constant #RETRY       \ Re-transmit attempts for XEMIT
value #FAIL             \ Note XEMIT failures
: XEMIT     ( c -- )
    0 to #fail  begin
        led-on
        dup temit  dup WRITE-DTX? if \ Echo command, send payload
            drop  flush-tx  reset 
            led-off  read-mode  exit
        then
        incr #fail  start24l01      \ TX failed, reinit.
        #fail #me 1+ * /ms          \ Variable retry time
    #fail #retry = until            \ #RETRY * ARC = 15 * 8 = 120 retries in total
    drop  read-mode ;


: READ-DRX? ( -- f )                \ Receive 1 to 32 bytes
    60 nrf@  dup 20 >               \ Read & check payload size
    if  flush-rx  drop false exit  then \ Check if invalid!
    to mlen  61 {spi-out  'read  0
    begin
        2dup + spi-in swap c!
    mlen inc= until
    spi}  2drop  true ;

: XKEY          ( -- c )
    begin
        0  begin                    \ Do eight receive attempts
            7 nrf@ 40 and           \ Leave 40 when payload was received
        ack?  and 0= while          \ and IRQ noticed, not?
            start24l01  response    \ Then restart 24L01 & pickup retry
        #retry inc= until
        ce-low 0=  exit  then  drop \ Failed, leave zero & to standby II
    read-drx? until  0 pay>         \ Yes, read payload packet & leave command
    reset  flush-rx  ce-low ;       \ Empty pipeline & to standby II

\ Set destination address to node from stack, receive address is my "me"
: SET-DEST      ( node -- )
    dup >r  1 >pay  #me 2 >pay      \ Set Destination & origin nodes
    F0 F0 F0 F0 r@ 2A write-addr    \ Receive address P0
    F0 F0 F0 F0 r> 30 write-addr ;  \ Transmit address

fresh
shield 24L01\   freeze

\ End ;;;
