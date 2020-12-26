onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /VDP2_tb/VDP2/CLK
add wave -noupdate /VDP2_tb/VDP2/HS_N
add wave -noupdate /VDP2_tb/VDP2/VS_N
add wave -noupdate /VDP2_tb/VDP2/HBL_N
add wave -noupdate /VDP2_tb/VDP2/VBL_N
add wave -noupdate /VDP2_tb/VDP2/DOT_CE
add wave -noupdate {/VDP2_tb/VDP2/VA_PIPE[0].H_CNT}
add wave -noupdate {/VDP2_tb/VDP2/VA_PIPE[0].V_CNT}
add wave -noupdate /VDP2_tb/VDP2/ACCESS_TIME
add wave -noupdate -expand {/VDP2_tb/VDP2/VA_PIPE[0]}
add wave -noupdate /VDP2_tb/VDP2/N0CH_ADDR_LSB
add wave -noupdate -expand {/VDP2_tb/VDP2/VA_PIPE[1]}
add wave -noupdate /VDP2_tb/VDP2/VRAMA0_ADDR
add wave -noupdate /VDP2_tb/VDP2/VRAMA1_ADDR
add wave -noupdate /VDP2_tb/VDP2/RA0_DI
add wave -noupdate /VDP2_tb/VDP2/RA1_DI
add wave -noupdate /VDP2_tb/VDP2/PN0
add wave -noupdate -expand /VDP2_tb/VDP2/CD0
add wave -noupdate /VDP2_tb/VDP2/DCOL
add wave -noupdate /VDP2_tb/VDP2/R
add wave -noupdate /VDP2_tb/VDP2/G
add wave -noupdate /VDP2_tb/VDP2/B
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {731 ns} 0}
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
WaveRestoreZoom {1059 ns} {2067 ns}
