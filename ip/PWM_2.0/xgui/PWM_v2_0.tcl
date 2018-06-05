package require xilinx::board 1.0
namespace import ::xilinx::board::*

proc get_pwm_vlnv {} {
	return "xilinx.com:interface:gpio_rtl:1.0"
}

proc init_params {IPINST PARAM_VALUE.PWM_BOARD_IF} {
	set_property preset_proc "PWM_BOARD_IF_PRESET" ${PARAM_VALUE.PWM_BOARD_IF}
}

proc PWM_BOARD_IF_PRESET {IPINST PRESET_VALUE} {
	if { $PRESET_VALUE == "Custom" } {
		return ""
	}
	set board [::ipxit::get_project_property BOARD]
	set vlnv [get_property ipdef $IPINST] 
	set preset_params [board_ip_presets $vlnv $PRESET_VALUE $board "PWM_GPIO"]
	if { $preset_params != "" } {
		return $preset_params
	} else {
		return ""
	}
}
proc init_gui { IPINST PROJECT_PARAM.ARCHITECTURE PROJECT_PARAM.BOARD } {
    set c_family ${PROJECT_PARAM.ARCHITECTURE}
    set board ${PROJECT_PARAM.BOARD}
    set Component_Name [ ipgui::add_param  $IPINST  -parent  $IPINST  -name Component_Name ]
    add_board_tab $IPINST
    #Adding Page
    set Page_0 [ipgui::add_page $IPINST -name "Properties"]
    set NUM_PWM [ipgui::add_param $IPINST -name "NUM_PWM" -parent ${Page_0}]
    set_property tooltip {Number of PWM signals to output} ${NUM_PWM}
    set POLARITY [ipgui::add_param $IPINST -name "POLARITY" -parent ${Page_0} -widget comboBox]
    set_property tooltip {The polarity of the output pulse. Setting this to Low will cause larger duty cycle values to result in smaller pulses} ${POLARITY}
    set USE_GPIO [ipgui::add_param $IPINST -name "USE_GPIO"]
    set_property tooltip {Enable Xilinx GPIO Interface} ${USE_GPIO}
}

proc update_PARAM_VALUE.PWM_BOARD_IF {IPINST PARAM_VALUE.PWM_BOARD_IF PROJECT_PARAM.BOARD} {
	set param_range [get_board_interface_param_range $IPINST -name "PWM_BOARD_IF"]
	set candidate_range [split $param_range ","]
	set filtered_range [list]
	foreach var $candidate_range {
		set tri_o [get_board_part_pins_of_intf_port $var TRI_O]
		set tri_i [get_board_part_pins_of_intf_port $var TRI_I]
        # Only allow GPIO interfaces taht are not "input only"
		if { $tri_o ne "" || $tri_i eq "" } {
			lappend filtered_range $var
		}
	}
	set_property range [join $filtered_range ","] ${PARAM_VALUE.PWM_BOARD_IF}
}

proc update_PARAM_VALUE.NUM_PWM {PARAM_VALUE.NUM_PWM PARAM_VALUE.PWM_BOARD_IF PROJECT_PARAM.BOARD} {
    set boardIfName [get_property value ${PARAM_VALUE.PWM_BOARD_IF}]
    if { $boardIfName ne "Custom" } {
	    set boardIfName [get_property value ${PARAM_VALUE.PWM_BOARD_IF}]
	   	set tri_o [get_board_part_pins_of_intf_port $boardIfName TRI_O]
		set port_width [get_width_of_intf_port $boardIfName TRI_O]
		set_property value $port_width ${PARAM_VALUE.NUM_PWM}
		set_property enabled false ${PARAM_VALUE.NUM_PWM}
	} else {
		set_property enabled true ${PARAM_VALUE.NUM_PWM}
	}
}

proc update_PARAM_VALUE.POLARITY { IPINST PARAM_VALUE.POLARITY PARAM_VALUE.PWM_BOARD_IF PROJECT_PARAM.BOARD } {
    set boardIfName [get_property value ${PARAM_VALUE.PWM_BOARD_IF}]
    if { $boardIfName ne "Custom" } {
	    set boardIfName [get_property value ${PARAM_VALUE.PWM_BOARD_IF}]
        set preset [PWM_BOARD_IF_PRESET $IPINST $boardIfName]
        set idx [expr 1 + [lsearch $preset "CONFIG.POLARITY"]]
        set polarity "[lindex $preset $idx]"
        set_property value {"$polarity"} ${PARAM_VALUE.POLARITY}
        puts "DEV_INFO: [get_property range ${PARAM_VALUE.POLARITY}]"
		set_property enabled false ${PARAM_VALUE.POLARITY}
	} else {
		set_property enabled true ${PARAM_VALUE.POLARITY}
	}
}

proc update_PARAM_VALUE.USE_GPIO { PARAM_VALUE.USE_GPIO PARAM_VALUE.PWM_BOARD_IF PROJECT_PARAM.BOARD } {
    set boardIfName [get_property value ${PARAM_VALUE.PWM_BOARD_IF}]
    if { $boardIfName ne "Custom" } {
        set_property value true ${PARAM_VALUE.USE_GPIO}
		set_property enabled false ${PARAM_VALUE.USE_GPIO}
	} else {
		set_property enabled true ${PARAM_VALUE.USE_GPIO}
	}
}

proc update_PARAM_VALUE.C_PWM_AXI_DATA_WIDTH { PARAM_VALUE.C_PWM_AXI_DATA_WIDTH } {}
proc update_PARAM_VALUE.C_PWM_AXI_ADDR_WIDTH { PARAM_VALUE.C_PWM_AXI_ADDR_WIDTH } {}
proc update_PARAM_VALUE.C_PWM_AXI_BASEADDR { PARAM_VALUE.C_PWM_AXI_BASEADDR } {}
proc update_PARAM_VALUE.C_PWM_AXI_HIGHADDR { PARAM_VALUE.C_PWM_AXI_HIGHADDR } {}

proc update_MODELPARAM_VALUE.C_PWM_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_PWM_AXI_DATA_WIDTH PARAM_VALUE.C_PWM_AXI_DATA_WIDTH } {
	set_property value [get_property value ${PARAM_VALUE.C_PWM_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_PWM_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_PWM_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_PWM_AXI_ADDR_WIDTH PARAM_VALUE.C_PWM_AXI_ADDR_WIDTH } {
	set_property value [get_property value ${PARAM_VALUE.C_PWM_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_PWM_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.NUM_PWM { MODELPARAM_VALUE.NUM_PWM PARAM_VALUE.NUM_PWM } {
	set_property value [get_property value ${PARAM_VALUE.NUM_PWM}] ${MODELPARAM_VALUE.NUM_PWM}
}

proc update_MODELPARAM_VALUE.POLARITY { MODELPARAM_VALUE.POLARITY PARAM_VALUE.POLARITY } {
	set_property value [get_property value ${PARAM_VALUE.POLARITY}] ${MODELPARAM_VALUE.POLARITY}
}

proc validate_PARAM_VALUE.PWM_BOARD_IF { PARAM_VALUE.PWM_BOARD_IF IPINST PROJECT_PARAM.BOARD } {
	return true
}

proc validate_PARAM_VALUE.NUM_PWM { PARAM_VALUE.NUM_PWM } {
	return true
}

proc validate_PARAM_VALUE.POLARITY { PARAM_VALUE.POLARITY } {
	return true
}

proc validate_PARAM_VALUE.USE_GPIO { PARAM_VALUE.USE_GPIO } {
	return true
}

proc validate_PARAM_VALUE.C_PWM_AXI_DATA_WIDTH { PARAM_VALUE.C_PWM_AXI_DATA_WIDTH } {
	return true
}

proc validate_PARAM_VALUE.C_PWM_AXI_ADDR_WIDTH { PARAM_VALUE.C_PWM_AXI_ADDR_WIDTH } {
	return true
}

proc validate_PARAM_VALUE.C_PWM_AXI_BASEADDR { PARAM_VALUE.C_PWM_AXI_BASEADDR } {
	return true
}

proc validate_PARAM_VALUE.C_PWM_AXI_HIGHADDR { PARAM_VALUE.C_PWM_AXI_HIGHADDR } {
	return true
}