`timescale 1ns / 1ps

module lab5(
  input clk,
  input reset_n,
  input [3:0] usr_btn,
  input [3:0] usr_sw,
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

// Parameters
parameter SCROLL_INTERVAL = 32'd100_000_000; // 1 second at 50MHz

// Registers for number sequences
reg [3:0] col1 [0:8];
reg [3:0] col2 [0:8];
reg [3:0] col3 [0:8];
reg [3:0] col1_idx, col2_idx, col3_idx;

// Registers for timers and state
reg [31:0] scroll_counter;
reg [1:0] col2_scroll_counter;
reg [3:0] sw_state_old;
reg game_over;
reg game_start;

// LCD text registers
reg [127:0] row_A, row_B;

// LCD module instantiation
LCD_module lcd0(
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);

// Initialize number sequences
initial begin
  {col1[0], col1[1], col1[2], col1[3], col1[4], col1[5], col1[6], col1[7], col1[8]} = {4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9};
  {col2[0], col2[1], col2[2], col2[3], col2[4], col2[5], col2[6], col2[7], col2[8]} = {4'd9, 4'd8, 4'd7, 4'd6, 4'd5, 4'd4, 4'd3, 4'd2, 4'd1};
  {col3[0], col3[1], col3[2], col3[3], col3[4], col3[5], col3[6], col3[7], col3[8]} = {4'd1, 4'd3, 4'd5, 4'd7, 4'd9, 4'd2, 4'd4, 4'd6, 4'd8};

  // Initial display
  row_A = "     |1|9|1|    ";
  row_B = "     |2|8|3|    ";
end

// Function to convert 4-bit binary to ASCII
function [7:0] bin_to_ascii;
  input [3:0] bin;
  begin
    // Return '0'~'9' ASCII values (48~57)
    bin_to_ascii = bin + 8'd48; // '0' starts at ASCII 48
  end
endfunction

// Main logic
always @(posedge clk or negedge reset_n) begin
  if (~reset_n) begin
    // Reset logic
    col1_idx <= 0;
    col2_idx <= 0;
    col3_idx <= 0;
    scroll_counter <= 0;
    col2_scroll_counter <= 0;
    sw_state_old <= 4'b1111;
    game_over <= 0;
    game_start <= 0;

    row_A <= "      |1|9|1|     ";
    row_B <= "      |2|8|3|     ";
  end else begin
    // Scrolling logic starts only when usr_sw[0] == 0
    if(usr_sw[0]&&(~usr_sw[1]||~usr_sw[2]||~usr_sw[3]))begin
        row_A <= "     ERROR      ";
        row_B <= "  game stopped  ";
    end
    if (~usr_sw[0]) begin
      game_start <= 1;
      if (scroll_counter == SCROLL_INTERVAL) begin
        scroll_counter <= 0;
        
        // Scroll column 1 and 3 based on switches
        if (usr_sw[3]) col1_idx <= (col1_idx + 1) % 9;
        if (usr_sw[1]) col3_idx <= (col3_idx + 1) % 9;
        
        // Increment counter for column 2
        col2_scroll_counter <= col2_scroll_counter + 1;
        
        // Scroll column 2 every two seconds based on switch
        if (col2_scroll_counter == 2'd1 && usr_sw[2]) begin
          col2_idx <= (col2_idx + 1) % 9;
          col2_scroll_counter <= 0;
        end
      end else begin
        scroll_counter <= scroll_counter + 1;
      end
    end
    if(usr_sw[0] == 1 && game_start == 1)begin
        row_A <= "     ERROR      ";
        row_B <= "  game stopped  ";
    end
    // Game over logic, happens when all switches are 0
    if (usr_sw == 4'b0000 && sw_state_old != 4'b0000) begin
      game_over <= 1;
    end
    sw_state_old <= usr_sw;

    // Display logic
    if (game_over) begin
      if (col1[col1_idx+1] == col2[col2_idx+1] && col2[col2_idx+1] == col3[col3_idx+1]) begin
        row_A <= "    Jackpot!    ";
      end else if (col1[col1_idx+1] == col2[col2_idx+1] || col2[col2_idx+1] == col3[col3_idx+1] || col1[col1_idx+1] == col3[col3_idx+1]) begin
        row_A <= "    Free Game!  ";
      end else begin
        row_A <= "     Loser!     ";
      end
      row_B <= "    Game over   ";
    end else begin
      // Display numbers when game is not over
      row_A <= {"     |", bin_to_ascii(col1[col1_idx]), "|", bin_to_ascii(col2[col2_idx]), "|", bin_to_ascii(col3[col3_idx]), "|    "};
      row_B <= {"     |", bin_to_ascii(col1[(col1_idx+1)%9]), "|", bin_to_ascii(col2[(col2_idx+1)%9]), "|", bin_to_ascii(col3[(col3_idx+1)%9]), "|    "};
    end
  end
end

endmodule
