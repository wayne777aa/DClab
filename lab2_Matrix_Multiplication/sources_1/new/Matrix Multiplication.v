`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/17 23:26:13
// Design Name: 
// Module Name: Matrix Multiplication
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mmult(
  input  clk,                 // Clock signal.
  input  reset_n,             // Reset signal (negative logic).
  input  enable,              // Activation signal for matrix multiplication (tells the circuit that A and B are ready for use).
  input  [0:9*8-1] A_mat,     // A matrix.
  input  [0:9*8-1] B_mat,     // B matrix.

  output valid,               // Signals that the output is valid
                              //   to read.
  output reg [0:9*18-1] C_mat // The result of A x B.
);

reg [0:71] A;
reg [0:71] B;
reg v;

assign valid = v;

integer i;
initial begin
    i = 0;
end

always @(posedge clk) begin
    
    if(~reset_n) begin
        A <= A_mat;
        B <= B_mat;
        v <= 0;
        i <= 0;
    end 
    else if(enable && ~v) begin
        if(i<3) begin
            C_mat[54*i+:18] <= A[24*i+:8]*B[0+:8]+A[8+24*i+:8]*B[24+:8]+A[16+24*i+:8]*B[48+:8];
            C_mat[18+54*i+:18] <= A[24*i+:8]*B[8+:8] +A[8+24*i+:8]*B[32+:8]+A[16+24*i+:8]*B[56+:8];
            C_mat[36+54*i+:18] <= A[24*i+:8]*B[16+:8]+A[8+24*i+:8]*B[40+:8]+A[16+24*i+:8]*B[64+:8];
        end
        if(i == 3) begin
            v <= 1;
        end else begin
            i <= i+1;
        end
    end
end
endmodule
