## Configuration examples

These examples show how to set the RP2040 to several frequencies including moderest overclocking.

- Setting the system clock & switch GPIO pin
- Set the used UART base address
- Setting the baudrate
- Setting input address for S?
- The fifth cell is for noForth t's internal use, it notes
  if noForth t solo or noForth t duo is running

When the changes are correct you may make them permanent by using `FREEZE` (for the booted core) 
or `FREEZE2` for the auxillary core that boots when you type `COLD2`. The current settings will by showed when file [****print-cfg.f****](../Tools/print-cfg.f)
is included.
