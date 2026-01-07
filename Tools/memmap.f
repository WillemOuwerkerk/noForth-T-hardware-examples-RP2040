\ Memory map for noForth t (duo) on rp2040 (idea A.N.)

hex
v: inside also  extra definitions
: U.L ( <i*x> +n -- )
  for  0 du.str dup >r type  0A r> - 0 max spaces  next ;

: MEMMAP    ( -- )  \ Show noForth memory map
    base @ >r  hex
    cr ." ROM:      BOOT      IMAGE     IMAGE-END "
    D000,0000 @ if              \ Second core?
        ."  (Image 2) "
        1000,0100 @  1000,0100 + >r \ End
        r@ ivecs @ +  1000,0000  r> \ End Start
        1000,0000  3
    else
        4 cfg @ if              \ First of dual core?
            ." IMAGE-END2 (DUO)"  1000,0100 >r
            1000,0100 dup @  tuck +  @ + r@ +
            ivecs @ r@ +
            r>  1000,0000  4
        else                    \ No, just single core
            ivecs @ 1000,0100 +  1000,0100  1000,0000  3
        then
    then
    cr dm 10 spaces  u.l  cr cr
    ." RAM:      IVECS     HOT       UHERE ..  ORIGIN    CHERE ..  FLYBUF    (FP)"
    cr dm 10 spaces  fp  flybuf  chere  origin   uhere  hot  ivecs  7 u.l
    cr cr ."           FLYBUF/   R0        S0        TIB       TIB/      RAMBORDER"
    cr dm 10 spaces  ramborder  tib/  tib  s0  r0  flybuf/  6 u.l  cr
    4 cfg @ if cr  ." The second system runs from: " ramborder .  then
    cr ." XRAM:     START     XHERE ..  END"
    cr 0A spaces  xhere FFF or 1+  xhere  xhere FFFFF000 and  3 u.l cr
    r> base ! ;

memmap

: UNUSED    ( -- +n )   border chere - ; \ free dictionary space in ROM
: FREE-RAM  ( -- +n )   origin uhere - ; \ free data space in user RAM

\ Error messages
\ Msg from CHERE? -- dictionary full (in RAM)

v: fresh
memmap
