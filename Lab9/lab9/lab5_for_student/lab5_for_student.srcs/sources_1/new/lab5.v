`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module lab5(input clk,
            input reset_n,
            input [3:0] usr_btn,
            output LCD_RS,
            output LCD_RW,
            output LCD_E,
            output [3:0] LCD_D);
    
    localparam [2:0]
    S_MAIN_INIT = 3'b000,
    S_MAIN_PREP = 3'b111,
    S_MAIN_CALC = 3'b001,
    S_MAIN_TURN = 3'b110,
    S_MAIN_SHOW = 3'b010;
    
    integer i;
    // Declare system variables
    reg [255:0] passwd_hash = 256'h7135E636345649BB91FE75D96E449C87309B0D0F615F925AF0878EC17A8A585F;
    // debounce
    wire btn_level, btn_pressed;
    reg  prev_btn_level;
    // FSM
    reg  [2:0] P, P_next;
    // SHA256
    
    // 计数?��
    reg [71:0] counter_0, counter_1, counter_2, counter_3, counter_4;
    
    // SHA256 信号
    reg sha_start_0, sha_start_1, sha_start_2, sha_start_3, sha_start_4;
    wire sha_done_0, sha_done_1, sha_done_2, sha_done_3, sha_done_4;
    reg [511:0] message_0, message_1, message_2, message_3, message_4;
    wire [255:0] sha_hash_0, sha_hash_1, sha_hash_2, sha_hash_3, sha_hash_4;
    // function
    reg [71:0] pwd_ascii;
    reg [375:0] padding;
    reg [63:0] msg_length;
    
    // flag and answer
    reg found, restart, restart_1, restart_2, restart_3, restart_4;
    reg [71:0] found_password;
    // LCD
    reg  [127:0] row_A;
    reg  [127:0] row_B;
    // timer
    reg [55:0] timer;
    
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
    
    debounce btn_db0(
    .clk(clk),
    .btn_input(usr_btn[3]),
    .btn_output(btn_level)
    );
    
    // SHA256 模�?��?��?��??
    sha256 u_sha256_0 (
    .clk(clk),
    .reset(!reset_n),
    .start(sha_start_0),
    .data_in(message_0),
    .done(sha_done_0),
    .hash_out(sha_hash_0)
    );
    
    sha256 u_sha256_1 (
    .clk(clk),
    .reset(!reset_n),
    .start(sha_start_1),
    .data_in(message_1),
    .done(sha_done_1),
    .hash_out(sha_hash_1)
    );
    
    sha256 u_sha256_2 (
    .clk(clk),
    .reset(!reset_n),
    .start(sha_start_2),
    .data_in(message_2),
    .done(sha_done_2),
    .hash_out(sha_hash_2)
    );
    
    sha256 u_sha256_3 (
    .clk(clk),
    .reset(!reset_n),
    .start(sha_start_3),
    .data_in(message_3),
    .done(sha_done_3),
    .hash_out(sha_hash_3)
    );
    
    sha256 u_sha256_4 (
    .clk(clk),
    .reset(!reset_n),
    .start(sha_start_4),
    .data_in(message_4),
    .done(sha_done_4),
    .hash_out(sha_hash_4)
    );
    
    always @(posedge clk) begin
        if (~reset_n)
            prev_btn_level <= 0;
        else
            prev_btn_level <= btn_level;
    end
    
    assign btn_pressed = (btn_level == 1 && prev_btn_level == 0) ? 1 : 0;
    
    always @(posedge clk) begin
        if (~reset_n)
            P <= S_MAIN_INIT;
        else
            P <= P_next;
    end
    
    always @(*) begin
        case (P)
            S_MAIN_INIT:
            if (btn_pressed) P_next = S_MAIN_PREP;
            else P_next             = S_MAIN_INIT;
            
            S_MAIN_PREP:
            P_next = S_MAIN_CALC;
            
            S_MAIN_CALC:
            if (found) P_next = S_MAIN_TURN;
            else if (restart && restart_1 && restart_2 && restart_3 && restart_4)
            P_next      = S_MAIN_PREP;
            else P_next = S_MAIN_CALC;
            
            S_MAIN_TURN:
            P_next = S_MAIN_SHOW;
            
            S_MAIN_SHOW:
            P_next = S_MAIN_SHOW;
            
            default:
            P_next = S_MAIN_INIT;
        endcase
    end
    
    always @(posedge clk) begin
        if (!reset_n) begin
            counter_0 <= "000000000";
            counter_1 <= "000000001";
            counter_2 <= "000000002";
            counter_3 <= "000000003";
            counter_4 <= "000000004";
            
            sha_start_0 <= 0;
            sha_start_1 <= 0;
            sha_start_2 <= 0;
            sha_start_3 <= 0;
            sha_start_4 <= 0;
            
            found      <= 0;
            restart    <= 0;
            restart_1  <= 0;
            restart_2  <= 0;
            restart_3  <= 0;
            restart_4  <= 0;
            padding    <= {1'b1, 375'd0};
            msg_length <= 64'd72;
        end
        
        else if (P == S_MAIN_PREP) begin
        
        restart   = 0;
        restart_1 = 0;
        restart_2 = 0;
        restart_3 = 0;
        restart_4 = 0;
        
        counter_0[7:0] = counter_0[7:0] + 8'd5;
        
        if (counter_0[7:0] > "9") begin
            counter_0[7:0]  = counter_0[7:0] - 8'd10;
            counter_0[15:8] = counter_0[15:8] + 8'd1;
            if (counter_0[15:8] > "9") begin
                counter_0[15:8]  = "0";
                counter_0[23:16] = counter_0[23:16] + 8'd1;
                if (counter_0[23:16] > "9") begin
                    counter_0[23:16] = "0";
                    counter_0[31:24] = counter_0[31:24] + 8'd1;
                    if (counter_0[31:24] > "9") begin
                        counter_0[31:24] = "0";
                        counter_0[39:32] = counter_0[39:32] + 8'd1;
                        if (counter_0[39:32] > "9") begin
                            counter_0[39:32] = "0";
                            counter_0[47:40] = counter_0[47:40] + 8'd1;
                            if (counter_0[47:40] > "9") begin
                                counter_0[47:40] = "0";
                                counter_0[55:48] = counter_0[55:48] + 8'd1;
                                if (counter_0[55:48] > "9") begin
                                    counter_0[55:48] = "0";
                                    counter_0[63:56] = counter_0[63:56] + 8'd1;
                                    if (counter_0[63:56] > "9") begin
                                        counter_0[63:56] = "0";
                                        counter_0[71:64] = counter_0[71:64] + 8'd1;
                                        if (counter_0[71:64] > "9") begin
                                            counter_0[71:64] = "0";
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        counter_1[7:0] = counter_1[7:0] + 8'd5;
        
        if (counter_1[7:0] > "9") begin
            counter_1[7:0]  = counter_1[7:0] - 8'd10;
            counter_1[15:8] = counter_1[15:8] + 8'd1;
            if (counter_1[15:8] > "9") begin
                counter_1[15:8]  = "0";
                counter_1[23:16] = counter_1[23:16] + 8'd1;
                if (counter_1[23:16] > "9") begin
                    counter_1[23:16] = "0";
                    counter_1[31:24] = counter_1[31:24] + 8'd1;
                    if (counter_1[31:24] > "9") begin
                        counter_1[31:24] = "0";
                        counter_1[39:32] = counter_1[39:32] + 8'd1;
                        if (counter_1[39:32] > "9") begin
                            counter_1[39:32] = "0";
                            counter_1[47:40] = counter_1[47:40] + 8'd1;
                            if (counter_1[47:40] > "9") begin
                                counter_1[47:40] = "0";
                                counter_1[55:48] = counter_1[55:48] + 8'd1;
                                if (counter_1[55:48] > "9") begin
                                    counter_1[55:48] = "0";
                                    counter_1[63:56] = counter_1[63:56] + 8'd1;
                                    if (counter_1[63:56] > "9") begin
                                        counter_1[63:56] = "0";
                                        counter_1[71:64] = counter_1[71:64] + 8'd1;
                                        if (counter_1[71:64] > "9") begin
                                            counter_1[71:64] = "0";
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        counter_2[7:0] = counter_2[7:0] + 8'd5;
        
        if (counter_2[7:0] > "9") begin
            counter_2[7:0]  = counter_2[7:0] - 8'd10;
            counter_2[15:8] = counter_2[15:8] + 8'd1;
            if (counter_2[15:8] > "9") begin
                counter_2[15:8]  = "0";
                counter_2[23:16] = counter_2[23:16] + 8'd1;
                if (counter_2[23:16] > "9") begin
                    counter_2[23:16] = "0";
                    counter_2[31:24] = counter_2[31:24] + 8'd1;
                    if (counter_2[31:24] > "9") begin
                        counter_2[31:24] = "0";
                        counter_2[39:32] = counter_2[39:32] + 8'd1;
                        if (counter_2[39:32] > "9") begin
                            counter_2[39:32] = "0";
                            counter_2[47:40] = counter_2[47:40] + 8'd1;
                            if (counter_2[47:40] > "9") begin
                                counter_2[47:40] = "0";
                                counter_2[55:48] = counter_2[55:48] + 8'd1;
                                if (counter_2[55:48] > "9") begin
                                    counter_2[55:48] = "0";
                                    counter_2[63:56] = counter_2[63:56] + 8'd1;
                                    if (counter_2[63:56] > "9") begin
                                        counter_2[63:56] = "0";
                                        counter_2[71:64] = counter_2[71:64] + 8'd1;
                                        if (counter_2[71:64] > "9") begin
                                            counter_2[71:64] = "0";
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        counter_3[7:0] = counter_3[7:0] + 8'd5;
        
        if (counter_3[7:0] > "9") begin
            counter_3[7:0]  = counter_3[7:0] - 8'd10;
            counter_3[15:8] = counter_3[15:8] + 8'd1;
            if (counter_3[15:8] > "9") begin
                counter_3[15:8]  = "0";
                counter_3[23:16] = counter_3[23:16] + 8'd1;
                if (counter_3[23:16] > "9") begin
                    counter_3[23:16] = "0";
                    counter_3[31:24] = counter_3[31:24] + 8'd1;
                    if (counter_3[31:24] > "9") begin
                        counter_3[31:24] = "0";
                        counter_3[39:32] = counter_3[39:32] + 8'd1;
                        if (counter_3[39:32] > "9") begin
                            counter_3[39:32] = "0";
                            counter_3[47:40] = counter_3[47:40] + 8'd1;
                            if (counter_3[47:40] > "9") begin
                                counter_3[47:40] = "0";
                                counter_3[55:48] = counter_3[55:48] + 8'd1;
                                if (counter_3[55:48] > "9") begin
                                    counter_3[55:48] = "0";
                                    counter_3[63:56] = counter_3[63:56] + 8'd1;
                                    if (counter_3[63:56] > "9") begin
                                        counter_3[63:56] = "0";
                                        counter_3[71:64] = counter_3[71:64] + 8'd1;
                                        if (counter_3[71:64] > "9") begin
                                            counter_3[71:64] = "0";
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        counter_4[7:0] = counter_4[7:0] + 8'd5;
        
        if (counter_4[7:0] > "9") begin
            counter_4[7:0]  = counter_4[7:0] - 8'd10;
            counter_4[15:8] = counter_4[15:8] + 8'd1;
            if (counter_4[15:8] > "9") begin
                counter_4[15:8]  = "0";
                counter_4[23:16] = counter_4[23:16] + 8'd1;
                if (counter_4[23:16] > "9") begin
                    counter_4[23:16] = "0";
                    counter_4[31:24] = counter_4[31:24] + 8'd1;
                    if (counter_4[31:24] > "9") begin
                        counter_4[31:24] = "0";
                        counter_4[39:32] = counter_4[39:32] + 8'd1;
                        if (counter_4[39:32] > "9") begin
                            counter_4[39:32] = "0";
                            counter_4[47:40] = counter_4[47:40] + 8'd1;
                            if (counter_4[47:40] > "9") begin
                                counter_4[47:40] = "0";
                                counter_4[55:48] = counter_4[55:48] + 8'd1;
                                if (counter_4[55:48] > "9") begin
                                    counter_4[55:48] = "0";
                                    counter_4[63:56] = counter_4[63:56] + 8'd1;
                                    if (counter_4[63:56] > "9") begin
                                        counter_4[63:56] = "0";
                                        counter_4[71:64] = counter_4[71:64] + 8'd1;
                                        if (counter_4[71:64] > "9") begin
                                            counter_4[71:64] = "0";
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
    end
    //-----------------------------------------------------------------------------------------------------
    //-----------------------------------------------------------------------------------------------------
    //-----------------------------------------------------------------------------------------------------
    else if (P == S_MAIN_CALC && !found) begin
    // SHA256 Module 0
    if (!sha_start_0 && !sha_done_0) begin
        message_0   = { counter_0, padding, msg_length };
        sha_start_0 = 1;
    end
    else if (sha_start_0 && !sha_done_0) begin
        sha_start_0 <= 0;
    end
        else if (sha_done_0) begin
        if (sha_hash_0 == passwd_hash) begin
            found          <= 1;
            found_password <= counter_0;
        end
        else begin
            restart = 1;
        end
        end
        
        // SHA256 Module 1
        if (!sha_start_1 && !sha_done_1) begin
            message_1 = { counter_1, padding, msg_length };
            sha_start_1 <= 1;
        end
        
        else if (sha_start_1 && !sha_done_1) begin
        sha_start_1 <= 0;
        end
        else if (sha_done_1) begin
        if (sha_hash_1 == passwd_hash) begin
            found          <= 1;
            found_password <= counter_1;
        end
        
    else begin
        restart_1 = 1;
    end
    end
    
    // SHA256 Module 2
    if (!sha_start_2 && !sha_done_2) begin
        message_2 = { counter_2, padding, msg_length };
        sha_start_2 <= 1;
    end
    else if (sha_start_2 && !sha_done_2) begin
        sha_start_2 <= 0;
    end
        
        else if (sha_done_2) begin
        if (sha_hash_2 == passwd_hash) begin
            found          <= 1;
            found_password <= counter_2;
        end
        else begin
            restart_2 = 1;
        end
        end
        
        // SHA256 Module 3
        if (!sha_start_3 && !sha_done_3) begin
            message_3 = { counter_3, padding, msg_length };
            sha_start_3 <= 1;
        end
        
        else if (sha_start_3 && !sha_done_3) begin
        sha_start_3 <= 0;
        end
        else if (sha_done_3) begin
        if (sha_hash_3 == passwd_hash) begin
            found          <= 1;
            found_password <= counter_3;
        end
        else begin
            restart_3 = 1;
        end
        end
        
        // SHA256 Module 4
        if (!sha_start_4 && !sha_done_4) begin
            message_4 = { counter_4, padding, msg_length };
            sha_start_4 <= 1;
        end
        
        else if (sha_start_4 && !sha_done_4) begin
        sha_start_4 <= 0;
        end
        else if (sha_done_4) begin
        if (sha_hash_4 == passwd_hash) begin
            found          <= 1;
            found_password <= counter_4;
        end
        else begin
            restart_4 = 1;
        end
        end
        end
        
        else if (P == S_MAIN_TURN) begin
        
        found_password[7:0] = found_password[7:0] - 8'd5;
        
        if (found_password[7:0] < "0") begin
            found_password[7:0] = found_password[7:0] + 8'd10;
            if (found_password[15:8] == "0") begin
                found_password[15:8] = found_password[15:8] + 8'd9;
                if (found_password[23:16] == "0") begin
                    found_password[23:16] = found_password[23:16] + 8'd9;
                    if (found_password[31:24] == "0") begin
                        found_password[31:24] = found_password[31:24] + 8'd9;
                        if (found_password[39:32] == "0") begin
                            found_password[39:32] = found_password[39:32] + 8'd9;
                            if (found_password[47:40] == "0") begin
                                found_password[47:40] = found_password[47:40] + 8'd9;
                                if (found_password[55:48] == "0") begin
                                    found_password[55:48] = found_password[55:48] + 8'd9;
                                    if (found_password[63:56] == "0") begin
                                        found_password[63:56] = found_password[63:56] + 8'd9;
                                        if (found_password[71:64] == "0") begin
                                            found_password[71:64] = found_password[71:64] + 8'd9;
                                            end else begin
                                            found_password[71:64] = found_password[71:64] - 8'h1;
                                        end
                                        end else begin
                                        found_password[63:56] = found_password[63:56] - 8'h1;
                                    end
                                    end else begin
                                    found_password[55:48] = found_password[55:48] - 8'h1;
                                end
                                end else begin
                                found_password[47:40] = found_password[47:40] - 8'h1;
                            end
                            end else begin
                            found_password[39:32] = found_password[39:32] - 8'h1;
                        end
                        end else begin
                        found_password[31:24] = found_password[31:24] - 8'h1;
                    end
                    end else begin
                    found_password[23:16] = found_password[23:16] - 8'h1;
                end
                end else begin
                found_password[15:8] = found_password[15:8] - 8'h1;
            end
        end
        end
        end
        
        // timer
        always @(posedge clk) begin
            if (P == S_MAIN_INIT) begin
                timer <= 0;
                end else if (P == S_MAIN_CALC && !found) begin
                timer <= timer + 1;
            end
        end
        
        // LCD Display function.
        always @(posedge clk) begin
            if (P == S_MAIN_INIT) begin
                row_A <= "Press  BTN3  to ";
                row_B <= "start calculate ";
            end
            else if (P == S_MAIN_CALC || P == S_MAIN_PREP) begin
                row_A <= "Calculating.....";
                row_B <= "                ";
            end
                else if (P == S_MAIN_SHOW) begin
                row_A <= {"Pwd:", found_password, "   "};
                row_B <= {"T:",
                (((timer[55:52] > 9)? "7" : "0") + timer[55:52]),
                (((timer[51:48] > 9)? "7" : "0") + timer[51:48]),
                (((timer[47:44] > 9)? "7" : "0") + timer[47:44]),
                (((timer[43:40] > 9)? "7" : "0") + timer[43:40]),
                (((timer[39:36] > 9)? "7" : "0") + timer[39:36]),
                (((timer[35:32] > 9)? "7" : "0") + timer[35:32]),
                (((timer[31:28] > 9)? "7" : "0") + timer[31:28]),
                (((timer[27:24] > 9)? "7" : "0") + timer[27:24]),
                (((timer[23:20] > 9)? "7" : "0") + timer[23:20]),
                (((timer[19:16] > 9)? "7" : "0") + timer[19:16]),
                (((timer[15:12] > 9)? "7" : "0") + timer[15:12]),
                (((timer[11: 8] > 9)? "7" : "0") + timer[11: 8]),
                (((timer[7 : 4] > 9)? "7" : "0") + timer[7 : 4]),
                (((timer[3 : 0] > 9)? "7" : "0") + timer[3 : 0])};
                end
                end
                
                endmodule
