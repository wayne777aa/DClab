`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] fish1_clock;
wire [9:0]  pos1;
wire        fish1_region;

reg  [31:0] fish2_clock;
wire [9:0]  pos2;
wire        fish2_region;

reg  [31:0] fish3_clock;
wire [9:0]  pos3;
wire        fish3_region;

// declare SRAM control signals
wire [16:0] sram_addr_background;
wire [16:0] sram_addr1;
wire [16:0] sram_addr2;
wire [16:0] sram_addr3;
wire [11:0] data_in;
wire [11:0] data_out_background;
wire [11:0] data_out1;
wire [11:0] data_out2;
wire [11:0] data_out3;

wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr_background;
reg  [17:0] pixel_addr1;
reg  [17:0] pixel_addr2;
reg  [17:0] pixel_addr3;

reg st1;
reg st2;
reg st3;


// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH_W      = 64; // Width of the fish.
localparam FISH1_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam FISH1_H      = 32; // Height of the fish.
reg [17:0] fish1_addr[0:7];   // Address array for up to 8 fish images.
localparam FISH2_VPOS   = 100; // Vertical location of the fish in the sea image.
localparam FISH2_H      = 44; // Height of the fish.
reg [17:0] fish2_addr[0:7];   // Address array for up to 8 fish images.
localparam FISH3_VPOS   = 120; // Vertical location of the fish in the sea image.
localparam FISH3_H      = 72; // Height of the fish.
reg [17:0] fish3_addr[0:7];   // Address array for up to 8 fish images.
//--------------------
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  fish1_addr[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
  fish1_addr[1] = VBUF_W*VBUF_H + FISH_W*FISH1_H; /* Addr for fish image #2 */
  fish1_addr[2] = VBUF_W*VBUF_H + FISH_W*FISH1_H*2; /* Addr for fish image #3 */
  fish1_addr[3] = VBUF_W*VBUF_H + FISH_W*FISH1_H*3; /* Addr for fish image #4 */
  fish1_addr[4] = VBUF_W*VBUF_H + FISH_W*FISH1_H*4; /* Addr for fish image #5 */
  fish1_addr[5] = VBUF_W*VBUF_H + FISH_W*FISH1_H*5; /* Addr for fish image #6 */
  fish1_addr[6] = VBUF_W*VBUF_H + FISH_W*FISH1_H*6; /* Addr for fish image #7 */
  fish1_addr[7] = VBUF_W*VBUF_H + FISH_W*FISH1_H*7; /* Addr for fish image #8 */
  
  fish2_addr[0] = 18'd0;         /* Addr for fish image #1 */
  fish2_addr[1] = 18'd0 + FISH_W*FISH2_H; /* Addr for fish image #2 */
  fish2_addr[2] = 18'd0 + FISH_W*FISH2_H*2; /* Addr for fish image #3 */
  fish2_addr[3] = 18'd0 + FISH_W*FISH2_H*3; /* Addr for fish image #4 */
//  fish2_addr[4] = 18'd0 + FISH2_W*FISH2_H*4; /* Addr for fish image #5 */
//  fish2_addr[5] = 18'd0 + FISH2_W*FISH2_H*5; /* Addr for fish image #6 */
//  fish2_addr[6] = 18'd0 + FISH2_W*FISH2_H*6; /* Addr for fish image #7 */
//  fish2_addr[7] = 18'd0 + FISH2_W*FISH2_H*7; /* Addr for fish image #8 */

  fish3_addr[0] = 11264; /* Addr for fish image #2 */
  fish3_addr[1] = 11264 + FISH_W*FISH3_H; /* Addr for fish image #2 */
  fish3_addr[2] = 11264 + FISH_W*FISH3_H*2; /* Addr for fish image #2 */
  fish3_addr[3] = 11264 + FISH_W*FISH3_H*3; /* Addr for fish image #2 */
//  fish3_addr[4] = 11264 + FISH3_W*FISH3_H*4; /* Addr for fish image #2 */
//  fish3_addr[5] = 11264 + FISH3_W*FISH3_H*5; /* Addr for fish image #2 */
//  fish3_addr[6] = 11264 + FISH3_W*FISH3_H*6; /* Addr for fish image #2 */
//  fish3_addr[7] = 11264 + FISH3_W*FISH3_H*7; /* Addr for fish image #2 */
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H + FISH_W*FISH1_H*8), .FILE("images.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en), .data_i(data_in),
        .addr1(sram_addr1) , .addr2(sram_addr_background),
        .data_o1(data_out1), .data_o2(data_out_background));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH2_H*4 + FISH_W*FISH3_H*4), .FILE("images2.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en), .data_i(data_in),
        .addr1(sram_addr2) , .addr2(sram_addr3),
        .data_o1(data_out2), .data_o2(data_out3));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr_background = pixel_addr_background;
assign sram_addr1 = pixel_addr1;
assign sram_addr2 = pixel_addr2;
assign sram_addr3 = pixel_addr3;


assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
assign pos1 = fish1_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign pos2 = fish2_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign pos3 = fish3_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen

always @(posedge clk) begin
  if (~reset_n) begin
    fish1_clock <= 0;
    st1 <= 0;
  end else if(fish1_clock[31:21] >= VBUF_W && st1 == 0)
    st1 <= 1;
  else if(fish1_clock[31:21] <= FISH_W && st1 == 1)
    st1 <= 0;
  else if(st1 == 0)
    fish1_clock <= fish1_clock +1;
  else if(st1 == 1)
    fish1_clock <= fish1_clock -1;
  
  if (~reset_n) begin
    fish2_clock <= 0;
    st2 <= 0;
  end else if(fish2_clock[31:21] >= VBUF_W && st2 == 0)
    st2 <= 1;
  else if(fish2_clock[31:21] <= FISH_W && st2 == 1)
    st2 <= 0;
  else if(st2 == 0)
    fish2_clock <= fish2_clock +2;
  else if(st2 == 1)
    fish2_clock <= fish2_clock -2;
    
  if (~reset_n) begin
    fish3_clock <= VBUF_W + FISH_W;
    st3 <= 0;
  end else if(fish3_clock[31:21] <= FISH_W && st3 == 0)
    st3 <= 1;
  else if(fish3_clock[31:21] >= VBUF_W && st3 == 1)
    st3 <= 0;
  else if(st3 == 0)
    fish3_clock <= fish3_clock -3;
  else if(st3 == 1)
    fish3_clock <= fish3_clock +3;
end

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign fish1_region =
           pixel_y >= (FISH1_VPOS<<1) && pixel_y < (FISH1_VPOS+FISH1_H)<<1 &&
           (pixel_x + 127) >= pos1 && pixel_x < pos1 + 1;
assign fish2_region =
           pixel_y >= (FISH2_VPOS<<1) && pixel_y < (FISH2_VPOS+FISH2_H)<<1 &&
           (pixel_x + 127) >= pos2 && pixel_x < pos2 + 1;
assign fish3_region =
           pixel_y >= (FISH3_VPOS<<1) && pixel_y < (FISH3_VPOS+FISH3_H)<<1 &&
           (pixel_x + 127) >= pos3 && pixel_x < pos3 + 1;

always @ (posedge clk) begin
  if (fish1_region) begin
    if(st1 == 0)
      pixel_addr1 <= fish1_addr[fish1_clock[25:23]] +
                  ((pixel_y>>1)-FISH1_VPOS)*FISH_W +
                  ((pixel_x +(FISH_W*2-1)-pos1)>>1);
    else if(st1 == 1)
      pixel_addr1 <= fish1_addr[fish1_clock[25:23]] +
                  ((pixel_y>>1)-FISH1_VPOS)*FISH_W + 
                  FISH_W - ((pixel_x +(FISH_W*2-1)-pos1)>>1);
  end else
    pixel_addr1 <= fish1_addr[0];

  if (fish2_region) begin
    if(st2 == 0)
      pixel_addr2 <= fish2_addr[fish2_clock[24:23]] +
                  ((pixel_y>>1)-FISH2_VPOS)*FISH_W +
                  ((pixel_x +(FISH_W*2-1)-pos2)>>1);
    else if(st2 == 1)
      pixel_addr2 <= fish2_addr[fish2_clock[24:23]] +
                  ((pixel_y>>1)-FISH2_VPOS)*FISH_W +
                  FISH_W - ((pixel_x +(FISH_W*2-1)-pos2)>>1);
  end else
    pixel_addr2 <= fish2_addr[0];

  if (fish3_region) begin
    if(st3 == 0)
      pixel_addr3 <= fish3_addr[fish3_clock[24:23]] +
                  ((pixel_y>>1)-FISH3_VPOS)*FISH_W +
                  ((pixel_x +(FISH_W*2-1)-pos3)>>1);
    else if(st3 == 1)
      pixel_addr3 <= fish3_addr[fish3_clock[24:23]] +
                  ((pixel_y>>1)-FISH3_VPOS)*FISH_W +
                  FISH_W - ((pixel_x +(FISH_W*2-1)-pos3)>>1);
  end else
    pixel_addr3 <= fish3_addr[0];
end

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr_background <= 0;
  end else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr_background <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else
    if(data_out1 != 12'h0f0)
      rgb_next = data_out1; // RGB value at (pixel_x, pixel_y)
    else if(data_out2 != 12'h0f0)
      rgb_next = data_out2;
    else if(data_out3 != 12'h0f0)
      rgb_next = data_out3;
    else
      rgb_next = data_out_background;
end

// End of the video data display code.
// ------------------------------------------------------------------------



endmodule
