`timescale 1ns/1ps
module conv_tb(
//  input clk,
  output [7:0] Led,
  input [7:0] sw,
  input rx,
  output tx
);

reg clk = 0;
always begin
  #5 clk <= ~clk;
end

// Weights
wire wt_we;
wire [9:0] wt_addr;
wire [31:0] wt_idata;
wire [31:0] wt_odata;
//Outputs
wire o_val_rst;
wire o_val_we;
wire [12:0] o_val_addr;
wire [31:0] o_val_idata;
wire [31:0] o_val_odata;
//Lastin
wire lastin_rst;
wire lastin_we;
wire [10:0] lastin_addr;
wire [31:0] lastin_idata;
wire  [31:0] lastin_odata;
//Error
wire error_rst; 
wire error_we;
wire [10:0] error_addr;
wire [31:0] error_idata;
wire [31:0] error_odata;
// Image
reg image_we;
reg [9:0] image_addr;
reg [31:0] image_idata;
wire [31:0] image_odata;
// Output
reg output_we;
reg [10:0] output_addr;
reg [31:0] output_idata;
wire [31:0] output_odata;

// UART variables
reg start;
reg [7:0] out_data;
wire rx_irdy, rx_ordy;
wire [7:0] in_data;

uart_rx rx_inst(clk, 1, rx, rx_irdy, in_data);
uart_tx tx_inst(clk, 1, start, out_data, tx, tx_ordy);

conv_wt weights (
    .clka(clk), // input clka
    .wea(wt_we), // input [0 : 0] wea
    .addra(wt_addr), // input [12 : 0] addra
    .dina(wt_idata), // input [31 : 0] dina
    .douta(wt_odata) // output [31 : 0] douta
);

conv_error error (
  .clka(clk), // input clka
  .rsta(error_rst), // input rsta
  .wea(error_we), // input [0 : 0] wea
  .addra(error_addr), // input [10 : 0] addra
  .dina(error_idata), // input [15 : 0] dina
  .douta(error_odata) // output [15 : 0] douta
);

conv_lastin lastin (
  .clka(clk), // input clka
  .rsta(lastin_rst), // input rsta
  .wea(lastin_we), // input [0 : 0] wea
  .addra(lastin_addr), // input [10 : 0] addra
  .dina(lastin_idata), // input [31 : 0] dina
  .douta(lastin_odata) // output [31 : 0] douta
);

conv_o_val o_val (
  .clka(clk), // input clka
  .rsta(o_val_rst), // input rsta
  .wea(o_val_we), // input [0 : 0] wea
  .addra(o_val_addr), // input [11 : 0] addra
  .dina(o_val_idata), // input [31 : 0] dina
  .douta(o_val_odata) // output [31 : 0] douta
);

input_image image (
  .clka(clk), // input clka
  .wea(image_we), // input [0 : 0] wea
  .addra(image_addr), // input [11 : 0] addra
  .dina(image_idata), // input [31 : 0] dina
  .douta(image_odata) // output [31 : 0] douta
);

tb_output cout (
  .clka(clk), // input clka
  .wea(output_we), // input [0 : 0] wea
  .addra(output_addr), // input [11 : 0] addra
  .dina(output_idata), // input [31 : 0] dina
  .douta(output_odata) // output [31 : 0] douta
);

parameter LOAD_IMAGE = 0;
parameter FW_SEND = 1;
parameter FW_REC = 2;
parameter UART_FW = 3;
parameter BP_SEND = 4;
parameter BP_REC = 5;

parameter IDLE = 4;

reg out_rdy, forward, load_weights, in_valid, mem_valid;
reg [2:0] state;
reg [31:0] conv_input;
reg [2:0] conv_input_idx;
reg [4:0] conv_input_x, conv_input_y;
reg [1:0] byte_idx;

wire [31:0] conv_output;
wire [2:0] conv_output_idx;
wire [3:0] conv_output_x, conv_output_y;
wire in_rdy,out_valid;

reg led7;

assign Led[0] = state == 0;
assign Led[1] = state == 1;
assign Led[2] = state == 2;
assign Led[3] = state == 3;
assign Led[4] = state == 4;
assign Led[5] = rx;
assign Led[6] = tx;
assign Led[7] = led7;

conv #(1,28,3,5,5,1,2,8,1,3) conv_inst(clk,out_rdy,in_valid,load_weights,conv_input,conv_input_idx,,conv_input_x,conv_input_y,
    in_rdy,out_valid,conv_output,conv_output_idx,conv_output_x,conv_output_y,
    wt_we,wt_addr,wt_idata,wt_odata,o_val_rst,o_val_we,o_val_addr,o_val_idata,o_val_odata,lastin_rst,lastin_we,lastin_addr,lastin_idata,lastin_odata,
    error_rst,error_we,error_addr,error_idata,error_odata);



initial begin
  mem_valid = 0;
  byte_idx = 0;
  start = 1;
  led7 = 0;
  state = FW_SEND;
  image_idata = 0;
  image_addr = 0;
  image_we = 0;
  in_valid = 0;
  out_data = "7";
  out_rdy = 1;
  forward = 1;
  load_weights = 0;
  conv_input = {16'b01,16'b0};
  conv_input_idx = 0;
  conv_input_x = 0;
  conv_input_y = 0;
end

//always begin
//    #5 clk <= ~clk;
//end

//always @(out_valid)
//	$stop;

always @(posedge clk) begin
    if (start == 1)
        start <= 0;
        
    case(state)
    LOAD_IMAGE: begin
        if (image_addr[4:0] == 27 && image_addr[9:5] == 27) begin
            image_addr <= 0;
            image_we <= 0;
            state <= FW_SEND;
        end
        if (rx_irdy == 1) begin
            image_idata[31] <= in_data[7];
            image_idata[30:15] <= 16'b0;
            image_idata[14:8] <= (in_data[7] == 1) ? in_data[6:0] : ~in_data[6:0];
            image_idata[7:0] <= 8'b0;
            image_we <= 1;
            if (image_addr[4:0] == 27) begin
                image_addr[4:0] <= 0;
                image_addr[9:5] <= image_addr[9:5] + 1;
            end else
                image_addr[4:0] <= image_addr[4:0] + 1;
         end
    end
    FW_SEND: begin
        if (mem_valid == 1 && in_valid == 0) begin
            in_valid <= 1;
            conv_input <= image_odata;
	      end else if (in_valid == 0) begin
		        mem_valid <= 1;
        end else if (in_rdy == 1) begin
            conv_input <= image_odata;
            mem_valid <= 0;
            in_valid <= 0;
            if (image_addr[4:0] == 27) begin
                image_addr[9:5] <= image_addr[9:5] + 1;
                image_addr[4:0] <= 0;
            end else begin
                image_addr[4:0] <= image_addr[4:0] + 1;
            end 
            if (conv_input_y == 27) begin
                if (conv_input_x == 27) begin
                    state <= FW_REC;
                    in_valid <= 0;
                end else begin
                    conv_input_x <= conv_input_x + 1;
                    conv_input_y <= 0;
                end
            end else begin
                conv_input_y <= conv_input_y + 1;
            end 
        end
    end
    FW_REC: begin
        if (out_valid == 1) begin
            output_addr[3:0] <= conv_output_y;
            output_addr[7:4] <= conv_output_x;
            output_addr[10:8] <= conv_output_idx;
            $display("(%d,%d,%d), %d.%d",conv_output_idx, conv_output_x,conv_output_y,conv_output[30:15],conv_output[14:0] );
            output_idata <= conv_output;
            output_we <= 1;
        end else if (output_addr[3:0] == 11 && output_addr[7:4] == 11 && output_addr[10:8] == 7) begin
            output_we <= 0;
            state <= UART_FW;
            output_addr <= 0;
            byte_idx <= 0;
        end
    end
    
    UART_FW: begin
        if (tx_ordy == 1 && start != 1) begin
            out_data <= output_odata >> (8*byte_idx);
            start <= 1;
            if (byte_idx == 3) begin
                if (output_addr[3:0] == 11) begin
                    if (output_addr[7:4] == 11) begin
                        if (output_addr[10:8] == 7) begin
                            state <= IDLE;
                        end else begin
                            output_addr[10:8] <= output_addr[10:8] + 1;
                            output_addr[7:0] <= 0;
                            byte_idx <= 0;
                        end
                    end else begin
                        output_addr[7:4] <= output_addr[7:4] + 1;
                        output_addr[3:0] <= 0;
                        byte_idx <= 0;
                    end
                end else begin
                    output_addr[3:0] <= output_addr[3:0] + 1;
                    byte_idx <= 0;
                end
            end else
                byte_idx <= byte_idx + 1;
        end
    end
    endcase
    //if (in_rdy == 1 || out_valid == 1)
    //    $display("Input (%d,%d,%d)--Output (%d,%d,%d) %d.%d F(%b)", conv_input_x, conv_input_y, conv_input_idx,
    //         conv_output_x, conv_output_y, conv_output_idx, conv_output[31:16], conv_output[15:0], forward);
end

endmodule