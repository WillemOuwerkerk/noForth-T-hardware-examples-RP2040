(* USB CDC device 2 for second noForth core, 592 bytes

    Willem Jager, Leon Konings & Henny Luijkx did test and document this effort

    5010,0480   = USB state 0, 2 or 3, a 16-bit number
    5010,0484   = Free
    5010,0488   = Ring buffers

Ring buffers:
    cell 0 = Number of bytes in use
    cell 1 = Position where bytes are stored to
    cell 2 = Position where bytes are read from
    cell 3 = Start of circular buffer, size a factor of two

*)

hex  here
v: inside also  definitions
\ Ring buffers for safe character I/O
  100       constant #L         \ Must be factor of two

create #RX1 ( -- +n )                                           \ Chars in RX buffer (20)
    5010,0488  #L 3 cells +  2 * + ,  here >r
code>  600B3904 ,  681BCA08 ,  CA10C804 ,  FFFF46A7 ,  end-code
create #TX1 ( -- +n )   r>  here cell- !                        \ Chars in TX1 buffer
    5010,0488  #L 3 cells +  3 * + ,

create >TX1 ( c -- )   5010,0488 #L 3 cells +  3 * + ,  #L 1- , \ Store char to send
code>
    0015CA84 ,  350C6854 ,  3401552B ,  6054403C ,
    35016815 ,  C9086015 ,  CA10C804 ,  FFFF46A7 ,
end-code
create RX1> ( -- c )   5010,0488 #L 3 cells +  2 * + ,  #L 1- , \ Read received char
code>
    0015CA84 ,  600B3904 ,  350C6894 ,  34015D2B ,
    6094403C ,  3D016815 ,  C8046015 ,  46A7CA10 ,
end-code


(* Using spinlocks

A spinlock is a dedicated memory location that can be used
to protect memory access & hardware devices on a multicore system.
When read zero the address or device is locked, when read non zero
the device is free to use and locked at the same time.
When both cores access the spinlock at the same time core-0 wins.

D0000100    - Spinlock 0

0 yours     - RX spinlock ( 0 mine? )
4 yours     - TX spinlock ( 4 mine? )

*)

create MINE?    ( +n -- s ) \ Leave 1 when spinlock +n is free, 0 when occupied
    D0000100 ,  code> 18E4CA10 ,  C8046823 ,  46A7CA10 ,
end-code
create YOURS    ( +n -- )   \ Free spinlock +n
    D0000100 ,  code> 18E4CA10 ,  6023C908 ,  CA10C804 ,  FFFF46A7 ,
end-code

v: extra definitions
: USB-KEY?  ( -- f )    pause  #rx1 ;   \ Data in receive buffer

: USB-KEY   ( -- c )
    begin  pause  #rx1 until    \ Waiting for data in receive buffer
    begin  pause  0 mine? until \ Waiting for access to be granted?
    rx1>  0 yours ;             \ Read key and free receive buffer

: USB-EMIT  ( c -- )
    begin  pause  #L #tx1 - until   \ Waiting for space in send buffer
    begin  pause  4 mine? until     \ Waiting for access to be granted?
    >tx1  4 yours ;                 \ Put char in ring buffer en free transmit buffee

: USB-ON    ( -- )
    begin  pause  #tx1 0= until  20 ms \ Start with empty ringbuffers
    ['] usb-key? to 'key?
    ['] usb-key  to 'key
    ['] usb-emit to 'emit ;

' usb-on   to &config   \ Fill additional configuration vector
v: fresh
shield CDC1\  \ freeze
here swap - dm .

\ End
