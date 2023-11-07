## Configuration examples

These examples show how to set the RP2040 to several frequencies including moderest overclocking.

- Setting the system clock
- Choose the used UART (for future use only)
- Setting the baudrate
- Setting the switch input for S?
- The fifth cell is for noForth t's internal use, it notes
  if noForth t or noForth t duo is running

When the changes are correct you may make them permanent by using `FREEZE` (for the booted core) 
or `FREEZE2` for the auxillary core that boots when you type `COLD2`.
