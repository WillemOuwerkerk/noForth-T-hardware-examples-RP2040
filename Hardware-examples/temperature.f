(* Small example on how to use the Analog-Digital-Converter W.O. 2023

Celsius conversion routine built by Albert Nijhof
More on ADC chapter 4.9 page 559 ff

Calibration-value = Given-temperature - Measured-temperature

*)

hex
4004C000 constant ADC-CS            \ ADC Control and Status
4004C004 constant ADC-RESULT        \ Result of most recent ADC conversion
dm 12000 value #CAL                 \ Calibration value, chip dependent

: TEMPERATURE)  ( -- u )
    3 adc-cs !                      \ Enable ADC and temperature sensor
    begin  100 adc-cs bit** until   \ Wait for READY flag
    4007 adc-cs !                   \ Start conversion on channel 4, temperature sensor
    begin  100 adc-cs bit** until   \ Wait for READY flag
    adc-result @ ;                  \ Fetch conversion result


\ s - in milliVolts
\ c - in hundredths of degrees Celsius
: CELSIUS ( s -- c )
    dm 373 dm 100 */ dm 5333 - negate \ Convert measurement to Celsius
    #cal + ; \ Add chip dependent correction value!

: .TEMPERATURE  ( -- )
    base @ >r  decimal              \ Show in decimal
    temperature) dup .  celsius     \ Show raw voltage & convert temperature
    0 <# # # ch , hold #s #> type   \ Print out
    space E4 emit  ." C "  r> base ! ;

: CALIBRATE     ( celsius*100 -- )
    0 to #cal  cr ." Before " .temperature  20 ms \ Uncalibrated temperature
    temperature) celsius -  to #cal        \ Celsius*100 - measured temperature = #CAL
    20 ms  cr ." After  " .temperature ;   \ Calibrated temperature

: TEMPERATURE   ( -- )
    begin  cr .temperature  100 ms  key? until ;

\ End
