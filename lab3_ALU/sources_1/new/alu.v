`timescale 1ns / 1ps

module alu(
    // DO NOT modify the interface!
    // input signal
    input [7:0] accum,
    input [7:0] data,
    input [2:0] opcode,
    input reset,
    
    // result
    output [7:0] alu_out,
    
    // PSW
    output zero,
    output overflow,
    output parity,
    output sign
    );
    
    reg [7:0] alu;
    reg ze;
    reg over;
    reg pa;
    reg si;
    assign alu_out = alu[7:0];
    assign zero = ze;
    assign overflow = over;
    assign parity = pa;
    assign sign = si;
    
    
    initial begin
        alu = 0;
        ze = 0;
        over = 0;
        pa = 0;
        si = 0;
    end
    
    always @(*) begin
        if(reset) begin
            alu = 0;
            ze = 0;
            over = 0;
            pa = 0;
            si = 0;
        end
        else begin
            alu = 0;
            ze = 0;
            over = 0;
            pa = 0;
            si = 0;
            case(opcode)
                3'b000: alu = accum;
                3'b001: begin 
                            alu = accum + data;
                            if((accum[7] == 0)&&(data[7] == 0)&&(alu[7] == 1)) begin //underflow
                                alu = 8'b01111111;
                                over = 1;
                            end
                            if((accum[7] == 1)&&(data[7] == 1)&&(alu[7] == 0)) begin //underflow
                                alu = 8'b10000000;
                                over = 1;
                            end
                        end
                3'b010: begin 
                            alu = accum - data;
                            if((accum[7] == 0)&&(data[7] == 1)&&(alu[7] == 1)) begin //underflow
                                alu = 8'b01111111;
                                over = 1;
                            end
                            if((accum[7] == 1)&&(data[7] == 0)&&(alu[7] == 0)) begin //underflow
                                alu = 8'b10000000;
                                over = 1;
                            end
                        end
                3'b011: alu = $signed(accum) >>> data;
                3'b100: alu = accum ^ data;
                3'b101: begin 
                            if(accum[7] == 1) begin
                                alu = ~accum+1;
                            end 
                            else alu = accum;
                        end
//                3'b110: alu = $signed(accum[3:0]) * $signed(data[3:0]);
                3'b110: alu = {{4{accum[3]}},accum[3:0]} * {{4{data[3]}},data[3:0]};    //前面補和符號位一樣的數一路補到左邊的位數
                3'b111: alu = ~accum+1;
                default: alu = 0;
            endcase
            if(alu == 0) ze = 1;
            pa = ^alu[7:0];
            si = alu[7];
        end
    end
endmodule
