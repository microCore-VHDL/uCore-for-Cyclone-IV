\
\ Last change: KS 03.08.2022 18:50:43
\
\ Basic microCore load screen for execution on the target.
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

8 trap-addr code-origin
          0 data-origin

include constants.fs            \ MicroCore Register addresses and bits
include debugger.fs
library forth_lib.fs  

: log2ceil  ( ki -- log_ki )  -1 swap  ( -1 ki )    \ log2 "counter" initialized to -1
   BEGIN  dup WHILE                ( ctr ki' )      \ continue while ki' > 0
                u2/                ( ctr ki'/2 )    \ shift ki'
                swap 1+ swap       ( ctr+1 ki'/2 )  \ increment log2
   REPEAT  drop                    ( log_ki )       \ drop ki' = 0
;
Data_width &16 = [IF]
   : u+    ( u1 u2 -- u3 )     + carry? IF  drop $FFFF  THEN ;
   : u-    ( u1 u2 -- u3 )     - carry? 0= IF  drop  0  THEN ;
   : u+sat ( u16 n -- u16' )  \ add signed number to unsigned with saturation (clipping)
      2dup + -rot
      0< IF   0< 0= IF  carry? 0= IF  drop  0  THEN  \ n < 0, u16 <= $7FFF, may underflow
                    THEN
         ELSE 0<    IF  carry? IF  drop $FFFF  THEN  \ n >= 0, u16 >= $8000, may overflow
                    THEN
         THEN
   ;
[ELSE]
   : c?   ( u16 -- f )        $10000 and ;
   : s?   ( n -- f )           $8000 and ;

   : u+    ( u1 u2 -- u3 )    + dup c? IF  drop $FFFF  THEN ;
   : u-    ( u1 u2 -- u3 )    - dup c? IF  drop     0  THEN ;
   : u+sat ( u16 n -- u16' )  \ add signed number to unsigned with saturation (clipping)
      2dup + -rot
      s? IF   s? 0= IF  dup c? IF  drop     0  THEN    \ n < 0, u16 <= $7FFF
                    THEN
         ELSE s?    IF  dup c? IF  drop $FFFF  THEN    \ n >= 0, u16 >= $8000
                    THEN
         THEN
   ;
[THEN]

: integrate ( accu hyst ki error -- accu' )
   swap log2 2 - ashift swap  ( accu ki*error/4 hyst )
   over abs <                 ( accu ki*error/4 flag )
   IF  u+sat  EXIT THEN       ( accu' )     \ integrate while above hyst
   drop                       ( accu' )     \ don't do anything while below hyst
;
Variable OPO_INT      $8000 OPO_INT !
Variable OPO_CTRL_KI      4 OPO_CTRL_KI !
Variable OPO_CTRL_HYST    9 OPO_CTRL_HYST !
Variable OPO_CTRL_KP      2 OPO_CTRL_KP !
Variable OPO_CTRL_MIN $1999 OPO_CTRL_MIN !
Variable OPO_CTRL_MAX $E667 OPO_CTRL_MAX !
Variable OPO_CTRL_FSR $AAAA OPO_CTRL_FSR !
Variable OPO_CTRL

: opo_PI  ( error -- )
   >r   Opo_INT @   r@ OPO_CTRL_KI @ log2ceil 4 - ashift
   dup abs  OPO_CTRL_HYST @ < IF  rdrop 2drop   EXIT THEN               \ don't do anything while below hyst
   u+sat dup   r> OPO_CTRL_KP @ log2ceil 4 - ashift   u+sat
   dup OPO_CTRL_MIN @ <=
   IF     OPO_CTRL_FSR @ rot over + -rot +  ( #opo_jump Fru-status ! )
   ELSE  dup OPO_CTRL_MAX @ >=
      IF  OPO_CTRL_FSR @ rot over - -rot -  ( #opo_jump Fru-status ! ) THEN
   THEN
   OPO_CTRL !   OPO_INT !
;
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
