`timescale 1ns/1ps

module stage2_tb(
    input clk,
    input enable,
    input rst,
    input [5:0] sw,
    input del,
    output [7:0] bit_sel,
    output [7:0] seg_out,
    output reg [19:0] data,
    output reg [3:0] times
);

parameter  period = 200000;
parameter  l_period = 200_000_000;

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
reg error_not_5_digits = 0;
reg error_not_1_times = 0;
assign seg_out = {Y_reg, 1'b1};
assign bit_sel = bit_sel_reg;

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
    if (sw5_history == 32'h3fff_ffff) begin
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
    if(rst == 1) begin
        data <= 20'b0;
        times <= 4'b0;
        pos <= 3'b0;
        error <= 0;
        error_not_1_times <= 0;
        error_not_5_digits <= 0;
        errorType <= 2'b0;
    end
    else begin
        if(enable == 1) begin
            if(sw[5] == 0) begin
                display_data <= {times, 8'b0, data};
                case(pos)
                    0: begin data[19:16] <= sw[3:0]; state <= 16'b10_00_00_01_00_00_00_00; end
                    1: begin data[15:12] <= sw[3:0];state <= 16'b10_00_00_10_01_00_00_00; end
                    2: begin data[11:8] <= sw[3:0];state <= 16'b10_00_00_10_10_01_00_00; end
                    3: begin data[7:4] <= sw[3:0];state <= 16'b10_00_00_10_10_10_01_00; end
                    4: begin data[3:0] <= sw[3:0];state <= 16'b10_00_00_10_10_10_10_01; end
                    5: state <= 16'b10_00_00_10_10_10_10_10;
                endcase
            end
            else begin
                display_data <= {times, 8'b0, data};
                case(pos)
                    0: begin times <= sw[3:0]; state <= 16'b01_00_00_10_10_10_10_10; end
                    1: begin state <= 16'b10_00_00_10_10_10_10_10; end
                endcase
            end
            if(sw4_posedge_detected == 1) begin
                if(sw[5] == 0) begin
                    if(sw[3:0] >= 4'b1010 || (sw[3:0] < 4'b1010 &&
                        (pos == 3'b001 && (data[19:16] == sw[3:0])) ||
                        (pos == 3'b010 && (data[19:16] == sw[3:0] || data[15:12] == sw[3:0])) ||
                        (pos == 3'b011 && (data[19:16] == sw[3:0] || data[15:12] == sw[3:0] || data[11:8] == sw[3:0])) || 
                        (pos == 3'b100 && (data[19:16] == sw[3:0] || data[15:12] == sw[3:0] || data[11:8] == sw[3:0] || data[7:4] == sw[3:0])))) begin
                            errorType <= 2'b01;
                            error <= 1;
                    end 
                    else begin
                        if(pos != 3'b101) begin
                            pos <= pos + 3'b001;   
                        end
                    end
                end
                else begin
                    if(sw[3:0] >= 4'b1010 || sw[3:0] == 4'b0) begin
                        errorType <= 2'b10;
                        error <= 1;
                    end
                    else begin
                        if(pos != 3'b001) begin
                            pos <= pos + 3'b001;   
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
                if(error_not_1_times == 1)begin
                    error_not_1_times <= 0;
                end
                else begin
                    if(pos != 3'b101) begin
                        errorType <= 2'b01;
                        error_not_5_digits <= 1;
                    end
                    else begin
                        pos <= 3'b0;
                    end
                end
            end
            else if(sw5_negedge_detected) begin
                if(error_not_5_digits == 1)begin
                    error_not_5_digits <= 0;
                end
                else begin 
                    if(pos != 3'b001) begin
                        errorType <= 2'b10;
                        error_not_1_times <= 1;
                    end
                    else begin
                        pos <= 3'b0;
                    end
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
    if(!enable)
        bit_sel_reg = 8'b00000000;
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
always @(scan_cnt)
begin
    if(error == 0 && error_not_1_times == 0 && error_not_5_digits == 0)
    begin
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
        else
        begin
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
    end
endmodule