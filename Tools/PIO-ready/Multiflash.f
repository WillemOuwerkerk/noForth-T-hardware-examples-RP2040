(* PIO example programs generated with the EXPORT function

For use with the 'mini-PIO.f' base file

WS2812  - Changes color all the time
FLASH   - LED on GPIO25 flashes
LED-ON  - LED continue on
LED-OFF - LED off

*)

hex
:  MULTI-FLASH  \ WS2812 on GPIO23 & LED on GPIO-25 & GPIO-26
    0000 50200000 !
    1F000 502000CC !
    14000000 502000DC !
    258000 502000C8 !
    14005C00 502000DC !
    34005C00 502000DC !
    34005EE0 502000DC !
    24005EE0 502000DC !
    0006 400140BC !
    40000 502000D0 !
    E081 50200048 !
    A0E6 5020004C !
    6024 50200050 !
    A027 50200054 !
    0020 50200058 !
    A0C7 5020005C !
    0000 50200060 !
    0027 50200058 !
    E03F 50200064 !
    A0C1 50200068 !
    0009 50200060 !
    E057 5020006C !
    6021 50200070 !
    1020 50200074 !
    1000 50200078 !
    102D 50200074 !
    A021 5020007C !
    100E 50200078 !
    008A 50200080 !
    EF3F 50200084 !
    A0E1 50200088 !
    602C 5020008C !
    A027 50200090 !
    0F53 50200094 !
    0001 50200098 !
    0000 502000D8 !
    0001 50200000 !
    0001 50200000 !
    1F000 502000E4 !
    14000000 502000F4 !
    F4240000 502000E0 !
    14006800 502000F4 !
    34006800 502000F4 !
    4001F000 502000E4 !
    54006800 502000F4 !
    54006B20 502000F4 !
    48006B20 502000F4 !
    0006 400140CC !
    0006 400140D4 !
    E083 5020009C !
    E003 502000A0 !
    0017 502000A4 !
    FF01 502000A8 !
    E75F 502000AC !
    E700 502000B0 !
    079A 502000B4 !
    0018 502000B8 !
    0015 502000F0 !
    0003 50200000 !
    0000 set-pio ;    \ Set PIO address

multi-flash

: FLASH    18 1 exec ;              \ Jump to address 24, start flasher
: LED-OFF  17 1 exec  E000 1 exec ; \ Pin 25 & 26 off, jump to wait loop (address 23)
: LED-ON   17 1 exec  F801 1 exec ; \ Pin 25 & 26 on, jump to wait loop (address 23)

' multi-flash  to app
shield MULTI\   ( freeze )
