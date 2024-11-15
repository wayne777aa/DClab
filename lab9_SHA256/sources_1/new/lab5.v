`timescale 1ns / 1ps
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
localparam [2:0] S_MAIN_INIT = 0, S_MAIN_BTN = 1, S_MAIN_CALCULATE = 2,
                 S_MAIN_SHOW = 3;
reg [2:0] P, P_next;
wire btn_level, btn_pressed;
reg  prev_btn_level;
reg [127:0] row_A = "Hit BTN3 to     "; // Initialize the text of the first row. 
reg [127:0] row_B = "CALCULATE       "; // Initialize the text of the second row.

localparam DELAY1 = 100_000000;
reg [$clog2(DELAY1):0] counter;
reg [$clog2(DELAY1):0] init_counter;
reg [55:0] timer;
reg [255:0] passwd_hash = 256'h5f140cdd68d02a020af21299eb57850c55b7ef294e97c18e217c4e911961b785;
reg [71:0] finalnum;
wire [71:0] hash [5:0];
wire [5:0] done;

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

// Enable one cycle of btn_pressed per each button hit
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;

//----------------------------
// FSM
//----------------------------
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT;
  end
  else begin
    P <= P_next;
  end
end
always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Wait for initial delay of the circuit.
	  if (init_counter < DELAY1) P_next = S_MAIN_INIT; //等初始化
      else P_next = S_MAIN_BTN; //初始化完
    S_MAIN_BTN:
      if(btn_pressed) P_next = S_MAIN_CALCULATE;
      else P_next = S_MAIN_BTN;
    S_MAIN_CALCULATE:
      if(|done) P_next = S_MAIN_SHOW;
      else P_next = S_MAIN_CALCULATE;
    S_MAIN_SHOW:
      P_next = S_MAIN_SHOW;
  endcase
end
// end of FSM
//----------------------------
// main function
//----------------------------

SHA256 F0(
  .clk(clk),
  .P(P),
  .passwd_hash(passwd_hash),
  .start(72'h303030303030303030),
  .hash(hash[0]),
  .done(done[0])
);
    
SHA256 F1(
  .clk(clk),
  .P(P),
  .passwd_hash(passwd_hash),
  .start(72'h313636363636363636),
  .hash(hash[1]),
  .done(done[1])
);

SHA256 F2(
  .clk(clk),
  .P(P),
  .passwd_hash(passwd_hash),
  .start(72'h333333333333333332),
  .hash(hash[2]),
  .done(done[2])
);

SHA256 F3(
  .clk(clk),
  .P(P),
  .passwd_hash(passwd_hash),
  .start(72'h343939393939393938),
  .hash(hash[3]),
  .done(done[3])
);

SHA256 F4(
  .clk(clk),
  .P(P),
  .passwd_hash(passwd_hash),
  .start(72'h363636363636363634),
  .hash(hash[4]),
  .done(done[4])
);

SHA256 F5(
  .clk(clk),
  .P(P),
  .passwd_hash(passwd_hash),
  .start(72'h383333333333333330),
  .hash(hash[5]),
  .done(done[5])
);

always @(posedge clk) begin
  if(~reset_n || P == S_MAIN_INIT)
    finalnum <= 0;
  else if (P_next == S_MAIN_SHOW) begin
    case(done)
      6'b000001:
        finalnum <= hash[0];
      6'b000010:
        finalnum <= hash[1];
      6'b000100:
        finalnum <= hash[2];
      6'b001000:
        finalnum <= hash[3];
      6'b010000:
        finalnum <= hash[4];
      6'b100000:
        finalnum <= hash[5];
    endcase
  end
end

// end of main function
//----------------------------
// counter
//----------------------------
// initial counter
always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + (init_counter < DELAY1);
  else init_counter <= 0;
end
//counter
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_INIT) begin
    timer <= 0;
    counter <= 0;
  end
  else if (P == S_MAIN_CALCULATE) begin
    if(counter==DELAY1) begin
      counter <= 0;
      timer <= timer+(timer<56'hFFFFFFFFFFFFFF);
    end else
      counter <= counter +1;
  end
end
//end of counter
//----------------------------
// LCD Display function.
//----------------------------
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_INIT) begin
    row_A <= "Hit BTN3 to     ";
    row_B <= "CALCULATE       ";
  end else if (P == S_MAIN_BTN) begin
    row_A <= "Hit BTN3 to     ";
    row_B <= "CALCULATE       ";
  end else if (P == S_MAIN_CALCULATE) begin
    row_A <= "calculating...  ";
    row_B[127:112] <= "T:";
    row_B[111:104] <= ((timer[55:52] > 9)? "7" : "0") + timer[55:52];
    row_B[103: 96] <= ((timer[51:48] > 9)? "7" : "0") + timer[51:48];
    row_B[ 95: 88] <= ((timer[47:44] > 9)? "7" : "0") + timer[47:44];
    row_B[ 87: 80] <= ((timer[43:40] > 9)? "7" : "0") + timer[43:40];
    row_B[ 79: 72] <= ((timer[39:36] > 9)? "7" : "0") + timer[39:36]; 
    row_B[ 71: 64] <= ((timer[35:32] > 9)? "7" : "0") + timer[35:32];
    row_B[ 63: 56] <= ((timer[31:28] > 9)? "7" : "0") + timer[31:28];
    row_B[ 55: 48] <= ((timer[27:24] > 9)? "7" : "0") + timer[27:24];
    row_B[ 47: 40] <= ((timer[23:20] > 9)? "7" : "0") + timer[23:20];
    row_B[ 39: 32] <= ((timer[19:16] > 9)? "7" : "0") + timer[19:16];
    row_B[ 31: 24] <= ((timer[15:12] > 9)? "7" : "0") + timer[15:12];
    row_B[ 23: 16] <= ((timer[11: 8] > 9)? "7" : "0") + timer[11: 8];
    row_B[ 15:  8] <= ((timer[ 7: 4] > 9)? "7" : "0") + timer[ 7: 4];
    row_B[  7:  0] <= ((timer[ 3: 0] > 9)? "7" : "0") + timer[ 3: 0];
  end else if (P == S_MAIN_SHOW) begin
    row_A[127:96] <= "Pwd:";
    row_A[ 95: 88] <= finalnum[71:64];
    row_A[ 87: 80] <= finalnum[63:56];
    row_A[ 79: 72] <= finalnum[55:48]; 
    row_A[ 71: 64] <= finalnum[47:40];
    row_A[ 63: 56] <= finalnum[39:32];
    row_A[ 55: 48] <= finalnum[31:24];
    row_A[ 47: 40] <= finalnum[23:16];
    row_A[ 39: 32] <= finalnum[15: 8];
    row_A[ 31: 24] <= finalnum[ 7: 0];
    row_A[ 23:  0] <= "   ";
    row_B[127:112] <= "T:";
    row_B[111:104] <= ((timer[55:52] > 9)? "7" : "0") + timer[55:52];
    row_B[103: 96] <= ((timer[51:48] > 9)? "7" : "0") + timer[51:48];
    row_B[ 95: 88] <= ((timer[47:44] > 9)? "7" : "0") + timer[47:44];
    row_B[ 87: 80] <= ((timer[43:40] > 9)? "7" : "0") + timer[43:40];
    row_B[ 79: 72] <= ((timer[39:36] > 9)? "7" : "0") + timer[39:36]; 
    row_B[ 71: 64] <= ((timer[35:32] > 9)? "7" : "0") + timer[35:32];
    row_B[ 63: 56] <= ((timer[31:28] > 9)? "7" : "0") + timer[31:28];
    row_B[ 55: 48] <= ((timer[27:24] > 9)? "7" : "0") + timer[27:24];
    row_B[ 47: 40] <= ((timer[23:20] > 9)? "7" : "0") + timer[23:20];
    row_B[ 39: 32] <= ((timer[19:16] > 9)? "7" : "0") + timer[19:16];
    row_B[ 31: 24] <= ((timer[15:12] > 9)? "7" : "0") + timer[15:12];
    row_B[ 23: 16] <= ((timer[11: 8] > 9)? "7" : "0") + timer[11: 8];
    row_B[ 15:  8] <= ((timer[ 7: 4] > 9)? "7" : "0") + timer[ 7: 4];
    row_B[  7:  0] <= ((timer[ 3: 0] > 9)? "7" : "0") + timer[ 3: 0];
  end
end
// End of the LCD display function
//----------------------------
endmodule
