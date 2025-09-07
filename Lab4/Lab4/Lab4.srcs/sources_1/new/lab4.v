`timescale 1ns / 1ps

module lab4(
    input clk,            // System clock at 100 MHz
    input reset_n,        // System reset signal, in negative logic
    input [3:0] usr_btn,  // Four user pushbuttons
    output [3:0] usr_led  // Four yellow LEDs (Gray code display)
);

// Debounced button signals
wire [3:0] btn;
debounce A0(clk, reset_n, usr_btn[0], btn[0]);
debounce A1(clk, reset_n, usr_btn[1], btn[1]);
debounce A2(clk, reset_n, usr_btn[2], btn[2]);
debounce A3(clk, reset_n, usr_btn[3], btn[3]);

// Internal registers
reg [3:0] gray_code;      // 4-bit Gray code counter
reg [3:0] binary_counter; // Binary counter (for Gray code conversion)
reg [2:0] brightness_level;  // 5 brightness levels (0 to 4)
reg [19:0] pwm_counter;   // Counter for PWM (for brightness control)            // PWM output signal
reg [3:0] btn_prev;       // Previous button state for edge detection
wire [3:0] btn_edge;      // Button edge detection
reg [3:0] led;

// Edge detection for button presses
assign btn_edge = btn & ~btn_prev;
assign usr_led = led;
// Gray code conversion logic (Binary to Gray)
always @(*) begin
    gray_code[3] = binary_counter[3];
    gray_code[2] = binary_counter[3] ^ binary_counter[2];
    gray_code[1] = binary_counter[2] ^ binary_counter[1];
    gray_code[0] = binary_counter[1] ^ binary_counter[0];
end

// Main control logic for counter and brightness
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        binary_counter <= 4'b0000;
        brightness_level <= 3'b000;
        btn_prev <= 4'b0000;
    end else begin
        btn_prev <= btn;
        
        // Gray Code Counter Logic
        if (btn_edge[1] && binary_counter < 4'b1111)
            binary_counter <= binary_counter + 1;
        else if (btn_edge[0] && binary_counter > 4'b0000)
            binary_counter <= binary_counter - 1;
        
        // Brightness Control Logic
        if (btn_edge[2] && brightness_level > 3'b000)
            brightness_level <= brightness_level - 1;
        else if (btn_edge[3] && brightness_level < 3'b100)
            brightness_level <= brightness_level + 1;
    end
end

// PWM Generation for Brightness Control
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        pwm_counter <= 0;
    end else begin
        pwm_counter <= pwm_counter + 1;
        case (brightness_level)
            3'b000: led <= (pwm_counter < 50000)? gray_code : 0;   // 5% duty cycle
            3'b001: led <= (pwm_counter < 250000)? gray_code : 0;  // 25% duty cycle
            3'b010: led <= (pwm_counter < 500000)? gray_code : 0;  // 50% duty cycle
            3'b011: led <= (pwm_counter < 750000)? gray_code : 0;  // 75% duty cycle
            3'b100: led <= (pwm_counter < 1000000)? gray_code : 0; // 100% duty cycle
            default: led <= 1'b0; // Should never happen
        endcase
    end
end

endmodule

// Improved debounce module for buttons
module debounce (
    input clk,
    input reset_n,
    input btn,
    output sig_out
);
    
    // Internal signals
    reg [19:0] timer;
    reg btn_prev;
    reg btn_stable;
    assign sig_out = btn_prev;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            timer <= 20'd500000;
            btn_prev <= 0;
            btn_stable <= 0;
        end else begin 
            if (btn_prev == 1) begin
                // Button state changed, reset the timer
                btn_prev <= 0;
            end else if (!btn && timer > 20'd1000000 && btn_stable == 0) begin
                btn_prev <= 1;
                timer <= 20'd500000;
                end 
            else if (btn)begin
                if (timer < 20'hFFFFF)  // prevent overflow causes by press for a long time
                    timer <= timer + 1;
            end else if (timer < 20'd500000) begin
                timer <= timer + 3;
                end
            else if (timer > 28'h500001 && !btn_stable) begin
                timer <= timer - 3;
                end
            end
            btn_stable <= btn_prev;
        end

endmodule
