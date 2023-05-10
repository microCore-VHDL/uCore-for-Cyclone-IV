-- ---------------------------------------------------------------------
-- @file : fpga.vhd for the Intel EP4CE6_OMDAZZ prototyping board
-- ---------------------------------------------------------------------
--
-- Last change: KS 10.05.2023 21:23:50
-- @project: EP4CE6_OMDAZZ
-- @language: VHDL-93
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
-- @brief: Top level entity with umbilical debug interface for the
--         EP4CE6_OMDAZZ prototyping board.
--
-- Version Author   Date       Changes
--  1000     ks    8-May-2023  initial version
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY fpga IS PORT (                        -- pins
   reset_n     : IN    STD_LOGIC;            --  25
   clock       : IN    STD_LOGIC;            --  23  external clock input
-- Demoboard specific pins
   int_n       : IN    STD_LOGIC;            --  88  used as external interrupt input
   leds_n      : OUT   UNSIGNED(3 DOWNTO 0); --  84, 85, 86, 87
-- umbilical uart for debugging
   dsu_rxd     : IN    STD_LOGIC;            -- 115  UART receive
   dsu_txd     : OUT   STD_LOGIC             -- 114  UART transmit
); END fpga;

ARCHITECTURE technology OF fpga IS

SIGNAL uBus       : uBus_port;
ALIAS  reset      : STD_LOGIC IS uBus.reset;
ALIAS  clk        : STD_LOGIC IS uBus.clk;
ALIAS  clk_en     : STD_LOGIC IS uBus.clk_en;
ALIAS  delay      : STD_LOGIC IS uBus.delay;

SIGNAL reset_a    : STD_LOGIC; -- asynchronous reset positive logic
SIGNAL reset_s    : STD_LOGIC; -- synchronized reset_n
SIGNAL dsu_rxd_s  : STD_LOGIC;
SIGNAL dsu_break  : STD_LOGIC;
SIGNAL cycle_ctr  : NATURAL RANGE 0 TO cycles - 1; -- sub-uCore_clk counter

COMPONENT microcore PORT (
   uBus        : IN    uBus_port;
   core        : OUT   core_signals;
   memory      : OUT   datamem_port;
-- umbilical uart interface
   rxd         : IN    STD_LOGIC;
   break       : OUT   STD_LOGIC;
   txd         : OUT   STD_LOGIC
); END COMPONENT microcore;

SIGNAL core         : core_signals;
SIGNAL flags        : flag_bus;
SIGNAL flags_pause  : STD_LOGIC;
SIGNAL ctrl         : UNSIGNED(ctrl_width-1 DOWNTO 0);
SIGNAL flag_sema    : STD_LOGIC;    -- a software semaphor for testing
SIGNAL memory       : datamem_port; -- multiplexed memory signals

-- data cache memory
COMPONENT uDatacache PORT (
   uBus        : IN  uBus_port;
   rdata       : OUT data_bus;
   dma_mem     : IN  datamem_port;
   dma_rdata   : OUT data_bus
); END COMPONENT uDatacache;

SIGNAL cache_rdata  : data_bus;
SIGNAL mem_rdata    : data_bus;
SIGNAL dma_mem      : datamem_port;
SIGNAL dma_rdata    : data_bus;
SIGNAL cache_addr   : data_addr;    -- for simulation only

-- board specific IO

SIGNAL ext_rdata    : data_bus;

BEGIN

-- ---------------------------------------------------------------------
-- clk generation (perhaps a PLL will be used)
-- ---------------------------------------------------------------------

clk <= clock;

enable_proc: PROCESS (clk)
BEGIN
   IF  rising_edge(clk)  THEN
      IF  cycle_ctr = 0  THEN
         IF  delay = '0'  THEN
            cycle_ctr <= cycles - 1;
         END IF;
      ELSE
         cycle_ctr <= cycle_ctr - 1;
      END IF;
   END IF;
END PROCESS enable_proc;

delay <= '0'; -- SRAM_delay;

clk_en <= '1' WHEN  delay = '0' AND cycle_ctr = 0  ELSE '0';

-- ---------------------------------------------------------------------
-- input signal synchronization
-- ---------------------------------------------------------------------

reset_a <= NOT reset_n;
synch_reset: synchronize PORT MAP(clk, reset_a, reset_s);
reset <= reset_a OR reset_s; -- this is an instantaneous and metastable safe reset

synch_dsu_rxd:   synchronize   PORT MAP(clk, dsu_rxd, dsu_rxd_s);
synch_interrupt: synchronize_n PORT MAP(clk, int_n,   flags(i_ext));

-----------------------------------------------------------------------
-- flags
-----------------------------------------------------------------------

-- synopsys translate_off
flags         <= (OTHERS => 'L');
-- synopsys translate_on

flags(f_dsu)    <= NOT dsu_break;     -- '1' if debug terminal present
flags(f_sema)   <= flag_sema;
flags(f_bitout) <= ctrl(c_bitout);    -- just for coretest

------------------------------------------------------------------------
-- ctrl-register (bitwise)
-- ---------------------------------------------------------------------

ctrl_proc: PROCESS (reset, clk)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      ctrl <= (OTHERS => '0');
   ELSIF  rising_edge(clk)  THEN
      IF  uReg_write(uBus, CTRL_REG)  THEN
         IF  uBus.wdata(signbit) = '0'  THEN
               ctrl <= ctrl OR  uBus.wdata(ctrl'range);
         ELSE  ctrl <= ctrl AND uBus.wdata(ctrl'range);
         END IF;
      END IF;
      IF  reset = '1' AND NOT ASYNC_RESET  THEN
         ctrl <= (OTHERS => '0');
      END IF;
   END IF;
END PROCESS ctrl_proc;

-- ---------------------------------------------------------------------
-- software semaphor f_sema using flag register
-- ---------------------------------------------------------------------

sema_proc: PROCESS (clk, reset)
BEGIN
   IF  reset = '1' AND ASYNC_RESET  THEN
      flag_sema <= '0';
   ELSIF  rising_edge(clk)  THEN
      IF  uReg_write(uBus, FLAG_REG)  THEN
         IF  (uBus.wdata(signbit) XOR uBus.wdata(f_sema)) = '1'  THEN
            flag_sema <= uBus.wdata(f_sema);
         END IF;
      END IF;
      IF  reset = '1' AND NOT ASYNC_RESET  THEN
         flag_sema <= '0';
      END IF;
   END IF;
END PROCESS sema_proc;

flags_pause <= '1' WHEN  uReg_write(uBus, FLAG_REG) AND uBus.wdata(signbit) = '0' AND
                         unsigned(uBus.wdata(flag_width-1 DOWNTO 0) AND flags) /= 0
               ELSE  '0';

-- ---------------------------------------------------------------------
-- microcore interface
-- ---------------------------------------------------------------------

uCore: microcore PORT MAP (
   uBus       => uBus,
   core       => core,
   memory     => memory,
-- umbilical uart interface
   rxd        => dsu_rxd_s,
   break      => dsu_break,
   txd        => dsu_txd
);

-- control signals
--ALIAS  reset        : STD_LOGIC IS uBus.reset;
--ALIAS  clk          : STD_LOGIC IS uBus.clk;
--ALIAS  clk_en       : STD_LOGIC IS uBus.clk_en;
uBus.chain                <= core.chain;
uBus.pause                <= flags_pause;
--ALIAS  delay        : STD_LOGIC IS uBus.delay;
uBus.tick                 <= core.tick;
-- registers
uBus.sources(STATUS_REG)  <= resize(core.status, data_width);
uBus.sources(DSP_REG)     <= resize(core.dsp, data_width);
uBus.sources(RSP_REG)     <= resize(core.rsp, data_width);
uBus.sources(INT_REG)     <= resize(core.int, data_width);
uBus.sources(FLAG_REG)    <= resize(flags, data_width);
uBus.sources(VERSION_REG) <= to_unsigned(version, data_width);
uBus.sources(DEBUG_REG)   <= core.debug;
uBus.sources(TIME_REG)    <= core.time;
uBus.sources(CTRL_REG)    <= resize(ctrl, data_width);
-- data memory and return stack
uBus.reg_en               <= core.reg_en;
uBus.mem_en               <= core.mem_en;
uBus.ext_en               <= core.ext_en;
uBus.bytes                <= memory.bytes;
uBus.write                <= memory.write;
uBus.addr                 <= memory.addr;
uBus.wdata                <= memory.wdata;
uBus.rdata                <= mem_rdata;

-- ---------------------------------------------------------------------
-- data memory consisting of dcache, ext_mem, and debugmem
-- ---------------------------------------------------------------------

dma_mem.enable   <= '0';
dma_mem.write    <= '0';
dma_mem.bytes    <= 0;
dma_mem.addr     <= (OTHERS => '0');
dma_mem.wdata    <= (OTHERS => '0');

internal_data_mem: uDatacache PORT MAP (
   uBus         => uBus,
   rdata        => cache_rdata,
   dma_mem      => dma_mem,
   dma_rdata    => dma_rdata
);

mem_rdata_proc : PROCESS (uBus, cache_rdata, ext_rdata)
BEGIN
   mem_rdata <= cache_rdata;
   IF  uBus.ext_en = '1' AND WITH_EXTMEM  THEN
      mem_rdata <= ext_rdata;
   END IF;
END PROCESS mem_rdata_proc;

-- pragma translate_off
memaddr_proc : PROCESS (clk)
BEGIN
   IF  rising_edge(clk)  THEN
      IF  (clk_en AND core.mem_en) = '1'  THEN
         cache_addr <= memory.addr; -- state of the internal blockRAM address register while simulating
      END IF;
END IF;
END PROCESS memaddr_proc;
-- pragma translate_on
-- ---------------------------------------------------------------------
-- external SDRAM data memory
-- ---------------------------------------------------------------------

ext_rdata <= (OTHERS => '0');

-- ---------------------------------------------------------------------
-- XP2_8_protoboard specific IO
-- ---------------------------------------------------------------------

simulating: IF  SIMULATION  GENERATE

leds_n(3 DOWNTO 1) <= NOT Ctrl(c_led3 DOWNTO c_led1);
leds_n(0)          <= NOT Ctrl(c_bitout);

END GENERATE simulating; executing: IF  NOT SIMULATION  GENERATE

leds_n <= NOT ctrl(c_led3 DOWNTO c_led0);

END GENERATE executing;


END technology;
