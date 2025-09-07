module alu(
    // DO NOT modify the interface!
    // input signal
    input [7:0] accum,
    input [7:0] data,
    input [2:0] opcode,
    input reset,
    
    // result
    output reg [7:0] alu_out,
    
    // PSW
    output reg zero,
    output reg overflow,
    output reg parity,
    output reg sign
    );
    
    wire signed [3:0] sa, sd;
    assign sa = accum[3:0];
    assign sd = data[3:0];
    
    `define PASS 3'b000
    `define ADD   3'b001
    `define SUB   3'b010
    `define SHIFT 3'b011
    `define XOR   3'b100
    `define ABS   3'b101
    `define MUL   3'b110
    `define FLIP  3'b111
    
    always @* begin
        alu_out = 8'b0;
        overflow = 1'b0;

        casez (opcode)
            `PASS : alu_out = accum;
            `ADD  : begin
                        alu_out = accum + data;
                        overflow = (accum[7] == data[7]) && (alu_out[7] != accum[7]); 
                        if (overflow == 1 && accum[7] == 0) begin
                            alu_out = 8'b01111111; 
                        end else if (overflow == 1 && accum[7] == 1) begin
                            alu_out = 8'b10000000; 
                        end
                    end
            `SUB  : begin
                        alu_out = accum + ~data + 1; 
                        overflow = (accum[7] != data[7]) && (alu_out[7] != accum[7]); 
                        if (overflow == 1 && accum[7] == 0) begin
                            alu_out = 8'b01111111; 
                        end else if (overflow == 1 && accum[7] == 1) begin
                            alu_out = 8'b10000000; 
                        end
                    end
            `SHIFT : alu_out = $signed(accum) >>> data;
            `XOR   : alu_out = accum ^ data;
            `ABS   : alu_out = (accum[7] == 1) ? (~accum + 1) : accum;
            `MUL   : alu_out = $signed(sa) * $signed(sd);
            `FLIP  : alu_out = ~accum + 1;
            default: alu_out = 0;
        endcase
        zero = (alu_out == 0);
        parity = ^alu_out;  
        sign = alu_out[7];
    end
    
    always @(posedge reset) begin
        if (reset) begin
            alu_out <= 0;
            overflow <= 0;
            zero <= 0;
            parity <= 0;
            sign <= 0;
        end
    end
endmodule
