\ 
\ Last change: KS 03.08.2022 18:05:59
\
\ MicroCore load screen for testing Create ... Does
\
Only Forth also definitions 

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on

Target new initialized          \ go into target compilation mode and initialize target compiler

8 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs

Variable Link  0 Link !

Host: Obconst ( n -- )  T Create  ,                        Does> @ . ;
Host: Object  ( n -- )  T Create  ,  here Link @ , Link !  Does> @   ;

: .link  ( -- )   Link BEGIN @ ?dup WHILE dup cell- dup . @ . $20 emit  REPEAT ;

$1234 Object Dies
$5555 Obconst Und
$4321 Object Das

: test ( -- )  Dies . ;

WITH_BYTES [IF]   Create Einzeln  $98 c, $22 c,   [THEN]

\ ----------------------------------------------------------------------
\ Interrupt
\ ----------------------------------------------------------------------

Variable Ticker  0 Ticker !

: interrupt ( -- )  Intflags @
   #i-time and IF  1 Ticker +!  #i-time not Flags !  THEN
;
init: init-int  ( -- )  #i-time int-enable ei ;

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
