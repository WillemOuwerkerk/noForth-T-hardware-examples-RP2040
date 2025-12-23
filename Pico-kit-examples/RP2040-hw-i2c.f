(* This I2C example is connected to GPIO14 & GPIO15 for I2C0 and
   to GPIO14 & GPIO15 for I2C1. I2C is chapter 4.3 from page 440 ff.
   Look at Project Forth Works for a detailed description
   https://forth-ev.de/wiki/en:pfw:i2c

    SDA0: 00,04,08,12,16,20
    SDA1: 02,06,10,14,18,26

    Use: Clock pin need I2C
          100   4  need I2C

*)

need [undefined]
need [if]
need -literal

hex  here
v: inside also  definitions
dm 14                       ( Default GPIO14 )
( gpio )    constant SDA
sda 1+      constant SCL
dm 100      constant CLK    ( Default 100 kHz )

cr .( Clock ) clk dm .  .( kHz, SDA ) sda dm .  .( SCL ) scl dm .

sda 2/ 1 and [if]   \ I2C1
40048000 constant 'I2C      \ I2C1_BASE     I2C register pointer
[else]
40044000 constant 'I2C      \ I2C0_BASE     I2C register pointer
[then]
0 value SUM                 \ Count of bytes to transmit or receive

: 'I2C   ( "offset" -- )      'i2c  -literal ; immediate

: BUS?          ( -- )
    10 us  'i2c 70 @ 2 = ?abort ; \ Abort on not connected bus

: DATA!         ( +n -- )       \ Send data +n
    -1 +to sum  sum 0= 200 and  \ Decrease byte count, Last byte, add
    or  'i2c 10 ! ;             \ stop condition & send

v: extra definitions        \ I2C basic primitive set
: DEVICE!       ( dev -- )
    1  'i2c 6C **bic        \ Disable I2C
    7F and 400 or 'i2c 4 !  \ Set TARget address
    1  'i2c 6C **bis ;      \ Enable I2C

: I2C-ON        ( -- )
    03 sda gpio! 03 scl gpio! \ I2C0 on GPIO12 & GPIO13
    4A sda pads! 4A scl pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    1  'i2c 6C **bic        \ Disable I2C
[ clk dm 50 = ] [if]
    dm 1100  'i2c 1C !      \ Set high & low clock period (~50kHz)
    dm 1300  'i2c 20 !
[else]
[ clk dm 200 = ] [if]
    dm 240  'i2c 1C !       \ Set high & low clock period (~200kHz)
    dm 294  'i2c 20 !
[else]
[ clk dm 400 = ] [if]
    dm 075  'i2c 1C !       \ Set high & low clock period (~400kHz)
    dm 163  'i2c 20 !       \ Fast mode plus 1MHz clock these are: hi=33, low=63
[else]
[ clk dm 1000 = ] [if]
    dm 033  'i2c 1C !       \ Set high & low clock period (~400kHz)
    dm 063  'i2c 20 !       \ Fast mode plus 1MHz clock these are: hi=33, low=63
[else]
    dm 500  'i2c 1C !       \ Set high & low clock period (~100kHz)
    dm 588  'i2c 20 !
[then] [then] [then] [then]
    dm 12   'i2c A0 !       \ Spike suppressing to 100 ns (7 for high speed)
    0065    'i2c 0 !        \ 7-bit master, fast speed, restart & slave off
\   0067    'i2c 0 !        \ 7-bit master, high speed, restart & slave off
    1  'i2c 6C **bis ;      \ Enable I2C

: I2C@          ( -- +n )       'i2c 70 @ ; \ Read I2C status register
: {I2C-WRITE    ( +n -- )       to sum  begin i2c@ 6 = until ; \ Bus free?
: {I2C-READ     ( +n -- )       {i2c-write ;

: BUS!          ( b -- )
    FF and  data!                   \ Send data byte b
    begin   bus?  i2c@
            6  sum if 21 + then     \ Bus ready status or busy status
    = until ;                       \ Ok

: BUS@          ( -- b )
    100 data!                       \ Send dummy byte
    begin   'i2c 2C @  50 = ?abort  \ Abort on invalid read
            bus?  i2c@
            0E  sum if 21 + then    \ Bus ready or busy
    = until                         \ Wait until data is received
    'i2c 10 @  FF and ;             \ Read & mask returned data b

: I2C}          ( -- ) ; immediate  \ Dummy i2c ending

: {DEVICE-OK?}  ( -- f )            \ leave true when address matched a device
    1 {i2c-read  100 data!  true    \ Start dummy read data with stop condition
    begin
        drop  'i2c 2C @ dup 14 =    \ Device present & ready (ACK)?
        over 50 =  or               \ Device not present or busy (NACK)?
    until  14 <>                    \ Device not present?
    if    false  'i2c 54            \ Yes, get abort address
    else  true   'i2c 10            \ Data register
    then  @ drop ;                  \ Dummy read on data or abort register

cr .( I2C basis loaded ) here over - dm .

( A set of additional I2C primitives. Waiting for an EEPROM )
( write to succeed is named acknowledge polling with timeout )
: {POLL}        ( -- )
    100  begin
    1- dup while                \ Decrease timeout counter until zero
    {device-ok?} until          \ Not zero, check Ack?
    then  0= ?abort ;           \ Abort when zero

: {I2C-OUT      ( dev +n -- )   swap  device!  {i2c-write ;
: {I2C-IN       ( dev +n -- )   swap  device!  {i2c-read ;
: BUS!}         ( b -- )        bus!  i2c} ;
: BUS@}         ( -- b )        bus@  i2c} ;
: BUS-MOVE      ( a u -- )      for  c@+ bus!  next  drop ; \ Send string of bytes

cr .( with I2C extensions ) here over - dm .

v: fresh
' scan-i2c  to app
shield HW-I2C\ \ freeze
cr .( Length with examples )  here swap - dm .

\ End
