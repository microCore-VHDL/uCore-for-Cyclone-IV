-- ---------------------------------------------------------------------
-- @file : SDRAM_4MBx16.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 09.07.2023 14:28:16
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
-- @brief: external SDRAM_4MBx16 interface. Please refer to the data
--         sheets of the W9812G6JH and MT48LC16M4A2, which emphasize
--         different aspects for SDRAM access in detail.
--
-- Version Author   Date       Changes
--  1000     ks   27-May-2023  initial version
--  1110     ks   27-Jun-2023  General version for varying data_widths
--                             up to 32 bits.
--  1200     ks    8-Jul-2023  General version including byte addressing.
-- ---------------------------------------------------------------------
Library IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.architecture_pkg.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY SDRAM_4MBx16 IS PORT (
   uBus        : IN    uBus_port;
   delay       : OUT   STD_LOGIC;
-- SDRAM
   sd_ram      : OUT   SDRAM_signals;
   sd_dq       : INOUT ram_data_bus
); END SDRAM_4MBx16;

ARCHITECTURE rtl OF SDRAM_4MBx16 IS

-- uBus aliases
ALIAS reset    : STD_LOGIC IS uBus.reset;
ALIAS clk      : STD_LOGIC IS uBus.clk;
ALIAS clk_en   : STD_LOGIC IS uBus.clk_en;
ALIAS ext_en   : STD_LOGIC IS uBus.ext_en;
ALIAS write    : STD_LOGIC IS uBus.write;
ALIAS bytes    : byte_type IS uBus.bytes;
ALIAS addr     : data_addr IS uBus.addr;
ALIAS wdata    : data_bus  IS uBus.wdata;

-- TYPE  SDRAM_signals  IS RECORD -- defined in architecture_pkg.vhd
--   cke         : STD_LOGIC;             --                           3     2     1    0
--   cmd         : UNSIGNED( 3 DOWNTO 0); -- combines SDRAM inputs: | cs | ras | cas | we |
--   addr        : UNSIGNED(11 DOWNTO 0);
--   bank        : UNSIGNED( 1 DOWNTO 0);
--   byte_en     : UNSIGNED( 1 DOWNTO 0);
--   rdata       : data_bus;
-- END RECORD;

TYPE sd_states IS (init_wait, init_mode, init_precharge, init_refresh1, init_refresh2,
                   idle, refresh, activate, write0, write1, rd_low, rd_high, finished);

SIGNAL sd_state        : sd_states;

SUBTYPE cmd_type is UNSIGNED(3 DOWNTO 0);
--                        |  3 |   2 |   1 |  0 |
-- combines SDRAM inputs: | cs | ras | cas | we |

CONSTANT cmd_inhibit   : cmd_type := "0000";
CONSTANT cmd_nop       : cmd_type := "1000";
CONSTANT cmd_mode      : cmd_type := "1111";
CONSTANT cmd_activate  : cmd_type := "1100";
CONSTANT cmd_read      : cmd_type := "1010";
CONSTANT cmd_write     : cmd_type := "1011";
CONSTANT cmd_burst_end : cmd_type := "1001";
CONSTANT cmd_precharge : cmd_type := "1101";
CONSTANT cmd_refresh   : cmd_type := "1110";

-- SDRAM mode register data sent on the address bus.
--
-- | A11-A10 |    A9    | A8  A7 | A6 A5 A4 |    A3   | A2 A1 A0 |
-- | reserved| wr burst |reserved| CAS Ltncy|burst typ| burst len|
--    0   0        0       0   0    0  1  0       0      0  0  0
SIGNAL mode_reg        : UNSIGNED(11 DOWNTO 0);

SIGNAL sd_cke          : STD_LOGIC;
SIGNAL sd_cmd          : cmd_type;
SIGNAL sd_addr         : UNSIGNED(11 DOWNTO 0);
SIGNAL sd_bank         : UNSIGNED( 1 DOWNTO 0);
SIGNAL sd_byte_en      : UNSIGNED( 1 DOWNTO 0); -- "byte enable" is the inverted "dqmh/l" signals

SIGNAL sd_rdata_l      : UNSIGNED(ram_data_width-1 DOWNTO 0);
SIGNAL sd_rdata_h      : UNSIGNED(ram_data_width-1 DOWNTO 0);

SIGNAL row             : UNSIGNED(11 DOWNTO 0);
SIGNAL col             : UNSIGNED(11 DOWNTO 0);
SIGNAL bank            : UNSIGNED( 1 DOWNTO 0);

CONSTANT wait_cnt      : NATURAL := (clk_frequency / 1000000) * 200; -- 200 usec
CONSTANT refresh_cnt   : NATURAL := (clk_frequency / 1000000) *  15; --  15 usec

SIGNAL wait_ctr        : NATURAL RANGE 0 TO wait_cnt;
SIGNAL refresh_ctr     : NATURAL RANGE 0 TO refresh_cnt;
SIGNAL ref_ctr         : NATURAL RANGE 0 TO 8;

BEGIN

delay <= '0' WHEN wait_ctr = 0 AND sd_state = finished  ELSE ext_en;

sd_ram.cke     <= sd_cke;
sd_ram.cmd     <= sd_cmd;
sd_ram.addr    <= sd_addr;
sd_ram.bank    <= sd_bank;
sd_ram.byte_en <= sd_byte_en;
sd_ram.rdata   <= resize((sd_rdata_h & sd_rdata_l), data_width);

single_access: IF  ram_chunks = 1  GENERATE -- data_width <= 16
-- 21  20  | 19 18 17 16 15 14 13 12 11 10 09 08 | 07 06 05 04 03 02 01 00 |
--  BANK   |       ROW (A11-A0)  4096 rows       |  COL (A7-A0)  256 cols  |

   mode_reg <= "00" & "0" & "00" & "010" & "0" & "000";

   SDRAM_proc : PROCESS(wdata, addr, bytes, sd_state)
   BEGIN

      IF  byte_addr_width = 0  THEN
         bank <= "00";
         col <= "0100" & addr(7 DOWNTO 0);       -- a(10) = 1 => precharge all banks, automatic refresh
         row <= resize(addr(data_addr_width-1 DOWNTO 8), 12);
      ELSIF  byte_addr_width = 1  THEN
         bank <= "00";
         col <= "0100" & addr(7 DOWNTO 1) & '0'; -- a(10) = 1 => precharge all banks, automatic refresh
         row <= resize(addr(data_addr_width-1 DOWNTO 8), 12);
      END IF;

      sd_dq <= (OTHERS => 'Z');
      IF  sd_state = write1  THEN
         sd_dq <= resize(wdata, 16);
         IF  byte_addr_width = 1 AND bytes = 1  THEN        -- byte access
            sd_dq <= wdata(7 DOWNTO 0) & wdata(7 DOWNTO  0);
         END IF;
      END IF;
   END PROCESS SDRAM_proc;

END GENERATE single_access;

double_access: IF  ram_chunks = 2  GENERATE -- data_width > 16
--  21  20 | 19 18 17 16 15 14 13 12 11 10 09 08 | 07 06 05 04 03 02 01 00 |
--   BANK  |       ROW (A11-A0)  4096 rows       |  COL (A7-A0)  256 cols  |

   mode_reg <= "00" & "0" & "00" & "010" & "0" & "001";

   SDRAM_proc : PROCESS(wdata, addr, bytes, sd_state)
   BEGIN
      IF  byte_addr_width = 0  THEN
         bank <= "00";
         col <= "0100" & addr(6 DOWNTO 0) & '0';  -- a(10) = 1 => precharge all banks, automatic refresh
         row <= resize(addr(data_addr_width-1 DOWNTO 7), 12);
         IF  data_addr_width = 20  THEN
            bank(0) <= addr(19);
            row <= resize(addr(18 DOWNTO 7), 12);
         END IF;
         IF  data_addr_width > 20  THEN
            bank <= addr(20 DOWNTO 19);
            row <= resize(addr(18 DOWNTO 7), 12);
         END IF;
      ELSIF  byte_addr_width = 2  THEN
         bank <= "00";
         col <= "0100" & addr(8 DOWNTO 2) & '0';  -- a(10) = 1 => precharge all banks, automatic refresh
         row <= resize(addr(data_addr_width-1 DOWNTO 9), 12);
         IF  data_addr_width = 22  THEN
            bank(0) <= addr(21);
            row <= resize(addr(20 DOWNTO 9), 12);
         END IF;
         IF  data_addr_width > 22  THEN
            bank <= addr(22 DOWNTO 21);
            row <= resize(addr(20 DOWNTO 9), 12);
         END IF;
      END IF;

      sd_dq <= (OTHERS => 'Z');
      IF  bytes = 0  THEN
         IF  sd_state = write0  THEN
            sd_dq <= resize(wdata, 16);
         ELSIF  sd_state = write1  THEN
            sd_dq <= resize(wdata(data_width-1 DOWNTO 16), 16);
         END IF;
      END IF;
      IF  sd_state = write1 OR sd_state = write0  THEN
         IF  bytes = 1  THEN      -- byte access
            sd_dq <= wdata(7 DOWNTO 0) & wdata(7 DOWNTO  0);
         ELSIF  bytes = 2  THEN   -- word access
            sd_dq <= wdata(15 DOWNTO 0);
         END IF;
      END IF;
   END PROCESS SDRAM_proc;

END GENERATE double_access;

SDRAM_proc : PROCESS(clk, reset)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      sd_state <= init_wait;
      wait_ctr <= 0;
      ref_ctr <= 0;
      sd_cke <= '0';
   ELSIF  rising_edge(clk)  THEN

      sd_cke <= '1';
      sd_cmd <= cmd_inhibit;

      IF  refresh_ctr /= 0  THEN
         refresh_ctr <= refresh_ctr-1;
      END IF;

      IF  wait_ctr /= 0  THEN
         wait_ctr <= wait_ctr-1;

      ELSE

         sd_addr <= col;
         sd_bank <= bank;
         sd_byte_en <= "00";

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
               wait_ctr <= wait_cnt / 20; -- 10 usec during simulation, model modified accordingly
            END IF;

         WHEN init_precharge =>
            sd_state <= init_refresh1;
            wait_ctr <= 1;           -- Wait 2 cycles plus state overhead for 20ns Trp.
            ref_ctr <= 8;            -- Do 8 refresh cycles in the next state.
            sd_cmd <= cmd_precharge;

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
            sd_addr <= mode_reg;

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

         WHEN idle =>
            sd_cmd <= cmd_inhibit;
            IF  ext_en = '1' THEN
               sd_state <= activate;
               sd_cmd <= cmd_activate;
               sd_addr <= row;        -- Set bank select and row on activate command.
               wait_ctr <= 2;
            ELSIF  refresh_ctr = 0  THEN
               sd_state <= refresh;
               sd_cmd <= cmd_refresh;
               wait_ctr <= 7;           -- Wait 8 cycles plus state overhead for 75ns refresh.
            END IF;

         WHEN refresh =>
            sd_state <= idle;
            refresh_ctr <= refresh_cnt;

         WHEN activate =>
            sd_byte_en <= "11";
            IF  write = '0'  THEN  -- read
               sd_cmd <= cmd_read;
               sd_state <= rd_low;
               wait_ctr <= 2;
            ELSE                   -- write
               sd_cmd <= cmd_write;
               IF  ram_chunks = 1  THEN
                  sd_state <= write1;
                  wait_ctr <= 2;
               ELSE
                  sd_state <= write0;
               END IF;
               IF  byte_addr_width = 1 AND bytes = 1  THEN
                  sd_byte_en <= addr(0) & (NOT addr(0));
               END IF;
               IF  byte_addr_width = 2  THEN
                  IF  bytes = 1  THEN
                     IF  addr(1) = '0'  THEN
                        sd_byte_en <= addr(0) & (NOT addr(0));
                     ELSE
                        sd_byte_en <= "00";
                     END IF;
                  ELSIF  bytes = 2  THEN
                     IF  addr(1) = '1'  THEN
                        sd_byte_en <= "00";
                     END IF;
                  END IF;
               END IF;
            END IF;

   -- reading
         WHEN rd_low =>
            sd_rdata_l <= sd_dq;
            IF  byte_addr_width = 1 AND bytes = 1  THEN
               IF  addr(0) = '0'  THEN
                  sd_rdata_l <= resize(sd_dq( 7 DOWNTO 0), ram_data_width);
               ELSE
                  sd_rdata_l <= resize(sd_dq(15 DOWNTO 8), ram_data_width);
               END IF;
            ELSIF  byte_addr_width = 2  THEN
               IF  bytes = 1  THEN
                  sd_rdata_l <= (OTHERS => '0');
                  IF  addr(1) = '0'  THEN
                     IF  addr(0) = '0'  THEN
                        sd_rdata_l <= resize(sd_dq( 7 DOWNTO 0), ram_data_width);
                     ELSE
                        sd_rdata_l <= resize(sd_dq(15 DOWNTO 8), ram_data_width);
                     END IF;
                  END IF;
               ELSIF  bytes = 2 AND addr(1) = '1' THEN
                  sd_rdata_l <= (OTHERS => '0');
               END IF;
            END IF;
            IF  ram_chunks = 1  THEN
               sd_state <= finished;
               wait_ctr <= 1;
            ELSE
               sd_state <= rd_high;
            END IF;

         WHEN rd_high =>
            IF  ram_chunks = 2  THEN
               sd_rdata_h <= sd_dq;
               sd_state <= finished;
               wait_ctr <= 1;
               IF  byte_addr_width = 2  THEN
                  IF  bytes = 2  THEN
                     sd_rdata_h <= (OTHERS => '0');
                     IF  addr(1) = '1'  THEN
                        sd_rdata_l <= sd_dq;
                     END IF;
                  ELSIF  bytes = 1  THEN
                     sd_rdata_h <= (OTHERS => '0');
                     IF  addr(1) = '1'  THEN
                        IF  addr(0) = '0'  THEN
                           sd_rdata_l <= resize(sd_dq( 7 DOWNTO 0), ram_data_width);
                        ELSE
                           sd_rdata_l <= resize(sd_dq(15 DOWNTO 8), ram_data_width);
                        END IF;
                     END IF;
                  END IF;
               END IF;
            END IF;

   -- writing
         WHEN write0 =>
            sd_byte_en <= "11";
            IF  bytes = 1  THEN
               IF  addr(1) = '1'  THEN
                  sd_byte_en <= addr(0) & (NOT addr(0));
               ELSE
                  sd_byte_en <= "00";
               END IF;
            ELSIF  bytes = 2 AND addr(1) = '0'  THEN
               sd_byte_en <= "00";
            END IF;
            sd_state <= write1;
            wait_ctr <= 1;

         WHEN write1 =>
            sd_state <= finished;

         WHEN finished =>
            sd_state <= idle;

         END CASE;

      END IF;

      IF  reset = '1' AND NOT ASYNC_RESET  THEN
         sd_state <= init_wait;
         wait_ctr <= 0;
         ref_ctr <= 0;
         sd_cke <= '0';
      END IF;

   END IF;
END PROCESS SDRAM_proc;

END rtl;
