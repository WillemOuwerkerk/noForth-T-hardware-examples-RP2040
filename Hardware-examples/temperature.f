(* Small example on how to use the Analog-Digital-Converter W.O. 2023

Celsius conversion routine built by Albert Nijhof
More on ADC chapter 4.9 page 559 ff

*)

hex
4004C000 constant ADC-CS            \ ADC Control and Status
4004C004 constant ADC-RESULT        \ Result of most recent ADC conversion
dm 180   value #CAL                 \ Calibration value, chip dependent

: TEMP          ( -- u )
    3 adc-cs !                      \ Enable ADC and temperature sensor
    begin  100 adc-cs bit** until   \ Wait for READY flag
    4007 adc-cs !                   \ Start conversion on channel 4, temperature sensor
    begin  100 adc-cs bit** until   \ Wait for READY flag
    adc-result @ ;                  \ Fetch conversion result


\ s = in milliVolts
: CELSIUS       ( s -- celcius*100 ) 
    dm 373 dm 100 */ dm 5333 - negate \ Convert measurement to Celcius
    #cal + ; \ Add chip dependent correction value!

: .TEMP         ( -- )
    base @ >r  decimal              \ Show in decimal
    temp dup .  celsius             \ Show raw voltage & convert temperature
    0 <# # # ch , hold #s #> type   \ Print out
    BA emit  ." C "  r> base ! ;

: TEMP-DEMO     ( -- )
    begin  cr .temp  100 ms  key? until ;

\ End
