\ E60b - For noForth C&V 200202: Small character set
\ Small characters 5 x 8 pixels (code space: 692 bytes)

chere
: |     ( bitrow -- )
    0  0D parse  8 umin bounds
    ?do  2*  i c@ ch X =  -  loop  c, ;

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

hex
: SEMIT   ( +n -- )
    c>n  80 x - dup 6 < if      \ Line full?
        dup &eol  0 y 1+ xy     \ Yes, fill & to next line
    then  drop
    5 * tiny +  40 {ol          \ Go to wanted char
    0  begin
        2dup + c@ i2out  1+     \ Display bit row
    dup 5 = until  2drop
    0 ol}  x 6 + y xy ;         \ To new char position

: SMALL     ['] semit to o-emit ;

cr ." Length " chere swap - dm .  ." bytes "

: SMALLDEMO     ( -- )                      \ Display small token set
    display-setup  small  &page
    dm 30 0 xy" Egel project"   \ Startup message
    dm 36 2 xy" Characters" 
    dm 48 4 xy" by W.O." 
    key drop  &page
    bl 60 bounds do  i &emit  loop
    key drop  &page
    80 0 do  ch @ &emit  bl &emit  loop ;

shield SMALL\  freeze

\ End
