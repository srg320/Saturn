onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /CD_tb/cd/sh1/CLK
add wave -noupdate /CD_tb/cd/sh1/CE_F
add wave -noupdate /CD_tb/cd/sh1/CE_R
add wave -noupdate /CD_tb/cd/sh1/A
add wave -noupdate /CD_tb/cd/sh1/DI
add wave -noupdate /CD_tb/cd/sh1/DO
add wave -noupdate /CD_tb/cd/sh1/RDN
add wave -noupdate /CD_tb/cd/sh1/WRLN
add wave -noupdate /CD_tb/cd/sh1/WRHN
add wave -noupdate /CD_tb/cd/sh1/CS1N_CASHN
add wave -noupdate /CD_tb/cd/sh1/CS2N
add wave -noupdate /CD_tb/cd/sh1/CS6N
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_A
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_DI
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_DO
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_WR
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_BA
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_REQ
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/BUS_WAIT
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/STATE
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/PIPE.ID
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/PIPE.EX
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/PIPE.MA
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/PIPE.WB
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/ALU_A
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/ALU_B
add wave -noupdate /CD_tb/cd/sh1/sh7034/core/ALU_RES
add wave -noupdate /CD_tb/cd/sh1/sh7034/bsc/BUS_STATE
add wave -noupdate /CD_tb/cd/sh1/sh7034/bsc/WAIT_N
add wave -noupdate /CD_tb/cd/sh1/sh7034/bsc/NEXT_BA
add wave -noupdate /CD_tb/cd/sh1/sh7034/bsc/BUSY
add wave -noupdate {/CD_tb/cd/sh1/sh7034/core/regfile/GR[0]}
add wave -noupdate /CD_tb/cd/ygr/SH_REG_SEL
add wave -noupdate /CD_tb/cd/ygr/SA
add wave -noupdate /CD_tb/cd/ygr/SDI
add wave -noupdate /CD_tb/cd/ygr/FIFO_BUF
add wave -noupdate /CD_tb/cd/ygr/FIFO_WR_POS
add wave -noupdate /CD_tb/cd/ygr/FIFO_RD_POS
add wave -noupdate /CD_tb/cd/ygr/FIFO_AMOUNT
add wave -noupdate /CD_tb/cd/ygr/FIFO_DREQ
add wave -noupdate /CD_tb/cd/ygr/DACK1
add wave -noupdate /CD_tb/cd/ygr/BDI
add wave -noupdate /CD_tb/cd/sh1/sh7034/dmac/DMA_RD
add wave -noupdate {/CD_tb/cd/sh1/sh7034/dmac/TCR[1]}
add wave -noupdate /CD_tb/cd/sh1/sh7034/dmac/DBUS_WAIT
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2995730998 ps} 0}
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
WaveRestoreZoom {2995578451 ps} {2995834451 ps}
