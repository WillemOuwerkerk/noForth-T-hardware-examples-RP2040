(* USB driver used Leon's & Alex Taradov's code & RP2040 datasheet for documentation
    Henny Luijkx made the overview of Alex's code ( 3880 bytes )

0000 = R/W, 1000=XOR, 2000=SET, 3000=CLEAR
https://www.beyondlogic.org/usbnutshell/usb1.shtml

This version USB-XS-003mc is a neat CDC driver that works with
Linux, Windows using a 1 millisec. line delay and a little with macOS.
*)

hex  here dup
v: inside also  definitions \ Write halfword with USB data order (lb hb)
: 2C,   ( h -- )    dup c,  >< c, ;
: OF                ( -- )      \ A Forth macro for readability
    postpone over  postpone =  postpone if  postpone drop ; immediate
here swap - dm .

v: inside definitions \ USB device data structures
here >r     \ Device descriptor (18 bytes)
12 c,  1 c,  0200 2c,  EF c,  2 c,  1 c,  40 c,  6666 2c,
6610 2c,  0020 2c, ( vsn 0.20 )  0 c,  2 c,  0 c,  1 c,  ( align )
here >r     \ Configuration descriptor (9 or 75 bytes)
9 c,  2 c,  004B 2c,  2 c,  1 c,  0 c,  80 c,  FA c,    \ Maximum power = 500mA
8 c,  0B c,  0 c,  2 c,  2 c,  2 c,  1 c,  0 c,         \ Interface Association Descriptor
9 c,  4 c,  0 c,  0 c,  1 c,  2 c,  2 c,  1 c,  0 c,    \ Interface 1: Control - 1 - 0 -
5 c,  24 c,  0 c,  110 2c, ( CDC vsn 1.10 )             \ CDC Header functional
5 c,  24 c,  1 c,  0 c,  1 c,                           \ CDC Call management functional
4 c,  24 c,  2 c,  2 c,                                 \ CDC ACM functional ( two commands )
5 c,  24 c,  6 c,  0 c,  1 c,                           \ CDC Union functional ( one interface )
7 c,  5 c,  81 c,  3 c,  0008 2c,  10 c,                \ Endpoint 1 IN descriptor
9 c,  4 c,  1 c,  0 c,  2 c,  0A c,  0 c,  0 c,  0 c,   \ Interface 2: DATA
7 c,  5 c,  82 c,  2 c,  0040 2c,  0 c,                 \ Endpoint 2 IN descriptor
7 c,  5 c,  3 c,  2 c,  0040 2c,  0 c,  align           \ Endpoint 3 OUT descriptor

create USB-STATE  0 ,           \ Hold current USB state: 7 = ready, 107 = functional
        4 c, 3 c, 9 c, 4 c,     \ English/US = language ID
        dm 115200 ,  0 c,  0 c,  8 c,  align  \ Line data: 115k2, Stop bits, Parity, Data bits
                                \ Second half word for 900/880 requests
: START-USB     ( -- )
    1000000  4000C000           \ Bit-24 mask & Reset register
    2dup **bis  2dup **bic      \ Restart USB
    begin  2dup 8 + bit** until \ Wait until USB is ready
    2drop 5010,0000 1000 0 fill \ Erase USB ram
    0000,0009  5011,0074  !     \ USB_USB_MUXING    Softcon, to PHY
    0000,000C  5011,0078  !     \ USB_USB_PWR       VBUS overide & detect enable
    0000,0001  5011,0040  !     \ USB_MAIN_CTRl     Enable controller
    2000,0000  5011,004C  !     \ USB_SIE_CONTROL   Enable End Point 0 interrupt
    false      5011,0000  !     \ Respond to address 0 on initial setup
    0001,1010  5011,0090  !     \ USB_INTE          Enable 3 interrupts
    AC00,0180  5010,0008  !     \ init COMM endpoint in buffer 1
    A800,0200  5010,0010  !     \ init SEND endpoint in buffer 2
    A800,0280  5010,001C  !     \ init RECV endpoint out buffer 3
    0001,0000  5011,204C  ! ;   \ USB_SIE_CONTROL   Enable pull up

\ Name:    CNT  ORG  PKT  PID   INBUF-CTRL  OUTBUF-CTRL   EPxBUF
\ Offsets: 00   04   08   0C       10            14         18
create EP0   4 cells allot   5010,0080  dup ,   4 + ,    5010,0100 ,
create EP1   4 cells allot   5010,0088  dup ,   4 + ,    5010,0180 ,
create EP2   4 cells allot   5010,0090  dup ,   4 + ,    5010,0200 ,
create EP3   4 cells allot   5010,0098  dup ,   4 + ,    5010,0280 ,

: @VAL      ( -- +n )       5010,0002 h@ ; \ wValue
: @LEN      ( -- +n )       5010,0006 h@ ; \ wLength

(* High level code for documentation
: >UNI      ( a1 u -- a2 )      \ Convert string to unicode format for USB
    dup  2* 302 + fp h!  0      \ String length & notifier
    ?do  c@+  fp i 2* + 2 + h!  loop  drop  fp ;
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
: USB?      ( -- +n )               usb-state h@ ;
: 2+        ( n1 -- n2 )            2 + ;
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
create USB?     usb-state ,  code>  39046812 ,  8813600B ,  CA10C804 ,  FFFF46A7 ,  end-code
code 2+         C8043302 ,  46A7CA10 ,  end-code

\ Basic receive & transmit packet handlers
: USB-PACKET ( ep -- )      >r  r@ >next  r@ !pkt  2000 r> >pid **bix  400 swap **bix ;
: USB-SEND   ( ep -- )      dup ep-in move   usb-packet ;
: USB-RCV    ( pid ep -- )  tuck >pid !  usb-receive ;

: BUS-RESET     ( -- )
    80000  5011,3050  !         \ SIE_STATUS - BUS_RESET (Clear bit)
    false  5011,0000  !  false usb-state !  \ USB-address=0 & USB-state=0, u-config = 0
    false ep3 usb-rcv    false ep2 >pid ! ; \ Allow receiving EP3 & init. transmit EP2

: SETUP>        ( a u -- )      \ Handle the answer for all setup packages
    2000 ep0 >pid !  ep0 prepare                \ Start with DATA1, setup packet data
    begin
        ep0 usb-send  1 5011,0058               \ Send packet
        begin   pause  2dup bit** until  **bis  \ Packet gone?
    ep0 @ 0= until  2000 ep0 usb-rcv ;          \ Handle ZLP

: $DESCR>       ( a u -- )  1D min >uni  dup c@ @len min setup> ;   \ Sent string descriptors
: ZLP>          ( -- )      here false setup> ;                     \ Send EP0 ZLP
: CONF-DESCR>   ( -- )      [ r> ] literal  @len 4B min setup> ;
: DEV-DESCR>    ( -- )      [ r> ] literal  12 @len min setup> ;
: STALL>        ( -- )      1 5011,0068 !  800 5010,0080 ! ;        \ Send EP0 stall
: SET-CONFIG    ( -- )      zlp>  @val   usb-state 2+  h! ;

: HANDLE-SETUP      ( -- )
    @val
    0100 of  dev-descr>  exit               then    \ Handle device decriptor
    0200 of  conf-descr> exit               then    \ Handle config decriptor
    0300 of  usb-state cell+ 4 setup>  exit then    \ Handle string decriptor 0
    0302 of  me count $descr>  exit         then    \ Handle string decriptor 2
    drop  stall> ;                                  \ Unkown command send stall

: HANDLE-REQUESTS   ( -- )
    20000 5011,3050 !  5010,0000 h@ \ INTS - SETUP_REQ (Clear bit)
    0500 of  zlp>  @val 5011,0000 !  exit       then    \ Set device address
    0680 of  handle-setup  exit                 then    \ Basic usb SETUP handler
    0880 of  usb-state 2+ 2 setup> exit         then    \ Get USB configuration
    0900 of  set-config  exit                   then    \ Set USB configuration
    2021 of  2000 ep0 usb-rcv  zlp>  exit       then    \ Set line coding
    21A1 of  usb-state cell+ cell+ 7 setup>  exit then  \ Get line coding
    2221 of  @val usb-state c!  zlp>  exit      then    \ Set control line state
    2321 of  boot                               then    \ Restart noForth, keep code on BREAK
    drop  stall> ;                                      \ Unkown command send stall

\ Ring buffers for safe character I/O
100         constant #L         \ Must be factor of two
\ 5010,0300   constant BUFFERS    \ Usess 2 * #L + 24 bytes  = 536 bytes
create #RX  ( -- +n )   \ Chars in RX buffer (20)
    5010,0300 ,  here >r
code>  600B3904 ,  681BCA08 ,  CA10C804 ,  FFFF46A7 ,  end-code
create #TX  ( -- +n )   r>  here cell- !  5010,0300 #L + 3 cells + , \ Chars in TX buffer
create >RX  ( c -- )    \ Save char. in RX buffer
    5010,0300 ,  #L 1- ,  code>   here >r
    0015CA84 ,  350C6854 ,  3401552B ,  6054403C ,
    35016815 ,  C9086015 ,  CA10C804 ,  FFFF46A7 ,
end-code
create >TX  ( c -- )   r>  here cell- !  5010,0300 #L +  3 cells + ,  #L 1- , \ Save char to send
create RX>  ( -- c )    \ Read char from RX buffer
    5010,0300 ,  #L 1- ,  code>   here >r
    0015CA84 ,  600B3904 ,  350C6894 ,  34015D2B ,
    6094403C ,  3D016815 ,  C8046015 ,  46A7CA10 ,
end-code
create TX>   ( -- c )   r>  here cell- !  5010,0300 #L +  3 cells + ,  #L 1- , \ Read received char

: USB-KEY?  ( -- f )    pause  #rx ;    \ KEY & EMIT with ringbuffer
: USB-KEY   ( -- c )    begin  pause  #rx until  rx> ;
: USB-EMIT  ( c -- )    begin  pause  #L #tx - until  >tx ;

: ENDPOINTS ( f -- f )  \ Handle used endpoints
    5011,0058 @ >r
    r@ 04 and if  zlp>  then        \ EP1 active?
    r@ 80 and if                    \ EP3 active?
        5010,009C @ FF and ?dup if  \ Characters received?
            ep3 >buf @  swap        \ Yes, place text
            for c@+ >rx  pause  next  20 us
            drop  #L #tx - 40 >     \ Enough space in TX buffer?
            #L #rx - 40 > and if    \ And next RX packet fits too?
                ep3 usb-receive     \ Yes, allow next packet
            else  1-                \ No, change delayed reception flag
            then
        then
    then  r> 5011,0058 ! ;

\ : REQUESTS  ( f -- f )
\    5011,0098 @ >r ( ints )
\    r@    10 and if  endpoints        then   \    10 = dm 04 bitmask
\    r@  1000 and if  bus-reset        then   \  1000 = dm 12 bitmask
\    r> 10000 and if  handle-requests  then ; \ 10000 = dm 16 bitmask
create REQUESTS
    5011,0098 ,  ' endpoints ,  ' bus-reset ,  ' handle-requests ,
code>
    6824CA10 ,  42AC2510 ,  6812D102 ,
    46A7CA10 ,  42AC022D ,  6852D102 ,  46A7CA10 ,
    42AC012D ,  6892D102 ,  46A7CA10 ,  CA10C804 ,
    FFFF46A7 ,  end-code

: HANDLE-USB        ( -- )  \ Handle USB setup & transceiving of chars
    start-usb  false usb-state !  false
    ['] usb-key? to 'key?
    ['] usb-key  to 'key
    ['] usb-emit to 'emit
    begin
        requests  pause
        usb? 103 = if           \ Connected?
            #tx if              \ EP2 Any chars to send?
                ep2 gone? if    \ Yes, previous packet gone?
                    30 us  ep2 >buf @  #tx  40 umin \ Packet place & size
                    2dup ep2 prepare  bounds    \ Init. transmit pointers
                    ?do  tx> i c!  pause  loop  \ Place data in EP-buffer
                    ep2 usb-packet              \ Send to host
                then
            then
            dup if                      \ Delayed reception acknowledge?
                #rx 0=  #tx 0= and  if  \ Yes, wait until #RX and #TX are empty
                    ep3 usb-receive  drop  false \ Allow next packet
                then
            then
        then
    again ;

: READY             ( -- )      \ Free CDC interface after USB setup
    begin  4 us  usb? 3 = until  8 ms  100 usb-state **bis ;

task: USB1      task: USB2      \ The USB tasks
v: extra definitions
: USB-ON            ( -- )
    5010,0300  [ #L 2* 6 cells + ] literal  false fill
    ['] handle-usb  usb1 start-task
    ['] ready       usb2 start-task ;

v: fresh
' usb-on  5 cfg !   \ Fill additional configuration vector
shield USB\  \ freeze
here swap - dm .
