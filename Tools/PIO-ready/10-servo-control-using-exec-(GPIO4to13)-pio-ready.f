(* 10 servo pulse width control, W.0. april 2026

    Only 7 PIO instructions are needed 
    The pulse width is from about .5ms to 2.5ms 
    It may be adjusted by a combination of 
    the state machine freqency and the number range
    wich goes from decimal 0 to 96 because of the
    maximum delay of 0 to 31 for each PIO-opcode

    Note that; The PIO opcode table length is set to 32 bytes
    The next size is 64 bytes so when you want more resolution
    for the servo control you may add another PIO opcode to 
    the table below, like this:

    FF01 h,  FF01 h,  EE01 h,           \ Servo 0, 3 PIO opcodes
    FF01 h,  FF01 h,  EE01 h,  FF01 h,  \ Servo 0, 4 PIO opcodes

    Now adjust the table to 64 bytes and change to PIO clock
    in such a way that you get the desired pulse range
    Ofcourse you have to change the word SERVO a little too

clean-pio  decimal          \ Empty code space mirror
0 0 {pio        \ Servo output on GPIO4 etc. on sm-0 & pio-0

    40000 =freq             \ State machine 0 runs on 40kHz
    4 5 =set-pins           \ GPIO4 to GPIO8 for SET
    0 =out-dir              \ Shift OSR to left!

    31 pindirs set,         \ All 5 pins output
    begin,
        wrap-target         \ Begin of wrap loop
            block pull,     \ 1
            16 exec out,    \ 1 + 1 + []
        wrap                \ End
      ONE                   \ Delay
        0 pins set,         \ All outputs off
        9 x set,            \ Wait a while
        begin,
        31 [] x--? until,
    again,                  \ Back to wrap loop
    0 =exec                 \ Jump to start
pio}

1 0 {pio    \ Five more servo's on GPIO9 to GPIO13
    0 clone                 \ Copy SM0 setup
    40000 =freq             \ State machine 1 runs on 40kHz
    9 5 =set-pins           \ GPIO9 to GPIO13 for SET
    0 =out-dir              \ Shift OSR to left!
    0 =exec                 \ Jump to start
pio}
*)

\ need piobase\     ( needs the piobase.f file loaded first )

hex
: PIO-PULSE
    00000000 50200000 ! \ CTRL stop all state machines
    0C350000 502000C8 ! \ SM0 clock divider     0C350000/0C852000
    14000080 502000DC ! \ SM0 pin control
    00040000 502000D0 ! \ SM0 shift control
    00002080 502000CC ! \ SM0 exec. control

    00000006 40014024 ! \ GPIO4 pin setup, etc.
    00000006 4001402C !
    00000006 40014034 !
    00000006 4001403C !
    00000006 40014044 !

    0000E09F 50200048 ! \ 0
    000080A0 5020004C ! \ 1
    000060F0 50200050 ! \ 2

    0000E000 50200054 ! \ 3
    0000E029 50200058 ! \ 4
    00001F45 5020005C ! \ 5
    00000001 50200060 ! \ 6
    00000000 502000D8 ! \ SM0 Jump to start

    0C350000 502000E0 ! \ SM1 clock divider     0C350000
    14000120 502000F4 ! \ SM1 pin control
    00040000 502000E8 ! \ SM1 shift control
    00002080 502000E4 ! \ SM1 exec. control

    00000006 4001404C ! \ GPIO9 pin setup, etc.
    00000006 40014054 !
    00000006 4001405C !
    00000006 40014064 !
    00000006 4001406C !

    00000000 502000F0 ! \ SM1 Jump to start
    00000003 50200000 ! \ Start SM0 & SM1
    00000000 =pio ;
pio-pulse


hex
\ The 16 half-word opcode buffer must be 32-byte aligned!
here 20 mod negate 20 + allot

\ The two opcode buffers (16 half-words) must be 32-byte aligned!
here    \ First 5 servos
    FF01 h,  FF01 h,  EE01 h,   \ Servo 0
    FF02 h,  E102 h,  E102 h,   \ Servo 1
    EC04 h,  E004 h,  E004 h,   \ Servo 2
    FF08 h,  E108 h,  E108 h,   \ Servo 3
    FF10 h,  E110 h,  E110 h,   \ Servo 4
    0003 h,  ( one> )           \ Pause, jump to 3th PIO-opcode
here    \ Next 5 servos
    FF01 h,  FF01 h,  EF01 h,   \ Servo 0
    FF02 h,  E102 h,  E102 h,   \ Servo 1
    EC04 h,  E004 h,  E004 h,   \ Servo 2
    FF08 h,  E108 h,  E108 h,   \ Servo 3
    FF10 h,  E110 h,  E110 h,   \ Servo 4
    0003 h,  ( one> )           \ Pause, jump to 3th PIO-opcode
constant OPCODES2
constant OPCODES1


create RELOAD  10 ,     \ TRANS_COUNT0 reload

(* DMA control & Trigger register
0       = Enable
2:3     = Data size, 0=Byte, 1=Halfword, 2=Word
4       = Incr. read
5       = Incr, write
6:9     = Ring size 1=2, 15=32768
10      = Ring read = 0, write=1
11:14   = Chain to other DMA
15:20   = Transfer request select; 0 to 3A = DREQ, 3B=Timer0, etc.
*)
: START         ( -- )
  reload    5000,0040 !   \ READ_ADDR1      \ DMA 1 & 0 for state machine 0
  5000,001C 5000,0044 !   \ WRITE_ADDR1
  1         5000,0048 !   \ TRANS_COUNT1
  0000,0009 5000,004C !   \ CTRL_TRIG1 (CHAIN=0)
  opcodes1  5000,0000 !   \ READ_ADDR0
  5020,0010 5000,0004 !   \ WRITE_ADDR0
  10        5000,0008 !   \ TRANS_COUNT0
  0000,0955 5000,000C !   \ CTRL_TRIG0 (DREQ=0, Ring=32, CHAIN=1)

  reload    5000,00C0 !   \ READ_ADDR3      \ DMA 3 & 2 for state machine 1
  5000,009C 5000,00C4 !   \ WRITE_ADDR3
  1         5000,00C8 !   \ TRANS_COUNT3
  0000,1009 5000,00CC !   \ CTRL_TRIG3 (CHAIN=2)
  opcodes2  5000,0080 !   \ READ_ADDR2
  5020,0014 5000,0084 !   \ WRITE_ADDR2
  10        5000,0088 !   \ TRANS_COUNT2
  0000,9955 5000,008C ! ; \ CTRL_TRIG2 (DREQ=1, Ring=32, CHAIN=3)


\ Modify the code in the PIO-opcodes array. It calculates
\ the three servo index address. Then it calculates how
\ many opcodes get the maximum delay en sets these. Now
\ it stores the remainder delay and/or zero delays.
: SERVO     ( +n servo -- )     \ valid +n = 13 to 93
    9 umin >r   r@ 6 *  opcodes1 +      \ +n addr     Opcode address 'servo'
    r> 4 >  2 and +  swap               \ addr +n     Correct for pause call
    dm 80 umin  dm 13 +                 \ addr +n+13  Scale servo pulse range
    hx 1F /mod 2>r                      \ addr        Get delay values for opcodes
    r@ for  hx FF over 1+ c!  2 +  next \ addr        Store maximum delays
    2r>  3 swap - for                   \ addr mod    Calc. remainder opc. to adjust
        hx E0 or  over 1+ c!  2 +   0   \ addr 0      Store rest delay or zero delay
    next  2drop ;


\ Small background demo for two servos on GPIO12 & GPIO13
need task
need tasks

task: SERVOS
: MOVES     ( -- )
    begin
        dm 80 0 do 
            i 8 servo
            dm 80 i -  5 umax  9 servo  40 ms
        loop
        dm 80 0 do 
            dm 80 i - 8 servo
            i  5 umax  9 servo  40 ms
        loop
    again ;

: DEMO      ( -- )    pio-pulse  start  ['] moves  servos start-task ;

demo  tasks

\ End ;;;
