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
                 S_MAIN_WAIT = 3'b010, S_MAIN_FINDBEGIN = 3'b011,S_MAIN_READ = 3'b100,
                 S_MAIN_WAIT2 = 3'b101, S_MAIN_CALCULATE = 3'b110,
                 S_MAIN_SHOW = 3'b111;
localparam DELAY1 = 100_000000;
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

reg [103:0] buffer; //找begin end
reg [55:0] sector; //答案區間
reg [$clog2(DELAY1):0] counter; //delay 1s
reg [2:0] cnt; //數4次

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
reg [3:0] R_count;
reg [3:0] G_count;
reg [3:0] B_count;
reg [3:0] P_count;
reg [3:0] Y_count;
reg [3:0] X_count;

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
//只有P == read的時候才改sram
assign sram_we = (P == S_MAIN_READ)? sd_valid : 0;          // Write data into SRAM when sd_valid is high.
assign sram_en = 1;                 // Always enable the SRAM block.
assign data_in = sd_dout;           // Input data always comes from the SD controller.
assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
// End of the SRAM memory block
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the SD card reader that reads the super block (512 bytes)
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
    S_MAIN_INIT: // wait for SD card initialization
      if (init_finished == 1) P_next = S_MAIN_IDLE;
      else P_next = S_MAIN_INIT;
    S_MAIN_IDLE: // wait for button click
      if (btn_pressed == 1) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_IDLE;
    S_MAIN_WAIT: // issue a rd_req to the SD controller until it's ready
      P_next = S_MAIN_FINDBEGIN;
    S_MAIN_FINDBEGIN: //find begin
      if (buffer[71:0] == "DCL_START") P_next = S_MAIN_READ;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_FINDBEGIN;
    S_MAIN_READ:      //find end & write sram
      if(buffer[55:0] == "DCL_END") P_next = S_MAIN_CALCULATE;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT2;
      else P_next = S_MAIN_READ;
    S_MAIN_WAIT2: // issue a rd_req to the SD controller until it's ready
      P_next = S_MAIN_READ;
    S_MAIN_CALCULATE: //answer
      if (sector[55:0] == "DCL_END") P_next = S_MAIN_SHOW;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT2;
      else P_next = S_MAIN_CALCULATE;
    S_MAIN_SHOW: //show the number of color
      if (btn_pressed == 1) P_next = S_MAIN_IDLE;
      else P_next = S_MAIN_SHOW;    
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
  else if(P == S_MAIN_WAIT || P == S_MAIN_WAIT2) blk_addr <= blk_addr+1;
  else blk_addr <= blk_addr; // In lab 6, change this line to scan all blocks
  
  if (~reset_n || P == S_MAIN_IDLE) begin
    buffer <= 104'd0;
    sector <= 56'd0;
  end else if(P == S_MAIN_FINDBEGIN && sd_valid)
    buffer <= {buffer[95:0],sd_dout};
  else if(P == S_MAIN_READ && sd_valid) 
    buffer <= {buffer[95:0],sd_dout};
  else if(P == S_MAIN_CALCULATE && counter == 0)
    sector <= {sector[47:0],data_byte};
end

// FSM output logic: controls the 'sd_counter' signal.
// SD card read address incrementer
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_WAIT || P == S_MAIN_WAIT2 
  || (P == S_MAIN_FINDBEGIN && P_next == S_MAIN_READ) //found begin
  || (P==S_MAIN_READ && P_next == S_MAIN_CALCULATE))  //found end
    sd_counter <= 0;
  else if ((P == S_MAIN_FINDBEGIN || P == S_MAIN_READ) && sd_valid )//sd_counter
    sd_counter <= sd_counter + 1;
  else if (P == S_MAIN_CALCULATE && counter == DELAY1 )//sram address
    sd_counter <= sd_counter + 1;
end

always @(posedge clk) begin
  if (P == S_MAIN_CALCULATE && counter < DELAY1) counter <= counter + 1;
  else if (P == S_MAIN_CALCULATE && counter == DELAY1) begin
    counter <= 0;
    cnt <= cnt + (cnt < 4);//先讀四次才開始亮燈
  end
  else begin 
    counter <= 0;
    cnt <= 0;
  end
end


// FSM ouput logic: Retrieves the content of sram[] for display
always @(posedge clk) begin
  if (~reset_n) data_byte <= 8'b0;
  else if (sram_en && P == S_MAIN_CALCULATE) data_byte <= data_out;
end
// End of the FSM of the SD card reader
// ------------------------------------------------------------------------
// RGB Display function
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_IDLE) begin
    r_out <= 4'b0000;
    g_out <= 4'b0000;
    b_out <= 4'b0000;
  end else if (P == S_MAIN_CALCULATE && cnt == 4) begin
    //Red-------------------------------------------------------------------------------------------------------
    if(sector[31:24] == "R" || sector[31:24] == "r" 
    || sector[31:24] == "P" || sector[31:24] == "p" 
    || sector[31:24] == "Y" || sector[31:24] == "y") r_out[3] <= 1;
    else r_out[3] <= 0;
    
    if(sector[23:16] == "R" || sector[23:16] == "r" 
    || sector[23:16] == "P" || sector[23:16] == "p" 
    || sector[23:16] == "Y" || sector[23:16] == "y") r_out[2] <= 1;
    else r_out[2] <= 0;
    
    if(sector[15: 8] == "R" || sector[15: 8] == "r" 
    || sector[15: 8] == "P" || sector[15: 8] == "p" 
    || sector[15: 8] == "Y" || sector[15: 8] == "y") r_out[1] <= 1;
    else r_out[1] <= 0;
    
    if(sector[ 7: 0] == "R" || sector[ 7: 0] == "r" 
    || sector[ 7: 0] == "P" || sector[ 7: 0] == "p" 
    || sector[ 7: 0] == "Y" || sector[ 7: 0] == "y") r_out[0] <= 1;
    else r_out[0] <= 0;
    
    //Green-------------------------------------------------------------------------------------------------------
    if(sector[31:24] == "G" || sector[31:24] == "g" 
    || sector[31:24] == "Y" || sector[31:24] == "y") g_out[3] <= 1;
    else g_out[3] <= 0;
    
    if(sector[23:16] == "G" || sector[23:16] == "g" 
    || sector[23:16] == "Y" || sector[23:16] == "y") g_out[2] <= 1;
    else g_out[2] <= 0;
    
    if(sector[15: 8] == "G" || sector[15: 8] == "g" 
    || sector[15: 8] == "Y" || sector[15: 8] == "y") g_out[1] <= 1;
    else g_out[1] <= 0;
    
    if(sector[ 7: 0] == "G" || sector[ 7: 0] == "g" 
    || sector[ 7: 0] == "Y" || sector[ 7: 0] == "y") g_out[0] <= 1;
    else g_out[0] <= 0;
    
    //Blue-------------------------------------------------------------------------------------------------------
    if(sector[31:24] == "B" || sector[31:24] == "b" 
    || sector[31:24] == "P" || sector[31:24] == "p") b_out[3] <= 1;
    else b_out[3] <= 0;
    
    if(sector[23:16] == "B" || sector[23:16] == "b" 
    || sector[23:16] == "P" || sector[23:16] == "p") b_out[2] <= 1;
    else b_out[2] <= 0;
    
    if(sector[15: 8] == "B" || sector[15: 8] == "b" 
    || sector[15: 8] == "P" || sector[15: 8] == "p") b_out[1] <= 1;
    else b_out[1] <= 0;
    
    if(sector[ 7: 0] == "B" || sector[ 7: 0] == "b" 
    || sector[ 7: 0] == "P" || sector[ 7: 0] == "p") b_out[0] <= 1;
    else b_out[0] <= 0;
  end
end
//PWM
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
// Count color
always @(posedge clk) begin
  if (~reset_n || P == S_MAIN_IDLE) begin
    R_count <= 0;
    G_count <= 0;
    B_count <= 0;
    P_count <= 0;
    Y_count <= 0;
    X_count <= 0;
  end else if (P == S_MAIN_CALCULATE && counter == DELAY1) begin
    if     (sector[7:0] == "R" || sector[7:0] == "r") R_count <= R_count+1;
    else if(sector[7:0] == "G" || sector[7:0] == "g") G_count <= G_count+1;
    else if(sector[7:0] == "B" || sector[7:0] == "b") B_count <= B_count+1;
    else if(sector[7:0] == "P" || sector[7:0] == "p") P_count <= P_count+1;
    else if(sector[7:0] == "Y" || sector[7:0] == "y") Y_count <= Y_count+1;
    else X_count <= X_count+1;
  end
end
// End of Count color
// ------------------------------------------------------------------------
// LCD Display function.
always @(posedge clk) begin
  if (~reset_n) begin
    row_A = "SD card cannot  ";
    row_B = "be initialized! ";
  end else if (P == S_MAIN_FINDBEGIN) begin
    row_A <= "searching for   ";
    row_B <= "title           ";
  end else if (P == S_MAIN_CALCULATE && cnt == 4) begin
    row_A <= "calculating...  ";
    row_B <= "                ";
//    row_B <= {"         ",sector[55:0]};//show sector
  end else if (P == S_MAIN_SHOW) begin
    row_A <= "RGBPYX          ";
    row_B[127:120] <= ((R_count > 9)? "7" : "0") + R_count;
    row_B[119:112] <= ((G_count > 9)? "7" : "0") + G_count;
    row_B[111:104] <= ((B_count > 9)? "7" : "0") + B_count;
    row_B[103: 96] <= ((P_count > 9)? "7" : "0") + P_count;
    row_B[ 95: 88] <= ((Y_count > 9)? "7" : "0") + Y_count;
    row_B[ 87: 80] <= ((X_count-7 > 9)? "7" : "0") + X_count-7;
    row_B[79:0] <= "          ";
  end else if (P == S_MAIN_IDLE) begin
    row_A <= "Hit BTN2 to read";
    row_B <= "the SD card ... ";
  end
end
// End of the LCD display function
// ------------------------------------------------------------------------
endmodule
