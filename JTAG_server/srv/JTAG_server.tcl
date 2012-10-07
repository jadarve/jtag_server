# Copyright (c) 2012 Juan David Adarve
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in 
# the Software without restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
# Software, and to permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#******************************************************************************
# JTAG TCL SERVER FOR ALTERA FPGA DESIGNS
# 
# This script is partially based on the post by Chris Zeh at
# http://idle-logic.com/2012/04/15/talking-to-the-de0-nano-using-the-virtual-jtag-interface/
#
#******************************************************************************

#************************************************
# GLOBAL VARIABLES
#************************************************
global usb_blaster_name
global test_device


proc list_device { } {
	global usb_blaster_name
	global test_device

	# select the hardware
	foreach hardware_name [get_hardware_names] {
		puts $hardware_name
		if {[string match "USB-Blaster*" $hardware_name]} {
			set usb_blaster_name $hardware_name
		}
	}

	puts "\nselected JTAG connected hardware $usb_blaster_name.\n"

	# select the device connected to the hardware
	foreach device_name [get_device_names -hardware_name $usb_blaster_name] {

		puts $device_name
		if {[string match "@1*" $device_name]} {
			set test_device $device_name
		}
	}

	puts "\nselected virtual JTAG device $test_device.\n"

}

proc open_JTAG {} {
	global usb_blaster_name
	global test_device

	list_device
	
	puts "open_JTAG: $usb_blaster_name:$test_device"
	# open a connection to the device
	open_device -hardware_name $usb_blaster_name -device_name $test_device
	device_lock -timeout 10000
}

proc close_JTAG {} {
	global usb_blaster_name
	global test_device
	
	puts "close_JTAG: $usb_blaster_name:$test_device"
	device_unlock
	close_device
}

proc jtag_IR {irCode} {
	#TODO add error handling
	if {[string is integer $irCode]} {
		device_virtual_ir_shift -instance_index 0 -ir_value $irCode -no_captured_ir_value
		return "IR:ok"
	} else {
		return "IR:error:invalid code $irCode"
	}
	
}

proc jtag_DR {string_command} {
	#TODO add error handling
	
	# gets the data to be send to the JTAG adapter
	set index [string first ":" $string_command]
	set i [expr $index - 1]
	#puts $i
	set data_value [string range $string_command 0 $i]
	
	#get the second argument (data length)
	set cLength [string length $string_command]
	set i [expr $index + 1]
	#puts $i
	set string_command [string range $string_command $i $cLength]
	set data_length $string_command
	
	if {[string is xdigit $data_value] && [string is integer $string_command]} {
		#puts "valid input command: $data_value : $data_length"
		set readOut [device_virtual_dr_shift -instance_index 0 -dr_value $data_value  -length $data_length -value_in_hex]
		return "DR:ok:$readOut"
	} else {
		return "DR:error:invalid command"
	}
}

#******************************************************************************
# TCP/IP SERVER
#******************************************************************************

global IR_instruction
global DR_instruction
set IR_instruction "ir:"
set DR_instruction "dr:"

global server_port
global connection
set server_port 2000

proc start_server { port } {
	puts "starting JTAG server..."
	set srv_socket [socket -server server_handler $port]
	
	vwait forever	;# the server is always listening for new connections
}

proc server_handler { srv_socket client_addr client_port } {
	puts "server socket $srv_socket"
	puts "receiving connection from $client_addr port: $client_port"
	
	fconfigure $srv_socket -buffering line
	fconfigure $srv_socket -encoding utf-8
	fileevent $srv_socket readable [list read_socket_data $srv_socket]
	
	puts "opening JTAG adapter"
	open_JTAG
}

proc read_socket_data { srv_socket } {
	
	if {[eof $srv_socket] || [catch { gets $srv_socket line}]}  {
		puts "closing client connection..."
		close $srv_socket
		puts "closing JTAG adapter"
		close_JTAG
	} else {
		#puts "closing connection..."
		set length [string length $line]
		if { $length != "0" } then {
			process_command $line $srv_socket
		}
	}
}

proc process_command {command channel} {
	global IR_instruction
	global DR_instruction
	
	set command [string tolower $command]
	set cLength [string length $command]
	if {$cLength < 3} {
		puts "unknown command: $command"
	} else {
		#puts "processing command: $command"
		set instruction [string range $command 0 2]
		#puts $instruction
		
		if {[string match $instruction $IR_instruction]} {
			# get the instruction code for the IR shift
			set irCode [string range $command 3 $cLength]
			if {[string length $irCode] != 0} {
				# call the IR shift procedure
				set returnValue [jtag_IR $irCode]
				puts -nonewline $channel "$returnValue;"
				flush $channel
			}
			# TODO: add no_captured_ir_value option
			
		} elseif {[string match $instruction $DR_instruction]} {
			#puts "processing DR"
			
			# get the substring with the rest of the instruction code
			set substring [string range $command 3 $cLength]
			if {[string length $substring] != 0} {
				set returnValue [jtag_DR $substring] 
				puts -nonewline $channel "$returnValue;"
				flush $channel
			}
		}
	}
}


#******************************************************************************
# STARTS THE SERVER
#******************************************************************************

start_server $server_port