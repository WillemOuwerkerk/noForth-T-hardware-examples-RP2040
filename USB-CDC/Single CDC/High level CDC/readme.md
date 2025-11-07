<h1 align="center"> High level Forth USB CDC driver </h1>

A Forth implementation of the CDC driver. It is implemented with an absolute minimum of noForth-specific words, no machine code and no multitasker. It could therefore be easily transferred to other systems.

The entire handler is implemented in the word USB-HANDLER
which in turn is used in the words USB-KEY? USB-KEY and USB-EMIT
The word USB-ON activates this CDC driver.

***
**Add the CDC driver:**

    1) Load the file: USB-XS-005hi-barebone.f
    2) Type: USB-ON <enter> and ready
    3) To make it permanent type: FREEZE <enter>
