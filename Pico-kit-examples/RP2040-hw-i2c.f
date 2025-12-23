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
    i2c-on  init
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
