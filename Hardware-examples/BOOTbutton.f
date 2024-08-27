(* Read the state of the Bootsel button.
   This one pulls the "Chip Select" wire of the QSPI flash low.

   Disconnects the SPI memory logic, this is in the OEOVER field of the SS-pin,
   waits a little (10us) for the charge to settle, then read the button state
   and finally restore the QSPI state.

More on SIO chapter 2.3.1 page 27 ff
More on IO QSPI bank chapter 2.19.2 page 236/287 ff

*)

hex
: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us  \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=         \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;       \ QSPI pin-SS peripheral function again

\ End
