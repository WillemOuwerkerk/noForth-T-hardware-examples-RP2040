<h1 align="center"> USB driver </h1>

A high level implementation of the single port CDC driver.
It is implemented with an absolute minimum of noForth specific
words. So it should be easy to port to other systems.

The whole handler is implemented in the word USB-HANDLER
which is used in the words; USB-KEY? USB-KEY and USB-EMIT
The word USB-ON activates this CDC driver.

