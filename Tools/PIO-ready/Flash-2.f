(* PIO example program generated with the EXPORT function

For use with the 'mini-PIO.f' base file

FLASH   - LED on GPIO25 flashes
LED-ON  - LED continue on
LED-OFF - LED off
TEMPO   - Uses numbers from 7D0 and higher

*)

hex
: TOGGLE1   \ GPIO-25 LED control
    0000 50200000 !
    1F000 502000CC !
    14000000 502000DC !
    F4240000 502000C8 !
    14000320 502000DC !
    8000320 502000DC !
    0006 400140CC !
    0006 400140D4 !
    E083 50200048 !
    0001 5020004C !
    1F100 502000CC !
    E703 50200050 !
    E75F 50200054 !
    E700 50200058 !
    0784 5020005C !
    5100 502000CC !
    0000 502000D8 !
    0001 50200000 !
    0000 set-pio ;    \ Set PIO address

toggle1

: FLASH    2 0 exec ;      \ Jump to address 2, start flasher
: LED-OFF  1 0 exec  E000 0 exec ;  \ Pin 25 off, jump to wait loop
: LED-ON   1 0 exec  E001 0 exec ;  \ Pin 25 on, jump to wait loop
: TEMPO    7D0 max  0 freq  flash ; \ Change flasher frequency

: START     ( -- )      toggle1  1 ms  flash ;
' start  to app

shield TOGGLE\  ( freeze )
