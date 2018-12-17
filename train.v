`timescale 1ns/1ps
module train(
    //input clk,
    input rx,
    output tx,
    output [7:0] led,
	 output [6:0] seg,
	 output cat
);
reg clk = 0;
always begin
  #5 clk <= ~clk;
end

/********* MEMORY BLOCKS CONV 1 *********/
// Weights
wire conv1_wt_we;
wire [9:0] conv1_wt_addr;
wire [31:0] conv1_wt_idata;
wire [31:0] conv1_wt_odata;
//Outputs
wire conv1_o_val_rst;
wire conv1_o_val_we;
wire [12:0] conv1_o_val_addr;
wire [31:0] conv1_o_val_idata;
wire [31:0] conv1_o_val_odata;
//Lastin
wire conv1_lastin_rst;
wire conv1_lastin_we;
wire [10:0] conv1_lastin_addr;
wire [31:0] conv1_lastin_idata;
wire  [31:0] conv1_lastin_odata;
//Error
wire conv1_error_rst; 
wire conv1_error_we;
wire [10:0] conv1_error_addr;
wire [31:0] conv1_error_idata;
wire [31:0] conv1_error_odata;

conv1_wt conv1_weights (
    .clka(clk), // input clka
    .wea(conv1_wt_we), // input [0 : 0] wea
    .addra(conv1_wt_addr), // input [12 : 0] addra
    .dina(conv1_wt_idata), // input [31 : 0] dina
    .douta(conv1_wt_odata) // output [31 : 0] douta
);

conv1_error conv1_error (
  .clka(clk), // input clka
  .rsta(conv1_error_rst), // input rsta
  .wea(conv1_error_we), // input [0 : 0] wea
  .addra(conv1_error_addr), // input [10 : 0] addra
  .dina(conv1_error_idata), // input [15 : 0] dina
  .douta(conv1_error_odata) // output [15 : 0] douta
);

conv1_lastin conv1_lastin (
  .clka(clk), // input clka
  .rsta(conv1_lastin_rst), // input rsta
  .wea(conv1_lastin_we), // input [0 : 0] wea
  .addra(conv1_lastin_addr), // input [10 : 0] addra
  .dina(conv1_lastin_idata), // input [31 : 0] dina
  .douta(conv1_lastin_odata) // output [31 : 0] douta
);

conv1_o_val conv1_o_val (
  .clka(clk), // input clka
  .rsta(conv1_o_val_rst), // input rsta
  .wea(conv1_o_val_we), // input [0 : 0] wea
  .addra(conv1_o_val_addr), // input [11 : 0] addra
  .dina(conv1_o_val_idata), // input [31 : 0] dina
  .douta(conv1_o_val_odata) // output [31 : 0] douta
);
/********* MEMORY BLOCKS CONV 2 *********/
// Weights
wire conv2_wt_we;
wire [12:0] conv2_wt_addr;
wire [31:0] conv2_wt_idata;
wire [31:0] conv2_wt_odata;
//Outputs
wire conv2_o_val_rst;
wire conv2_o_val_we;
wire [11:0] conv2_o_val_addr;
wire [31:0] conv2_o_val_idata;
wire [31:0] conv2_o_val_odata;
//Lastin
wire conv2_lastin_rst;
wire conv2_lastin_we;
wire [10:0] conv2_lastin_addr;
wire [31:0] conv2_lastin_idata;
wire  [31:0] conv2_lastin_odata;
//Error
wire conv2_error_rst; 
wire conv2_error_we;
wire [10:0] conv2_error_addr;
wire [31:0] conv2_error_idata;
wire [31:0] conv2_error_odata;

conv2_wt conv2_weights (
    .clka(clk), // input clka
    .wea(conv2_wt_we), // input [0 : 0] wea
    .addra(conv2_wt_addr), // input [12 : 0] addra
    .dina(conv2_wt_idata), // input [31 : 0] dina
    .douta(conv2_wt_odata) // output [31 : 0] douta
);

conv2_error conv2_error (
  .clka(clk), // input clka
  .rsta(conv2_error_rst), // input rsta
  .wea(conv2_error_we), // input [0 : 0] wea
  .addra(conv2_error_addr), // input [10 : 0] addra
  .dina(conv2_error_idata), // input [15 : 0] dina
  .douta(conv2_error_odata) // output [15 : 0] douta
);

conv2_lastin conv2_lastin (
  .clka(clk), // input clka
  .rsta(conv2_lastin_rst), // input rsta
  .wea(conv2_lastin_we), // input [0 : 0] wea
  .addra(conv2_lastin_addr), // input [10 : 0] addra
  .dina(conv2_lastin_idata), // input [31 : 0] dina
  .douta(conv2_lastin_odata) // output [31 : 0] douta
);

conv2_o_val conv2_o_val (
  .clka(clk), // input clka
  .rsta(conv2_o_val_rst), // input rsta
  .wea(conv2_o_val_we), // input [0 : 0] wea
  .addra(conv2_o_val_addr), // input [11 : 0] addra
  .dina(conv2_o_val_idata), // input [31 : 0] dina
  .douta(conv2_o_val_odata) // output [31 : 0] douta
);
/********* MEMORY BLOCKS FC *********/
wire fc_wt_we;
wire [13:0] fc_wt_addr;
wire [31:0] fc_wt_idata;
wire [31:0] fc_wt_odata;
fc_weights fc_weights (
  .clka(clk), // input clka
  .wea(fc_wt_we), // input [0 : 0] wea
  .addra(fc_wt_addr), // input [13 : 0] addra
  .dina(fc_wt_idata), // input [15 : 0] dina
  .douta(fc_wt_odata) // output [15 : 0] douta
);

wire fc_o_val_rst, fc_o_val_we;
wire [3:0] fc_o_val_addr;
wire [31:0] fc_o_val_idata;
wire [31:0] fc_o_val_odata;
fc_o_val fc_output_val (
  .clka(clk), // input clka
  .rsta(fc_o_val_rst), // input rsta
  .wea(fc_o_val_we), // input [0 : 0] wea
  .addra(fc_o_val_addr), // input [3 : 0] addra
  .dina(fc_o_val_idata), // input [15 : 0] dina
  .douta(fc_o_val_odata) // output [15 : 0] douta
);

wire fc_lastin_rst, fc_lastin_we;
wire [9:0] fc_lastin_addr;
wire [31:0] fc_lastin_idata;
wire [31:0] fc_lastin_odata;
fc_lastin last_input (
  .clka(clk), // input clka
  .rsta(fc_lastin_rst), // input rsta
  .wea(fc_lastin_we), // input [0 : 0] wea
  .addra(fc_lastin_addr), // input [9 : 0] addra
  .dina(fc_lastin_idata), // input [15 : 0] dina
  .douta(fc_lastin_odata) // output [15 : 0] douta
);

wire fc_error_rst, fc_error_we;
wire [9:0] fc_error_addr;
wire [31:0] fc_error_idata;
wire [31:0] fc_error_odata;
fc_error error_val (
  .clka(clk), // input clka
  .rsta(fc_error_rst), // input rsta
  .wea(fc_error_we), // input [0 : 0] wea
  .addra(fc_error_addr), // input [9 : 0] addra
  .dina(fc_error_idata), // input [15 : 0] dina
  .douta(fc_error_odata) // output [15 : 0] douta
);

/************ IMAGE MEMORY BLOCK *************/
reg image_we;
reg [9:0] image_addr;
reg [31:0] image_idata;
wire [31:0] image_odata;
input_image image (
  .clka(clk), // input clka
  .wea(image_we), // input [0 : 0] wea
  .addra(image_addr), // input [11 : 0] addra
  .dina(image_idata), // input [31 : 0] dina
  .douta(image_odata) // output [31 : 0] douta
);

reg conv1_i_valid;
reg fw;
reg load_weights;
reg [3:0] state;

wire conv1_rdy, conv2_rdy, fc_rdy;
wire conv1_o_valid, conv2_o_valid, fc_o_valid;

parameter LOAD_IMAGE = 0;
parameter CONV1_FW = 1;
parameter CONV1_BP = 2;
parameter CONV2_FW = 3;
parameter CONV2_BP = 4;
parameter FC_FW = 5;
parameter FC_BP = 6;
parameter ERROR = 7;

reg [31:0] conv1_in;
reg [4:0] conv1_x_in, conv1_y_in;
reg [2:0] conv1_i_in, conv1_i2_in;
wire [31:0] conv1_out;
wire [4:0] conv1_x_out, conv1_y_out;
wire [2:0] conv1_i_out;

reg [31:0] conv2_in;
reg [3:0] conv2_x_in, conv2_y_in;
reg [3:0] conv2_i_in, conv2_i2_in;
wire [31:0] conv2_out;
wire [3:0] conv2_x_out, conv2_y_out;
wire [3:0] conv2_i_out;

reg [31:0] fc_in;
reg [9:0] fc_i_in, fc_i2_in;
wire [31:0] fc_out;
wire [9:0] fc_i_out;

// UART variables
reg start;
reg [7:0] out_data;
wire rx_irdy, tx_ordy;
wire [7:0] in_data;

uart_rx rx_inst(clk, 1, rx, rx_irdy, in_data);
uart_tx tx_inst(clk, 1, start, out_data, tx, tx_ordy);

reg [3:0] digit;
seven_seg seven_seg(
clk,
digit,
seg,
cat
);

conv #(1,28,3,5,5,1,2,8,1,3) conv1(
    clk,
    conv2_rdy,
    conv1_i_valid,
    load_weights,
    conv1_in,
    conv1_i_in,
    conv1_i2_in,
    conv1_x_in,
    conv1_y_in,
    conv1_rdy,
    conv1_o_valid,
    conv1_out,
    conv1_i_out,
    conv1_x_out,
    conv1_y_out,
    conv1_wt_we,
    conv1_wt_addr,
    conv1_wt_idata,
    conv1_wt_odata,
    conv1_o_val_rst,
    conv1_o_val_we,
    conv1_o_val_addr,
    conv1_o_val_idata,
    conv1_o_val_odata,
    conv1_lastin_rst,
    conv1_lastin_we,
    conv1_lastin_addr,
    conv1_lastin_idata,
    conv1_lastin_odata,
    conv1_error_rst,
    conv1_error_we,
    conv1_error_addr,
    conv1_error_idata,
    conv1_error_odata
);

conv #(8,12,4,4,5,1,1,16,3,4) conv2(
     clk,
     fc_rdy,
     conv1_o_valid,
     load_weights,
     conv1_out,
     {1'b0,conv1_i_out},
     conv2_i2_in,
     conv1_x_out,
     conv1_y_out,
    conv2_rdy,
     conv2_o_valid,
     conv2_out,
     conv2_i_out,
     conv2_x_out,
     conv2_y_out,
    conv2_wt_we,
     conv2_wt_addr,
     conv2_wt_idata,
     conv2_wt_odata,
     conv2_o_val_rst,
     conv2_o_val_we,
     conv2_o_val_addr,
     conv2_o_val_idata,
     conv2_o_val_odata,
     conv2_lastin_rst,
     conv2_lastin_we,
     conv2_lastin_addr,
     conv2_lastin_idata,
     conv2_lastin_odata,
    conv2_error_rst,
     conv2_error_we,
     conv2_error_addr,
     conv2_error_idata,
     conv2_error_odata
);

fc #(1024,10,10,10,4) fc_inst(
    clk,
    1'b1,
    conv2_o_valid,
    fw,
    load_weights,
    conv2_out,
    {conv2_x_out[2:0],conv2_y_out[2:0],conv2_i_out},
    fc_i2_in,
    fc_rdy,
	 fc_o_valid,
    fc_out,
    fc_i_out,
    fc_wt_we, 
    fc_wt_addr, 
    fc_wt_idata, 
    fc_wt_odata, 
    fc_o_val_rst, 
    fc_o_val_we, 
    fc_o_val_addr, 
    fc_o_val_idata, 
    fc_o_val_odata,
    fc_lastin_rst, 
    fc_lastin_we, 
    fc_lastin_addr, 
    fc_lastin_idata, 
    fc_lastin_odata, 
    fc_error_rst, 
    fc_error_we, 
    fc_error_addr, 
    fc_error_idata, 
    fc_error_odata
);

reg [31:0] max_val;
reg [4:0] max_idx;
reg mem_valid;
reg first_val;

assign led = state;

initial begin
    first_val = 0;
    fw = 0;
    load_weights = 0;
    conv1_i_valid = 0;
    conv1_i_in = 0;
    conv1_i2_in = 0;
    conv1_x_in = 0;
    conv1_y_in = 0;
    state = CONV1_FW;
	 mem_valid = 0;
	 image_addr = 0;
	 image_we = 0;
end

always @(posedge clk) begin
    case(state)
    LOAD_IMAGE: begin
        if (image_addr == 27*32 + 27) begin
            image_addr <= 0;
            image_we <= 0;
            mem_valid <= 0;
            state <= CONV1_FW;
				mem_valid <= 0;
				conv1_i_valid <= 0;
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
    CONV1_FW: begin
        if (mem_valid == 0) begin
		      mem_valid <= 1;
		  end else if (conv1_i_valid == 0) begin
		      conv1_in <= image_odata;
				conv1_i_valid <= 1;
				conv1_i_in <= 0;
				conv1_x_in <= image_addr[9:5];
				conv1_y_in <= image_addr[4:0];
		  end else if (conv1_rdy == 1) begin
		      conv1_i_valid <= 0;
				mem_valid <= 0;
				if (image_addr[4:0] == 27) begin
				    image_addr[4:0] <= 0;
					 image_addr[9:5] <= image_addr[9:5] + 1;
			   end else
				    image_addr[4:0] <= image_addr[4:0] + 1;
				if (conv1_x_in == 27 && conv1_y_in == 27) begin
				    state <= FC_FW;
					 max_val = 0;
					 max_idx = 0;
				end
		  end
    end 
	 
	 FC_FW: begin
	     if (fc_o_valid == 1 && fc_out > max_val) begin
		      max_val = fc_out;
		      max_idx = fc_i_out;
		  end
		  if (fc_i_out == 9) begin
		      digit <= max_idx;
				state <= LOAD_IMAGE;
				image_addr <= 0;
	         image_we <= 0;
				mem_valid <= 0;
		  end
	 end
	 endcase
end

endmodule