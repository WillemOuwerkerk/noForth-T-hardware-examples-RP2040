(* CRC32 checksum for RP2040 bootloader, etc.

    • Polynomial:           04C11DB7
    • Input reflection:     no
    • Output reflection:    no
    • Initial value:        FFFFFFFF
    • Final XOR:            00000000

create CRC  ( a1 u -- crc )
    true ,  04C11DB7 ,      \ Start value & polynomial
code>
    day  sp )+ ldr,         \ a1 to DAY
    moon tos mov,           \ u to MOON
    w  { tos hop } ldm,     \ -1 to TOS, polynomial to HOP
    moon day adds,          \ Calc. a1+u=a2 in MOON
    begin,
        sun  day ) ldrb,    \ Read byte using a1
        sun 18 # lsls,      \ Position it on the far left
        tos sun eors,       \ XOR with CRC
        w 8 # movs,         \ Add all 8 bits individually
        begin,
            tos 1 # lsls,   \ Shift CRC left
            cs? if,         \ Bit lost is one?
                tos hop eors, \ Yes, XOR polynomial
            then,
            w 1 # subs,     \ Count bits
        =? until,           \ All done?
        day 1 # adds,       \ Yes, to next byte
        day moon cmp,       \ Test a1 & a2
    =? until,               \ Ready when equal
    next,
end-code

*)

create CRC  ( a1 u -- crc )
 FFFFFFFF ,  04C11DB7 ,
code>
 461FC920 ,  197FCA18 ,  0636782E ,
 22084073 ,  D300005B ,  3A014063 ,
 3501D1FA ,  D1F342BD ,  CA10C804 ,
 FFFF46A7 ,
end-code

\ End
