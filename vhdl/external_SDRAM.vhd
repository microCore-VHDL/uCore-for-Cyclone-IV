-- ---------------------------------------------------------------------
-- @file : external_SDRAM_16.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 24.06.2023 11:51:16
-- @project: OMDAZZ board
-- @language: VHDL-2008
-- @copyright (c): Klaus Schleisiek, All Rights Reserved.
-- @contributors:
--
-- @license: Do not use this file except in compliance with the License.
-- You may obtain a copy of the Public License at
-- https://github.com/microCore-VHDL/microCore/tree/master/documents
-- Software distributed under the License is distributed on an "AS IS"
-- basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
-- See the License for the specific language governing rights and
-- limitations under the License.
--
-- @brief: external SDRAM_16 interface for a 16 bit system using
--    the HYNIX HY57V641620FTP-H
--    Structure and comments adapted from Matthew Hagerty's sdram_simple.vhd
--
-- Version Author   Date       Changes
--  1000     ks    8-May-2023  initial version
-- ---------------------------------------------------------------------
Library IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.architecture_pkg.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY external_SDRAM IS PORT (
   uBus        : IN  uBus_port;
   delay       : OUT STD_LOGIC;
-- SDRAM
   sd_ram      : OUT SDRAM_signals;
   sd_dq       : IN  UNSIGNED(15 DOWNTO 0)
); END external_SDRAM;

ARCHITECTURE rtl OF external_SDRAM IS

-- uBus aliases
ALIAS  reset    : STD_LOGIC IS uBus.reset;
ALIAS  clk      : STD_LOGIC IS uBus.clk;
ALIAS  clk_en   : STD_LOGIC IS uBus.clk_en;
ALIAS  ext_en   : STD_LOGIC IS uBus.ext_en;
ALIAS  write    : STD_LOGIC IS uBus.write;
ALIAS  addr     : data_addr IS uBus.addr;
ALIAS  wdata    : data_bus  IS uBus.wdata;

-- TYPE  SDRAM_signals  IS RECORD -- defined in architecture_pkg.vhd
--    cke      : STD_LOGIC;             --                           3    2     1     0
--    cmd      : UNSIGNED( 3 DOWNTO 0); -- combines SDRAM inputs: | cs | we | ras | cas |
--    a        : UNSIGNED(11 DOWNTO 0);
--    ba       : UNSIGNED( 1 DOWNTO 0);
--    dqm      : UNSIGNED( 1 DOWNTO 0);
--    rdata    : UNSIGNED(15 DOWNTO 0);
-- END RECORD;

SUBTYPE cmd_type is UNSIGNED(3 DOWNTO 0);

TYPE sd_states IS (  -- SDRAM controller states.
   init_wait,
   init_mode,
   init_precharge,
   init_refresh1,
   init_refresh2,
   idle,
   refresh,
   activate,
   rcd,
   rw,
   ras,
   precharge
);

-- SDRAM mode register data sent on the address bus.
--
-- | A11-A10 |    A9    | A8  A7 | A6 A5 A4 |    A3   | A2 A1 A0 |
-- | reserved| wr burst |reserved| CAS Ltncy|burst typ| burst len|
--    0   0        0       0   0    0  1  0       0      0  0  0
CONSTANT mode_reg      : UNSIGNED(11 DOWNTO 0) := "00" & "0" & "00" & "010" & "0" & "000";

CONSTANT cmd_inhibit   : cmd_type := "0000";
CONSTANT cmd_nop       : cmd_type := "1000";
CONSTANT cmd_mode      : cmd_type := "1111";
CONSTANT cmd_activate  : cmd_type := "1100";
CONSTANT cmd_read      : cmd_type := "1010";
CONSTANT cmd_write     : cmd_type := "1011";
CONSTANT cmd_burst_end : cmd_type := "1001";
CONSTANT cmd_precharge : cmd_type := "1101";
CONSTANT cmd_refresh   : cmd_type := "1110";

SIGNAL sd_state        : sd_states;

SIGNAL sd_cke          : STD_LOGIC; --                          3     2     1    0
SIGNAL sd_cmd          : cmd_type;  -- combines SDRAM inputs: | cs | ras | cas | we |
SIGNAL sd_a            : UNSIGNED(11 DOWNTO 0);
SIGNAL sd_ba           : UNSIGNED( 1 DOWNTO 0);
SIGNAL sd_dqm          : UNSIGNED( 1 DOWNTO 0);
SIGNAL sd_rdata        : UNSIGNED(15 DOWNTO 0);

SIGNAL bank            : UNSIGNED( 1 DOWNTO 0);
SIGNAL row             : UNSIGNED(11 DOWNTO 0);
SIGNAL col             : UNSIGNED(11 DOWNTO 0);

CONSTANT wait_cnt      : NATURAL := (clk_frequency / 1000000) * 200; -- 200 usec
CONSTANT refresh_cnt   : NATURAL := (clk_frequency / 1000000) *  15; --  15 usec

SIGNAL wait_ctr        : NATURAL RANGE 0 TO wait_cnt;
SIGNAL refresh_ctr     : NATURAL RANGE 0 TO refresh_cnt;
SIGNAL ref_ctr         : NATURAL RANGE 0 TO 8;

BEGIN

sd_ram.cke   <= sd_cke;
sd_ram.cmd   <= sd_cmd;
sd_ram.a     <= sd_a;
sd_ram.ba    <= sd_ba;
sd_ram.dqm   <= sd_dqm;
sd_ram.rdata <= sd_rdata;

-- 21  20  | 19 18 17 16 15 14 13 12 11 10 09 08 | 07 06 05 04 03 02 01 00 |
-- BA1 BA0 |       ROW (A11-A0)  4096 rows       |  COL (A7-A0)  256 cols  |
row  <= "0000" & addr(15 DOWNTO 8);
col  <= "0100" & addr( 7 DOWNTO 0); -- a(10) = 1 => precharge all banks, automatic refresh

delay <= ext_en WHEN  sd_state /= precharge  ELSE '0';

SDRAM_proc : PROCESS(clk, reset)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      sd_state <= init_wait;
      wait_ctr <= 0;
      ref_ctr <= 0;
      sd_cke <= '0';
      bank <= "00";
      sd_dqm <= "11";
   ELSIF  rising_edge(clk)  THEN

      sd_cmd <= cmd_inhibit;

      IF  refresh_ctr /= 0  THEN
         refresh_ctr <= refresh_ctr-1;
      END IF;

      IF  wait_ctr /= 0  THEN
         wait_ctr <= wait_ctr-1;
      ELSE

         sd_cke <= '1';
         sd_ba <= bank;  -- for 16 bit system,  addr(21 DOWNTO 20) for larger system
         sd_a <= col;

         CASE  sd_state  IS

-- ---------------------------------------------------------------------
-- Initialization
-- ---------------------------------------------------------------------
-- 1. Wait 200us with DQM signals high, cmd NOP.
-- 2. Precharge all banks.
-- 3. Eight refresh cycles.
-- 4. Set mode register.
-- 5. Eight refresh cycles.
-- ---------------------------------------------------------------------

         WHEN init_wait =>
            sd_state <= init_precharge;
            wait_ctr <= wait_cnt;        -- 200 usec in operation
            IF  SIMULATION  THEN
               wait_ctr <= wait_cnt / 2; -- 100 usec during simulation
            END IF;
            sd_dqm <= "00";

         WHEN init_precharge =>
            sd_state <= init_refresh1;
            wait_ctr <= 1;           -- Wait 2 cycles plus state overhead for 20ns Trp.
            ref_ctr <= 8;            -- Do 8 refresh cycles in the next state.
            sd_cmd <= cmd_precharge;
            sd_ba <= "00";

         WHEN init_refresh1 =>

            IF  ref_ctr = 0  THEN
               sd_state <= init_mode;
            ELSE
               ref_ctr <= ref_ctr-1;
               sd_cmd <= cmd_refresh;
               wait_ctr <= 7;        -- Wait 8 cycles plus state overhead for 75ns refresh.
            END IF;

         WHEN init_mode =>
            sd_state <= init_refresh2;
            wait_ctr <= 1;           -- Trsc = 2 cycles after issuing MODE command.
            ref_ctr <= 8;            -- Do 8 refresh cycles in the next state.
            sd_cmd <= cmd_mode;
            sd_a <= mode_reg;
            sd_ba <= "00";

         WHEN init_refresh2 =>
            IF  ref_ctr = 0  THEN
               sd_state <= idle;
               refresh_ctr <= refresh_cnt;
            ELSE
               ref_ctr <= ref_ctr-1;
               sd_cmd <= cmd_refresh;
               wait_ctr <= 7;        -- Wait 8 cycles plus state overhead for 75ns refresh.
            END IF;

-- ---------------------------------------------------------------------
-- Normal Operation
-- ---------------------------------------------------------------------
-- Trc  - 70ns - Activate to activate command.
-- Trcd - 20ns - Activate to read/write command.
-- Tras - 50ns - Activate to precharge command.
-- Trp  - 20ns - Precharge to activate command.
-- TCas - 2clk - Read/write to data out.
--
--         |<-----------       Trc      ------------>|
--         |<----------- Tras ---------->|
--         |<- Trcd  ->|<- TCas  ->|     |<-  Trp  ->|
--  T0__  T1__  T2__  T3__  T4__  T5__  T6__  T0__  T1__
-- __/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__
-- IDLE  ACTVT  NOP  RD/WR  NOP   NOP  PRECG IDLE  ACTVT
--     --<Row>-------------------------------------<Row>--
--                ---<Col>---
--                ---<A10>-------------<A10>---
--                                  ---<Bank>---
--                ---<DQM>---
--                ---<Din>---
--                                  ---<Dout>---
--   ---<Refsh>-----------------------------------<Refsh>---
--
-- A10 during rd/wr : 0 = disable auto-precharge, 1 = enable auto-precharge.
-- A10 during precharge: 0 = single bank, 1 = all banks.
--
-- Next State vs Current State Guide
--
--  T0__  T1__  T2__  T3__  T4__  T5__  T6__  T0__  T1__  T2__
-- __/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__
-- IDLE  ACTVT  NOP  RD/WR  NOP   NOP  PRECG IDLE  ACTVT
--       IDLE  ACTVT  NOP  RD/WR  NOP   NOP  PRECG IDLE  ACTVT
-- ---------------------------------------------------------------------

         WHEN idle =>
            -- 70ns since activate when coming from PRECHARGE state.
            -- 10ns since PRECHARGE.  Trp == 20ns min.
            sd_dqm <= "11";
            IF  ext_en = '1' THEN
               sd_state <= activate;
               sd_cmd <= cmd_activate;
               sd_a <= row;             -- Set bank select and row on activate command.
               sd_ba <= "00";
               wait_ctr <= 1;
            ELSIF  refresh_ctr = 0  THEN
               sd_state <= refresh;
               sd_cmd <= cmd_refresh;
               wait_ctr <= 7;           -- Wait 8 cycles plus state overhead for 75ns refresh.
            END IF;

         WHEN refresh =>
            sd_state <= idle;
            refresh_ctr <= refresh_cnt;

         WHEN activate =>
            -- Trc (Active to Active Command Period) is 65ns min.
            -- 70ns since activate when coming from PRECHARGE -> IDLE states.
            -- 20ns since PRECHARGE.
            -- ACTIVATE command is presented to the SDRAM.  The command out of this
            -- state will be NOP for one cycle.
            sd_state <= rcd;

         WHEN rcd =>
            -- 20ns since activate.
            -- Trcd == 20ns min.  The clock is 10ns, so the requirement is satisfied by this state.
            -- READ or WRITE command will be active in the next cycle.
            sd_state <= rw;
            sd_dqm <= "00";
            IF  write = '1'  THEN
               sd_cmd <= cmd_write;
            ELSE
               sd_cmd <= cmd_read;
            END IF;

         WHEN rw =>
            -- 30ns since activate.
            -- READ or WRITE command presented to SDRAM.
            sd_state <= ras;
            sd_dqm <= "11";
            wait_ctr <= 1;

         WHEN ras =>
            -- 40ns since activate.
            -- Tras (Active to precharge Command Period) 45ns min.
            -- PRECHARGE command will be active in the next cycle.
            sd_state <= precharge;
            sd_cmd <= cmd_precharge;
            sd_rdata <= sd_dq;

         WHEN precharge =>
            -- 60ns since activate.
            -- PRECHARGE presented to SDRAM.
            sd_state <= idle;

         END CASE;

      END IF;
   END IF;
END PROCESS SDRAM_proc;

END rtl;
