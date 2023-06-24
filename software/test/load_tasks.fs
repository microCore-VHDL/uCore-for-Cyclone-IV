\
\ Last change: KS 24.06.2023 13:54:44
\
\ MicroCore load screen to test all aspects of the multitasker.
\ Use  .tasks and .semas to observe the state of the system.
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
include multitask.fs

Task Blinker

Semaphore Sema
Semaphore Mailbox

: mailbox-init  ( -- )   di   Mailbox 2 cells erase ;

\ ----------------------------------------------------------------------
\ lock ... unlock mutual exclusion via Sema.
\ After 'golock' the LED-line starts shifting.
\ 'Sema lock' will stop it, 'Sema unlock' will make it move again.
\ ----------------------------------------------------------------------

: shiftleds  ( n -- n' )
   dup -ctrl !   dup +
   dup #c-led3 > IF  drop #c-led0  THEN
   dup ctrl !
;
: locktask   ( -- )     1 BEGIN  Sema lock  shiftleds  Sema unlock  &200 ms sleep  REPEAT ;

: golock     ( -- )     mailbox-init   Blinker ['] locktask activate ;

\ ----------------------------------------------------------------------
\ Wait .. signal interaction between interrupt and task via Mailbox.
\ ?? should show increasing values for Signals and Waits and a
\ temporary difference of at most 1
\ ----------------------------------------------------------------------

\ Variable Signals
\ Variable Waits
\ 
\ : waittask   ( -- )     Waits  BEGIN  Mailbox wait   dup inc  REPEAT ;
\ 
\ : itime-reset  ( -- )   #i-time not Flags ! ;
\ 
\ : gowait     ( -- )     mailbox-init   Blinker ['] waittask activate
\                         itime-reset   0  dup Signals !  Waits !   ei
\ ;
\ : ??         ( -- )     Status @  di  Signals @  Waits @   rot Status !  over . dup . - . ;

\ ----------------------------------------------------------------------
\ The #i-time interrupt hits every 1/ticks_per_ms.
\ It is continually running in order to demonstrate the independence of
\ the pause signal and the multitasker from interrupts.
\ It serves a driving role during gowait.
\ ----------------------------------------------------------------------

: interrupt ( -- ) ; \  Mailbox signal   Signals inc   itime-reset ;

\ ----------------------------------------------------------------------
\ poll test
\ After 'gopoll' the LED-line starts shifting every 200 msec.
\ '1 Trigger !' will increase the time to 400 msec.
\ ----------------------------------------------------------------------

Variable Trigger

: check_trig ( -- f )   Trigger @ ;

: polltask   ( -- )     1 BEGIN  shiftleds   ['] check_trig &200 ms poll-tmax IF  &400 ms sleep  THEN REPEAT ;

: gopoll     ( -- )     mailbox-init   blinker ['] polltask activate ;
                        
\ ----------------------------------------------------------------------
\ After 'gomsg tasks' you will see the error message in Blinker.
\ ----------------------------------------------------------------------

: msgtask    ( -- )     #not-my-semaphore message ;

: gomsg      ( -- )     mailbox-init   Blinker ['] msgtask activate ;
                        
\ ----------------------------------------------------------------------
\ CATCH THROW test:
\ '0 Trigger ! catching' should print 0,
\ '5 Trigger ! catching' should print 1.
\ ----------------------------------------------------------------------

  : ?throw   ( -- )  Trigger @ throw ;

  : catching ( -- )  ['] ?throw catch dup . IF  1 ELSE 0 THEN . ;

\ ----------------------------------------------------------------------
\ Booting and TRAPs
\ ----------------------------------------------------------------------

init: init-tasks     ( -- )
   Terminal Blinker schedule
\   #i-time int-enable
;
init: init-leds ( -- )  [ #c-led0 #c-led1 or #c-led2 or #c-led3 or ] Literal -ctrl ! ;

: boot  ( -- )   0 #cache erase   CALL initialization   debug-service ;

#reset TRAP: rst    ( -- )            boot                 ;  \ compile branch to boot at reset vector location
#isr   TRAP: isr    ( -- )            interrupt IRET       ;
#psr   TRAP: psr    ( -- )            pause                ;  \ call the scheduler, eventually re-execute instruction
#break TRAP: break  ( -- )            debugger             ;  \ Debugger
#does> TRAP: dodoes ( addr -- addr' ) ld cell+ swap BRANCH ;  \ the DOES> runtime primitive
#data! TRAP: data!  ( dp n -- dp+1 )  swap st cell+        ;  \ Data memory initialization

end
