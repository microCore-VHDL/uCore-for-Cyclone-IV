# RZ-EASY FPGA Cyclone IV EP4CE6 prototyping board
microCore implemented on the simple RZ-EASY prototyping board with the EP4CE6 FPGA.<BR>
Running @ 33 MHz ~ 25 M Forth instructions / second.<BR>
Its RS232 UART is used as a umbilical link connecting to the host system that runs the cross-compiler and interactive debugger.<BR>
Its row of 4 LEDs is used for signalling.<BR>
Input buttons can be read in the flag register.<BR>
The SDRAM has been integrated in the design for a 64k x 16 memory size.
architecture files have been added for 16, 27, and 32 bit cell addressed machines.
