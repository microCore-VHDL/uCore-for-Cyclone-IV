-- ---------------------------------------------------------------------
-- @file : debugger.vhd
-- ---------------------------------------------------------------------
--
-- Last change: KS 03.11.2022 19:30:56
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
-- @brief: The debugger connects to the host via an RS232 interface
--         and allows interactive control while microCore is running.
--         The debugger does not use the processor, it is a specific
--         set of state machines. Except when reading or writing the
--         uCore's memories.
--
-- Version Author   Date       Changes
--   210     ks    8-Jun-2020  initial version
--  2300     ks    8-Mar-2021  STD_LOGIC_(UN)SiGNED replaced by NUMERIC_STD.
--  2400     ks   03-Nov-2022  byte addressing using byte_addr_width
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions_pkg.ALL;
USE work.architecture_pkg.ALL;

ENTITY debugger IS PORT (
   uBus           : IN  uBus_port;
   deb_reset      : OUT STD_LOGIC;    -- reset generated by debugger
   deb_pause      : OUT STD_LOGIC;
   deb_prequest   : OUT STD_LOGIC;    -- request program memory write cycle
   deb_penable    : IN  STD_LOGIC;    -- execute program memory write
   deb_drequest   : OUT STD_LOGIC;    -- request data memory for a read/write cycle
   deb_denable    : IN  STD_LOGIC;    -- execute data memory read/write
   umbilical      : OUT progmem_port; -- interface to the program memory
   debugmem       : OUT datamem_port; -- interface to the data memory
   debugmem_rdata : IN  data_bus;
-- umbilical uart
   rxd            : IN  STD_LOGIC;
   break          : OUT STD_LOGIC;
   txd            : OUT STD_LOGIC
); END debugger;

ARCHITECTURE rtl OF debugger IS

CONSTANT addr_width   : NATURAL := max(data_addr_width, prog_addr_width);

ALIAS  reset       : STD_LOGIC IS uBus.reset;
ALIAS  clk         : STD_LOGIC IS uBus.clk;
ALIAS  clk_en      : STD_LOGIC IS uBus.clk_en;
ALIAS  wdata       : data_bus  IS uBus.wdata;
SIGNAL progload    : STD_LOGIC;

COMPONENT uart GENERIC (
   rate       : NATURAL;
   depth      : NATURAL;
   ramstyle   : STRING
); PORT (
   uBus       : IN  uBus_port;
   pause      : OUT STD_LOGIC; -- uart pause
   rx_full    : OUT STD_LOGIC; -- rx data buffer full
   rx_read    : IN  STD_LOGIC; -- read rx data buffer
   rx_data    : OUT byte;      -- rx data buffer
   rx_break   : OUT STD_LOGIC; -- break detected
   rx_ovrn    : OUT STD_LOGIC; -- rx overrun, queue = full+1
   tx_empty   : OUT STD_LOGIC; -- data buffer empty
   tx_write   : IN  STD_LOGIC; -- write into data buffer
   tx_data    : IN  byte;      -- output data
   tx_busy    : OUT STD_LOGIC; -- tx uart still busy
-- UART I/O
   dtr        : IN  STD_LOGIC;
   rxd        : IN  STD_LOGIC;
   txd        : OUT STD_LOGIC
); END COMPONENT uart;

SIGNAL rx_full     : STD_LOGIC;  -- uart buffer full
SIGNAL rx_read     : STD_LOGIC;  -- read uart buffer
SIGNAL rx_data     : byte;       -- uart input buffer
SIGNAL tx_empty    : STD_LOGIC;  -- uart buffer empty
SIGNAL tx_write    : STD_LOGIC;  -- write byte
SIGNAL tx_data     : byte;       -- uart output buffer
SIGNAL tx_busy     : STD_LOGIC;  -- uart transmitter busy
SIGNAL uart_break  : STD_LOGIC;  -- break from uart
SIGNAL host_break  : STD_LOGIC;  -- break via umbilical

-- umbilical
CONSTANT all_nibbles : NATURAL := octetts-1;

-- umbilical uart input
TYPE in_states     IS (idle, getaddr, getlength, loading, rx_debug, full, ack, uploading, downloading);

SIGNAL in_state    : in_states;
SIGNAL in_ctr      : NATURAL RANGE 0 TO all_nibbles; -- #nibbles to receive from host
SIGNAL in_reg      : UNSIGNED(octetts*8-1 DOWNTO 0);
SIGNAL new_inreg   : UNSIGNED(in_reg'range);
SIGNAL in_rd       : STD_LOGIC;  -- target reads in_reg
SIGNAL upload      : STD_LOGIC;
SIGNAL download    : STD_LOGIC;
SIGNAL addr_ptr    : UNSIGNED(addr_width-1 DOWNTO 0);
SIGNAL addr_ctr    : UNSIGNED(addr_width-1 DOWNTO 0);

-- umbilical uart output
TYPE out_states    IS (start, idle, mark, tx_debug, wait_ack, readmem, downloading);

SIGNAL out_state   : out_states;
SIGNAL out_ctr     : NATURAL RANGE 0 TO all_nibbles; -- #nibbles to receive from host
SIGNAL out_wr      : STD_LOGIC;  -- target writes out_reg
SIGNAL out_reg     : UNSIGNED(octetts*8-1 DOWNTO 0);
SIGNAL new_outreg  : UNSIGNED(out_reg'range);
SIGNAL send_ack    : STD_LOGIC;

-- memory control
SIGNAL dread       : STD_LOGIC;
SIGNAL write       : STD_LOGIC;  -- write signal for umbilical

-- pragma translate_off
SIGNAL in_read     : STD_LOGIC;
SIGNAL out_written : STD_LOGIC;
-- pragma translate_on

BEGIN

break        <= host_break OR uart_break;
deb_prequest <= write AND progload;

-- pragma translate_off
in_read     <= '0' WHEN  in_state /= full                       ELSE in_rd;  -- for simulation only
out_written <= '0' WHEN  out_state /= idle OR in_state /= idle  ELSE out_wr; -- for simulation only
-- pragma translate_on

umbilical.enable  <= deb_penable;
umbilical.write   <= write;
umbilical.read    <= '0';
umbilical.addr    <= addr_ptr(umbilical.addr'range);
umbilical.wdata   <= rx_data;

debugmem.enable   <= deb_denable;
debugmem.write    <= write;
debugmem.bytes    <= 0 WHEN  byte_addr_width = 0  ELSE 1;
debugmem.addr     <= addr_ptr(debugmem.addr'range);
debugmem.wdata    <= in_reg(debugmem.wdata'range);

in_rd  <= '1' WHEN  uReg_read (uBus, DEBUG_REG)  ELSE '0';
out_wr <= '1' WHEN  uReg_write(uBus, DEBUG_REG)  ELSE '0';

deb_pause <= '1' WHEN  (in_rd  = '1' AND  in_state /= full) OR
                       (out_wr = '1' AND (in_state /= idle OR out_state /= idle))
                 ELSE '0';

-- ---------------------------------------------------------------------
-- loading the program memory
-- and listening to the host
-- ---------------------------------------------------------------------

tx_data <= mark_ack   WHEN  send_ack = '1'       ELSE
           mark_debug WHEN  out_state = mark     ELSE
           mark_nack  WHEN  out_state = start    ELSE
           out_reg(out_reg'high DOWNTO out_reg'high-7);

new_inreg <= in_reg(in_reg'high-8 DOWNTO 0) & rx_data;

new_outreg_proc: PROCESS(debugmem_rdata, addr_ptr)
BEGIN
   new_outreg <= resize(debugmem_rdata, out_reg'length);
   IF  byte_addr_width = 1  THEN  -- 16 bit
      CASE  addr_ptr(0)  IS
      WHEN  '0' => new_outreg(out_reg'high DOWNTO out_reg'high-7) <= debugmem_rdata(07 DOWNTO 00);
      WHEN  '1' => new_outreg(out_reg'high DOWNTO out_reg'high-7) <= debugmem_rdata(15 DOWNTO 08);
      WHEN OTHERS => NULL;
      END CASE;
   ELSIF  byte_addr_width = 2  THEN -- 32 bit
      CASE  addr_ptr(1 DOWNTO 0)  IS
      WHEN "00" => new_outreg(out_reg'high DOWNTO out_reg'high-7) <= debugmem_rdata(07 DOWNTO 00);
      WHEN "01" => new_outreg(out_reg'high DOWNTO out_reg'high-7) <= debugmem_rdata(15 DOWNTO 08);
      WHEN "10" => new_outreg(out_reg'high DOWNTO out_reg'high-7) <= debugmem_rdata(23 DOWNTO 16);
      WHEN "11" => new_outreg(out_reg'high DOWNTO out_reg'high-7) <= debugmem_rdata(31 DOWNTO 24);
      WHEN OTHERS => NULL;
      END CASE;
   END IF;
END PROCESS new_outreg_proc;

umbilical_proc: PROCESS(clk, reset)

   PROCEDURE tx_ack IS
   BEGIN
      IF  out_state = idle AND tx_empty = '1' AND tx_write = '0'  THEN
         send_ack <= '1';
         tx_write <= '1';
      END IF;
   END tx_ack;

   PROCEDURE tx_start IS
   BEGIN
      IF  tx_empty = '1' AND tx_write = '0'  THEN
         tx_write <= '1';
      END IF;
   END tx_start;

BEGIN

   IF  reset = '1' AND ASYNC_RESET  THEN
         out_ctr <= all_nibbles;
       out_state <= start;
        in_state <= idle;
        progload <= '0';
        send_ack <= '0';
          upload <= '0';
        download <= '0';
      host_break <= '0';
           write <= '0';
       deb_reset <= '0';
    deb_drequest <= '0';

   ELSIF  rising_edge(clk)  THEN
      IF  clk_en = '1'  THEN
         tx_write <= '0';
         dread <= '0';

         IF  deb_denable = '1'  THEN
            IF  write = '0'  THEN
               dread <= '1';
            END IF;
            write <= '0';
            deb_drequest <= '0';
         END IF;

         IF  (deb_penable OR dread OR (deb_denable AND write)) = '1'  THEN
            addr_ptr <= addr_ptr + 1;
            addr_ctr <= addr_ctr - 1;
         END IF;

-- ---------------------------------------------------------------------
-- umbilical input
-- ---------------------------------------------------------------------

         CASE in_state IS

         WHEN idle      => in_ctr <= all_nibbles;
                           progload <= '0';
                           IF  rx_full = '1' AND download = '0'  THEN
                              CASE rx_data IS
                              WHEN mark_start    => in_state <= getaddr;
                                                    progload <= '1';
                              WHEN mark_reset    => deb_reset <= '1';
                                                    in_state <= getaddr;
                                                    progload <= '1';
                              WHEN mark_debug    => in_state <= rx_debug;
                              WHEN mark_upload   => IF  WITH_UP_DOWNLOAD  THEN
                                                       in_state <= getaddr;
                                                       upload <= '1';
                                                    END IF;
                              WHEN mark_download => IF  WITH_UP_DOWNLOAD  THEN
                                                       in_state <= getaddr;
                                                       download <= '1';
                                                    END IF;
                              WHEN mark_break    => host_break <= '1';
                              WHEN mark_nbreak   => host_break <= '0';
                              WHEN OTHERS        => NULL;
                              END CASE;
                           END IF;

         WHEN getaddr   => IF  rx_full = '1'  THEN
                              in_reg <= new_inreg;
                              IF  in_ctr = 0  THEN
                                 in_ctr <= all_nibbles;
                                 addr_ptr <= unsigned(new_inreg(addr_ptr'range));
                                 in_state <= getlength;
                              ELSE
                                 in_ctr <= in_ctr - 1;
                              END IF;
                           END IF;

         WHEN getlength => IF  rx_full = '1'  THEN
                              in_reg <= new_inreg;
                              IF  in_ctr = 0  THEN
                                 in_ctr <= all_nibbles;
                                 addr_ctr <= unsigned(new_inreg(addr_ctr'range));
                                 in_state <= loading;
                                 IF  upload = '1' AND WITH_UP_DOWNLOAD  THEN
                                    in_state <= uploading;
                                 END IF;
                                 IF  download = '1' AND WITH_UP_DOWNLOAD  THEN
                                    in_state <= downloading;
                                    IF  byte_addr_width /= 0  THEN
                                       in_ctr <= 0;
                                    END IF;
                                 END IF;
                              ELSE
                                 in_ctr <= in_ctr - 1;
                              END IF;
                           END IF;

         WHEN loading   => IF  addr_ctr = 0  THEN
                              tx_ack;
                              IF  send_ack = '1'  THEN
                                 send_ack <= '0';
                                 in_state <= idle;
                                 deb_reset <= '0';
                              END IF;
                           ELSIF  rx_full = '1'  THEN
                              write <= '1';
                           ELSIF  deb_penable = '1'  THEN
                              write <= '0';
                           END IF;

         WHEN rx_debug  => IF  rx_full = '1'  THEN
                              in_reg <= new_inreg;
                              IF  in_ctr = 0  THEN
                                 in_ctr <= all_nibbles;
                                 in_state <= full;
                              ELSE
                                 in_ctr <= in_ctr - 1;
                              END IF;
                           END IF;

         WHEN full      => IF  in_rd = '1'  THEN
                              in_state <= ack;
                           END IF;

         WHEN ack       => tx_ack;
                           IF  send_ack = '1'  THEN
                              send_ack <= '0';
                              in_state <= idle;
                           END IF;

         WHEN uploading => IF  WITH_UP_DOWNLOAD  THEN
                              IF  addr_ctr = 0  THEN
                                 tx_ack;
                                 IF  send_ack = '1'  THEN
                                    send_ack <= '0';
                                    upload <= '0';
                                    in_state <= idle;
                                 END IF;
                              ELSIF  byte_addr_width = 0  THEN -- cell addressing
                                 IF  rx_full = '1'  THEN
                                    in_reg <= new_inreg;
                                    IF  in_ctr = 0  THEN
                                       in_ctr <= all_nibbles;
                                       deb_drequest <= '1';
                                       write <= '1';
                                    ELSE
                                       in_ctr <= in_ctr - 1;
                                    END IF;
                                 END IF;
                              ELSIF  byte_addr_width = 1  THEN
                                 IF  rx_full = '1'  THEN
                                    deb_drequest <= '1';
                                    write <= '1';
                                    in_reg <= resize(rx_data & rx_data, in_reg'length);
                                 END IF;
                              ELSE -- byte_addr_width = 2
                                 IF  rx_full = '1'  THEN
                                    deb_drequest <= '1';
                                    write <= '1';
                                    in_reg <= resize(rx_data & rx_data & rx_data & rx_data, in_reg'length);
                                 END IF;
                              END IF;
                           END IF;

         WHEN downloading => IF  WITH_UP_DOWNLOAD  THEN
                              IF  out_state = idle  THEN
                                 deb_drequest <= '1';
                                 out_state <= readmem;
                                 in_state <= idle;
                              END IF;
                           END IF;

         WHEN OTHERS    => in_state <= idle;

         END CASE;

-- ---------------------------------------------------------------------
-- umbilical output
-- ---------------------------------------------------------------------

         CASE out_state IS

         WHEN start     => tx_start;
                           IF  tx_write = '1'  THEN
                              IF  out_ctr = 0  THEN
                                 out_state <= idle;
                              ELSE
                                 out_ctr <= out_ctr - 1;
                              END IF;
                           END IF;

         WHEN idle      => out_ctr <= all_nibbles;
                           IF  out_wr = '1' AND in_state = idle AND send_ack = '0'  THEN   -- send a new word
                              out_reg <= resize(wdata, out_reg'length);
                              out_state <= mark;
                           END IF;

         WHEN mark      => tx_start;
                           IF  tx_write = '1'  THEN
                              out_state <= tx_debug;
                           END IF;

         WHEN tx_debug  => tx_start;
                           IF  tx_write = '1'  THEN
                              IF  out_ctr = 0  THEN
                                 out_state <= wait_ack;
                              ELSE
                                 out_reg <= out_reg(out_reg'high-8 DOWNTO 0) & "00000000";
                                 out_ctr <= out_ctr - 1;
                              END IF;
                           END IF;

         WHEN wait_ack  => IF  rx_full = '1' AND rx_data = mark_ack  THEN
                              out_state <= idle;
                              download <= '0';
                           END IF;

         WHEN readmem   => IF  WITH_UP_DOWNLOAD  THEN
                              IF  WITH_EXTMEM AND addr_extern <= to_INTEGER(addr_ptr(debugmem.addr'range))  THEN -- external memory
                                 IF  deb_denable = '1'  THEN
                                    out_reg <= new_outreg;
                                    out_ctr <= all_nibbles;
                                    out_state <= downloading;
                                 END IF;
                              ELSIF  dread = '1'  THEN -- internal memory
                                 out_reg <= new_outreg;
                                 IF  byte_addr_width /= 0  THEN
                                    out_ctr <= 0;
                                 ELSE
                                    out_ctr <= all_nibbles;
                                 END IF;
                                 out_state <= downloading;
                              END IF;
                           END IF;

         WHEN downloading => IF  WITH_UP_DOWNLOAD  THEN
                              tx_start;
                              IF  tx_write = '1'  THEN
                                 IF  out_ctr /= 0  THEN
                                    out_reg <= out_reg(out_reg'high-8 DOWNTO 0) & "00000000";
                                    out_ctr <= out_ctr - 1;
                                 ELSIF  addr_ctr /= 0  THEN
                                    deb_drequest <= '1';
                                    out_state <= readmem;
                                 ELSE -- addr_ctr = 0
                                    out_state <= wait_ack;
                                 END IF;
                              END IF;
                           END IF;

         WHEN OTHERS    => out_state <= idle;

         END CASE;

      END IF; -- clk_en = '1'

      IF  reset = '1' AND NOT ASYNC_RESET  THEN
           out_ctr <= all_nibbles;
         out_state <= start;
          in_state <= idle;
          progload <= '0';
          send_ack <= '0';
            upload <= '0';
          download <= '0';
        host_break <= '0';
             write <= '0';
         deb_reset <= '0';
      deb_drequest <= '0';
      END IF;

   END IF;
END PROCESS umbilical_proc;

-- ---------------------------------------------------------------------
-- umbilical uart
-- ---------------------------------------------------------------------

rx_read <= rx_full AND clk_en;

debug_uart: uart
GENERIC MAP (umbilical_rate, 4, "registers") PORT MAP (
   uBus       => uBus,
   pause      => OPEN,
   rx_full    => rx_full,    -- rx data buffer full
   rx_read    => rx_read,    -- read rx data buffer
   rx_data    => rx_data,    -- rx data buffer
   rx_break   => uart_break, -- break detected
   rx_ovrn    => OPEN,
   tx_empty   => tx_empty,   -- data buffer empty
   tx_write   => tx_write,   -- write into data buffer
   tx_data    => tx_data,    -- output data
   tx_busy    => tx_busy,
-- UART I/O
   dtr        => '1',
   rxd        => rxd,
   txd        => txd
);

END rtl;