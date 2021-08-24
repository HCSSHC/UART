`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:17:03 01/22/2021 
// Design Name: 
// Module Name:    uart_txfifo 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module uart_txfifo(
				  input 	     SCLK,
				  input 	     RST_n,
				  
				  input  [7:0]   FIFO_WR_DATA,
				  input		     FIFO_WREN,
				  input 		 FIFO_RDEN,
				  output [7:0]   FIFO_RD_DATA,
				  output		 FIFO_Empty,
				  output		 FIFO_FULL,
				  output		 FIFO_OVER,
				  output		 FIFO_UNDER
				  );

//8*32

	reg [4:0] fifo_cnt; //under,over,xxxxx32

	wire empty;
	assign empty = (fifo_cnt[4:0] == 5'b0);
	assign FIFO_Empty = empty;
	
	wire full;
	assign full = (fifo_cnt[4:0] == 5'd31);	
	assign FIFO_FULL = full;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) 		    fifo_cnt <= 5'b0;
		else
		begin
			case({FIFO_RDEN, FIFO_WREN})
			2'b00: 		  fifo_cnt <= fifo_cnt;
			2'b01: //wr
			begin
				if(full)  fifo_cnt <= fifo_cnt;
				else 	  fifo_cnt <= fifo_cnt + 1'b1;	 
			end
			2'b10: //rd
			begin
				if(empty) fifo_cnt <= fifo_cnt;
				else 	  fifo_cnt <= fifo_cnt - 1'b1;
			end			
			2'b11:  	  fifo_cnt <= fifo_cnt;	
			endcase
		end
	end	
	
	reg [4:0] fifo_wr_pointer;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)		   			fifo_wr_pointer <= 5'b0;
		else if(FIFO_WREN && !full) fifo_wr_pointer <= fifo_wr_pointer + 1'b1;
		else			   			fifo_wr_pointer <= fifo_wr_pointer;
	end

	reg [4:0] fifo_rd_pointer;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)		   			 fifo_rd_pointer <= 5'b0;
		else if(FIFO_RDEN && !empty) fifo_rd_pointer <= fifo_rd_pointer + 1'b1;
		else			   			 fifo_rd_pointer <= fifo_rd_pointer;
	end

	reg [7:0] fifo_stack [31:0];
	
	integer i;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)
		begin
			for(i = 0; i < 32; i = i + 1)
			begin
				fifo_stack[i] <= 8'b0;
			end		
		end
		else if(FIFO_WREN)
		begin
			fifo_stack[fifo_wr_pointer] <= FIFO_WR_DATA;
		end
	end

	assign FIFO_RD_DATA = fifo_stack[fifo_rd_pointer - 1'b1];

	reg OVER;

	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)		   			OVER <= 1'b0;
		else if(FIFO_WREN && !full) OVER <= 1'b1;
		else if(FIFO_RDEN)			OVER <= 1'b0;
		else			   			OVER <= OVER;
	end

	assign FIFO_OVER = OVER;

	reg UNDER;

	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)		   			 UNDER <= 1'b0;
		else if(FIFO_RDEN && !empty) UNDER <= 1'b1;
		else if(FIFO_WREN)			 UNDER <= 1'b0;
		else			   			 UNDER <= UNDER;
	end

	assign FIFO_UNDER = UNDER;

endmodule
