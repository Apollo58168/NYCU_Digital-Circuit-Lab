`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/10/10 16:10:38
// Design Name: UART I/O example for Arty
// Module Name: lab6
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz
// Tool Versions: 
// Description: 
// 
// The parameters for the UART controller are 9600 baudrate, 8-N-1-N
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab6(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx
);

localparam [2:0] S_MAIN_INIT = 0,
                 S_MAIN_PROMPT1 = 1,
                 S_MAIN_READ_NUM1 = 2,
                 S_MAIN_PROMPT2 = 3,
                 S_MAIN_READ_NUM2 = 4,
                 S_MAIN_DIV = 5,
                 S_MAIN_REPLY = 6,
                 S_MAIN_ERROR = 7;
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz
localparam PROMPT1_STR = 0;  // starting index of the prompt message
localparam PROMPT1_LEN = 35; // length of the prompt message
localparam PROMPT2_STR = 35;  // starting index of the prompt2 message
localparam PROMPT2_LEN = 36; // length of the prompt2 message
localparam REPLY_STR  = 71; // starting index of the hello message
localparam REPLY_LEN  = 37; // length of the hello message
localparam ERROR_STR  = 108; // length of the hello message
localparam ERROR_LEN  = 27; // length of the hello message
localparam MEM_SIZE   = PROMPT1_LEN + PROMPT2_LEN + REPLY_LEN + ERROR_LEN;

// declare system variables
wire enter_pressed;
wire print_enable, print_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [2:0] P, P_next;
reg [1:0] Q, Q_next;
reg [$clog2(INIT_DELAY):0] init_counter;
reg [7:0] data[0:MEM_SIZE-1];
reg [0:PROMPT1_LEN*8-1] msg1 = { "\015\012Enter the first decimal number: ", 8'h00 };
reg [0:PROMPT2_LEN*8-1] msg2 = { "\015\012Enter the second decimal number: ", 8'h00 };
reg [0:REPLY_LEN*8-1]   msg3 = { "\015\012The integer quotient is: 0x0000.\015\012", 8'h00 };
reg [0:ERROR_LEN*8-1]   msg4 = { "\015\012ERROR! DIVIDE BY ZERO!\015\012", 8'h00};
reg [15:0] num1, num2, quotient, remainder;  // The key-in number register
reg [2:0] key_cnt;  // The key strokes counter
integer div_counter; // 5-bit counter to handle 16-bit division
reg div_done;

// declare UART signals
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

/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
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

// Initializes some strings.
// System Verilog has an easier way to initialize an array,
// but we are using Verilog 2001 :(
//
integer idx;

always @(posedge clk) begin
  if (~reset_n) begin
    for (idx = 0; idx < PROMPT1_LEN; idx = idx + 1) data[idx+PROMPT1_STR] = msg1[idx*8 +: 8];
    for (idx = 0; idx < PROMPT2_LEN; idx = idx + 1) data[idx+PROMPT2_STR] = msg2[idx*8 +: 8];
    for (idx = 0; idx < REPLY_LEN; idx = idx + 1) data[idx+REPLY_STR] = msg3[idx*8 +: 8];
    for (idx = 0; idx < ERROR_LEN; idx = idx + 1) data[idx+ERROR_STR] = msg4[idx*8 +: 8];
  end
  else if (P == S_MAIN_REPLY) begin
    data[REPLY_STR+29] <= ((quotient[15:12] > 9)? "7" : "0") + quotient[15:12];
    data[REPLY_STR+30] <= ((quotient[11: 8] > 9)? "7" : "0") + quotient[11: 8];
    data[REPLY_STR+31] <= ((quotient[ 7: 4] > 9)? "7" : "0") + quotient[ 7: 4];
    data[REPLY_STR+32] <= ((quotient[ 3: 0] > 9)? "7" : "0") + quotient[ 3: 0];
  end
end

// Combinational I/O logics of the top-level system
assign usr_led = usr_btn;
assign enter_pressed = (rx_temp == 8'h0D); // don't use rx_byte here!

// ------------------------------------------------------------------------
// Main FSM that reads the UART input and triggers
// the output of the string "Hello, World!".
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Wait for initial delay of the circuit.
	   if (init_counter < INIT_DELAY) P_next = S_MAIN_INIT;
		else P_next = S_MAIN_PROMPT1;
    S_MAIN_PROMPT1: // Print the prompt message.
      if (print_done) P_next = S_MAIN_READ_NUM1;
      else P_next = S_MAIN_PROMPT1;
    S_MAIN_READ_NUM1: // wait for <Enter> key.
      if (enter_pressed) P_next = S_MAIN_PROMPT2;
      else P_next = S_MAIN_READ_NUM1;
    S_MAIN_PROMPT2: // Print the prompt message.
      if (print_done) P_next = S_MAIN_READ_NUM2;
      else P_next = S_MAIN_PROMPT2;
    S_MAIN_READ_NUM2: // wait for <Enter> key.
      if (enter_pressed)begin
        if(num2 != 0) P_next = S_MAIN_DIV;
        else P_next = S_MAIN_ERROR;
      end else P_next = S_MAIN_READ_NUM2;
    S_MAIN_DIV:
      if (div_done) P_next = S_MAIN_REPLY;
      else P_next = S_MAIN_DIV;
    S_MAIN_REPLY: // Print the hello message.
      if (print_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_REPLY;
    S_MAIN_ERROR: // Print the error message.
      if (print_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_ERROR;
  endcase
end

// FSM output logics: print string control signals.
assign print_enable = (P != S_MAIN_PROMPT1 && P_next == S_MAIN_PROMPT1) ||
                      (P == S_MAIN_READ_NUM1 && P_next == S_MAIN_PROMPT2) ||
                      (P == S_MAIN_DIV && P_next == S_MAIN_REPLY) ||
                      (P == S_MAIN_READ_NUM2 && P_next == S_MAIN_ERROR);
assign print_done = (tx_byte == 8'h0);

// Initialization counter.
always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
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
assign transmit = (Q_next == S_UART_WAIT ||
                  (P == S_MAIN_READ_NUM1 && received) ||
                  (P == S_MAIN_READ_NUM2 && received) ||
                   print_enable);
assign is_num_key = (rx_byte > 8'h2F) && (rx_byte < 8'h3A) && (key_cnt < 5);
assign echo_key = (is_num_key || rx_byte == 8'h0D)? rx_byte : 0;
assign tx_byte  = (((P == S_MAIN_READ_NUM1) || (P == S_MAIN_READ_NUM2)) && received)? echo_key : data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  case (P_next)
    S_MAIN_INIT: send_counter <= PROMPT1_STR;
    S_MAIN_READ_NUM1: send_counter <= PROMPT2_STR;
    S_MAIN_READ_NUM2: 
        if(num2 != 0)send_counter <= REPLY_STR;
        else send_counter <= ERROR_STR;
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
  endcase
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// UART input logic
// Decimal number input will be saved in num1 or num2.
always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_INIT || P == S_MAIN_PROMPT1 || P == S_MAIN_PROMPT2)) key_cnt <= 0;
  else if (received && is_num_key) key_cnt <= key_cnt + 1;
end

always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_INIT) begin
    num1 <= 0;
    num2 <= 0;
    quotient <= 0;
    remainder <= 0;
    div_done <= 0;
  end else if (P == S_MAIN_READ_NUM1 && received && is_num_key) 
    num1 <= (num1 * 10) + (rx_byte - 48);  // 將讀入的數字存入 num1
  else if (P == S_MAIN_READ_NUM2 && received && is_num_key) 
    num2 <= (num2 * 10) + (rx_byte - 48);  // 將讀入的數字存入 num2
  else if (P == S_MAIN_DIV && !div_done) begin
    for(div_counter = 15; div_counter >= 0; div_counter = div_counter - 1)begin
      remainder = remainder << 1;
      remainder[0] = num1[div_counter];  // 將 num1 的 bit 移入 remainder_temp
      if (remainder >= num2) begin
        remainder = remainder - num2;
        quotient[div_counter] = 1;       // 更新 quotient 的當前位元
      end
    end
    div_done = 1;             
  end
end

// The following logic stores the UART input in a temporary buffer.
// The input character will stay in the buffer for one clock cycle.
always @(posedge clk) begin
  rx_temp <= (received)? rx_byte : 8'h0;
end
// End of the UART input logic
// ------------------------------------------------------------------------
endmodule