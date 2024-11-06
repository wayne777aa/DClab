`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/11/01 11:16:50
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is a sample circuit to show you how to initialize an SRAM
//              with a pre-defined data file. Hit BTN0/BTN1 let you browse
//              through the data.
// 
// Dependencies: LCD_module, debounce
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab7(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D,
  
  //uart
  input  uart_rx,
  output uart_tx
);

localparam [2:0] S_MAIN_INIT = 3'b000, S_MAIN_READSRAM = 3'b001,
                 S_MAIN_READMATRIX = 3'b010, S_MAIN_MAXPOOLING = 3'b011,
                 S_MAIN_MATRIXMUL = 3'b100, S_MAIN_WAIT = 3'b101,
                 S_MAIN_REPLY = 3'b110;
localparam INIT_DELAY = 100_000;
                 
//declare what I need
reg [$clog2(INIT_DELAY):0] init_counter;

reg [7 : 0] ram [97:0];
wire r_done;

reg [7:0] A[48:0];
reg [7:0] B[48:0];
integer imatrix = 0;
wire read_matrix_done;

reg [4:0] ia,ib;
reg [18:0] poolA[24:0];
reg [18:0] poolB[24:0];
wire maxpooling_done;
reg [7:0] maxa,maxb;

reg [4:0] i_reply;
wire wait_done;

//reg [25*19-1:0] outmat;
reg [18:0] outmat[24:0];
reg [4:0]  idxmul;
wire mul_done;

// declare uart
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam MEM_SIZE   = 199;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [7:0] data[0:MEM_SIZE-1];
reg [0:MEM_SIZE*8-1] msg = {"\015\012The matrix operation result is:\015\012The matrix operation result is:\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]", 8'h00 };
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;
reg [1:0] Q, Q_next;
wire print_enable, print_done;
reg done;

// declare system variables
wire [1:0]  btn_level, btn_pressed;
reg  [1:0]  prev_btn_level;
reg  [2:0]  P, P_next;
reg  [11:0] user_addr;
reg  [7:0]  user_data;

reg  [127:0] row_A, row_B;

// declare SRAM control signals
wire [10:0] sram_addr;
wire [7:0]  data_in;
wire [7:0]  data_out;
wire        sram_we, sram_en;

assign usr_led = 4'h00;

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
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 2'b00;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

// ------------------------------------------------------------------------
// The following code creates an initialized SRAM memory block that
// stores an 1024x8-bit unsigned numbers.
sram ram0(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
                             // if you set 'we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = (P == S_MAIN_READSRAM); // Enable the SRAM block.
assign sram_addr = user_addr[11:0];
assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT:
      if (init_counter < INIT_DELAY) P_next = S_MAIN_INIT; //等初始化
	  else if(btn_pressed[1]) P_next = S_MAIN_READSRAM;
	  else P_next = S_MAIN_INIT;
    S_MAIN_READSRAM: // read SRAM
      if (r_done) P_next = S_MAIN_READMATRIX;
      else P_next = S_MAIN_READSRAM;
    S_MAIN_READMATRIX: // read A B matrix
      if (read_matrix_done) P_next = S_MAIN_MAXPOOLING;
      else P_next = S_MAIN_READMATRIX;
    S_MAIN_MAXPOOLING: //max pooling
      if (maxpooling_done) P_next = S_MAIN_MATRIXMUL;
      else P_next = S_MAIN_MAXPOOLING;
    S_MAIN_MATRIXMUL:
      if (mul_done)P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_MATRIXMUL;
    S_MAIN_WAIT: // wait for a button click
      if (wait_done) P_next = S_MAIN_REPLY;
      else P_next = S_MAIN_WAIT;
    S_MAIN_REPLY: // Print the hello message.
      if (print_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_REPLY;
  endcase
end

// FSM ouput logic: Fetch the data bus of sram[] for display
always @(posedge clk) begin
  if (~reset_n) user_data <= 8'b0;
  else if (sram_en && !sram_we) user_data <= data_out;
end

always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end

// End of the main controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// -------------UART---------------------
//localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
//                 S_UART_SEND = 2, S_UART_INCR = 3;
//localparam MEM_SIZE   = 199;
// declare UART signals
//reg [$clog2(MEM_SIZE):0] send_counter;
//reg [7:0] data[0:MEM_SIZE-1];
//reg [0:MEM_SIZE*8-1] msg = {"\015\012The matrix operation result is:\015\012The matrix operation result is:\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]\015\012[00000,00000,00000,00000,00000]", 8'h00 };
/*
{"
\015\012The matrix operation result is: 33 //不知道為什麼第一行會不見 但總之秉持著能動就別動的原則 就不碰他了
\015\012The matrix operation result is: 33
\015\012[00040,00046,00052,00058,00064] 33
\015\012[00073,00079,00085,00091,00097] 33
\015\012[00106,00112,00118,00124,00130] 33
\015\012[00139,00145,00151,00157,00163] 33
\015\012[00172,00178,00184,00190,00196]", 8'h00 } 34
total 33+166
*/
uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);

integer idx;
//reg [4:0] i_reply;
reg [2:0]count;
//wire wait_done;
assign wait_done = i_reply >= 25;
always @(posedge clk) begin
  if (~reset_n) begin
    for (idx = 0; idx < MEM_SIZE; idx = idx + 1) data[idx] = msg[idx*8 +: 8];
  end
  else if(P == S_MAIN_INIT) begin 
    i_reply <= 0;
    count <= 0;
  end
  else if(P == S_MAIN_WAIT && count <5)begin
    case(i_reply)
      0:begin
          if(count <4)
            data[40-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[40-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
//          if(count <3)//poolA
//            data[40+(i_reply%5)*6-count]  <= ((poolA[i_reply][4*count+:4] > 9)? "7" : "0") + poolA[i_reply][4*count+:4];
//          if(count <3)//poolB
//            data[40+(i_reply%5)*6-count]  <= ((poolB[i_reply][4*count+:4] > 9)? "7" : "0") + poolB[i_reply][4*count+:4];
//          if(count <4)//
//            data[40+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
//          if(count ==4)
//            data[40+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
      end
      1:begin 
          if(count <4)
            data[46-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[46-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
//          if(count <3)
//            data[73+(i_reply%5)*6-count]  <= ((poolA[i_reply][4*count+:4] > 9)? "7" : "0") + poolA[i_reply][4*count+:4];
//          if(count <3)
//            data[73+(i_reply%5)*6-count]  <= ((poolB[i_reply][4*count+:4] > 9)? "7" : "0") + poolB[i_reply][4*count+:4];
//          if(count <4)//
//            data[73+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
//          if(count ==4)
//            data[73+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
      end
      2:begin
          if(count <4)
            data[52-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[52-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
//          if(count <3)
//            data[106+(i_reply%5)*6-count]  <= ((poolA[i_reply][4*count+:4] > 9)? "7" : "0") + poolA[i_reply][4*count+:4];
//          if(count <3)
//            data[106+(i_reply%5)*6-count]  <= ((poolB[i_reply][4*count+:4] > 9)? "7" : "0") + poolB[i_reply][4*count+:4];
//          if(count <4)//
//            data[106+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
//          if(count ==4)
//            data[106+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
      end
      3:begin
          if(count <4)
            data[58-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[58-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
//          if(count <3)
//            data[139+(i_reply%5)*6-count]  <= ((poolA[i_reply][4*count+:4] > 9)? "7" : "0") + poolA[i_reply][4*count+:4];
//          if(count <3)
//            data[139+(i_reply%5)*6-count]  <= ((poolB[i_reply][4*count+:4] > 9)? "7" : "0") + poolB[i_reply][4*count+:4];
//          if(count <4)//
//            data[139+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
//          if(count ==4)
//            data[139+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
      end
      4:begin
          if(count <4)
            data[64-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[64-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
//          if(count <3)
//            data[172+(i_reply%5)*6-count]  <= ((poolA[i_reply][4*count+:4] > 9)? "7" : "0") + poolA[i_reply][4*count+:4];
//          if(count <3)
//            data[172+(i_reply%5)*6-count]  <= ((poolB[i_reply][4*count+:4] > 9)? "7" : "0") + poolB[i_reply][4*count+:4];
//          if(count <4)//
//            data[172+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
//          if(count ==4)
//            data[172+(i_reply%5)*6-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
      end
      5:begin
          if(count <4)
            data[73-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[73-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      6:begin
          if(count <4)
            data[79-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[79-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      7:begin
          if(count <4)
            data[85-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[85-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      8:begin
          if(count <4)
            data[91-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[91-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      9:begin
          if(count <4)
            data[97-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[97-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      10:begin
          if(count <4)
            data[106-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[106-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      11:begin
          if(count <4)
            data[112-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[112-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      12:begin
          if(count <4)
            data[118-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[118-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      13:begin
          if(count <4)
            data[124-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[124-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      14:begin
          if(count <4)
            data[130-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[130-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      15:begin
          if(count <4)
            data[139-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[139-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      16:begin
          if(count <4)
            data[145-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[145-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      17:begin
          if(count <4)
            data[151-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[151-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      18:begin
          if(count <4)
            data[157-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[157-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      19:begin
          if(count <4)
            data[163-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[163-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      20:begin
          if(count <4)
            data[172-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[172-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      21:begin
          if(count <4)
            data[178-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[178-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      22:begin
          if(count <4)
            data[184-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[184-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      23:begin
          if(count <4)
            data[190-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[190-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
      24:begin
          if(count <4)
            data[196-count]  <= ((outmat[i_reply][4*count+:4] > 9)? "7" : "0") + outmat[i_reply][4*count+:4];
          if(count ==4)
            data[196-count]  <= ((outmat[i_reply][4*count+:3] > 9)? "7" : "0") + outmat[i_reply][4*count+:3];
          count <= count+1;
      end
    endcase
  end
  else if(P == S_MAIN_WAIT && count ==5)begin
    i_reply <= i_reply + 1;
      count <= 0;
  end
end

always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

assign print_enable = (P == S_MAIN_WAIT && P_next == S_MAIN_REPLY);
assign print_done = (tx_byte == 8'h0);
assign transmit = (Q_next == S_UART_WAIT ||
                   print_enable);

assign tx_byte  = data[send_counter];

always @(posedge clk) begin
  if (~reset_n) send_counter <= 0;
  else if (P==S_MAIN_INIT) send_counter <= 0;
  else if(P==S_MAIN_REPLY)send_counter <= send_counter + (Q_next == S_UART_INCR);
end

// ------------------------------------------------------------------------
// ------------read Sramnum------------------------idk why 0 1 2 stay the same
//reg [7 : 0] ram [97:0];
//wire r_done;
assign r_done = (user_addr>=100);
always @(posedge clk) begin 
  if (~reset_n)
    user_addr <= 12'h000;
  else if (P == S_MAIN_INIT)
    user_addr <= 12'h000;
  else if (P == S_MAIN_READSRAM) begin
    if(user_addr >= 2)
      ram[user_addr-2] <= user_data;
    user_addr <= (user_addr < 100)? user_addr + 1 : user_addr;
  end
end

//-------------matrix read-----------------------it seens OK
//reg [7:0] A[48:0];
//reg [7:0] B[48:0];
//integer imatrix;
//wire read_matrix_done;
assign read_matrix_done = (imatrix>=98);
always @(posedge clk) begin
  if (~reset_n)
    imatrix <= 0;
  else if (P==S_MAIN_READMATRIX) begin
    if(imatrix<49) begin
      case(imatrix)
        0: A[0 ] <= ram[imatrix];
        1: A[7 ] <= ram[imatrix];
        2: A[14] <= ram[imatrix];
        3: A[21] <= ram[imatrix];
        4: A[28] <= ram[imatrix];
        5: A[35] <= ram[imatrix];
        6: A[42] <= ram[imatrix];
        7: A[1 ] <= ram[imatrix];
        8: A[8 ] <= ram[imatrix];
        9: A[15] <= ram[imatrix];
        10:A[22] <= ram[imatrix];
        11:A[29] <= ram[imatrix];
        12:A[36] <= ram[imatrix];
        13:A[43] <= ram[imatrix];
        14:A[2 ] <= ram[imatrix];
        15:A[9 ] <= ram[imatrix];
        16:A[16] <= ram[imatrix];
        17:A[23] <= ram[imatrix];
        18:A[30] <= ram[imatrix];
        19:A[37] <= ram[imatrix];
        20:A[44] <= ram[imatrix];
        21:A[3 ] <= ram[imatrix];
        22:A[10] <= ram[imatrix];
        23:A[17] <= ram[imatrix];
        24:A[24] <= ram[imatrix];
        25:A[31] <= ram[imatrix];
        26:A[38] <= ram[imatrix];
        27:A[45] <= ram[imatrix];
        28:A[4 ] <= ram[imatrix];
        29:A[11] <= ram[imatrix];
        30:A[18] <= ram[imatrix];
        31:A[25] <= ram[imatrix];
        32:A[32] <= ram[imatrix];
        33:A[39] <= ram[imatrix];
        34:A[46] <= ram[imatrix];
        35:A[5 ] <= ram[imatrix];
        36:A[12] <= ram[imatrix];
        37:A[19] <= ram[imatrix];
        38:A[26] <= ram[imatrix];
        39:A[33] <= ram[imatrix];
        40:A[40] <= ram[imatrix];
        41:A[47] <= ram[imatrix];
        42:A[6 ] <= ram[imatrix];
        43:A[13] <= ram[imatrix];
        44:A[20] <= ram[imatrix];
        45:A[27] <= ram[imatrix];
        46:A[34] <= ram[imatrix];
        47:A[41] <= ram[imatrix];
        48:A[48] <= ram[imatrix];
      endcase
      imatrix <= imatrix+1;
    end else if(imatrix>=49 && imatrix<98) begin
      case(imatrix-49)
        0: B[0 ] <= ram[imatrix];
        1: B[7 ] <= ram[imatrix];
        2: B[14] <= ram[imatrix];
        3: B[21] <= ram[imatrix];
        4: B[28] <= ram[imatrix];
        5: B[35] <= ram[imatrix];
        6: B[42] <= ram[imatrix];
        7: B[1 ] <= ram[imatrix];
        8: B[8 ] <= ram[imatrix];
        9: B[15] <= ram[imatrix];
        10:B[22] <= ram[imatrix];
        11:B[29] <= ram[imatrix];
        12:B[36] <= ram[imatrix];
        13:B[43] <= ram[imatrix];
        14:B[2 ] <= ram[imatrix];
        15:B[9 ] <= ram[imatrix];
        16:B[16] <= ram[imatrix];
        17:B[23] <= ram[imatrix];
        18:B[30] <= ram[imatrix];
        19:B[37] <= ram[imatrix];
        20:B[44] <= ram[imatrix];
        21:B[3 ] <= ram[imatrix];
        22:B[10] <= ram[imatrix];
        23:B[17] <= ram[imatrix];
        24:B[24] <= ram[imatrix];
        25:B[31] <= ram[imatrix];
        26:B[38] <= ram[imatrix];
        27:B[45] <= ram[imatrix];
        28:B[4 ] <= ram[imatrix];
        29:B[11] <= ram[imatrix];
        30:B[18] <= ram[imatrix];
        31:B[25] <= ram[imatrix];
        32:B[32] <= ram[imatrix];
        33:B[39] <= ram[imatrix];
        34:B[46] <= ram[imatrix];
        35:B[5 ] <= ram[imatrix];
        36:B[12] <= ram[imatrix];
        37:B[19] <= ram[imatrix];
        38:B[26] <= ram[imatrix];
        39:B[33] <= ram[imatrix];
        40:B[40] <= ram[imatrix];
        41:B[47] <= ram[imatrix];
        42:B[6 ] <= ram[imatrix];
        43:B[13] <= ram[imatrix];
        44:B[20] <= ram[imatrix];
        45:B[27] <= ram[imatrix];
        46:B[34] <= ram[imatrix];
        47:B[41] <= ram[imatrix];
        48:B[48] <= ram[imatrix];
      endcase
      imatrix <= imatrix+1;
    end
  end
end

//-----------------max pooling--------------------it seens OK
//reg [4:0]  ia,ib;
//reg [7:0] poolA[24:0];
//reg [7:0] poolB[24:0];
//wire maxpooling_done;
//reg [7:0] maxa,maxb;
 
assign maxpooling_done = (ia>=25 && ib>=25);
reg [3:0] i;
wire [3:0] iadiv5mul2;
assign iadiv5mul2 = (ia>=5)? ((ia>=10)?((ia>=15)?((ia>=20)?8:6):4):2): 0;
always @(posedge clk) begin
  if (~reset_n) begin
    ia <= 0;
  end
  else if (P==S_MAIN_INIT) begin
    ia <= 0;
    i <= 0;
  end
  else if (P==S_MAIN_MAXPOOLING && ia<25) begin
    if(i < 10)begin
      case(i)
        0:  maxa =  A[ia+   iadiv5mul2];
        1:  maxa = (A[ia+1+ iadiv5mul2]>maxa)? A[ia+1+ iadiv5mul2]: maxa;
        2:  maxa = (A[ia+2+ iadiv5mul2]>maxa)? A[ia+2+ iadiv5mul2]: maxa;
        3:  maxa = (A[ia+7+ iadiv5mul2]>maxa)? A[ia+7+ iadiv5mul2]: maxa;
        4:  maxa = (A[ia+8+ iadiv5mul2]>maxa)? A[ia+8+ iadiv5mul2]: maxa;
        5:  maxa = (A[ia+9+ iadiv5mul2]>maxa)? A[ia+9+ iadiv5mul2]: maxa;
        6:  maxa = (A[ia+14+iadiv5mul2]>maxa)? A[ia+14+iadiv5mul2]: maxa;
        7:  maxa = (A[ia+15+iadiv5mul2]>maxa)? A[ia+15+iadiv5mul2]: maxa;
        8:  maxa = (A[ia+16+iadiv5mul2]>maxa)? A[ia+16+iadiv5mul2]: maxa;
        9: poolA[ia] = maxa;
      endcase
      i=i+1;
    end else if(i ==10) begin
    ia = ia+1;
    i = 0;
    end
  end
end
reg [3:0] j;
wire [3:0] ibdiv5mul2;
assign ibdiv5mul2 = (ib>=5)? ((ib>=10)?((ib>=15)?((ib>=20)?8:6):4):2): 0;
always @(posedge clk) begin
  if (~reset_n) begin
    ib <= 0;
  end
  else if (P==S_MAIN_INIT) begin
    ib <= 0;
    j  <= 0;
  end
  else if (P==S_MAIN_MAXPOOLING && ib<25) begin
    if(j < 10) begin
      case(j)
        0: begin 
          if(ib==24) maxb =  B[32];//ib==24的時候初始化會變成B[0]
          else maxb =  B[ib+   ibdiv5mul2];
        end
        1:  maxb = (B[ib+1+ ibdiv5mul2]>maxb)? B[ib+1+ ibdiv5mul2]: maxb;
        2:  maxb = (B[ib+2+ ibdiv5mul2]>maxb)? B[ib+2+ ibdiv5mul2]: maxb;
        3:  maxb = (B[ib+7+ ibdiv5mul2]>maxb)? B[ib+7+ ibdiv5mul2]: maxb;
        4:  maxb = (B[ib+8+ ibdiv5mul2]>maxb)? B[ib+8+ ibdiv5mul2]: maxb;
        5:  maxb = (B[ib+9+ ibdiv5mul2]>maxb)? B[ib+9+ ibdiv5mul2]: maxb;
        6:  maxb = (B[ib+14+ibdiv5mul2]>maxb)? B[ib+14+ibdiv5mul2]: maxb;
        7:  maxb = (B[ib+15+ibdiv5mul2]>maxb)? B[ib+15+ibdiv5mul2]: maxb;
        8:  maxb = (B[ib+16+ibdiv5mul2]>maxb)? B[ib+16+ibdiv5mul2]: maxb;
        9: poolB[ib] = maxb;
      endcase
      j = j+1;
    end else if(j == 10) begin 
      ib = ib+1;
      j = 0;
    end
  end
end

//-----------------Matrix Multiplication----------------
//reg [25*19-1:0] outmat;
//reg [18:0] outmat[24:0];
//reg [4:0]  idxmul;
//wire mul_done;
assign mul_done = idxmul >=25;
wire [4:0] idxdiv5;
reg [4:0] idxmod5;
assign idxdiv5 = (idxmul>=5)? ((idxmul>=10)?((idxmul>=15)?((idxmul>=20)?4:3):2):1): 0;
reg [18:0] sum;
reg [2:0] cnt;
always @(posedge clk) begin
  if (~reset_n) begin
    idxmul <= 0;
    sum <= 19'b0;
    cnt <= 0;
    idxmod5 <= 0;
//    idxdiv5 <= 0;
  end
  else if (P==S_MAIN_INIT) begin
    idxmul <= 0;
    sum <= 19'b0;
    cnt <= 0;
    idxmod5 <= 0;
//    idxdiv5 <= 0;
  end
  else if (P==S_MAIN_MATRIXMUL && cnt<5  ) begin
    sum <= sum + poolA[cnt+5*idxdiv5]*poolB[cnt+5*idxmod5];
    cnt <= cnt +1;
  end
  else if (P==S_MAIN_MATRIXMUL && cnt==5 ) begin
    outmat[idxmul] <= sum;
    cnt <= 0;
    sum <= 0;
    idxmul <= idxmul +1;
    if(idxmod5 < 4)
      idxmod5 <= idxmod5 +1;
    else begin
      idxmod5 <= 0;
//      idxdiv5 <= idxdiv5 +1;
    end
  end
end

endmodule
