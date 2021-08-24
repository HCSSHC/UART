`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:17:03 01/22/2021 
// Design Name: 
// Module Name:    Serial 
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
module uart_receive(
				   input 			SCLK,
				   input 			RST_n,
				   input 	 [12:0] rxBAUND_DATA,		   
				   input 			data_rx,
				   output reg [7:0] o_RECEIVED_DATA,
				   output 	 		UART_RX_busy,
				   output 	 		receive_done
				   );

	wire [12:0] BAUND_END_CNT;
	
	assign BAUND_END_CNT = rxBAUND_DATA;

	assign receive_half_cnt = (BAUND_END_CNT >> 1);
	
	reg data_rx_0;
	reg data_rx_1;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(RST_n == 1'b0)
		begin
			data_rx_0 <= 1'b0;
			data_rx_1 <= 1'b0;	
		end
		else
		begin
			data_rx_0 <= data_rx;
			data_rx_1 <= data_rx_0;
		end
	end

	wire start_receive;
	assign start_receive = data_rx_1 && ~data_rx_0;
	
	reg [12:0] receive_cnt;
	reg [3:0] receive_stat;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)							  receive_cnt <= 13'b0;
		else if(receive_stat == 4'b0000)	  receive_cnt <= 13'b0;
		else if(receive_cnt == BAUND_END_CNT) receive_cnt <= 13'b0;
		else								  receive_cnt <= receive_cnt + 1'b1;
	end
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) receive_stat <= 4'b0000;  
		else
		begin
			case(receive_stat)
			4'b0000: receive_stat <= (start_receive) ? 4'b0001 : 4'b0000;
			4'b0001: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b0010 : 4'b0001; //0 
			4'b0010: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b0011 : 4'b0010; //1 data
			4'b0011: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b0100 : 4'b0011; //2 data
			4'b0100: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b0101 : 4'b0100; //3 data
			4'b0101: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b0110 : 4'b0101; //4 data
			4'b0110: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b0111 : 4'b0110; //5 data
			4'b0111: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b1000 : 4'b0111; //6 data
			4'b1000: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b1001 : 4'b1000; //7 data
			4'b1001: receive_stat <= (receive_cnt == BAUND_END_CNT) ? 4'b1010 : 4'b1001; //8 data
			4'b1010: receive_stat <= (receive_cnt == receive_half_cnt) ? 4'b1011 : 4'b1010; //9
			4'b1011: receive_stat <= 4'b0000;
			endcase
		end
	end

	reg [7:0] data_inter_cache;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) data_inter_cache <= 8'b0000;  
		else if(receive_cnt == receive_half_cnt)
		begin
			case(receive_stat)
			4'b0010: data_inter_cache[0] <= data_rx;
			4'b0011: data_inter_cache[1] <= data_rx;
			4'b0100: data_inter_cache[2] <= data_rx;
			4'b0101: data_inter_cache[3] <= data_rx;
			4'b0110: data_inter_cache[4] <= data_rx;
			4'b0111: data_inter_cache[5] <= data_rx;
			4'b1000: data_inter_cache[6] <= data_rx;
			4'b1001: data_inter_cache[7] <= data_rx;
			default: data_inter_cache <= data_inter_cache;
			endcase
		end
		else data_inter_cache <= data_inter_cache;
	end
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) 						 o_RECEIVED_DATA <= 8'b0;
		else if(receive_stat == 4'b1010) o_RECEIVED_DATA <= data_inter_cache;
		else							 o_RECEIVED_DATA <= o_RECEIVED_DATA;
	end
	
	assign receive_done = (receive_stat == 4'b1011) ? 1'b1 : 1'b0;
	assign UART_RX_busy = (receive_stat != 4'b0000) ? 1'b1 : 1'b0;
	
endmodule
