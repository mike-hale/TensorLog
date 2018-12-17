`include "arith.vh"

module exp(
    input clk,
    input [31:0] x,
    input i_valid,
    input i_rdy,
    output o_valid,
    output o_rdy,
    output reg [31:0] y
);


parameter [31:0] e = 'h15bf0;
parameter [31:0] e_inv = 'h2f16;
parameter [6*32 - 1:0] fp_fact = {{17'd120,15'b0}, {17'd24,15'b0}, {17'd6,15'b0}, {17'd2,15'b0}, {17'd1,15'b0}, {17'd1,15'b0}};

parameter IDLE = 0;
parameter INT_MULT = 1;
parameter T_MULT = 2;
parameter OUT = 3;

reg [2:0] state = IDLE;
reg [15:0] int_mults;
reg [31:0] t_approx;
reg [31:0] t_exp;
reg [31:0] frac;
reg [2:0] degree;

reg [31:0] temp;

assign o_rdy = state == IDLE;
assign o_valid = state == OUT;

always @(posedge clk) begin
    case(state)
        IDLE: begin
            if (i_valid) begin
                int_mults <= x[30:15];
                frac <= {x[31],16'b0,x[14:0]};
                y <= 1 << 15;
                if (x[30:15] != 0)
                    state <= INT_MULT;
                else begin
                    degree <= 2;
                    t_approx <= add(1 << 15,{x[31],16'b0,x[14:0]});
                    t_exp <= {x[31],16'b0,x[14:0]};
                    state <= T_MULT;
                end
            end
        end

        INT_MULT: begin
            int_mults <= int_mults - 1;
            if (int_mults == 1) begin
                degree <= 2;
                t_approx = add(1 << 15,frac);
                t_exp = frac;
                state <= T_MULT;
            end
            if (frac[31])
                y <= mult(y,e_inv);
            else
                y <= mult(y,e);
        end

        T_MULT: begin
            degree <= degree + 1;
            t_exp = mult(t_exp,frac);
            temp = div(t_exp,fp_fact >> (32*degree));
            t_approx = add(t_approx,temp);
            if (degree == 5) begin
                state <= OUT;
                y <= mult(y,t_approx);
            end
        end

        OUT: begin
            if (i_rdy) begin
                state <= IDLE;
            end
        end
    endcase
end

endmodule