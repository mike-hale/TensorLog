module lfsr_rng_tb();

wire [15:0] rand;
reg clk;
reg [9:0] cnt;

lfsr_rng lfsr_inst(clk,rand);

initial begin
    cnt <= 0;
    clk = 0;
end

always begin
    #5 clk = ~clk;
end

always @(posedge clk)
    if (cnt < 100) begin
        cnt <= cnt + 1;
        $display("%d Dec (%05d) Hex (%04x) Bin (%b)", cnt, rand, rand, rand);
    end

endmodule