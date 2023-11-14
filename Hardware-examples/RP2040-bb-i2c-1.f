(* RP2040 bitbang I2C driver for noForth t

    I2C core:        1296 bytes
    with extensions: 1508 bytes
    with examples:   3744 bytes ( PC8574, 24C02 & bus scanner )

GPIO12 = SDA
GPIO13 = SCL

  User words:  I2C-ON  {I2C-WRITE  {I2C-READ   I2C}
               BUS@  BUS!  DEVICE!  {DEVICE-OK?}
  Additional:  {I2C-OUT  {I2C-IN  {POLL}  BUS!}  BUS@}  BUS-MOVE

  An example, first execute I2C-ON  After that the I2C is setup as
  a master. Sent byte 'b' to an I2C device with address 'a'.
    : >SLAVE    ( b a -- )  1 {i2c-write  bus!  i2c} ;
    : >PCF8574  ( b -- )    40 >slave ;

D0000000    SIO_BASE, 04=input, 10=output, 20=output enable
40014004    IO_BANK0_BASE, 300=high, 3000=output, 2000=input ( 8 + )
4001C004    PADS_BANK0_BASE, GPIO0, 5A = Input with pull up ( 4 + )

: T1      ( -- )
    bus D000,0020 **bic \ Outputs off
    bus D000,0010 **bic \ Outputs active low
    begin
        bus D000,0020 **bix  wait \ Toggle outputs on/off
    key? until
    bus D000,0020 **bic ; \ Outputs off

  4A 0c pad  4A 0d pad   t2

*)

hex  here
v: inside  also definitions
40014004 constant GPIO-CTRL \ IO_BANK0_BASE     control register
4001C004 constant PAD-CTRL  \ PADS_BANK0_BASE   pad control registers
D0000004 constant GPIO-IN   \ SIO_BASE          input data register
D0000020 constant GPIO-OEN  \ GPIO_OE           output enable register

0C bitmask constant SDA     \ I2C data line
0D bitmask constant SCL     \ I2C clock line
SCL SDA or constant BUS     \ I2C bus lines

0 value DEV   0 value SUM   0 value NACK?
\ : WAIT          ( -- )      24 for next ;         \ About 100 KHz with 125 MHz clock
  : WAIT          ( -- )      0D for next ;         \ About 200 KHz with 125 MHz clock
\ : WAIT          ( -- )      6 for next ;          \ About 300 KHz with 125 MHz clock
\ : WAIT          ( -- )      noop noop noop ;      \ About 500 KHz with 125 MHz clock

: I2START       ( -- )
    scl gpio-oen **bic  wait
    sda gpio-oen **bis  wait ;

: I2ACK         ( -- )
    scl gpio-oen **bis  sda gpio-oen **bis  wait
    scl gpio-oen **bic  wait ;

: I2NACK        ( -- )
    scl gpio-oen **bis  sda gpio-oen **bic  wait
    scl gpio-oen **bic  wait ;

: I2ACK@        ( -- )
    scl gpio-oen **bis  sda gpio-oen **bic  wait
    scl gpio-oen **bic  wait
    sda gpio-in bit** to nack? ;

v: extra definitions
: BUS!          ( b -- )
    8 for
        scl gpio-oen **bis
        dup 80 and if   sda gpio-oen **bic
        else            sda gpio-oen **bis
        then            wait  2*
        scl gpio-oen **bic  wait
    next  drop  i2ack@ ;

v: inside definitions
: {I2C-ADDR     ( +n -- )       drop  i2start  dev bus! ; \ Start I2C write with address from DEV


\ Higher level I2C access, hides internal details!
v: extra definitions
: I2C-ON        ( -- )
     5 0C gpio!  5 0D gpio! \ Use nomal I/O on GPIO12 & GPIO13
    4A 0C pads! 4A 0D pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    bus  D000,0020 **bic    \ I2C bus inputs at startup (pulled high)
    bus  D000,0010 **bic ;  \ Init. bus outputs to low

: BUS@          ( -- b )
    0  8 for
        2*  scl gpio-oen **bis  sda gpio-oen **bic  wait
        sda gpio-in bit**  0<> 1 and  or
        scl gpio-oen **bic wait
    next
    -1 +to sum
    sum if  i2ack  else  i2nack  then ;

: I2C}          ( -- )
    scl gpio-oen **bis  sda gpio-oen **bis  wait
    scl gpio-oen **bic  wait
    sda gpio-oen **bic ;

: DEVICE!       ( ia -- )   2* FE and  to dev ;
: {DEVICE-OK?}  ( -- f )    0 {i2c-addr  i2c} nack? 0= ; \ 'f' is true when an ACK was received
: {I2C-WRITE    ( +n -- )   {i2c-addr  nack? ?abort ; \ Start I2C write to device in DEV

: {I2C-READ     ( +n -- )     \ Start read from device in DEV
    to sum  i2start  dev 1+ bus!  nack? ?abort ;

here over - cr .( I2C basis ) dm .

\ Waiting for an EEPROM write to succeed is named acknowledge polling.
: {POLL}    ( -- )          begin  {device-ok?} until ;
: {I2C-OUT  ( dev +n -- )   swap  device!  {i2c-write ;
: {I2C-IN   ( dev +n -- )   swap  device!  {i2c-read ;
: BUS!}     ( b -- )        bus!  i2c} ;
: BUS@}     ( -- b )        bus@  i2c} ;
: BUS-MOVE  ( a u -- )      for  c@+ bus!  next  drop ; \ Send string of bytes

here over - cr .( with I2C extensions ) dm .



\ A first demo  PCF8574 output & PCF8574 input
i2c-on
: >PCF8574  ( b dev -- )    device!  1 {i2c-write  bus!  i2c} ;
: >LEDS     ( b -- )        invert 21 >pcf8574 ;
: INPUT     ( -- b )        20 device!  1 {i2c-read  bus@  i2c}  FF xor ;
: BLINK     ( -- )          true >leds 100 ms  false >leds 100 ms ;

v: forth definitions
: RUNNER   ( -- )          \ Show a running light on leds
    i2c-on
    begin
        input 0= if         \ Nothing pressed?
            blink           \ Yes, flash LEDs
        else                \ No, running light
            8 0 do
                i bitmask >leds  input 2* ms
            loop
        then
    key? until  blink ;

: KEYS      ( -- )          \ Show key press on leds
    i2c-on  blink  begin  input >leds  key? until  blink ;



\ EEPROM 24C02
v: extra definitions
: {EEADDR   ( ea +n -- )    \ Address EEPROM
    52 device!  {i2c-write  bus! ;                      \ 24C02 EE-addr.

\ Byte wide fetch and store in EEPROM
: NEC@      ( -- b )        1 {i2c-read  bus@ i2c} ;    \ EE Read next byte
: EC@       ( ea -- b )     1 {eeaddr i2c}  nec@ ;      \ EE Read byte from address
: EC!       ( b ea -- )     2 {eeaddr  bus! i2c} {poll} ; \ EE Store byte at address
: EC@+      ( ea -- ea+ x ) dup 1+  swap ec@ ;          \ EE version of COUNT

\ Cell wide read and store operators for 24Cxxx EEPROM
: E@        ( ea -- x )      ec@  nec@  b+b ;       \ EE Read word from address
: E@+       ( ea1 -- ea2 x ) dup 2 +  swap e@ ;     \ EE Read word with auto increase
: E!        ( x ea -- )      >r  b-b r@ 1+ ec!  r> ec! ; \ EE Store word at address
: E+!       ( n ea -- )      >r  r@ e@ +  r> e! ;   \ EE Increase contents of address with n

\ Example: A forth style memory interface with tools
  i2c-on
  0100 constant EESIZE         \ 24C02

\ First cell in EEPROM is used as EHERE, this way it is always up to date
\ We have to take care manually of the forget action on this address pointer
\ Note that EHERE is initialised at address 2 right behind itself!!
0 constant EDP  2 edp e!    \ Define and initialise EHERE
: EHERE         ( -- ea )   edp e@ ;                \ EE dictionary pointer
: EALLOT        ( +n -- )   eesize over ehere + u< throw  edp e+! ; \ EE reserve memory
: EC,           ( b -- )    ehere  1 eallot  ec! ;  \ EE compile byte
: E,            ( x -- )    ehere  2 eallot  e! ;   \ EE compile word
: ECREATE       ( -- ea )   ehere  constant ;       \ EE named memory
: EVARIABLE     ( -- ea )   ecreate  2 eallot ;
: EFILL         ( ea u b -- )   rot rot for  2dup ec!  1+  next  2drop ;

v: forth definitions
: EDMP      ( ea -- )
    hex  i2c-on  begin
        cr  dup 4 u.r ." : "
        dup   10 for  ec@+ 2 .r space  next  ch | emit  \ Show hex
        drop  10 for  ec@+ pchar emit  next             \ Show Ascii
    key bl <> until  drop ;

v: extra definitions
: EM,           ( a u -- )  \ This version is more carefull on EEPROM wear
    dup 0 ?do  over i + c@  ehere i + ec!  loop \ EE compile the string a,n
    nip  edp e+! ;                              \ Increase EDP

: ETYPE         ( ea u -- ) \ EE type string
    for  ec@+ emit  next  drop ;

ecreate STRING  ( -- ea )       \ Store named string in EEPROM
s" Forth"  dup ec, em,



\ Show stored string from EEPROM
v: forth definitions
: EEPROM    ( -- )
    i2c-on
    begin
        cr ." Project "
        string ec@+ etype
        ."  Works"  blink
    key? until ;



\ Show if a device with address 'dev' is present on the I2C-bus
v: extra definitions
: DEV?          ( dev -- )
    i2c-on  device!  {device-ok?}
    0= if  ." not "  then  ." present " ;


\ Generic implementation of an I2C bus scanner, original J. J. Hoekstra
v: inside definitions
\ I2C bus scanner, after the original sample implementation by J. J. Hoekstra
: .BYTE         ( byte -- )         0 <# # # #> type space ;

: .I2C-HEADER   ( -- )
    cr  8 spaces  10 0 do  i 2 .r space  loop ;

: .I2C-ROW      ( dev -- )
    cr  4 spaces  .byte  8 emit  ." : " ;

: .I2C-DEVICE   ( dev -- )
    dup device!  {device-ok?} if  .byte exit  then  drop ." -- " ;

: FIRST-LINE    ( -- )
    0 .i2c-row ." gc cb db fp hs hs hs hs "
    10 8 do  i .i2c-device  loop ;

: LAST-LINE     ( -- )
    70 .i2c-row   78 70 do  i .i2c-device  loop
    ." sw sw sw sw ?? ?? ?? ??" ;

v: forth definitions
: SCAN-I2C      ( -- )      \ Scan for all valid I2C bus addresses
    i2c-on  base @ >r  hex
    .i2c-header  first-line
    7 1 do
        i 10 *  dup .i2c-row
        10 bounds do  i .i2c-device  loop
    loop
    last-line  r> base ! cr ;

v: fresh
shield BB-I2C\ \ freeze
cr .( Length with examples )  here swap - dm .

\ End ;;;
