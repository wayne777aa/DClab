`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/10/10 16:10:38
// Design Name: UART I/O example for Arty
// Module Name: lab6
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz
// Tool Versions: 
// Description: 
// 
// The parameters for the UART controller are 9600 baudrate, 8-N-1-N
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module longdivision(
  input  clk,
  input  reset_n,
  input  [15:0] dividend,
  input  [15:0] divisor,
  input  [2:0]P,
  output reg [15:0] quo,
  output reg done
);

reg [31:0] tempA;
reg [31:0] tempB;
integer i;
always@(posedge clk)begin
  if (~reset_n) begin
    tempA <= 32'd0;
    tempB <= 32'd0;
    done <= 0;
  end
  else if (P == 0) begin  //S_MAIN_INIT = 0
    tempA <= 32'd0;
    tempB <= 32'd0;
    done <= 0;
  end 
  else if(P == 3) begin   //S_MAIN_ARITHMETIC = 3
      tempA = {16'h0000,dividend};//前面多16位來運算
      tempB = {divisor,16'h0000};//後面多16位來無視還沒算到的被除數
      for(i = 0;i<16;i=i+1) begin
        tempA = tempA << 1;
        if(tempA >= tempB) tempA = tempA - tempB +1; //後面+1是商
        else tempA = tempA;
      end
      quo = tempA[15:0];
      done = 1;
  end
end
/* //--------------沒有整除數字會錯----------------
reg [15:0] R;
integer i;
always@(posedge clk)begin
  if (~reset_n) begin
    quo <= 0;
    R <= 0;
    done <= 0;
  end
  else if (P == 0) begin  //S_MAIN_INIT = 0
    quo <= 0;
    R <= 0;
    done <= 0;
  end 
  else if(P == 3) begin
    for (i = 15; i >= 0; i=i-1) begin 
      R = R << 1; // left-shift R by 1 bit
      R[0] = dividend[i]; // R(0) is 0th bit of R,
      if (R >= divisor) begin
        R = R - divisor;
        quo[i] = 1;
      end
    end
    done = 1;
  end
end
*/
endmodule
//-----------------------------------------------
module lab6(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx
);

localparam [2:0] S_MAIN_INIT = 0, S_MAIN_PROMPT = 1,
                 S_MAIN_READ_NUM = 2, S_MAIN_ARITHMETIC = 3, S_MAIN_REPLY = 4;
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz
localparam PROMPT_STR = 0;  // starting index of the prompt message
localparam PROMPT_LEN = 35; // length of the prompt message
localparam PROMPT_STR2 = 35;
localparam PROMPT_LEN2 = 36;
localparam REPLY_STR  = 71; // starting index of the hello message
localparam REPLY_LEN  = 37; // length of the hello message
localparam ERROR_STR  = 108;
localparam ERROR_LEN  = 27;
localparam MEM_SIZE   = PROMPT_LEN+PROMPT_LEN2+REPLY_LEN+ERROR_LEN;

// declare system variables
wire enter_pressed;
wire print_enable, print_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [2:0] P, P_next;
reg [1:0] Q, Q_next;
reg [$clog2(INIT_DELAY):0] init_counter;
reg [7:0] data[0:MEM_SIZE-1];
reg  [0:PROMPT_LEN*8-1] msg1 = { "\015\012Enter the first decimal number: ", 8'h00 }; //8'h00是用來確認輸出完這段
reg  [0:PROMPT_LEN2*8-1] msg1_2 = { "\015\012Enter the second decimal number: ", 8'h00 }; 
reg  [0:REPLY_LEN*8-1]  msg2 = { "\015\012The integer quotient is: 0x0000.\015\012", 8'h00 };
reg  [0:ERROR_LEN*8-1] errormsg = {"\015\012ERROR! DIVIDE BY ZERO!\015\012", 8'h00};
reg  [15:0] num_reg;  // The key-in number register
reg  [15:0] num_reg2; //second number
reg  [2:0]  key_cnt;  // The key strokes counter
wire  flag; //0輸入第一個數 1輸入第二個數
assign flag = (send_counter>=REPLY_STR-1);//輸出完msg1_2
wire done; //除法器做完

// declare UART signals
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

/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
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

// Initializes some strings.
// System Verilog has an easier way to initialize an array,
// but we are using Verilog 2001 :(
//
integer idx;
wire  [15:0] Quo;
always @(posedge clk) begin
  if (~reset_n) begin
    for (idx = 0; idx < PROMPT_LEN; idx = idx + 1) data[idx] = msg1[idx*8 +: 8];
    for (idx = 0; idx < PROMPT_LEN2; idx = idx + 1) data[idx+PROMPT_LEN] = msg1_2[idx*8 +: 8];
    for (idx = 0; idx < REPLY_LEN; idx = idx + 1) data[idx+PROMPT_LEN+PROMPT_LEN2] = msg2[idx*8 +: 8];
    for (idx = 0; idx < ERROR_LEN; idx = idx + 1) data[idx+PROMPT_LEN+PROMPT_LEN2+REPLY_LEN] = errormsg[idx*8 +: 8];
  end
  else if (P == S_MAIN_REPLY) begin
    data[REPLY_STR+29] <= ((Quo[15:12] > 9)? "7" : "0") + Quo[15:12]; //'7' = 55 'A' = 55+10 = 65
    data[REPLY_STR+30] <= ((Quo[11: 8] > 9)? "7" : "0") + Quo[11: 8];
    data[REPLY_STR+31] <= ((Quo[ 7: 4] > 9)? "7" : "0") + Quo[ 7: 4];
    data[REPLY_STR+32] <= ((Quo[ 3: 0] > 9)? "7" : "0") + Quo[ 3: 0];
  end
end

// Combinational I/O logics of the top-level system
assign usr_led = usr_btn;
assign enter_pressed = (rx_temp == 8'h0D); // don't use rx_byte here!

// ------------------------------------------------------------------------
// Main FSM that reads the UART input and triggers
// the output of the string "Hello, World!".
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Wait for initial delay of the circuit.
	   if (init_counter < INIT_DELAY) P_next = S_MAIN_INIT; //等初始化
		else P_next = S_MAIN_PROMPT; //初始化完
    S_MAIN_PROMPT: // Print the prompt message.
      if (print_done) P_next = S_MAIN_READ_NUM;
      else P_next = S_MAIN_PROMPT;
    S_MAIN_READ_NUM: // wait for <Enter> key.
      if (enter_pressed && flag) P_next = S_MAIN_ARITHMETIC; //如果是第二次就跑到運算的階段
      else if (enter_pressed && ~flag) begin //回上一個階段 輸出msg1_2
        P_next = S_MAIN_PROMPT;
      end
      else P_next = S_MAIN_READ_NUM;
    S_MAIN_ARITHMETIC:
      if(done) P_next = S_MAIN_REPLY;
      else P_next = S_MAIN_ARITHMETIC;
    S_MAIN_REPLY: // Print the hello message.
      if (print_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_REPLY;
  endcase
end

// FSM output logics: print string control signals.
assign print_enable = (P != S_MAIN_PROMPT && P_next == S_MAIN_PROMPT) ||
                  (P == S_MAIN_ARITHMETIC && P_next == S_MAIN_REPLY); //把READ_NUM改成ARITHMETIC
assign print_done = (tx_byte == 8'h0);

// Initialization counter. //拖時間用 往下個階段
always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end

// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the controller that sends a string to the UART.
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

// FSM output logics: UART transmission control signals
assign transmit = (Q_next == S_UART_WAIT ||
                  (P == S_MAIN_READ_NUM && received) ||
                   print_enable);
assign is_num_key = (rx_byte > 8'h2F) && (rx_byte < 8'h3A) && (key_cnt < 5);
assign echo_key = (is_num_key || rx_byte == 8'h0D)? rx_byte : 0; //用來重複輸入
assign tx_byte  = ((P == S_MAIN_READ_NUM) && received)? echo_key : data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  case (P_next)
    S_MAIN_INIT: send_counter <= PROMPT_STR;
    S_MAIN_READ_NUM: begin
                       if(flag) begin
                         if(num_reg2 == 0) send_counter <= ERROR_STR;
                         else send_counter <= REPLY_STR;
                       end
                       else  send_counter <= PROMPT_STR2; //flag == 0
                     end
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
  endcase
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// UART input logic
// Decimal number input will be saved in num1 or num2.
always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_INIT || P == S_MAIN_PROMPT)) key_cnt <= 0;
  else if (received && is_num_key) key_cnt <= key_cnt + 1;
end

always @(posedge clk)begin
  if (~reset_n) begin
    num_reg  <= 0;
    num_reg2 <= 0;
  end
  else if (P == S_MAIN_INIT) begin 
    num_reg  <= 0;
    num_reg2 <= 0;
  end
  else if (~flag && received && is_num_key) num_reg  <= (num_reg * 10) + (rx_byte - 48); //'0' = 48(ASCII)
  else if (flag && received && is_num_key) num_reg2 <= (num_reg2* 10) + (rx_byte - 48);
end

// The following logic stores the UART input in a temporary buffer.
// The input character will stay in the buffer for one clock cycle.
always @(posedge clk) begin
  rx_temp <= (received)? rx_byte : 8'h0;
end
// End of the UART input logic
// ------------------------------------------------------------------------
//-----------------long divison----------------
longdivision diviosion(
  .clk(clk),
  .reset_n(reset_n),
  .dividend(num_reg),
  .divisor(num_reg2),
  .P(P),
  .quo(Quo),
  .done(done)
);
endmodule
