-- ---------------------------------------------------------------------
-- @file : fpga.vhd for the Intel EP4CE6_OMDAZZ prototyping board
-- ---------------------------------------------------------------------
--
-- Last change: KS 02.07.2023 22:17:56
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

ENTITY fpga IS PORT (                         -- pins
   reset_n     : IN    STD_LOGIC;             --  25
   clock       : IN    STD_LOGIC;             --  23  external clock input
-- Demoboard specific pins
   keys_n      : IN    UNSIGNED(3 DOWNTO 0);  --  91, 90, 89, 88 <= used as interrupt input during simulation
   beep        : OUT   STD_LOGIC;             -- 110
   leds_n      : OUT   UNSIGNED(3 DOWNTO 0);  --  84, 85, 86, 87
-- temp sensor
   scl         : OUT   STD_LOGIC;             -- 112
   sda         : INOUT STD_LOGIC;             -- 113
-- serial E2prom
   i2c_scl     : OUT   STD_LOGIC;             --  99
   i2c_sda     : INOUT STD_LOGIC;             --  98
-- IR es ist mir unklar, ob das ein Sender oder ein Empfänger ist, deshal erstmal auskommentiert
--   IR          : ????? STD_LOGIC;             -- 100
-- VGA
--   vga_hsync   : OUT   STD_LOGIC;             -- 101 Pin 101 can not be used!
   vga_vsync   : OUT   STD_LOGIC;             -- 103
   vga_bgr     : OUT   UNSIGNED(2 DOWNTO 0);  -- 104, 105, 106
-- LCD
   lcd_rs      : OUT   STD_LOGIC;             -- 141
   lcd_rw      : OUT   STD_LOGIC;             -- 138
   lcd_e       : OUT   STD_LOGIC;             -- 143
   lcd_data    : OUT   UNSIGNED(7 DOWNTO 0);  --  11, 7, 10, 2, 3, 144, 1, 142
-- 7-Segment
   dig         : OUT   UNSIGNED(3 DOWNTO 0);  -- 137, 136, 135, 133
   seg         : OUT   UNSIGNED(7 DOWNTO 0);  -- 127, 124, 126, 132, 129, 125, 121, 128
-- SDRAM
   sd_clk      : OUT   STD_LOGIC;             -- 43
   sd_cke      : OUT   STD_LOGIC;             -- 58
   sd_cs_n     : OUT   STD_LOGIC;             -- 72
   sd_we_n     : OUT   STD_LOGIC;             -- 69
   sd_a        : OUT   UNSIGNED(11 DOWNTO 0); -- 59, 75, 60, 64, 65, 66, 67, 68, 83, 80, 77, 76
   sd_ba       : OUT   UNSIGNED( 1 DOWNTO 0); -- 74, 73
   sd_ras_n    : OUT   STD_LOGIC;             -- 71
   sd_cas_n    : OUT   STD_LOGIC;             -- 70
   sd_ldqm     : OUT   STD_LOGIC;             -- 42
   sd_udqm     : OUT   STD_LOGIC;             -- 55
   sd_dq       : INOUT UNSIGNED(15 DOWNTO 0); -- 44, 46, 49, 50, 51, 52, 53, 54, 39, 38, 34, 33, 32, 31, 30, 28
-- umbilical uart for debugging
   dsu_rxd     : IN    STD_LOGIC;             -- 115  UART receive
   dsu_txd     : OUT   STD_LOGIC              -- 114  UART transmit
); END fpga;

ARCHITECTURE technology OF fpga IS

SIGNAL uBus       : uBus_port;
ALIAS  reset      : STD_LOGIC IS uBus.reset;
ALIAS  clk        : STD_LOGIC IS uBus.clk;
ALIAS  clk_en     : STD_LOGIC IS uBus.clk_en;
ALIAS  wdata      : data_bus  IS uBus.wdata;
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

COMPONENT pll PORT (
   inclk0   : IN  STD_LOGIC;
   c0       : OUT STD_LOGIC;
   locked   : OUT STD_LOGIC
); END COMPONENT pll;

SIGNAL locked       : STD_LOGIC;
SIGNAL c0           : STD_LOGIC;

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

-- ---------------------------------------------------------------------
-- board specific IO
-- ---------------------------------------------------------------------

COMPONENT SDRAM_4MBx16 PORT (
   uBus        : IN    uBus_port;
   delay       : OUT   STD_LOGIC;
-- SDRAM
   sd_ram      : OUT   SDRAM_signals;
   sd_dq       : INOUT ram_data_bus
); END COMPONENT SDRAM_4MBx16;

SIGNAL sd_ram       : SDRAM_signals;
SIGNAL ext_rdata    : data_bus;
SIGNAL SDRAM_delay  : STD_LOGIC;

SIGNAL int_time     : STD_LOGIC; -- a simple interrupt process for testing

BEGIN

-- ---------------------------------------------------------------------
-- clk generation (perhaps a PLL will be used)
-- ---------------------------------------------------------------------

sim_clock: IF  SIMULATION  GENERATE

   clk <= clock;
   locked <= '1';

END GENERATE sim_clock; syn_clock: IF  NOT SIMULATION  GENERATE

   pll_100MHz: pll PORT MAP (
     inclk0  => clock,  -- 50 MHz
     c0      => clk,    -- 100 MHz
     locked  => locked
   );

END GENERATE syn_clock;

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

delay <= SDRAM_delay;

clk_en <= '1' WHEN  delay = '0' AND cycle_ctr = 0 AND locked = '1'  ELSE '0';

-- ---------------------------------------------------------------------
-- input signal synchronization
-- ---------------------------------------------------------------------

reset_a <= NOT reset_n;
synch_reset: synchronize PORT MAP(clk, reset_a, reset_s);
reset <= reset_a OR reset_s; -- this is an instantaneous and metastable safe reset

synch_dsu_rxd:   synchronize   PORT MAP(clk, dsu_rxd,   dsu_rxd_s);

i_time_sim: IF  SIMULATION  GENERATE
-- interrupt that interoperates with the test bench.vhd

   synch_interrupt: synchronize_n PORT MAP(clk, keys_n(0), int_time);

END GENERATE i_time_sim; i_time_syn: IF  NOT SIMULATION  GENERATE
-- very simple interrupt generator for testing potential interrupt
-- interference with other processes

   int_time_proc : PROCESS (clk)
   BEGIN
      IF  rising_edge(clk)  THEN
         IF  uBus.tick = '1'  THEN
            int_time <= '1';
         END IF;
         IF  uReg_write(uBus, FLAG_REG) AND uBus.wdata(signbit) = '1' AND uBus.wdata(i_time) = '0'  THEN
            int_time <= '0';
         END IF;
      END IF;
   END PROCESS int_time_proc;

END GENERATE i_time_syn;

-----------------------------------------------------------------------
-- flags
-----------------------------------------------------------------------

flags(i_time)   <= int_time;
flags(f_dsu)    <= NOT dsu_break; -- '1' if debug terminal present
flags(f_sema)   <= flag_sema;

sim_keys: IF  SIMULATION  GENERATE

flags                       <= (OTHERS => 'L');
flags(f_bitout)             <= ctrl(c_bitout); -- just for coretest
flags(f_key3 DOWNTO f_key1) <= NOT keys_n(3 DOWNTO 1);

END GENERATE sim_keys; exe_keys: IF  NOT SIMULATION  GENERATE

flags(f_key3 DOWNTO f_key0) <= NOT keys_n;

END GENERATE exe_keys;

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

SDRAM: SDRAM_4MBx16 PORT MAP (
   uBus        => uBus,
   delay       => SDRAM_delay,
-- SDRAM
   sd_ram      => sd_ram,
   sd_dq       => sd_dq
);

sd_clk    <= clk;
sd_cke    <= sd_ram.cke;
sd_cs_n   <= NOT sd_ram.cmd(3);
sd_ras_n  <= NOT sd_ram.cmd(2);
sd_cas_n  <= NOT sd_ram.cmd(1);
sd_we_n   <= NOT sd_ram.cmd(0);
sd_a      <= sd_ram.a;
sd_ba     <= sd_ram.ba;
sd_ldqm   <= NOT sd_ram.ben(0);
sd_udqm   <= NOT sd_ram.ben(1);
ext_rdata <= sd_ram.rdata;

-- sd_clk    <= '0';
-- sd_cke    <= '0';
-- sd_cs_n   <= '1';
-- sd_ras_n  <= '1';
-- sd_cas_n  <= '1';
-- sd_we_n   <= '1';
-- sd_a      <= (OTHERS => '0');
-- sd_ba     <= (OTHERS => '0');
-- sd_ldqm   <= '0';
-- sd_udqm   <= '0';
-- sd_dq     <= (OTHERS => 'Z');
-- ext_rdata <= (OTHERS => '0');

-- ---------------------------------------------------------------------
-- OMDAZZ board specific IO
--
-- At present, only the leds are actually used for signalling nad
-- keys_n(0) as interrupt input during simulation
--
-- all other output are set to an inactive state, so the peripheral
-- does not consume extra power.
-- ---------------------------------------------------------------------

-- leds
sim_leds: IF  SIMULATION  GENERATE

leds_n(3 DOWNTO 1) <= NOT Ctrl(c_led3 DOWNTO c_led1);
leds_n(0)          <= NOT Ctrl(c_bitout);

END GENERATE sim_leds; exe_leds: IF  NOT SIMULATION  GENERATE

leds_n <= NOT ctrl(c_led3 DOWNTO c_led0);

END GENERATE exe_leds;

-- beeper
beep <= '1'; -- no current consumption

-- temp sensor
scl <= '1';
sda <= 'Z'; -- INOUT pin

-- serial E2prom
i2c_scl <= '1';
i2c_sda <= 'Z'; -- INOUT pin

-- VGA
-- vga_hsync <= '0';
vga_vsync <= '0';
vga_bgr   <= (OTHERS => '0');

-- LCD
lcd_rs    <= '0';
lcd_rw    <= '0';
lcd_e     <= '0';
lcd_data  <= (OTHERS => '0');

-- 7-Segmant
dig       <= (OTHERS => '0');
seg       <= (OTHERS => '1');

END technology;
