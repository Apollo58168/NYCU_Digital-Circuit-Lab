`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/17 22:35:16
// Design Name: 
// Module Name: rotate
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rotate_pipeline (input wire clk,
                        input wire reset,
                        input wire [31:0] data_in,
                        input wire [4:0] shift,
                        output reg [31:0] data_out);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_out <= 32'd0;
            end else begin
            data_out <= (data_in >> shift) | (data_in << (32 - shift));
        end
    end
endmodule

