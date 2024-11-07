module PWM(
    input       clk,
    input      [3:0] light_in,
    output reg [3:0] light_out
);
localparam DELAY1 = 1000000;
reg [$clog2(DELAY1):0] cnt;

always@(posedge clk)begin
  if(cnt<DELAY1) //0.01s
    cnt <= cnt+1;
  else
    cnt <=0;
end

always@(posedge clk)begin
  if(cnt<50000) //5%
    light_out <= light_in;
  else
    light_out <= 0;
end
endmodule