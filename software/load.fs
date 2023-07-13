\ 
\ Last change: KS 13.07.2023 18:45:16
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

: test   DO I   2 +LOOP ;
: test-  do I  -2 +LOOP ;

\ ----------------------------------------------------------------------
\ Booting, Interrupts and TRAPs
\ ----------------------------------------------------------------------

Variable Ticker  0 Ticker !

: interrupt ( -- )  Intflags @
   #i-time and IF  1 Ticker +!  #i-time not Flags !  THEN
;
init: init-leds ( -- )  #c-leds -ctrl ! ;
init: init-int  ( -- )  #i-time int-enable ei ;

: boot  ( -- )     0 #cache erase   CALL initialization   debug-service ;

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET       ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end

