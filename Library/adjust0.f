\ Restore library pointers

v: inside
: ADJUST        ( -- )
    10081000 dup to lib-org  begin  c@+ FF = until  1- to libhere ;

adjust cr .( Library pointers are set: ) lib-org . libhere .

s" CORE\"       find-chapter 1- to hardware)
s" BIT-TOGGLE1" find-chapter 1- to pio)

cr .( Shortcuts HARDWARE & PIO are also set: ) hardware) . pio) .
v: forth
