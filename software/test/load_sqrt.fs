\
\ Last change: KS 03.08.2022 18:07:28
\
\ MicroCore load screen for the core test program that is transferred
\ into the program memory via the debug umbilical
\
Only Forth also definitions

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

Target new initialized          \ go into target compilation mode and initialize target compiler

8 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs

: blink       ( -- )      Leds @ $80 xor Leds ! ;

: sqrt-test  ( -- )
   -1 FOR  r@ sqrt dup * + r@ - IF  r>  EXIT THEN
           r@ $3FFFF and 0= IF  blink  THEN
   NEXT  0
;
\ ----------------------------------------------------------------------
\ Interrupt
\ ----------------------------------------------------------------------

: interrupt ( -- )  Intflags @ drop ;

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

init: init-leds  ( -- )   0 Leds ! ;

: boot  ( -- )   0 #cache erase   CALL initialization  debug-service ;

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET       ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end
