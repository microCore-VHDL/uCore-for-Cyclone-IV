-- ---------------------------------------------------------------------
-- @file : arbitration.vhd
-- ---------------------------------------------------------------------
--
-- Author: Klaus Schleisiek
-- Last change: KS 04.04.2021 18:35:14
-- Project: arbitration test
-- Language: VHDL-93
--
-- ---------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY bench IS
END bench;

ARCHITECTURE testbench OF bench IS

BEGIN

oscillator: PROCESS
BEGIN
  clk <= '0';
  WAIT FOR 150 ns;
  LOOP
    WAIT FOR 50 ns;
    clk <= '1';
    WAIT FOR 50 ns;
    clk <= '0';
  END LOOP;
END PROCESS oscillator;

END testbench;
