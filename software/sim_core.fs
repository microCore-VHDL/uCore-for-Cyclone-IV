\ 
\ Last change: KS 02.07.2023 20:00:43
\
\ MicroCore load screen for coretest simulation.
\ It produces program.mem for initialization of the program memory during simulation.
\ Use wave signal script core.do in the simulator directory.
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg_sim.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on

Target new initialized          \ go into target compilation mode and initialize target compiler

9 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
library forth_lib.fs
include coretest.fs             \ needs 110 usec on EP4CE6 @ 25 MHz

init: init-leds ( -- )  [ #c-led0 #c-led1 or #c-led2 or #c-led3 or ] Literal -ctrl ! ;

: boot  ( -- )   CALL INITIALIZATION coretest BEGIN REPEAT ;

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

#reset TRAP: rst    ( -- )            boot            ;  \ compile branch to coretest at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET  ;
#psr   TRAP: psr    ( -- )            #f-sema release ;  \ matches coretest's test_sema
#data! TRAP: data!  ( dp n -- dp+ )   swap st cell+   ;  \ Data memory initialization operator

end

MEM-file program.mem  cr .( sim_core.fs written to program.mem )
