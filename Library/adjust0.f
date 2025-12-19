\ Restore library pointers

v: inside
: ADJUST        ( -- )
    10081000 dup to lib-org  begin  c@+ FF = until  1- to libhere ;

adjust cr .( Library pointers are set: ) lib-org . libhere .
v: forth
