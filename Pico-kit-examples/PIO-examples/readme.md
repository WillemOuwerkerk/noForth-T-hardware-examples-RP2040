## WS2812B driver examples

These examples need a Pico-kit and an YD-RP2040 board that is compatible with a Pico board but has an
WS2812B LED already mounted on the board. The active code runs on one or more state machines using PIO-0.
Before this code can be loaded first the [****PIO-assembler****](..\..\..\tools\PIO-assembler.f) and PIO-disassembler must be loaded.

- [****WS2812 & flash-P.f****](WS2812%20&%20flash-P.f) ; Single WS2812 & LED driver for any Pico (compatible) board
- [****WS2812 & flash-P2.f****](WS2812%20&520flash-P2.f) ; Dual WS2812 & LED driver for an YP-RP2040 board
- [****WS2812-P.f****](WS2812-P.f) ; Single WS2812 & LED driver for any Pico (compatible) board
- [****WS2812-P2.f****](WS2812-P2.f) ; Dual WS2812 & LED driver for an YP-RP2040 board

***
### WS2812 working on YP-RP2040 board ###
![WS2812 driver](https://github.com/WillemOuwerkerk/noForth-T-hardware-examples-RP2040-/assets/11397265/6ef887ac-da08-47f6-af74-f2c98076eaab)
