`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/05/08 15:29:41
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions:
// Description: The sample top module of lab 6: sd card reader. The behavior of
//              this module is as follows
//              1. When the SD card is initialized, display a message on the LCD.
//                 If the initialization fails, an error message will be shown.
//              2. The user can then press usr_btn[2] to trigger the sd card
//                 controller to read the super block of the sd card (located at
//                 block # 8192) into the SRAM memory.
//              3. During SD card reading time, the four LED lights will be turned on.
//                 They will be turned off when the reading is done.
//              4. The LCD will then displayer the sector just been read, and the
//                 first byte of the sector.
//              5. Everytime you press usr_btn[2], the next byte will be displayed.
// 
// Dependencies: clk_divider, LCD_module, debounce, sd_card
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab8(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // SD card specific I/O ports
  output spi_ss,
  output spi_sck,
  output spi_mosi,
  input  spi_miso,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D,
  
  // tri-state LED
  output [3:0] rgb_led_r,
  output [3:0] rgb_led_g,
  output [3:0] rgb_led_b
);

localparam [2:0] S_MAIN_INIT = 3'b000, S_MAIN_IDLE = 3'b001,
                 S_MAIN_WAIT = 3'b010, S_MAIN_FINDBEGIN = 3'b011,
                 S_MAIN_WAIT2 = 3'b100, S_MAIN_CALCULATE = 3'b101,
                 S_MAIN_SHOW = 3'b110;
localparam DELAY1 = 100_000000; // 1 sec
// Declare system variables
wire btn_level, btn_pressed;
reg  prev_btn_level;
reg  [5:0] send_counter;
reg  [2:0] P, P_next;
reg  [9:0] sd_counter;
reg  [7:0] data_byte;
reg  [31:0] blk_addr;

reg  [127:0] row_A = "SD card cannot  ";
reg  [127:0] row_B = "be initialized! ";
reg  done_flag; // Signals the completion of reading one SD sector.

reg [103:0] buffer;
reg [$clog2(DELAY1):0] counter1;

// Declare SD card interface signals
wire clk_sel;
wire clk_500k;
reg  rd_req;
reg  [31:0] rd_addr;
wire init_finished;
wire [7:0] sd_dout;
wire sd_valid;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

// Declare RGB
reg [3:0] r_out;
reg [3:0] g_out;
reg [3:0] b_out;
wire [3:0] r_PWM;
wire [3:0] g_PWM;
wire [3:0] b_PWM;

// Declare count
reg [3:0] R;
reg [3:0] G;
reg [3:0] B;
reg [3:0] P_count;
reg [3:0] Y;
reg [3:0] X;

assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller
assign usr_led = 4'h00;

clk_divider#(200) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(clk_500k)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level)
);

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

sd_card sd_card0(
  .cs(spi_ss),
  .sclk(spi_sck),
  .mosi(spi_mosi),
  .miso(spi_miso),

  .clk(clk_sel),
  .rst(~reset_n),
  .rd_req(rd_req),
  .block_addr(rd_addr),
  .init_finished(init_finished),
  .dout(sd_dout),
  .sd_valid(sd_valid)
);

sram ram0(
  .clk(clk),
  .we(sram_we),
  .en(sram_en),
  .addr(sram_addr),
  .data_i(data_in),
  .data_o(data_out)
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;

// ------------------------------------------------------------------------
// The following code sets the control signals of an SRAM memory block
// that is connected to the data output port of the SD controller.
// Once the read request is made to the SD controller, 512 bytes of data
// will be sequentially read into the SRAM memory block, one byte per
// clock cycle (as long as the sd_valid signal is high).
assign sram_we = sd_valid;          // Write data into SRAM when sd_valid is high.
assign sram_en = 1;                 // Always enable the SRAM block.
assign data_in = sd_dout;           // Input data always comes from the SD controller.
assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
// End of the SRAM memory block
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the SD card reader that reads the super block (512 bytes)
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // wait for SD card initialization
      if (init_finished == 1) P_next = S_MAIN_IDLE;
      else P_next = S_MAIN_INIT;
    S_MAIN_IDLE: // wait for button click
      if (btn_pressed == 1) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_IDLE;
    S_MAIN_WAIT: // issue a rd_req to the SD controller until it's ready
      P_next = S_MAIN_FINDBEGIN;
    S_MAIN_FINDBEGIN: // wait for the input data to enter the SRAM buffer
      if (buffer[103:32] == "DCL_START") P_next = S_MAIN_CALCULATE;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_FINDBEGIN;
    S_MAIN_WAIT2:
      P_next = S_MAIN_CALCULATE;
    S_MAIN_CALCULATE: 
      if (buffer[55:0] == "DCL_END") P_next = S_MAIN_SHOW;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT2;
      else P_next = S_MAIN_CALCULATE;
    S_MAIN_SHOW:
      if (btn_pressed == 1) P_next = S_MAIN_IDLE;
    default:
      P_next = S_MAIN_IDLE;
  endcase
end

// FSM output logic: controls the 'rd_req' and 'rd_addr' signals.
always @(*) begin
  rd_req = (P == S_MAIN_WAIT || P == S_MAIN_WAIT2);
  rd_addr = blk_addr;
end

always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_IDLE) blk_addr <= 32'h2000;
  else if(P == S_MAIN_WAIT || P == S_MAIN_WAIT2) blk_addr <= blk_addr+1; // In lab 6, change this line to scan all blocks

  if (~reset_n || P == S_MAIN_IDLE) buffer <= 104'd0;
  else if((P == S_MAIN_FINDBEGIN || P == S_MAIN_CALCULATE) && sd_valid) 
    buffer <= {buffer[95:0],data_byte};

  
end

// FSM output logic: controls the 'sd_counter' signal.
// SD card read address incrementer
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_WAIT || P == S_MAIN_WAIT2)
    sd_counter <= 0;
  else if (P == S_MAIN_FINDBEGIN && sd_valid )
    sd_counter <= sd_counter + 1;
  else if (P == S_MAIN_CALCULATE && counter1 == DELAY1 && sd_valid)
    sd_counter <= sd_counter + 1;
end

always @(posedge clk) begin
  if (P == S_MAIN_CALCULATE && counter1 < DELAY1 && sd_valid) counter1 <= counter1 + 1;
  else if (P == S_MAIN_CALCULATE && counter1 == DELAY1 && sd_valid) begin
    counter1 <= 0;
  end
  else begin 
    counter1 <= 0;
  end
end


// FSM ouput logic: Retrieves the content of sram[] for display
always @(posedge clk) begin
  if (~reset_n) data_byte <= 8'b0;
  else if (sram_en && (P == S_MAIN_FINDBEGIN || P == S_MAIN_CALCULATE) && sd_valid) data_byte <= data_out;
end
// End of the FSM of the SD card reader
// ------------------------------------------------------------------------
// RGB Display function
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_IDLE) begin
    r_out <= 4'd0;
    g_out <= 4'd0;
    b_out <= 4'd0;
  end else if (P == S_MAIN_CALCULATE) begin
    //-----r-------------------------------------------------------------------------------------------------------
    if(buffer[31:24] == "R" || buffer[31:24] == "r" 
    || buffer[31:24] == "P" || buffer[31:24] == "p" 
    || buffer[31:24] == "Y" || buffer[31:24] == "y") r_out[3] <= 1;
    else r_out[3] <= 0;
    
    if(buffer[23:16] == "R" || buffer[23:16] == "r" 
    || buffer[23:16] == "P" || buffer[23:16] == "p" 
    || buffer[23:16] == "Y" || buffer[23:16] == "y") r_out[2] <= 1;
    else r_out[2] <= 0;
    
    if(buffer[15: 8] == "R" || buffer[15: 8] == "r" 
    || buffer[15: 8] == "P" || buffer[15: 8] == "p" 
    || buffer[15: 8] == "Y" || buffer[15: 8] == "y") r_out[1] <= 1;
    else r_out[1] <= 0;
    
    if(buffer[ 7: 0] == "R" || buffer[ 7: 0] == "r" 
    || buffer[ 7: 0] == "P" || buffer[ 7: 0] == "p" 
    || buffer[ 7: 0] == "Y" || buffer[ 7: 0] == "y") r_out[0] <= 1;
    else r_out[0] <= 0;
    //-----g-------------------------------------------------------------------------------------------------------
    if(buffer[31:24] == "G" || buffer[31:24] == "g" 
    || buffer[31:24] == "Y" || buffer[31:24] == "y") g_out[3] <= 1;
    else g_out[3] <= 0;
    
    if(buffer[23:16] == "G" || buffer[23:16] == "g" 
    || buffer[23:16] == "Y" || buffer[23:16] == "y") g_out[2] <= 1;
    else g_out[2] <= 0;
    
    if(buffer[15: 8] == "G" || buffer[15: 8] == "g" 
    || buffer[15: 8] == "Y" || buffer[15: 8] == "y") g_out[1] <= 1;
    else g_out[1] <= 0;
    
    if(buffer[ 7: 0] == "G" || buffer[ 7: 0] == "g" 
    || buffer[ 7: 0] == "Y" || buffer[ 7: 0] == "y") g_out[0] <= 1;
    else g_out[0] <= 0;
    //-----b-------------------------------------------------------------------------------------------------------
    if(buffer[31:24] == "B" || buffer[31:24] == "b" 
    || buffer[31:24] == "P" || buffer[31:24] == "p") b_out[3] <= 1;
    else b_out[3] <= 0;
    
    if(buffer[23:16] == "B" || buffer[23:16] == "b" 
    || buffer[23:16] == "P" || buffer[23:16] == "p") b_out[2] <= 1;
    else b_out[2] <= 0;
    
    if(buffer[15: 8] == "B" || buffer[15: 8] == "b" 
    || buffer[15: 8] == "P" || buffer[15: 8] == "p") b_out[1] <= 1;
    else b_out[1] <= 0;
    
    if(buffer[ 7: 0] == "B" || buffer[ 7: 0] == "b" 
    || buffer[ 7: 0] == "P" || buffer[ 7: 0] == "p") b_out[0] <= 1;
    else b_out[0] <= 0;
  end
end

PWM R_PWM(
  .clk(clk),
  .light_in(r_out),
  .light_out(r_PWM)
);
PWM G_PWM(
  .clk(clk),
  .light_in(g_out),
  .light_out(g_PWM)
);
PWM B_PWM(
  .clk(clk),
  .light_in(b_out),
  .light_out(b_PWM)
);
assign rgb_led_r = r_PWM;
assign rgb_led_g = g_PWM;
assign rgb_led_b = b_PWM;
// End of the RGB Display function
// ------------------------------------------------------------------------
// count the number of color
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_IDLE) begin
    R <= 0;
    G <= 0;
    B <= 0;
    P_count <= 0;
    Y <= 0;
    X <= 0;
  end else if (P == S_MAIN_CALCULATE && counter1 == DELAY1 && sd_valid) begin
    if     (buffer[31:24] == "R" || buffer[31:24] == "r") R <= R+1;
    else if(buffer[31:24] == "G" || buffer[31:24] == "g") G <= G+1;
    else if(buffer[31:24] == "B" || buffer[31:24] == "b") B <= B+1;
    else if(buffer[31:24] == "P" || buffer[31:24] == "p") P_count <= P_count+1;
    else if(buffer[31:24] == "Y" || buffer[31:24] == "y") Y <= Y+1;
    else X <= X+1;
  end
end


// End of counting
// ------------------------------------------------------------------------
// LCD Display function.
always @(posedge clk) begin
  if (~reset_n) begin
    row_A = "SD card cannot  ";
    row_B = "be initialized! ";
  end else if (P == S_MAIN_FINDBEGIN) begin
    row_A <= "searching for   ";
    row_B <= "title           ";
  end else if (P == S_MAIN_CALCULATE) begin
    row_A <= "calculating...  ";
    row_B <= "                ";
  end else if (P == S_MAIN_SHOW) begin
    row_A <= "RGBPYX          ";
    row_B[127:120] <= ((R > 9)? "7" : "0") + R;
    row_B[119:112] <= ((G > 9)? "7" : "0") + G;
    row_B[111:104] <= ((B > 9)? "7" : "0") + B;
    row_B[103:96] <= ((P_count > 9)? "7" : "0") + P_count;
    row_B[95:88] <= ((Y > 9)? "7" : "0") + Y;
    row_B[87:80] <= ((X-4 > 9)? "7" : "0") + X-4;
    row_B[79:0] <= "          ";
  end else if (P == S_MAIN_IDLE) begin
    row_A <= "Hit BTN2 to read";
    row_B <= "the SD card ... ";
  end
end
// End of the LCD display function
// ------------------------------------------------------------------------

endmodule
