(* I2C slave implementation, base: 468 bytes, plus examples: 740 bytes

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


: COUNTER       ( -- )      \ I2C slave demo
    cr  i2c-on  0  begin
        30 pcf8574> if
            dup .  dup 30 >pcf8574  1+
        else  ." ."  then  20 ms
    key? until  drop ;

*)

hex  here
40044000 value 'I2C     \ I2C0_BASE     I2C register pointer
create I2C   ( -- )
noname
    adr 'i2c ,              \ I2C device pointer
code> 
    tos  sp -) str,         \ 3 - Save TOS
    ip  { tos } ldm,        \ 2 - Read inline data
    w  { w } ldm,           \ 2 - Read I2C pointer
    w  { w } ldm,           \ 2 - Read contents of pointer
    tos w add,              \ 1 - Make I2C register address
    next,                   \ 6
end-code
does>        ( -- )    flyer  compile,  , ; immediate

: I2C0          ( -- )
    03 0C gpio! 03 0D gpio! \ I2C0 on GPIO12 & GPIO13
    4A 0C pads! 4A 0D pads! \ Set GPIO12=SDA & GPIO13=SCL with pull up
    40044000 to 'I2C ;      \ I2C0 register set

: DEVICE-ON     ( mode my-addr -- )
    i2c0                    \ Initialise GPIO12 & GPIO13 for I2C
    1 [ 6C ] i2c  **bic     \ Disable I2C
         [ 8 ] i2c  !       \ Set SAR (slave) address
         [ 0 ] i2c  !       \ Set I2C mode for this device
    1 [ 6C ] i2c  **bis ;   \ Enable I2C

: RESET-FLAGS   ( -- )
    [ 50 ] i2c              \ Clear interrupt registers base
    @+ drop  @ drop ;       \ Clear read request & TX abort

: I2C-READ?     ( -- 0|x )  20 [ 2C ] i2c  bit** ;  \ I2C read request?
: I2C-WRITE?    ( -- 0|x )   8 [ 70 ] i2c  bit** ;  \ I2C write request?
: I2C-DATA      ( -- a )    [ 10 ] i2c ;            \ I2C data register

here over - dm .


: BOOTKEY?  ( -- f )
    2000 4001800C **bis  10 us  \ QSPI pin-SS is input (OEOVER bitfield)
    2 D0000008 bit** 0=         \ Read boot key on QSPI pin-SS
    3000 4001800C **bic ;       \ QSPI pin-SS peripheral function again

: SLAVE         ( -- )          \ Send & receive I2C data on MY address
    84 30 device-on  cr         \ I2C slave on addr. 30 active
    begin
        i2c-read? if                    \ Read request?
            bootkey? FF and  i2c-data ! \ Yes , send data
            50 us  reset-flags          \ wait and clear interrupts
        then
        i2c-write? if                   \ Data received?
            i2c-data @  FF and  3 .r    \ Yes, read data & show it
        then
     key? until  65 30 device-on ;      \ I2C slave off

here swap - dm .
shield I2SLAVE\

\ End
