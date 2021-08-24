`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:17:03 01/22/2021 
// Design Name: 
// Module Name:    Serial_UART 
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
module Serial_UART(
				  input	  	 		 UART_CLK,
				  input	  	 		 UART_RST_n,
				  
				  input 	         UART_WR_VALID, //BUS_interface
				  output 	 	     UART_WR_READY, //BUS_interface
				  input 	         UART_RD_READY, //BUS_interface
				  output 	 	     UART_RD_VALID, //BUS_interface
				  input       [31:0] UART_I_DATA,   //BUS_interface
				  input       [31:0] UART_I_ADDR,   //BUS_interface
				  output reg  [31:0] UART_O_DATA,   //BUS_interface
				  
				  input	    		 UART_RX,	 	//RX_unit_ports
				  output 	   	 	 UART_TX	 	//TX_unit_ports
				  );
////////////////////////////////////////////interface
//0x00011000 TX
//0x00011001 RX
//0x00011002 BAUND
//0x00011003 STATUS
////////////////////////////////////////////ADDR_part
	wire is_SUART_TX;		   
	wire is_SUART_RX;		   
	wire is_SUART_BAUND;		   
	wire is_SUART_STATUS;		   
	
	assign is_SUART_TX 	   = (UART_I_ADDR == 32'h00011000) ? 1'b1 : 1'b0;//UART		   
	assign is_SUART_RX 	   = (UART_I_ADDR == 32'h00011001) ? 1'b1 : 1'b0;//UART		   
	assign is_SUART_BAUND  = (UART_I_ADDR == 32'h00011002) ? 1'b1 : 1'b0;//UART		   
	assign is_SUART_STATUS = (UART_I_ADDR == 32'h00011003) ? 1'b1 : 1'b0;//UART		  

	assign is_UART_ADDR = is_SUART_TX | is_SUART_RX | is_SUART_BAUND | is_SUART_STATUS;

	wire   BUS_ACCESS;
	assign BUS_ACCESS = (UART_WR_VALID | UART_RD_READY)	? 1'b1 : 1'b0;	
////////////////////////////////////////////bus_FSM
localparam INTERFACE_FSM_0 	    = 3'd0;
localparam INTERFACE_FSM_WR		= 3'd1;
localparam INTERFACE_FSM_RD		= 3'd2;
localparam INTERFACE_FSM_ready  = 3'd3;

	reg  [2:0] INTERFACE_FSM;
	wire WR_DATA_done;
	wire RD_DATA_done;

	always@(posedge UART_CLK or negedge UART_RST_n)
	begin
		if(!UART_RST_n) INTERFACE_FSM <= INTERFACE_FSM_0;
		else
		begin
			case(INTERFACE_FSM)
			INTERFACE_FSM_0:
			begin
				if(UART_WR_VALID & is_UART_ADDR)      INTERFACE_FSM <= INTERFACE_FSM_WR;
				else if(UART_RD_READY & is_UART_ADDR) INTERFACE_FSM <= INTERFACE_FSM_RD;
				else				   				  INTERFACE_FSM <= INTERFACE_FSM_0;
			end
			INTERFACE_FSM_WR: //tx_fifo
			begin
				if(WR_DATA_done)
				begin
					INTERFACE_FSM <= INTERFACE_FSM_ready;
				end
				else INTERFACE_FSM <= INTERFACE_FSM_WR;
			end			
			INTERFACE_FSM_RD: //rx_fifo
			begin
				if(RD_DATA_done)
				begin
					INTERFACE_FSM <= INTERFACE_FSM_ready;
				end
				else INTERFACE_FSM <= INTERFACE_FSM_RD;
			end		
			INTERFACE_FSM_ready: INTERFACE_FSM <= INTERFACE_FSM_0;//status
			endcase
		end
	end		
	
	assign UART_WR_READY = ((INTERFACE_FSM == INTERFACE_FSM_ready) && UART_WR_VALID) ? 1'b1 : 1'b0;
	assign UART_RD_VALID = ((INTERFACE_FSM == INTERFACE_FSM_ready) && UART_RD_READY) ? 1'b1 : 1'b0;
	
//////////////////////////////////////////AUTOFIFO_BURST	
//WR_tx_fifo
	reg  [2:0] txFIFO_FSM;
	reg  	   txFIFO_WREN; 
	wire [3:0] UART_status_reg;	//
	wire [7:0] FIFO_status_reg;		
	reg		   BAUND_WREN;
	
	always@(posedge UART_CLK or negedge UART_RST_n)
	begin
		if(!UART_RST_n)	
		begin
			txFIFO_FSM  <= 3'b0;
			txFIFO_WREN <= 1'b0;
			BAUND_WREN  <= 1'b0;
		end
		else 
		begin
			case(txFIFO_FSM)
			3'd0: //start
			begin
				txFIFO_FSM  <= (UART_WR_VALID) ? (is_SUART_TX ? 3'd1 : (is_SUART_BAUND ? 3'd3 : 3'd0)) : 3'd0; //TXFIFO+BAUND
				txFIFO_WREN <= 1'b0;
				BAUND_WREN  <= 1'b0;
			end
			3'd1: //FIFO_full?
			begin
				txFIFO_FSM  <= FIFO_status_reg[6] ? 3'd1 : 3'd2;
				txFIFO_WREN <= 1'b0;
				BAUND_WREN  <= 1'b0;				
			end
			3'd2: //WREN
			begin
				txFIFO_FSM  <= 3'd4;
				txFIFO_WREN <= 1'b1;
				BAUND_WREN  <= 1'b0;					
			end	
			3'd3:
			begin
				txFIFO_FSM  <= 3'd4;
				txFIFO_WREN <= 1'b0;
				BAUND_WREN  <= 1'b1;					
			end				
			3'd4: //wait interface ready
			begin
				txFIFO_FSM  <= (INTERFACE_FSM == INTERFACE_FSM_ready) ? 3'd0 : 3'd4;
				txFIFO_WREN <= 1'b0;
				BAUND_WREN  <= 1'b0;					
			end				
			default:
			begin
				txFIFO_FSM  <= 3'b0;
				txFIFO_WREN <= 1'b0;
				BAUND_WREN  <= 1'b0;					
			end				
			endcase
		end	
	end		

//////////////////////////////////////////BAUND_data
	reg [12:0] BAUND_END_CNT;
	
	always@(posedge UART_CLK or negedge UART_RST_n)
	begin
		if(!UART_RST_n) 	BAUND_END_CNT <= 9'd434;
		else if(BAUND_WREN) BAUND_END_CNT <= UART_I_DATA;
		else  			 	BAUND_END_CNT <= BAUND_END_CNT;
	end	
//////////////////////////////////////////
	wire [7:0] txFIFO_RD_DATA;
	reg 	  txFIFO_RDEN;
	reg 	  txSEND_EN;

	uart_txfifo tx_fifo(
					   .SCLK		 (UART_CLK),	
					   .RST_n        (UART_RST_n),
					   
					   .FIFO_WR_DATA (UART_I_DATA),
					   .FIFO_WREN    (txFIFO_WREN),			
					   .FIFO_RDEN    (txFIFO_RDEN),			
					   .FIFO_RD_DATA (txFIFO_RD_DATA),			
					   .FIFO_Empty   (FIFO_status_reg[7]),			
					   .FIFO_FULL    (FIFO_status_reg[6]),			
					   .FIFO_OVER    (FIFO_status_reg[5]),			
					   .FIFO_UNDER   (FIFO_status_reg[4])			
					   );

	uart_send u_send_0 (
					   .SCLK        	(UART_CLK),
					   .RST_n      		(UART_RST_n),
					   .txBAUND_DATA    (BAUND_END_CNT),
					   .data_tx     	(UART_TX),
					   .send_en     	(txSEND_EN),
					   .i_SEND_DATA 	(txFIFO_RD_DATA),
					   .UART_TX_busy    (UART_status_reg[3]),
					   .sent_done   	(UART_status_reg[2])
					   );	
//AUTO sender
	wire   txFIFO_Empty;
	assign txFIFO_Empty = FIFO_status_reg[7];
	wire   txFIFO_sent_done;
	assign txFIFO_sent_done = FIFO_status_reg[2];


	reg [1:0] tx_FSM;
	
	always@(posedge UART_CLK or negedge UART_RST_n)
	begin
		if(!UART_RST_n)
		begin
			tx_FSM 		<= 2'b0;		
			txFIFO_RDEN <= 1'b0;
			txSEND_EN 	<= 1'b0;
		end
		else 
		begin
			case(tx_FSM)
			2'd0:
			begin
				tx_FSM 		<= txFIFO_Empty ? 2'd0 : 2'd1;			
				txFIFO_RDEN <= 1'b0;
				txSEND_EN 	<= 1'b0;
			end
			2'd1: //auto sent
			begin
				tx_FSM 		<= 2'd2;			
				txFIFO_RDEN <= 1'b1;
				txSEND_EN 	<= 1'b0;
			end
			2'd2:
			begin
				tx_FSM 		<= 2'd3;			
				txFIFO_RDEN <= 1'b0;
				txSEND_EN 	<= 1'b1;
			end			
			2'd3:
			begin
				tx_FSM 		<= UART_status_reg[2] ? 2'd0 : 2'd3;			
				txFIFO_RDEN <= 1'b0;
				txSEND_EN 	<= 1'b0;
			end
			endcase
		end	
	end	
	
	assign WR_DATA_done = (txFIFO_FSM == 3'd4);

//////////////////////////////////////////
	wire [7:0] UART_DATA_RECED;
	wire [7:0] rxFIFO_READ;
	reg 	  rxFIFO_RDEN; 
	
	uart_receive   u_receive_0 (
							   .SCLK            (UART_CLK),
							   .RST_n      		(UART_RST_n),
							   .rxBAUND_DATA    (BAUND_END_CNT),
							   .data_rx         (UART_RX),
							   .o_RECEIVED_DATA (UART_DATA_RECED),
							   .UART_RX_busy 	(UART_status_reg[1]),
							   .receive_done 	(UART_status_reg[0])
							   );

	uart_rxfifo        rx_fifo ( 
				        	   .SCLK		 (UART_CLK),	
				        	   .RST_n        (UART_RST_n),
				        	   
				        	   .FIFO_WR_DATA (UART_DATA_RECED),
				        	   .FIFO_WREN    (UART_status_reg[0]),	//rece_done		
				        	   .FIFO_RDEN    (rxFIFO_RDEN),			
				        	   .FIFO_RD_DATA (rxFIFO_READ),			
				        	   .FIFO_Empty    (FIFO_status_reg[3]),			
				        	   .FIFO_FULL     (FIFO_status_reg[2]),			
				        	   .FIFO_OVER     (FIFO_status_reg[1]),			
				        	   .FIFO_UNDER    (FIFO_status_reg[0])			
				        	   );
							   
//RD_rx_fifo
	reg [1:0] rxFIFO_FSM;

	
	always@(posedge UART_CLK or negedge UART_RST_n)
	begin
		if(!UART_RST_n)	
		begin
			rxFIFO_FSM  <= 2'b0;
			rxFIFO_RDEN <= 1'b0;
		end
		else 
		begin
			case(rxFIFO_FSM)
			2'd0: //start
			begin
				rxFIFO_FSM  <= (UART_RD_READY & is_SUART_RX) ? 2'd1 : 2'd0;
				rxFIFO_RDEN <= 1'b0;
			end
			2'd1: //
			begin
				rxFIFO_FSM  <= 2'd2;
				rxFIFO_RDEN <= 1'b1;
			end
			2'd2: //RDEN
			begin
				rxFIFO_FSM  <= (INTERFACE_FSM == INTERFACE_FSM_ready) ? 2'd0 : 2'd2;
				rxFIFO_RDEN <= 1'b0;
			end			
			default:
			begin
				rxFIFO_FSM  <= 2'b0;
				rxFIFO_RDEN <= 1'b0;
			end				
			endcase
		end	
	end		
	
	assign RD_DATA_done = (rxFIFO_FSM == 2'd2);
//////////////////////DATA_selection
	always@(*)
	begin
		if(UART_RD_READY)
		begin
			case({is_SUART_TX,is_SUART_RX,is_SUART_BAUND,is_SUART_STATUS})
			4'b0001: UART_O_DATA <= {20'd0, FIFO_status_reg, UART_status_reg};
			4'b0010: UART_O_DATA <= {20'd0, BAUND_END_CNT};
			4'b0100: UART_O_DATA <= {24'd0, rxFIFO_READ};
			4'b1000: UART_O_DATA <= 32'd0;
			default: UART_O_DATA <= 32'd0;
			endcase		
		end
		else UART_O_DATA <= 32'b0;
	end		
/////////////////	
	
endmodule
