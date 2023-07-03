\ 
\ Last change: KS 03.07.2023 12:08:37
\
\ MicroCore load screen for the coretest program that is transferred
\ into the program memory via the umbilical.
\
\ 'coretest' should finish with 'message: $100'.
\ Any other number is an error number, which can be located in coretest.fs
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on

Target new initialized          \ go into target compilation mode and initialize target compiler

9 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs
include coretest.fs

: memtest  ( -- error-addr )
   #extern #top over DO  dup I ! 1+  LOOP  drop
   #top #extern DO  I dup @ - IF  I rdrop rdrop EXIT THEN  LOOP  0 .
;
\ ----------------------------------------------------------------------
\ Booting, Interrupts and TRAPs
\ ----------------------------------------------------------------------

Variable Ticker  0 Ticker !

: interrupt ( -- )  Intflags @
   #i-time and IF  1 Ticker +!  #i-time not Flags !  THEN
;
init: init-leds ( -- )  [ #c-led0 #c-led1 or #c-led2 or #c-led3 or ] Literal -ctrl ! ;
init: init-int  ( -- )  #i-time int-enable ei ;

: boot  ( -- )   0 #cache erase   CALL initialization   debug-service ;

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET       ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end