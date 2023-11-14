(* -------------------------------------------------------------
    Example on how to use low edge pin interrupts on RP2040
    Uses GPIO3 as input & GPIO25 as output
   -------------------------------------------------------------
    E000E100 = NVIC_ISER        Interrupt Set-Enable Register
    400140F0 = IO_BANK0_INTR0   Raw IRQ flags 0 to 7
    40014100 = PROC0_INTE0      Enable edge interrupts
    4001C000 = PADS_BANK0_BASE  Pull up, etc. 5A = pullup
    E000E100 = NVIC_ISER        Enable interrupts in NVIC
    D000001C = GPIO_OUT_XOR     Toggle GPIO register
    D0000020 = GPIO_OE          Set GPIO output enable register
    20000074 = IO IRQ bank 0    IRQ interrupt vector

More on IRQ chapter 2.3.2 page 60 ff
More on NVIC chapter 2.4.5 page 75 ff
More on SIO chapter 2.3.1 page 27 ff
More on IO user bank chapter 2.29 page 235 ff
Select an IO function, see page 240

*)

hex
v: forth definitions
code INT-ON     ( -- )      cpsie,  next, end-code
code INT-OFF    ( -- )      cpsid,  next, end-code  int-off

dm 03 bitmask  9 lshift constant GPIO-IN    \ GPIO3 mask (page 240)
dm 25 bitmask           constant GPIO-OUT   \ GPIO25 mask

: IRQ!      ( a +n -- )         \ Set IRQ vector +n
    1F umin cells  40 +  ivecs +  vec! ;

\ : PIN-IRQ ( -- )
\  800 400140F0 !               \ Clear pin interrupt on GPIO3
\  dm 25 bitmask D000001C ! ;   \ GPIO_OUT_XOR  Toggle GPIO25 (LED) on interrupt
routine PIN-IRQ    ( -- )
    { w hop day lr } push,
    data>   gpio-in ,       \ GPIO3         clear high edge mask
            400140F0 ,      \ INTR0         interupt 0 register
            gpio-out ,      \ GPIO25        bit mask
            D000001C ,      \ GPIO_OUT_XOR  toggle register
    code>
    w  { hop day } ldm,     \ HOP=GPIO3, DAY=Input
    hop  day ) str,         \ Reset GPIO3
    w  { hop day } ldm,     \ HOP=GPIO25, DAY=GPIO_XOR
    hop  day ) str,         \ Toggle GPIO25
    { w hop day pc } pop,
end-code

: IRQ-DEMO  ( -- )
    int-off                     \ Disable interrupts
    gpio-out D0000020 !         \ GPIO_OE        set GPIO25 as output
    5A 3 pads!                  \ GPIO3_CTRL     Enable pull-up
    pin-irq  0D irq!            \ PIN-IRQ to interrupt handler 13: IO IRQ bank 0
    2000 E000E100 !             \ NVIC_ISER      enable IO_BANK0, interrupt 13 in NVIC
    gpio-in 40014100 !          \ PROC0_INTE0    enable low edge interrupt for GPIO3
    gpio-in 400140F0 ! int-on ; \ IO_BANK0_INTR0 interrupt flag cleared & active

irq-demo

\ End