\
\ Last change: KS 24.06.2023 13:42:33
\
\ Basic microCore load screen for execution on the target.
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on

Host  Variable int16p   0 int16p !

Target new initialized          \ go into target compilation mode and initialize target compiler

8 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs

Host: uint16 ;

Class int16   int16 definitions
1 int16 allot   int16 seal

     h' Object Alias Variable

     : @  ( addr -- n )  @ $FFFF and dup $8000 and IF  $FFFF not or  THEN ;
Macro: !  ( n addr -- )  T ! H ;
Target

$200 int16 Constant int
int16  Variable signed
uint16 Variable unsigned

Class Cell   Cell definitions
#cell Self allot   Self seal
Macro: @    ( obj -- n )   T @ H ;
Macro: !    ( n obj -- )   T ! H ;
     : +!   ( n obj -- )   +! ;
     : on   ( obj -- )     on ;
     : off  ( obj -- )     off ;
     : ?    ( obj -- )     @ . ;
Target

Class Point  Point definitions
   Cell Attribute X
   Cell Attribute Y
Point seal
: set   ( X Y obj -- )     swap over Self Y !   Self X ! ;
: ?     ( obj -- )         dup Point X ?   Point Y ? ;
Target

Point Object Punkt   init: init-Punkt ( -- )   1 2 Punkt set ;

\ ----------------------------------------------------------------------
\ Interrupt
\ ----------------------------------------------------------------------

: interrupt ( -- )  Intflags @ drop ;

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

init: init-leds ( -- )  [ #c-led0 #c-led1 or #c-led2 or #c-led3 or ] Literal -ctrl ! ;

: boot  ( -- )   0 #cache erase   CALL initialization  debug-service ;

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET       ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end
