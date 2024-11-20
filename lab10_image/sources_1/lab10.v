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

// declare SRAM control signals
wire [16:0] sram_addr;
wire [16:0] sram_addr_background;
wire [11:0] data_in;
wire [11:0] data_out;
wire [11:0] data_out_background;
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
reg  [17:0] pixel_addr;
reg  [17:0] pixel_addr_background;

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH1_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam FISH1_W      = 64; // Width of the fish.
localparam FISH1_H      = 32; // Height of the fish.
reg [17:0] fish1_addr[0:2];   // Address array for up to 8 fish images.
localparam FISH2_VPOS   = 100; // Vertical location of the fish in the sea image.
localparam FISH2_W      = 64; // Width of the fish.
localparam FISH2_H      = 32; // Height of the fish.
reg [17:0] fish2_addr[0:2];   // Address array for up to 8 fish images.

// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  fish1_addr[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
  fish1_addr[1] = VBUF_W*VBUF_H + FISH1_W*FISH1_H; /* Addr for fish image #2 */
  
  fish2_addr[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
  fish2_addr[1] = VBUF_W*VBUF_H + FISH2_W*FISH2_H; /* Addr for fish image #2 */
  
//  fish_addr3[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
//  fish_addr3[1] = VBUF_W*VBUF_H + FISH_W*FISH_H; /* Addr for fish image #2 */

//  fish_addr4[0] = VBUF_W*VBUF_H + 18'd0;         /* Addr for fish image #1 */
//  fish_addr4[1] = VBUF_W*VBUF_H + FISH_W*FISH_H; /* Addr for fish image #2 */
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
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H+FISH1_W*FISH1_H*2+FISH2_W*FISH2_H*2))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en), .data_i(data_in),
          .addr(sram_addr), .addr_background(sram_addr_background),
          .data_o(data_out), .data_o_background(data_out_background));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign sram_addr_background = pixel_addr_background;
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

                          
always @(posedge clk) begin
  if (~reset_n || fish1_clock[31:21] > VBUF_W + FISH1_W)
    fish1_clock <= 0;
  else
    fish1_clock <= fish1_clock + 1;
  
  if (~reset_n || fish2_clock[31:21] > VBUF_W + FISH2_W)
    fish2_clock <= 0;
  else
    fish2_clock <= fish2_clock + 2;
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

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
  end else if (fish1_region)
    pixel_addr <= fish1_addr[fish1_clock[23]] +
                  ((pixel_y>>1)-FISH1_VPOS)*FISH1_W +
                  ((pixel_x +(FISH1_W*2-1)-pos1)>>1);
  else if (!fish1_region && fish2_region)
    pixel_addr <= fish2_addr[fish2_clock[23]] +
                  ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                  ((pixel_x +(FISH2_W*2-1)-pos2)>>1);
  else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
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
    if(data_out != 12'h0f0)
      rgb_next = data_out; // RGB value at (pixel_x, pixel_y)
    else
      rgb_next = data_out_background;
end

// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
