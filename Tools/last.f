
: LAST\         ( -- )  \ Execute last shield
    ['] noforth\  dup @ swap    \ xt@ adr
    chere over do
        over i @ = if  drop  i  then
    cell +loop  nip
    flyer  postpone literal  postpone execute ; immediate

: SHIELD\       ( -- )  \ Execute last shield
    ['] noforth\  dup @ swap    \ xt@ adr
    chere over do
        over i @ = if  drop  i  then
    cell +loop  nip
    flyer  postpone literal  postpone execute ; immediate


\ End
