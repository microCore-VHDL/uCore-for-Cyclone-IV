\ 
\ Last change: KS 13.07.2023 20:41:42
\
\ MicroCore load screen for complete division tests.
\ This has been prepared for a 10 bit data_width so the test
\ is about 20 bits / 10 bits, which takes about 10 hours to finish.
\ UN-SIGNED = true  : um/mod and um* tests
\ UN-SIGNED = false :  m/mod and m* tests
\
Only Forth also definitions hex

[IFDEF] unpatch     unpatch    [ENDIF]
[IFDEF] close-port  close-port [ENDIF]
[IFDEF] microcore   microcore  [ENDIF]   Marker microcore

include extensions.fs           \ Some System word (re)definitions for a more sympathetic environment
include ../vhdl/architecture_pkg.vhd
include microcross.fs           \ the cross-compiler

\ Verbose on

Target new initialized          \ go into target compilation mode and initialize target compiler

6 trap-addr code-origin
          0 data-origin

true  Version UN-SIGNED

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs
include div_tasks.fs

$28 cells Constant Arguments    \ Area to save "Ambiguous" Argument sets of ddividend and divisor

Variable Irregular  0 Irregular !

uninitialized
Create Dividend  0 , 0 ,
Create Divisor   0 ,
Create Errors    0 ,
Create Ambiguous 0 ,
Create Ptr       Arguments , \ After a warm boot Ptr must be initialized to: '$28 Ptr !'
initialized

: Leds!  ( n -- )  #c-leds -ctrl !  Ctrl ! ;

: save-arguments  ( -- )
   Ptr @ #rstack u> ?EXIT  \ memory full
   Irregular @ ?EXIT       \ result was ( -- 0 #signbit ), which is irregular in 2's complement
   Dividend 2@ Ptr @ 2!
   Divisor @ Ptr @ 2 cells +   dup cell+ Ptr !   !
   1 Ambiguous +!   Ambiguous @ Leds!
;
UN-SIGNED [IF]

   : check ( -- f )
      Dividend 2@ Divisor @ um/mod   ovfl? >r
      Divisor @ 0=
      IF  or 0= r> xor ?EXIT  1 Errors +!            \ 0 is always wrong with the exception of 0 / 0
      ELSE  Divisor @ um* rot 0 d+   Dividend 2@ d=
           IF   r> 0= ?EXIT  save-arguments  EXIT    \ correct and ovfl set
           ELSE r>    ?EXIT  1 Errors +!             \ false and ovfl not set
      THEN THEN   $FF Leds!  halt
   ;
   : ??    ( -- )   divisor @  dividend 2@ ud. u. Errors @ u. Ambiguous @ u.  Ptr @ u. ;

[ELSE] \ signed divide

   : fm/mod   ( d n -- rem quot )
      dup >r 0< IF  dnegate  r@ negate  ELSE  r@  THEN
      over   0< IF  tuck + swap um/mod   ovfl? over 0< not
                ELSE            um/mod   ovfl? over 0<
                THEN  or -rot  \ the ovfl-bit
      r> 0< IF  swap negate swap  THEN
      rot IF  #ovfl st-set  ExIT THEN  #ovfl st-reset
   ;
   : check ( -- )
      Dividend 2@ Divisor @ m/mod   ovfl? >r
      2dup + #signbit = Irregular !   Divisor @ 0=
      IF  or 0= r> xor ?EXIT  1 Errors +!                \ 0 is always wrong with the exception of 0 / 0
      ELSE  Divisor @ m* rot extend d+   Dividend 2@ d=
            IF   r> 0= ?EXIT  save-arguments  EXIT       \ correct and ovfl set
            ELSE r>    ?EXIT  1 Errors +!                \ false and ovfl not set
      THEN THEN   $FF Leds!  halt
   ;
   : ??    ( -- )   divisor @  dividend 2@ d. . Errors @ u. Ambiguous @ u. Ptr @ u. ;

   : fdiv   fm/mod ovfl? ;
   : mdiv    m/mod ovfl? ;

[THEN]

: advance  ( -- )   1 Divisor +!  Divisor @ ?EXIT
   1 Dividend +2!  Dividend 2@ or ?EXIT  $55 Leds! halt
;
: blink    ( -- )      Ctrl @ $8 xor Leds! ;

: divtest  ( -- )   0 Leds!    8
   BEGIN   pause check  advance   Divisor @
           0= IF  1- ?dup 0= IF  8  blink  THEN THEN
   REPEAT
;
: start  ( -- )  Tester ['] divtest activate ;

: delay   2 FOR $1FF sleep NEXT ;

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

: boot  ( -- )   0 Dividend erase   CALL initialization   debug-service ; \ for warm boot
\ : boot  ( -- )   0 #cache erase   CALL initialization   debug-service ; \ for cold boot

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            di              IRET ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end
