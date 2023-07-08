-- ---------------------------------------------------------------------
-- @file : uDatacache_32b.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 05.07.2023 18:19:34
-- @project: microCore
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
-- @brief: Definition of the internal data memory.
--         Here fpga specific dual port memory IP can be included.
--
-- Version Author   Date       Changes
--  10003    ks   12-Jun-2023  for EP4CE6 Altera/Intel FPGA
--  1200     ks                byte addressing
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY uDatacache IS PORT (
   uBus        : IN  uBus_port;
   rdata       : OUT data_bus;
   dma_mem     : IN  datamem_port;
   dma_rdata   : OUT data_bus
); END uDatacache;

ARCHITECTURE rtl OF uDatacache IS

ALIAS clk            : STD_LOGIC IS uBus.clk;
ALIAS clk_en         : STD_LOGIC IS uBus.clk_en;
ALIAS mem_en         : STD_LOGIC IS uBus.mem_en;
ALIAS bytes          : byte_type IS uBus.bytes;
ALIAS write          : STD_LOGIC IS uBus.write;
ALIAS addr           : data_addr IS uBus.addr;
ALIAS wdata          : data_bus  IS uBus.wdata;
ALIAS dma_enable     : STD_LOGIC IS dma_mem.enable;
ALIAS dma_bytes      : byte_type IS dma_mem.bytes;
ALIAS dma_write      : STD_LOGIC IS dma_mem.write;
ALIAS dma_addr       : data_addr IS dma_mem.addr;
ALIAS dma_wdata      : data_bus  IS dma_mem.wdata;

SIGNAL enable        : STD_LOGIC;

SIGNAL bytes_en      : byte_addr;
SIGNAL mem_wdata     : data_bus;
SIGNAL mem_rdata     : data_bus;

SIGNAL dma_bytes_en  : byte_addr;
SIGNAL dma_mem_wdata : data_bus;
SIGNAL dma_mem_rdata : data_bus;

COMPONENT byte_cache_32 IS PORT (
   clock      : IN  STD_LOGIC;
-- port a
   rden_a     : IN  STD_LOGIC;
   wren_a     : IN  STD_LOGIC;
   byteena_a  : IN  STD_LOGIC_VECTOR ( 3 DOWNTO 0);
   address_a  : IN  STD_LOGIC_VECTOR (11 DOWNTO 0);
   data_a     : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
   q_a        : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
-- port b
   rden_b     : IN  STD_LOGIC;
   wren_b     : IN  STD_LOGIC;
   byteena_b  : IN  STD_LOGIC_VECTOR ( 3 DOWNTO 0);
   address_b  : IN  STD_LOGIC_VECTOR (11 DOWNTO 0);
   data_b     : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
   q_b        : OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
); END COMPONENT byte_cache_32;

SIGNAL rden_a         : STD_LOGIC;
SIGNAL rden_b         : STD_LOGIC;
SIGNAL wren_a         : STD_LOGIC;
SIGNAL wren_b         : STD_LOGIC;
SIGNAL slv_mem_rdata  : STD_LOGIC_VECTOR(rdata'range);
SIGNAL slv_dma_rdata  : STD_LOGIC_VECTOR(dma_rdata'range);

BEGIN

enable <= clk_en AND mem_en;

byte_access_proc : PROCESS(uBus, mem_rdata, dma_mem, dma_mem_rdata)
BEGIN

   mem_wdata <= wdata;
   rdata <= mem_rdata;
   bytes_en <= (OTHERS => '1');

   dma_mem_wdata <= dma_wdata;
   dma_rdata <= dma_mem_rdata;
   dma_bytes_en <= (OTHERS => '1');

-- 16 bit system
   IF  byte_addr_width = 1  THEN
      IF  bytes = 1  THEN        -- byte access
         mem_wdata <= wdata(7 DOWNTO 0) & wdata(7 DOWNTO  0);
         bytes_en <= "01";
         rdata <= resize(mem_rdata(07 DOWNTO 0), data_width);
         IF  addr(0) = '1'  THEN
            bytes_en <= "10";
            rdata <= resize(mem_rdata(15 DOWNTO 8), data_width);
         END IF;
         dma_mem_wdata <= dma_wdata(7 DOWNTO 0) & dma_wdata(7 DOWNTO  0);
         dma_bytes_en <= "01";
         dma_rdata <= resize(dma_mem_rdata(07 DOWNTO 0), data_width);
         IF  dma_addr(0) = '1'  THEN
            dma_bytes_en <= "10";
            dma_rdata <= resize(dma_mem_rdata(15 DOWNTO 8), data_width);
         END IF;
      END IF;
   END IF;

-- 32 bit system
   IF  byte_addr_width = 2  THEN
      IF  bytes = 1  THEN           -- byte access
         mem_wdata <= wdata(7 DOWNTO  0) & wdata(7 DOWNTO  0) & wdata(7 DOWNTO  0) & wdata(7 DOWNTO  0);
         CASE addr(1 DOWNTO 0) IS
         WHEN "00" => bytes_en <= "0001";
                      rdata <= resize(mem_rdata(07 DOWNTO 00), data_width);
         WHEN "01" => bytes_en <= "0010";
                      rdata <= resize(mem_rdata(15 DOWNTO 08), data_width);
         WHEN "10" => bytes_en <= "0100";
                      rdata <= resize(mem_rdata(23 DOWNTO 16), data_width);
         WHEN "11" => bytes_en <= "1000";
                      rdata <= resize(mem_rdata(31 DOWNTO 24), data_width);
         WHEN OTHERS => NULL;
         END CASE;
         dma_mem_wdata <= dma_wdata( 7 DOWNTO  0) & dma_wdata( 7 DOWNTO  0) & dma_wdata( 7 DOWNTO  0) & dma_wdata( 7 DOWNTO  0);
         CASE dma_addr(1 DOWNTO 0) IS
         WHEN "00" => dma_bytes_en <= "0001";
                      dma_rdata <= resize(dma_mem_rdata(07 DOWNTO 00), data_width);
         WHEN "01" => dma_bytes_en <= "0010";
                      dma_rdata <= resize(dma_mem_rdata(15 DOWNTO 08), data_width);
         WHEN "10" => dma_bytes_en <= "0100";
                      dma_rdata <= resize(dma_mem_rdata(23 DOWNTO 16), data_width);
         WHEN "11" => dma_bytes_en <= "1000";
                      dma_rdata <= resize(dma_mem_rdata(31 DOWNTO 24), data_width);
         WHEN OTHERS => NULL;
         END CASE;
      ELSIF  bytes = 2  THEN         -- word access
         mem_wdata <= wdata(15 DOWNTO 0) & wdata(15 DOWNTO  0);
         bytes_en <= "0011";
         rdata <= resize(mem_rdata(15 DOWNTO 0), data_width);
         IF  addr(1) = '1'  THEN
            bytes_en <= "1100";
            rdata <= resize(mem_rdata(31 DOWNTO 16), data_width);
         END IF;
         dma_mem_wdata <= dma_wdata(15 DOWNTO 0) & dma_wdata(15 DOWNTO  0);
         dma_bytes_en <= "0011";
         dma_rdata <= resize(dma_mem_rdata(15 DOWNTO 0), data_width);
         IF  dma_addr(1) = '1'  THEN
            dma_bytes_en <= "1100";
            dma_rdata <= resize(dma_mem_rdata(31 DOWNTO 16), data_width);
         END IF;
      END IF;
   END IF;

END PROCESS byte_access_proc;

make_sim_mem: IF  SIMULATION  GENERATE

   internal_data_mem: internal_dpbram
   GENERIC MAP (data_width, cache_size, byte_addr_width, "no_rw_check", DMEM_file)
   PORT MAP (
      clk     => clk,
      ena     => enable,
      wea     => write,
      bytea   => bytes_en,
      addra   => addr(cache_addr_width-1 DOWNTO byte_addr_width),
      dia     => mem_wdata,
      doa     => mem_rdata,
   -- dma port
      enb     => dma_enable,
      web     => dma_write,
      byteb   => dma_bytes_en,
      addrb   => dma_addr(cache_addr_width-1 DOWNTO byte_addr_width),
      dib     => dma_mem_wdata,
      dob     => dma_mem_rdata
   );

END GENERATE make_sim_mem; make_syn_mem: IF  NOT SIMULATION  GENERATE
-- instantiate FPGA specific IP for byte addressed memory here:

   rden_a <= enable AND NOT write;
   wren_a <= enable AND     write;
   rden_b <= dma_enable AND NOT dma_write;
   wren_b <= dma_enable AND     dma_write;

   dpb_data_mem: byte_cache_32
      PORT MAP (
      clock       => clk,
      rden_a      => rden_a,
      wren_a      => wren_a,
      byteena_a   => std_logic_vector(bytes_en),
      address_a   => std_logic_vector(addr(cache_addr_width-1 DOWNTO byte_addr_width)),
      data_a      => std_logic_vector(mem_wdata),
      q_a         => slv_mem_rdata,
-- dma port
      rden_b      => rden_b,
      wren_b      => wren_b,
      byteena_b   => std_logic_vector(dma_bytes_en),
      address_b   => std_logic_vector(dma_addr(cache_addr_width-1 DOWNTO byte_addr_width)),
      data_b      => std_logic_vector(dma_mem_wdata),
      q_b         => slv_dma_rdata
   );

   mem_rdata     <= unsigned(slv_mem_rdata);
   dma_mem_rdata <= unsigned(slv_dma_rdata);

END GENERATE make_syn_mem;

END rtl;

-- ============================================================
-- File Name: byte_cache_32.vhd
-- Megafunction Name(s):
-- 			altsyncram
--
-- Simulation Library Files(s):
-- 			altera_mf
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 20.1.1 Build 720 11/11/2020 SJ Lite Edition
-- ************************************************************


--Copyright (C) 2020  Intel Corporation. All rights reserved.
--Your use of Intel Corporation's design tools, logic functions
--and other software and tools, and any partner logic
--functions, and any output files from any of the foregoing
--(including device programming or simulation files), and any
--associated documentation or information are expressly subject
--to the terms and conditions of the Intel Program License
--Subscription Agreement, the Intel Quartus Prime License Agreement,
--the Intel FPGA IP License Agreement, or other applicable license
--agreement, including, without limitation, that your use is for
--the sole purpose of programming logic devices manufactured by
--Intel and sold by Intel or its authorized distributors.  Please
--refer to the applicable agreement for further details, at
--https://fpgasoftware.intel.com/eula.


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY byte_cache_32 IS
	PORT
	(
		address_a		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		address_b		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		byteena_a		: IN STD_LOGIC_VECTOR (3 DOWNTO 0) :=  (OTHERS => '1');
		byteena_b		: IN STD_LOGIC_VECTOR (3 DOWNTO 0) :=  (OTHERS => '1');
		clock		: IN STD_LOGIC  := '1';
		data_a		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rden_a		: IN STD_LOGIC  := '1';
		rden_b		: IN STD_LOGIC  := '1';
		wren_a		: IN STD_LOGIC  := '0';
		wren_b		: IN STD_LOGIC  := '0';
		q_a		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
END byte_cache_32;


ARCHITECTURE SYN OF byte_cache_32 IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (31 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (31 DOWNTO 0);

BEGIN
	q_a    <= sub_wire0(31 DOWNTO 0);
	q_b    <= sub_wire1(31 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_reg_b => "CLOCK0",
		byteena_reg_b => "CLOCK0",
		byte_size => 8,
		clock_enable_input_a => "BYPASS",
		clock_enable_input_b => "BYPASS",
		clock_enable_output_a => "BYPASS",
		clock_enable_output_b => "BYPASS",
		indata_reg_b => "CLOCK0",
		intended_device_family => "Cyclone IV E",
		lpm_type => "altsyncram",
		numwords_a => 4096,
		numwords_b => 4096,
		operation_mode => "BIDIR_DUAL_PORT",
		outdata_aclr_a => "NONE",
		outdata_aclr_b => "NONE",
		outdata_reg_a => "UNREGISTERED",
		outdata_reg_b => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		ram_block_type => "M9K",
		read_during_write_mode_mixed_ports => "OLD_DATA",
		read_during_write_mode_port_a => "OLD_DATA",
		read_during_write_mode_port_b => "OLD_DATA",
		widthad_a => 12,
		widthad_b => 12,
		width_a => 32,
		width_b => 32,
		width_byteena_a => 4,
		width_byteena_b => 4,
		wrcontrol_wraddress_reg_b => "CLOCK0"
	)
	PORT MAP (
		address_a => address_a,
		address_b => address_b,
		byteena_a => byteena_a,
		byteena_b => byteena_b,
		clock0 => clock,
		data_a => data_a,
		data_b => data_b,
		rden_a => rden_a,
		rden_b => rden_b,
		wren_a => wren_a,
		wren_b => wren_b,
		q_a => sub_wire0,
		q_b => sub_wire1
	);



END SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: ADDRESSSTALL_A NUMERIC "0"
-- Retrieval info: PRIVATE: ADDRESSSTALL_B NUMERIC "0"
-- Retrieval info: PRIVATE: BYTEENA_ACLR_A NUMERIC "0"
-- Retrieval info: PRIVATE: BYTEENA_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_ENABLE_A NUMERIC "1"
-- Retrieval info: PRIVATE: BYTE_ENABLE_B NUMERIC "1"
-- Retrieval info: PRIVATE: BYTE_SIZE NUMERIC "8"
-- Retrieval info: PRIVATE: BlankMemory NUMERIC "1"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_A NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_B NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_A NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_B NUMERIC "0"
-- Retrieval info: PRIVATE: CLRdata NUMERIC "0"
-- Retrieval info: PRIVATE: CLRq NUMERIC "0"
-- Retrieval info: PRIVATE: CLRrdaddress NUMERIC "0"
-- Retrieval info: PRIVATE: CLRrren NUMERIC "0"
-- Retrieval info: PRIVATE: CLRwraddress NUMERIC "0"
-- Retrieval info: PRIVATE: CLRwren NUMERIC "0"
-- Retrieval info: PRIVATE: Clock NUMERIC "0"
-- Retrieval info: PRIVATE: Clock_A NUMERIC "0"
-- Retrieval info: PRIVATE: Clock_B NUMERIC "0"
-- Retrieval info: PRIVATE: IMPLEMENT_IN_LES NUMERIC "0"
-- Retrieval info: PRIVATE: INDATA_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: INDATA_REG_B NUMERIC "1"
-- Retrieval info: PRIVATE: INIT_FILE_LAYOUT STRING "PORT_A"
-- Retrieval info: PRIVATE: INIT_TO_SIM_X NUMERIC "0"
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Cyclone IV E"
-- Retrieval info: PRIVATE: JTAG_ENABLED NUMERIC "0"
-- Retrieval info: PRIVATE: JTAG_ID STRING "NONE"
-- Retrieval info: PRIVATE: MAXIMUM_DEPTH NUMERIC "0"
-- Retrieval info: PRIVATE: MEMSIZE NUMERIC "131072"
-- Retrieval info: PRIVATE: MEM_IN_BITS NUMERIC "0"
-- Retrieval info: PRIVATE: MIFfilename STRING ""
-- Retrieval info: PRIVATE: OPERATION_MODE NUMERIC "3"
-- Retrieval info: PRIVATE: OUTDATA_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: OUTDATA_REG_B NUMERIC "0"
-- Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "2"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_MIXED_PORTS NUMERIC "1"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_A NUMERIC "1"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_B NUMERIC "1"
-- Retrieval info: PRIVATE: REGdata NUMERIC "1"
-- Retrieval info: PRIVATE: REGq NUMERIC "0"
-- Retrieval info: PRIVATE: REGrdaddress NUMERIC "0"
-- Retrieval info: PRIVATE: REGrren NUMERIC "1"
-- Retrieval info: PRIVATE: REGwraddress NUMERIC "1"
-- Retrieval info: PRIVATE: REGwren NUMERIC "1"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: PRIVATE: USE_DIFF_CLKEN NUMERIC "0"
-- Retrieval info: PRIVATE: UseDPRAM NUMERIC "1"
-- Retrieval info: PRIVATE: VarWidth NUMERIC "0"
-- Retrieval info: PRIVATE: WIDTH_READ_A NUMERIC "32"
-- Retrieval info: PRIVATE: WIDTH_READ_B NUMERIC "32"
-- Retrieval info: PRIVATE: WIDTH_WRITE_A NUMERIC "32"
-- Retrieval info: PRIVATE: WIDTH_WRITE_B NUMERIC "32"
-- Retrieval info: PRIVATE: WRADDR_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: WRADDR_REG_B NUMERIC "1"
-- Retrieval info: PRIVATE: WRCTRL_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: enable NUMERIC "0"
-- Retrieval info: PRIVATE: rden NUMERIC "1"
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: CONSTANT: ADDRESS_REG_B STRING "CLOCK0"
-- Retrieval info: CONSTANT: BYTEENA_REG_B STRING "CLOCK0"
-- Retrieval info: CONSTANT: BYTE_SIZE NUMERIC "8"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_A STRING "BYPASS"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_B STRING "BYPASS"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_OUTPUT_A STRING "BYPASS"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_OUTPUT_B STRING "BYPASS"
-- Retrieval info: CONSTANT: INDATA_REG_B STRING "CLOCK0"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Cyclone IV E"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "altsyncram"
-- Retrieval info: CONSTANT: NUMWORDS_A NUMERIC "4096"
-- Retrieval info: CONSTANT: NUMWORDS_B NUMERIC "4096"
-- Retrieval info: CONSTANT: OPERATION_MODE STRING "BIDIR_DUAL_PORT"
-- Retrieval info: CONSTANT: OUTDATA_ACLR_A STRING "NONE"
-- Retrieval info: CONSTANT: OUTDATA_ACLR_B STRING "NONE"
-- Retrieval info: CONSTANT: OUTDATA_REG_A STRING "UNREGISTERED"
-- Retrieval info: CONSTANT: OUTDATA_REG_B STRING "UNREGISTERED"
-- Retrieval info: CONSTANT: POWER_UP_UNINITIALIZED STRING "FALSE"
-- Retrieval info: CONSTANT: RAM_BLOCK_TYPE STRING "M9K"
-- Retrieval info: CONSTANT: READ_DURING_WRITE_MODE_MIXED_PORTS STRING "OLD_DATA"
-- Retrieval info: CONSTANT: READ_DURING_WRITE_MODE_PORT_A STRING "OLD_DATA"
-- Retrieval info: CONSTANT: READ_DURING_WRITE_MODE_PORT_B STRING "OLD_DATA"
-- Retrieval info: CONSTANT: WIDTHAD_A NUMERIC "12"
-- Retrieval info: CONSTANT: WIDTHAD_B NUMERIC "12"
-- Retrieval info: CONSTANT: WIDTH_A NUMERIC "32"
-- Retrieval info: CONSTANT: WIDTH_B NUMERIC "32"
-- Retrieval info: CONSTANT: WIDTH_BYTEENA_A NUMERIC "4"
-- Retrieval info: CONSTANT: WIDTH_BYTEENA_B NUMERIC "4"
-- Retrieval info: CONSTANT: WRCONTROL_WRADDRESS_REG_B STRING "CLOCK0"
-- Retrieval info: USED_PORT: address_a 0 0 12 0 INPUT NODEFVAL "address_a[11..0]"
-- Retrieval info: USED_PORT: address_b 0 0 12 0 INPUT NODEFVAL "address_b[11..0]"
-- Retrieval info: USED_PORT: byteena_a 0 0 4 0 INPUT VCC "byteena_a[3..0]"
-- Retrieval info: USED_PORT: byteena_b 0 0 4 0 INPUT VCC "byteena_b[3..0]"
-- Retrieval info: USED_PORT: clock 0 0 0 0 INPUT VCC "clock"
-- Retrieval info: USED_PORT: data_a 0 0 32 0 INPUT NODEFVAL "data_a[31..0]"
-- Retrieval info: USED_PORT: data_b 0 0 32 0 INPUT NODEFVAL "data_b[31..0]"
-- Retrieval info: USED_PORT: q_a 0 0 32 0 OUTPUT NODEFVAL "q_a[31..0]"
-- Retrieval info: USED_PORT: q_b 0 0 32 0 OUTPUT NODEFVAL "q_b[31..0]"
-- Retrieval info: USED_PORT: rden_a 0 0 0 0 INPUT VCC "rden_a"
-- Retrieval info: USED_PORT: rden_b 0 0 0 0 INPUT VCC "rden_b"
-- Retrieval info: USED_PORT: wren_a 0 0 0 0 INPUT GND "wren_a"
-- Retrieval info: USED_PORT: wren_b 0 0 0 0 INPUT GND "wren_b"
-- Retrieval info: CONNECT: @address_a 0 0 12 0 address_a 0 0 12 0
-- Retrieval info: CONNECT: @address_b 0 0 12 0 address_b 0 0 12 0
-- Retrieval info: CONNECT: @byteena_a 0 0 4 0 byteena_a 0 0 4 0
-- Retrieval info: CONNECT: @byteena_b 0 0 4 0 byteena_b 0 0 4 0
-- Retrieval info: CONNECT: @clock0 0 0 0 0 clock 0 0 0 0
-- Retrieval info: CONNECT: @data_a 0 0 32 0 data_a 0 0 32 0
-- Retrieval info: CONNECT: @data_b 0 0 32 0 data_b 0 0 32 0
-- Retrieval info: CONNECT: @rden_a 0 0 0 0 rden_a 0 0 0 0
-- Retrieval info: CONNECT: @rden_b 0 0 0 0 rden_b 0 0 0 0
-- Retrieval info: CONNECT: @wren_a 0 0 0 0 wren_a 0 0 0 0
-- Retrieval info: CONNECT: @wren_b 0 0 0 0 wren_b 0 0 0 0
-- Retrieval info: CONNECT: q_a 0 0 32 0 @q_a 0 0 32 0
-- Retrieval info: CONNECT: q_b 0 0 32 0 @q_b 0 0 32 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL byte_cache_32.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL byte_cache_32.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL byte_cache_32.cmp FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL byte_cache_32.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL byte_cache_32_inst.vhd FALSE
-- Retrieval info: LIB_FILE: altera_mf
