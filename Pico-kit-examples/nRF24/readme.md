## Driver for the nRF24L01+ and some RF tools ##

The [nRF24L01+](https://www.sparkfun.com/datasheets/Components/SMD/nRF24L01Pluss_Preliminary_Product_Specification_v1_0.pdf) is a cheap 2.4GHz transceiver module with a low level
part of the communication layer already in hardware available.
Features of the nRF24L01+ are, adjustable auto retransmit, RF ACK handshake, a 1 to 32 byte payload 
with variable length (Dynamic Payload), Fifo of 3 deep, 125 selectable frequencies, 
adjustable output power, CRC, etc.   

- [****SPI0 driver****](spi0.f) ; SPI0 driver tailored for the nRF24L01+
- [****nRF24L01+ driver****](basic 24L01dn RP2040 pico-kit.f) ; Dynamic payload driver for the nRF24L01+
- [****Mesh network driver****](mesh%20node%20v4.1rf%20RV-dn-pico-kit.f) ; Mesh network driver for the nRF24L01+
- [****Directory with RF tests****](/Tests) ; Carrier wave scanner, send & receive test, etc.

