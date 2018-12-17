`ifndef ARITH_VH
`define ARITH_VH

`define Q 15
`define N 32

function [`N - 1:0] div;
    input [`N - 1:0] dividend, divisor;
    reg [`N - 1:0] scl_divd;
    reg [`N - 1:0] temp;
    integer i;
    begin  
        temp = 0;
        div = 0;
        scl_divd = dividend << `Q;
        for (i=0;i<`N - 1;i=i+1) begin
            temp = temp << 1;
            temp[0] = scl_divd[`N - 2 - i];
            div = div << 1;
            temp = temp - divisor;
            if (temp[`N - 1] == 1) begin // negative value
                div[0] = 0;
                temp = temp + divisor;
            end else
                div[0] = 1;
        end

        div[`N - 1] = dividend[`N - 1] ^ divisor[`N - 1]; // Sign logic
    end
endfunction

function [`N-1:0] mult;
	 input			[`N-1:0]	i_multiplicand;
	 input			[`N-1:0]	i_multiplier;
   reg [2*`N-1:0]	r_result;
begin
  r_result = i_multiplicand[`N-2:0] * i_multiplier[`N-2:0];
  mult[`N-1] = (i_multiplier[`N-1] ^ i_multiplicand[`N-1]);
  mult[`N-2:0] = r_result[`N-2+`Q:`Q];
end
endfunction

function [`N-1:0] add;
    input [`N-1:0] a;
    input [`N-1:0] b;
begin
  // both negative or both positive
	if(a[`N-1] == b[`N-1]) begin						//	Since they have the same sign, absolute magnitude increases
		add[`N-2:0] = a[`N-2:0] + b[`N-2:0];		//		So we just add the two numbers
		add[`N-1] = a[`N-1];							//		and set the sign appropriately...  Doesn't matter which one we use,  
  end												//		Not doing any error checking on this...
	//	one of them is negative...
	else if(a[`N-1] == 0 && b[`N-1] == 1) begin		//	subtract a-b
		if( a[`N-2:0] > b[`N-2:0] ) begin					//	if a is greater than b,
			add[`N-2:0] = a[`N-2:0] - b[`N-2:0];			//		then just subtract b from a
			add[`N-1] = 0;										//		and manually set the sign to positive
			end
		else begin												//	if a is less than b,
			add[`N-2:0] = b[`N-2:0] - a[`N-2:0];			//		we'll actually subtract a from b to avoid a 2's complement answer
			if (add[`N-2:0] == 0)
				add[`N-1] = 0;										//		I don't like negative zero....
			else
				add[`N-1] = 1;										//		and manually set the sign to negative
			end
		end
	else begin												//	subtract b-a (a negative, b positive)
		if( a[`N-2:0] > b[`N-2:0] ) begin					//	if a is greater than b,
			add[`N-2:0] = a[`N-2:0] - b[`N-2:0];			//		we'll actually subtract b from a to avoid a 2's complement answer
			if (add[`N-2:0] == 0)
				add[`N-1] = 0;										//		I don't like negative zero....
			else
				add[`N-1] = 1;										//		and manually set the sign to negative
			end
		else begin												//	if a is less than b,
			add[`N-2:0] = b[`N-2:0] - a[`N-2:0];			//		then just subtract a from b
			add[`N-1] = 0;										//		and manually set the sign to positive
			end
  end
end
endfunction

`endif