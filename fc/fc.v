`include "arith.vh"

module fc #(
    parameter INPUT_WIDTH = 1024,
    parameter IDX_WIDTH = 10,
    parameter OUTPUT_WIDTH = 10,
    parameter IN_ADDR_WIDTH = 10,
    parameter O_ADDR_WIDTH = 4
)
(
    input clk,
    input out_rdy,
    input in_valid,
    input forward,
    input load_weights,
    input [31:0] fc_input,
    input [IDX_WIDTH - 1:0] fc_input_idx,
    input [IDX_WIDTH - 1:0] fc_input_idx2, // Only used for weights
    output in_rdy,
    output reg out_valid,
    output reg [31:0] fc_output,
    output reg [IDX_WIDTH - 1:0] fc_output_idx,
    // Weights
    output reg wt_we,
    output reg [IN_ADDR_WIDTH + O_ADDR_WIDTH - 1:0] wt_addr,
    output reg [31:0] wt_idata,
    input [31:0] wt_odata,
    //Outputs
    output reg o_val_rst, 
    output reg o_val_we,
    output reg [O_ADDR_WIDTH - 1:0] o_val_addr,
    output reg [31:0] o_val_idata,
    input [31:0] o_val_odata,
    //Lastin
    output reg lastin_rst, 
    output reg lastin_we,
    output reg [IN_ADDR_WIDTH - 1:0] lastin_addr,
    output reg [31:0] lastin_idata,
    input  [31:0] lastin_odata,
    //Error
    output reg error_rst, 
    output reg error_we,
    output reg [IN_ADDR_WIDTH - 1:0] error_addr,
    output reg [31:0] error_idata,
    input [31:0] error_odata
);

//reg [31:0] weights [OUTPUT_WIDTH - 1:0] [INPUT_WIDTH - 1:0];
/* Weight addressing scheme:
   0x0000: w_0_0 w_1_0 w_2_0 ... w_9_0 0 0 0 0 0 0 <-- weights corresponding to input 0
   0x0010: w_1_0 w_1_1 w_2_1 ... w_9_1 0 0 0 0 0 0
   ...
   0x3FF0: w_1023_0 ...      w_1023_10 0 0 0 0 0 0
   Weights corresponding to the same input value are adjacent (fill the rest of the block with zeros)
*/

parameter FW_REC = 0;
parameter FW_COMP = 1;
parameter FW_SEND = 2;
parameter BP_REC = 3;
parameter BP_COMP = 4;
parameter BP_SEND = 5;

reg [2:0] state;
reg [31:0] fc_in_val;
reg [63:0] temp;
reg mem_valid;
reg [IDX_WIDTH - 1:0] last_input_idx;

assign in_rdy = state == FW_REC || state == BP_REC;

initial begin
    state <= FW_REC;
    fc_output_idx = 0;
	 o_val_we = 0;
	 wt_we = 0;
    last_input_idx = INPUT_WIDTH - 1;
    fc_output = 32'b0;
end

// Updates output_val based on incoming inputs.
always @(posedge clk) begin
    if (load_weights == 1) begin
        if (in_valid == 1) begin
                wt_we <= 1;
                wt_addr <= {fc_input_idx2[IN_ADDR_WIDTH - 1:0],fc_input_idx[O_ADDR_WIDTH - 1:0]};
                wt_idata <= fc_input;
            //weights[fc_input_idx][fc_input_idx2] <= fc_input;
          end
    end

    
    else begin
        wt_we <= 0; // If we were writing weights, stop that now
        case(state)
        FW_REC: begin
            o_val_rst <= 0;
            error_rst <= 0;
            if (in_valid == 1 && fc_input_idx != last_input_idx) begin
                // Record the input, then shut off the flow while we perform computation
                last_input_idx <= fc_input_idx;
                wt_addr <= fc_input_idx << O_ADDR_WIDTH; // Retrieve the first weight for this input
                o_val_addr <= 0;
                mem_valid <= 0;
                lastin_we <= 1;
                lastin_addr <= fc_input_idx;
                lastin_idata <= fc_input;
                state <= FW_COMP;
            end
        end

        FW_COMP: begin
            lastin_we <= 0;
			if (mem_valid == 0)
				mem_valid <= 1;
            else if (o_val_we == 0) begin // First we must read the stored value in o_val
                o_val_idata <= add(o_val_odata, mult(wt_odata, lastin_idata));
                o_val_we <= 1;					  
            end else begin
                o_val_we <= 0;
                mem_valid <= 0;
                wt_addr <= wt_addr + 1;
                if (o_val_addr == OUTPUT_WIDTH - 1) begin // Last output value is updated
                    if (lastin_addr != INPUT_WIDTH - 1) // We reset in_rdy if we need more inputs
                        state <= FW_REC;
                    else begin //Prepare to start sending data
                        o_val_addr <= 0;
                        state <= FW_SEND;
								out_valid <= 0;
                    end
                end else 
                    o_val_addr <= o_val_addr + 1;
            end 
        end

        FW_SEND: begin      
            // Sending stage of forward computation
            if (!mem_valid)
                mem_valid <= 1;
            else if (!out_valid) begin
                out_valid <= 1;
                if (o_val_odata[31])
                    fc_output <= 0;
                else
                    fc_output <= o_val_odata;
                fc_output_idx <= o_val_addr;
            end else if (out_rdy) begin
                out_valid <= 0;
                mem_valid <= 0;
                if (fc_output_idx == OUTPUT_WIDTH - 1)
                    state <= BP_REC;
                else
                    o_val_addr <= o_val_addr + 1;
            end
        end 
        
        BP_REC: begin // Backprop stage
            if (in_valid == 1 && fc_input_idx != last_input_idx) begin
                //$display("BP receive (%d): %x", fc_input_idx, fc_input);
                last_input_idx <= fc_input_idx;
                fc_in_val <= fc_input;
				state <= BP_COMP;
                wt_addr <= fc_input_idx;
                o_val_addr <= fc_input_idx;
				mem_valid <= 0;
                lastin_addr <= 0;
                error_addr <= 0;
			end
		end
        
        BP_COMP: begin
            if (mem_valid == 0)
                mem_valid <= 1;
            else if (error_we == 0) begin
                //$display("error: %d weight: %d lastin: %d input: %d", error_odata, wt_odata, lastin_odata, fc_in_val);
                if (!o_val_odata[31]) begin // Output was positive
                    error_idata <= add(error_odata, mult(wt_odata, fc_in_val));
                    wt_idata <= add(wt_odata, mult(~lastin_odata + 1, fc_in_val >> 4));
                end else begin // If output was zero/negative, we have no updates
                    error_idata <= error_odata;
                    wt_idata <= wt_odata;
                end 
                wt_we <= 1;
                error_we <= 1;
            end else begin
                if (error_addr == INPUT_WIDTH - 1) begin
                    if (wt_addr[O_ADDR_WIDTH - 1:0] != OUTPUT_WIDTH - 1) // We go back to BP_REC if we need more inputs
                        state <= BP_REC;
                    else begin//Prepare to start sending data
                        state <= BP_SEND;
						error_addr <= 0;
					end
                end else begin
                    wt_addr[IN_ADDR_WIDTH + O_ADDR_WIDTH - 1:O_ADDR_WIDTH] <= wt_addr[IN_ADDR_WIDTH + O_ADDR_WIDTH - 1:O_ADDR_WIDTH] + 1;
                    lastin_addr <= lastin_addr + 1;
                    error_addr <= error_addr + 1;
                end
                wt_we <= 0;
                error_we <= 0;
                mem_valid <= 0;
            end
        end 

        BP_SEND: begin
		    if (!mem_valid)
                mem_valid <= 1;
            else if (!out_valid) begin
                out_valid <= 1;
                fc_output <= error_odata;
                fc_output_idx <= error_addr;
            end else if (out_rdy) begin
                //$display("sending %d", fc_output_idx);
                out_valid <= 0;
                mem_valid <= 0;
                if (fc_output_idx == INPUT_WIDTH - 1)
                    state <= FW_REC;
                else
                    error_addr <= error_addr + 1;
            end
		end
		endcase
    end
end 

endmodule