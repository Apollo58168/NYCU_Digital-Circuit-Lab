module mmult(
  input  clk,
  input  reset_n,
  input  enable,
  input  [0:9*8-1] A_mat,
  input  [0:9*8-1] B_mat,
  output valid,
  output [0:9*18-1] C_mat
);
  
  reg [0:9*8-1] A, B;
  reg [0:9*18-1] C;
  reg [0:1] count;
  reg [0:1] i;

  assign C_mat = C;
  assign valid = (count == 3);
  
  always @(posedge clk) begin
    if(~reset_n) begin
      A <= A_mat;
      B <= B_mat;
      C <= 0;
      count <= 0;
    end
    else if(enable) begin
      if(count < 3) begin
        for(i=0; i<3; i = i + 1)begin
            C[(count*3+i)*18+:18] <= A[count*3*8+:8] * B[i*8+:8] + A[(count*3+1)*8+:8] * B[(i+3)*8+:8] + A[(count*3+2)*8+:8] * B[(i+6)*8+:8];
        end
        count <= count + 1;
      end
    end
  end
endmodule
