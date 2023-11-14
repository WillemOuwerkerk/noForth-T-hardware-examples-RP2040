(* I2C temperature measuring temperature with LM75CIM

  AUTHOR      : Willem Ouwerkerk, November 25, 1999
  LAST CHANGE : Willem Ouwerkerk, july 4, 2023, 484/984 bytes
  Added compensation value for the LM75 named #CAL
  Uses a special character 'BA' that displays the degrees sign

*)

hex  here
dm 37 value #CAL    \ Correction value in half degrees please adjust!
: {REGISTER     ( reg +n -- )   4C device!  7 and {i2c-write bus! ; \ Select reg.

: @REG8         ( reg -- b )    \ Read 8-bit register
    1 {register i2c}  1 {i2c-read  bus@ i2c} ;
: @REG16        ( reg -- x )    \ Read 16-bit register
    1 {register i2c}  2 {i2c-read  bus@ bus@ i2c} swap b+b ;
: !REG16        ( t reg -- )    \ Store 16-bit temperature register
    3 {register bus! bus! i2c} ;

\ Temperature is given in half degrees for each bit, where zero
\ is 0 degrees celcius, the range goes from -55 tot 125 degrees.
: TEMPERATURE   ( -- n )            \ Read corrected temperature
    0 @reg16  dup 0F rshift         \ Shift 15 bits to right
    if  true  FFFF xor  or  then    \ Convert sign to systems word width
    7 arshift  #cal + ;             \ And adjust for differences

\ The temperature T needs to be given in whole degrees here
: CONFIGURATION ( b  -- )       1 1 {register i2c} ; \ Set LM75 configuration
: >TEMP         ( t -- tl th )  b-b swap ; \ Convert temperature to two bytes
: LOW-LIMIT     ( t -- )        >temp 2 !reg16 ; \ Set thermostat low boundary
: HIGH-LIMIT    ( t -- )        >temp 3 !reg16 ; \ Set thermostat high boundary

i2c-on \ Activate I2C

here over - .( LM75 basis ) dm .



\ Example programs

\ Show temperature in whole degrees celcius
: .CELCIUS1         ( n -- )
    base @ >r  decimal  2/ 3 .r  BA emit ." C "  r> base ! ;

\ Needs Celsius times ten on the stack to calculate the calibration value
: CALIBRATE         ( celcius*10 -- )
    5 /  0 to #cal  temperature drop
    temperature dup cr ." before" .celcius1
    - to #cal cr ." after " temperature .celcius1 ;

: TEMPERATURE1      ( -- )
    i2c-on
    begin
        cr temperature .celcius1  100 ms
    key? until ;

\ Show temperature in half degrees celsius
: .CELCIUS2         ( n -- )
    base @ >r  decimal
    5 * s>d <# # ch . hold #s #> type  BA emit ." C "
    r> base ! ;

: TEMPERATURE2      ( -- )
    i2c-on
    begin
        cr temperature .celcius2  100 ms
    key? until ;

shield LM75\
here swap - .( LM75 demo ) dm .

\ End ;;;
