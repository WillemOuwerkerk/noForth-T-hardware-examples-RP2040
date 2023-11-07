\ This version-02g, SPI0 runs on noForth RCV version 201030 & later.
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
\
\ Dynamic payload format from 1 to 32 bytes:
\ |   0   |  1  |  2  |    3   |  4  |  5 to 31   |
\ |-------|-----|-----|--------|-----|------------|
\ |Command|Dest.|Orig.|Sub node|Admin|d00| to |d1A|
\
\ 0 buf>  = Command for destination      1 buf>       = Destination node
\ 2 buf>  = Origin node                  3 buf>       = Address of sub node
\ 4 buf>  = Administration byte          5 to 31 buf> = Data 0x1A (#26) bytes
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
\   Set the nRF24 receiver address to just the base address
\   Disable Enhanced Shockburst
\   Disable CRC checking
\   Configure a fixed payload size

hex  inside also definitions
\ PB0 0x03 = Power out simulation, PB5 0x20 = signal LED
40010C00 constant PORTB-CRL \ Port-B ontrol Register for pins 0 to 7
40010C0C constant PORTB-ODR \ Port-B Output Data Register

\ NOTE: This value must be adjusted for different clock speeds & MPU's!!!
\ It is the timeout for receiving an ACK handshake after a transmit!!
  1200 constant #IRQ     \ Delay loops for XEMIT (104 MHz)
\  900 constant #IRQ     \ 72 MHz

: LED-ON    20 portb-odr *bic ; : LED-OFF   20 portb-odr *bis ;
: POWER-ON  3 portb-odr *bic ;  : POWER-OFF  3 portb-odr *bis ;
: /MS       ( u -- )    ms# >r  r@ 0A / to ms#  ms  r> to ms# ;
: IRQ?      ( -- flag ) 4 40011008 bit* 0= ;

: RESPONSE? ( -- flag )     \ Leave true when an IRQ was received
    false  #irq for  irq? if  1-  rdrop exit  then  next ;


                    (  SPI0 interface to nRF24L01+ )

code {SPI        ( -- ) \ Redefine {SPI SPI}
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

code CE-LOW      ( -- ) \ Control CE of nRF24
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


                ( Read and write to and from nRF24L01 )

value #CH             \ Used channel number
value #ME             \ Later contains node number
\ The first written byte returns internal status always
\ It is saved in the value STATUS using SPI-COMMAND
: GET-STATUS    ( -- s )    {spi  FF spi-i/o  spi} ;
: SPI-COMMAND   ( c -- )    {spi  spi-out ;
\ Reading and writing to registers in the 24L01
: WMASK       ( b1 -- b2 )  1F and  20 or ;
: READ-REG      ( r -- b )  1F and  spi-command  0 spi-i/o  spi} ;
: WRITE-REG     ( b r -- )  wmask spi-command  spi-out  spi} ;
\ Write the communication addresses, of pipe-0 default: E7E7E7E7E7
: WRITE-ADDR  ( trxa -- )   wmask spi-command  3 0 do spi-out loop  spi} ;
: SET-MY-ADDR   ( -- )      F0 F0 F0  0A write-addr ; \ Set ME own receive address


                ( nRF24L01+ control commands and setup )

\ Empty RX or TX data pipe
: FLUSH-RX      ( -- )      E2 spi-command  spi} ; \ Remove received data
: FLUSH-TX      ( -- )      E1 spi-command  spi} ; \ Remove transmitted data
: RESET         ( -- )      70 7 write-reg ;       \ Reset IRQ flags
: PIPES-ON      ( mask -- ) 3F and  2 write-reg ;  \ Set active pipes
: WAKEUP        ( -- )      03 0 write-reg ;       \ CRC off, Powerup
: >CHANNEL      ( +n -- )   5 write-reg ;          \ Change RF-channel 7-bits

value RF              \ Contains nRF24 RF setup
\ Bitrate conversion table: 0=250 kbit, 1=1 Mbit, 2=2 Mbit, 3=250 kBit.
    20 c, 00 c, 08 c,  20 c, align  \ 250 kbit, 1 Mbit, 2 Mbit
: RF!   ( db bitrate -- )   b+b to rf ; \ Save RF-settings
: RF@   ( -- db bitrate )   rf b-b ;    \ Get RF-settings

\ db:  0 = -18db, 1 = -12db, 2 = -6db, 3 = 0db )
\ bitrate:  0 = 250 kbit, 1 = 1 Mbit, 2 = 2 Mbit
: >RF           ( db bitrate -- )       \ Change nRF24 RF settings
    3 and  [ ' rf >body cell+ ] literal \ Address of conversion table
    + c@ >r  3 and 2*  r> or  6 write-reg ;

3 1 rf! \ Initialise RF settings


\ Saved payload length, from here on a lot a small adjustments are done to the code
18 constant #LEN        \ Payload size max. 32 bytes, here 24

\ Elementary command set for the nRF24L01+
: SETUP24L01    ( -- )
    0 0 write-reg       \ Disable CRC
    0 1 write-reg       \ Auto Ack on all pipes off
    1 pipes-on          \ Pipe 0 on
    #len 11 write-reg   \ #pay bytes payload in P0
    1 3 write-reg       \ Three byte address
    set-my-addr         \ Set receive address
    1F 4 write-reg      \ Retry after 500 us & 15 retry's
    #ch >channel        \ channel #CH to start with
    rf@ >rf             \ 1 Mbps, max. power
    reset               \ reset flags
    flush-rx  flush-tx  \ Start empty
    wakeup  0F /ms      \ Enable CRC, 2 bytes & Power up
    led-off ;


\ Format: Addr-4, Addr-5, PCR, Command, Dest, Org, Sub, Aux, D0, D1, .. to Dx, CHK-1, CHK-2
value PTR  value #PAY  value CNT  value #CRC
create LOG    6000 allot  align     \ xx payloads buffer
create BUFFER #len allot  align     \ Improvement buffer
: BUF>      ( +n -- b )     buffer + c@ ;  \ Read byte from RX payload

: XRECEIVE  ( -- )                  \ Receive 1 to #len bytes
    61 spi-command  ptr             \ Start receiving to address PTR
    spi-in over c!  1+              \ nRF address 4
    spi-in over c!  1+              \ nRF address 5      
    spi-in >r  r@ over c!  1+       \ nRF PCF
    r> 2/ 2/ to #pay                \ Filter payload length
    #pay 3 + bounds                 \ & correct
    ?do  spi-in i c!  loop  spi}    \ Read rest of payload
    reset  flush-rx  incr cnt ;     \ Reset receiver


                    ( Receive commands for nRF24L01 )

: READ-MODE     ( -- )
    3 0 write-reg  1 pipes-on   \ Power up module as receiver, activate pipe-0
    reset  ce-high  2 /ms ;     \ PCODR  Enable receive mode, wait 200 microsec.

: .BITRATE  ( +n -- )   ?dup 0= if ." 250 kBit " exit then . ." Mbit, " ;

extra definitions
: .STATUS   ( -- )
    base @ >r  decimal
    cr ." nRF24 sniffer v 1.0 " \ Show vsn
    get-status ?dup if          \ nRF24 not connected?
        E <> if  ." not "  then \ nRF24 not ready?
        ." ok, " rf@ nip .bitrate \ Show nRF24 RF settings
        ." RF channel = "  #ch .
    then  r> base ! ;

: .HX       ( x -- )        \ Print last digit of x in hex
    0F and                  \ lowest nibble
    9 over < 7 and +        \ for A..F
    ch 0 +   emit ;

: .B        ( b -- )        dup 4 rshift .hx .hx ;  \ Print last n digits of x in hex
: .BYTE     ( b -- )        .b  space ;
: .DUMP     ( a +n -- )     #len umin  bounds do  i c@ .byte  loop ;

inside definitions
code @PAYLENGTH ( a -- a +n )   \ Get payload length
    day tos .mov
    sp -) tos .mov
    day 2 .addi
    tos day ) bmov
    tos 2 .srli
    next
end-code

code RMOVE ( a1 a2 len -- ) \ Move from a1 & rearrange packet to buffer a2
    day sp )+ .mov          \ pop a2 + len - 1 to DAY
    day tos .add
    day -1 .addi
    sun sp )+ .mov          \ pop a1 + len - 1 to SUN
    sun tos .add
    sun -1 .addi
    hop 0 .li               \ carry = 0
    begin,
        moon sun ) bmov     \ a1 c@ to MOON
        w 3 .li    
        tos w >? if,
            w moon .mov     \ dup to W
            moon moon .add  \ 2*
            moon hop .or    \ carry or
            w 7 .srli       \ 7 rshift = new carry
        then,
        day ) moon bmov     \ MOON a2 c!
        hop w .mov          \ New carry from W to HOP
        sun -1 .addi        \ Decrease pointers & count
        day -1 .addi
        tos -1 .addi
    tos .0=? until,
    tos sp )+ .mov          \ drop len
    next        
end-code

\ CRC check on received packets
\ : CRC       ( x1 -- x2 )
\    dup 8000 and if
\        2* FFFF and  1021  xor  ( CRC-POLYNOMIAL CCITT )
\    else
\        2* 
\    then ;
code CRC    ( x1 -- x2 )
    day 8000 li         \ dup 8000 and
    day tos .and
    tos tos .add        \ 2*
    day .0<>? if,       \ if
        day FFFF li     \ FFFF and
        tos day .and
        day 1021 li     \ 1021 xor
        tos day .xor
    then,
    next
end-code

: CRC16     ( x1 b -- x2 )
    8 lshift xor crc crc crc crc crc crc crc crc ;

code LAST-BIT ( a x1 #pay -- a x2 )
    day sp )+ .mov      \ DAY = x1
    sun sp )  .mov      \ SUN = a
    sun tos .add        \ #pay +
    sun 3 .addi         \ 3 +
    sun sun ) bmov      \ SUN = a c@
    hop 80 li           \ 80 and
    sun hop .and
    sun 8 .slli         \ 8 lshift
    tos day .mov        \ TOS = x1
    tos sun .xor        \ xor  TOS = x2
    next
end-code

: CRC?      ( a #pay -- a f )   \ Generate & check CRC code
    >r  D310                                \ CRC of three base address bytes   a x1
    over r@ 3 + bounds do  i c@ crc16  loop \ Other address bytes & payload     a x2
    r@ last-bit  crc
    buffer r> 3 + + h@ ><  =                \ CRC correct ?                     a f
    dup 0= abs +to #crc ;                   \ Count errors                      a f

: .DATA     ( #pay -- )
    >r  buffer 8 +              \ Data start address
    3 buf> ch F = if            \ Forth command?
        ."  f: " 7 buf> type    \ Yes, show data in ASCII
    else
        ."  d: " r@ 5 - .dump   \ No, show hexdump
    then  rdrop ;

: .PAYLOAD  ( #pay -- )         \ Decode & show payload data
    >r  cr  space  3 buf> emit  \ Command first
    space  5 buf> .b ."  -> " 4 buf> .byte \ Show direction
    4 buf> 5 buf> = if          \ Hopping?
        ." via:" 1 buf> .b      \ Yes, show
    else  6 spaces  then  space
    r@ 3 > if  ."  s:" 6 buf> .byte  else 6 spaces then \ Show additional data
    r@ 4 > if  ."  a:" 7 buf> .byte  else 6 spaces then
    r@ 5 > if  r@ .data  then  rdrop ;

: .PACKETS  ( -- )
    base @ >r  decimal  
    cr ." Logged packets: " cnt .  
    ."  CRC errors: " #crc .  r> base ! ;

forth definitions
: .RAW      ( -- )  \ Show logged packets raw
    log  0 to #crc
    begin
    dup ptr < while             \ Data in log buffer
        @paylength 6 + >r       \ Get & construct packet size
        cr  dup r@ .dump        \ Show packet
        r> +                    \ To next
    repeat  drop .packets ;

: .PRETTY   ( -- )      \ Pretty read format
    log  0 to #crc
    begin
    dup ptr < while
        @paylength >r           \ Get payload length in bytes
        dup buffer r@ 6 + rmove \ Copy next packet to buffer
        r@ crc?
        r@ .payload             \ Decode packet
\ Show if packet is correct or not
        0= if  ." ~ Wrong CRC"  then
        r> 6 + +                \ Next packet
    repeat  drop  .packets ;

: .ERRORS   ( -- )      \ Pretty read format for errors only
    log  0 to #crc
    begin
    dup ptr < while
        @paylength >r           \ Get payload length in bytes
        dup buffer r@ 6 + rmove \ Copy next packet to buffer
        r@ crc? 0= if           \ Show only packets with errors
            r@ .payload ."  | " \ Decode packet
            dup r@ 6 + .dump    \ and show raw info too
        then
        r> 6 + +                \ Next packet
    repeat  drop  .packets ;

inside definitions
: CIRCULAR      ( -- )          \ Make buffer circular
    ptr log 5FF0 + < 0= if
        log to ptr  ch # emit   \ Show buffer overflow
        0 to cnt  0 to #crc  cr \ Start again
    then ;

forth definitions
\ Logged data:
\   last two bytes of device address
\   Nine bits with payload length (6-bits), PID (2-bits) & NoAck (1-bit)
\   Currently nine bytes of the real payload with possibly the 2 bytes checksum...
\
\   The CRC is the mandatory error detection mechanism in the packet. 
\   It is either 1 or 2 bytes and is calculated over the address, Packet Control Field and Payload.
\   The polynomial for 2 byte CRC is X16+ X12 + X5 + 1. Initial value 0xFFFF.
: SNIFF         ( -- )      \ Background sniffer
    spi-setup  FF to #me    \ Activate bitbang SPI-active,
    55 to #ch  3 1 rf!
    5 ms  setup24L01        \ Wakeup & init. nRF24
    .status  cr  read-mode  
    log to ptr  0 to cnt    \ Start here
    begin
        irq? if
            power-on  xreceive  \ Save packet
            #pay 6 + +to ptr    \ Add packet size to PTR
            cnt 1F and 0= if  ch . emit  then
            circular  power-off
        then 
    key? until  .pretty ;

: SNIFFER       ( -- )      \ Realtime sniffer (barebone and a bit slow)
    spi-setup               \ Activate bitbang SPI-active,
    FF to #me  55 to #ch  3 1 rf!
    5 ms  setup24L01        \ Wakeup & init. nRF24
    .status  read-mode
    log to ptr  0 to cnt    \ Start here
    begin
        begin
            response? if
                power-on  xreceive
                ptr buffer #pay 6 + rmove \ Copy next packet to buffer
                cr buffer #pay 5 + .dump
                #pay 6 + +to ptr        \ Add packet size to PTR
                circular  power-off
            then
        key? until 
        key dup bl = if  drop key  then \ Space is pause other key is stop
    bl <> until ;

fresh
' sniffer  to app
shield SNIFFER\   freeze

\ End ;;;
