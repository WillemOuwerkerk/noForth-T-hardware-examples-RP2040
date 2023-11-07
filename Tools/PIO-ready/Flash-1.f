(* PIO example program generated with the EXPORT function

For use with the 'mini-PIO.f' base file

Starts flashing when it's loaded

*)

hex
: PIO-PROG  ( -- )
    0000 50200000 !
    1F000 502000CC !
    14000000 502000DC !
    F4240000 502000C8 !
    14000320 502000DC !
    8000320 502000DC !
    0006 400140CC !
    0006 400140D4 !
    E083 50200048 !
    E703 5020004C !
    E75F 50200050 !
    E700 50200054 !
    0783 50200058 !
    0001 5020005C !
    0000 502000D8 !
    0001 50200000 !
    0000 set-pio ;

pio-prog

' pio-prog  to app
shield FLASH\  ( freeze )
