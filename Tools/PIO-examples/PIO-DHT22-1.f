(* DHT22 sensor, using PIO: 20952 bytes

    40-bits pulse stream 32-bits data & 8-bits checksum

*)

chere   \ Load PIO (dis)assembler first

code ARSHIFT ( a b -- c )   \ Arithmetic right shift
    D9002B20 ,  1D2320 ,  412BC908 , CA10C804 ,  46C046A7 ,
end-code

clean-pio  decimal      \ Empty code space, start at zero
0 0 {pio                \ Use state machine-0 on PIO-0
    160000 =freq        \ On 4 * 40 kHz frequency (6.25 탎 ticks)
    05 1 =out-pins      \ GPIO 5 for OUT & SET
    05 1 =set-pins
    05 =in-pin          \ GPIO 5 for IN & JMP
    05 =jmp-pin
    0 =in-dir           \ Shift left

    0 pindirs set,              \ Pin is input
    wrap-target
        4 [] begin, again,      \ Wait for start command
    one ( Sensor readout )
        1 pindirs set,          \ Pin is output
        3 y set,  begin,        \ Generate start pulse low .8 ms
            31 [] 0 pins set,
        y--? until,
        6 [] 1 pins set,        \ 44 탎 start pulse high

        6 [] 0 pindirs set,     \ Now input, wait 44 탎, skip response low
        6 [] high 0 pin wait,   \ Wait for response high 44 탎

        1 x set,                \ Read 32-bits & 8-bits 6.25 탎
        31 y set,               \ Now read the 32-bits answer 6.25 탎
        begin,
            begin,              \ First the sensor data
                low 0 pin wait,
                5 [] high 0 pin wait, \ Wait for high bit 37.5 탎
                1 pins in,      \ Shift in low or high bit 6.25 탎
            y--? until,         \ Count all 32 bits 6.25 탎)
            push,               \ Result to fifo 6.25 탎
            7 y set,            \ Then 8-bit checksum 6.25 탎
        x--? until,             \ 6.25 탎
    wrap
    0 =exec                     \ Start with wait loop
pio}

: READ) ( -- data chk )
    one> 0 exec-opc             \ Start new measurement
    begin  0 rx-depth 1- until  \ Fifo minimal two deep?
    0 rxf>   0 rxf> ;           \ 32-bits data & 8-bits checksum

: .DHT  ( h -- )                \ Show scaled result
    16 lshift  16 arshift       \ Extend sign bit
    s>d tuck  dabs
    <# # ch . hold #s rot sign #>
    type space ;

: CHKS  ( data -- chks )        \ Calculate checksum
    h-h  b-b +  swap            \ Split & calc. checksum
    b-b +  +  b-b drop ;

: READ  ( -- t h )
    0  begin   read)            \ Read sensor
    over chks <> while          \ Checksum not ok?
        drop  1+                \ Drop DHT22 reading, count retries
        dup 1- ?abort           \ More then one retry, abort
        2000 ms
    repeat  nip  h-h ;          \ Split in temp. & hum.

: DHT22  ( -- )
    base @  decimal
    read  .dht ." %rel, " .dht ." Celcius" \ Show scaled result
    base ! ;

v: fresh
hex
chere swap - dm .
