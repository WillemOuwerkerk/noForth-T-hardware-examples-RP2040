\ Small character set 5 x 8 pixels (code space ~700 bytes)

hex
v: inside also definitions
: |     ( bitrow -- )
    0  0D parse  8 umin bounds
    do  2*  i c@ ch X =  -  loop  c, ;

\ Small tokens of 5x8 bits
create TINY
| ........      \ Special tokens-1
| ........
| ........
| ........
| ........

| ........
| ........
| .X..XXXX
| ........
| ........

| ........
| .....XXX
| ........
| .....XXX
| ........

| ...X.X..
| .XXXXXXX
| ...X.X..
| .XXXXXXX
| ...X.X..

| ..X..X..
| ..X.X.X.
| .XXXXXXX
| ..X.X.X.
| ...X..X.

| ..X...XX
| ...X..XX
| ....X...
| .XX..X..
| .XX...X.

| ..XX.XX.
| .X..X..X
| .X.X.X.X
| ..X...X.
| .X.X....

| ........
| ........
| .....X.X
| ......XX
| ........

| ........
| ...XXX..
| ..X...X.
| .X.....X
| ........

| ........
| .X.....X
| ..X...X.
| ...XXX..
| ........

| ...X.X..
| ....X...
| ..XXXXX.
| ....X...
| ...X.X..

| ....X...
| ....X...
| ..XXXXX.
| ....X...
| ....X...

| ........
| ........
| .X.X....
| ..XX....
| ........

| ....X...
| ....X...
| ....X...
| ....X...
| ....X...

| ........
| ........
| .XX.....
| .XX.....
| ........

| ..X.....
| ...X....
| ....X...
| .....X..
| ......X.

| ..XXXXX.      \ Numbers & number tokens
| .X.....X
| .X..X..X
| .X.....X
| ..XXXXX.

| ........
| .X....X.
| .XXXXXXX
| .X......
| ........

| .X....X.
| .XX....X
| .X.X...X
| .X..X..X
| .X...XX.

| ..X....X
| .X.....X
| .X...X.X
| .X..X.XX
| ..XX...X

| ...XX...
| ...X.X..
| ...X..X.
| .XXXXXXX
| ...X....

| ..X..XXX
| .X...X.X
| .X...X.X
| .X...X.X
| ..XXX..X

| ..XXXX..
| .X..X.X.
| .X..X..X
| .X..X..X
| ..XX....

| .......X
| .XXX...X
| ....X..X
| .....X.X
| ......XX

| ..XX.XX.
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX.XX.

| .....XX.
| .X..X..X
| .X..X..X
| ..X.X..X
| ...XXXX.

| ........
| ........
| ..XX.XX.
| ..XX.XX.
| ........

| ........
| ........
| .X.X.XX.
| ..XX.XX.
| ........

| ........
| ....X...
| ...X.X..
| ..X...X.
| .X.....X

| ...X.X..
| ...X.X..
| ...X.X..
| ...X.X..
| ...X.X..

| ........
| .X.....X
| ..X...X.
| ...X.X..
| ....X...

| ......X.
| .......X
| .X.X...X
| ....X..X
| .....XX.

| ..XX..X.
| .X..X..X
| .XXXX..X
| .X.....X
| ..XXXXX.

| .XXXXXX.      \ Capitals
| ....X..X
| ....X..X
| ....X..X
| .XXXXXX.

| .XXXXXXX
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX.XX.

| ..XXXXX.
| .X.....X
| .X.....X
| .X.....X
| ..X...X.

| .XXXXXXX
| .X.....X
| .X.....X
| .X.....X
| ..XXXXX.

| .XXXXXXX
| .X..X..X
| .X..X..X
| .X..X..X
| .X.....X

| .XXXXXXX
| ....X..X
| ....X..X
| ....X..X
| .......X

| ..XXXXX.
| .X.....X
| .X..X..X
| .X..X..X
| ..XXX.X.

| .XXXXXXX
| ....X...
| ....X...
| ....X...
| .XXXXXXX

| ........
| .X.....X
| .XXXXXXX
| .X.....X
| ........

| ..XX....
| .X......
| .X.....X
| ..XXXXXX
| .......X

| .XXXXXXX
| ....X...
| ...X.X..
| ..X...X.
| .X.....X

| .XXXXXXX
| .X......
| .X......
| .X......
| .X......

| .XXXXXXX
| ......X.
| ....XX..
| ......X.
| .XXXXXXX

| .XXXXXXX
| ......X.
| .....X..
| ....X...
| .XXXXXXX

| ..XXXXX.
| .X.....X
| .X.....X
| .X.....X
| ..XXXXX.

| .XXXXXXX
| ....X..X
| ....X..X
| ....X..X
| .....XX.

| ..XXXXX.
| .X.....X
| .X.X...X
| ..X....X
| .X.XXXX.

| .XXXXXXX
| ....X..X
| ...XX..X
| ..X.X..X
| .X...XX.

| .X...XX.
| .X..X..X
| .X..X..X
| .X..X..X
| ..XX...X

| .......X
| .......X
| .XXXXXXX
| .......X
| .......X

| ..XXXXXX
| .X......
| .X......
| .X......
| ..XXXXXX

| ...XXXXX
| ..X.....
| .X......
| ..X.....
| ...XXXXX

| ..XXXXXX
| .X......
| ..XXX...
| .X......
| ..XXXXXX

| .XX...XX
| ...X.X..
| ....X...
| ...X.X..
| .XX...XX

| .....XXX
| ....X...
| .XXX....
| ....X...
| .....XXX

| .XX....X
| .X.X...X
| .X..X..X
| .X...X.X
| .X....XX

| ........     \ Special tokens-2
| .XXXXXXX
| .X.....X
| .X.....X
| ........

| ......X.
| .....X..
| ....X...
| ...X....
| ..X.....

| ........
| .X.....X
| .X.....X
| .XXXXXXX
| ........

| .....X..
| ......X.
| .......X
| ......X.
| .....X..

| X.......
| X.......
| X.......
| X.......
| X.......

| ........
| .......X
| ......X.
| .....X..
| ........

| ..X.....     \ Lower case
| .X.X.X..
| .X.X.X..
| .X.X.X..
| .XXXX...

| .XXXXXXX
| .X..X...
| .X...X..
| .X...X..
| ..XXX...

| ..XXX...
| .X...X..
| .X...X..
| .X...X..
| ..X.....

| ..XXX...
| .X...X..
| .X...X..
| .X..X...
| .XXXXXXX

| ..XXX...
| .X.X.X..
| .X.X.X..
| .X.X.X..
| ...XX...

| ....X...
| .XXXXXX.
| ....X..X
| .......X
| ......X.

| ...XX...
| X.X..X..
| X.X..X..
| X.X..X..
| .XXXXX..

| .XXXXXXX
| ....X...
| .....X..
| .....X..
| .XXXX...

| ........
| .X...X..
| .XXXXX.X
| .X......
| ........

| .X......
| X.......
| X....X..
| .XXXXX.X
| ........

| .XXXXXXX
| ...X....
| ..X.X...
| .X...X..
| ........

| ........
| .X.....X
| .XXXXXXX
| .X......
| ........

| .XXXXX..
| .....X..
| ...XX...
| .....X..
| .XXXX...

| .XXXXX..
| ....X...
| .....X..
| .....X..
| .XXXX...

| ..XXX...
| .X...X..
| .X...X..
| .X...X..
| ..XXX...

| XXXXXX..
| ...X.X..
| ...X.X..
| ...X.X..
| ....X...

| ....X...
| ...X.X..
| ...X.X..
| ...XX...
| XXXXXX..

| .XXXXX..
| ....X...
| .....X..
| .....X..
| ....X...

| .X..X...
| .X.X.X..
| .X.X.X..
| .X.X.X..
| ..X.....

| .....X..
| ..XXXXXX
| .X...X..
| .X......
| ..X.....

| ..XXXX..
| .X......
| .X......
| ..X.....
| .XXXXX..

| ...XXX..
| ..X.....
| .X......
| ..X.....
| ...XXX..

| ..XXXX..
| .X......
| ..XX....
| .X......
| ..XXXX..

| .X...X..
| ..X.X...
| ...X....
| ..X.X...
| .X...X..

| ....XX..
| X..X....
| X..X....
| X..X....
| .XXXXX..

| .X...X..
| .XX..X..
| .X.X.X..
| .X..XX..
| .X...X..

| ........     \ Special tokens-3
| ....X...
| ..XX.XX.
| .X.....X
| ........

| ........
| ........
| XXXXXXXX
| ........
| ........

| ........
| .X.....X
| ..XX.XX.
| ....X...
| ........

| ....X...
| .....X..
| ....X...
| ...X....
| ....X...

| ........
| ........
| ........
| ........
| ........
align

0 [if]

: SEMIT   ( +n -- )
    c>n  80 x - dup 6 < if      \ Line full?
        dup &eol  0 y 1+ xy     \ Yes, fill & to next line
    then  drop
    5 * tiny +  ( 6 {data )        \ Go to wanted char
    0  begin
        2dup + c@ >data  1+     \ Display bit row
    dup 5 = until  2drop
    0 >data  x 6 + y xy ;       \ To new char position

[else]

: SEMIT   ( +n -- )
    onscr? 0= if  drop exit  then   \ Offscreen do nothing
    c>n  'x x - dup 6 < if          \ Line full?
        dup 7 &eol                  \ Yes, fill & to next line
        strip? if  2drop exit  then \ Suppress character overflow?
        0 y 8 + 'y over -  07 <
        if  drop  0  then  xy
    then  drop
    4 7 slot  5 * tiny +            \ Set character box, get wanted char
    x y 2>r  5 for                  \ and show it
        r@ to y  count  8 for
            onscr? if dup 1 and >pix then  2/  incr y
        next  drop  incr x
    next  drop  r> r> 6 +  swap xy ;

[then]

v: extra definitions
: SMALL     ['] semit to o-emit ;


\ Example
: SMALLDEMO     ( -- )          \ Display small token set
    small  &page  magenta >lc
    dm 30 8 xy" Egel project"   \ Startup message
    dm 36 18 xy" Characters"
    dm 48 30 xy" by W.O."
    800 ms  &page  0 10 xy  cyan >lc
    80 bl do  i &emit  loop     \ Show character set
    C00 ms  &page  0 8 xy  orange >lc
    8 0 do                      \ Display @ pattern
        0 i 10 * xy  ( new line )
        i 3 and  1+ &spaces
        8 0 do  ch @ &emit  bl &emit  loop
    loop ;

V: fresh
shield SMALL\

\ End
