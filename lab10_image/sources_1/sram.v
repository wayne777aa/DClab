//
// This module show you how to infer an initialized SRAM block
// in your circuit using the standard Verilog code.  The initial
// values of the SRAM cells is defined in the text file "image.dat"
// Each line defines a cell value. The number of data in image.dat
// must match the size of the sram block exactly.

module sram
#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 16, RAM_SIZE = 65536)
 (input clk, input we, input en,
  input  [ADDR_WIDTH-1 : 0] addr,
  input  [ADDR_WIDTH-1 : 0] addr_background,
  input  [DATA_WIDTH-1 : 0] data_i,
  output reg [DATA_WIDTH-1 : 0] data_o,
  output reg [DATA_WIDTH-1 : 0] data_o_background
  );

// Declareation of the memory cells
(* ram_style = "block" *) reg [DATA_WIDTH-1 : 0] RAM [RAM_SIZE - 1:0];

integer idx;

// ------------------------------------
// SRAM cell initialization
// ------------------------------------
// Initialize the sram cells with the values defined in "image.dat."
initial begin
    $readmemh("images.mem", RAM);
end

// ------------------------------------
// SRAM read operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we) begin
    data_o <= data_i;
  end else begin
    data_o <= RAM[addr];
    data_o_background <= RAM[addr_background];
  end
end

// ------------------------------------
// SRAM write operation
// ------------------------------------
always@(posedge clk)
begin
  if (en & we) begin
    RAM[addr] <= data_i;
  end
end

endmodule
