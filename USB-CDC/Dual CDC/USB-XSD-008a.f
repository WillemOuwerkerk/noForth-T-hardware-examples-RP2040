(* USB driver used Leon's & Alex Taradov's code & RP2040 datasheet for documentation
    Henny Luijkx made the overview of Alex's code ( ~4412 bytes + 648 for tasker )
    Willem Jager, Leon Konings & Henny Luijkx did test and document this effort

0000 = R/W, 1000=XOR, 2000=SET, 3000=CLEAR
https://www.beyondlogic.org/usbnutshell/usb1.shtml

This version USB-XSD-008 is a CDC driver that works with Linux & Windows
using a 1 millisec. line delay and on macOS using character handshake.
*)

hex  here
v: inside also definitions \ USB device data structures
here >r     \ Device descriptor (18 bytes)
12 c,  1 c,  10 c, 1 c, ( 1.10 ) EF c,  2 c,  1 c,  40 c,  09 c, 12 c,
26 c, B1 c,  0 c, 1 c, ( vsn 1.00 )  0 c,  2 c,  0 c,  1 c,  ( noForth PID? )
here >r     \ Configuration descriptor (9 or 75 bytes, dual 9 or 141? )
9 c,  2 c,  8D c,  0 c,  4 c,  1 c,  0 c,  80 c,  FA c,  \ Maximum power = 500mA (4B+CDC1)
\ CDC 0 = 66 bytes
8 c,  0B c,  0 c,  2 c,  2 c,  2 c,  0 c,  0 c,         \ Interface Association Descriptor
9 c,  4 c,  0 c,  0 c,  1 c,  2 c,  2 c,  0 c,  4 c,    \ Interface 1: Control
5 c,  24 c,  0 c,  10 c,  1 c, ( CDC vsn 1.10 )         \ CDC Header functional
5 c,  24 c,  1 c,  0 c,  1 c, ( 2 )                     \ CDC Call management functional
4 c,  24 c,  2 c,  6 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  6 c,  0 c,  1 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  81 c,  3 c,  8 c,  0 c,  10 c,              \ Endpoint 1 IN descriptor
9 c,  4 c,  1 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  82 c,  2 c,  40 c,  0 c,  0 c,              \ Endpoint 2 IN descriptor
7 c,  5 c,  03 c,  2 c,  40 c,  0 c,  0 c, ( align )    \ Endpoint 3 OUT descriptor
\ CDC 1 = 66 bytes
8 c,  0B c,  2 c,  2 c,  2 c,  2 c,  1 c,  0 c,         \ Interface Association Descriptor
9 c,  4 c,  2 c,  0 c,  1 c,  2 c,  2 c,  1 c,  0 c,    \ Interface 1: Control
5 c,  24 c,  0 c,  10 c,  1 c, ( CDC vsn 1.10 )         \ CDC Header functional
4 c,  24 c,  2 c,  6 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  1 c,  0 c,  1 c,                           \ CDC Call management functional
5 c,  24 c,  6 c,  2 c,  3 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  84 c,  3 c,  8 c,  0 c,  10 c,              \ Endpoint 4 IN descriptor
9 c,  4 c,  3 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  85 c,  2 c,  40 c,  0 c,  0 c,              \ Endpoint 5 IN descriptor
7 c,  5 c,  06 c,  2 c,  40 c,  0 c,  0 c, ( align )    \ Endpoint 6 OUT descriptor
here r@ - .  align

5010,0480 constant USB-STATE    \ USB status of both CDC-interfaces
create USB-DATA   0 ,           \ Hold current USB config. data
                                \ Second half word for 900/880 requests
    4 c, 3 c, 9 c, 4 c,         \ English/US = language ID
    dm 115200 ,  0 c,  0 c,  8 c,  align  \ Line data: 115k2, Stop bits, Parity, Data bits

\ Name:    CNT  ORG  PKT  PID   INBUF-CTRL    OUTBUF-CTRL   EPxBUF
\ Offsets: 00   04   08   0C        10            14          18
create EP0   4 cells allot    5010,0080  dup ,   4 + ,     5010,0100 ,
create EP1   4 cells allot    5010,0088  dup ,   4 + ,     5010,0180 , \ CDC 0
create EP2   4 cells allot    5010,0090  dup ,   4 + ,     5010,0200 ,
create EP3   4 cells allot    5010,0098  dup ,   4 + ,     5010,0280 ,
create EP4   4 cells allot    5010,00A0  dup ,   4 + ,     5010,0300 , \ CDC 1
create EP5   4 cells allot    5010,00A8  dup ,   4 + ,     5010,0380 ,
create EP6   4 cells allot    5010,00B0  dup ,   4 + ,     5010,0400 ,

(* High level code for documentation
: 2+        ( n1 -- n2 )            2 + ;
: >UNI      ( a1 u -- a2 )      \ Convert string to unicode format for USB
    dup  2* 302 + fp h!  0      \ String length & notifier
    ?do  c@+  fp i 2* + 2+ h!  loop  drop  fp ;
: >CNT      ; immediate     \ 00 - ep0 >cnt !
: >ORG      cell+ ;         \ 04 - ep1 >org @
: >PKT      2 cells + ;     \ 08
: >PID      3 cells + ;     \ 0C
: >ICTRL    4 cells + ;     \ 10
: >OCTRL    5 cells + ;     \ 14
: >BUF      6 cells + ;     \ 18
: EP-IN     ( ep -- org buf pkt )   >r  r@ >org @   r@ >buf @   r> >pkt @ ;
: PREPARE   ( a u ep -- )           >r  dup r@ >cnt !  40 min r@ >pkt !  r> >org ! ;
: >NEXT     ( ep -- pkt )           >r  r@ >pkt @   r@ >org @  +  r@ >org !
                                    r@ >pkt @  r@ @  over -  dup r@ !  40 min r> >pkt ! ;
: !PKT      ( pkt ep -- ictrl )     >r  r@ >pid @ or  8000 or   \ pid + pkt + mask
                                    r> >ictrl @  tuck ! ;
: USB-RECEIVE   ( ep -- )           >r r@ >octrl @   r@ >pid @  40 or  over !
                                    2000 r> >pid **bix  400 swap **bis ;
: GONE?     ( ep -- f )             >ictrl @ @ 400 and 0= ;
: USB1?     ( -- +n )               usb-state h@ ;
: USB2?     ( -- +n )               usb-state 2+ h@ ;
*)

create >UNI ( a1 u1 -- a2 )     \ Convert string to unicode format for USB (32)
    adr fp ,  300 ,  code>
    6824CA30 ,  C9208025 ,  782F2202 ,  52A73501 ,
    3B013202 ,  7022D1F9 ,  C8040023 ,  46A7CA10 ,  end-code
code >PID       C804330C ,  46A7CA10 ,  end-code
code >BUF       C8043318 ,  46A7CA10 ,  end-code
code EP-IN      699D685C ,  3904689B ,  3904600C ,  C804600D ,  46A7CA10 ,  end-code
code PREPARE    601DC920 ,  D9002D40 ,  609D2540 ,
                605DC920 ,  C804C908 ,  46A7CA10 ,  end-code
code >NEXT      685D689C ,  605D192D ,  1B2D681D ,
                2D40601D ,  2540D900 ,  0023609D ,  CA10C804 ,  FFFF46A7 ,  end-code
code !PKT       C92068DC ,  2580432C ,  432C022D ,
                601C691B ,  CA10C804 ,  FFFF46A7 ,  end-code
code USB-RECEIVE  68DD695C ,  43352640 ,
                26206025 ,  68DF0236 ,  60DF4077 ,  1362640 ,
                60254335 ,  C804C908 ,  46A7CA10 ,  end-code
code GONE?      681B3310 ,  2404681B ,  40230224 ,
                419B3B01 ,  CA10C804 ,  FFFF46A7 ,  end-code
code 2+         C8043302 ,  46A7CA10 ,  end-code
create USB0?    usb-state ,  code> here >r  39046812 ,  8813600B ,  D0002B03 ,  C8042300 ,  46A7CA10 ,  end-code
create USB1?    r> here cell- !  usb-state 2+ ,

(* Using spinlocks
A spinlock is a dedicated memory location that can be used
to protect memory access & hardware devices on a multicore system.
When read zero the address or device is locked, when read non zero!
the device is free to use and locked at the same time.
When both cores access the spinlock at the same time core-0 wins.
D0000100    - Spinlock 0

0 yours     - RX spinlock ( 0 mine? )
4 yours     - TX spinlock ( 4 mine? )
*)

create MINE?    ( +n -- s ) \ Leave 1 when spinlock +n is free, 0 when occupied
    D0000100 ,  code> 18E4CA10 ,  C8046823 ,  46A7CA10 ,  end-code
create YOURS    ( +n -- )   \ Free spinlock +n
    D0000100 ,  code> 18E4CA10 ,  6023C908 ,  CA10C804 ,  FFFF46A7 ,  end-code

\ Basic receive & transmit packet handlers
: USB-SEND   ( ep -- )      >r  r@ >next  r@ !pkt  2000 r> >pid **bix  400 swap **bix ;
: USB-RCV    ( pid ep -- )  tuck >pid !  usb-receive ;

: SETUP>        ( a u -- )      \ Handle the answer for all setup packages
    2000 ep0 >pid !  ep0 prepare                \ Start with DATA1, setup packet data
    begin
        ep0 ep-in move  ep0 usb-send            \ Send setup packet
        1 5011,0058                             \ Packet gone?
        begin   pause  2dup bit** until  **bis
    ep0 @ 0= until  2000 ep0 usb-rcv ;          \ Handle ZLP

\ : XTABLE        ( req a +n -- )        \ USB execution table handler (148)
\    >r r@ for  2dup @ = if              \ Token found?
\            nip  rdrop  r> cells +      \ Yes, calc. cell with XT
\            @ execute  exit             \ Fetch & execute XT
\        then
\        cell+
\    next  rdrop  2drop                  \ No token found
\    1 5011,0068 !  800 5010,0080 ! ;    \ Send EP0 stall
create XTABLE   ( req a +n -- ) \ USB execution table handler (72)
    50110068 ,  50100080 ,
code>
    001FC930 ,  6826009B ,  D10442B5 ,
    C90818E4 ,  CA106822 ,  340446A7 ,
    D1F43F01 ,  2301CAC0 ,  23086033 ,
    603B021B ,  C804C908 ,  46A7CA10 ,
end-code

: @VAL      ( -- +n )       5010,0002 h@ ; \ wValue
: @LEN      ( -- +n )       5010,0006 h@ ; \ wLength
: $DESCR>   ( a u -- )      1D min >uni  dup c@ @len min setup> ; \ Send string descriptors
: ZLP>      ( -- )          here false setup> ;     \ Send EP0 ZLP
:noname     ramborder 428 + c@+ $descr> ;           \ 0304 Device-1 name string
:noname     me count $descr> ;                      \ 0302 Device-0 name string
:noname     usb-data cell+ 4 setup> ;               \ 0300 Lang-ID string
:noname     [ r> ] literal  @len 8D min setup> ;    \ 0200 CONF-DESCR>
:noname     [ r> ] literal  12 @len min setup> ;    \ 0100 DEV-DESCR>
create SETUP-REQ    ( req -- )
    0100 ,     0200 ,      0300 ,     0302 ,     0304 ,
    ( dev ) ,  ( conf ) ,  ( lang ) , ( name ) , ( name2 ) ,
does>   ( req a -- )    5 xtable ;

' cold                                      \ 2321 Break, restart noForth t
:noname     @val 50100004 c@ usb-state + c! \ 2221 Set control line state
            zlp>  0 yours  4 yours ;        \ Free RX & TX ringbuffers
:noname     usb-data cell+ cell+ 7 setup> ; \ 21A1 Get line coding
:noname     2000 ep0 usb-rcv  zlp> ;        \ 2021 Set line coding
:noname     zlp>  @val usb-data h! ;        \ 0900 Set USB configuration
:noname     usb-data 2 setup> ;             \ 0880 Get USB configuration
:noname     @val setup-req ;                \ 0680 Basic usb SETUP handler
:noname     zlp>  @val 5011,0000 ! ;        \ 0500 Set device address
create HANDLE-REQ   ( -- )
    0500 ,  0680 ,  0880 ,  0900 ,  2021 ,  21A1 ,  2221 ,  2321 ,
    ,       ,       ,       ,       ,       ,       ,       ,
does>   ( a -- )        20000 5011,3050 !  5010,0000 h@  swap  8 xtable ;

\ Ring buffers for safe character I/O
        100  constant #L        \ Must be factor of two
\ 5010,0480  constant USB-STATE \ Both driver statuses
\ 5010,0484  constant EMPTY     \ Now free space
\ 5010,0488  constant BUFFERS   \ Usess #L + 12 bytes * 4

create #RX0 ( -- +n )   \ Chars in RX buffer (20)
    5010,0488 ,  here >r  code>  600B3904 ,  681BCA08 ,  CA10C804 ,  FFFF46A7 ,  end-code
create #TX0 ( -- +n )   r@  here cell- !  5010,0488  #L 3 cells +  1 * + , \ Chars in TX buffer
create #RX1 ( -- +n )   r@  here cell- !  5010,0488  #L 3 cells +  2 * + , \ Chars in RX1 buffer
create #TX1 ( -- +n )   r>  here cell- !  5010,0488  #L 3 cells +  3 * + , \ Chars in TX1 buffer

create >RX0 ( c -- )    \ Save char. in RX buffer
    5010,0488 ,  #L 1- ,  code>   here >r
    0015CA84 ,  350C6854 ,  3401552B ,  6054403C ,
    35016815 ,  C9086015 ,  CA10C804 ,  FFFF46A7 ,
end-code
create >TX0 ( c -- )   r@  here cell- !  5010,0488 #L 3 cells +  1 * + ,  #L 1- , \ Save char to send
create >RX1 ( c -- )   r>  here cell- !  5010,0488 #L 3 cells +  2 * + ,  #L 1- , \ Save char to receive1
\ create >TX1 ( c -- )   r>  here cell- !  5010,0488 #L 3 cells +  3 * + ,  #L 1- , \ Save char to send1

create RX0> ( -- c )    \ Read char from RX buffer
    5010,0488 ,  #L 1- ,  code>   here >r
    0015CA84 ,  600B3904 ,  350C6894 ,  34015D2B ,
    6094403C ,  3D016815 ,  C8046015 ,  46A7CA10 ,
end-code
create TX0> ( -- c )   r@  here cell- !  5010,0488 #L 3 cells +  1 * + ,  #L 1- , \ Read received char
\ create RX1> ( -- c )   r@  here cell- !  5010,0488 #L 3 cells +  2 * + ,  #L 1- , \ Read received char
create TX1> ( -- c )   r>  here cell- !  5010,0488 #L 3 cells +  3 * + ,  #L 1- , \ Read received char

: USB-KEY?  ( -- f )    pause  #rx0 ;    \ KEY & EMIT with ringbuffer
: USB-KEY   ( -- c )    begin  pause  #rx0 until  rx0> ;
: USB-EMIT  ( c -- )    begin  pause  #L #tx0 - until  >tx0 ;

:noname \ BUS-RESET     ( -- )
    80000  5011,3050  !                     \ SIE_STATUS - BUS_RESET (Clear bit)
    false  5011,0000  !  false usb-state !  \ USB-address=0 & USB-state=0
    false ep3 usb-rcv    false ep2 >pid !   \ Allow receiving EP3 & init. transmit EP2
    false ep6 usb-rcv    false ep5 >pid ! ; \ Allow receiving EP6 & init. transmit EP5

:noname \ ENDPOINTS ( if0 -- if1 ) \ Handle used endpoints
    5011,0058 @
    dup 04 and if  zlp>  then   \ EP1 active?
    dup 5011,0058 !             \ Clear active flags
    2080 and  or ;  2>r         \ EP3 and/or EP6 active, remember

\ : REQUESTS  ( if0 -- if1 )
\    5011,0098 @ >r ( ints )
\    r@    10 and if  endpoints        then   \    10 = dm 04 bitmask
\    r@  1000 and if  bus-reset        then   \  1000 = dm 12 bitmask
\    r> 10000 and if  handle-requests  then ; \ 10000 = dm 16 bitmask
create REQUESTS
    5011,0098 ,  ( ' endpoints ) r> ,  ( ' bus-reset ) r> ,  ' handle-req ,
code>
    6824CA10 ,  42AC2510 ,  6812D102 ,
    46A7CA10 ,  42AC022D ,  6852D102 ,  46A7CA10 ,
    42AC012D ,  6892D102 ,  46A7CA10 ,  CA10C804 ,
    FFFF46A7 ,  end-code

:noname \ USB-TX1           ( -- )
    begin  4 us  usb1? until  0A ms
    begin
        begin  pause  usb1? until   \ Connected?
        #tx1 if                     \ EP5 Any chars to send?
            ep5 gone? if            \ Yes, previous packet gone?
                40 us  4 mine? if                   \ TX1 buffer free to use
                    ep5 >buf @  #tx1  40 umin       \ Packet place & size
                    2dup ep5 prepare  bounds        \ Init. transmit pointers
                    ?do  tx1> i c! loop  4 yours    \ Place data in EP5-buffer
                    ep5 usb-send                    \ Send data to host
                then
            then
        then
    again ;  >r

:noname \ USB-TX0           ( -- )
    begin  4 us  usb0? until  0A ms
    begin
        begin  pause  usb0? until   \ Connected?
        #tx0 if                     \ EP2 Any chars to send?
            ep2 gone? if            \ Yes, previous packet gone?
                40 us  ep2 >buf @  #tx0 40 umin \ Packet place & size
                2dup ep2 prepare  bounds        \ Init. transmit pointers
                ?do  tx0> i c!  loop            \ Place data in EP2-buffer
                ep2 usb-send                    \ Send data to host
            then
        then
    again ;  >r

:noname \ USB-RX            ( if0 -- if1 )  \ Restart RX after a delayed reception
    dup 80 and if                   \ Delayed reception active?
        5010,009C c@ >r             \ Data bytes arrived in EP3
        #L #tx0 - r@ >              \ Yes, enough space in TX buffer?
        #L #rx0 - r@ >  and if      \ And next RX packet fits too?
            ep3 >buf @  r@          \ Yes, fill RX0 buffer
            for  c@+ >rx0  next
            10 us  drop  80 xor     \ Done
            ep3 usb-receive         \ And allow next RX0 packet
        then  rdrop
    then
    dup 2000 and if                 \ Delayed reception active?
        5010,00B4 c@ >r             \ Data bytes arrived in EP6
        #L #tx1 - r@ >              \ Enough space in TX1 buffer?
        #L #rx1 - r@ >  and if      \ And next RX1 packet fits too?
            0 mine? if              \ Available?
                ep6 >buf @  r@      \ Yes, fill RX1 buffer
                for  c@+ >rx1  next drop
                0 yours  8 us  2000 xor \ Done
                ep6 usb-receive     \ Allow next RX1 packet
            then
        then  rdrop
    then ;  >r

:noname \ START-USB     ( -- )
    1000000  4000C000           \ Bit-24 mask & Reset register
    2dup **bis  2dup **bic      \ Restart USB
    begin  2dup 8 + bit** until \ Wait until USB is ready
    2drop 5010,0000 1000 false fill \ Erase USB ram
    0000,0009  5011,0074  !     \ USB_USB_MUXING    Softcon, to PHY
    0000,000C  5011,0078  !     \ USB_USB_PWR       VBUS overide & detect enable
    0000,0001  5011,0040  !     \ USB_MAIN_CTRl     Enable controller
    2000,0000  5011,004C  !     \ USB_SIE_CONTROL   Enable End Point 0 interrupt
    false      5011,0000  !     \ Respond to address 0 on initial setup
    0001,1010  5011,0090  !     \ USB_INTE          Enable 3 interrupts
\ CDC 0
    AC00,0180  5010,0008  !     \ init COMM endpoint in buffer 1
    A800,0200  5010,0010  !     \ init SEND endpoint in buffer 2
    A800,0280  5010,001C  !     \ init RECV endpoint out buffer 3
\ CDC 1
    AC00,0300  5010,0020  !     \ init COMM endpoint in buffer 4
    A800,0380  5010,0028  !     \ init SEND endpoint in buffer 5
    A800,0400  5010,0034  !     \ init RECV endpoint out buffer 6

    0001,0000  5011,204C  ! ;  >r  \ USB_SIE_CONTROL   Enable pull up

:noname \ HANDLE-USB        ( -- )  \ Handle USB setup & transceiving of chars
    ( start-usb ) [ r> compile, ]  false usb-state !  false  ( if )
    ['] usb-key? to 'key?
    ['] usb-key  to 'key
    ['] usb-emit to 'emit
    begin
        requests  pause  ( usb-rx ) [ r> compile, ]
    again ;  >r

task: USB1      task: USB2    task: USB3    \ The USB tasks
v: extra definitions
: USB-ON            ( -- )
    0 yours  4 yours            \ Free access to RX & TX ringbuffers
    ( ['] handle-usb ) [ r> ] literal  usb1 start-task
    ( ['] usb-tx0 )    [ r> ] literal  usb2 start-task
    ( ['] usb-tx1 )    [ r> ] literal  usb3 start-task ;

' usb-on   to &config   \ Fill additional configuration vector
v: fresh
shield CDC0\  \ freeze
here swap - dm .
