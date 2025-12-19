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
v: also inside
: -LITERAL  ( u1 offset -- u2 )  \ Build number from u1 and an offset leaving u2
    flyer  bl-word count number? 0<> ?abort drop  +  postpone literal ;
v: previous

 40048000 constant 'I2C      \ I2C1_BASE     I2C register pointer
 0           value SUM       \ Count of bytes to transmit or receive

: 'I2C   ( "offset" -- )    'i2c  -literal ; immediate

: I2C-ON        ( -- )
    3 0E gpio!  3 0F gpio!  \ I2C1 on GPIO14 & GPIO15
    4A 0E pads! 4A 0F pads! \ Set GPIO14=SDA & GPIO15=SCL with pull up
    1 'i2c 6C **bic         \ Disable I2C
\   dm 500  'i2c 1C !       \ Set high & low clock period (~100kHz)
\   dm 588  'i2c 20 !
\   dm 240  'i2c 1C !       \ Set high & low clock period (~200kHz)
\   dm 294  'i2c 20 !
    dm 075  'i2c 1C !       \ Set high & low clock period (~400kHz)
    dm 163  'i2c 20 !
    dm 12   'i2c A0 !       \ Spike suppressing to 100 ns (7 for high speed)
    0065 'i2c 0 !           \ 7-bit master, fast speed, restart & slave off
    1 'i2c 6C **bis ;       \ Enable I2C

inside also
create DEVICE!  ( dev -- ) ( 96/38 bytes )
    'i2c 0 ,            \ HOP = Address of I2C register base pointer
    400 ,               \ DAY = Generate start byte mask
code>
    w  { hop day } ldm, \ 3 - Read pool
    w  hop movs,        \ 1 - Move I2C base address to W
    sun 1 # movs,       \ 1 - Enable I2C mask
    moon sun mvns,      \ 1 - Invert I2C mask
    moon  w 6C #) str,  \ 2 - Disable I2C
    moon 7F # movs,     \ 1 - 7-bit address mask
    tos moon ands,      \ 1 - Mask device address
    tos day orrs,       \ 1 - Add start bit mask
    tos  w 4 #) str,    \ 2 - Store device address
    sun  w 6C #) str,   \ 2 - Enable I2C
    tos  sp )+ ldr,     \ 3 - Pop TOS
    next,               \ 6
end-code

code {I2C-WRITE     ( +n -- ) ( 52/32 bytes)
(data
    'i2c 0 ,                \ HOP = Address of I2C register base pointer
    adr sum ,               \ DAY = Address of SUM
data)
    w  { hop day } ldm,     \ 3 - Read pool
    w  hop movs,            \ 1 - Move I2C base address to W
    tos  day ) str,         \ 2 - Store byte count in sum
    begin,
        hop  w 70 #) ldr,   \ 2 - Read I2C status
        hop 6 # cmp,        \ 1 - Bus free
    =? until,               \ 1/2
    tos  sp )+ ldr,         \ 3 - Pop TOS
    next,                   \ 6
end-code

code {I2C-READ      ( +n -- )    \ Reuse {i2c-write
    -4 allot  ' {i2c-write >body ,
end-code

routine DATA!)  ( +n -- ) ( 64/38 bytes )
    (data                   \ 4 - Store PC in W & jump over data
        'i2c 0 ,            \ HOP = Address of I2C register base pointer
        adr sum ,           \ DAY = Address of SUM
        200 ,               \ SUN = Generate stop condition mask
    data)
    w { hop day sun } ldm,  \ 4 - Read pool data
    moon  day ) ldr,        \ 2 - Sum to MOON
    moon 1 # subs,          \ 1 - Decrease with one
    moon  day ) str,        \ 2 - Save again
    =? if,                  \ 1/2 - Was it zero?
        tos sun orrs,       \ 1 - Yes, add stop condition to data
    then,
    w  hop movs,            \ 1 - Move I2C base address to W
    tos  w 10 #) str,       \ 2 - Store masked data in buffer
    tos  sp )+ ldr,         \ 3 - Pop TOS
    lr bx,                  \ 2+2 - Return  (25 cycles)
end-code

code BUS!           ( b -- ) ( 80/42 bytes )
    moon FF # movs,
    tos moon ands,
    data!) bl,              \ 25 -
    begin,
        day  w 70 #) ldr,   \ 2 - Read I2C status register
        sun 6 # movs,       \ 1 - SUN = 6
        moon 0 # cmp,       \ 1 - Sum = 0
        =? no if,           \ 1/2 - No,
            sun 21 # adds,  \ 1 - then SUN = 27
        then,
        day sun cmp,        \ 1 - Check status register
    =? until,               \ 1/2 - Equal then data is ready
    next,
end-code

code BUS@           ( -- b ) ( 112/62 bytes )
    tos  sp -) str,         \ 3 - Save TOS
    tos 1 # movs,           \ 1 - Day = 1
    tos 8 # lsls,           \ 1 - DAY = 100
    data!) bl,              \ xx -
    begin,
\ Needs built-in abort on failed read!!
        day  w 70 #) ldr,   \ 2 - Read I2C status register
        sun 0E # movs,      \ 1 - SUN = 0E
        moon 0 # cmp,       \ 1 - Sum = 0
        =? no if,           \ 1/2 - No,
            sun 21 # adds,  \ 1 - then SUN = 2F
        then,
        day sun cmp,        \ 1 - Check status register
    =? until,               \ 1/2 - Equal then data is ready
    tos  sp -) str,         \ 3 - Save TOS
    tos  w 10 #) ldr,       \ 2 - Read received data
    day FF # movs,          \ 1 - Leave byte data only
    tos day ands,           \ 1 -
    next,                   \ 6
end-code

code DATA!          ( +n -- )
    data!) bl,  next,       \ 25+6
end-code

: I2C}  ; immediate

inside
: {DEVICE-OK?}  ( -- f )            \ leave true when address matched a device
    1 {i2c-read  100 data!          \ Start dummy read data with stop condition
    begin
        'i2c 2C @  dup 14 =         \ Device present & ready (ACK)?
        swap 50 =                   \ Device not present or busy (NACK)?
    or until  0A for noop next      \ Wait for response & small delay
    true  'i2c 0 dup 2C + @ 40 and  \ Device not present?
    if    >r  0=  r> 44 +           \ Yes, change flag & correct address
    then  10 + @ drop ;             \ Dummy read on data or abort register


here over - cr .( I2C basis ) dm .


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

here swap - cr .( with I2C extensions ) dm .

v: fresh
shield HW-I2C\ \ freeze
