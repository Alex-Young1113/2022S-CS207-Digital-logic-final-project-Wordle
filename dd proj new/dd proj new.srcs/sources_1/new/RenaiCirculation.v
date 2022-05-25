`timescale 1ns / 1ps

module RenaiCirculation(input clk, input enable, output reg[0:0] music = 0);

parameter do_low = 382225;
parameter re_low = 340524;
parameter me_low = 303372;
parameter fa_low = 286345;
parameter so_low = 255105;
parameter la_low = 227272;
parameter si_low = 202476;

parameter do = 191110;
parameter re = 170259;
parameter me = 151685;
parameter fa = 143172;
parameter so = 127554;
parameter la = 113636;
parameter si = 101239;


parameter beat = 15_000_000;
parameter gap =  3_750_000;
parameter index_period = beat + gap;

parameter silence = beat<<9;

reg [1269:0] melody = 1270'b0100001001010000100001000010100101000000010000000001010000000110101010000000101001001010000100101010010100000001001000000101000000011000000001001010100100001001010100101000000010010000001010000000110101010000000101001001010000100101010010100000001001000000101000000011000000001000010010100000000010000011001000010000101000110010000100001010010110101001011011000000001100010110101001011010100000001100010110101001011010100000001010001100100000000010000011001000010000101000110010000100001010010110101001011011000000001100010110101001011010100000001100010110101001011010100000001000010010000001000010100101100000001010000001000001010000001000000000010100000010000010100000010000010101000000000101001001010000000001000001010100000000010100100101000000000100001010000000011000000010000101001011000000010100000010000010100000010000000000101000000100000101000000100000101010000000001010010010100000000010000010101000000000101001001010000000001000000000100001010010000000001000010010100000000010000010100110000000011000101010000000001010001010011000000001100010101000000000100000101001100000000110001010000001010001100100000000010000100101000000000100000101001100000000110001010000001010000000100000101001100000000110001010100000000010000010100110000000011000101010000101001000;

parameter length = 254;

reg[29:0] freq =  beat;

integer frequency_count = 0;      // count1 control frequency
integer index_count = 0;      // count2 control beat;
integer index = 0;       // index control the location music playing

always @(posedge clk) begin
    
    if(enable == 0) begin
        index = 0;
        index_count = 0;
        frequency_count = 0;
        music = 0;
    end
    else begin
        if(frequency_count >= freq) begin
            frequency_count = 0;
            music = ~music;
         end
        else 
            frequency_count = frequency_count + 1;
        if(index_count > index_period) begin
            index_count = 0;
            index = index + 1;
        end
        if(index >length) begin
            index = 0;
        end
    end
    index_count = index_count + 1;
end

always @ * begin
    if(index_count <= gap)
        freq = silence;
    else
        case(melody[index * 5 +4 -:5])
        5'd0 : freq = silence;
        5'd1 : freq = do_low;
        5'd2 : freq = re_low;
        5'd3 : freq = me_low;
        5'd4 : freq = fa_low;
        5'd5 : freq = so_low;
        5'd6 : freq = la_low;
        5'd7 : freq = si_low;
        5'd8 : freq = do;
        5'd9 : freq = re;
        5'd10 : freq = me;
        5'd11: freq = fa;
        5'd12 : freq = so;
        5'd13 : freq = la;
        5'd14 : freq = si;
        default : freq = silence;
        endcase
end


endmodule