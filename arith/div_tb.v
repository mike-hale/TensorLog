`timescale 1ns/1ps

module div_tb();

integer k,j;

parameter WIDTH = 16;
function [WIDTH - 1:0] div;
    input [WIDTH - 1:0] dividend, divisor;
    reg [WIDTH:0] temp;
    integer i;
    begin  
        temp = 0;
        div = dividend;
        for (i=0;i<WIDTH;i=i+1) begin
            temp = temp << 1;
            temp[0] = div[WIDTH - 1];
            div = div << 1;
            temp = temp - divisor;
            if (temp[WIDTH] == 1) begin // negative value
                div[0] = 0;
                temp = temp + divisor;
            end else
                div[0] = 1;
        end
    end
endfunction

initial begin
  for (k=0;k<10;k=k+1)
    for (j=0;j<10;j=j+1) begin
        $display("Out (%d, %d): %d", k, j, div(k,j));
    end

end

endmodule