// Copyright (c) 2012 Juan David Adarve
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in 
// the Software without restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
// Software, and to permit persons to whom the Software is furnished to do so, subject
// to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
// OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module DE0_JTAG_example(
		CLOCK_50,
		LED,
		KEY 
	);
	
	//*****************************************************************************
	// PARAMETERS
	//*****************************************************************************
	parameter JTAG_SET_LEDS			= 8'h01;
	parameter JTAG_GET_LEDS			= 8'h02;

	//*****************************************************************************
	// INPUT OUTPUT DECLARATION
	//*****************************************************************************
	input wire CLOCK_50;
	input wire [1:0] KEY;
	output wire[7:0] LED;
	

	//*****************************************************************************
	// AUXILIAR SIGNALS
	//*****************************************************************************
	
	reg [7:0] reg_LED;
	wire reset_n;
	
	//**********************************
	// VJTAG interface
	//**********************************
	wire [7:0] ir_in, ir_out;	// input and output for the instruction register
	wire tdi, tdo;					// serial input and output for the data register
	wire tck;						// JTAG clock signal
	
	// virtual state signals
	wire vs_cdr, vs_cir, vs_e1dr, vs_e2dr, vs_pdr, vs_sdr, vs_udr, vs_uir;
	
	reg [7:0] shift_register;


	//*****************************************************************************
	// ASSIGNMENTS
	//*****************************************************************************
	
	assign LED[7:0] = reg_LED;
	assign reset_n = KEY[0];
	
	assign ir_out = 8'h00;
	assign tdo = tdo_output(ir_in, shift_register);

	//*****************************************************************************
	// BEHAVIORAL BLOCKS
	//*****************************************************************************
	
	// assings the value for the serial output according to the current instruction
	function tdo_output;
		input [7:0] instruction;
		input [7:0] shift_reg;
		
		begin
			case(instruction)
				JTAG_SET_LEDS: tdo_output = 1'b0;
				JTAG_GET_LEDS: tdo_output = shift_reg[0];
				default: tdo_output = 1'b0;
			endcase
		end
	endfunction
	

	always @(posedge tck or negedge reset_n)
	begin
	
		if(reset_n == 1'b0) begin
			shift_register <= 8'h00;
			reg_LED <= 8'b00;
		end
		else begin
			case(ir_in)
				JTAG_SET_LEDS: begin
					if(vs_sdr == 1'b1) begin	// shift data register
						// left serial input
						shift_register[7:0] <= {tdi, shift_register[7:1]};
					end
					
					if(vs_udr == 1'b1) begin	// update data register
						reg_LED[7:0] <= shift_register[7:0];
					end
				end
				
				JTAG_GET_LEDS: begin
					if(vs_cdr == 1'b1) begin	// capture data register
						shift_register[7:0] <= reg_LED[7:0];
					end
				
					if(vs_sdr == 1'b1) begin	// shift data register
						// left serial input
						shift_register[7:0] <= {tdi, shift_register[7:1]};
					end					
				end
			endcase
		end
	end

	//*****************************************************************************
	// STRUCTURAL BLOCKS
	//*****************************************************************************

	// Virtual JTAG module instantiation
	VJTAG vjtag_adapter (
		.ir_out(ir_out),
		.tdo(tdo),
		.ir_in(ir_in),
		.tck(tck),
		.tdi(tdi),
		.virtual_state_cdr(vs_cdr),
		.virtual_state_cir(vs_cir),
		.virtual_state_e1dr(vs_e1dr),
		.virtual_state_e2dr(vs_e2dr),
		.virtual_state_pdr(vs_pdr),
		.virtual_state_sdr(vs_sdr),
		.virtual_state_udr(vs_udr),
		.virtual_state_uir(vs_uir)
	);

endmodule
