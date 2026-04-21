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

*)

\ need pio\     ( Load the pio assembler & disassembler first )

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
\ The 16 half-words opcode buffer must be 32-byte aligned!
here 20 mod negate 20 + allot

\ The two opcode buffers (16 half-words)
here    \ First 5 servos
    FF01 h,  FF01 h,  EE01 h,   \ Servo 0
    FF02 h,  E102 h,  E102 h,   \ Servo 1
    EC04 h,  E004 h,  E004 h,   \ Servo 2
    FF08 h,  E108 h,  E108 h,   \ Servo 3
    FF10 h,  E110 h,  E110 h,   \ Servo 4
    one> h,                     \ Pause
here    \ Next 5 servos
    FF01 h,  FF01 h,  EF01 h,   \ Servo 5
    FF02 h,  E102 h,  E102 h,   \ Servo 6
    EC04 h,  E004 h,  E004 h,   \ Servo 7
    FF08 h,  E108 h,  E108 h,   \ Servo 8
    FF10 h,  E110 h,  E110 h,   \ Servo 9
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
: SET-DMA       ( ctrl cnt wr rd +n -- )    \ Set DMA control registers for DMA +n
    40 *  5000,0000 +  10 bounds do  i !  4 +loop ;

\ DMA0 CTRL = DREQ=0, Ring=32, CHAIN=1
\ DMA1 CTRL = CHAIN=0
\ DMA2 CTRL = DREQ=1, Ring=32, CHAIN=3
\ DMA3 CTRL = CHAIN=2
: START         ( -- )
    0955 10 5020,0010 opcodes1  0 set-dma   \ DMA 0 for state machine 0
    0009 01 5000,001C reload    1 set-dma   \ DMA 1 for state machine 0
    9955 10 5020,0014 opcodes2  2 set-dma ; \ DMA 2 for state machine 1
    1009 01 5000,009C reload    3 set-dma   \ DMA 3 for state machine 1


\ Modify the code in the PIO-opcodes array. It calculates
\ the three servo index address. Then it calculates how
\ many opcodes get the maximum delay en sets these. Now
\ it stores the remainder delay and/or zero delays.
: SERVO     ( +n servo -- )     \ valid +n = 13 to 93
    9 umin >r   r@ 6 *  opcodes1 +      \ +n addr     Address of opcode row for 'servo'
    r> 4 >  2 and +  swap               \ addr +n     Correct for pause call
    dm 80 umin  dm 13 +                 \ addr +n+13  Scale servo pulse range
    hx 1F /mod 2>r                      \ addr        Get delay values for opcodes
    r@ for  hx FF over 1+ c!  2 +  next \ addr        Store maximum delays
    2r>  3 swap - for                   \ addr mod    Calc. remainder opc. to adjust
        hx E0 or  over 1+ c!  2 +   0   \ addr 0      Store mod or zero delay
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

: DEMO      ( -- )    start  ['] moves  servos start-task ;

shield PSERVO\

\ End ;;;
