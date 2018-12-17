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

//parameter RATE = {1'b0,16'b0,15'd1638}; // Approx 0.05

//reg [31:0] weights [OUTPUT_WIDTH - 1:0] [INPUT_WIDTH - 1:0];
/* Weight addressing scheme:
   0x0000: w_0_0 w_1_0 w_2_0 ... w_9_0 0 0 0 0 0 0 <-- weights corresponding to input 0
   0x0010: w_1_0 w_1_1 w_2_1 ... w_9_1 0 0 0 0 0 0
   ...
   0x3FF0: w_1023_0 ...      w_1023_10 0 0 0 0 0 0
   Weights corresponding to the same input value are adjacent (fill the rest of the block with zeros)
*/

// Multiplier and adder module
parameter Q = 15;
parameter N = 32;

function [N-1:0] qmult;
	 input			[N-1:0]	i_multiplicand;
	 input			[N-1:0]	i_multiplier;
   reg [2*N-1:0]	r_result;
begin
  r_result = i_multiplicand[N-2:0] * i_multiplier[N-2:0];
	qmult[N-1] = (i_multiplier[N-1] ^ i_multiplicand[N-1]);
  qmult[N-2:0] = r_result[N-2+Q:Q];
end
endfunction

function [N-1:0] qadd;
    input [N-1:0] a;
    input [N-1:0] b;
begin
  // both negative or both positive
	if(a[N-1] == b[N-1]) begin						//	Since they have the same sign, absolute magnitude increases
		qadd[N-2:0] = a[N-2:0] + b[N-2:0];		//		So we just add the two numbers
		qadd[N-1] = a[N-1];							//		and set the sign appropriately...  Doesn't matter which one we use,  
  end												//		Not doing any error checking on this...
	//	one of them is negative...
	else if(a[N-1] == 0 && b[N-1] == 1) begin		//	subtract a-b
		if( a[N-2:0] > b[N-2:0] ) begin					//	if a is greater than b,
			qadd[N-2:0] = a[N-2:0] - b[N-2:0];			//		then just subtract b from a
			qadd[N-1] = 0;										//		and manually set the sign to positive
			end
		else begin												//	if a is less than b,
			qadd[N-2:0] = b[N-2:0] - a[N-2:0];			//		we'll actually subtract a from b to avoid a 2's complement answer
			if (qadd[N-2:0] == 0)
				qadd[N-1] = 0;										//		I don't like negative zero....
			else
				qadd[N-1] = 1;										//		and manually set the sign to negative
			end
		end
	else begin												//	subtract b-a (a negative, b positive)
		if( a[N-2:0] > b[N-2:0] ) begin					//	if a is greater than b,
			qadd[N-2:0] = a[N-2:0] - b[N-2:0];			//		we'll actually subtract b from a to avoid a 2's complement answer
			if (qadd[N-2:0] == 0)
				qadd[N-1] = 0;										//		I don't like negative zero....
			else
				qadd[N-1] = 1;										//		and manually set the sign to negative
			end
		else begin												//	if a is less than b,
			qadd[N-2:0] = b[N-2:0] - a[N-2:0];			//		then just subtract a from b
			qadd[N-1] = 0;										//		and manually set the sign to positive
			end
  end
end
endfunction

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
                o_val_idata <= qadd(o_val_odata, qmult(wt_odata, lastin_idata));
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
            o_val_addr <= o_val_addr + 1;
            // Sending stage of forward computation
            if (mem_valid == 0)
                mem_valid <= 1;
            else if (out_valid == 0) begin // Sending first data value
                if (o_val_odata[31] == 1)
                    fc_output <= 0;
                else
                    fc_output <= o_val_odata;
                fc_output_idx <= 0;
                out_valid <= 1;
            end else begin // Sending rest of data value
                if (fc_output_idx == OUTPUT_WIDTH - 1) begin
                    o_val_addr <= 0;
                    state <= BP_REC;
                    mem_valid <= 0;
                    out_valid <= 0;
                end else begin
                    // Implement ReLu layer as we're sending data
                    if (o_val_odata[31] == 1) // Negative value
                        fc_output <= 0;
                    else
                        fc_output <= o_val_odata;
                    fc_output_idx <= fc_output_idx + 1;
                end
            end
        end 
        
        BP_REC: begin // Backprop stage
            if (in_valid == 1 && fc_input_idx != last_input_idx) begin
                last_input_idx <= fc_input_idx;
                o_val_addr <= o_val_addr + 1;
                // Again we must only update if the output was positive
                if (o_val_odata[31] == 0) begin // Positive value
					     state <= BP_COMP;
                    wt_addr <= {'b0,fc_input_idx[O_ADDR_WIDTH - 1:0]};
						  mem_valid <= 0;
                    lastin_addr <= 0;
                    fc_in_val <= fc_input;
                end
				end
		  end
        
        BP_COMP: begin
            if (mem_valid == 0)
                mem_valid <= 1;
            else if (error_we == 0) begin
                error_idata <= qadd(error_odata, qmult(wt_odata, lastin_idata));
                wt_idata <= qadd(wt_odata, qmult(~lastin_odata, lastin_idata)); 
                wt_we <= 1;
                error_we <= 1;
            end else begin
                if (error_addr == INPUT_WIDTH - 1) begin
                    if (wt_addr[O_ADDR_WIDTH - 1:0] != OUTPUT_WIDTH - 1) // We reset in_rdy if we need more inputs
                        state <= BP_REC;
                    else begin//Prepare to start sending data
                        state <= BP_SEND;
								error_addr <= 0;
						  end
                end else begin
                    wt_addr[IN_ADDR_WIDTH + O_ADDR_WIDTH - 1:O_ADDR_WIDTH] <= wt_addr[IN_ADDR_WIDTH + O_ADDR_WIDTH - 1:O_ADDR_WIDTH] + 1;
                    error_addr <= error_addr + 1;
                end
                wt_we <= 0;
                error_we <= 0;
                mem_valid <= 0;
            end
        end 

        BP_SEND: begin
		      error_addr <= error_addr + 1;
		      if (mem_valid == 0)
				    mem_valid <= 1;
				else if (out_valid == 0) begin
                fc_output <= error_odata;
                fc_output_idx <= 0;
                out_valid <= 1;
            end else begin
                if (fc_output_idx == INPUT_WIDTH - 1) begin
                    error_rst <= 1;
                    o_val_rst <= 1;
                    out_valid <= 0;
						  state <= FW_REC;
                end else begin
                    fc_output <= error_odata;
                    fc_output_idx <= fc_output_idx + 1;
                end
            end
		  end
		  endcase
    end
end 

endmodule