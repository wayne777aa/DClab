`timescale 1ns / 1ps
//---------------display--------------
module display(
  input clk,
  input reset_n,
  input usr_sw0, // start/end
  input usr_sw, // 1~3
  input [79:0] seq,
  input [1:0] timer,
  output reg [7:0] cs,
  output reg [7:0] ns
);
  reg [27:0] cnt;
  reg [27:0] cnt2; //cnt2因為第一次還沒reset之前的那次一開始會出現0,initial沒有用
  integer i = 1;
  always@(posedge clk) begin
    if(~reset_n) begin
      cnt<= 0;
      i <= 1;
      cs <= seq[0 +:8];
      ns <= seq[8 +:8];
    end
    else if(~usr_sw0 && usr_sw)begin
    //--------------cnt2----------------
      if(cnt2< timer*100000000) begin
        cnt2 <= cnt2+1;
        cs <= seq[0 +:8];
        ns <= seq[8 +:8];
      end
    //----------------------------------
      if(cnt < timer*100000000) //timer秒
        cnt <= cnt+1;
      else begin
        cnt <= 0;
        if(i<8) i <= i+1;
        else i <= 0;
        cs <= seq[i*8 +:8];
        ns <= seq[i*8+8 +:8];
      end
    end
end
endmodule
/////////////////////////////////////////////////////////
module lab5(
  input clk,
  input reset_n,
  input [3:0] usr_btn,      // button 
  input [3:0] usr_sw,       // switches
  output [3:0] usr_led,     // led
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

assign usr_led = 4'b0000; // turn off led
reg [127:0] row_A = "     |2|8|3|    "; // Initialize the text of the first row. 
reg [127:0] row_B = "     |1|9|1|    "; // Initialize the text of the second row.

wire [79:0] seq1;
wire [79:0] seq2;
wire [79:0] seq3;
assign seq1 = "1987654321";//1,2,3,4,5,6,7,8,9,1...
assign seq2 = "9123456789";//9,8,7,6,5,4,3,2,1,9...
assign seq3 = "1864297531"; //1,3,5,7,9,2,4,6,8,1...
wire [1:0] timer1 = 2'b01; //1 second
wire [1:0] timer2 = 2'b10; //2 seconds
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
//from left to right |0|1|2|
wire [7:0] row1 [2:0]; //next
wire [7:0] row2 [2:0]; //current
//------------display--------------
display col1(.clk(clk), .reset_n(reset_n), .usr_sw0(usr_sw[0]), .usr_sw(usr_sw[3]), .seq(seq1), .timer(timer1), .ns(row1[0]), .cs(row2[0]));
display col2(.clk(clk), .reset_n(reset_n), .usr_sw0(usr_sw[0]), .usr_sw(usr_sw[2]), .seq(seq2), .timer(timer2), .ns(row1[1]), .cs(row2[1]));
display col3(.clk(clk), .reset_n(reset_n), .usr_sw0(usr_sw[0]), .usr_sw(usr_sw[1]), .seq(seq3), .timer(timer1), .ns(row1[2]), .cs(row2[2]));

wire [1:0] eql = (row2[0] == row2[1])+ (row2[0] == row2[2])+ (row2[1] == row2[2]); //how many the same
reg [4:0] flag = 5'b00000; //[3:0]對應switch [4]對應gameover or error
always @(posedge clk) begin
  if (~reset_n) begin
    // Initialize the text when the user hit the reset button
    row_A <= "     |2|8|3|    ";
    row_B <= "     |1|9|1|    ";
    flag <= 5'b00000; //error detect
  end else if (~usr_sw[0] && |usr_sw && ~flag[4]) begin //at least one sw is 1
        row_A[39:0]  <= "|    ";
        row_A[47:40] <= row1[2];
        row_A[55:48] <= "|";
        row_A[63:56] <= row1[1];
        row_A[71:64] <= "|";
        row_A[79:72] <= row1[0];
        row_A[127:80]<= "     |";
        
        row_B[39:0]  <= "|    ";
        row_B[47:40] <= row2[2];
        row_B[55:48] <= "|";
        row_B[63:56] <= row2[1];
        row_B[71:64] <= "|";
        row_B[79:72] <= row2[0];
        row_B[127:80]<= "     |";
  end
  else if(~|usr_sw) begin
    if(eql == 0) row_A <= "   Loser!       ";
    if(eql == 1) row_A <= "   Free Game!   ";
    if(eql >  1) row_A <= "   Jackpots!    ";
    row_B <= "   Game over    ";
    flag[4] <= 1;
  end
//-----------error detect-------------
//when pull down flag <= 1
  if(~usr_sw[0]) flag[0] <= 1;
  if(~usr_sw[1]) flag[1] <= 1;
  if(~usr_sw[2]) flag[2] <= 1;
  if(~usr_sw[3]) flag[3] <= 1;
//pull down sw[3:1] before sw[0]
  if(flag[0] == 0) begin
    if((flag[0] || flag[1] || flag[2]) == 1) begin
      flag[4] <= 1;
      row_A <= "   ERROR        ";
      row_B <= "  game stopped  ";
    end
  end
//pull up again during gameplay
  if(flag[4] == 0) begin
    if((flag[0]==1 && usr_sw[0] == 1) ||
       (flag[1]==1 && usr_sw[1] == 1) ||
       (flag[2]==1 && usr_sw[2] == 1) ||
       (flag[3]==1 && usr_sw[3] == 1)   ) begin
          flag[4] <= 1;
          row_A <= "   ERROR        ";
          row_B <= "  game stopped  ";
    end
  end
end
endmodule
