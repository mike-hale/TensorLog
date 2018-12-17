`timescale 1ns/1ps

module exp_tb();

reg clk = 0;
always begin
    #5 clk <= ~clk;
end

reg [31:0] x;
reg i_rdy, i_valid;
wire o_rdy, o_valid;
wire [31:0] y;
exp exp_module(clk,x,i_valid,i_rdy,o_valid,o_rdy,y);

initial begin
    x <= 1 << 31;
    i_rdy <= 1;
    i_valid <= 1;
end

always @(posedge clk) begin
    if (o_rdy) begin
        if (x[30:0] > (5 << 15))
            $finish;
        x <= x + (1 << 11);
        $display("X: %d.%05d", x[30:15],3.0518*x[14:0]);
    end
    if (o_valid)
        $display("Y: %d.%05d", y[30:15],3.0518*y[14:0]);
end

endmodule