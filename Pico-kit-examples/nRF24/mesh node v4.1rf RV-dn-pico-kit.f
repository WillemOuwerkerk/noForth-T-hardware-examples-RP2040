(*     **** Mesh network implementation ****

    ***
        Update-1, using NON? in >DEST and >NODE and HANDLER)
        using CATCH on the HANDLER) and changed SCANX to
        work with any RF-setting
    ***
        Update-2, add RF-settings behind shield
    ***
        Update-3, remove & add unstable node to keep
        the network as fast as possible.
    ***
        Update-4, Add extra RF-data to SETRF and change
        data address in >PAYLOAD & ADD-CONN was 6 'PAY now 5 'PAY
        New version of REGISTER with ask number!!
        Changed READ-RX & XEMIT? and ORG redefined as 2 PAY>
        Refactored !HOP & HOP) is now !HOPS
        Rewitten .STATUS to print real values
        Added REGISTER function to MESH core!
    ***
        Update-5, added trace info for suppressing & releasing nodes
        Changed <MS> to <WAIT>, etc.
        Corrected notation of faulty node when doing indirect access
    ***
        Update-6, integrate dynamic payload
    ***
        Update-7, Risc-V version
    ***
        Update-8, New dynamic payload & rf-error handling implementation
                  Also >F is fixed by repairing READ-DRX?
    ***
        Update-9, Changed XEMIT & XKEY layout. Suppress failed XKEY
                  in (HANDLER) Increased node speed
    ***
        Update-10, Taken improved structure from minimal version.
                  Shrinked: SETRF  <WAIT>  <GIVE-NO.  REGISTER>  GET-NO.
                  Improved: NEXT?  MSTIMER  REGISTER
    ***

                                         1st         2nd   Current
        basic 24L01dn G2553-01b:         1464 bytes (1520) (1568) SPI & small tools
        Mesh node 4.2d:                  2320 bytes (2666) (3170)
        Total:                           3784 bytes (4186) (4738)
        Free with use of small tools:    3728 bytes (3316) (2760)
        Free RAM:                         140 bytes  (130)   (66)
        With BUILD & demo routines free: ROM=...., RAM=..

Dynamic payload format from 1 to 32 bytes:
|   0   |  1  |  2  |    3   |  4  |  5 to 31   |
|-------|-----|-----|--------|-----|------------|
|Command|Dest.|Orig.|Sub node|Admin|d00| to |d1A|

0 pay>  = Command for destination      1 pay>       = Destination node
2 pay>  = Origin node                  3 pay>       = Address of sub node
4 pay>  = Administration byte          5 to 31 pay> = Data 0x1A (#26) bytes

*)

hex  inside also  definitions   \ Defining this node
 1 constant #TYPE         \ I am a power switch
 0 constant #SUB          \ I contain +n sub nodes
10 constant #N            \ Max. number of nodes used
#n 10 /mod swap 0 > abs + \ Calculate half words for table
2* constant #MAP          \ Convert to byte size of bitmap

\ EXEC handles execution tables, it needs the table address on the
\ stack. Note that, all data needs te be cell aligned. The last command
\ token is always -1 and ERR-XT is then the error recovery routine.
\ Like: CREATE EXEC-TABLE  C0 ,  XT0 ,  C1 , XT1  ...  -1 , ERR-XT ,
\ c = command token, exec-table = start address of execution table
: EXEC      ( c exec-table -- ?? )
    swap >r                 \ Save char
    begin
        dup @ -1 <> while   \ Not at end of table?
        r@ over @ = >r      \ Yes, char found?
        r@ 0= if 2 cells + then \ No, to next item
    r> until                \ Found?
    then  rdrop             \ Drop char
    cell+ @ execute ;       \ Execute token

: LOC       ( node a -- bit halfword-addr ) \ Bit location in byte-addr
    over 4 rshift 2*        \ Convert to half word addresses
    #map 1- and +  >r       \ Mask overflow and make halfword address
    0F and 1 swap lshift  r> ; \ Convert low nibble to bit mask

\ Node data tables
create USER     #map allot  \ Working BIT-table for APP programmer only!

create WORK     #map allot  \ Scratch BIT-table for internal use
create ALL      #map allot  \ BIT-table with all found nodes
create DIRECT   #map allot  \ BIT-table with direct accessable nodes
create INDIRECT #map allot  \ BIT-table with indirect accessable nodes
create RF-ERROR #map allot  \ Bit-table with failed nodes
create TYPES    #n allot    \ Table with node-types
create HOPS     #n allot    \ Table with hopping nodes

: *ZERO ( a -- )        #map 0 fill ; \ Erase bit-map a
: *SET  ( node a -- )   loc *bis ; \ Add node to a
: *CLR  ( node a -- )   loc *bic ; \ Remove node from a
: GET*  ( node a -- b ) loc bit* ; \ Node present in a?
: >USER     ( a -- )    user #map move ;        \ Copy nodes to node accu for app programmer
: >WORK     ( a -- )    work #map move ;        \ Copy node for internal use only

: COUNT*    ( a -- +n ) \ Leave number of nodes found in a bitmap
    0  #n 0 ?do
        over i swap get* \ Node present?
        if  1+  then    \ Add 1 when found
    loop  nip ;

\ Leave node number of the first used node in bitmap & erase it
: NEXT?     ( a -- false | node true )
    #n 0 ?do            \ Test all bits
        i over get* if  \ Node bit set?
            i swap *clr  i true unloop exit
        then
    loop  drop  false ;  \ Nothing found


\ Basic control values
0 value STOP?     \ Is -1 for stopping programs
0 value ON?       \ Switch On/Off
0 value PWR       \ nRF24 scan TX-power
#len 5 - constant #B \ Databuffer size in payload

: ORG>      ( -- node ) 2 pay> ;
: .DB       ( +n -- )   3 and  -3 +  6 * .  ." db" ;
: .BITRATE  ( +n -- )   ?dup 0= if ." 250 kBit " exit then . ." Mbit, " ;

v: extra definitions
: .STATUS   ( -- )
    base @ >r  decimal
    cr ." Node v 4.1e nr: "     \ Show node vsn
    #me . ."  nRF24 "           \ Which node with nRf24
    7 nrf@ ?dup if              \ nRF24 not connected?
        E <> if  ." not "  then \ nRF24 not ready?
        ." ok, " rf@ .bitrate   \ Show nRF24 RF settings
        .db  ." , Scan " pwr .db
        ." , RF channel = "  #ch .
    then  r> base ! ;

: .MAP      ( a -- ) \ Print all noted nodes from a bitmap
    dup count* 0= if  ." no "  then  ." nodes "
    0  begin  swap
        2dup get* if  over .  then \ Show nodes found
    swap #n inc= until  2drop ;

v: extra definitions
: .ALL      ( -- )
    .status
    cr ."      All " all .map        \ Show all found nodes
    cr ."   Direct " direct .map
    cr ." Indirect " indirect .map
    cr ." RF-error " rf-error .map
    cr ."      All " all .map        \ Show all found nodes
    cr ."     Node types "
    0  begin
        dup all get* if  dup types + c@ . then
    #n inc= until  drop
    cr ."     Hop route: "  indirect >work
    begin  work next? while  dup .  hops + c@ . space  repeat ;


\ NOTE! Rewrite RF settings & node number for nRF24 right behind the shield NODE\
\ Usable range in europe 2400 MHz to 2483 MHz
\ #ch:      Used nRF24 channel number (0 t/m 7D)    ( 125 bands, separation 1 Mhz )
\ scan pwr: 0 = -18db, 1 = -12db, 2 = -6db, 3 = 0db ( Power used to build network )
\ pwr:      0 = -18db, 1 = -12db, 2 = -6db, 3 = 0db ( Communication power )
\ bitrate:  0 = 250 kbit, 1 = 1 Mbit, 2 = 2 Mbit    ( Communication bitrate )
: SETRF     ( #ch scan-pwr pwr bitrate #me -- )
    to #me  rf!  to pwr     \ Save node nr. & rf-settings
    to #ch  setup24l01      \ then channel number & initialise
    s" NODE\" evaluate      \ Remove previous settings  *** Change shield name if necessary ***
    rf ,  #me ,  pwr ,      \ Compile & save new settings
    #ch ,  freeze ;

v: inside definitions
\ Switch node states
: RUN       ( -- )      false to stop? ;        \ Allow a program to run free
: HALT      ( -- )      true to stop?  ch ) temit ; \ Stop a program
: HALT?     ( -- )      key?  stop? or  run ;   \ Alternative KEY? to stop node programs
: 'DATA     ( -- a )    'write 5 + ;            \ Data address in payload


\ Alternative MS routine that waits for answers to commands
\ code TICK   ( -- u )        \ Read half (low 32-bits) of rdcycle register
\    sp -) tos .mov
\    tos B00 zero csrrs      \ Read low counter
\    next
\ end-code
: TICK      ( -- tck )      40054028 @ ;


: MS>TK     ( ms -- u )     3E8 * ;     \ Initialise MS -> ticks

0 value WAIT? \ Exit <WAIT> when false
0 value #MS   \ Remember time duration
0 value TCK   \ Remember start time
: READY     ( -- )      0 to wait? ;                            \ Exit <WAIT> loop
: >MS       ( u -- )    ms>tk to #ms tick to tck  -1 to wait? ; \ (Re)start timeout timer

: (MS)      ( -- )
    wait? if  tick tck - #ms u< ?exit  ch ] temit  ready  then ; \ Timeout controller

\ When node is noted in RF-ERROR, ping it & take it in use again when it responds!
: RF-ERROR?     ( node -- flag )    \ Give true if node cannot be found
    dup RF-ERROR get* if            \ Node marked as suppressed?
        dup set-dest                \ Yes, activate write mode
        ch ! WRITE-DTX? if          \ Try to connect, succeeded?
            dup RF-ERROR *clr       \ Yes, release node again
            t? if  dup 1 .r ch + emit  then \ Show that node is in use
        then
        start24l01                  \ Restore nRF24
    then
    RF-ERROR get* 0<> ;             \ Leave node error/ok flag


\ Wait MS milliseconds & respond to external network commands. Leave early after an answer command!
0 value 'HANDLER \ Contains token of HANDLER)
v: extra definitions
: <WAIT>      ( u -- )
    #fail #retry = if  drop exit  then  >ms
    read-mode  begin
        irq? if  'handler execute  then  (ms)  \ Handle all packets
    wait? 0= until  read-mode ;

v: inside definitions
0 value NON?  \ True when'node' is a non existing node number!
0 value HOP#  \ Holds direct hopping node
: >DEST     ( node -- )
    dup FF = if set-dest exit then  \ Is it a not registered node, ready!
    dup indirect get* if            \ No, is it an indirect node?
        dup hops + c@  dup set-dest \ Yes, fetch node used for hopping
        to hop#  1 >pay  exit       \ Set dest with correct (hopping) destination
    then
    dup direct get* 0= to non?      \ A direct node, check if node does not exists?
    non? if ."  Unknown node " then \ If so give message!
    set-dest ;

: >NODE     ( node c -- ) \ New version with releasing of a node when it does not respond
    over RF-ERROR? if                   \ Skip node if it was previously unresponsive
        #retry to #fail  2drop  exit    \ Also skip <WAIT> behind it
    then  1 /ms
    swap  t? if  dup 1 .r  then  >dest  \ Set destination
    non? if  drop exit  then  xemit     \ When node unknown, skip XEMIT
    #fail #retry < ?exit  1 '>pay c@    \ No failure, then ready, or leave failed node
    t? if   dup 1 .r ch - emit  then    \ Show suppress of a failed node
    dup direct get* 0=                  \ Not a direct node?
    if drop hop# then  RF-ERROR *set ;  \ Yes, replace with direct hopping node & note failure!


: <INFO     ( -- )          \ len = 5+2
    #type 5 >pay            \ Node type
    #sub 6 >pay             \ Number of sub nodes, 0 to 9
(   ...  )  7 >len          \ 8 to 12, max. nine sub node types
    org> ch @ >node ;       \ Send data back

: INFO>     ( -- )      \ Receive info from other nodes
    5 pay>  org> types + c!  ready ;


\ Add all my connections to the payload! Note that the payload is 5 + 2*table length bytes!
: ADD-CONN  ( -- )
    direct  'data [ #map 2* ] literal  move ; \ Direct & indirect data ready

\ Return 'H' answer, the nr of direct nodes and the bitmap of these nodes
: <HOP      ( -- )
    ch H temit add-conn         \ Send my direct table & indirect table
    [ 5 #map 2* + ] literal >len  org> ch ^ >node ; \ (5+(#map*2))

: !HOPS     ( a -- )            \ Extend my indirect node tables
    begin  dup next? while      \ Node found in table 'a'
        dup all get* 0= if      \ Not yet present?
            dup indirect *set   \ Note an indirect node
            dup all *set        \ Extend all nodes table too
            org> over hops + c!  \ Finally note HOPping node
            t? if               \ Show hop found
                cr ." Node " org> . ." hop to " dup .
            then
        then  drop
    repeat  drop ;

: HOP>      ( -- )
    5 'pay> !hops                 \ Direct node data
    5 'pay> #map + !hops  ready ; \ Indirect node data

: <OK)      ( +n -- )   ch } >node ;      \ Return '}' answer to node +n (len=3)
: <OK       ( -- )      org> ch } >node ; \ Return '}' answer to origin node (len=3)

: <PING     ( -- )
    [ 5 #map 2* + ] literal >len  add-conn  <ok ; \ Return '}'  (len=5+(#map*2))

: PING>     ( -- )
    0 to #ms  ready ;   \ Receive PING response

\ Registration of new unregistered nodes
: <GIVE-NO. ( -- )              \ This is network data command 'N' (5+1)
    6 >len  0  begin            \ Start with node-no. 0
    dup all get* if  [ 2swap ]  \ Not a free node number?
    #n inc= until  drop         \ Yes, then all nodes checked?
    FF  then                    \ Yes, FF means nothing found
    5 >pay  org> ch # >node ;   \ Send result to asker!

: GET-NO.>  ( -- )              \ This is node data command '#'
    5 pay> to #me  ready ;      \ Replace node number #ME

: REGISTER> ( -- )      \ Handle the registration of a new node
    org> all *set       \ Register the new node
    org> direct *set    \ It's a direct node ofcourse!
    5 'pay> !hops  ready ; \ Add possible but unlikely new indirect nodes

: SIGN-UP   ( -- )              \ Copy #ME & NEW nodes table to blend into a network (5+2)
    direct >work                \ Add myself to all direct accessable nodes
    [ 5 #map + ] literal  >len  \ Payload size
    begin  work next? while     \ Select direct nodes
        direct 'data #map move  \ Copy NEW nodes table to direct neighbours
        ch R >node
    repeat  norm ;

\ Set a node table ready apart from myself
: >WORK-ME    ( a -- )      >work  #me work *clr ;

: DELETE-MESH ( -- )
    all *zero  direct *zero   rf-error *zero \ Clear node administration
    indirect *zero  types #n 0 fill ; \ Empty type table

: >NODES    ( c ms -- )      \ Send node command to all nodes in NM
    >r  begin  work next? while  dup .  over >node  r@ <wait>  repeat
    drop  rdrop  0 to #fail ;

v: extra definitions
\ 0 scan = max. 4 meters  ( 1 wall )    2 scan = max. 10 meters ( 1 wall )
\ 4 scan = max. 10 meters ( 2 walls )   6 scan = max. .. meters ( .. )
: SCANX     ( -- )
    t? if cr pwr .db ."  sx " then  \ Show scan power
    pwr rf@ nip >rf                 \ Set scan power
    delete-mesh  0                  \ Start fresh & scan all nodes
    begin
        dup #me <> if               \ but myself
            dup set-dest            \ Set node address
            ch ! WRITE-DTX? if      \ Send command, ACK received?
                dup all *set dup direct *set \ Note this node
                t? if dup 1 .r  ." + " then  \ Show addition
            then
            start24l01              \ Restore 24L01
        then
    #n inc= until
    drop  read-mode  rf@ >rf ;      \ Restore normal RF power

v: inside definitions
: >OTHERS   ( c -- )    400 >nodes ;
: HOP       ( -- )      ch H >others   ;
: INFO      ( -- )
    #type #me types + c!    \ Add myself
    all >work-me  ch I >others ; \ then all the others

: *SCANX    ( -- )      org>  scanx  <ok) ; \ Return answer to correct node
: *HOP      ( -- )      org>  hop    <ok) ;
: *INFO     ( -- )      org>  info   <ok) ;


\ Handle commands & scripts
: COMM-ERROR ( -- )
    t? if  cr ." Comm. error " 0 pay> . .s then \ Signal error
    start24l01 ;

v: inside also
\ Receive and execute commands from another node
: OUTPUTON  ( -- )      -1 to on?  power-on   <ok ;
: OUTPUTOFF ( -- )      0 to on?   power-off  <ok ;
: FORTH>    ( -- ?? )   5 'pay>  4 pay>  evaluate  ready  .ok  <ok ;


\ Node commands, since all nodes are equal each node
\ must be able to send and receive commands.
create 'COMMANDS    ( -- addr )
  ( Execute generic commands )
    ch F ,  ' forth> ,      \ Execute (Run) Forth command
    ch | ,  ' halt ,        \ Stop any free running program
  ( Execute target specific commands )
    ch * ,  ' outputon ,    \ Activate output
    ch _ ,  ' outputoff ,   \ Deactivate output
  ( Give back some network data )
    ch I ,  ' <info ,       \ Give node info back
    ch H ,  ' <hop ,        \ Give my direct nodes back
    ch P ,  ' <ping ,       \ Respond on ping
    ch N ,  ' <give-no. ,   \ Give free node number back
  ( Gather network data actively )
    ch s ,  ' *scanx ,      \ Scan network, with finish message
    ch i ,  ' *info ,       \ Gather node info
    ch h ,  ' *hop ,        \ Ask direct nodes of neighbours
  ( Receive node data )
    ch ^ ,  ' hop> ,        \ Receive HOP data
    ch @ ,  ' info> ,       \ Receive node info
    ch R ,  ' register> ,   \ Add a new node to the network
    ch } ,  ' ping> ,       \ Receive ping (external command finished)
    ch # ,  ' get-no.> ,    \ Receive & save free node number
    ch ! ,  ' noop ,        \ Do nothing, for SCANX & RF-ERROR?
  ( Finish )
    -1 ,    ' comm-error ,  \ Message on an command error
    align


v: extra definitions
\ Commands to other nodes directly
: ON        ( node -- )     ch * >node FF <wait> ; \ Send power on command
: OFF       ( node -- )     ch _ >node FF <wait> ; \ Send power off command
: STOP      ( node -- )     ch | >node FF <wait> ; \ Stop external Forth program
: ALL-ON    ( -- )          all >work  ch * FF >nodes ;
: ALL-OFF   ( -- )          all >work  ch _ FF >nodes ;
: STOPALL   ( -- )          all >work  ch | FF >nodes ;

v: inside definitions
: SWITCH?   ( -- flag )         \ Handle switch event
    s? if  key? exit  then      \ No keypress, check terminal key
    begin  40 <wait> s? until   \ Short keypress only
    on? if all-off else all-on then  false ;

: (HANDLER)  ( -- )
    xkey  ?dup 0= ?exit             \ Fetch command, invalid? then ready!
    1 pay> #me = if                 \ Packet for me?
        'commands exec              \ Yes, execute command
    else
        mlen >len                   \ Yes, set original payload length
        'read 'write mlen move      \ Copy RX- to TX-payload
        #me >r  org> to #me         \ Use same origin
        1 pay> swap >node r> to #me \ & relay packet
    then  norm  read-mode ;         \ Restore payload length

: HANDLER)  ( -- )
    ['] (handler) catch if ( drop ) start24l01  read-mode  norm  then ;

: HANDLER?  ( -- flag )     \ Handle all node data & commands
    irq? if                 \ Payload packet received?
        handler) false      \ Yes, get it
    else                    \ No, own command
        wait? ?dup 0= if
            switch?         \ Primitive event
        then
    then ;

: XKEY)     ( -- c )    begin  handler? until  key) ;

v: extra definitions
here  -1 ,  to #me      \ Headerless node data address
: STARTNODE ( -- )      \ Initialise node, with tracer on, change to TROFF in startup
    [ #me ] literal @           \ Fetch RF data address
    @+ to rf  @+ to #me         \ Get & set RF mode and node number too
    @+ to pwr  @ to #ch         \ Set scan power & used channel number
   ( next-on ) spi-setup          \ Activate B0 SPI interface
    5 ms  setup24L01            \ Wakeup & init. nRF24
    .status  tron  run          \ Print status, tracer on
    power-off  0 to on?
    ready                       \ Activate <WAIT>
    ['] handler)  to 'handler   \ Add NODE handler to <WAIT>
    ['] xkey)  to 'key  read-mode ; \ Add KEY & node handler to KEY


\ Send Forth command string of max. #LEN-5 bytes to remote node
: >F)       ( node a u -- )     \ Send string a u to node
    dup 5 + >len  dup 4 >pay    \ Payload = u+5 & u to admin byte
    'data  swap  [ #len 5 - ]   \ Payload data address & max length ( #LEN - 5 )
    literal  umin move          \ Copy command to payload
    ch F >node  800 <wait> ;    \ Send command

: >F        ( node ccc -- )     0 parse  >f) ;

: >ALL      ( a u -- )      \ Send string a u to all nodes
    2>r  all >work-me       \ Do send to all but myself
    begin  work next? while  2r@ >f)  repeat
    cr  2r> evaluate ;      \ Execute string on myself


: REGISTER  ( -- )                  \ Register a single node to the mesh network
    .status   scanx                 \ Show nRF24 status
    #me FF =  #me all get*  or if   \ Am i present in the network?
        cr  direct >work work next? if  \ Yes, get lowest node number in use?
            cr ch N >node  100 <wait>  \ Yes, ask first free node there
            #ch pwr rf@  #me setrf  \ Renew node with received number and current RF-settings
            #me FF = if  ." Failed " exit  then \ Network complete, sorry :)
        then
    then
    sign-up  hop                    \ Add my node to the network do HOP
    all >work-me  ch h 400 >nodes   \ on myself & all other nodes found
    cr all >work-me  ch i 400 >nodes \ Finally node type info
    info  .all ;


( Add your own application here )




' startnode  to app   v: fresh
shield NODE\   troff  ( Tracer off )

here  #me !         \ Store address RF data

v: inside
spi-setup           \ Activate SPI interface

v: forth
' 24l01\ ' tools\ - dm .  ( Basic )

' node\  ' 24l01\ - dm .  ( Mesh )

' node\  ' tools\ - dm .  ( All )

border here - dm .        ( Free memory )


55 1  3 1  FF setrf \ Default RF value & node number, etc.

\ End
