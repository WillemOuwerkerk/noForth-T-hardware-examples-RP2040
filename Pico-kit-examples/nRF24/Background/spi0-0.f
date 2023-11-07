(* High level SPI-0 master primitives

    SPI0-ON     ( clk +n -- )       - Activate SPI for port 0
    SPI0-I/O    ( b1 -- b2 )        - Send & receive on spi0
    SPI0-OUT    ( b -- )            - Send on spi0
    SPI0-IN     ( -- b )            - Receive on spi0

    4003C000    - SPI0_BASE
    40040000    - SPI1_BASE
    40014000    - IO_BANK0_BASE

SPI is chapter 4.4 from page 503 ff

SPI0 master

                     GD32VF103
              ^  -----------------
             /|\|              XIN|- Optional 32.768 kHz xtal
              | |                 |
              --|RST          XOUT|- Idem
                |                 |
          IRQ ->|GPIO22     GPIO19|-> Data Out (MOSI0)
                |                 |
           CE <-|GPIO20     GPIO16|<- Data In (MISO0)
                |                 |
          CSN <-|GPIO17     GPIO18|-> Serial Clock Out (CLK0)
                |                 |
          LED <-|GPIO25     GPIO26|-> Power out

*)

v: inside also definitions
hex
: KHZ>          ( khz -- div1 div2 )
    cfg @ dm 1,000 *  swap /                    \ Calculate divisor
    dup FF < if  7E and  0000  exit  then       \ 254 or smaller
    dup 6000 < if  19 /  1800  exit  then       \ 6000 or smaller
    dup dm 64770 < if  FA /  F900  exit  then   \ 64770 or smaller
    ?abort ;    \ Unable to calculate divider settings!

: SPI-MASTER    ( khz -- )
    4003C000 >r             \ Select SPI0 hardware
    khz>  0007 or  r@ !     \ SSPCR0    Clock divisor, 8-bits data, motorola
    2 r@ cell+ **bic        \ SSPCR1    Disable SSE
    2 r@ cell+ !            \ SSPCR1    Synchronous master
    r> 10 + ! ;             \ SSPCPSR   clock prescaler

\ SPI-0 on GPIO 16 to 19  (rx, csn, sck, tx)
: SPI0-ON       ( khz -- )
    1 10 gpio!  5 11 gpio!  \ GPIO16 to 19 for SPI0
    1 12 gpio!  1 13 gpio!
    dm 1000 spi-master ;

: SPI0-I/O      ( b1 -- b2 )
    4003C008 >r
    begin  10 r@ cell+ bit** 0= until  r@ !
    begin  10 r@ cell+ bit** 0= until  r> @ ;

: SPI0-OUT      ( b -- )        spi0-i/o drop ;
: SPI0-IN       ( -- b )        0 spi0-i/o ;

v: fresh

\ End
