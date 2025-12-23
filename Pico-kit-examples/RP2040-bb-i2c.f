(* RP2040 bitbang I2C driver, W.O. 16-10-2025

    I2C core:        1296 bytes
    with extensions: 1508 bytes
    with examples:   3744 bytes ( PC8574, 24C02 & bus scanner )

23-12-2025  Added clock bit stretching & improved bus@

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

0E bitmask constant SDA     \ I2C data line
0F bitmask constant SCL     \ I2C clock line
SCL SDA or constant BUS     \ I2C bus lines

0 value DEV   0 value SUM   0 value NACK?
\ : WAIT          ( -- )      20 for next ; \ About 100 KHz with 125 MHz clock
  : WAIT          ( -- )      0A for next ; \ About 200 KHz with 125 MHz clock
\ : WAIT          ( -- )      4 for next ;  \ About 300 KHz with 125 MHz clock
\ : WAIT          ( -- )      ;             \ About 400 KHz with 125 MHz clock

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
        scl gpio-oen **bic
        begin  scl gpio-in bit** until  \ Clock bit stretching?
        wait
    next  drop  i2ack@ ;

v: inside definitions
: {I2C-ADDR     ( +n -- )       drop  i2start  dev bus! ; \ Start I2C write with address from DEV


\ Higher level I2C access, hides internal details!
v: extra definitions
: I2C-ON        ( -- )
     5 0E gpio!  5 0F gpio! \ Use nomal I/O on GPIO12 & GPIO13
    4A 0E pads! 4A 0F pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    bus  D000,0020 **bic    \ I2C bus inputs at startup (pulled high)
    bus  D000,0010 **bic ;  \ Init. bus outputs to low

: BUS@          ( -- b )
    0  8 for
        2*  scl gpio-oen **bis  sda gpio-oen **bic  wait
        scl gpio-oen **bic
        begin  scl gpio-in bit** until  \ Clock bit stretching?
        sda gpio-in bit**  0<> 1 and or \ Read bit moved to here
        wait
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

v: fresh
shield BB-I2C\ \ freeze
cr .( Length with examples )  here swap - dm .

\ End ;;;
