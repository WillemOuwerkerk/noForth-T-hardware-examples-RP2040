## PIO example programs ##

- [****My first PIO program****](Bit%20toggle-1%20(GPIO25).f) ; Simple LED flasher on GPIO25
- [****LED flasher & trace output****](Bit%20toggle-2%20(GPIO25&26).f) ; Controllable LED flasher on GPIO25 & GPIO26 using a loop
- [****LED flasher & trace output****](Bit%20toggle-3%20(GPIO25&26).f) ; Controllable LED flasher on GPIO25 & GPIO26 using wrap
- [****LED on/off with a switch****](In&out-1%20(GPIO24&25).f) ; Switch input using the WAIT command for switching a LED
- [****LED on/off with a switch****](In&out-2%20(GPIO24&25%20compact).f) ; Switch input using the MOV command to toggle a LED
- [****LED on/off with a switch****](In&out-3%20(GPIO24&25)%20debounce%20invert.f) ; Switch input using the WAIT & MOV command with debouncing
- [****IRQ for data exchange****](irq-1%20(GPIO24&25)%20loop.f) ; Data exchange between two state machines using loop
- [****IRQ for data exchange****](irq-2%20(GPIO24&25)%20wrap.f) ; Data exchange between two state machines using wrap
- [****Generating frequencies****](music-0%20(GPIO26to29).f) ; Generating four different frequencies from 8Hz to 20kHz with timbre setting
- [****Blink a LED****](on&off-1%20(GPIO24&25)%20pin,%20invert,%20delay.f) ; The LED toggles each 500 ms, using the PIN? function
- [****Toggle a LED on/off****](on&off-2%20(GPIO24&25)%20pin,%20invert,%20delay.f) ; Switch LED on/off using PIN? function
- [****Toggle a LED on/off****](on&off-2%20(GPIO24&25)%20pin,%20invert,%20delay.f) ; Switch LED on/off using PIN? function and the WAIT command
- [****1000Hz PWM, range 0-100****](PWM-1%20(GPIO25&26)%201000Hz,%20100%20range.f) ; 1000 Hz pulse width modulation on GPIO25&26
- [****1000Hz PWM, range 0-200****](PWM-2%20(GPIO25&26)%201000Hz,%20200%20range.f) ; 1000 Hz pulse width modulation on GPIO25&26
- [****1000Hz PWM, range 0-400****](PWM-3%20(GPIO25&26)%201000Hz,%20400%20range.f) ; 1000 Hz pulse width modulation on GPIO25&26
- [****10kHz PWM, range 0-400****](PWM-4%20(GPIO25&26)%2010000Hz,%20400%20range.f) ; 10 kHz pulse width modulation on GPIO25&26
- [****Rotary encoder****](rotary-0%20(GPIO26to28)%20encoder.f) ; Rotary encoder on GPIO26 to GPIO28
- [****SPI-0 driver****](spi-0%20(GPIO26to28)%20125kHz.f) ; Basic 125 kHz SPI-0 driver on GPIO26 to GPIO28
- [****SPI-0 driver****](spi-1%20(GPIO26to28)%20125kHz&20%cs,%20v1.f) ; 125 kHz SPI-0 driver on GPIO26 to GPIO29 with chip select
- [****SPI-0 driver****](spi-2%20(GPIO26to28)%20125kHz&20%cs,%20v2.f) ; 125 kHz SPI-0 driver on GPIO26 to GPIO29 with chip select
- [****SPI-0 driver****](spi-3%20(GPIO26to28)%20250kHz%20&%20cs%20with%20normal%20IO.f) ; 250 kHz SPI-0 driver on GPIO26 to GPIO29 with external chip select
- [****SPI-0 driver****](spi-4%20(GPIO26to28)%20125kHz%20&%20cs%20with%20mulitple%20bytes%20data.f) ; Multi byte 125 kHz SPI-0 driver on GPIO26 to GPIO29 with chip select
- [****SPI-0 driver****](spi-5%20(GPIO26to28)%20250kHz%20&%20cs%20mulitple%20bytes.f) ;  Multi byte 250 kHz SPI-0 driver on GPIO26 to GPIO29 with chip select
- [****UART-0 TX driver****](uart-0,%20TX%20(GPIO26)%20single%20uart%20using%20=baud.f) ; UART0 output at 115k2 baud on GPIO26
- [****Dual UART-0 TX driver****](uart-1,%20TX%20(GPIO26)%20single%20uart%20using%20=baud%20&%20clone.f) ; Dual UART0 output at 115k2 baud & 38K4 baud on GPIO26&27
- [****UART-0 TX & RX driver****](uart-2,%20TX,RX%20(GPIO26&27)%20single%20uart.f) ; UART0 input & output at 115k2 baud on GPIO26&27
- [****UART-0 TX & RX driver****](uart-3,%20TX%20(GPIO26&27)%20with%20chat%20example.f) ; UART0 input & output at 115k2 baud on GPIO26&27 and a chat example
- [****UART-0 TX & RX driver****](uart-4,%20TX,%20RX%20(GPIO26&27)%20replace%20KEY%20&%20EMIT.f) ; UART0 input & output at 460k8 baud on GPIO26&27, replace default KEY & EMIT in noForth t
- [****WS2812B driver & LED flasher****](WS2812%20on%20GPIO23%20&%20flash%20on%20GPIO25.f) ; WS2812B driver on GPIO23 and controlable LED flasher on GPIO25
- [****WS2812B driver****](WS2812%20on%20GPIO23.f) ; WS2812B driver on GPIO23 
- [****WS2812B driver & tracer output****](WS2812%20on%20GPIO23%20&%20trace%20output%20on%20GPIO26.f) ; WS2812B driver on GPIO23 with tracer output on GPIO26
- [****Multiple WS2812B pattern driver****](WS2812%20on%20GPIO23%20&%20multi%20color%20pattern%20driver.f) ; WS2812B driver on GPIO23 and complete multi LED color pattern driver

***
