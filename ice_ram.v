module ice_ram #(
    parameter addr_width = 3,
    parameter data_width = 32
) 
(
    input [data_width-1:0] din, 
    input [addr_width-1:0] addr, 
    input write_en, 
    input clk, 
    reg [data_width-1:0] dout
);// 512x8

reg [data_width-1:0] mem [(1<<addr_width)-1:0];

always @(posedge clk) begin
    if (write_en) begin
        mem[addr] <= din;
        dout <= din;
    end else
        dout <= mem[addr]; // Output register controlled by clock.
end

endmodule