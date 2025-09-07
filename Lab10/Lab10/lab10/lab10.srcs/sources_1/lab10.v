`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
//
// Create Date: 2018/12/11 16:04:41
// Design Name:
// Module Name: lab9
// Project Name:
// Target Devices:
// Tool Versions:
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
//
// Dependencies: vga_sync, clk_divider, sram
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module lab10(input clk,
             input reset_n,
             input [3:0] usr_btn,
             output [3:0] usr_led,
             output VGA_HSYNC,
             output VGA_VSYNC,
             output [3:0] VGA_RED,
             output [3:0] VGA_GREEN,
             output [3:0] VGA_BLUE);
    
    // Declare system variables
    reg  [31:0] fish1_clock;
    wire [9:0]  fish1_x_pos;
    wire [9:0]  fish1_y_pos;
    wire        fish1_region;
    reg  [31:0] fish1_clock_y;
    reg  [3:0]  fish1_speed;
    
    reg  [31:0] fish2_clock;
    wire [9:0]  fish2_x_pos;
    wire        fish2_region;
    
    reg  [31:0] fish3_clock;
    wire [9:0]  fish3_x_pos;
    wire        fish3_region;
    // debounce
    wire [1:0]  btn_level, btn_pressed;
    reg  [1:0]  prev_btn_level;
    
    // declare SRAM control signals
    wire [16:0] seabed_sram_addr, fish1_sram_addr, fish2_sram_addr, fish3_sram_addr;
    wire [11:0] data_in;
    wire [11:0] seabed_data_out, fish1_data_out, fish2_data_out, fish3_data_out;
    wire        sram_we, sram_en;
    
    // General VGA control signals
    wire vga_clk;         // 50MHz clock for VGA control
    wire video_on;        // when video_on is 0, the VGA controller is sending
    // synchronization signals to the display device.
    
    wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
    // based for the new coordinate (pixel_x, pixel_y)
    
    wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639)
    wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
    
    reg  [11:0] rgb_reg;  // RGB value for the current pixel
    reg  [11:0] rgb_next; // RGB value for the next pixel
    
    // Application-specific VGA signals
    reg  [17:0] pixel_addr, fish1_pixel_addr, fish2_pixel_addr, fish3_pixel_addr;
    
    // Declare the video buffer size
    localparam VBUF_W = 320; // video buffer width
    localparam VBUF_H = 240; // video buffer height
    
    // Set parameters for the fish1 images
    localparam FISH1_VPOS = 128; // Vertical location of the fish in the sea image.
    localparam FISH1_W    = 64; // Width of the fish.
    localparam FISH1_H    = 32; // Height of the fish.
    reg [17:0] fish1_addr[0:8];   // Address array for up to 8 fish images.
    
    // Set parameters for the fish2 images
    localparam FISH2_VPOS = 70; // Vertical location of the fish in the sea image.
    localparam FISH2_W    = 64; // Width of the fish.
    localparam FISH2_H    = 44; // Height of the fish.
    reg [17:0] fish2_addr[0:8];   // Address array for up to 8 fish images.
    
    // Set parameters for the fish3 images
    localparam FISH3_VPOS = 64; // Vertical location of the fish in the sea image.
    localparam FISH3_W    = 32; // Width of the fish.
    localparam FISH3_H    = 36; // Height of the fish.
    reg [17:0] fish3_addr[0:8];   // Address array for up to 8 fish images.
    
    // Initializes the fish images starting addresses.
    // Note: System Verilog has an easier way to initialize an array,
    //       but we are using Verilog 2001 :(
    initial begin
        fish1_addr[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
        fish1_addr[1] = VBUF_W*VBUF_H + FISH1_W*FISH1_H; /* Addr for fish image #2 */
        fish1_addr[2] = VBUF_W*VBUF_H + FISH1_W*FISH1_H*2; /* Addr for fish image #3 */
        fish1_addr[3] = VBUF_W*VBUF_H + FISH1_W*FISH1_H*3; /* Addr for fish image #4 */
        // reverse
        fish1_addr[4] = VBUF_W*VBUF_H + FISH1_W*FISH1_H*4; /* Addr for fish image #5 */
        fish1_addr[5] = VBUF_W*VBUF_H + FISH1_W*FISH1_H*5; /* Addr for fish image #6 */
        fish1_addr[6] = VBUF_W*VBUF_H + FISH1_W*FISH1_H*6; /* Addr for fish image #7 */
        fish1_addr[7] = VBUF_W*VBUF_H + FISH1_W*FISH1_H*7; /* Addr for fish image #8 */
        //-------------------------------------------------
        fish2_addr[0] = 18'd0;         /* Addr for fish image #1 */
        fish2_addr[1] = FISH2_W*FISH2_H; /* Addr for fish image #2 */
        fish2_addr[2] = FISH2_W*FISH2_H*2; /* Addr for fish image #3 */
        fish2_addr[3] = FISH2_W*FISH2_H*3; /* Addr for fish image #4 */
        // reverse
        fish2_addr[4] = FISH2_W*FISH2_H*4; /* Addr for fish image #5 */
        fish2_addr[5] = FISH2_W*FISH2_H*5; /* Addr for fish image #6 */
        fish2_addr[6] = FISH2_W*FISH2_H*6; /* Addr for fish image #7 */
        fish2_addr[7] = FISH2_W*FISH2_H*7; /* Addr for fish image #8 */
        //-------------------------------------------------
        fish3_addr[0] = FISH2_W*FISH2_H*8 + 18'd0;         /* Addr for fish image #1 */
        fish3_addr[1] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H; /* Addr for fish image #2 */
        fish3_addr[2] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H*2; /* Addr for fish image #3 */
        fish3_addr[3] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H*3; /* Addr for fish image #4 */
        fish3_addr[4] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H*4; /* Addr for fish image #5 */
        fish3_addr[5] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H*5; /* Addr for fish image #6 */
        fish3_addr[6] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H*6; /* Addr for fish image #7 */
        fish3_addr[7] = FISH2_W*FISH2_H*8 + FISH3_W*FISH3_H*7; /* Addr for fish image #8 */
    end
    
    // LCD
    reg  [127:0] row_A;
    reg  [127:0] row_B;
    
    // Instiantiate the VGA sync signal generator
    vga_sync vs0(
    .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
    .visible(video_on), .p_tick(pixel_tick),
    .pixel_x(pixel_x), .pixel_y(pixel_y)
    );
    
    clk_divider#(2) clk_divider0(
    .clk(clk),
    .reset(~reset_n),
    .clk_out(vga_clk)
    );
    
    debounce btn_db0(
    .clk(clk),
    .btn_input(usr_btn[0]),
    .btn_output(btn_level[0])
    );
    
    debounce btn_db1(
    .clk(clk),
    .btn_input(usr_btn[1]),
    .btn_output(btn_level[1])
    );
    
    always @(posedge clk) begin
        if (~reset_n)
            prev_btn_level <= 0;
        else
            prev_btn_level <= btn_level;
    end
    
    assign btn_pressed[0] = (btn_level[0] == 1 && prev_btn_level[0] == 0) ? 1 : 0;
    assign btn_pressed[1] = (btn_level[1] == 1 && prev_btn_level[1] == 0) ? 1 : 0;
    
    // ------------------------------------------------------------------------
    // The following code describes an initialized SRAM memory block that
    // stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
    sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W * VBUF_H + FISH1_W * FISH1_H * 8), .FILE("images.mem"))
    ram0 (.clk(clk), .we(sram_we), .en(sram_en),
    .addr1(seabed_sram_addr), .data_i1(data_in), .data_o1(seabed_data_out),
    .addr2(fish1_sram_addr), .data_i2(data_in), .data_o2(fish1_data_out));
    
    sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH2_W * FISH2_H * 8 + FISH3_W * FISH3_H * 8), .FILE("images2.mem"))
    ram1 (.clk(clk), .we(sram_we), .en(sram_en),
    .addr1(fish2_sram_addr), .data_i1(data_in), .data_o1(fish2_data_out),
    .addr2(fish3_sram_addr), .data_i2(data_in), .data_o2(fish3_data_out));
    
    
    assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
    // you set 'sram_we' to 0, Vivado fails to synthesize
    // ram0 as a BRAM -- this is a bug in Vivado.
    assign sram_en          = 1;          // Here, we always enable the SRAM block.
    assign seabed_sram_addr = pixel_addr;
    assign fish1_sram_addr  = fish1_pixel_addr;
    assign fish2_sram_addr  = fish2_pixel_addr;
    assign fish3_sram_addr  = fish3_pixel_addr;
    assign data_in          = 12'h000; // SRAM is read-only so we tie inputs to zeros.
    // End of the SRAM memory block.
    // ------------------------------------------------------------------------
    
    // VGA color pixel generator
    assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;
    
    // ------------------------------------------------------------------------
    // An animation clock for the motion of the fish, upper bits of the
    // fish clock is the x position of the fish on the VGA screen.
    // Note that the fish will move one screen pixel every 2^20 clock cycles,
    // or 10.49 msec
    assign fish1_x_pos = fish1_clock[31:20]; // the x position of the right edge of the fish image
    reg fish1_reverse;
    assign fish2_x_pos = fish2_clock[31:20]; // the x position of the right edge of the fish image
    reg fish2_reverse;
    assign fish3_x_pos = fish3_clock[31:20]; // the x position of the right edge of the fish image
    
    assign fish1_y_pos = fish1_clock_y[31:20]; // the x position of the up edge of the fish image
    reg fish1_reverse_y;
    // in the 640x480 VGA screen
    // fish1 reverse flag
    
    always @(posedge clk) begin
        if (~reset_n) begin
            fish1_reverse <= 0;
        end
        
        else if (fish1_x_pos < FISH1_W*2 && fish1_reverse == 1) begin
        fish1_reverse <= 0;
    end
    
    else if (fish1_x_pos > VBUF_W*2) begin
    fish1_reverse <= 1;
    end
    end
    
    always @(posedge clk) begin
        if (~reset_n) begin
            fish1_reverse_y <= 0;
        end
        
        else if (fish1_y_pos < 1 && fish1_reverse_y == 1) begin
        fish1_reverse_y <= 0;
    end
    
    else if (fish1_y_pos > VBUF_H - FISH1_H) begin
    fish1_reverse_y <= 1;
    end
    end
    
    // fish1 clock
    always @(posedge clk) begin
        if (~reset_n) begin
            fish1_clock <= 0;
        end
        
        else if (fish1_reverse) begin
        fish1_clock <= fish1_clock - (1 << (fish1_speed-1));
    end
    
    else if (~fish1_reverse) begin
    fish1_clock <= fish1_clock + (1 << (fish1_speed-1));
    end
    end
    
    always @(posedge clk) begin
        if (~reset_n) begin
            fish1_clock_y <= 32'b00000100000000000000000000000000;
        end
        
        else if (fish1_reverse_y) begin
        fish1_clock_y <= fish1_clock_y - (1 << (fish1_speed-1));
    end
    
    else if (~fish1_reverse_y) begin
    fish1_clock_y <= fish1_clock_y + (1 << (fish1_speed-1));
    end
    end
    
    // fish2 reverse flag
    always @(posedge clk) begin
        if (~reset_n) begin
            fish2_reverse <= 1;
        end
        
        else if (fish2_x_pos < FISH1_W*2 && fish2_reverse == 1) begin
        fish2_reverse <= 0;
    end
    
    else if (fish2_x_pos > VBUF_W*2) begin
    fish2_reverse <= 1;
    end
    end
    // fish2 clock
    always @(posedge clk) begin
        if (~reset_n) begin
            fish2_clock <= 32'b00101000000000000000000000000000;
        end
        
        else if (fish2_reverse) begin
        fish2_clock <= fish2_clock - 2;
    end
    
    else if (~fish2_reverse) begin
    fish2_clock <= fish2_clock + 2;
    end
    end
    // fish3
    always @(posedge clk) begin
        if (~reset_n || fish3_clock[31:21] > VBUF_W + FISH3_W)
            fish3_clock <= 0;
        else
            fish3_clock <= fish3_clock + 1;
    end
    // End of the animation clock code.
    // ------------------------------------------------------------------------
    
    // ------------------------------------------------------------------------
    // Video frame buffer address generation unit (AGU) with scaling control
    // Note that the width x height of the fish image is 64x32, when scaled-up
    // on the screen, it becomes 128x64. 'fish1_x_pos' specifies the right edge of the
    // fish image.
    assign fish1_region = 
    (pixel_y > (fish1_y_pos<<1)- 1) && pixel_y < ((fish1_y_pos + FISH1_H)<<1) &&
    ((pixel_x + 127) > fish1_x_pos - 1) && pixel_x < fish1_x_pos + 1;
    
    assign fish2_region = 
    (pixel_y > (FISH2_VPOS<<1) - 1) && pixel_y < (FISH2_VPOS + FISH2_H)<<1 &&
    ((pixel_x + 127) > fish2_x_pos - 1) && pixel_x < fish2_x_pos + 1;
    
    assign fish3_region = 
    (pixel_y > (FISH3_VPOS<<1) - 1) && pixel_y < (FISH3_VPOS + FISH3_H)<<1 &&
    ((pixel_x + 63) > fish3_x_pos) && pixel_x < fish3_x_pos + 1;
    
    always @ (posedge clk) begin
        if (~reset_n) begin
            pixel_addr       <= 0;
            fish1_pixel_addr <= 0;
            fish2_pixel_addr <= 0;
            fish3_pixel_addr <= 0;
            end else begin
            if (fish1_region) begin
                if (fish1_reverse) begin
                    fish1_pixel_addr <= fish1_addr[fish1_clock[24:23] + 4] +
                    (((pixel_y >>1) - fish1_y_pos) * FISH1_W) +
                    ((pixel_x >>1) - (fish1_x_pos>>1) + FISH1_W);
                    
                    end else begin
                    fish1_pixel_addr <= fish1_addr[fish1_clock[24:23]] +
                    (((pixel_y >>1) - fish1_y_pos) * FISH1_W) +
                    ((pixel_x >>1) - (fish1_x_pos>>1) + FISH1_W);
                end
            end
            
            if (fish2_region) begin
                if (fish2_reverse) begin
                    fish2_pixel_addr <= fish2_addr[fish2_clock[25:24] + 4] +
                    ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                    ((pixel_x>>1) - (fish2_x_pos>>1) + FISH2_W);
                    end else begin
                    fish2_pixel_addr <= fish2_addr[fish2_clock[25:24]] +
                    ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                    ((pixel_x>>1) - (fish2_x_pos>>1) + FISH2_W);
                end
            end
                if (fish3_region) begin
                    fish3_pixel_addr <= fish3_addr[fish3_clock[25:23]] +
                    ((pixel_y>>1)-FISH3_VPOS)*FISH3_W +
                    ((pixel_x>>1) - (fish3_x_pos>>1) + FISH3_W);
                end
        end
        pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
    end
    
    // End of the AGU code.
    // ------------------------------------------------------------------------
    
    // ------------------------------------------------------------------------
    // Send the video data in the sram to the VGA controller
    always @(posedge clk) begin
        if (pixel_tick) rgb_reg <= rgb_next;
    end
    
    always @(*) begin
        if (~video_on)
            rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
        
        else if (!(fish2_data_out == 12'h0F0) && fish2_region) begin
        rgb_next <= fish2_data_out; //fish2 and not green
    end
    
    else if (!(fish3_data_out == 12'h0F0) && fish3_region) begin
    rgb_next <= fish3_data_out; //fish1 and not green
    end
    
    else if (!(fish1_data_out == 12'h0F0)&& fish1_region) begin
    rgb_next <= fish1_data_out;
    end
    else
    rgb_next <= seabed_data_out; // RGB value at (pixel_x, pixel_y)
    end
    // End of the video data display code.
    // ------------------------------------------------------------------------
    
    // speed control block
    always @(posedge clk) begin
        if (~reset_n) begin
            fish1_speed <= 1;
        end
        else begin
            if (btn_pressed[0]) begin
                fish1_speed <= fish1_speed - 1;
            end
            
            else if (btn_pressed[1]) begin
            fish1_speed <= fish1_speed + 1;
            
        end
        else
        fish1_speed <= fish1_speed;
    end
    end
    
    // led
    assign usr_led = fish1_speed;
    
endmodule
