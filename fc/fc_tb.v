`include "arith.vh"

module fc_tb();

reg clk, forward, load_weights, out_rdy;
reg [31:0] fc_input;
reg [9:0] fc_in_idx;

wire in_rdy;
wire [31:0] fc_output;
wire [9:0] fc_out_idx;
integer bound;

wire wt_we;
wire [13:0] wt_addr;
wire [31:0] wt_idata;
wire [31:0] wt_odata;
ice_ram #(14,32,"fc/weights.dat") weights (
  .clk(clk), // input clka
  .we(wt_we), // input [0 : 0] wea
  .rst(1'b0),
  .addr(wt_addr), // input [13 : 0] addra
  .din(wt_idata), // input [15 : 0] dina
  .dout(wt_odata) // output [15 : 0] douta
);

wire o_val_rst, o_val_we;
wire [3:0] o_val_addr;
wire [31:0] o_val_idata;
wire [31:0] o_val_odata;
ice_ram #(4,32) output_val (
  .clk(clk), // input clka
  .we(o_val_we), // input [0 : 0] wea
  .rst(o_val_rst), // input rsta
  .addr(o_val_addr), // input [3 : 0] addra
  .din(o_val_idata), // input [15 : 0] dina
  .dout(o_val_odata) // output [15 : 0] douta
);

wire lastin_rst, lastin_we;
wire [9:0] lastin_addr;
wire [31:0] lastin_idata;
wire [31:0] lastin_odata;
ice_ram #(10,32) last_input (
  .clk(clk), // input clka
  .we(lastin_we), // input [0 : 0] wea
  .rst(lastin_rst), // input rsta
  .addr(lastin_addr), // input [9 : 0] addra
  .din(lastin_idata), // input [15 : 0] dina
  .dout(lastin_odata) // output [15 : 0] douta
);

wire error_rst, error_we;
wire [9:0] error_addr;
wire [31:0] error_idata;
wire [31:0] error_odata;
ice_ram #(10,32) error_val (
  .clk(clk), // input clka
  .we(error_we), // input [0 : 0] wea
  .rst(error_rst), // input rsta
  .addr(error_addr), // input [9 : 0] addra
  .din(error_idata), // input [15 : 0] dina
  .dout(error_odata) // output [15 : 0] douta
);

// Image
reg image_we;
reg [9:0] image_addr;
reg [31:0] image_idata;
wire [31:0] image_odata;

ice_ram #(10,32,"fc/image.dat") image (
  .clk(clk), // input clka
  .we(image_we), // input [0 : 0] wea
  .rst(1'b0),
  .addr(image_addr), // input [11 : 0] addra
  .din(image_idata), // input [31 : 0] dina
  .dout(image_odata) // output [31 : 0] douta
);

parameter LOAD_IMAGE = 0;
parameter FW_SEND = 1;
parameter FW_REC = 2;
parameter UART_FW = 3;
parameter BP_SEND = 4;
parameter BP_REC = 5;

reg mem_valid, in_valid;
reg [31:0] all_outs [9:0];
reg [2:0] state;
wire out_valid;


fc #(1024,10,10) fc_layer(clk, out_rdy,in_valid, forward, load_weights, fc_input, fc_in_idx,, in_rdy, out_valid, fc_output, fc_out_idx,
    wt_we, wt_addr, wt_idata, wt_odata, o_val_rst, o_val_we, o_val_addr, o_val_idata, o_val_odata, lastin_rst, lastin_we, lastin_addr,
	 lastin_idata, lastin_odata, error_rst, error_we, error_addr, error_idata, error_odata);

initial begin
  mem_valid = 0;
  in_valid = 0;
  image_addr = 0;
  image_we = 0;
  state = FW_SEND;
  clk = 0;
  out_rdy = 1;
  forward = 1;
  load_weights = 0;
  fc_input = {16'b01,16'b0};
  fc_in_idx = 0;
  bound = 1023;
end

always begin
  #5 clk <= ~clk;
end

always @(posedge clk) begin
  case(state)
  FW_SEND: begin
        if (mem_valid == 1 && in_valid == 0) begin
            in_valid <= 1;
            fc_input <= image_odata;
	     end else if (in_valid == 0) begin
		      mem_valid <= 1;
        end else if (in_rdy == 1) begin
            fc_input <= image_odata;
				mem_valid <= 0;
				in_valid <= 0;
            image_addr <= image_addr + 1;
            if (fc_in_idx == 1023) begin
                state <= FW_REC;
                in_valid <= 0;
			   end else
				    fc_in_idx <= fc_in_idx + 1;
		  end
    end
	 
	FW_REC: begin
	    if (out_valid == 1) begin
		      $display("Output (%d); %d.%05d", fc_out_idx, fc_output[30:15],3.0517*fc_output[14:0]);
          all_outs[fc_out_idx] = fc_output;
		      if (fc_out_idx == 9) begin
			      state <= BP_SEND;
            fc_input <= {~all_outs[0][31], all_outs[0][30:0]};
            fc_in_idx <= 0;
            in_valid <= 1;
          end
		  end
  end

  BP_SEND: begin
      if (in_rdy) begin
          if (fc_in_idx == 9) begin
              state <= BP_REC;
              image_addr <= 0;
              in_valid <= 0;
              mem_valid <= 0;
          end else begin
              fc_in_idx <= fc_in_idx + 1;
              fc_input <= add(all_outs[fc_in_idx + 1], ~fc_in_idx + 2);
         end
      end
  end

  BP_REC: begin
	    if (out_valid == 1) begin
		      //$display("Backprop (%d); %d.%05d", fc_out_idx, fc_output[30:15],3.0517*fc_output[14:0]);
		      if (fc_out_idx == 1023) begin
			      state <= FW_SEND;
            fc_input <= 0;
            fc_in_idx <= 0;
            in_valid <= 1;
          end
		  end
  end

  endcase	 
end

endmodule