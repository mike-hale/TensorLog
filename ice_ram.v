module ice_ram #(
    parameter addr_width = 3,
    parameter data_width = 32,
    parameter init_file = ""
) 
(
    input clk,
    input we,
    input rst, 
    input [addr_width-1:0] addr, 
    input [data_width-1:0] din, 
    output reg [data_width-1:0] dout
);// 512x8

localparam mem_size = (1 << addr_width);

reg [data_width-1:0] mem [mem_size-1:0];
integer i, open_file, scan_ret;

initial begin
    if (init_file == "")
        for (i=0; i<mem_size; i=i+1)
            mem[i] = 0;
    else begin
        open_file = $fopen(init_file, "r");
        for (i=0; i<mem_size; i=i+1) begin
            scan_ret = $fscanf(open_file, "%x\n", mem[i]); // read directly into memory
            $display("Address(%x): %d.%05d", i, mem[i][30:15], 3.018*mem[i][14:0]);
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        for (i=0; i<mem_size; i=i+1)
            mem[i] <= 0;
    end else if (we) begin
        mem[addr] <= din;
        dout <= din;
    end else
        dout <= mem[addr]; // Output register controlled by clock.
end

endmodule