module conv #(
    parameter INPUT_DEPTH = 1,
    parameter INPUT_SIZE = 13,
    parameter IDX_WIDTH = 3,
    parameter COORD_WIDTH = 5,
    parameter KERNEL_SIZE = 5,
    parameter STRIDE = 2,
    parameter MAXPOOL = 1,
    parameter OUTPUT_DEPTH = 8,
    parameter IN_ADDR_WIDTH = 5,
    parameter O_ADDR_WIDTH = 5
)
(
    input clk,
    input out_rdy,
    input in_valid,
    input load_weights,
    input [31:0] conv_input,
    input [IDX_WIDTH - 1:0] conv_input_idx,
    input [IDX_WIDTH - 1:0] conv_input_idx2, // Only used to load weights, might not keep it tbh
    input [COORD_WIDTH - 1:0] conv_input_x,
    input [COORD_WIDTH - 1:0] conv_input_y,
    output in_rdy,
    output reg out_valid,
    output reg [31:0] conv_output,
    output reg [IDX_WIDTH - 1:0] conv_output_idx,
    output reg [COORD_WIDTH - 1:0] conv_output_x,
    output reg [COORD_WIDTH - 1:0] conv_output_y,
    // Weights
    output reg wt_we,
    output reg [O_ADDR_WIDTH + IN_ADDR_WIDTH + 5:0] wt_addr,
    output reg [31:0] wt_idata,
    input [31:0] wt_odata,
    //Outputs
    output reg o_val_rst, 
    output reg o_val_we,
    output reg [O_ADDR_WIDTH + 2*COORD_WIDTH - 1:0] o_val_addr,
    output reg [31:0] o_val_idata,
    input [31:0] o_val_odata,
    //Lastin
    output reg lastin_rst, 
    output reg lastin_we,
    output reg [IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:0] lastin_addr,
    output reg [31:0] lastin_idata,
    input  [31:0] lastin_odata,
    //Error
    output reg error_rst, 
    output reg error_we,
    output reg [IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:0] error_addr,
    output reg [31:0] error_idata,
    input [31:0] error_odata
);

parameter OUTPUT_SIZE = (INPUT_SIZE - KERNEL_SIZE) / STRIDE + 1;

parameter FW_REC = 0;
parameter FW_COMP = 1;
parameter FW_SEND = 2;
parameter BP_REC = 3;
parameter BP_COMP = 4;
parameter BP_SEND = 5;

reg [IDX_WIDTH - 1:0] last_input_idx;
reg [COORD_WIDTH - 1:0] last_input_x;
reg [COORD_WIDTH - 1:0] last_input_y;
reg [63:0] temp;
reg [31:0] rel_val;
reg [31:0] max_val;
reg [31:0] conv_in_val;
reg offset_x, offset_y;
reg [2:0] state;
reg mem_valid;

// Status signals correspond to internal state
assign in_rdy = state == FW_REC || state == BP_REC;

// Signals used for convenience
wire last_in_idx, last_in_x, last_in_y;
wire last_o_idx, last_o_x, last_o_y;
wire last_in_idx_bp, last_in_x_bp, last_in_y_bp;
wire last_o_idx_bp, last_o_x_bp, last_o_y_bp;
assign last_in_idx = conv_input_idx == INPUT_DEPTH - 1;
assign last_in_x   = conv_input_x == INPUT_SIZE - 1;
assign last_in_y   = conv_input_y == INPUT_SIZE - 1;
assign last_o_idx  = conv_output_idx == OUTPUT_DEPTH - 1;
assign last_o_x    =  conv_output_x == OUTPUT_SIZE / MAXPOOL - 1;
assign last_o_y    =  conv_output_y == OUTPUT_SIZE / MAXPOOL - 1;
assign last_in_idx_bp = conv_input_idx == OUTPUT_DEPTH - 1;
assign last_in_x_bp   =  conv_input_x == OUTPUT_SIZE / MAXPOOL - 1;
assign last_in_y_bp   =  conv_input_y == OUTPUT_SIZE / MAXPOOL - 1;
assign last_o_idx_bp  = conv_output_idx == INPUT_DEPTH - 1;
assign last_o_x_bp    =  conv_output_x == INPUT_SIZE - 1;
assign last_o_y_bp    =  conv_output_y == INPUT_SIZE - 1;

// More convenience signals
wire last_w_in_idx, last_w_o_idx, last_w_x, last_w_y;
assign last_w_o_idx = wt_addr[O_ADDR_WIDTH + IN_ADDR_WIDTH + 5:IN_ADDR_WIDTH + 6] == OUTPUT_DEPTH - 1;
assign last_w_in_idx = wt_addr[IN_ADDR_WIDTH + 5:6] == INPUT_DEPTH - 1;
assign last_w_x = wt_addr[5:3] == KERNEL_SIZE - 1;
assign last_w_y = wt_addr[2:0] == KERNEL_SIZE - 1;

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

initial begin
    out_valid = 0;
    conv_output_idx = 0;
    conv_output_x = 0;
    conv_output_y = 0;
    wt_we = 0;
    wt_addr = 0;
    wt_idata = 0;
    error_we = 0;
    error_rst = 0;
    error_addr = 0;
    error_idata = 0;
    o_val_we = 0;
    o_val_addr = 0;
    o_val_rst = 0;
    o_val_idata = 0;
    lastin_we = 0;
    lastin_rst = 0;
    lastin_addr = 0;
    lastin_idata = 0;
    state = FW_REC;
    last_input_idx = INPUT_DEPTH - 1;
    last_input_x = INPUT_SIZE - 1;
    last_input_y = INPUT_SIZE - 1;
    conv_output = 32'b0;
end

//Update the temporary computed value upon each input
always @(posedge clk) begin
    if (load_weights == 1) begin
        if (in_valid == 1) begin
            // We store the input in the weights if this pin is high and we are not sendig 
            wt_we <= 1;
            wt_addr <= {conv_input_idx[O_ADDR_WIDTH - 1:0],conv_input_idx2[IN_ADDR_WIDTH - 1:0],conv_input_x[2:0],conv_input_y[2:0]};
            wt_idata <= conv_input;
        end
    end

    else begin
        wt_we <= 0;
        case(state)

        /********** FORWARD STAGE INPUT RECEPTION **********/
        FW_REC: begin
            error_rst <= 0;
            o_val_rst <= 0;
            if (in_valid == 1 && (conv_input_idx != last_input_idx || conv_input_x != last_input_x || conv_input_y != last_input_y)) begin
                // Update last input indices so we dont overcount inputs
                last_input_idx <= conv_input_idx;
                last_input_x <= conv_input_x;
                last_input_y <= conv_input_y;
                conv_in_val <= conv_input;
                // Get ready for computation stage
                wt_addr <= {conv_input_idx[IN_ADDR_WIDTH - 1:0],3'b0,3'b0};
                o_val_addr <= {conv_input_x[COORD_WIDTH - 1:0],conv_input_y[COORD_WIDTH - 1:0]};
                mem_valid <= 0;
                lastin_we <= 1;
                lastin_idata <= conv_input;
                lastin_addr <= {conv_input_idx,conv_input_x[COORD_WIDTH - 1:0],conv_input_y[COORD_WIDTH - 1:0]};
                state <= FW_COMP;
            end
        end

        /********** FORWARD STAGE COMPUTATION **********/
        FW_COMP: begin
            lastin_we <= 0;
            if (o_val_we == 0) begin // If we just read a value from o_val, we write that value plus temp
                if (mem_valid == 1) begin
                    if (last_input_x >= wt_addr[5:3] && last_input_x - wt_addr[5:3] < OUTPUT_SIZE &&
                        last_input_y >= wt_addr[2:0] && last_input_y - wt_addr[2:0] < OUTPUT_SIZE) begin
                        // If input coordinates and weight coordinates yield a valid output value
                        temp = qmult(wt_odata, conv_in_val);
                    end else
                        temp = 0;               
                    o_val_idata <= qadd(temp,o_val_odata);
                    o_val_we <= 1; // Next cycle we write
                end else 
                    mem_valid <= 1; // The next cycle our memory will be ready
            end else begin // Otherwise we simply read the next output or change states
                o_val_we <= 0;
                mem_valid <= 0;
                if (last_w_y == 1 && last_w_x == 1 && last_w_o_idx == 1) begin // We've completed computation stage
                    if (last_input_idx == INPUT_DEPTH - 1 && last_input_x == INPUT_SIZE - 1 && last_input_y == INPUT_SIZE - 1) begin
                        // Move on to output stage 
                        state <= FW_SEND;
                        max_val = 0;
                        o_val_addr <= 'b0;
                        conv_output_x <= (OUTPUT_SIZE - 1) / MAXPOOL;
                        conv_output_y <= (OUTPUT_SIZE - 1) / MAXPOOL;
                        conv_output_idx <= 'hFFFF;
					
                    end else begin
                        // Go back and wait for another input
                        state <= FW_REC;
                    end
                end else begin // Move on to the next weight/output pair
                    if (last_w_y == 1) begin
                        if (last_w_x == 1) begin
                            // Reset x,y but increment output idx 
                            wt_addr[O_ADDR_WIDTH + IN_ADDR_WIDTH + 5:IN_ADDR_WIDTH + 6] <= wt_addr[O_ADDR_WIDTH + IN_ADDR_WIDTH + 5:IN_ADDR_WIDTH + 6] + 1;
                            wt_addr[5:0] <= 6'b0;
                            // note o_val x,y coordinates reset to input coord values
                            o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] <= o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] + 1;
                            o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= last_input_x;
                            o_val_addr[COORD_WIDTH - 1:0] <= last_input_y;
                        end else begin
                            // Reset y, increment x
                            wt_addr[5:3] <= wt_addr[5:3] + 1;
                            wt_addr[2:0] <= 3'b0;
                            o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] - 1;
                            o_val_addr[COORD_WIDTH - 1:0] <= last_input_y;
                        end
                    end else begin
                        // Increment y
                        wt_addr[2:0] <= wt_addr[2:0] + 1;
                        o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] - 1;
                    end
                end
            end
        end

        /********** FORWARD STAGE SENDING **********/
        FW_SEND: begin  
            if (MAXPOOL > 1) begin		  
            // If we are done scanning, start sending
            if (mem_valid == 1 && out_valid == 0) begin
                conv_output <= max_val;
                out_valid <= 1;
                if (conv_output_y == (OUTPUT_SIZE - 1) / MAXPOOL) begin
                    if (conv_output_x == (OUTPUT_SIZE - 1) / MAXPOOL) begin
                        conv_output_idx <= conv_output_idx + 1;
                        conv_output_x <= 0;
                        conv_output_y <= 0;
                    end else begin
                        conv_output_x <= conv_output_x + 1;
                        conv_output_y <= 0;
                    end
                 end else
                     conv_output_y <= conv_output_y + 1; 
            end else if (out_rdy == 1) // If the next layer is ready, we move on 
                out_valid <= 0;

            // Must scan inputs over the pooling region before sending
				if (o_val_addr[COORD_WIDTH - 1:0] % MAXPOOL == 0 && o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] % MAXPOOL == 0)
				    max_val = 0;
			   else 
                if (o_val_odata[31] == 0 && o_val_odata > max_val)
                    max_val = o_val_odata;
				 					 
            if (out_rdy == 1 && out_valid == 1 && last_o_idx == 1 && last_o_x == 1 && last_o_y == 1) begin
                state <= FW_REC;
                o_val_addr <= 0;
					 out_valid <= 0;
            end
            // Incrementing address is complex since we must sweep the maxpool region
            else if (o_val_addr[COORD_WIDTH - 1:0] % MAXPOOL == MAXPOOL - 1) begin
                if (o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] % MAXPOOL == MAXPOOL - 1) begin
					     if (out_valid == 0) begin
                    if (o_val_addr[COORD_WIDTH - 1:0] == OUTPUT_SIZE - 1) begin
                        if (o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] == OUTPUT_SIZE - 1) begin
                            // Reached the end of row and column (increment idx)
                            o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] <= o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] + 1;
                            o_val_addr[2*COORD_WIDTH - 1:0] <= 'b0;
                        end else begin
                            // Reached end of row (increment x)
                            o_val_addr[COORD_WIDTH - 1:0] <= 0;
                            o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
                        end
                    end else begin
                        // Reached end of maxpool region (increment y but subtract (MAXPOOL - 1) from x)
                        o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] + 1;
                        o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] - MAXPOOL + 1;
                    end                          
                    mem_valid <= 1; // next cycle we must 
						  end
                end else begin
                    // Reached edge of maxpool region (increment x but subtract (MAXPOOL - 1) from y)
                    o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] - MAXPOOL + 1;
                    o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
                end
            end else begin
                mem_valid <= 0;
                // Default case, just increment y
                o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] + 1;
            end
				end else begin // Not maxpooling
				  if (out_rdy == 1 && out_valid == 1 && last_o_idx == 1 && last_o_x == 1 && last_o_y == 1) begin
                state <= FW_REC;
                o_val_addr <= 0;
					 out_valid <= 0;
              end
				  if (mem_valid == 0)
				      mem_valid <= 1;
				  else if (out_valid == 0) begin
				      out_valid <= 1;
				      conv_output <= (o_val_odata[31] == 1) ? 0 : o_val_odata;
						conv_output_y <= o_val_addr[COORD_WIDTH - 1:0];
						conv_output_x <= o_val_addr[2*COORD_WIDTH - 1:0];
						conv_output_idx <= o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH];
				  end else if (out_rdy == 1) begin
				      out_valid <= 0;
						mem_valid <= 0;
					   if (o_val_addr[COORD_WIDTH - 1:0] == OUTPUT_SIZE - 1) begin
						    if (o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] == OUTPUT_SIZE - 1) begin
							     if (o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] == OUTPUT_DEPTH - 1) begin
								      state <= BP_REC;
										o_val_addr <= 0;
								  end else begin
							         o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] <= o_val_addr[O_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] + 1;
                              o_val_addr[2*COORD_WIDTH - 1:0] <= 'b0;
								  end
							 end else begin
							     o_val_addr[COORD_WIDTH - 1:0] <= 0;
								  o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
							 end
						end else
						    o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] + 1; 
				    end
				  end
        end

        /********** BACKPROP STAGE INPUT RECEPTION **********/
        BP_REC: begin  // Backprop stage
            if (in_valid == 1 && (conv_input_idx != last_input_idx || conv_input_x != last_input_x || conv_input_y != last_input_y)) begin
                // Update last input indices so we dont overcount inputs
                last_input_idx <= conv_input_idx;
                last_input_x <= conv_input_x;
                last_input_y <= conv_input_y;
                conv_in_val <= conv_input;
                // Get ready for computation stage
                wt_addr <= (conv_input_idx[O_ADDR_WIDTH - 1:0] << (6 + IN_ADDR_WIDTH));
                o_val_addr <= {conv_input_idx[O_ADDR_WIDTH - 1:0],conv_input_x[COORD_WIDTH - 1:0]*MAXPOOL,conv_input_y[COORD_WIDTH - 1:0]*MAXPOOL};
                state <= BP_COMP;
                max_val = 0;
                rel_val <= 'hFFFF;
            end
        end

        /********** BACKPROP STAGE COMPUTATION **********/
        BP_COMP: begin
            if (rel_val == 'hFFFF) begin //If we haven't determined the correct value & offset
                if (o_val_odata[31] == 0 && o_val_odata > max_val) begin
                    max_val = o_val_odata;
                    offset_x = o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] % MAXPOOL;
                    offset_y = o_val_addr[COORD_WIDTH - 1:0] % MAXPOOL;
                end
                if (o_val_addr[COORD_WIDTH - 1:0] % MAXPOOL == MAXPOOL - 1) begin
                    if (o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] % MAXPOOL == MAXPOOL - 1) begin // Set rel_val to max_val
                        rel_val <= max_val;
                        error_addr <= {MAXPOOL*last_in_x + offset_x, MAXPOOL*last_in_y + offset_y};
                        lastin_addr <= {MAXPOOL*last_in_x + offset_x, MAXPOOL*last_in_y + offset_y};
                    end else begin
                        o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] - MAXPOOL + 1;
                        o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= o_val_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
                    end 
                end else begin
                    o_val_addr[COORD_WIDTH - 1:0] <= o_val_addr[COORD_WIDTH - 1:0] + 1;
                end
            end else begin
                if (error_we == 0) begin
                    error_we <= 1;
                    wt_we <= 1;
                    if (max_val != 0) begin
                        // Update error data
                        temp = qmult(wt_odata, conv_in_val);
                        error_idata <= qadd(temp,error_odata);
                        // Update weights
                        temp = qmult(lastin_odata, conv_in_val);
                        wt_idata <= qadd(temp,wt_odata);
                    end else begin
                        error_idata <= error_odata;
                        wt_idata <= wt_odata;
                    end
                end else begin 
                    error_we <= 0;
                    wt_we <= 0;
                    if (last_w_in_idx == 1 && last_w_x == 1 && last_w_y == 1) begin
                        if (last_input_idx == OUTPUT_DEPTH - 1 && last_input_x == OUTPUT_SIZE / MAXPOOL - 1 && last_input_y == OUTPUT_SIZE / MAXPOOL - 1) begin
                            // Get ready to start sending data
                            state <= BP_SEND;
                            error_addr <= 'b0;
                        end else begin
                            // Get ready to receive more data
                            state <= BP_REC;
                        end
                    end else begin
                        if (last_w_y == 1) begin
                            if (last_w_x == 1) begin
                                // Increment idx, reset x,y
                                wt_addr[IN_ADDR_WIDTH + 5:6] <= wt_addr[IN_ADDR_WIDTH + 5:6] + 1;
                                error_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] <= error_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] + 1;
                                lastin_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] <= lastin_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] + 1;
                                wt_addr[5:0] <= 0;
                                error_addr[2*COORD_WIDTH - 1:0] <= {MAXPOOL*last_input_x + offset_x, MAXPOOL*last_input_y + offset_y};
                                lastin_addr[2*COORD_WIDTH - 1:0] <= {MAXPOOL*last_input_x + offset_x, MAXPOOL*last_input_y + offset_y};
                            end else begin
                                wt_addr[5:3] <= wt_addr[5:2] + 1;
                                error_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= error_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
                                lastin_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= lastin_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
                                wt_addr[2:0] <= 0;
                                error_addr[COORD_WIDTH - 1:0] <= 0;
                                lastin_addr[COORD_WIDTH - 1:0] <= 0;
                            end 
                        end else begin
                            wt_addr[2:0] <= wt_addr[2:0] + 1;
                            error_addr[COORD_WIDTH - 1:0] <= error_addr[COORD_WIDTH - 1:0] + 1;
                            lastin_addr[COORD_WIDTH - 1:0] <= lastin_addr[COORD_WIDTH - 1:0] + 1;
                        end
                    end
                end
            end
        end

        /********** BACKPROP STAGE SENDING **********/
        BP_SEND: begin
            if (last_o_idx_bp == 1 && last_o_x_bp == 1 && last_o_y_bp == 1) begin
                o_val_rst <= 1;
                error_rst <= 1;
                state <= FW_REC;
            end else begin
                conv_output <= error_odata;
                conv_output_idx <= error_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH];
                conv_output_x <= error_addr[2*COORD_WIDTH - 1:COORD_WIDTH];
                conv_output_y <= error_addr[COORD_WIDTH - 1:0];
                if (last_o_y_bp == 1) begin
                    if (last_o_x_bp == 1) begin
                        error_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] <= error_addr[IN_ADDR_WIDTH + 2*COORD_WIDTH - 1:2*COORD_WIDTH] + 1;
                        error_addr[2*COORD_WIDTH - 1:0] <= 0;
                    end else begin
                        error_addr[2*COORD_WIDTH - 1:COORD_WIDTH] <= error_addr[2*COORD_WIDTH - 1:COORD_WIDTH] + 1;
                        error_addr[COORD_WIDTH - 1:0] <= 0;
                    end
                end else begin
                    error_addr[COORD_WIDTH - 1:0] <= error_addr[COORD_WIDTH -1:0] + 1;
                end
            end
        end
        endcase
    end
end // always

endmodule