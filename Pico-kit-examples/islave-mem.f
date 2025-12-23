(* I2C slave implementation, base: 488 bytes, plus examples: 1020 bytes

40044000 I2C0_BASE
40048000 I2C1_BASE

I2C is chapter 4.3 from page 440 ff.
I2C registers from page  465 ff.

00  = IC_CON            Control Register, slave=84, master=65
04  = IC_TAR            Target Address Register
08  = IC_SAR            Slave Address Register
10  = IC_DATA_CMD       Rx/Tx Data Buffer and Command Register
1C  = IC_FS_SCL_HCNT    Fast Mode or Fast Mode Plus I2C Clock
20  = IC_FS_SCL_LCNT
2C  = IC_INTR_STAT      IC_FS_SCL_HCNT
54  = IC_CLR_TX_ABRT    Clear TX abort flag by reading
6C  = IC_ENABLE         Enable Register
70  = IC_STATUS         Status Register
A0  = IC_FS_SPKLEN      Spike suppression (byte)


: {MADDR        ( ma +n -- )    \ Address buffer
    30 device!  {i2c-write  bus! ;                      \ -addr.

\ Byte wide fetch and store in buffer
: NMC@          ( -- b )        1 {i2c-read  bus@ i2c} ; \ Buffer Read next byte
: MC@           ( ma -- b )     1 {maddr i2c}  nmc@ ;    \ Buffer Read byte from address
: MC!           ( b ma -- )     2 {maddr  bus! i2c} ;    \ Buffer Store byte at address
: MC@+          ( ma -- ma+ x ) dup 1+  swap mc@ ;       \ Buffer version of COUNT
: MFILL         ( ea u b -- )   rot rot for  2dup mc!  1+  next  2drop ;

: MDMP          ( ma -- )
    hex  i2c-on  begin
        cr  dup 4 u.r ." : "
        dup   10 for  mc@+ 2 .r space  next  ch | emit  \ Show hex
        drop  10 for  mc@+ pchar emit  next             \ Show Ascii
    key bl <> until  drop ;

: STRING,       ( a u -- )  \ Store string at start of memory
    dup 0 mc!  0 ?do  dup i + c@  i 1+ mc!  loop  drop ;

*)

hex  here
need -literal

40044000 constant 'I2C  \ I2C0_BASE     I2C0 register pointer
: I2C       ( -- )      'I2C  -literal ; immediate

: I2C0          ( -- )
    03 0C gpio! 03 0D gpio!     \ I2C0 on GPIO12 & GPIO13
    4A 0C pads! 4A 0D pads! ;   \ Set GPIO12=SDA & GPIO12=SCL with pull up

: DEVICE-ON     ( mode my-addr -- )
    i2c0                \ Initialise GPIO12 & GPIO13 for I2C
    1  i2c 6C **bic     \ Disable I2C
    i2c 8 !             \ Set SAR (slave) address
    i2c 0 !             \ Set I2C mode for this device
    1  i2c 6C **bis ;   \ Enable I2C

: RESET-FLAGS   ( -- )          \ Clear interrupt registers base
    i2c 50  @+ drop  @ drop ;   \ Clear read request & TX abort

: READ-QUERY?   ( -- 0|x )  20  i2c 2C  bit** ; \ I2C read request?
: WRITE-QUERY?  ( -- 0|x )   8  i2c 70  bit** ; \ I2C write request?
: I2C-DATA      ( -- a )    i2c 10 ;            \ I2C data register

here over - dm .


create RAM  100 allot       \ Data buffer
0 value MEM                 \ Pointer

: MEM-SLAVE ( -- )                          \ Store & read I2C data on device address
    84 30 device-on  ." on " cr             \ I2C memory slave on address 30 active
    begin  begin
        read-query? if                      \ Read request from me?
            mem c@ i2c-data !               \ Yes, read buffer & send data
            incr mem  reset-flags           \ Increase addr. & clear interrupts
        then
        write-query? while                  \ Handle first write request?
            i2c-data @ FF and  ram + to mem \ Yes, set memory buffer address
            begin   write-query?            \ Wait until the next read or
            read-query?  or until           \ write request was received?
        write-query? until                  \ Handle write request?
        i2c-data @  mem c!  then            \ Yes, fetch data & store in buffer
    key? until   65 30 device-on            \ Exit I2C slave
    cr ." Slave off " ;

here swap - dm .
shield I2MSLAVE\

\ End ;;;
