# vivado -mode batch -source scripts/build.tcl   (run from project root; Vivado 2022.2+)
set root [file normalize [file dirname [info script]]/..]
create_project ntt_k24 $root/vivado_proj -part xck24-ubva530-2LV-c -force
add_files [glob $root/rtl/*.vhd]
set_property file_type {VHDL 2008} [get_files [glob $root/rtl/*.vhd]]
add_files -fileset sim_1 [list $root/tb/tb_ntt_core.vhd $root/tb/tb_ntt_axi.vhd]
set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets sim_1]]
set_property top tb_ntt_core [get_filesets sim_1]
set_property -name xsim.simulate.runtime -value all -objects [get_filesets sim_1]
update_compile_order -fileset sources_1

# ---- block design ----
create_bd_design system
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ps]
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__M_AXI_GP2 {0} CONFIG.PSU__FPGA_PL0_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200}] $ps
set ntt [create_bd_cell -type module -reference ntt_axi ntt0]
set smc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smc]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smc
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst0]
connect_bd_net [get_bd_pins $ps/pl_clk0] [get_bd_pins $ps/maxihpm0_fpd_aclk] \
  [get_bd_pins $smc/aclk] [get_bd_pins $ntt/s_axi_aclk] [get_bd_pins $rst/slowest_sync_clk]
connect_bd_net [get_bd_pins $ps/pl_resetn0] [get_bd_pins $rst/ext_reset_in]
connect_bd_net [get_bd_pins $rst/peripheral_aresetn] [get_bd_pins $smc/aresetn] [get_bd_pins $ntt/s_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_HPM0_FPD] [get_bd_intf_pins $smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $smc/M00_AXI] [get_bd_intf_pins $ntt/s_axi]
assign_bd_address
validate_bd_design
save_bd_design
set_property target_language VHDL [current_project]
make_wrapper -files [get_files $root/vivado_proj/ntt_k24.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse $root/vivado_proj/ntt_k24.gen/sources_1/bd/system/hdl/system_wrapper.vhd
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ---- simulate (RTL vs C reference vectors), then implement ----
launch_simulation
close_sim
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
open_run impl_1
report_utilization -file $root/utilization.rpt
report_timing_summary -file $root/timing.rpt
write_hw_platform -fixed -include_bit -force $root/ntt_k24.xsa
