(* Build-in I2C on standard to fast-mode bus speed for noForth t
                     High level - Code
    I2C core:        1064 bytes -  916
    with extensions: 1268 bytes - 1156
    with examples:   3528 bytes - 3400 ( PC8574, 24C02 & bus scanner )

At 125 MHz one step is 1,000,000,000 / 125,000,000 = 8 ns
So we choose 5000 /8 = 625 eight nanosec. steps
We must set the high & low clock period using this number.

IC_xCNT = (ROUNDUP(MIN_SCL_xxxtime*OSCFREQ,0))

MIN_SCL_HIGHtime =  Minimum High Period
MIN_SCL_HIGHtime =  4000ns for 100kbps = 4000/8 = 500
                    600ns for 400kbps  = 600/8 = 75
                    260ns for 1000kbps = 260/8 = 33

MIN_SCL_LOWtime = Minimum Low Period
MIN_SCL_LOWtime =   4700ns for 100kbps = 4000/8 = 588
                    1300ns for 400kbps = 1300/8 = 163
                    500ns for 1000kbps = 500/8 = 63

OSCFREQ = ic_clk Clock Frequency (Hz).

40044000 I2C0_BASE
40048000 I2C1_BASE

I2C is chapter 4.3 from page 440 ff.
I2C registers from page  465 ff.

00  = IC_CON            Control Register
04  = IC_TAR            Target Address Register
08  = IC_SAR            Slave Address Register
10  = IC_DATA_CMD       Rx/Tx Data Buffer and Command Register
1C  = IC_FS_SCL_HCNT    Fast Mode or Fast Mode Plus I2C Clock
20  = IC_FS_SCL_LCNT
2C  = IC_INTR_STAT      IC_FS_SCL_HCNT
54  = IC_CLR_TX_ABRT    Clear TX abort flag by reading
6C  = IC_ENABLE         Enable Register
70  = IC_STATUS         Status Register
A0  = IC_FS_SPKLEN      Spike suppression (byte)

\ Generic Forth I2C primitives
I2C-ON       ( -- )         enable I2C hardware
{I2C-WRITE   ( +n -- )      open I2C to write +n bytes
{I2C-READ    ( +n -- )      open I2C to read +n bytes
I2C}         ( -- )         close I2C (here it's a dummy)
BUS!         ( b -- )       send b over I2C bus
BUS@         ( -- b )       read b from I2C bus
DEVICE!      ( dev -- )     set active i2c device address
{DEVICE-OK?} ( -- f )       leave true when address matched a device

{POLL}       ( -- )         wait until an ACK is received
{I2C-OUT     ( dev +n -- )  open I2C to write +n bytes to dev
{I2C-IN      ( dev +n -- )  open I2C to read +n bytes from dev
BUS!}        ( b -- )       send b and close
BUS@}        ( -- b )       read b and close
BUS-MOVE     ( a u -- )     send string of +n bytes

*)

hex  here
v: inside  also definitions
40044000 value 'I2C         \ I2C0_BASE     I2C register pointer
0 value SUM                 \ Count of bytes to transmit or receive

\ create I2C   ( -- )
\ noname
\    adr 'i2c ,              \ I2C device pointer
\ code>
\    tos  sp -) str,         \ 3 - Save TOS
\    ip  { tos } ldm,        \ 2 - Read inline data
\    w  { w } ldm,           \ 2 - Read I2C pointer
\    w  { w } ldm,           \ 2 - Read contents of pointer
\    tos w add,              \ 1 - Make I2C register address
\    next,                   \ 6
\ end-code
create I2C      ( -- )
noname
    adr 'i2c ,
code>
    1F09 h,  600B h,  C808 h,  CA04 h,
    CA04 h,  4413 h,  next,
end-code
does>        ( -- )     flyer  compile,  , ; immediate

: BUS?          ( -- )
    10 us  [ 70 ] i2c  @ 2 = ?abort ; \ Abort on not connected bus

: DATA!         ( +n -- )       \ Send data +n
    -1 +to sum  sum 0= 200 and  \ Decrease byte count, Last byte, add
    or  [ 10 ] i2c  ! ;         \ stop condition & send

v: extra definitions        \ I2C basic primitive set
: DEVICE!       ( dev -- )
    1 [ 6C ] i2c  **bic     \ Disable I2C
    7F and 400 or [ 4 ] i2c ! \ Set TARget address
    1 [ 6C ] i2c  **bis ;   \ Enable I2C

: I2C0          ( -- )
    03 0C gpio! 03 0D gpio! \ I2C0 on GPIO12 & GPIO13
    4A 0C pads! 4A 0D pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    40044000 to 'I2C ;      \ I2C0 register set

: I2C1          ( -- )
    03 0E gpio! 03 0F gpio! \ I2C1 on GPIO14 & GPIO15
    4A 0E pads! 4A 0F pads! \ Set GPIO14=SDA & GPIO15=SCL with pull up
    40048000 to 'I2C ;      \ I2C1 register set

: I2C-ON        ( -- )
    i2c1                    \ Initialise GPIO14 & GPIO15 for I2C
    1 [ 6C ] i2c  **bic     \ Disable I2C
\   dm 1100 [ 1C ] i2c  !   \ Set high & low clock period (~50kHz)
\   dm 1300 [ 20 ] i2c  !
\   dm 500  [ 1C ] i2c  !   \ Set high & low clock period (~100kHz)
\   dm 588  [ 20 ] i2c  !
    dm 240  [ 1C ] i2c  !   \ Set high & low clock period (~200kHz)
    dm 294  [ 20 ] i2c  !
\   dm 075  [ 1C ] i2c  !   \ Set high & low clock period (~400kHz)
\   dm 163  [ 20 ] i2c  !   \ Fast mode plus 1MHz clock these are: hi=33, low=63
    dm 12   [ A0 ] i2c  !   \ Spike suppressing to 100 ns (7 for high speed)
    0065 [ 0 ] i2c  !       \ 7-bit master, fast speed, restart & slave off
\   0067 [ 0 ] i2c  !       \ 7-bit master, high speed, restart & slave off
    1 [ 6C ] i2c  **bis ;   \ Enable I2C

: I2C@          ( -- +n )       [ 70 ] i2c  @ ; \ Read I2C status register
: {I2C-WRITE    ( +n -- )       to sum  begin i2c@ 6 = until ; \ Bus free?
: {I2C-READ     ( +n -- )       {i2c-write ;

: BUS!          ( b -- )
    FF and  data!                   \ Send data byte b
    begin   bus?  i2c@
            6  sum if 21 + then     \ Bus ready status or busy status
    = until ;                       \ Ok

: BUS@          ( -- b )
    100 data!                       \ Send dummy byte
    begin   [ 2C ] i2c  @ 50 = ?abort \ Abort on invalid read
            bus?  i2c@
            0E  sum if 21 + then    \ Bus ready or busy
    = until                         \ Wait until data is received
    [ 10 ] i2c  @  FF and ;         \ Read & mask returned data b

\ : .I2C          ( -- )      space  [ 2C ] i2c  @ .  i2c@ . ;
: I2C}          ( -- ) ; immediate  \ Dummy i2c ending
\   ( 8 for  cr .i2c  next ) ;

: {DEVICE-OK?}  ( -- f )            \ leave true when address matched a device
    1 {i2c-read  100 data!  true    \ Start dummy read data with stop condition
    begin
        drop [ 2C ] i2c  @ dup 14 = \ Device present & ready (ACK)?
        over 50 =  or               \ Device not present or busy (NACK)?
    until  14 <>                    \ Device not present?
    if    false [ 54 ] i2c          \ Yes, get abort address
    else  true  [ 10 ] i2c          \ Data register
    then  @ drop ;                  \ Dummy read on data or abort register

here swap - cr .( I2C basis ) dm .


\ Set of additional I2C primitives
\ Waiting for an EEPROM write to succeed is named acknowledge polling with timeout.
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

here over - cr .( with I2C extensions ) dm .

v: fresh
shield HW-I2C\ \ freeze
