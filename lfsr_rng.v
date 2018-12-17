// Linear Feedback Shift Register--Random Number Generator
module lfsr_rng(
    input clk,
    output reg [15:0] random_num
);

reg [15:0] random_next;
reg feedback;
integer i;

initial begin
    // Initial seed (must be nonzero)
    random_num = 'hFFFF;
end

always @(posedge clk) begin
    random_next = random_num;
    // Each clock cycle we basically clear the shift register with new feedback inputs
    for (i=0;i<16;i=i+1) begin
        // Seeds for 16-bit LSFR: 11,13,14,16
        feedback = random_next[10] ^ random_next[12] ^ random_next[13] ^ random_next[15];
        random_next = {random_next[14:0],feedback};
    end
    random_num <= random_next;
end

endmodule