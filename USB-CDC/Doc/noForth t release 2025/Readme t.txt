Until now we have the following noForth variants:

MSP430          RISC-V  RP2040 (ARM)
____________    ______  ___________________
m       m-      r       t solo      t duo
mv      mv-     rv      tv solo     tv duo
mc      mc-     rc      t# solo     t# duo
mcv     mcv-    rcv     tv# solo    tv# duo

v = with vocabularies
c = compact
- = Low Power" noForth
# = with multitasker

solo = noForth runs only on core-0.
duo  = noForths run on both cores,
       each with its own memory.

Each variant can be expanded with a library and tools.
See the noForth page for more information.
There is also a Github page where all sample files are available.
The USB-CDC driver only runs on the version with multitasker and
can also be loaded from there.

A complete environment with USB, library, and tools is also available for each variant.
