onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /bench/myFPGA/reset
add wave -noupdate /bench/myFPGA/clock
add wave -noupdate /bench/myFPGA/clk
add wave -noupdate /bench/myFPGA/cycle_ctr
add wave -noupdate /bench/myFPGA/clk_en
add wave -noupdate /bench/myFPGA/uBus
add wave -noupdate /bench/myFPGA/uCore/uCntrl/r
add wave -noupdate -radix decimal /architecture_pkg/ram_chunks
add wave -noupdate -radix decimal /architecture_pkg/ram_subbits
add wave -noupdate /bench/myFPGA/SDRAM/mode_reg(0)
add wave -noupdate -divider {SDRAM control}
add wave -noupdate /bench/myFPGA/SDRAM/ext_en
add wave -noupdate /bench/myFPGA/delay
add wave -noupdate /bench/myFPGA/uBus.write
add wave -noupdate /bench/myFPGA/uBus.bytes
add wave -noupdate -radix binary -childformat {{/bench/myFPGA/SDRAM/sd_cmd(3) -radix binary} {/bench/myFPGA/SDRAM/sd_cmd(2) -radix binary} {/bench/myFPGA/SDRAM/sd_cmd(1) -radix binary} {/bench/myFPGA/SDRAM/sd_cmd(0) -radix binary}} -subitemconfig {/bench/myFPGA/SDRAM/sd_cmd(3) {-height 15 -radix binary} /bench/myFPGA/SDRAM/sd_cmd(2) {-height 15 -radix binary} /bench/myFPGA/SDRAM/sd_cmd(1) {-height 15 -radix binary} /bench/myFPGA/SDRAM/sd_cmd(0) {-height 15 -radix binary}} /bench/myFPGA/SDRAM/sd_cmd
add wave -noupdate /bench/myFPGA/SDRAM/bank
add wave -noupdate /bench/myFPGA/SDRAM/refresh_ctr
add wave -noupdate /bench/myFPGA/SDRAM/ref_ctr
add wave -noupdate /bench/myFPGA/uBus.addr
add wave -noupdate /bench/myFPGA/SDRAM/row
add wave -noupdate /bench/myFPGA/SDRAM/col
add wave -noupdate -divider SDRAM
add wave -noupdate /bench/myFPGA/SDRAM/wait_ctr
add wave -noupdate /bench/myFPGA/sd_cke
add wave -noupdate /bench/myFPGA/sd_cs_n
add wave -noupdate /bench/myFPGA/sd_we_n
add wave -noupdate /bench/myFPGA/sd_ras_n
add wave -noupdate /bench/myFPGA/sd_cas_n
add wave -noupdate /bench/myFPGA/SDRAM/sd_byte_en
add wave -noupdate /bench/myFPGA/sd_ldqm
add wave -noupdate /bench/myFPGA/sd_udqm
add wave -noupdate /bench/myFPGA/sd_a
add wave -noupdate /bench/myFPGA/sd_ba
add wave -noupdate /bench/myFPGA/sd_dq
add wave -noupdate /bench/myFPGA/SDRAM/sd_rdata_l
add wave -noupdate /bench/myFPGA/SDRAM/sd_rdata_h
add wave -noupdate /bench/myFPGA/ext_rdata
add wave -noupdate /bench/myFPGA/SDRAM/sd_state
add wave -noupdate /bench/myFPGA/uCore/uCntrl/r.tos
add wave -noupdate /bench/myFPGA/uCore/uCntrl/r.nos
add wave -noupdate /bench/myFPGA/uCore/uCntrl/prog_addr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {13760 ns} 0} {{Cursor 2} {13170 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 127
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
WaveRestoreZoom {13691 ns} {14141 ns}
