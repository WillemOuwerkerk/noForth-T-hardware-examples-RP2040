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
    i2c0                    \ Initialise GPIO12 & GPIO13 for I2C
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

here over - cr .( with I2C extensions ) dm .



\ PCF8574 example
: >PCF8574      ( b dev -- )    device!  1 {i2c-write  bus!} ;
: PCF8574>      ( dev -- b )    device!  1 {i2c-read   bus@} ;

i2c-on
: >LEDS         ( b -- )        invert 21 >pcf8574 ;
: INPUT         ( -- b )        20 pcf8574>  FF xor ;
: BLINK         ( -- )          true >leds 100 ms  false >leds 100 ms ;

v: forth definitions
: RUNNER        ( -- )      \ Show a running light on leds
    i2c-on
    begin
        input 0= if         \ Nothing pressed?
            blink           \ Yes, flash LEDs
        else                \ No, running light
            8 0 do
                i bitmask >leds  input 2* ms
            loop
        then
    key? until  0 >leds ;

: KEYS          ( -- )      \ Show key press on leds
    i2c-on  blink  begin  input >leds  key? until  0 >leds ;



: COUNTER       ( -- )      \ I2C slave demo
    cr  i2c-on  0  begin
        dup .  30 pcf8574> if
            dup 30 >pcf8574  1+
        then  20 ms
    key? until  drop ;

v: inside definitions
: {MADDR        ( ma +n -- )    \ Address buffer
    30 device!  {i2c-write  bus! ;                      \ -addr.

v: extra definitions
\ Byte wide fetch and store in buffer
: NMC@          ( -- b )        1 {i2c-read  bus@ i2c} ; \ Buffer Read next byte
: MC@           ( ma -- b )     1 {maddr i2c}  nmc@ ;    \ Buffer Read byte from address
: MC!           ( b ma -- )     2 {maddr  bus! i2c} ;    \ Buffer Store byte at address
: MC@+          ( ma -- ma+ x ) dup 1+  swap mc@ ;       \ Buffer version of COUNT
: MFILL         ( ma u b -- )   rot rot for  2dup mc!  1+  next  2drop ;

v: forth definitions
: MDMP          ( ma -- )
    hex  i2c-on  begin
        cr  dup 4 u.r ." : "
        dup   10 for  mc@+ 2 .r space  next  ch | emit  \ Show hex
        drop  10 for  mc@+ pchar emit  next             \ Show Ascii
    key bl <> until  drop ;

v: extra definitions
  0100 constant MSIZE       \ RAM buffer size

\ First cell in RAM-buffer is used for MHERE, this way it is always up to date
\ We have to take care manually of the forget action on this address pointer
\ Note that MHERE is initialised at address 1 right behind itself!!
0 constant MDP  1 mdp mc!   \ Define and initialise EHERE
: MHERE         ( -- ma )   mdp mc@ ;               \ RAM dictionary pointer
: MALLOT        ( +n -- )   msize over mhere + u< throw  mdp mc@ + mdp mc! ; \ RAM reserve memory
: MC,           ( b -- )    mhere  1 mallot  mc! ;  \ RAM compile byte
: MCREATE       ( -- ma )   mhere  constant ;       \ RAM named memory

v: extra definitions
: MM,           ( a u -- )  \ Compile string to RAM
    dup 0 ?do  over i + c@  mhere i + mc!  loop \ RAM compile the string a,n
    nip  mdp mc@ +  mdp mc! ;                   \ Increase MDP

: MTYPE         ( ma u -- ) \ RAM type string
    for  mc@+ emit  next  drop ;

mcreate STRING  ( -- ma )       \ Store named string in RAM buffer
: INIT          ( -- )
    1 mdp mc!  s" Forth Works"  dup mc, mm, ;

\ Show stored string from RAM buffer
v: forth definitions
: RAM           ( -- )
    i2c-on
    begin
        cr ." Project "
        string mc@+ mtype
        ."  from RAM"  blink
    key? until ;



\ EEPROM 24C02 example
v: extra definitions
: {EEADDR       ( ea +n -- )    \ Address EEPROM
    52 device!  {i2c-write  bus! ;                      \ 24C02 EE-addr.

\ Byte wide fetch and store in EEPROM
: NEC@          ( -- b )        1 {i2c-read  bus@ i2c} ;    \ EE Read next byte
: EC@           ( ea -- b )     1 {eeaddr i2c}  nec@ ;      \ EE Read byte from address
: EC!           ( b ea -- )     2 {eeaddr  bus! i2c} {poll} ; \ EE Store byte at address
: EC@+          ( ea -- ea+ x ) dup 1+  swap ec@ ;          \ EE version of COUNT

\ Cell wide read and store operators for 24Cxxx EEPROM
: E@            ( ea -- x )      ec@  nec@  b+b ;       \ EE Read word from address
: E@+           ( ea1 -- ea2 x ) dup 2 +  swap e@ ;     \ EE Read word with auto increase
: E!            ( x ea -- )      >r  b-b r@ 1+ ec!  r> ec! ; \ EE Store word at address
: E+!           ( n ea -- )      >r  r@ e@ +  r> e! ;   \ EE Increase contents of address with n

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
: E,            ( x -- )    ehere  2 eallot  e! ;   \ EE 16-bits compile word
: ECREATE       ( -- ea )   ehere  constant ;       \ EE named memory
: EVARIABLE     ( -- ea )   ecreate  2 eallot ;     \ EE 16-bits variable
: EFILL         ( ea u b -- )   rot rot for  2dup ec!  1+  next  2drop ;

v: forth definitions
: EDMP          ( ea -- )
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
: EEPROM        ( -- )
    i2c-on
    begin
        cr ." Project "
        string ec@+ etype
        ."  Works from EEPROM"  blink
    key? until ;




\ Show if a device with address 'dev' is present on the I2C-bus
v: extra definitions
: DEV?          ( dev -- )
    i2c-on  device!  {device-ok?}
    0= if  ." not "  then  ." present " ;



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
' scan-i2c  to app
shield HW-I2C\ \ freeze
cr .( Length with examples )  here swap - dm .

\ End
