## Pico-kit examples

The [Pico kit is an experimenter board](Pico-kit-v2%20manual.pdf) for the RP2040 Pico boards and clones. It features a number of well-known interfaces. For example, I2C, SPI, switches, LEDs, MOSFET output, Bluetooth, ESP-12F, OLED, etc. It also has two RS232 connections to allow noForth t duo comfortable use.
You can order the board if you like to try it, it comes with the required SMD-components (WS2812B, Mosfet & Schottkey diode) at w.ouwerkerk@kader.hcc.nl
i handle the orders for our local Dutch Forth users group.

***

### Pico-kit PCB
![Pico-kit board tiny](https://github.com/WillemOuwerkerk/noForth-T-hardware-examples-RP2040-/assets/11397265/0e98b048-a09f-4151-aea0-196c64987ae5)

***

- [****I2C slave examples****](I2C-board-examples.f) ; I2C bus scanner & usage examples with an EEPROM and RP2040 slaves
- [****RP2040-hw-i2c-3P.f****](RP2040-hw-i2c-3P.f) ; I2C1 master implementation
- [****blink-0-P.f****](blink-0-P.f) ; Simple blinker using the BOOT-key for escape
- [****blink-1-P.f****](blink-1-P.f) ; Simple blinker using S2 for escape
- [****interrupt-1P.f****](interrupt-1P.f) ; Hardware interrupt using S2
- [****islave-2P.f****](islave-2P.f) ; I2C slave on core-1
- [****pwm-1P.f****](pwm-1P.f) ; PWM driver on GPIO26 with MOSFET output
- [****I2C-OLED****](I2C-OLED/) ; PFW I2C OLED driver with multiple letter sets
- [****nRF24L01P****](nRF24/) ; Basic nRF24L01P driver with carrier wave scanner
- [****Pico-board-configuration****](Pico-board-config/) ; Pico-kit specific configuration file
- [****PIO-examples****](PIO-examples/) ; Pico-kit specific (WS2812B) LED drivers
- [****SPI-OLED****](SPI-OLED/) ; PFW OLED driver with SPI-interface & multiple letter sets

  ***
  ### Pico-kit constructed with nRF24L01P & logical analyzer connected ###
![Pico-kit-met-nRF24](https://github.com/WillemOuwerkerk/noForth-T-hardware-examples-RP2040-/assets/11397265/b3e0bd95-723f-432e-b4ec-f172747ddd9c)
