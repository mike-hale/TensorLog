`include "arith.vh"

module softmax #(
    parameter WIDTH = 10,
    parameter IDX_WIDTH = 4
)
(
    input clk,
    input [31:0] x,
    input [IDX_WIDTH - 1:0] x_i,
    input i_valid,
    input i_rdy,
    output reg [31:0] y,
    output reg [IDX_WIDTH - 1:0] y_i,
    output o_valid,
    output o_rdy
);

parameter FW_REC = 0;
parameter FW_EXP = 1;
parameter FW_DIV = 2;
parameter FW_SEND = 3;
parameter BP_REC = 4;
parameter BP_COMP = 5;
parameter BP_SEND = 6;

reg [31:0] max_input = 0;
reg [31:0] exp_sum = 0;
reg [IDX_WIDTH - 1:0] idx;
reg [2:0] state = FW_REC;

reg [31:0] values [WIDTH - 1:0];

reg [31:0] exp_x;
reg exp_i_rdy, exp_i_valid;
wire exp_o_rdy, exp_o_valid;
wire [31:0] exp_y;
exp exp_module(clk,exp_x,exp_i_valid,exp_i_rdy,exp_o_valid,exp_o_rdy,exp_y);

reg [31:0] temp;

assign o_rdy = state == FW_REC;
assign o_valid = state == FW_SEND;

initial begin
    exp_i_rdy = 0;
end

always @(posedge clk) begin
    case(state)
        FW_REC: begin
            if (i_valid) begin
                values[x_i] <= x;
                if (x[31] == 0 && x > max_input)
                    max_input <= x;
                if (x_i == WIDTH - 1) begin
                    state <= FW_EXP;
                    idx <= 0;
                    exp_sum <= 0;
                end
            end
        end

        FW_EXP: begin
            if (exp_o_valid) begin // Exp module is done computing, so we save the value
                values[idx] <= exp_y;
                exp_sum <= add(exp_sum, exp_y);
                exp_i_rdy <= 0;
                idx <= idx + 1;
                if (idx == WIDTH - 1) begin
                    state <= FW_DIV;
                    idx <= 0;
                end
            end else if (exp_i_rdy == 0) begin // If the exp module is idle, we assign it a new computation
                temp = add(values[idx], {~max_input[31],max_input[30:0]}); // Subtract the max value to prevent overflow
                exp_x <= temp;
                exp_i_valid <= 1;
                exp_i_rdy <= 1;
            end else if (exp_o_rdy) begin // If we just issued a computation
                exp_i_valid <= 0;
            end
        end

        FW_DIV: begin
            temp = div(values[idx], exp_sum);
            values[idx] <= temp;
            if (idx == WIDTH - 1) begin
                y <= values[0];
                y_i <= 0;
                state <= FW_SEND;
            end else
                idx <= idx + 1;
        end

        FW_SEND: begin
            if (i_rdy) begin
                if (y_i == WIDTH - 1) begin
                    max_input <= 0;
                    state <= FW_REC;
                end else begin
                    y <= values[y_i + 1];
                    y_i <= y_i + 1;
                end
            end
        end
    endcase
end

endmodule