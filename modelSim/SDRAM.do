onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /bench/myFPGA/reset
add wave -noupdate /bench/myFPGA/clock
add wave -noupdate /bench/myFPGA/clk
add wave -noupdate /bench/myFPGA/cycle_ctr
add wave -noupdate /bench/myFPGA/clk_en
add wave -noupdate /bench/myFPGA/uBus
add wave -noupdate /bench/myFPGA/uCore/uCntrl/prog_addr
add wave -noupdate -divider {SDRAM control}
add wave -noupdate /bench/myFPGA/SDRAM/ext_en
add wave -noupdate /bench/myFPGA/delay
add wave -noupdate /bench/myFPGA/uBus.write
add wave -noupdate -radix binary /bench/myFPGA/SDRAM/sd_cmd
add wave -noupdate /bench/myFPGA/SDRAM/row
add wave -noupdate /bench/myFPGA/SDRAM/col
add wave -noupdate /bench/myFPGA/SDRAM/wait_ctr
add wave -noupdate /bench/myFPGA/SDRAM/refresh_ctr
add wave -noupdate /bench/myFPGA/SDRAM/ref_ctr
add wave -noupdate -divider SDRAM
add wave -noupdate /bench/myFPGA/sd_clk
add wave -noupdate /bench/myFPGA/sd_cke
add wave -noupdate /bench/myFPGA/sd_cs_n
add wave -noupdate /bench/myFPGA/sd_we_n
add wave -noupdate /bench/myFPGA/sd_ras_n
add wave -noupdate /bench/myFPGA/sd_cas_n
add wave -noupdate /bench/myFPGA/sd_ldqm
add wave -noupdate /bench/myFPGA/sd_udqm
add wave -noupdate /bench/myFPGA/sd_a
add wave -noupdate /bench/myFPGA/sd_ba
add wave -noupdate /bench/myFPGA/sd_dq
add wave -noupdate /bench/myFPGA/ext_rdata
add wave -noupdate /bench/myFPGA/SDRAM/sd_state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {117369 ns} 0} {{Cursor 2} {102360 ns} 0}
quietly wave cursor active 2
configure wave -namecolwidth 111
configure wave -valuecolwidth 108
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {102587 ns} {103015 ns}
