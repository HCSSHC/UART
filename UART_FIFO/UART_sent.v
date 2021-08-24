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
module uart_send(
				input 	     SCLK,
				input 	     RST_n,
				input [12:0] txBAUND_DATA,
				input  	     send_en,
				input  [7:0] i_SEND_DATA,
				output   reg data_tx,
				output    	 UART_TX_busy,
				output  	 sent_done
				);

	wire [12:0] BAUND_END_CNT;
	
	assign BAUND_END_CNT = txBAUND_DATA;

	reg  [7:0] data_tx_cache;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) 		 data_tx_cache <= 8'b0;
		else if(send_en) data_tx_cache <= i_SEND_DATA;
		else  			 data_tx_cache <= data_tx_cache;
	end

	reg [12:0] send_cnt;
	reg  [3:0] send_stat;
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n)						   send_cnt <= 13'b0;
		else if(send_stat == 4'b0000)	   send_cnt <= 13'b0;
		else if(send_cnt == BAUND_END_CNT) send_cnt <= 13'b0;
		else							   send_cnt <= send_cnt + 1'b1;
	end
	
	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) send_stat <= 4'b0000;  
		else
		begin
			case(send_stat)
			4'b0000: send_stat <= (send_en) ? 4'b0001 : 4'b0000;
			4'b0001: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b0010 : 4'b0001; //0 
			4'b0010: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b0011 : 4'b0010; //1 data
			4'b0011: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b0100 : 4'b0011; //2 data
			4'b0100: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b0101 : 4'b0100; //3 data
			4'b0101: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b0110 : 4'b0101; //4 data
			4'b0110: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b0111 : 4'b0110; //5 data
			4'b0111: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b1000 : 4'b0111; //6 data
			4'b1000: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b1001 : 4'b1000; //7 data
			4'b1001: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b1010 : 4'b1001; //8 data
			4'b1010: send_stat <= (send_cnt == BAUND_END_CNT) ? 4'b1011 : 4'b1010; //9
			4'b1011: send_stat <= 4'b0000; //may cause some problems
			endcase
		end
	end

	always@(posedge SCLK or negedge RST_n)
	begin
		if(!RST_n) data_tx <= 1'b1;
		else 
		begin
			case(send_stat)
			4'b0000:data_tx <= 1'b1;
			4'b0001:data_tx <= 1'b0;
			4'b0010:data_tx <= data_tx_cache[0];//7
			4'b0011:data_tx <= data_tx_cache[1];//6
			4'b0100:data_tx <= data_tx_cache[2];//5
			4'b0101:data_tx <= data_tx_cache[3];//4
			4'b0110:data_tx <= data_tx_cache[4];//3
			4'b0111:data_tx <= data_tx_cache[5];//2
			4'b1000:data_tx <= data_tx_cache[6];//1
			4'b1001:data_tx <= data_tx_cache[7];//0
			4'b1010:data_tx <= 1'b1;
			default:data_tx <= 1'b1;
			endcase
		end
	end

	assign sent_done = (send_stat == 4'b1011) ? 1'b1 : 1'b0;
	assign UART_TX_busy = (send_stat != 4'b0000) ? 1'b1 : 1'b0;

endmodule
