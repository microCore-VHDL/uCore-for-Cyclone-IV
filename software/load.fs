\ 
\ Last change: KS 08.05.2023 23:23:56
\
\ Basic microCore load screen for execution on the target.
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on                      \ Library loading messages

Target new initialized          \ go into target compilation mode and initialize target compiler

6 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs

WITH_BYTES [IF]
    : cfill   here $20 FOR  r@ swap cst 1+  NEXT  drop ;
    Host
    : cfill   pad $20 1 DO  I over c! 1+ LOOP  drop ;
    Target
[ELSE]
    : cfill   here $20 FOR  r@ swap st 1+  NEXT  drop ;
    Host
    : cfill   pad $20 1 DO  I over ! cell+ LOOP  drop ;
    Target
[THEN]
\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

: interrupt ( -- ) Intflags @ drop ;

init: init-leds ( -- )  [ #c-led0 #c-led1 or #c_led2 or #c-led3 or ] Literal -ctrl ! ;

: boot  ( -- )     0 #cache erase   CALL initialization   debug-service ;

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET       ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end