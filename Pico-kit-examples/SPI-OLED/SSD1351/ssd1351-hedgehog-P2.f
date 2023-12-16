(* Animated hedgehog logo on OLED screen, ~430 Bytes
\ From well known words: MS

: WXY       ( x y -- )          >r  wx +  r> wy +  xy ;

: WXY"      ( x y ccc -- )      \ XY" voor OLED
    flyer  postpone wxy  postpone &" ; immediate
*)

: EGEL      ( x y -- )          \ Print hedgehog at pos x y
    empty                       \ Erase custom characters
    dm 59 0 >cc  dm 52 0 >cc    \ Build four custom characters: p
    dm 58 1 >cc  dm 51 1 >cc    \ q
    dm 53 2 >cc  dm 56 2 >cc  9 2 >cc  \ r
    dm 45 3 >cc  dm 11 3 >cc    \ s
    >r dup r@ 10 + xy" 0000000000W:`8c58050"
       dup r@ 18 + xy" 5700000000o8^^n]WjnXgV0"
       dup r@ 20 + xy" kpigbhhhge;q]^27o6n4[ii0"
       dup r@ 28 + xy" 0036grd700c0ef6hk07335of0"
       dup r@ 30 + xy" 0000000366kbkVk00b3f`46s0"
           r> 38 + xy" 00000000000000000003bf0" ;

: SHOW      ( -- )
    graphic orange >lc  &page  \ Init. and show Hedgehog
    78 0 do
        'x 1+  i 2* - 2 egel  10 ms
    loop  400 ms  &page
    38 00 do
        'x 1+  i 2* - 2 egel  10 ms
    loop
    80 ms  thin
    gray >lc    4 48 xy" Graphic chars"
    C00 ms  &page                           \ Wait then show message
    cyan >lc    4  8 xy" Project Forth"     \ Startup message
    blue  >lc  28 18 xy" Works"             \ To line 2
    green >lc  1A 30 xy" Graphics"          \ To line 4
    yellow >lc 20 40 xy" by W.O."  800 ms ; \ To line 6

: STARTUP   ( -- )
    display-setup  strip
    green >bc  whole  antracit-gray >bc
    7C 7C 2 2 window  show ;

v: fresh
' startup  to app
shield EGEL1\  freeze

\ End ;;;
