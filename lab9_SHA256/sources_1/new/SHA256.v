`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/16 00:22:32
// Design Name: 
// Module Name: SHA256
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


module SHA256(
  input clk,
  input [2:0] P,
  input [255:0] passwd_hash, //要求的password_hash
  input [71:0] start, //起始數字
  output [71:0] hash,
  output done //find password
    );
localparam [2:0] S_MAIN_INIT = 0, S_MAIN_BTN = 1, S_MAIN_CALCULATE = 2,
                 S_MAIN_SHOW = 3;
reg [31:0] H0 = 32'h6a09e667;
reg [31:0] H1 = 32'hbb67ae85;
reg [31:0] H2 = 32'h3c6ef372;
reg [31:0] H3 = 32'ha54ff53a;
reg [31:0] H4 = 32'h510e527f;
reg [31:0] H5 = 32'h9b05688c;
reg [31:0] H6 = 32'h1f83d9ab;
reg [31:0] H7 = 32'h5be0cd19;
reg [31:0] K [0:63];
reg [31:0] W [0:63];
reg [31:0] a, b, c, d, e, f, g, h;
reg [31:0] temp1, temp2;
reg cnt;
reg [71:0] curnum;
reg [255:0] H_out;
integer i;
assign done = (i==131);
assign hash = curnum;
always @(posedge clk) begin
  if (P == S_MAIN_INIT) begin
    curnum <= start;
    i <= 0;
    a <= 32'h6a09e667; b <= 32'hbb67ae85; c <= 32'h3c6ef372; d <= 32'ha54ff53a;
    e <= 32'h510e527f; f <= 32'h9b05688c; g <= 32'h1f83d9ab; h <= 32'h5be0cd19;
    cnt <= 0;
    H_out <= 0;
    H0 = 32'h6a09e667;
    H1 = 32'hbb67ae85;
    H2 = 32'h3c6ef372;
    H3 = 32'ha54ff53a;
    H4 = 32'h510e527f;
    H5 = 32'h9b05688c;
    H6 = 32'h1f83d9ab;
    H7 = 32'h5be0cd19;
    K[ 0] <= 32'h428a2f98;
    K[ 1] <= 32'h71374491;
    K[ 2] <= 32'hb5c0fbcf;
    K[ 3] <= 32'he9b5dba5;
    K[ 4] <= 32'h3956c25b;
    K[ 5] <= 32'h59f111f1;
    K[ 6] <= 32'h923f82a4;
    K[ 7] <= 32'hab1c5ed5;
    K[ 8] <= 32'hd807aa98;
    K[ 9] <= 32'h12835b01;
    K[10] <= 32'h243185be;
    K[11] <= 32'h550c7dc3;
    K[12] <= 32'h72be5d74;
    K[13] <= 32'h80deb1fe;
    K[14] <= 32'h9bdc06a7;
    K[15] <= 32'hc19bf174;
    K[16] <= 32'he49b69c1;
    K[17] <= 32'hefbe4786;
    K[18] <= 32'h0fc19dc6;
    K[19] <= 32'h240ca1cc;
    K[20] <= 32'h2de92c6f;
    K[21] <= 32'h4a7484aa;
    K[22] <= 32'h5cb0a9dc;
    K[23] <= 32'h76f988da;
    K[24] <= 32'h983e5152;
    K[25] <= 32'ha831c66d;
    K[26] <= 32'hb00327c8;
    K[27] <= 32'hbf597fc7;
    K[28] <= 32'hc6e00bf3;
    K[29] <= 32'hd5a79147;
    K[30] <= 32'h06ca6351;
    K[31] <= 32'h14292967;
    K[32] <= 32'h27b70a85;
    K[33] <= 32'h2e1b2138;
    K[34] <= 32'h4d2c6dfc;
    K[35] <= 32'h53380d13;
    K[36] <= 32'h650a7354;
    K[37] <= 32'h766a0abb;
    K[38] <= 32'h81c2c92e;
    K[39] <= 32'h92722c85;
    K[40] <= 32'ha2bfe8a1;
    K[41] <= 32'ha81a664b;
    K[42] <= 32'hc24b8b70;
    K[43] <= 32'hc76c51a3;
    K[44] <= 32'hd192e819;
    K[45] <= 32'hd6990624;
    K[46] <= 32'hf40e3585;
    K[47] <= 32'h106aa070;
    K[48] <= 32'h19a4c116;
    K[49] <= 32'h1e376c08;
    K[50] <= 32'h2748774c;
    K[51] <= 32'h34b0bcb5;
    K[52] <= 32'h391c0cb3;
    K[53] <= 32'h4ed8aa4a;
    K[54] <= 32'h5b9cca4f;
    K[55] <= 32'h682e6ff3;
    K[56] <= 32'h748f82ee;
    K[57] <= 32'h78a5636f;
    K[58] <= 32'h84c87814;
    K[59] <= 32'h8cc70208;
    K[60] <= 32'h90befffa;
    K[61] <= 32'ha4506ceb;
    K[62] <= 32'hbef9a3f7;
    K[63] <= 32'hc67178f2;
  end else if(P == S_MAIN_CALCULATE && i<16) begin //填到512位
    W[0] <= curnum[71:40];
    W[1] <= curnum[39:8];
    W[2] <= {curnum[7:0],24'b100000000000000000000000};
    W[3] <= 32'd0;
    W[4] <= 32'd0;
    W[5] <= 32'd0;
    W[6] <= 32'd0;
    W[7] <= 32'd0;
    W[8] <= 32'd0;
    W[9] <= 32'd0;
    W[10] <= 32'd0;
    W[11] <= 32'd0;
    W[12] <= 32'd0;
    W[13] <= 32'd0;
    W[14] <= 32'd0;
    W[15] <= 32'b00000000_00000000_00000000_01001000; //8bits * 9位數字
    i <= 16;
  end else if(P == S_MAIN_CALCULATE && i<64) begin // 填充計算
    W[i] <= W[i-16] + 
            ({W[i-15][ 6:0], W[i-15][31: 7]} ^ {W[i-15][17:0], W[i-15][31:18]} ^ ((W[i-15] >>  3))) + //sigma0(rotate7,18,shift3)
            W[i- 7] +
            ({W[i- 2][16:0], W[i- 2][31:17]} ^ {W[i- 2][18:0], W[i- 2][31:19]} ^ ((W[i- 2] >> 10)));  //sigma1(rotate17,19,shift10)
    i <= i+1;
  end else if(P == S_MAIN_CALCULATE && i<128) begin
    case(cnt)
    0:begin
      temp1 = h + 
              ({e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]}) + //Sigma1(rotate6,11,25)
              ((e & f) ^ (~e & g)) + //choice
              W[i-64] + K[i-64];
      temp2 = ({a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]}) + //Sigma0(rotate2,13,22)
              ((a & b) ^ (a & c) ^ (b & c)); //Majority
      cnt <= 1;
    end
    1:begin
      a <= temp1 + temp2;
      b <= a;
      c <= b;
      d <= c;
      e <= d + temp1;
      f <= e;
      g <= f;
      h <= g;
      cnt <= 0;
      i <= i+1;
    end
    endcase
  end else if(P == S_MAIN_CALCULATE && i==128) begin
            H0 <= H0 + a;
            H1 <= H1 + b;
            H2 <= H2 + c;
            H3 <= H3 + d;
            H4 <= H4 + e;
            H5 <= H5 + f;
            H6 <= H6 + g;
            H7 <= H7 + h;
            i  <= i+1;
  end else if(P == S_MAIN_CALCULATE && i==129) begin
    H_out <= {H0, H1, H2, H3, H4, H5, H6, H7};
    i <= i+1;
  end else if(P == S_MAIN_CALCULATE && i==130) begin
    if(passwd_hash == H_out) i <= 131;
    else begin
      i <= 0;
      H0 = 32'h6a09e667;
      H1 = 32'hbb67ae85;
      H2 = 32'h3c6ef372;
      H3 = 32'ha54ff53a;
      H4 = 32'h510e527f;
      H5 = 32'h9b05688c;
      H6 = 32'h1f83d9ab;
      H7 = 32'h5be0cd19;
      a <= 32'h6a09e667;
      b <= 32'hbb67ae85;
      c <= 32'h3c6ef372;
      d <= 32'ha54ff53a;
      e <= 32'h510e527f;
      f <= 32'h9b05688c;
      g <= 32'h1f83d9ab;
      h <= 32'h5be0cd19;
      cnt <= 0;
      if(curnum[7:0] == "9") begin //只計算數字密碼
        curnum[7:0] <= "0";
        if(curnum[15:8] == "9") begin
          curnum[15:8] <= "0";
            if(curnum[23:16] == "9") begin
            curnum[23:16] <= "0";
              if(curnum[31:24] == "9") begin
              curnum[31:24] <= "0";
                if(curnum[39:32] == "9") begin
                curnum[39:32] <= "0";
                  if(curnum[47:40] == "9") begin
                  curnum[47:40] <= "0";
                    if(curnum[55:48] == "9") begin
                    curnum[55:48] <= "0";
                      if(curnum[63:56] == "9") begin
                      curnum[63:56] <= "0";
                        if(curnum[71:64] == "9") begin
                        curnum[71:64] <= "0";
                      end else
                        curnum[71:64] <= curnum[71:64]+1;
                    end else
                      curnum[63:56] <= curnum[63:56]+1;
                  end else
                    curnum[55:48] <= curnum[55:48]+1;
                end else
                  curnum[47:40] <= curnum[47:40]+1;
              end else
                curnum[39:32] <= curnum[39:32]+1;
            end else
              curnum[31:24] <= curnum[31:24]+1;
          end else
            curnum[23:16] <= curnum[23:16]+1;
        end else
          curnum[15:8] <= curnum[15:8]+1;
      end else 
        curnum <= curnum+1;
    end 
  end
end

endmodule
