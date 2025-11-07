<h1 align="center"> USB CDC driver </h1>

This is a in plain Forth written USB CDC driver, that uses a coöperative  multitasker to run on top of noForth t. The picture below shows the finished driver in Windows 10.
This highlevel version shown in the USB-CDC base folder is for documentation only, it is however fully functional!

The folders contain a dual and single CDC-driver using RP2040 assembly too.
The single CDC also contains a CDC driver without code and multitasker for portability purposes.

![USB-drivers](https://github.com/user-attachments/assets/d22d2d55-bdf5-448c-8110-a597fe7b3845)

***

**What do we have to do**

    1. Initialising the USB hardware on the RP2040.
    2. Receiving and responding to setup packets from the host (PC). 
       This determines which driver the OS will load.
    3. If the host is satisfied with the setup, then sending and 
       receiving data packets may start.

***

**In more detail:**

    • The host detects a new device on the USB bus
    • The host issues a USB bus reset command to the new device
        ◦ It also detects what type of USB it is ( 1.10 or 2.00, etc. )
        ◦ Now device 0 is asked for information (what are you?)
        ◦ On Windows and Linux, we then get another USB bus reset
        ◦ Now we are assigned an address, we should start using that 
          address from now on
        ◦ Then the device information is once again requested
        ◦ Then the configuration info (how are you put together?)
        ◦ Now (partly optional) some strings are requested
            ▪ The language you speak in
            ▪ The device that you are
            ▪ The manufacturer
            ▪ The version number of the device
        ◦ Now the requests are getting more specific
            ▪ The UART settings
            ▪ Configuration status
            ▪ The line status ( can there be communication? )
        ◦ On a yes, data can be sent back and forth

Note: Requests and the number of them vary from OS to OS.

***

<img width="1045" height="571" alt="image" src="https://github.com/user-attachments/assets/78d3f146-085c-401f-90a5-cb94b4e07596" />
<h4 align="center">The host detects a new device on the USB bus</h4>

***

Connect a USB to serial cable to GPIO0 & GPIO1, reset noForth.
After noForth is booted, take the following actions.

**Add the CDC driver:**

    1) Load the file: tasker.f
    2) Load the file: USB-XS-005hilevel.f
    3) Type: USB-ON <enter> and ready
    4) To make it permanent type: FREEZE <enter>
       noForth will boot now with this CDC-driver added.

<end>

        
