onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /SCSP_tb/SCSP/CLK
add wave -noupdate /SCSP_tb/SCSP/SCCE_R
add wave -noupdate /SCSP_tb/SCSP/SCCE_F
add wave -noupdate /SCSP_tb/SCSP/SCA_DBG
add wave -noupdate /SCSP_tb/M68K/iEdb
add wave -noupdate /SCSP_tb/M68K/oEdb
add wave -noupdate /SCSP_tb/M68K/eRWn
add wave -noupdate /SCSP_tb/M68K/ASn
add wave -noupdate /SCSP_tb/M68K/LDSn
add wave -noupdate /SCSP_tb/M68K/UDSn
add wave -noupdate /SCSP_tb/M68K/DTACKn
add wave -noupdate /SCSP_tb/SCSP/MEM_ST
add wave -noupdate /SCSP_tb/SCSP/MEM_A
add wave -noupdate /SCSP_tb/SCSP/MEM_D
add wave -noupdate /SCSP_tb/SCSP/MEM_Q
add wave -noupdate /SCSP_tb/SCSP/MEM_WE
add wave -noupdate /SCSP_tb/SCSP/MEM_RD
add wave -noupdate /SCSP_tb/SCSP/MEM_CS
add wave -noupdate /SCSP_tb/SCSP/REG_CS
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2999951 ns} 0}
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
WaveRestoreZoom {2999050 ns} {3000050 ns}
