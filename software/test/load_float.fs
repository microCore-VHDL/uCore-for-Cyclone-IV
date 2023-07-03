\
\ Last change: KS 02.07.2023 13:34:15
\
\ MicroCore load screen for execution on the target.
\ Floating point library package.
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
library float_lib.fs

: exp?   0 BEGIN  cr dup u. dup exp2 u. $200000 + ?dup 0= UNTIL  cr -1 dup u. exp2 u. ;
Host
: exp?   0 BEGIN  cr dup u. dup exp2 u. $4000000 + ?dup 0= UNTIL  cr -1 dup u. exp2 u. ;
Target
\ ----------------------------------------------------------------------
\ Converting NTC resistance to/from temperature
\ ----------------------------------------------------------------------
Host

&3892  float Constant B-factor
&10000 float Constant R0
-&298  float Constant -T0
&27300       Constant 0-degC

B-factor -T0 f/ R0 fln f+ fexp Constant R-lim

: R>T   ( Ohm -- degC*100 )   float R-lim f/   fln   B-factor swap f/   &100 fscale integer 0-degC - ;

: T>R   ( degC*100 -- Ohm )   0-degC + float -&100 fscale  B-factor swap f/   fexp   R-lim f*   integer ;

: ntc-test  ( -- )   -&2000 &50 FOR  cr dup 6 .r   dup t>r dup 6 .r   r>t dup 6 .r over - 3 .r  &200 + NEXT  drop ;

Target

&3892  float Constant B-factor
&10000 float Constant R0
-&298  float Constant -T0
&27300       Constant 0-degC

B-factor -T0 f/ R0 fln f+ fexp Constant R-lim

: R>T   ( Ohm -- degC*100 )   float R-lim f/   fln   B-factor swap f/   &100 fscale integer 0-degC - ;

: T>R   ( degC*100 -- Ohm )   0-degC + float -&100 fscale  B-factor swap f/   fexp   R-lim f*   integer ;

: ntc-test  ( -- )   -&2000 &50 FOR  cr dup 6 .r   dup t>r dup 6 .r   r>t dup 6 .r over - 3 .r  &200 + NEXT  drop ;

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
