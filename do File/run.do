onerror {resume}
quietly WaveActivateNextPane {} 0

# ==============================================================================
# 1. Create and Map Work Library
# ==============================================================================
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# ==============================================================================
# 2. Compile Design Units & Testbench (Exact Filenames)
# ==============================================================================
vlog -sv APB_Address_Decoder.v
vlog -sv APB_Master_Controller.v
vlog -sv APB_Slave_Controller.v
vlog -sv APB_Top_Module.v
vlog -sv APB_Top_tb.v

# ==============================================================================
# 3. Start Simulation
# ==============================================================================
vsim -voptargs="+acc" work.tb_apb_subsystem

# ==============================================================================
# 4. Set Hierarchy Signal Paths
# ==============================================================================
set TB  /tb_apb_subsystem
set DUT $TB/dut

# ==============================================================================
# 5. Define FSM State Radix
# ==============================================================================
radix define APB_STATE_T {
    2'b00 "IDLE"
    2'b01 "SETUP"
    2'b10 "ACCESS"
    -default binary
}

# ==============================================================================
# 6. Add Signals Organized by Category & Color
# ==============================================================================

# Category 1: Clock & Reset
add wave -noupdate -group {Clock_and_Reset} -color Yellow                 $TB/pclk
add wave -noupdate -group {Clock_and_Reset} -color Yellow                 $TB/prstn

# Category 2: System Request Interface (TB -> Subsystem Top)
add wave -noupdate -group {System_Request_Interface} -color Green         $TB/req_valid
add wave -noupdate -group {System_Request_Interface} -color Green         $TB/req_write
add wave -noupdate -group {System_Request_Interface} -color Green -radix hexadecimal $TB/req_addr
add wave -noupdate -group {System_Request_Interface} -color Green -radix hexadecimal $TB/req_wdata
add wave -noupdate -group {System_Request_Interface} -color Green -radix binary      $TB/req_strb
add wave -noupdate -group {System_Request_Interface} -color Green -radix binary      $TB/req_prot

# Category 3: System Response Interface (Subsystem Top -> TB)
add wave -noupdate -group {System_Response_Interface} -color {Sky Blue}   $TB/req_ready
add wave -noupdate -group {System_Response_Interface} -color {Sky Blue}   $TB/rsp_valid
add wave -noupdate -group {System_Response_Interface} -color {Sky Blue}   $TB/rsp_error
add wave -noupdate -group {System_Response_Interface} -color {Sky Blue}   $TB/busy
add wave -noupdate -group {System_Response_Interface} -color {Sky Blue}   $TB/done
add wave -noupdate -group {System_Response_Interface} -color {Sky Blue} -radix hexadecimal $TB/rsp_rdata

# Category 4: APB Interconnect & Master Bus Signals
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange         $DUT/psel_master
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange         $DUT/penable
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange         $DUT/pwrite
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange -radix hexadecimal $DUT/paddr
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange -radix hexadecimal $DUT/pwdata
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange -radix binary      $DUT/pstrb
add wave -noupdate -group {APB_Master_Bus_Outputs} -color Orange -radix binary      $DUT/pprot

# Category 5: Address Decoder
add wave -noupdate -group {Address_Decoder} -color Cyan                   $DUT/psel1_raw
add wave -noupdate -group {Address_Decoder} -color Cyan                   $DUT/psel2_raw
add wave -noupdate -group {Address_Decoder} -color Cyan                   $DUT/psel1
add wave -noupdate -group {Address_Decoder} -color Cyan                   $DUT/psel2

# Category 6: Slave 1 Signals (Base: 0x0000_0000)
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue}         $DUT/u_slave_1/psel
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue}         $DUT/u_slave_1/penable
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue}         $DUT/pready_s1
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue}         $DUT/pslverr_s1
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue} -radix hexadecimal $DUT/prdata_s1
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue} -radix hexadecimal $DUT/u_slave_1/local_addr
add wave -noupdate -group {Slave_1_Interface} -color {Light Blue} -radix decimal     $DUT/u_slave_1/word_index

# Category 7: Slave 2 Signals (Base: 0x0000_4000)
add wave -noupdate -group {Slave_2_Interface} -color Coral                $DUT/u_slave_2/psel
add wave -noupdate -group {Slave_2_Interface} -color Coral                $DUT/u_slave_2/penable
add wave -noupdate -group {Slave_2_Interface} -color Coral                $DUT/pready_s2
add wave -noupdate -group {Slave_2_Interface} -color Coral                $DUT/pslverr_s2
add wave -noupdate -group {Slave_2_Interface} -color Coral -radix hexadecimal $DUT/prdata_s2
add wave -noupdate -group {Slave_2_Interface} -color Coral -radix hexadecimal $DUT/u_slave_2/local_addr
add wave -noupdate -group {Slave_2_Interface} -color Coral -radix decimal     $DUT/u_slave_2/word_index

# Category 8: Muxed Response (Slaves -> Master)
add wave -noupdate -group {Muxed_Bus_Response} -color Red                 $DUT/pready_bus
add wave -noupdate -group {Muxed_Bus_Response} -color Red                 $DUT/pslverr_bus
add wave -noupdate -group {Muxed_Bus_Response} -color Red -radix hexadecimal $DUT/prdata_bus

# Category 9: APB Master Internal FSM
add wave -noupdate -group {Master_Internal_FSM} -color Magenta -radix APB_STATE_T $DUT/u_apb_master/current_state
add wave -noupdate -group {Master_Internal_FSM} -color Magenta -radix APB_STATE_T $DUT/u_apb_master/next_state

# Category 10: Testbench Helper Variables
add wave -noupdate -group {TB_Variables} -color White -radix hexadecimal $TB/read_data_buf

# ==============================================================================
# 7. Configure Wave Window Display Settings
# ==============================================================================
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 260
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 10
configure wave -griddelta 40
configure wave -timeline 0
update

# ==============================================================================
# 8. Run Simulation & Auto-Fit Waveform
# ==============================================================================
run -all
wave zoom full