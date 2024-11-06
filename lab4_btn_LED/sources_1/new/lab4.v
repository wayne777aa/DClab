`timescale 1ns / 1ps
//-----------------------debounce--------------------------
module debounce(
    input       clk,
    input       reset_n,
    input       btn,
    output reg  btn_out
);
reg [15:0] cnt;
reg cs,ns;
always@(posedge clk) begin  //state_register
    if(~reset_n) begin
        cnt<= 0;
        cs <= 0;
        ns <= 0;
    end
    else begin
        ns <= btn;          //avoid bouncing
        cs <= ns;
        if(ns == cs) begin
            if(cnt < 16'hffff)
                cnt <= cnt+1;
        end else 
            cnt <= 0;
        if(cnt == 16'hffff)
            btn_out <= cs;
    end
end
endmodule

//--------------------pwm--------------------
module PWM(
    input       clk,
    input       reset_n,
    input      [2:0] light,
    input      [3:0] gray,
    output reg [3:0] out
);
reg [26:0] cnt;

always@(posedge clk)begin
    if(~reset_n)
        cnt <=0;
    else if(cnt<1000000-1) //0.01s
        cnt <= cnt+1;
    else
        cnt <=0;
end

always@(posedge clk)begin
    if(light == 3'b100)begin
        out <= gray;
    end
    else if(light == 3'b011)begin //75%
        if(cnt<750000)
        out <= gray;
        else
        out <= 0;
    end
    else if(light == 3'b010)begin //50%
        if(cnt<500000)
        out <= gray;
        else
        out <= 0;
    end
    else if(light == 3'b001)begin //25%
        if(cnt<250000)
        out <= gray;
        else
        out <= 0;
    end
    else if(light == 3'b000)begin //5%
        if(cnt<50000)
        out <= gray;
        else
        out <= 0;
    end
    else
        out <= 0;
end
endmodule

//--------------------main------------------
module lab4(
  input  clk,            // System clock at 100 MHz
  input  reset_n,        // System reset signal, in negative logic
  input  [3:0] usr_btn,  // Four user pushbuttons
  output [3:0] usr_led   // Four yellow LEDs
);

reg [3:0] count; //binary counter 15~0
wire [3:0] gray;
reg [2:0] light; //4~0
wire [3:0] o_pwm;
assign usr_led = o_pwm; 
//用reg接led都不會過,wire才能過?
//------------------------debounce-------------------------
wire [3:0] btn_out;
reg flag;
debounce de0(.clk(clk), .reset_n(reset_n), .btn(usr_btn[0]), .btn_out(btn_out[0]));
debounce de1(.clk(clk), .reset_n(reset_n), .btn(usr_btn[1]), .btn_out(btn_out[1]));
debounce de2(.clk(clk), .reset_n(reset_n), .btn(usr_btn[2]), .btn_out(btn_out[2]));
debounce de3(.clk(clk), .reset_n(reset_n), .btn(usr_btn[3]), .btn_out(btn_out[3]));

//---------------------count and light----------------------
always@(posedge clk) begin
    if(~reset_n) begin
        count <= 0;
        light <= 4;
        flag <= 0;          //avoid repeating
    end 
    else begin
       if((btn_out[0] == 1) &&(count>0) && (flag == 0)) begin
            count <= count-1;
            flag <= 1;
       end
       if((btn_out[1] == 1) &&(count<15)&& (flag == 0)) begin
            count <= count+1;
            flag <= 1;
       end
       if((btn_out[2] == 1) &&(light<4) && (flag == 0)) begin
            light <= light+1;
            flag <= 1;
       end
       if((btn_out[3] == 1) &&(light>0) && (flag == 0)) begin
            light <= light-1;
            flag <= 1;
       end
       if(~(|btn_out)) flag <=0; //one time one btn
    end
end

//-----------binary to gray code----------------
assign gray = (count >>1) ^ (count);

//------------------PWM-------------------------
PWM pwm(.clk(clk), .reset_n(reset_n), .light(light), .gray(gray), .out(o_pwm));

endmodule