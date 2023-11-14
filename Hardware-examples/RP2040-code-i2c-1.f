(* RP2040 hardware I2C for noForth t

    I2C core:         848 bytes
    with extensions: 1052 bytes
    with examples:   3296 bytes ( PC8574, 24C02 & bus scanner )

I2C is chapter 4.3 from page 440 ff.
I2C registers from page  465 ff.

40044000 I2C0_BASE
40048000 I2C1_BASE

I2C-ON       ( -- )         enable I2C hardware
{I2C-WRITE   ( +n -- )      open I2C to write +n bytes
{I2C-READ    ( +n -- )      open I2C to read +n bytes
I2C}         ( -- )         close I2C (here it's a dummy)
BUS!         ( b -- )       send b over I2C bus
BUS@         ( -- b )       read b from I2C bus
DEVICE!      ( dev -- )     set active I2C device address
{DEVICE-OK?} ( -- f )       leave true when address matched a device

*)

hex  here
 40044000    value 'I2C      \ I2C0_BASE     I2C register pointer
 0           value SUM       \ Count of bytes to transmit or receive
: I2C-ON        ( -- )
    3 0C gpio!  3 0D gpio!  \ I2C0 on GPIO12 & GPIO13
    4A 0C pads! 4A 0D pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    1 'i2c 6C + **bic       \ Disable I2C
    dm 240  'i2c 1C + !     \ Set high & low clock period (~200kHz)
    dm 294  'i2c 20 + !
    dm 12   'i2c A0 + !     \ Spike suppressing to 100 ns (7 for high speed)
    0065 'i2c !             \ 7-bit master, fast speed, restart & slave off
    1 'i2c 6C + **bis ;     \ Enable I2C

inside also
code DEVICE!    ( dev -- ) ( 96/38 bytes )
    adr 'i2c ,          \ HOP = Address of I2C register base pointer
    400 ,               \ DAY = Generate start byte mask
code>
    w  { hop day } ldm, \ 3 - Read pool
    w  hop ) ldr,       \ 2 - Read I2C base address to W
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
data>
    adr 'i2c ,              \ HOP = Address of I2C register base pointer
    adr sum ,               \ DAY = Address of SUM
code>
    w  { hop day } ldm,     \ 3 - Read pool
    w  hop ) ldr,           \ 2 - Read I2C base address to W
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
    data>                   \ 4 - Store PC in W & jump over data
        adr 'i2c ,          \ HOP = Address of I2C register base pointer
        adr sum ,           \ DAY = Address of SUM
        200 ,               \ SUN = Generate stop condition mask
    code>
    w { hop day sun } ldm,  \ 4 - Read pool data
    moon  day ) ldr,        \ 2 - Sum to MOON
    moon 1 # subs,          \ 1 - Decrease with one
    moon  day ) str,        \ 2 - Save again
    =? if,                  \ 1/2 - Was it zero?
        tos sun orrs,       \ 1 - Yes, add stop condition to data
    then,
    w  hop ) ldr,           \ 2 - Read I2C base address to W
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
        'i2c 2C + @  dup 14 =       \ Device present & ready (ACK)?
        swap 50 =                   \ Device not present or busy (NACK)?
    or until  0A for noop next      \ Wait for response & small delay
    true  'i2c dup 2C + @ 40 and    \ Device not present?
    if    >r  0=  r> 44 +           \ Yes, change flag & correct address
    then  10 + @ drop ;             \ Dummy read on data or abort register



here over - cr .( I2C basis ) dm .


\ Set of extra I2C primitives
\ Waiting for an EEPROM write to succeed is named acknowledge polling.
: {POLL}        ( -- )          begin  {device-ok?} until ;
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
    key? until  blink ;

: KEYS          ( -- )      \ Show key press on leds
    i2c-on  blink  begin  input >leds  key? until  blink ;



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
        ."  Works"  blink
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
shield HW-I2C\ \ freeze
.( Length with examples )  here swap - dm .

\ End
