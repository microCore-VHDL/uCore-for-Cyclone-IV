\ ----------------------------------------------------------------------
\ @file : constants.fs for the EP4CE6_OMDAZZ prototyping board
\ ----------------------------------------------------------------------
\
\ Last change: KS 15.07.2023 17:11:13
\ @project: microForth/microCore
\ @language: gforth_0.6.2
\ @copyright (c): Free Software Foundation
\ @original author: ks - Klaus Schleisiek
\ @contributor:
\
\ @license: This file is part of microForth.
\ microForth is free software for microCore that loads on top of Gforth;
\ you can redistribute it and/or modify it under the terms of the
\ GNU General Public License as published by the Free Software Foundation,
\ either version 3 of the License, or (at your option) any later version.
\ This program is distributed in the hope that it will be useful,
\ but WITHOUT ANY WARRANTY; without even the implied warranty of
\ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
\ GNU General Public License for more details.
\ You should have received a copy of the GNU General Public License
\ along with this program. If not, see http://www.gnu.org/licenses/.
\
\ @brief : MicroCore hardware/software interface: Register Constants
\          Quantities between H ..... T due to loading
\          architecture_pkg.VHD on the Host.
\
\ Version Author   Date       Changes
\  1000     ks    8-May-2023  initial version
\ ----------------------------------------------------------------------
Target

\ ----------------------------------------------------------------------
\ Memory mapping
\ ----------------------------------------------------------------------

                    #extern Constant #sdram

data_width data_addr_width = [IF]
                 #registers Constant #top   \ beware of the registers at top memory end
[ELSE]
    H data_addr_width 2** T Constant #top   \ cell memory fully available
[THEN]

\ ----------------------------------------------------------------------
\ registers and bits
\ ----------------------------------------------------------------------

H STATUS_REG      T Register Status
H s_c          T Bit #c            \    1 carry mask
H s_ovfl       T Bit #ovfl         \    2 integer and float overflow mask
H s_ie         T Bit #ie           \    4 interrupt enable mask
H s_iis        T Bit #iis          \    8 interrupt in service mask
H s_lit        T Bit #lit          \  $10 previous instruction was lit_instruction mask
H s_neg        T Bit #neg          \  $20 sign mask
H s_zero       T Bit #zero         \  $40 zero mask
H s_div        T Bit #sign-div     \  $80 sign of DIVisor mask
H s_den        T Bit #sign-den     \ $100 sign of DividENd mask
H s_unfl       T Bit #unfl         \ $200 float underflow mask

H DSP_REG         T Register Dsp

H RSP_REG         T Register Rsp

H INT_REG         T Register Intflags
H i_time       T Bit #i-time  \ while executing
H i_time       T Bit #i-ext   \ while simulating
H FLAG_REG        T Register Flags
H f_dsu        T Bit #f-dsu        \ set when the dsu is connected to the umbilical (no break!)
H f_sema       T Bit #f-sema
H f_key0       T Bit #f-key0   H f_bitout T Bit #f-bitout \ Alias name for coretest
H f_key1       T Bit #f-key1
H f_key2       T Bit #f-key2
H f_key3       T Bit #f-key3

H VERSION_REG     T Register Version-reg

H DEBUG_REG       T Register Debug-reg

H CTRL_REG        T Register Ctrl-reg
H c_led0       T Bit #c-led0   H c_bitout T Bit #c-bitout \ Alias name for coretest
H c_led1       T Bit #c-led1
H c_led2       T Bit #c-led2
H c_led3       T Bit #c-led3

#c-led0 #c-led1 or #c-led2 or #c-led3 or Constant #c-leds

H TIME_REG        T Register Time-reg

