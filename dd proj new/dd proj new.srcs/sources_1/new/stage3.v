`timescale 1ns/1ps

module stage3_tb(
    input clk,
    input enable,
    input rst,
    input [5:0] sw,
    input del,
    input [19:0] data,
    input [3:0] guess_times,
    output [7:0] bit_sel,
    output [7:0] seg_out,
    output reg [4:0] LED,
    output buzzer
);
RenaiCirculation rc(clk, success, buzzer);
reg [9:0] led_state = 10'b0;
parameter  period = 200000;
parameter  l_period = 200_000_000;
reg success = 0;
reg fail = 0;
reg [19:0] cur_data = 20'b0;

reg error = 0;
reg [1:0] errorType = 0;
reg [15:0] state = 16'b00_00_00_10_10_10_10_10; // 00 for lights out, 01 for lights flickering, 10 for lights on
reg [32:0] display_data = 32'b0;
reg clkout = 0;
reg l_clkout = 0;
reg [31:0] cnt = 32'b0;
reg [31:0] l_cnt = 32'b0;
reg [2:0] scan_cnt = 3'b0;
reg [6:0] Y_reg = 7'b0;
reg [7:0] bit_sel_reg = 8'b0;
reg [2:0] pos = 3'b0; 
reg  [31:0] sw5_history = 32'h0;
reg sw5_posedge_detected = 1'b0;
reg sw5_negedge_detected = 1'b0;
reg  [31:0] sw4_history = 32'h0;
reg sw4_posedge_detected = 1'b0;
reg  [31:0] del_history = 32'h0;
reg del_posedge_detected = 1'b0;
reg  [31:0] enable_history = 32'h0;
reg enable_posedge_detected = 1'b0;
reg error_not_5_digits = 0;
assign seg_out = {Y_reg, 1'b1};
assign bit_sel = bit_sel_reg;

reg [19:0] password;
reg [3:0] remaining_times;


// get clkout of period hz and l_clkout of l_period hz
always @(posedge clk)
begin
    if(cnt == (period >> 1) - 1) begin
        clkout <= ~clkout;
        cnt <= 0;
    end
    else
        cnt <= cnt + 1;
end

always @(posedge clk)
begin
    if(l_cnt == (l_period >> 1) - 1) begin
        l_clkout <= ~l_clkout;
        l_cnt <= 0;
    end
    else
        l_cnt <= l_cnt + 1;
end

// detect the posedge of sw5, sw4 sw6, sw7 and del
always @(negedge clkout) begin    
    sw4_history <= {sw4_history[30:0], sw[4]};
    if (sw4_history == 32'h3fff_ffff)
        sw4_posedge_detected <= 1'b1;
    else
        sw4_posedge_detected <= 1'b0;
end

always @(negedge clkout) begin  
    sw5_history <= { sw5_history[30:0], sw[5] } ;
    if (sw5_history == 31'h3fff_ffff) begin
        sw5_posedge_detected <= 1'b1;
    end
    else begin
        sw5_posedge_detected <= 1'b0;
    end
    if(sw5_history == 32'hffff_fffc) begin
        sw5_negedge_detected <= 1'b1;
    end
    else begin
        sw5_negedge_detected <= 1'b0;
    end
end

always @(negedge clkout) begin
  del_history <= { del_history[30:0], del };
  if (del_history == 32'h3fff_ffff)
    del_posedge_detected <= 1'b1;
  else
    del_posedge_detected <= 1'b0;
end

//set the content of 5_digit number
always @(posedge clkout) begin
    if(rst == 1)begin
        error <= 0;
        error_not_5_digits <= 3'b0;
        errorType <= 2'b0;
        success <= 0;
        fail <= 0;
        remaining_times <= guess_times;
        pos <= 3'b0;
        led_state <= 10'b0;
    end
    else if(enable == 0) begin
        password <= data;
        remaining_times <= guess_times;
        pos <= 3'b0;
    end
    else begin // enable == 1
        if(sw4_posedge_detected == 1) begin
            if(error == 0 && error_not_5_digits ==0) begin
                if(sw[5] == 0) begin
                    if(sw[3:0] >= 4'b1010 || (sw[3:0] < 4'b1010 &&
                        (pos == 3'b001 && (cur_data[19:16] == sw[3:0])) ||
                        (pos == 3'b010 && (cur_data[19:16] == sw[3:0] || cur_data[15:12] == sw[3:0])) ||
                        (pos == 3'b011 && (cur_data[19:16] == sw[3:0] || cur_data[15:12] == sw[3:0] || cur_data[11:8] == sw[3:0])) || 
                        (pos == 3'b100 && (cur_data[19:16] == sw[3:0] || cur_data[15:12] == sw[3:0] || cur_data[11:8] == sw[3:0] || cur_data[7:4] == sw[3:0])))) begin
                            errorType <= 2'b11;
                            error <= 1;
                    end 
                    else begin
                        if(pos != 3'b101) begin
                            pos <= pos + 3'b001;   
                        end
                    end
                end 
            end
        end
        else if(del_posedge_detected == 1) begin
            if(error == 1)begin
                errorType <= 2'b00;
                error <= 0;
            end
            else begin
                if(pos != 3'b000) begin
                    pos <= pos - 3'b001;
                end
            end
        end
        else if(sw5_posedge_detected) begin
            if(pos != 3'b101) begin
                errorType <= 2'b11;
                error_not_5_digits <= 1;
            end
            else begin
                if(cur_data == password) begin
                    success <= 1;
                end
                else begin
                    if(remaining_times > 0) begin
                        pos <= 3'b0;
                        remaining_times <= remaining_times - 1;
                    end
                    else begin
                        fail <= 1;
                    end
                end
            end
        end
        else if(sw5_negedge_detected) begin
            if(error_not_5_digits == 1) begin
                error_not_5_digits <= 0;
            end
            else begin
                pos <= 3'b0;
                led_state <= 10'b0;
            end
        end
        else begin
            if(sw[5] == 0) begin
                led_state <= 10'b0;
                display_data <= {remaining_times, 8'b0, cur_data};
                case(pos)
                    0: begin cur_data[19:16] <= sw[3:0]; state <= 16'b10_00_00_01_00_00_00_00; end
                    1: begin cur_data[15:12] <= sw[3:0];state <= 16'b10_00_00_10_01_00_00_00; end
                    2: begin cur_data[11:8] <= sw[3:0];state <= 16'b10_00_00_10_10_01_00_00; end
                    3: begin cur_data[7:4] <= sw[3:0];state <= 16'b10_00_00_10_10_10_01_00; end
                    4: begin cur_data[3:0] <= sw[3:0];state <= 16'b10_00_00_10_10_10_10_01; end
                    5: state <= 16'b10_00_00_10_10_10_10_10;
                endcase
            end
            else begin
                if(error == 1 || error_not_5_digits == 1) begin
                    led_state <= 10'b0;
                end 
                else begin
                    case(cur_data[19:16])
                        password[19:16]: begin led_state[9:8] <= 10; end
                        password[15:12]: begin led_state[9:8] <= 01; end
                        password[11:8]: begin led_state[9:8] <= 01; end
                        password[7:4]: begin led_state[9:8] <= 01; end
                        password[3:0]: begin led_state[9:8] <= 01; end
                        default: led_state[9:8] <= 2'b00;
                    endcase
                    case(cur_data[15:12])
                        password[19:16]: begin led_state[7:6] <= 01; end
                        password[15:12]: begin led_state[7:6] <= 10; end
                        password[11:8]: begin led_state[7:6] <= 01; end
                        password[7:4]: begin led_state[7:6] <= 01; end
                        password[3:0]: begin led_state[7:6] <= 01;  end
                        default: led_state[7:6] <= 2'b00; 
                    endcase
                    case(cur_data[11:8])
                        password[19:16]: begin led_state[5:4] <= 01; end
                        password[15:12]: begin led_state[5:4] <= 01; end
                        password[11:8]: begin led_state[5:4] <= 10; end
                        password[7:4]: begin led_state[5:4] <= 01; end
                        password[3:0]: begin led_state[5:4] <= 01; end
                        default: led_state[5:4] <= 2'b00; 
                    endcase
                    case(cur_data[7:4])
                        password[19:16]: begin led_state[3:2] <= 01; end
                        password[15:12]: begin led_state[3:2] <= 01; end
                        password[11:8]: begin led_state[3:2] <= 01; end
                        password[7:4]: begin led_state[3:2] <= 10; end
                        password[3:0]: begin led_state[3:2] <= 01; end
                        default: led_state[3:2] <= 2'b00; 
                    endcase
                    case(cur_data[3:0])
                        password[19:16]: begin led_state[1:0] <= 01; end
                        password[15:12]: begin led_state[1:0] <= 01; end
                        password[11:8]: begin led_state[1:0] <= 01; end
                        password[7:4]: begin led_state[1:0] <= 01; end
                        password[3:0]: begin led_state[1:0] <= 10; end
                        default: led_state[1:0] <= 2'b00; 
                    endcase
                end
            end
        end
    end
end

//set scan_cnt to increase by 1 on each posedge of clkout
always @(posedge clkout)
begin
    if(enable == 0)
        scan_cnt <= 0;
    else begin
        if(scan_cnt == 3'b111)
            scan_cnt <= 0;
        else
        scan_cnt <= scan_cnt + 1;
    end
end

//combinational logic to set the bit_sel_reg according to scan_cnt
always @(scan_cnt)
begin
    if(enable == 0)
        bit_sel_reg = ~8'b00000000;
    else
    case(scan_cnt)
        3'b000: bit_sel_reg = ~8'b00000001;
        3'b001: bit_sel_reg = ~8'b00000010;
        3'b010: bit_sel_reg = ~8'b00000100;
        3'b011: bit_sel_reg = ~8'b00001000;
        3'b100: bit_sel_reg = ~8'b00010000;
        3'b101: bit_sel_reg = ~8'b00100000;
        3'b110: bit_sel_reg = ~8'b01000000;
        3'b111: bit_sel_reg = ~8'b10000000;
    endcase
end

//conbinational logic to set Y_reg according to state, data and error
always @(scan_cnt) begin
    if(error == 0 && success == 0 && fail == 0 && error_not_5_digits == 0) begin
       case(scan_cnt)
                3'b000: 
                if(state[1:0] == 0 || ((state[1:0] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[3:0])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase    
                3'b001:
                if(state[3:2] == 0 || ((state[3:2] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[7:4])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b010:
                if(state[5:4] == 0 || ((state[5:4] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[11:8])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b011:
                if(state[7:6] == 0 || ((state[7:6] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[15:12])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b100:
                if(state[9:8] == 0 || ((state[9:8] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[19:16])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b101:
                if(state[11:10] == 0 || ((state[11:10] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[23:20])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase  
                3'b110:
                if(state[13:12] == 0 || ((state[13:12] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[27:24])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b111:
                if(state[15:14] == 0 || ((state[15:14] == 1) && l_clkout == 0))
                    Y_reg = ~7'b0000_000;
                else
                case (display_data[31:28])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                default: Y_reg = ~7'b0000_000;   //all disabled
        endcase     
    end
    else if(error == 1) begin
        case(scan_cnt)
            3'b000:
            case (errorType)
                2'b00:Y_reg = ~7'b0000_000;   //off
                2'b01:Y_reg = ~7'b0110_000;   //1
                2'b10:Y_reg = ~7'b1101_101;   //2
                2'b11:Y_reg = ~7'b1111_001;   //3
            endcase
            3'b001: 
            Y_reg = ~7'b0000101;   //r
            3'b010:
            Y_reg = ~7'b0011101;  //o
            3'b011:
            Y_reg = ~7'b0000101;   //r
            3'b100:
            Y_reg = ~7'b0000101;   //r
            3'b101:
            Y_reg = ~7'b1001111;    //E
            default: Y_reg = ~7'b0000_000;   //all disabled
        endcase     
    end  
    else if(success == 1) begin
        case(scan_cnt)
            3'b000:
            Y_reg = ~7'b0;
            3'b001: 
            Y_reg = ~7'b1011011; // S
            3'b010:
            Y_reg = ~7'b1011011; // S
            3'b011:
            Y_reg = ~7'b1001111;   //E
            3'b100:
            Y_reg = ~7'b1001110;    //C
            3'b101:
            Y_reg = ~7'b1001110;    //C
            3'b110:
            Y_reg = ~7'b0111110; // U
            3'b111:
            Y_reg = ~7'b1011011; // S
            default: Y_reg = ~7'b0000_000;   //all disabled
        endcase
    end
    else if(fail == 1) begin
        if(sw[5] == 1) begin
            case(scan_cnt)
                3'b100:
                Y_reg = ~7'b0001110; // L
                3'b101:
                Y_reg = ~7'b0110000; //I
                3'b110:
                Y_reg = ~7'b1110_111; //A
                3'b111:
                Y_reg = ~7'b1000111; // F
                default: Y_reg = ~7'b0000_000;   //all disabled
            endcase
        end
        else begin
            case(scan_cnt)
                3'b000: 
                case (data[3:0])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase    
                3'b001:
                case (data[7:4])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b010:
                case (data[11:8])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b011:
                case (data[15:12])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
                3'b100:
                case (data[19:16])
                    0:Y_reg = ~7'b1111_110;   //0
                    1:Y_reg = ~7'b0110_000;   //1
                    2:Y_reg = ~7'b1101_101;   //2
                    3:Y_reg = ~7'b1111_001;   //3
                    4:Y_reg = ~7'b0110_011;   //4
                    5:Y_reg = ~7'b1011_011;   //5
                    6:Y_reg = ~7'b1011_111;   //6
                    7:Y_reg = ~7'b1110_000;   //7
                    8:Y_reg = ~7'b1111_111;   //8
                    9:Y_reg = ~7'b1110_011;   //9
                    10:Y_reg = ~7'b1110_111; //A
                    11:Y_reg = ~7'b0011_111; // b
                    12:Y_reg = ~7'b0001_101; // c
                    13:Y_reg = ~7'b0111_101; // d
                    14:Y_reg = ~7'b1001_111; // E
                    15:Y_reg = ~7'b1000_111; // F
                endcase
              
                default: Y_reg = ~7'b0;
            endcase
        end
    end
    else begin // not 5 digits
        case(scan_cnt)
            3'b000:
            Y_reg = ~7'b1111_001;   //3
            3'b001: 
            Y_reg = ~7'b0000101;   //r
            3'b010:
            Y_reg = ~7'b0011101;  //o
            3'b011:
            Y_reg = ~7'b0000101;   //r
            3'b100:
            Y_reg = ~7'b0000101;   //r
            3'b101:
            Y_reg = ~7'b1001111;    //E
            default: Y_reg = ~7'b0000_000;   //all disabled
        endcase   
    end
end

always @(clkout)begin
        if(led_state[1:0] == 2 || (led_state[1:0] == 1 && l_clkout == 1))
            LED[0] = 1;
        else
            LED[0] = 0;
        if(led_state[3:2] == 2 || (led_state[3:2] == 1 && l_clkout == 1))
            LED[1] = 1;
        else
            LED[1] = 0;
        if(led_state[5:4] == 2 || (led_state[5:4] == 1 && l_clkout == 1))
            LED[2] = 1;
        else
            LED[2] = 0;
        if(led_state[7:6] == 2 || (led_state[7:6] == 1 && l_clkout == 1))
            LED[3] = 1;
        else
            LED[3] = 0;
        if(led_state[9:8] == 2 || (led_state[9:8] == 1 && l_clkout == 1))
            LED[4] = 1;
        else
            LED[4] = 0;
end
endmodule