<h1 align="center"> Single USB CDC driver </h1>

A compact in low level implemented single port CDC driver.
It is implemented in two tasks of our coöperative multitasker.
The whole driver only needs 3200 bytes.

    1) Task-1 for the setup stage and input of data
    2) Task-2 does output data but only when a connection is live.

The word USB-ON activates this CDC driver.

***

Connect a USB to serial cable to GPIO0 & GPIO1, reset noForth.
After noForth is booted, take the following actions.

**Add the CDC driver:**

    1) Load the file: tasker.f
    2) Load the file: USB-XS-005.f
    3) Type: USB-ON <enter> and ready
    4) To make it permanent type: FREEZE <enter>
       Restart noForth with USB by typing: COLD
