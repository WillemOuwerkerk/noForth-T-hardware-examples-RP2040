(* High level SPI-0 master primitives

    SPI0-ON     ( clk +n -- )       - Activate SPI for port 0
    SPI0-I/O    ( b1 -- b2 )        - Send & receive on spi0
    SPI0-OUT    ( b -- )            - Send on spi0
    SPI0-IN     ( -- b )            - Receive on spi0
    SPI1-ON     ( clk +n -- )       - Activate SPI for port 1
    SPI1-I/O    ( b1 -- b2 )        - Send & receive on spi1
    SPI1-OUT    ( b -- )            - Send on spi1
    SPI1-IN     ( -- b )            - Receive on spi1
    LOOPBACK    ( f 0|1 -- )        - Enable/disable loopback mode on spi 0 or 1
    I/O         ( m gpio -- )       - Set GPIO-pin to mode m

    4003C000    - SPI0_BASE
    40040000    - SPI1_BASE
    40014000    - IO_BANK0_BASE

SPI is chapter 4.4 from page 503 ff

*)

hex
v: inside also definitions
D0000020 constant GPIO-OE           \ GPIO output enable
D0000010 constant GPIO-OUT          \ GPIO output value

: GPIO-BIT  ( gpio -- msk adr ) bitmask GPIO-OUT ;

: KHZ>          ( khz -- div1 div2 )
    0 cfg @ dm 1,000 *  swap /                  \ Calculate divisor
    dup FF < if  7E and  0000  exit  then       \ 254 or smaller
    dup 6000 < if  19 /  1800  exit  then       \ 6000 or smaller
    dup dm 64770 < if  FA /  F900  exit  then   \ 64770 or smaller
    ?abort ;    \ Unable to calculate divider settings!

: 'SPI          ( 0|1 -- a )    \ Select SPI base address
    1 = 4000 and  4003C000 + ;

: SPI-MASTER    ( khz 0|1 -- )
    'spi >r                 \ Select SPI hardware
    khz>  0007 or  r@ !     \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 r@ cell+ **bic        \ SSPCR1    Disable SSE
    2 r@ cell+ !            \ SSPCR1    Synchronous master
    r> 10 + ! ;             \ SSPCPSR   clock prescaler

\ SPI-0 on GPIO 17 to 19  (rx, csn, sck, tx)
: SPI0-ON       ( khz -- )
    5 11 gpio!              \ GPIO17 to 19 for SPI0
    1 12 gpio!  1 13 gpio!
    0A bitmask GPIO-OE **bis \ Bit-10 is CS
    0B bitmask GPIO-OE **bis \ Bit-11 is DC
    0C bitmask GPIO-OE **bis \ Bit-12 is RES
    0 spi-master ;

: SPI0-OUT      ( b1 -- )
    begin  2 4003C00C bit** until  4003C008 ! ;

: {SPI0         ( -- )          0A GPIO-BIT **bic ;

: SPI0}         ( -- )
    begin  10 4003C00C bit** 0= until \ SPI bus quiet
    begin  04 4003C00C bit** while 4003C008 @ drop  repeat \ Empty RX-fifo
    0A GPIO-BIT **bis ;

v: fresh

\ End
