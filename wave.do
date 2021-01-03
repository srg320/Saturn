onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Saturn_tb/Saturn/CE_R
add wave -noupdate /Saturn_tb/Saturn/CE_F
add wave -noupdate /Saturn_tb/Saturn/MSH/A
add wave -noupdate /Saturn_tb/Saturn/MSH/DI
add wave -noupdate /Saturn_tb/Saturn/MSH/DO
add wave -noupdate /Saturn_tb/Saturn/MSH/CS0_N
add wave -noupdate /Saturn_tb/Saturn/MSH/CS1_N
add wave -noupdate /Saturn_tb/Saturn/MSH/CS2_N
add wave -noupdate /Saturn_tb/Saturn/MSH/CS3_N
add wave -noupdate /Saturn_tb/Saturn/MSH/WE_N
add wave -noupdate /Saturn_tb/Saturn/MSH/RD_N
add wave -noupdate /Saturn_tb/Saturn/MSH/NMI_N
add wave -noupdate /Saturn_tb/Saturn/MSH/IRL_N
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_A
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_DI
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_DO
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_WR
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_BA
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_REQ
add wave -noupdate /Saturn_tb/Saturn/MSH/core/BUS_WAIT
add wave -noupdate /Saturn_tb/Saturn/MSH/core/PC
add wave -noupdate /Saturn_tb/Saturn/MSH/core/INTI
add wave -noupdate /Saturn_tb/Saturn/ROM_CS_N
add wave -noupdate /Saturn_tb/Saturn/RAML_CS_N
add wave -noupdate /Saturn_tb/Saturn/RAMH_CS_N
add wave -noupdate /Saturn_tb/ramh/ADDR
add wave -noupdate /Saturn_tb/ramh/DATA
add wave -noupdate /Saturn_tb/ramh/CS
add wave -noupdate /Saturn_tb/ramh/WREN
add wave -noupdate /Saturn_tb/Saturn/MSH/core/PIPE.EX
add wave -noupdate /Saturn_tb/Saturn/MSH/core/PIPE.MA
add wave -noupdate /Saturn_tb/Saturn/MSH/core/PIPE.WB
add wave -noupdate /Saturn_tb/Saturn/MSH/core/PIPE.WB2
add wave -noupdate /Saturn_tb/Saturn/MSH/core/ALU_A
add wave -noupdate /Saturn_tb/Saturn/MSH/core/ALU_B
add wave -noupdate /Saturn_tb/Saturn/MSH/core/ALU_RES
add wave -noupdate -expand /Saturn_tb/Saturn/MSH/core/regfile/GR
add wave -noupdate /Saturn_tb/Saturn/SCU/DMA_ST
add wave -noupdate /Saturn_tb/Saturn/SCU/BBUS_ST
add wave -noupdate /Saturn_tb/Saturn/SCU/BCSS_N
add wave -noupdate /Saturn_tb/Saturn/SCU/BADDT_N
add wave -noupdate /Saturn_tb/Saturn/BA
add wave -noupdate /Saturn_tb/Saturn/BD
add wave -noupdate /Saturn_tb/Saturn/SCSP_RAM_A
add wave -noupdate /Saturn_tb/Saturn/SCSP_RAM_D
add wave -noupdate /Saturn_tb/Saturn/SCSP_RAM_WE
add wave -noupdate /Saturn_tb/Saturn/SCSP_RAM_Q
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {187908388 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {187908203 ns} {187908459 ns}
