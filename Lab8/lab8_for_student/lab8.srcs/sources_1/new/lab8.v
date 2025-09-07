`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
//
// Create Date: 2017/05/08 15:29:41
// Design Name:
// Module Name: lab6
// Project Name:
// Target Devices:
// Tool Versions:
// Description: The sample top module of lab 6: sd card reader. The behavior of
//              this module is as follows
//              1. When the SD card is initialized, display a message on the LCD.
//                 If the initialization fails, an error message will be shown.
//              2. The user can then press usr_btn[2] to trigger the sd card
//                 controller to read the super block of the sd card (located at
//                 block # 8192) into the SRAM memory.
//              3. During SD card reading time, the four LED lights will be turned on.
//                 They will be turned off when the reading is done.
//              4. The LCD will then displayer the sector just been read, and the
//                 first byte of the sector.
//              5. Everytime you press usr_btn[2], the next byte will be displayed.
//
// Dependencies: clk_divider, LCD_module, debounce, sd_card
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module lab8(input clk,
            input reset_n,
            input [3:0] usr_btn,
            output [3:0] usr_led,
            output spi_ss,
            output spi_sck,
            output spi_mosi,
            input spi_miso,
            output LCD_RS,
            output LCD_RW,
            output LCD_E,
            output [3:0] LCD_D,
            output [3:0] rgb_led_r,
            output [3:0] rgb_led_g,
            output [3:0] rgb_led_b);
    
    localparam [3:0]
    S_MAIN_INIT = 4'b0000,
    S_MAIN_IDLE = 4'b0001,
    S_MAIN_WAIT = 4'b0010,
    S_MAIN_WAIT_READ = 4'b1100,
    S_MAIN_WAIT_COMP = 4'b1101,
    S_MAIN_READ = 4'b0011, // wait for the input data to enter the SRAM buffer
    S_MAIN_WATF = 4'b1000, // wait for the input data to enter the SRAM buffer
    S_MAIN_FIND = 4'b0111, // find DCL_START && DCL_END
    S_MAIN_COMP = 4'b1010, // comparing
    S_MAIN_WAIT_PROC = 4'b1001,
    S_MAIN_PROC = 4'b0110, // run RGB
    S_MAIN_DONE = 4'b0100,
    S_MAIN_SHOW = 4'b0101; // show calculate led's num
    
    // Declare system variables
    wire btn_level, btn_pressed;
    reg  prev_btn_level;
    reg  [5:0] send_counter;
    reg  [3:0] P, P_next;
    reg  [9:0] sd_counter;
    reg  [9:0] second_counter;
    reg  [9:0] counter;
    reg  [7:0] data_byte;
    reg  [31:0] blk_addr;
    reg  [3:0] buffer;
    reg  [19:0] pwm_counter;
    reg [31:0] display_flag;
    
    
    reg  [127:0] row_A = "SD card cannot  ";
    reg  [127:0] row_B = "be initialized! ";
    reg  done_flag; // Signals the completion of reading one SD sector.
    
    // led controller
    reg [3:0] led_r, led_g, led_b;
    reg [3:0] count_r, count_g, count_b, count_p, count_y, count_x;
    assign rgb_led_r = led_r;
    assign rgb_led_g = led_g;
    assign rgb_led_b = led_b;
    
    
    // find DCL_START, DCL_END and display rgb
    reg  [71:0] text; // find DCL_START
    reg  [71:0] DCL_START_LABEL = "DCL_START";
    reg  [55:0] DCL_END_LABEL   = "DCL_END";
    reg  [31:0] monitor;
    
    // time counter
    parameter change_interval = 32'd200_000_000;
    reg  [31:0] time_counter;
    // Declare SD card interface signals
    wire clk_sel;
    wire clk_500k;
    reg  rd_req;
    reg  [31:0] rd_addr;
    wire init_finished;
    wire [7:0] sd_dout;
    wire sd_valid;
    
    // Declare the control/data signals of an SRAM memory block
    wire [7:0] data_in;
    wire [7:0] data_out;
    wire [8:0] sram_addr;
    wire       sram_we, sram_en;
    
    assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller
    
    clk_divider#(200) clk_divider0(
    .clk(clk),
    .reset(~reset_n),
    .clk_out(clk_500k)
    );
    
    debounce btn_db0(
    .clk(clk),
    .btn_input(usr_btn[2]),
    .btn_output(btn_level)
    );
    
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
    
    sd_card sd_card0(
    .cs(spi_ss),
    .sclk(spi_sck),
    .mosi(spi_mosi),
    .miso(spi_miso),
    
    .clk(clk_sel),
    .rst(~reset_n),
    .rd_req(rd_req),
    .block_addr(rd_addr),
    .init_finished(init_finished),
    .dout(sd_dout),
    .sd_valid(sd_valid)
    );
    
    sram ram0(
    .clk(clk),
    .we(sram_we),
    .en(sram_en),
    .addr(sram_addr),
    .data_i(data_in),
    .data_o(data_out)
    );
    
    //
    // Enable one cycle of btn_pressed per each button hit
    //
    always @(posedge clk) begin
        if (~reset_n)
            prev_btn_level <= 0;
        else
            prev_btn_level <= btn_level;
    end
    
    assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;
    
    // ------------------------------------------------------------------------
    // The following code sets the control signals of an SRAM memory block
    // that is connected to the data output port of the SD controller.
    // Once the read request is made to the SD controller, 512 bytes of data
    // will be sequentially read into the SRAM memory block, one byte per
    // clock cycle (as long as the sd_valid signal is high).
    assign sram_we   = sd_valid;          // Write data into SRAM when sd_valid is high.
    assign sram_en   = 1;                 // Always enable the SRAM block.
    assign data_in   = sd_dout;           // Input data always comes from the SD controller.
    assign sram_addr = counter; // Set the driver of the SRAM address signal.
    // End of the SRAM memory block
    // ------------------------------------------------------------------------
    
    // ------------------------------------------------------------------------
    // FSM of the SD card reader that reads the super block (512 bytes)
    reg processed;
    reg readed;
    always @(posedge clk) begin
        if (~reset_n) begin
            P <= S_MAIN_INIT;
        end
        else begin
            P <= P_next;
        end
    end
    
    always @(*) begin // FSM next-state logic
        case (P)
            S_MAIN_INIT: // wait for SD card initialization
            if (init_finished)
                P_next      = S_MAIN_IDLE;
                else P_next = S_MAIN_INIT;
            
            S_MAIN_IDLE: // wait for button click
            if (btn_pressed)P_next = S_MAIN_WAIT;
            else P_next            = S_MAIN_IDLE;
            
            S_MAIN_WAIT: begin// issue a rd_req to the SD controller until it's ready
                P_next = S_MAIN_WAIT_READ;
            end
            
            S_MAIN_WAIT_READ:
            if (sd_valid) P_next = S_MAIN_WAIT_COMP;
            else P_next          = S_MAIN_WAIT_READ;
            
            S_MAIN_WAIT_COMP: // find DCL_START
            P_next = S_MAIN_COMP;
            
            S_MAIN_COMP: begin
                if (text == "DCL_START") begin
                    P_next = S_MAIN_WAIT_PROC;
                end
                else if (sd_counter == 512) begin
                    P_next = S_MAIN_WAIT;
                end
                else P_next = S_MAIN_WAIT_READ;
            end
            
            S_MAIN_WAIT_PROC:
            P_next = S_MAIN_PROC;
            
            S_MAIN_PROC: // run RGB
            if (text[55:0] == "DCL_END") begin
                P_next = S_MAIN_DONE;
            end
            else if (processed) begin
                P_next = S_MAIN_WAIT_PROC;
            end
            else P_next = S_MAIN_PROC;
            
            S_MAIN_DONE: // read byte 0 of the superblock from sram[]
            P_next = S_MAIN_SHOW;
            
            S_MAIN_SHOW:
            P_next = S_MAIN_SHOW;
            
            default:
            P_next = S_MAIN_IDLE;
        endcase
    end
    
    //FSM main logic
    always @(posedge clk) begin
        if (~reset_n) begin
            text         <= 72'b0;
            led_r        <= 0;
            led_g        <= 0;
            led_b        <= 0;
            count_r      <= 0;
            count_g      <= 0;
            count_b      <= 0;
            count_p      <= 0;
            count_y      <= 0;
            count_x      <= 0;
            buffer       <= 0;
            counter      <= 0;
            data_byte    <= 8'b0;
            readed       <= 0;
            processed    <= 0;
            display_flag <= 0;
        end
        else begin
            case(P)
                S_MAIN_WAIT: begin
                    counter <= sd_counter;
                    readed  <= 0;
                end
                S_MAIN_WAIT_READ: begin
                    counter   <= sd_counter;
                    data_byte <= data_out;
                end
                S_MAIN_WAIT_COMP: begin
                    counter <= sd_counter;
                    text    <= {text[63:0], data_byte};
                end
                S_MAIN_COMP: begin
                    counter <= sd_counter;
                end
                
                S_MAIN_WAIT_PROC: begin
                    counter   <= sd_counter;
                    data_byte <= data_out;
                    processed <= 0;
                    readed    <= 1;
                end
                S_MAIN_PROC: begin
                    counter <= sd_counter;
                    if (time_counter == change_interval) begin
                        case(data_byte)
                            "R", "r": begin
                                count_r <= count_r + 1;
                            end
                            "G", "g": begin
                                count_g <= count_g + 1;
                            end
                            "B", "b": begin
                                count_b <= count_b + 1;
                            end
                            "P", "p": begin
                                count_p <= count_p + 1;
                            end
                            "Y", "y": begin
                                count_y <= count_y + 1;
                            end
                            default: begin
                                count_x <= count_x + 1;
                            end
                        endcase
                        processed    <= 1;
                        display_flag <= display_flag + 1;
                        if (!(display_flag == 1)) begin
                            text <= {text[63:0], data_byte};
                        end
                    end
                    else if (display_flag > 3) begin
                        case(data_byte)
                            "R", "r": begin
                                led_r[0] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[0] <= 0;
                                led_b[0] <= 0;
                            end
                            "G", "g": begin
                                led_r[0] <= 0;
                                led_g[0] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[0] <= 0;
                            end
                            "B", "b": begin
                                led_r[0] <= 0;
                                led_g[0] <= 0;
                                led_b[0] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "P", "p": begin
                                led_r[0] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[0] <= 0;
                                led_b[0] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "Y", "y": begin
                                led_r[0] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[0] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[0] <= 0;
                            end
                            default: begin
                                led_r[0] <= 0;
                                led_g[0] <= 0;
                                led_b[0] <= 0;
                            end
                        endcase
                        case(text[7:0])
                            "R", "r": begin
                                led_r[1] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[1] <= 0;
                                led_b[1] <= 0;
                            end
                            "G", "g": begin
                                led_r[1] <= 0;
                                led_g[1] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[1] <= 0;
                            end
                            "B", "b": begin
                                led_r[1] <= 0;
                                led_g[1] <= 0;
                                led_b[1] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "P", "p": begin
                                led_r[1] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[1] <= 0;
                                led_b[1] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "Y", "y": begin
                                led_r[1] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[1] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[1] <= 0;
                            end
                            default: begin
                                led_r[1] <= 0;
                                led_g[1] <= 0;
                                led_b[1] <= 0;
                            end
                        endcase
                        case(text[15:8])
                            "R", "r": begin
                                led_r[2] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[2] <= 0;
                                led_b[2] <= 0;
                            end
                            "G", "g": begin
                                led_r[2] <= 0;
                                led_g[2] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[2] <= 0;
                            end
                            "B", "b": begin
                                led_r[2] <= 0;
                                led_g[2] <= 0;
                                led_b[2] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "P", "p": begin
                                led_r[2] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[2] <= 0;
                                led_b[2] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "Y", "y": begin
                                led_r[2] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[2] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[2] <= 0;
                            end
                            default: begin
                                led_r[2] <= 0;
                                led_g[2] <= 0;
                                led_b[2] <= 0;
                            end
                        endcase
                        case(text[23:16])
                            "R", "r": begin
                                led_r[3] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[3] <= 0;
                                led_b[3] <= 0;
                            end
                            "G", "g": begin
                                led_r[3] <= 0;
                                led_g[3] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[3] <= 0;
                            end
                            "B", "b": begin
                                led_r[3] <= 0;
                                led_g[3] <= 0;
                                led_b[3] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "P", "p": begin
                                led_r[3] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[3] <= 0;
                                led_b[3] <= (pwm_counter < 50000)? 1 : 0;
                            end
                            "Y", "y": begin
                                led_r[3] <= (pwm_counter < 50000)? 1 : 0;
                                led_g[3] <= (pwm_counter < 50000)? 1 : 0;
                                led_b[3] <= 0;
                            end
                            default: begin
                                led_r[3] <= 0;
                                led_g[3] <= 0;
                                led_b[3] <= 0;
                            end
                        endcase
                    end
                end
            endcase
        end
    end
    
    // FSM output logic: controls the 'rd_req' and 'rd_addr' signals.
    always @(*) begin
        rd_addr <= blk_addr;
        
        rd_req <= 
        (P == S_MAIN_WAIT);
    end
    
    always @(posedge clk) begin
        if (~reset_n) begin
            blk_addr <= 32'h2000;
            end else if ((P == S_MAIN_COMP && P_next == S_MAIN_WAIT) ||
            (P == S_MAIN_PROC && P_next == S_MAIN_WAIT)) begin
            blk_addr <= blk_addr + 1;
        end
    end
    
    // pwm
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_counter <= 0;
            end else begin
            pwm_counter <= pwm_counter + 1;
        end
    end
    
    // bin to ascii
    function [7:0] bin_to_ascii;
        input [3:0] bin;
        begin
            // Return '0'~'9' ASCII values (48~57)
            bin_to_ascii = bin + 8'd48; // '0' starts at ASCII 48
        end
    endfunction
    
    // SD card read address incrementer
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_COMP && P_next == S_MAIN_WAIT))
            sd_counter <= 0;
        else if (((P == S_MAIN_WAIT_READ) && sd_valid)||
            ((P == S_MAIN_PROC) && processed))
            sd_counter <= sd_counter + 1;
            end
            // End of the FSM of the SD card reader
        
        // process timer
        always @(posedge clk) begin
            if (~reset_n || (P == S_MAIN_WATF && P_next == S_MAIN_FIND) ||
                (P == S_MAIN_WAIT_PROC && P_next == S_MAIN_PROC)) begin
                time_counter <= 0;
                end
            else begin
                
                if (time_counter == change_interval) begin
                    time_counter <= 0;
                end
                else time_counter <= time_counter + 1;
            end
        end
        // FSM ouput logic: Retrieves the content of sram[] for display
        /*always @(posedge clk) begin
         if (~reset_n) data_byte <= 8'b0;
         else if (P == S_MAIN_WATR) begin
         data_byte <= data_out;
         end
         end*/
        
        // ------------------------------------------------------------------------
        
        // ------------------------------------------------------------------------
        // LCD Display function.
        always @(posedge clk) begin
            if (~reset_n) begin
                row_A = "SD card cannot  ";
                row_B = "be initialized! ";
            end
            else if (P == S_MAIN_IDLE) begin
                row_A <= "Hit BTN2 to read";
                row_B <= "the SD card ... ";
            end
                else if ((P == S_MAIN_PROC || P == S_MAIN_WAIT_PROC)) begin
                row_A <= "calculating...  ";
                row_B <= "                ";
                end
                else if (P == S_MAIN_READ || P == S_MAIN_FIND|| P == S_MAIN_WATF|| P == S_MAIN_COMP) begin
                row_A <= "searching for   ";
                row_B <= "title           ";
                end
                
                else if (P == S_MAIN_SHOW) begin
                row_A <= "RGBPYX          ";
                row_B <= {
                bin_to_ascii(count_r),
                bin_to_ascii(count_g),
                bin_to_ascii(count_b),
                bin_to_ascii(count_p),
                bin_to_ascii(count_y),
                bin_to_ascii(count_x-8),
                "          "
                };
                end
                end
                // End of the LCD display function
                // ------------------------------------------------------------------------
                endmodule
