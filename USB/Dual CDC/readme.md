<h1 align="center"> dual USB CDC driver </h1>

A compact in low level implemented dual port CDC driver.
It is implemented in three tasks of our coöperative multitasker.
The whole driver only needs 3200 bytes.

    1) Task-1 for the setup stage and input of data
    2) Task-2 does output CDC0 data but only when a connection is live.
    3) Task-3 does output CDC1 data but only when a connection is live.

The word USB-ON activates this CDC driver.

