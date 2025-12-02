\ USB driver used Leon's & Alex Taradov's code & RP2040 datasheet for documentation
\   Henny Luijkx made the overview of Alex's code ( 4216 bytes )
\   Willem Jager, Leon Konings & Henny Luijkx did test and document this effort
\
\ 0000 = R/W, 1000=XOR, 2000=SET, 3000=CLEAR
\ https://www.beyondlogic.org/usbnutshell/usb1.shtml
\
\ This version USB-XS-005hilevel is a CDC driver that works with Linux & Windows
\ using a 1 millisec. line delay and with macOS using character handshake.
\
\ This programme assumes 32-bit cells.
\ Non DPANS94 standard words used are:
\ : C@+   ( a1 -- a2 b )  count ;
\ : @+    ( a1 -- a2 u )  dup @ >r  cell+  r> ;
\ : H@    ( a - h )       count swap  c@ 8 lshift  or ;
\ : H!    ( h a -- )      >r  dup r@ c!  8 rshift  r> 1+ c! ;
\ : **BIS ( msk a -- )    >r r@ @ or  r> ! ;
\ : **BIC ( msk a -- )    >r invert r@ @ and  r> ! ;
\ : **BIX ( msk a -- )    >r r@ @ xor  r> ! ;
\ : BIT** ( msk a -- b )  @ and ;

hex  here   \ USB device data structures
create DEV-DESCR    \ Device descriptor (18 bytes)
12 c, 01 c, 10 c, 01 c, ( 1.10 ) EF c, 02 c, 01 c, 40 c, 66 c, 66 c, ( 6666 )
10 c, 66 c, ( 6610 ) 00 c, 01 c, ( vsn 1.00 ) 00 c, 02 c, 00 c, 01 c,  align
create CONFIG-DESCR \ Configuration descriptor (9 or 75 bytes)
9 c,  2 c,  4B c,  0 c,  2 c,  1 c,  0 c,  80 c,  FA c, \ Maximum power = 500mA
8 c,  0B c,  0 c,  2 c,  2 c,  2 c,  1 c,  0 c,         \ Interface Association Descriptor - CDC 0
9 c,  4 c,  0 c,  0 c,  1 c,  2 c,  2 c,  1 c,  0 c,    \ Interface 1: Control - 1 - 0 -
5 c,  24 c,  0 c,  10 c,  1 c, ( CDC vsn 1.10 )         \ CDC Header functional
5 c,  24 c,  1 c,  0 c,  1 c,                           \ CDC Call management functional
4 c,  24 c,  2 c,  2 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  6 c,  0 c,  1 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  81 c,  3 c,  8 c,  0 c,  10 c,              \ Endpoint 1 IN descriptor
9 c,  4 c,  1 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  82 c,  2 c,  40 c, 0 c,  0 c,               \ Endpoint 2 IN descriptor
7 c,  5 c,  3 c,  2 c,  40 c, 0 c,  0 c,  align         \ Endpoint 3 OUT descriptor

create PAD  ( -- a )    40 allot    \ Scratchpad memory

decimal
create USB-STATE  0 ,           \ Hold current USB state: 3 = ready
        4 c, 3 c, 9 c, 4 c,     \ English/US = language ID
        115200 ,  0 c,  0 c,  8 c,  align  \ Line data: 115k2, Stop bits, Parity, Data bits
hex                             \ Second half word for 900/880 requests
: START-USB     ( -- )
    1000000  4000C000           \ Bit-24 mask & Reset register
    2dup **bis  2dup **bic      \ Restart USB
    begin  2dup 8 + bit** until \ Wait until USB is ready
    2drop 50100000 1000 false fill \ Erase USB ram
    00000009  50110074  !       \ USB_USB_MUXING    Softcon, to PHY
    0000000C  50110078  !       \ USB_USB_PWR       VBUS overide & detect enable
    00000001  50110040  !       \ USB_MAIN_CTRl     Enable controller
    20000000  5011004C  !       \ USB_SIE_CONTROL   Enable End Point 0 interrupt
    false     50110000  !       \ Respond to address 0 on initial setup
    00011010  50110090  !       \ USB_INTE          Enable 3 interrupts
    AC000180  50100008  !       \ init COMM endpoint in buffer 1
    A8000200  50100010  !       \ init SEND endpoint in buffer 2
    A8000280  5010001C  !       \ init RECV endpoint out buffer 3
    00010000  5011204C  ! ;     \ USB_SIE_CONTROL   Enable pull up

\ Name:    CNT  ORG  PKT  PID   INBUF-CTRL  OUTBUF-CTRL   EPxBUF
\ Offsets: 00   04   08   0C       10            14         18
create EP0   4 cells allot   50100080  dup ,   4 + ,    50100100 ,
create EP1   4 cells allot   50100088  dup ,   4 + ,    50100180 ,
create EP2   4 cells allot   50100090  dup ,   4 + ,    50100200 ,
create EP3   4 cells allot   50100098  dup ,   4 + ,    50100280 ,

: @VAL      ( -- +n )       50100002 h@ ; \ wValue
: @LEN      ( -- +n )       50100006 h@ ; \ wLength

: >UNI      ( a1 u -- a2 )      \ Convert string to unicode format for USB
    dup  2* 302 + pad h!  0      \ String length & notifier
    ?do  c@+  pad i 2* + 2 + h!  loop  drop  pad ;

\ Addresssing tools for endpoint administration
: >CNT      ; immediate     \ 00 - ep0 >cnt !   - Bytes left te send
: >ORG      cell+ ;         \ 04 - ep1 >org @   - Address of next packet
: >PKT      2 cells + ;     \ 08                - Packet size
: >PID      3 cells + ;     \ 0C                - Actual PID
: >ICTRL    4 cells + ;     \ 10                - USB in control register
: >OCTRL    5 cells + ;     \ 14                - USB out control register
: >BUF      6 cells + ;     \ 18                - EPx buffer address

\ Primitive endpoint functionality
: EP-IN     ( ep -- org buf pkt )   >r  r@ >org @   r@ >buf @   r> >pkt @ ;     \ Calculate data to send for EPx
: PREPARE   ( a u ep -- )           >r  dup r@ >cnt !  40 min r@ >pkt !  r> >org ! ; \ Prepare data to send for EPx
: >NEXT     ( ep -- pkt )           >r  r@ >pkt @   r@ >org @  +  r@ >org !     \ Get next packet size for EPx
                                    r@ >pkt @  r@ @  over -  dup r@ !  40 min r> >pkt ! ;
: !PKT      ( pkt ep -- ictrl )     >r  r@ >pid @ or  8000 or   \ pid + pkt + mask - Store next packet to send for EPx
                                    r> >ictrl @  tuck ! ;
: PREP-RCV  ( ep -- )               >r r@ >octrl @   r@ >pid @  40 or  over !   \ Prepare to receive a packet on EPx
                                    2000 r> >pid **bix  400 swap **bis ;
: GONE?     ( ep -- f )             >ictrl @ @ 400 and 0= ;     \ Leave true when Epx packet was sent
: USB?      ( -- +n )               usb-state h@ 3 = ;          \ True when host & device are connected


\ Basic receive & transmit packet handlers
: USB-SEND   ( ep -- )      >r  r@ >next  r@ !pkt  2000 r> >pid **bix  400 swap **bix ;
: USB-RCV    ( pid ep -- )  tuck >pid !  prep-rcv ;

: BUS-RESET     ( -- )
    80000  50113050  !                     \ SIE_STATUS - BUS_RESET (Clear bit)
    false  50110000  !  false usb-state !  \ USB-address=0 & USB-state=0, u-config = 0
    false ep3 usb-rcv   false ep2 >pid ! ; \ Allow receiving EP3 & init. transmit EP2

: SETUP>        ( a u -- )      \ Handle the answer for all setup packages
    2000 ep0 >pid !  ep0 prepare                \ Start with DATA1, setup packet data
    begin
        ep0 ep-in move  ep0 usb-send            \ Store & send packet
        1 50110058                              \ Packet gone?
        begin  2dup bit** until  **bis
    ep0 @ 0= until  2000 ep0 usb-rcv ;          \ Handle ZLP

: XTABLE    ( +n "name" -- )    \ Define custom execution table
    create  ,
    does> @+    ( req -- )
    >r r@ 0 ?do  2dup @ = if            \ Token found?
            nip  unloop  r> cells +     \ Yes, calc. cell with XT
            @ execute  exit             \ Fetch & execute XT
        then
        cell+
    loop  r> drop  2drop                \ No token found
    1 5011,0068 !  800 5010,0080 ! ;    \ Send EP0 stall

: ZLP>          ( -- )      here false setup> ;             \ Send EP0 ZLP

:noname     me count 1D min >uni  dup c@ @len min setup> ;  \ 0302 Device name string
:noname     usb-state cell+ 4 setup> ;                      \ 0300 Lang-ID string
:noname     config-descr  @len 4B min setup> ;              \ 0200 Config descriptor
:noname     dev-descr  @len 12 min setup> ;                 \ 0100 Device descriptor
4 xtable HANDLE-SETUP   ( req -- )
    0100 ,     0200 ,      0300 ,     0302 ,
    ( dev ) ,  ( conf ) ,  ( 300 ) ,  ( 302 ) ,

:noname     @val usb-state c!  zlp> ;        \ 2221 Set control line state
:noname     usb-state cell+ cell+ 7 setup> ; \ 21A1 Get line coding
:noname     2000 ep0 usb-rcv  zlp> ;         \ 2021 Set line coding
:noname     zlp>  @val   usb-state 2 +  h! ; \ 0900 Set USB configuration
:noname     usb-state 2 + 2 setup> ;         \ 0880 Get USB configuration
:noname     @val handle-setup ;              \ 0680 Basic usb SETUP handler
:noname     zlp>  @val 5011,0000 ! ;         \ 0500 Set device address
7 xtable HANDLE-REQ)    ( -- )
    0500 ,  0680 ,  0880 ,  0900 ,  2021 ,  21A1 ,  2221 ,
    ,       ,       ,       ,       ,       ,       ,

: HANDLE-REQ    ( -- )  20000 5011,3050 !  5010,0000 h@  handle-req) ;

\ Ring buffer structure for serial I/O
\
\ 0   = Number of used storage units (CNT)
\ 1   = In pointer (IN)
\ 2   = Out pointer (OUT)
\ 3   = Start of ring buffer

100     constant #L     \ Buffer size
#L 1-   constant #R     \ Buffer mask

50100300   constant BUFFER1             \ Usess 2 * #L + 24 bytes  = 536 bytes
buffer1 #l + 3 cells + constant BUFFER2 \ Start of out buffer
: #RX       ( -- +n )   buffer1 @ ; \ +n characters in receive buffer
: #TX       ( -- +n )   buffer2 @ ; \ +n characters in send buffer

: >RX       ( ch -- )
    buffer1 cell+ >r
    r@ @  r@ 2 cells + +  c!        \ Yes, add char to buffer
    r@ @ 1+ #r and  r@ !            \ Increase & protect write pointer
    1  r> cell-  +! ;               \ Increase used space
: RX>       ( -- ch )
    buffer1 2 cells + >r
    r@ @  r@ cell+ + c@             \ Read char. from buffer
    r@ @ 1+ #r and r@ !             \ Increase & protect read pointer
    true  r> 2 cells -  +! ;        \ Decrease used space

: >TX       ( ch -- )
    buffer2 cell+ >r
    r@ @  r@ 2 cells + +  c!        \ Yes, add char to buffer
    r@ @ 1+ #r and  r@ !            \ Increase & protect write pointer
    1  r> cell-  +! ;               \ Increase used space
: TX>       ( -- ch )
    buffer2 2 cells + >r
    r@ @  r@ cell+ + c@             \ Read char. from buffer
    r@ @ 1+ #r and  r@ !            \ Increase & protect read pointer
    true  r> 2 cells -  +! ;        \ Decrease used space

variable IFLAG  0 iflag !
: ENDPOINTS ( -- )   \ Handle used endpoints
    50110058 @ >r
    r@ 04 and if  zlp>      then    \ EP1 active?
    iflag @  r@ 80 and or  iflag !  \ EP3 active, remember
    r> 50110058 ! ;

: REQUESTS  ( -- )                  \ Handle all USB requests
    50110098 @ >r ( ints )
    r@    10 and if  endpoints   then   \    10 = #04 bitmask
    r@  1000 and if  bus-reset   then   \  1000 = #12 bitmask
    r> 10000 and if  handle-req  then ; \ 10000 = #16 bitmask

: USB-HANDLER       ( -- )  \ Handle USB setup & character I/O
    requests
    iflag @ if                  \ Next RX packet wanted?
        #L #tx - 40 >           \ Yes, enough space in TX buffer?
        #L #rx - 40 > and if    \ And next RX packet fits too?
            ep3 >buf @  5010009C c@
            0 ?do c@+ >rx loop  \ Yes, fill RX buffer
            drop false  iflag ! \ Done
            ep3 prep-rcv        \ And allow next RX packet
        then
    then
    usb? if                     \ Still connected?
        #tx if                  \ EP2 Any chars to send?
            ep2 gone? if        \ Yes, previous packet gone?
                ep2 >buf @  #tx  40 min     \ Packet place & size
                2dup ep2 prepare  bounds    \ Init. transmit pointers
                ?do  tx> i c!  loop         \ Place data in EP2-buffer
                ep2 usb-send                \ Send to host
            then
        then
    then ;

: USB-KEY?  ( -- f )    usb-handler  #rx ;    \ KEY & EMIT with ringbuffer
: USB-KEY   ( -- c )    begin  usb-handler  #rx until  rx> ;
: USB-EMIT  ( c -- )    begin  usb-handler  #L #tx - until  >tx ;

: USB-ON            ( -- )
    50100300  [ #L 2* 6 cells + ] literal  false fill \ Init. buffer space to zero
    start-usb  false usb-state !  false iflag !
    ['] usb-key? to 'key?           \ Install USB CDC char. I/O vectors
    ['] usb-key  to 'key
    ['] usb-emit to 'emit ;

here swap - decimal . hex

usb-on
