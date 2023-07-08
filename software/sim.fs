\ 
\ Last change: KS 08.07.2023 17:22:20
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

data_width #16 = [IF]
   #extern  2*            Constant sdaddr
[ELSE]
   data_addr_width 1- 2** Constant sdaddr
[THEN]

cr .( debugging SDRAM_4MBx16)

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

#24 data_width < [IF]
   : boot  ( -- )
      #174 FOR NEXT  $1112222 sdaddr st ld swap $10001 + swap cell+ st @ drop
      WITH_BYTES [IF]
         $5555555 sdaddr !   $44 $33 $22 $11 sdaddr
         cst cld nip 1+ cst cld nip 1+ cst cld nip 1+ cst cld nip 3 - @ drop
         $2222 $1111 sdaddr wst wld nip 2 + wst wld nip 2 - @ drop
         #179 FOR NEXT  $1234567 #extern st noop @ drop
      [ELSE]
         -1 sdaddr +!  sdaddr @ drop
         #232 FOR NEXT  $1234567 #extern st noop @ drop
      [THEN]
      BEGIN REPEAT ;
[ELSE]
   : boot  ( -- )
      #174 FOR NEXT  $5555 sdaddr st ld swap 1+ swap cell+ st @ drop
      WITH_BYTES [IF]
         $22 $11 sdaddr cst cld nip 1+ cst cld nip  1- @ drop
         -$101 sdaddr +!  sdaddr @ drop
         #234 FOR NEXT  $1234 #extern st noop @ drop
      [ELSE]
         -$101 sdaddr +!  sdaddr @ drop
         #234 FOR NEXT  $1234 #extern st noop @ drop
      [THEN]
      BEGIN REPEAT ;
[THEN]

#reset TRAP: rst    ( -- )            boot              ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            di IRET           ;
#psr   TRAP: psr    ( -- )            pause             ;  \ reexecute the previous instruction

end

MEM-file program.mem cr .( sim.fs written to program.mem )
