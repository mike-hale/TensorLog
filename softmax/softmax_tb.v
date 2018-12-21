`timescale 1ns/1ps

module softmax_tb();

reg clk = 0;
always begin
    #5 clk = ~clk;
end

reg [31:0] x = 0;
reg [3:0] x_i = 0;
reg i_valid, i_rdy;
wire [31:0] y;
wire [3:0] y_i;
wire o_valid, o_rdy;
softmax #(10,4) my_soft(clk,x,x_i,i_valid,i_rdy,y,y_i,o_valid,o_rdy);

reg state = 0;

initial begin
    i_valid = 1;
    i_rdy = 1;
end

always @(posedge clk) begin
    if (state == 0) begin
        if (o_rdy) begin
            $display("Input (%d)", x_i);
            if (x_i == 9)
                state <= 1;
            else begin
                x <= x + (1 << 14);
                x_i <= x_i + 1;
            end
        end
    end else begin
        if (o_valid) begin
            $display("Output (%d): %d.%05d", y_i,y[30:15], 3.0518*y[14:0]);
            if (y_i == 9) begin
                state <= 0;
                x_i <= 0;
            end
        end
    end
end

endmodule