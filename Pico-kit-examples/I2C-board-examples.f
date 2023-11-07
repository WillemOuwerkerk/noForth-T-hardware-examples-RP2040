\ PCF8574 example
v: inside also definitions
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
: MFILL         ( ea u b -- )   rot rot for  2dup mc!  1+  next  2drop ;

: MDMP          ( ma -- )
    hex  i2c-on  begin
        cr  dup 4 u.r ." : "
        dup   10 for  mc@+ 2 .r space  next  ch | emit  \ Show hex
        drop  10 for  mc@+ pchar emit  next             \ Show Ascii
    key bl <> until  drop ;



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
v: fresh
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



v: inside also definitions
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
