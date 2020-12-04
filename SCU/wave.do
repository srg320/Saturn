onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /SCU_tb/scu/CLK
add wave -noupdate /SCU_tb/scu/CE_R
add wave -noupdate /SCU_tb/scu/A
add wave -noupdate /SCU_tb/scu/DI
add wave -noupdate /SCU_tb/scu/DO
add wave -noupdate /SCU_tb/scu/WR
add wave -noupdate /SCU_tb/scu/RD
add wave -noupdate /SCU_tb/scu/dsp/RUN
add wave -noupdate /SCU_tb/scu/dsp/IC
add wave -noupdate /SCU_tb/scu/dsp/DECI
add wave -noupdate /SCU_tb/scu/dsp/PC
add wave -noupdate /SCU_tb/scu/dsp/AC
add wave -noupdate /SCU_tb/scu/dsp/P
add wave -noupdate /SCU_tb/scu/dsp/RX
add wave -noupdate /SCU_tb/scu/dsp/RY
add wave -noupdate /SCU_tb/scu/dsp/EX
add wave -noupdate /SCU_tb/scu/dsp/EP
add wave -noupdate /SCU_tb/scu/dsp/PR
add wave -noupdate /SCU_tb/scu/dsp/ES
add wave -noupdate /SCU_tb/scu/dsp/LE
add wave -noupdate /SCU_tb/scu/dsp/CT0
add wave -noupdate /SCU_tb/scu/dsp/CT1
add wave -noupdate /SCU_tb/scu/dsp/CT2
add wave -noupdate /SCU_tb/scu/dsp/CT3
add wave -noupdate /SCU_tb/scu/dsp/RA0
add wave -noupdate /SCU_tb/scu/dsp/TN0
add wave -noupdate /SCU_tb/scu/dsp/T0
add wave -noupdate /SCU_tb/scu/dsp/D1BUS
add wave -noupdate /SCU_tb/scu/dsp/XBUS
add wave -noupdate /SCU_tb/scu/dsp/YBUS
add wave -noupdate /SCU_tb/scu/dsp/ALU_Q
add wave -noupdate /SCU_tb/scu/dsp/ALU_C
add wave -noupdate /SCU_tb/scu/dsp/DMA_A
add wave -noupdate /SCU_tb/scu/dsp/DMA_DI
add wave -noupdate /SCU_tb/scu/dsp/DMA_DO
add wave -noupdate /SCU_tb/scu/dsp/DMA_WR
add wave -noupdate /SCU_tb/scu/dsp/DMA_REQ
add wave -noupdate /SCU_tb/scu/dsp/DMA_ACK
add wave -noupdate /SCU_tb/scu/dsp/PRG_RAM_Q
add wave -noupdate /SCU_tb/scu/dsp/DATA_RAM0/dpram/MEM
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {515 ns} 0}
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
WaveRestoreZoom {0 ns} {250 ns}
