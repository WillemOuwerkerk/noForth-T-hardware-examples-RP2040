(* 10 servo pulse width control, W.0. april 2026

    Only 7 PIO instructions are needed 
    The pulse width is from .7ms to 2.5ms 
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

*)

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


hex
\ The 8-word opcode buffer must be 32-byte aligned!
here 20 mod negate 20 + allot

\ Two times eight words for totally 10 servo's & pause
here    \ First 5 servos
    FF01 h,  FF01 h,  EE01 h,   \ Servo 0
    FF02 h,  E102 h,  E102 h,   \ Servo 1
    EC04 h,  E004 h,  E004 h,   \ Servo 2
    FF08 h,  E108 h,  E108 h,   \ Servo 3
    FF10 h,  E110 h,  E110 h,   \ Servo 4
    one> h,                     \ Pause
here    \ Next 5 servos
    FF01 h,  FF01 h,  EF01 h,   \ Servo 0
    FF02 h,  E102 h,  E102 h,   \ Servo 1
    EC04 h,  E004 h,  E004 h,   \ Servo 2
    FF08 h,  E108 h,  E108 h,   \ Servo 3
    FF10 h,  E110 h,  E110 h,   \ Servo 4
    one> h,                     \ Pause
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
  reload    5000,0040 !   \ READ_ADDR1      \ DMA for state machine 1 & 0
  5000,001C 5000,0044 !   \ WRITE_ADDR1
  1         5000,0048 !   \ TRANS_COUNT1
  0000,0009 5000,004C !   \ CTRL_TRIG1 (CHAIN=0)
  opcodes1  5000,0000 !   \ READ_ADDR0
  5020,0010 5000,0004 !   \ WRITE_ADDR0
  10        5000,0008 !   \ TRANS_COUNT0
  0000,0955 5000,000C !   \ CTRL_TRIG0 (DREQ=0, Ring=32, CHAIN=1)  A45/955

  reload    5000,00C0 !   \ READ_ADDR3      \ DMA for state machine 3 & 2
  5000,009C 5000,00C4 !   \ WRITE_ADDR3
  1         5000,00C8 !   \ TRANS_COUNT3
  0000,1009 5000,00CC !   \ CTRL_TRIG3 (CHAIN=2)
  opcodes2  5000,0080 !   \ READ_ADDR2
  5020,0014 5000,0084 !   \ WRITE_ADDR2
  10        5000,0088 !   \ TRANS_COUNT2
  0000,9955 5000,008C ! ; \ CTRL_TRIG2 (DREQ=1, Ring=32, CHAIN=3) 9A45/9955


\ Modify the code in the PIO-opcodes array
: SERVO     ( +n servo -- )     \ valid +n = 13 to 93
    9 umin >r                           \ +n
    r@ 6 * opcodes1 +                   \ +n addr
    r> 4 >  2 and + swap                \ addr +n
    dm 74 umin  dm 19 +                 \ addr +n+19
    hx 1F /mod >r                       \ addr mod
    r@ 0 ?do
        over i 2* + 1+  hx FF swap c!   \ addr mod
    loop
    swap r@ 2* + swap                   \ addr mod
    3 r> - 0 ?do
        hx E0 or  over i 2* + 1+ c!  0  \ addr 0
    loop  2drop ;


\ Small background demo for two servos on GPIO12 & GPIO13
need task
need tasks

task: SERVOS
: MOVES     ( -- )
    dm 75 0 do 
        i 8 servo
        dm 74 i - 9 servo  40 ms
    loop
    dm 75 0 do 
        i 9 servo
        dm 74 i - 8 servo  40 ms
    loop ;

: RUN       ( -- )    begin  moves  again ;
: DEMO      ( -- )    start  ['] run  servos start-task ;

demo
tasks

\ End ;;;
