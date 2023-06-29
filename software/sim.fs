\ 
\ Last change: KS 29.06.2023 18:53:32
\
\ microCore load screen for simulation.
\ It produces program.mem for initialization of the program memory during simulation.
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg_sim.vhd
include microcross.fs           \ the cross-compiler

Target new initialized          \ go into target compilation mode and initialize target compiler

6 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
library forth_lib.fs

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

data_width #16 = [IF]
   #extern  2*             Constant sdaddr
[ELSE]
   data_addr_width 2 - 2** Constant sdaddr
[THEN]

16 data_width < [IF]
   : boot  ( -- )
      #174 FOR NEXT  $1112222 sdaddr st ld swap $10001 + swap 1+ st @ drop
      -1 sdaddr +!
      #232 FOR NEXT  $1234567 #extern st noop @ drop
      BEGIN REPEAT ;
[ELSE]
   : boot  ( -- )
      #174 FOR NEXT  $5555 sdaddr st ld swap 1+ swap 1+ st @ drop
      -1 sdaddr +!
      #234 FOR NEXT  $1234 #extern st noop @ drop
      BEGIN REPEAT ;
[THEN]

#reset TRAP: rst    ( -- )            boot              ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            di IRET           ;
#psr   TRAP: psr    ( -- )            pause             ;  \ reexecute the previous instruction

end

MEM-file program.mem cr .( sim.fs written to program.mem )
