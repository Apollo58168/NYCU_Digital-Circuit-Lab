`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/11/01 11:16:50
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is a sample circuit to show you how to initialize an SRAM
//              with a pre-defined data file. Hit BTN0/BTN1 let you browse
//              through the data.
// 
// Dependencies: LCD_module, debounce
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab6(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  
  input uart_rx,
  output uart_tx
);

localparam [4:0] S_MAIN_ADDR = 5'b00000, S_MAIN_READ = 5'b00001,
                 S_MAIN_POOL = 5'b00010, S_MAIN_TRANS = 5'b00011,
                 S_MAIN_MULT = 5'b00100, S_MAIN_WAIT = 5'b00110,
                 S_MAIN_SHOW_line1 = 5'b10000, S_MAIN_READ_line2 = 5'b10110,
                 S_MAIN_SHOW_line2 = 5'b10001, S_MAIN_READ_line3 = 5'b10111,
                 S_MAIN_SHOW_line3 = 5'b10010, S_MAIN_READ_line4 = 5'b11000,
                 S_MAIN_SHOW_line4 = 5'b10011, S_MAIN_READ_line5 = 5'b11001,
                 S_MAIN_SHOW_line5 = 5'b10100, S_MAIN_READ_line6 = 5'b11010,
                 S_MAIN_SHOW_line6 = 5'b10101, S_MAIN_FINISH = 5'b11111;

// declare system variables
wire [1:0]  btn_level, btn_pressed;
reg  [1:0]  prev_btn_level;
reg  [4:0]  P, P_next;
reg  [11:0] address_A, address_B;
reg  [18:0]  user_data;
// 二維陣列宣告：5行5列，每個元素19位
reg [18:0] matrix [0:4][0:4];
reg [7:0] pooled_A [0:4][0:4];
reg [7:0] pooled_B [0:4][0:4];
reg [7:0] trans_A [0:4][0:4];

// declare SRAM control signals
wire [10:0] sram_address_A, sram_address_B;
wire [7:0]  data_in;
wire [7:0]  sram_data_out_A, sram_data_out_B;
wire        sram_we, sram_en;

localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;

uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);
// ------------------------------------------------------------------------
// The following code creates an initialized SRAM memory block that
// stores an 1024x8-bit unsigned numbers.
sram ramA(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_address_A), .data_i(data_in), .data_o(sram_data_out_A));
sram ramB(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_address_B), .data_i(data_in), .data_o(sram_data_out_B));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
                             // if you set 'we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = (P == S_MAIN_ADDR || P == S_MAIN_READ || P == S_MAIN_POOL || P == S_MAIN_TRANS || P == S_MAIN_MULT); // Enable the SRAM block.
assign sram_address_A = address_A; // 連接地址寄存器到 SRAM 地址線
assign sram_address_B = address_B; // 連接地址寄存器到 SRAM 地址線
assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_ADDR; // read samples at 000 first
  end
  else begin
    P <= P_next;
  end
end

reg pooled;
reg transformed;
reg multiplied;

// uart print
wire print_enable, print_done;
assign print_enable = (P == S_MAIN_WAIT && P_next == S_MAIN_SHOW_line1) ||
                      (P == S_MAIN_READ_line2 && P_next == S_MAIN_SHOW_line2) ||
                      (P == S_MAIN_READ_line3 && P_next == S_MAIN_SHOW_line3) ||
                      (P == S_MAIN_READ_line4 && P_next == S_MAIN_SHOW_line4) ||
                      (P == S_MAIN_READ_line5 && P_next == S_MAIN_SHOW_line5) ||
                      (P == S_MAIN_READ_line6 && P_next == S_MAIN_SHOW_line6);
assign print_done = (tx_byte == 8'h00);

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_ADDR: // send an address to the SRAM 
      P_next = S_MAIN_READ;
    S_MAIN_READ: // fetch the sample from the SRAM
      P_next = S_MAIN_POOL;
    S_MAIN_POOL:
      if(pooled) P_next = S_MAIN_TRANS;
      else P_next = S_MAIN_POOL;
    S_MAIN_TRANS:
      if(transformed) P_next = S_MAIN_MULT;
      else P_next = S_MAIN_TRANS;
    S_MAIN_MULT:
      if(multiplied) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_MULT;
    S_MAIN_WAIT:
      P_next = S_MAIN_SHOW_line1;
    S_MAIN_SHOW_line1: // wait for a button click
      if (print_done) P_next = S_MAIN_READ_line2;
      else P_next = S_MAIN_SHOW_line1;
    S_MAIN_READ_line2: // wait for a button click
      P_next = S_MAIN_SHOW_line2;
    S_MAIN_SHOW_line2: // wait for a button click
      if (print_done) P_next = S_MAIN_READ_line3;
      else P_next = S_MAIN_SHOW_line2;
    S_MAIN_READ_line3: // wait for a button click
      P_next = S_MAIN_SHOW_line3;
    S_MAIN_SHOW_line3: // wait for a button click
      if (print_done) P_next = S_MAIN_READ_line4;
      else P_next = S_MAIN_SHOW_line3;
    S_MAIN_READ_line4: // wait for a button click
      P_next = S_MAIN_SHOW_line4;
    S_MAIN_SHOW_line4: // wait for a button click
      if (print_done) P_next = S_MAIN_READ_line5;
      else P_next = S_MAIN_SHOW_line4;
    S_MAIN_READ_line5: // wait for a button click
      P_next = S_MAIN_SHOW_line5;
    S_MAIN_SHOW_line5: // wait for a button click
      if (print_done) P_next = S_MAIN_READ_line6;
      else P_next = S_MAIN_SHOW_line5;
    S_MAIN_READ_line6: // wait for a button click
      P_next = S_MAIN_SHOW_line6;
    S_MAIN_SHOW_line6: // wait for a button click
      if (print_done) P_next = S_MAIN_FINISH;
      else P_next = S_MAIN_SHOW_line6;
    S_MAIN_FINISH: // wait for a button click
      P_next = S_MAIN_FINISH;
  endcase
end
// pooling
localparam [3:0] POOL_IDLE      = 4'b0000,
                 POOL_SET_ADDR_A = 4'b0001,
                 POOL_WAIT_A     = 4'b0010,
                 POOL_READ_A     = 4'b0011,
                 POOL_NEXT_A     = 4'b0100,
                 POOL_SET_ADDR_B = 4'b0101,
                 POOL_WAIT_B     = 4'b0110,
                 POOL_READ_B     = 4'b0111,
                 POOL_NEXT_B     = 4'b1000,
                 POOL_DONE       = 4'b1001;

// FSM Registers
reg [3:0] current, current_next;
reg [7:0] current_max_A, current_max_B;
reg [3:0] window_index_A, window_index_B; // 0~8 for 3x3 window
reg [4:0] out_index_A, out_index_B; // 0~24 for 5x5 output
reg [2:0] i_A, j_A, i_B, j_B; // Output matrix indices
reg [1:0] window_row_A, window_col_A, window_row_B, window_col_B; // Window indices

// FSM State Transition Logic
always @(*) begin
  if (P == S_MAIN_POOL) begin
    case (current)
      POOL_IDLE:
        current_next = POOL_SET_ADDR_A;
      POOL_SET_ADDR_A:
        current_next = POOL_WAIT_A;
      POOL_WAIT_A:
        current_next = POOL_READ_A;
      POOL_READ_A:
        if (window_index_A == 8)
          current_next = POOL_NEXT_A;
        else
          current_next = POOL_SET_ADDR_A;
      POOL_NEXT_A:
        if (out_index_A == 24)
          current_next = POOL_SET_ADDR_B;
        else
          current_next = POOL_SET_ADDR_A;
      POOL_SET_ADDR_B:
        current_next = POOL_WAIT_B;
      POOL_WAIT_B:
        current_next = POOL_READ_B;
      POOL_READ_B:
        if (window_index_B == 8)
          current_next = POOL_NEXT_B;
        else
          current_next = POOL_SET_ADDR_B;
      POOL_NEXT_B:
        if (out_index_B == 24)
          current_next = POOL_DONE;
        else
          current_next = POOL_SET_ADDR_B;
      POOL_DONE:
        current_next = POOL_DONE;
      default:
        current_next = POOL_IDLE;
    endcase
  end else begin
    current_next = POOL_IDLE;
  end
end

// FSM Output Logic and State Updates
always @(posedge clk) begin
  if (~reset_n) begin
    current <= POOL_IDLE;
    pooled <= 0;
    out_index_A <= 0;
    window_index_A <= 0;
    current_max_A <= 0;
    address_A <= 0;
    // Initialize variables for B similarly
  end else begin
    current <= current_next;
    if (P == S_MAIN_POOL) begin
      case (current)
        POOL_IDLE: begin
          // Reset variables for A
          pooled <= 0;
          out_index_A <= 0;
          window_index_A <= 0;
          current_max_A <= 0;
          address_A <= 0;
          // Reset variables for B
          out_index_B <= 0;
          window_index_B <= 0;
          current_max_B <= 0;
          address_B <= 49; // Starting address for B
        end
        POOL_SET_ADDR_A: begin
          // Compute address for A
          i_A = out_index_A / 5;
          j_A = out_index_A % 5;
          window_row_A = window_index_A / 3;
          window_col_A = window_index_A % 3;
          address_A <= (i_A + window_row_A) * 7 + (j_A + window_col_A);
        end
        POOL_WAIT_A: begin
          // Wait for BRAM read latency
        end
        POOL_READ_A: begin
          // Read data from BRAM and update current_max_A
          if (window_index_A == 0)
            current_max_A <= sram_data_out_A;
          else if (current_max_A < sram_data_out_A)
            current_max_A <= sram_data_out_A;
          window_index_A <= window_index_A + 1;
        end
        POOL_NEXT_A: begin
          // Store the pooled value into pooled_A
          pooled_A[out_index_A / 5][out_index_A % 5] <= current_max_A;
          out_index_A <= out_index_A + 1;
          window_index_A <= 0;
          current_max_A <= 0;
        end
        // Similar cases for B
        POOL_SET_ADDR_B: begin
          i_B = out_index_B / 5;
          j_B = out_index_B % 5;
          window_row_B = window_index_B / 3;
          window_col_B = window_index_B % 3;
          address_B <= (i_B + window_row_B) * 7 + (j_B + window_col_B) + 49;
        end
        POOL_WAIT_B: begin
          // Wait for BRAM read latency
        end
        POOL_READ_B: begin
          if (window_index_B == 0)
            current_max_B <= sram_data_out_B;
          else if (current_max_B < sram_data_out_B)
            current_max_B <= sram_data_out_B;
          window_index_B <= window_index_B + 1;
        end
        POOL_NEXT_B: begin
          pooled_B[out_index_B / 5][out_index_B % 5] <= current_max_B;
          out_index_B <= out_index_B + 1;
          window_index_B <= 0;
          current_max_B <= 0;
        end
        POOL_DONE: begin
          pooled <= 1; 
        end
      endcase
    end
  end
end

// tranforming
always @(posedge clk) begin
    if(~reset_n) begin
        transformed <= 0;
    end else if (P == S_MAIN_TRANS) begin
        trans_A[0][0] <= pooled_A[0][0];
        trans_A[0][1] <= pooled_A[1][0];
        trans_A[0][2] <= pooled_A[2][0];
        trans_A[0][3] <= pooled_A[3][0];
        trans_A[0][4] <= pooled_A[4][0];
        trans_A[1][0] <= pooled_A[0][1];
        trans_A[1][1] <= pooled_A[1][1];
        trans_A[1][2] <= pooled_A[2][1];
        trans_A[1][3] <= pooled_A[3][1];
        trans_A[1][4] <= pooled_A[4][1];
        trans_A[2][0] <= pooled_A[0][2];
        trans_A[2][1] <= pooled_A[1][2];
        trans_A[2][2] <= pooled_A[2][2];
        trans_A[2][3] <= pooled_A[3][2];
        trans_A[2][4] <= pooled_A[4][2];
        trans_A[3][0] <= pooled_A[0][3];
        trans_A[3][1] <= pooled_A[1][3];
        trans_A[3][2] <= pooled_A[2][3];
        trans_A[3][3] <= pooled_A[3][3];
        trans_A[3][4] <= pooled_A[4][3];
        trans_A[4][0] <= pooled_A[0][4];
        trans_A[4][1] <= pooled_A[1][4];
        trans_A[4][2] <= pooled_A[2][4];
        trans_A[4][3] <= pooled_A[3][4];
        trans_A[4][4] <= pooled_A[4][4];
        transformed = 1;
    end
end
// multiplying
localparam [2:0] MULT_IDLE = 3'b000, 
                 MULT_INIT = 3'b001,
                 MULT_CALC = 3'b010,
                 MULT_WAIT = 3'b011,
                 MULT_ADD  = 3'b100,
                 MULT_STORE= 3'b101,
                 MULT_NEXT = 3'b110,
                 MULT_DONE = 3'b111;

reg [2:0] mult_current, mult_next;
reg [2:0] mult_row, mult_col; // 0~4
reg [2:0] k; // 0~4
reg [19:0] product, sum;

always @(posedge clk) begin
    if (~reset_n)
        mult_current <= MULT_IDLE;
    else
        mult_current <= mult_next;
end

always @(*) begin
    if(P == S_MAIN_MULT || P_next == S_MAIN_MULT) begin
        case (mult_current)
            MULT_IDLE:
                mult_next = MULT_INIT;
            MULT_INIT:
                mult_next = MULT_CALC;
            MULT_CALC:
                mult_next = MULT_WAIT;
            MULT_WAIT:
                mult_next = MULT_ADD;
            MULT_ADD:
                if (k == 4)
                    mult_next = MULT_STORE;
                else
                    mult_next = MULT_CALC;
            MULT_STORE:
                mult_next = MULT_NEXT;
            MULT_NEXT:
                if (mult_row == 4 && mult_col == 4)
                    mult_next = MULT_DONE;
                else
                    mult_next = MULT_INIT;
            MULT_DONE:
                mult_next = MULT_DONE;
            default:
                mult_next = MULT_IDLE;
        endcase
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        multiplied <= 0;
        mult_row <= 0;
        mult_col <= 0;
        k <= 0;
        sum <= 0;
        product <= 0;
    end else if (P == S_MAIN_MULT) begin
        case (mult_current)
            MULT_IDLE: begin
                multiplied <= 0;
            end
            MULT_INIT: begin
                sum <= 0;
                k <= 0;
            end
            MULT_CALC: begin
                product <= trans_A[mult_row][k] * pooled_B[k][mult_col];
            end
            MULT_WAIT: begin
                // Wait for product to update
            end
            MULT_ADD: begin
                sum <= sum + product;
                if (k == 4) begin
                    // Do not increment k; stay at k == 4
                end else begin
                    k <= k + 1;
                end
            end
            MULT_STORE: begin
                matrix[mult_row][mult_col] <= sum;
            end 
            MULT_NEXT: begin
                if (mult_col < 4)
                    mult_col <= mult_col + 1;
                else begin
                    mult_col <= 0;
                    if (mult_row < 4)
                        mult_row <= mult_row + 1;
                end
            end
            MULT_DONE: begin
                multiplied <= 1;
            end
        endcase
    end
end
// End of the main controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The following code updates the 1602 LCD text messages.

localparam MEM_SIZE = 204;
localparam LINE2_STR = 34;
localparam LINE3_STR = 68;
localparam LINE4_STR = 102;
localparam LINE5_STR = 136;
localparam LINE6_STR = 170;
localparam LINE1_STR = 0;  // starting index of the prompt message
localparam PROMPT_LEN = 34; // length of the prompt message

reg [0:PROMPT_LEN*8-1] msg1 = { "The matrix operation result is:\015\012", 8'h00 };
reg [0:PROMPT_LEN*8-1] msg2 = { "[00000,00000,00000,00000,00000]\015\012", 8'h00 };
reg [0:PROMPT_LEN*8-1] msg3 = { "[00000,00000,00000,00000,00000]\015\012", 8'h00 };
reg [0:PROMPT_LEN*8-1] msg4 = { "[00000,00000,00000,00000,00000]\015\012", 8'h00 };
reg [0:PROMPT_LEN*8-1] msg5 = { "[00000,00000,00000,00000,00000]\015\012", 8'h00 };
reg [0:PROMPT_LEN*8-1] msg6 = { "[00000,00000,00000,00000,00000]\015\012", 8'h00 };
reg [1:0] Q, Q_next;
reg [7:0] data [0:MEM_SIZE-1];
reg [$clog2(MEM_SIZE):0] send_counter;

integer idx;

always @(posedge clk) begin
  if (~reset_n) begin
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx+LINE1_STR] = msg1[idx*8 +: 8];
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx+LINE2_STR] = msg2[idx*8 +: 8];
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx+LINE3_STR] = msg3[idx*8 +: 8];
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx+LINE4_STR] = msg4[idx*8 +: 8];
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx+LINE5_STR] = msg5[idx*8 +: 8];
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx+LINE6_STR] = msg6[idx*8 +: 8];
  end
  else if (P == S_MAIN_SHOW_line1) begin
    data[LINE2_STR+1] <= ((matrix[0][0][18:16] > 9)? "7" : "0") + matrix[0][0][18:16];
    data[LINE2_STR+2] <= ((matrix[0][0][15:12] > 9)? "7" : "0") + matrix[0][0][15:12];
    data[LINE2_STR+3] <= ((matrix[0][0][11: 8] > 9)? "7" : "0") + matrix[0][0][11: 8];
    data[LINE2_STR+4] <= ((matrix[0][0][ 7: 4] > 9)? "7" : "0") + matrix[0][0][ 7: 4];
    data[LINE2_STR+5] <= ((matrix[0][0][ 3: 0] > 9)? "7" : "0") + matrix[0][0][ 3: 0];
    
    data[LINE2_STR+7] <= ((matrix[0][1][18:16] > 9)? "7" : "0") + matrix[0][1][18:16];
    data[LINE2_STR+8] <= ((matrix[0][1][15:12] > 9)? "7" : "0") + matrix[0][1][15:12];
    data[LINE2_STR+9] <= ((matrix[0][1][11: 8] > 9)? "7" : "0") + matrix[0][1][11: 8];
    data[LINE2_STR+10] <= ((matrix[0][1][ 7: 4] > 9)? "7" : "0") + matrix[0][1][ 7: 4];
    data[LINE2_STR+11] <= ((matrix[0][1][ 3: 0] > 9)? "7" : "0") + matrix[0][1][ 3: 0];
    
    data[LINE2_STR+13] <= ((matrix[0][2][18:16] > 9)? "7" : "0") + matrix[0][2][18:16];
    data[LINE2_STR+14] <= ((matrix[0][2][15:12] > 9)? "7" : "0") + matrix[0][2][15:12];
    data[LINE2_STR+15] <= ((matrix[0][2][11: 8] > 9)? "7" : "0") + matrix[0][2][11: 8];
    data[LINE2_STR+16] <= ((matrix[0][2][ 7: 4] > 9)? "7" : "0") + matrix[0][2][ 7: 4];
    data[LINE2_STR+17] <= ((matrix[0][2][ 3: 0] > 9)? "7" : "0") + matrix[0][2][ 3: 0];
    
    data[LINE2_STR+19] <= ((matrix[0][3][18:16] > 9)? "7" : "0") + matrix[0][3][18:16];
    data[LINE2_STR+20] <= ((matrix[0][3][15:12] > 9)? "7" : "0") + matrix[0][3][15:12];
    data[LINE2_STR+21] <= ((matrix[0][3][11: 8] > 9)? "7" : "0") + matrix[0][3][11: 8];
    data[LINE2_STR+22] <= ((matrix[0][3][ 7: 4] > 9)? "7" : "0") + matrix[0][3][ 7: 4];
    data[LINE2_STR+23] <= ((matrix[0][3][ 3: 0] > 9)? "7" : "0") + matrix[0][3][ 3: 0];
    
    data[LINE2_STR+25] <= ((matrix[0][4][18:16] > 9)? "7" : "0") + matrix[0][4][18:16];
    data[LINE2_STR+26] <= ((matrix[0][4][15:12] > 9)? "7" : "0") + matrix[0][4][15:12];
    data[LINE2_STR+27] <= ((matrix[0][4][11: 8] > 9)? "7" : "0") + matrix[0][4][11: 8];
    data[LINE2_STR+28] <= ((matrix[0][4][ 7: 4] > 9)? "7" : "0") + matrix[0][4][ 7: 4];
    data[LINE2_STR+29] <= ((matrix[0][4][ 3: 0] > 9)? "7" : "0") + matrix[0][4][ 3: 0];
    
    data[LINE3_STR+1] <= ((matrix[1][0][18:16] > 9)? "7" : "0") + matrix[1][0][18:16];
    data[LINE3_STR+2] <= ((matrix[1][0][15:12] > 9)? "7" : "0") + matrix[1][0][15:12];
    data[LINE3_STR+3] <= ((matrix[1][0][11: 8] > 9)? "7" : "0") + matrix[1][0][11: 8];
    data[LINE3_STR+4] <= ((matrix[1][0][ 7: 4] > 9)? "7" : "0") + matrix[1][0][ 7: 4];
    data[LINE3_STR+5] <= ((matrix[1][0][ 3: 0] > 9)? "7" : "0") + matrix[1][0][ 3: 0];
    
    data[LINE3_STR+7] <= ((matrix[1][1][18:16] > 9)? "7" : "0") + matrix[1][1][18:16];
    data[LINE3_STR+8] <= ((matrix[1][1][15:12] > 9)? "7" : "0") + matrix[1][1][15:12];
    data[LINE3_STR+9] <= ((matrix[1][1][11: 8] > 9)? "7" : "0") + matrix[1][1][11: 8];
    data[LINE3_STR+10] <= ((matrix[1][1][ 7: 4] > 9)? "7" : "0") + matrix[1][1][ 7: 4];
    data[LINE3_STR+11] <= ((matrix[1][1][ 3: 0] > 9)? "7" : "0") + matrix[1][1][ 3: 0];
    
    data[LINE3_STR+13] <= ((matrix[1][2][18:16] > 9)? "7" : "0") + matrix[1][2][18:16];
    data[LINE3_STR+14] <= ((matrix[1][2][15:12] > 9)? "7" : "0") + matrix[1][2][15:12];
    data[LINE3_STR+15] <= ((matrix[1][2][11: 8] > 9)? "7" : "0") + matrix[1][2][11: 8];
    data[LINE3_STR+16] <= ((matrix[1][2][ 7: 4] > 9)? "7" : "0") + matrix[1][2][ 7: 4];
    data[LINE3_STR+17] <= ((matrix[1][2][ 3: 0] > 9)? "7" : "0") + matrix[1][2][ 3: 0];
    
    data[LINE3_STR+19] <= ((matrix[1][3][18:16] > 9)? "7" : "0") + matrix[1][3][18:16];
    data[LINE3_STR+20] <= ((matrix[1][3][15:12] > 9)? "7" : "0") + matrix[1][3][15:12];
    data[LINE3_STR+21] <= ((matrix[1][3][11: 8] > 9)? "7" : "0") + matrix[1][3][11: 8];
    data[LINE3_STR+22] <= ((matrix[1][3][ 7: 4] > 9)? "7" : "0") + matrix[1][3][ 7: 4];
    data[LINE3_STR+23] <= ((matrix[1][3][ 3: 0] > 9)? "7" : "0") + matrix[1][3][ 3: 0];
    
    data[LINE3_STR+25] <= ((matrix[1][4][18:16] > 9)? "7" : "0") + matrix[1][4][18:16];
    data[LINE3_STR+26] <= ((matrix[1][4][15:12] > 9)? "7" : "0") + matrix[1][4][15:12];
    data[LINE3_STR+27] <= ((matrix[1][4][11: 8] > 9)? "7" : "0") + matrix[1][4][11: 8];
    data[LINE3_STR+28] <= ((matrix[1][4][ 7: 4] > 9)? "7" : "0") + matrix[1][4][ 7: 4];
    data[LINE3_STR+29] <= ((matrix[1][4][ 3: 0] > 9)? "7" : "0") + matrix[1][4][ 3: 0];
    
    data[LINE4_STR+1] <= ((matrix[2][0][18:16] > 9)? "7" : "0") + matrix[2][0][18:16];
    data[LINE4_STR+2] <= ((matrix[2][0][15:12] > 9)? "7" : "0") + matrix[2][0][15:12];
    data[LINE4_STR+3] <= ((matrix[2][0][11: 8] > 9)? "7" : "0") + matrix[2][0][11: 8];
    data[LINE4_STR+4] <= ((matrix[2][0][ 7: 4] > 9)? "7" : "0") + matrix[2][0][ 7: 4];
    data[LINE4_STR+5] <= ((matrix[2][0][ 3: 0] > 9)? "7" : "0") + matrix[2][0][ 3: 0];
    
    data[LINE4_STR+7] <= ((matrix[2][1][18:16] > 9)? "7" : "0") + matrix[2][1][18:16];
    data[LINE4_STR+8] <= ((matrix[2][1][15:12] > 9)? "7" : "0") + matrix[2][1][15:12];
    data[LINE4_STR+9] <= ((matrix[2][1][11: 8] > 9)? "7" : "0") + matrix[2][1][11: 8];
    data[LINE4_STR+10] <= ((matrix[2][1][ 7: 4] > 9)? "7" : "0") + matrix[2][1][ 7: 4];
    data[LINE4_STR+11] <= ((matrix[2][1][ 3: 0] > 9)? "7" : "0") + matrix[2][1][ 3: 0];
    
    data[LINE4_STR+13] <= ((matrix[2][2][18:16] > 9)? "7" : "0") + matrix[2][2][18:16];
    data[LINE4_STR+14]<= ((matrix[2][2][15:12] > 9)? "7" : "0") + matrix[2][2][15:12];
    data[LINE4_STR+15] <= ((matrix[2][2][11: 8] > 9)? "7" : "0") + matrix[2][2][11: 8];
    data[LINE4_STR+16] <= ((matrix[2][2][ 7: 4] > 9)? "7" : "0") + matrix[2][2][ 7: 4];
    data[LINE4_STR+17] <= ((matrix[2][2][ 3: 0] > 9)? "7" : "0") + matrix[2][2][ 3: 0];
    
    data[LINE4_STR+19] <= ((matrix[2][3][18:16] > 9)? "7" : "0") + matrix[2][3][18:16];
    data[LINE4_STR+20] <= ((matrix[2][3][15:12] > 9)? "7" : "0") + matrix[2][3][15:12];
    data[LINE4_STR+21] <= ((matrix[2][3][11: 8] > 9)? "7" : "0") + matrix[2][3][11: 8];
    data[LINE4_STR+22] <= ((matrix[2][3][ 7: 4] > 9)? "7" : "0") + matrix[2][3][ 7: 4];
    data[LINE4_STR+23] <= ((matrix[2][3][ 3: 0] > 9)? "7" : "0") + matrix[2][3][ 3: 0];
    
    data[LINE4_STR+25] <= ((matrix[2][4][18:16] > 9)? "7" : "0") + matrix[2][4][18:16];
    data[LINE4_STR+26] <= ((matrix[2][4][15:12] > 9)? "7" : "0") + matrix[2][4][15:12];
    data[LINE4_STR+27] <= ((matrix[2][4][11: 8] > 9)? "7" : "0") + matrix[2][4][11: 8];
    data[LINE4_STR+28] <= ((matrix[2][4][ 7: 4] > 9)? "7" : "0") + matrix[2][4][ 7: 4];
    data[LINE4_STR+29] <= ((matrix[2][4][ 3: 0] > 9)? "7" : "0") + matrix[2][4][ 3: 0];
    
    data[LINE5_STR+1] <= ((matrix[3][0][18:16] > 9)? "7" : "0") + matrix[3][0][18:16];
    data[LINE5_STR+2] <= ((matrix[3][0][15:12] > 9)? "7" : "0") + matrix[3][0][15:12];
    data[LINE5_STR+3] <= ((matrix[3][0][11: 8] > 9)? "7" : "0") + matrix[3][0][11: 8];
    data[LINE5_STR+4] <= ((matrix[3][0][ 7: 4] > 9)? "7" : "0") + matrix[3][0][ 7: 4];
    data[LINE5_STR+5] <= ((matrix[3][0][ 3: 0] > 9)? "7" : "0") + matrix[3][0][ 3: 0];
    
    data[LINE5_STR+7] <= ((matrix[3][1][18:16] > 9)? "7" : "0") + matrix[3][1][18:16];
    data[LINE5_STR+8] <= ((matrix[3][1][15:12] > 9)? "7" : "0") + matrix[3][1][15:12];
    data[LINE5_STR+9] <= ((matrix[3][1][11: 8] > 9)? "7" : "0") + matrix[3][1][11: 8];
    data[LINE5_STR+10] <= ((matrix[3][1][ 7: 4] > 9)? "7" : "0") + matrix[3][1][ 7: 4];
    data[LINE5_STR+11] <= ((matrix[3][1][ 3: 0] > 9)? "7" : "0") + matrix[3][1][ 3: 0];
    
    data[LINE5_STR+13] <= ((matrix[3][2][18:16] > 9)? "7" : "0") + matrix[3][2][18:16];
    data[LINE5_STR+14] <= ((matrix[3][2][15:12] > 9)? "7" : "0") + matrix[3][2][15:12];
    data[LINE5_STR+15] <= ((matrix[3][2][11: 8] > 9)? "7" : "0") + matrix[3][2][11: 8];
    data[LINE5_STR+16] <= ((matrix[3][2][ 7: 4] > 9)? "7" : "0") + matrix[3][2][ 7: 4];
    data[LINE5_STR+17] <= ((matrix[3][2][ 3: 0] > 9)? "7" : "0") + matrix[3][2][ 3: 0];
    
    data[LINE5_STR+19] <= ((matrix[3][3][18:16] > 9)? "7" : "0") + matrix[3][3][18:16];
    data[LINE5_STR+20] <= ((matrix[3][3][15:12] > 9)? "7" : "0") + matrix[3][3][15:12];
    data[LINE5_STR+21] <= ((matrix[3][3][11: 8] > 9)? "7" : "0") + matrix[3][3][11: 8];
    data[LINE5_STR+22] <= ((matrix[3][3][ 7: 4] > 9)? "7" : "0") + matrix[3][3][ 7: 4];
    data[LINE5_STR+23] <= ((matrix[3][3][ 3: 0] > 9)? "7" : "0") + matrix[3][3][ 3: 0];
    
    data[LINE5_STR+25] <= ((matrix[3][4][18:16] > 9)? "7" : "0") + matrix[3][4][18:16];
    data[LINE5_STR+26] <= ((matrix[3][4][15:12] > 9)? "7" : "0") + matrix[3][4][15:12];
    data[LINE5_STR+27] <= ((matrix[3][4][11: 8] > 9)? "7" : "0") + matrix[3][4][11: 8];
    data[LINE5_STR+28] <= ((matrix[3][4][ 7: 4] > 9)? "7" : "0") + matrix[3][4][ 7: 4];
    data[LINE5_STR+29] <= ((matrix[3][4][ 3: 0] > 9)? "7" : "0") + matrix[3][4][ 3: 0];
    
    data[LINE6_STR+1] <= ((matrix[4][0][18:16] > 9)? "7" : "0") + matrix[4][0][18:16];
    data[LINE6_STR+2] <= ((matrix[4][0][15:12] > 9)? "7" : "0") + matrix[4][0][15:12];
    data[LINE6_STR+3] <= ((matrix[4][0][11: 8] > 9)? "7" : "0") + matrix[4][0][11: 8];
    data[LINE6_STR+4] <= ((matrix[4][0][ 7: 4] > 9)? "7" : "0") + matrix[4][0][ 7: 4];
    data[LINE6_STR+5] <= ((matrix[4][0][ 3: 0] > 9)? "7" : "0") + matrix[4][0][ 3: 0];
    
    data[LINE6_STR+7] <= ((matrix[4][1][18:16] > 9)? "7" : "0") + matrix[4][1][18:16];
    data[LINE6_STR+8] <= ((matrix[4][1][15:12] > 9)? "7" : "0") + matrix[4][1][15:12];
    data[LINE6_STR+9] <= ((matrix[4][1][11: 8] > 9)? "7" : "0") + matrix[4][1][11: 8];
    data[LINE6_STR+10] <= ((matrix[4][1][ 7: 4] > 9)? "7" : "0") + matrix[4][1][ 7: 4];
    data[LINE6_STR+11] <= ((matrix[4][1][ 3: 0] > 9)? "7" : "0") + matrix[4][1][ 3: 0];
    
    data[LINE6_STR+13] <= ((matrix[4][2][18:16] > 9)? "7" : "0") + matrix[4][2][18:16];
    data[LINE6_STR+14] <= ((matrix[4][2][15:12] > 9)? "7" : "0") + matrix[4][2][15:12];
    data[LINE6_STR+15] <= ((matrix[4][2][11: 8] > 9)? "7" : "0") + matrix[4][2][11: 8];
    data[LINE6_STR+16] <= ((matrix[4][2][ 7: 4] > 9)? "7" : "0") + matrix[4][2][ 7: 4];
    data[LINE6_STR+17] <= ((matrix[4][2][ 3: 0] > 9)? "7" : "0") + matrix[4][2][ 3: 0];
    
    data[LINE6_STR+19] <= ((matrix[4][3][18:16] > 9)? "7" : "0") + matrix[4][3][18:16];
    data[LINE6_STR+20] <= ((matrix[4][3][15:12] > 9)? "7" : "0") + matrix[4][3][15:12];
    data[LINE6_STR+21] <= ((matrix[4][3][11: 8] > 9)? "7" : "0") + matrix[4][3][11: 8];
    data[LINE6_STR+22] <= ((matrix[4][3][ 7: 4] > 9)? "7" : "0") + matrix[4][3][ 7: 4];
    data[LINE6_STR+23] <= ((matrix[4][3][ 3: 0] > 9)? "7" : "0") + matrix[4][3][ 3: 0];
    
    data[LINE6_STR+25] <= ((matrix[4][4][18:16] > 9)? "7" : "0") + matrix[4][4][18:16];
    data[LINE6_STR+26] <= ((matrix[4][4][15:12] > 9)? "7" : "0") + matrix[4][4][15:12];
    data[LINE6_STR+27] <= ((matrix[4][4][11: 8] > 9)? "7" : "0") + matrix[4][4][11: 8];
    data[LINE6_STR+28] <= ((matrix[4][4][ 7: 4] > 9)? "7" : "0") + matrix[4][4][ 7: 4];
    data[LINE6_STR+29] <= ((matrix[4][4][ 3: 0] > 9)? "7" : "0") + matrix[4][4][ 3: 0];
  end
end
// FSM of the controller that sends a string to the UART.
always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

// FSM output logics: UART transmission control signals
assign transmit = (Q_next == S_UART_WAIT) || print_enable;
assign tx_byte = data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
    case (P_next)
        S_MAIN_WAIT: send_counter <= LINE1_STR;
        S_MAIN_READ_line2: send_counter <= LINE2_STR;
        S_MAIN_READ_line3: send_counter <= LINE3_STR;
        S_MAIN_READ_line4: send_counter <= LINE4_STR;
        S_MAIN_READ_line5: send_counter <= LINE5_STR;
        S_MAIN_READ_line6: send_counter <= LINE6_STR;
        default: send_counter <= send_counter + (Q_next == S_UART_INCR);
    endcase   
end
endmodule