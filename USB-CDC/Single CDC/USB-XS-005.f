(* USB driver used Leon's & Alex Taradov's code & RP2040 datasheet for documentation
    Henny Luijkx made the overview of Alex's code ( 3200 bytes + 648 for tasker words )
    Willem Jager, Leon Konings & Henny Luijkx did test and document this effort

0000 = R/W, 1000=XOR, 2000=SET, 3000=CLEAR
https://www.beyondlogic.org/usbnutshell/usb1.shtml

This version USB-XS-005 is a compact CDC driver that works with Linux & Windows
using a 1 millisec. line delay and with macOS using character handshake.
*)

hex  here
v: inside also definitions \ USB device data structures
here >r     \ Device descriptor (18 bytes)
12 c, 01 c, 10 c, 01 c, ( 1.10 ) EF c, 02 c, 01 c, 40 c, 66 c, 66 c, ( 6666 )
10 c, 66 c, ( 6610 ) 00 c, 01 c, ( vsn 1.00 ) 00 c, 02 c, 00 c, 01 c,  ( align )
here >r     \ Configuration descriptor (9 or 75 bytes)
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

create USB-STATE  0 ,           \ Hold current USB state: 7 = ready, 107 = functional
        4 c, 3 c, 9 c, 4 c,     \ English/US = language ID
        dm 115200 ,  0 c,  0 c,  8 c,  align  \ Line data: 115k2, Stop bits, Parity, Data bits
                                \ Second half word for 900/880 requests

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
: >CNT      ; immediate         \ 00 - ep0 >cnt !
: >ORG      cell+ ;             \ 04 - ep1 >org @
: >PKT      2 cells + ;         \ 08
: >PID      3 cells + ;         \ 0C
: >ICTRL    4 cells + ;         \ 10
: >OCTRL    5 cells + ;         \ 14
: >EPBUF    6 cells + ;         \ 18
: EP-IN     ( ep -- org buf pkt )   >r  r@ >org @   r@ >epbuf @   r> >pkt @ ;
: PREPARE   ( a u ep -- )           >r  dup r@ >cnt !  40 min r@ >pkt !  r> >org ! ;
: >NEXT     ( ep -- pkt )           >r  r@ >pkt @   r@ >org @  +  r@ >org !
                                    r@ >pkt @  r@ @  over -  dup r@ !  40 min r> >pkt ! ;
: !PKT      ( pkt ep -- ictrl )     >r  r@ >pid @ or  8000 or   \ pid + pkt + mask
                                    r> >ictrl @  tuck ! ;
: PREP-RCV  ( ep -- )               >r r@ >octrl @   r@ >pid @  40 or  over !
                                    2000 r> >pid **bix  400 swap **bis ;
: GONE?     ( ep -- f )             >ictrl @ @ 400 and 0= ;
: USB?      ( -- +n )               usb-state h@ 3 = ;
*)

create >UNI ( a1 u1 -- a2 )     \ Convert string to unicode format for USB (32)
    adr fp ,  300 ,  code>
    6824CA30 ,  C9208025 ,  782F2202 ,  52A73501 ,
    3B013202 ,  7022D1F9 ,  C8040023 ,  46A7CA10 ,  end-code
code >PID       C804330C ,  46A7CA10 ,  end-code
code >EPBUF     C8043318 ,  46A7CA10 ,  end-code
code EP-IN      699D685C ,  3904689B ,  3904600C ,  C804600D ,  46A7CA10 ,  end-code
code PREPARE    601DC920 ,  D9002D40 ,  609D2540 ,
                605DC920 ,  C804C908 ,  46A7CA10 ,  end-code
code >NEXT      685D689C ,  605D192D ,  1B2D681D ,
                2D40601D ,  2540D900 ,  0023609D ,  CA10C804 ,  FFFF46A7 ,  end-code
code !PKT       C92068DC ,  2580432C ,  432C022D ,
                601C691B ,  CA10C804 ,  FFFF46A7 ,  end-code
code PREP-RCV   68DD695C ,  43352640 ,
                26206025 ,  68DF0236 ,  60DF4077 ,  1362640 ,
                60254335 ,  C804C908 ,  46A7CA10 ,  end-code
code GONE?      681B3310 ,  2404681B ,  40230224 ,
                419B3B01 ,  CA10C804 ,  FFFF46A7 ,  end-code
create USB?     usb-state ,  code>  39046812 ,  8813600B ,
                D0002B03 ,  C8042300 ,  46A7CA10 ,  end-code

\ Basic receive & transmit packet handlers
: USB-SEND      ( ep -- )       >r  r@ >next  r@ !pkt  2000 r> >pid **bix  400 swap **bix ;
: USB-RCV       ( pid ep -- )   tuck >pid !  prep-rcv ;

: SETUP>        ( a u -- )      \ Handle the answer for all setup packages
    2000 ep0 >pid !  ep0 prepare                \ Start with DATA1, setup packet data
    begin
        ep0 ep-in move  ep0 usb-send            \ Send packet
        1 5011,0058                             \ Packet gone?
        begin   pause  2dup bit** until  **bis
    ep0 @ 0= until  2000 ep0 usb-rcv ;          \ Handle ZLP

\ : XTABLE        ( tkn a +n -- )        \ USB execution table handler (148)
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

: ZLP>          ( -- )      here false setup> ;             \ Send EP0 ZLP

:noname     me count 1D min >uni  dup c@ @len min setup> ;  \ 0302 Device name string
:noname     usb-state cell+ 4 setup> ;                      \ 0300 Lang-ID string
:noname     [ r> ] literal  @len 4B min setup> ;            \ 0200 Config descriptor
:noname     [ r> ] literal  12 @len min setup> ;            \ 0100 Device descriptor
create HANDLE-SETUP     ( -- )
    0100 ,     0200 ,      0300 ,     0302 ,
    ( dev ) ,  ( conf ) ,  ( 300 ) ,  ( 302 ) ,
does>   ( req a -- )    4 xtable ;

' cold                                       \ 2321 Break, restart noForth t
:noname     @val usb-state c!  zlp> ;        \ 2221 Set control line state
:noname     usb-state cell+ cell+ 7 setup> ; \ 21A1 Get line coding
:noname     2000 ep0 usb-rcv  zlp> ;         \ 2021 Set line coding
:noname     zlp>  @val   usb-state 2 +  h! ; \ 0900 Set USB configuration
:noname     usb-state 2 + 2 setup> ;         \ 0880 Get USB configuration
:noname     @val handle-setup ;              \ 0680 Basic usb SETUP handler
:noname     zlp>  @val 5011,0000 ! ;         \ 0500 Set device address
create HANDLE-REQ
    0500 ,  0680 ,  0880 ,  0900 ,  2021 ,  21A1 ,  2221 ,  2321 ,
    ,       ,       ,       ,       ,       ,       ,       ,
does>   ( a -- )        20000 5011,3050 !  5010,0000 h@  swap  8 xtable ;

100         constant #L         \ Must be factor of two,  ring buffers for safe character I/O
\ 5010,0300   constant BUFFERS  \ Usess 2 * #L + 24 bytes  = 536 bytes

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
create TX>  ( -- c )   r>  here cell- !  5010,0300 #L +  3 cells + ,  #L 1- , \ Read received char

: USB-KEY?  ( -- f )    pause  #rx ;    \ KEY & EMIT with ringbuffer
: USB-KEY   ( -- c )    begin  pause  #rx until  rx> ;
: USB-EMIT  ( c -- )    begin  pause  #L #tx - until  >tx ;

:noname \ BUS-RESET     ( -- )
    80000  5011,3050  !                         \ SIE_STATUS - BUS_RESET (Clear bit)
    false  5011,0000  !  false usb-state !      \ USB-address=0 & USB-state=0, u-config = 0
    false ep3 usb-rcv    false ep2 >pid ! ;  >r \ Allow receiving EP3 & init. transmit EP2
:noname \ ENDPOINTS ( if0 -- if1 ) \ Handle used endpoints
    5011,0058 @
    dup 04 and if  zlp>  then   \ EP1 active?
    dup 5011,0058 !             \ Clear active flags
    80 and  or ;  >r            \ EP3 active, remember
\ : REQUESTS  ( if0 -- if1 )
\    5011,0098 @ >r ( ints )
\    r@    10 and if  endpoints        then   \    10 = dm 04 bitmask
\    r@  1000 and if  bus-reset        then   \  1000 = dm 12 bitmask
\    r> 10000 and if  handle-requests  then ; \ 10000 = dm 16 bitmask
create REQUESTS
    5011,0098 ,  ( endp ) r> ,  ( bus-rst ) r> ,  ' handle-req ,
code>
    6824CA10 ,  42AC2510 ,  6812D102 ,
    46A7CA10 ,  42AC022D ,  6852D102 ,  46A7CA10 ,
    42AC012D ,  6892D102 ,  46A7CA10 ,  CA10C804 ,
    FFFF46A7 ,  end-code

:noname \ START-USB     ( -- )
    1000000  4000C000           \ Bit-24 mask & Reset register
    2dup **bis  2dup **bic      \ Restart USB
    begin  2dup 8 + bit** until \ Wait until USB is ready
    2drop 5010,0000 1000 false fill \ Erase USB ram
    0000,0009  5011,0074 !      \ USB_USB_MUXING    Softcon, to PHY
    0000,000C  5011,0078 !      \ USB_USB_PWR       VBUS overide & detect enable
    0000,0001  5011,0040 !      \ USB_MAIN_CTRl     Enable controller
    2000,0000  5011,004C !      \ USB_SIE_CONTROL   Enable End Point 0 interrupt
    false      5011,0000 !      \ Respond to address 0 on initial setup
    0001,1010  5011,0090 !      \ USB_INTE          Enable 3 interrupts
    AC00,0180  5010,0008 !      \ init COMM endpoint in buffer 1
    A800,0200  5010,0010 !      \ init SEND endpoint in buffer 2
    A800,0280  5010,001C !      \ init RECV endpoint out buffer 3
    0001,0000  5011,204C ! ; >r \ USB_SIE_CONTROL   Enable pull up

:noname \ USB-HANDLER       ( -- )  \ Handle USB setup & receiving of chars
    ( start-usb ) [ r> compile, ]  false usb-state !  false ( if=0 )
    begin
        requests  pause
        dup if                      \ Next RX packet wanted?
            5010,009C c@ >r         \ Data bytes arrived in EP3
            #L #tx - r@ >           \ Yes, enough space in TX buffer?
            #L #rx - r@ > and if    \ And next RX packet fits too?
                ep3 >epbuf @  r@    \ Yes, fill RX buffer
                for  c@+ >rx  next
                20 us  2drop  false \ Done
                ep3 prep-rcv        \ And allow next RX packet
            then  rdrop
        then
    again ;
:noname \ USB-TX            ( -- )
    begin  4 us usb? until  0A ms   \ Connection with driver?
    begin
        begin  pause  usb? until    \ Still connected?
        #tx if                      \ EP2 Any chars to send?
            ep2 gone? if            \ Yes, previous packet gone?
                80 us  ep2 >epbuf @ #tx 40 umin \ Packet place & size
                2dup ep2 prepare  bounds        \ Init. transmit pointers
                ?do  tx> i c!  loop             \ Place data in EP2-buffer
                ep2 usb-send                    \ Send to host
            then
        then
    again ;  >r >r

task: USB1      task: USB2      \ The USB tasks
v: extra definitions
: USB-ON            ( -- )
    ( ['] usb-handler ) [ r> ] literal  usb1 start-task
    ( ['] usb-tx )      [ r> ] literal  usb2 start-task ;

' usb-on  to &config \ Fill configuration vector
v: fresh
shield CDC\  \ freeze
here swap - dm .

v: inside
: USB   ( -- )  \ Install terminal-i/O vectors
    ['] usb-key?    to 'key?
    ['] usb-key     to 'key
    ['] usb-emit    to 'emit ;
v: fresh

usb-on  usb  cdc\  ( Initialise CDC-driver & remove the word USB )

