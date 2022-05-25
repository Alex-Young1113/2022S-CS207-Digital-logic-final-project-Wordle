module wordle(
    input clk,
    input [7:0] sw,
    input del,
    output reg[7:0] bit_sel,
    output reg[7:0] seg_out,
    output reg[4:0] led_sel,
    output buzzer
);
reg stage2_enable = 0;
reg stage3_enable = 0;
wire [19:0] data;
wire [3:0] times;
wire [4:0] led;
stage2_tb s2(clk, stage2_enable, sw[7], sw[5:0], del, bit_sel_2, seg_out_2, data, times);
stage3_tb s3(clk, stage3_enable, sw[7], sw[5:0], del, data, times, bit_sel_3, seg_out_3, led, buzzer);
reg [1:0] stage = 2'b01;
reg sw6_negedge_detected = 0;
reg sw6_posedge_detected = 0;
reg sw7_posedge_detected = 0;
reg [31:0] sw6_history = 32'b0;
reg [31:0] sw7_history = 32'b0;
wire [7:0] bit_sel_2;
wire [7:0] bit_sel_3;
wire [7:0] seg_out_2;
wire [7:0] seg_out_3;

reg clkout = 0;
reg [31:0] cnt = 32'b0;
parameter period = 200_000;

always @(posedge clk)
begin
    if(cnt == (period >> 1) - 1) begin
        clkout <= ~clkout;
        cnt <= 0;
    end
    else
        cnt <= cnt + 1;
end

always @(negedge clkout) begin  
    sw6_history <= { sw6_history[30:0], sw[6] } ;
    if (sw6_history == 32'h3fff_ffff) begin
        sw6_posedge_detected <= 1'b1;
    end
    else begin
        sw6_posedge_detected <= 1'b0;
    end
    if(sw6_history == 32'hffff_fffc) begin
        sw6_negedge_detected <= 1'b1;
    end
    else begin
        sw6_negedge_detected <= 1'b0;
    end
end

always @(negedge clkout) begin  
    sw7_history <= { sw7_history[30:0], sw[7] } ;
    if (sw7_history == 32'h3fff_ffff)
        sw7_posedge_detected <= 1'b1;
    else
        sw7_posedge_detected <= 1'b0;
end

always @(posedge clkout) begin
    if(stage == 2'b01 && sw6_posedge_detected == 1) begin
        stage <= 2'b10;
    end
    else if (stage == 2'b10 && sw6_negedge_detected == 1) begin
        stage <= 2'b11;
    end
    else if(sw7_posedge_detected == 1) begin
        stage <= 2'b01;
    end
end

always @(stage)
    if(stage == 2'b01) begin
        led_sel <= 5'b0;
        bit_sel <= 8'b1111_1111;
        seg_out <= 8'b1111_1111;
        stage2_enable <= 0;
        stage3_enable <= 0;
    end
    else if(stage == 2'b10) begin
        led_sel <= 5'b0;
        bit_sel <= bit_sel_2;
        seg_out <= seg_out_2;
        stage2_enable <= 1;
        stage3_enable <= 0;
    end
    else begin
        led_sel <= led;
        bit_sel <= bit_sel_3;
        seg_out <= seg_out_3;
        stage2_enable <= 0;
        stage3_enable <= 1;
    end
endmodule