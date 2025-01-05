// Code your design here
module spi_master(
  input clk,newd,rst,
  input [11:0] din,
  output reg cs,mosi,sclk 
);
  
  typedef enum bit [1:0] {IDLE=2'b00, ENABLE=2'b01, SEND=2'b10,COMP=2'b11} state_type;
state_type state = IDLE;
int countc=0;
int count=0;
reg [11:0] temp;
  
  always @(posedge clk) begin
    if(rst) begin
    countc <= 0;
    sclk <= 0;
    end
    else begin
      if(countc < 10) begin
      countc <= countc + 1;
      end
      else begin
      countc <= 0;
      sclk <= !sclk;
      end
    end
  end
    
  always @(posedge sclk) begin
    if (rst) begin
      cs <=1'b1;
      mosi <=1'b0;
    end
    else begin
      case(state)
        IDLE : begin
          if(newd) begin
            state <= SEND;
            temp <= din;
            cs <= 1'b0;
          end
            else begin
              state <= IDLE;
              temp <= 0;
            end
        end
        
        SEND : begin
          if(count <= 11) begin
            mosi <= temp[count];
            count <= count + 1;
          end
          else begin
            state <= IDLE;
            count <= 0;
            cs <= 1'b1;
            mosi <= 1'b0;
          end
        end 
        default: state <= IDLE;
      endcase      
    end
  end
  
endmodule

module spi_slave (
input sclk, cs, mosi,
output [11:0] dout,
output reg done
);
 
typedef enum bit {detect_start = 1'b0, read_data = 1'b1} state_type;
state_type state = detect_start;
 
reg [11:0] temp = 0;
int count = 0;
 
always@(posedge sclk)
begin
 
case(state)
detect_start: 
begin
done   <= 1'b0;
if(cs == 1'b0)
 state <= read_data;
 else
 state <= detect_start;
end
 
read_data : begin
if(count <= 11)
 begin
 count <= count + 1;
 temp  <= { mosi, temp[11:1]};
 end
 else
 begin
 count <= 0;
 done <= 1'b1;
 state <= detect_start;
 end
 
end
 
endcase
end
assign dout = temp;
 
endmodule

module top (
input clk, rst, newd,
input [11:0] din,
output [11:0] dout,
output done
);
 
wire sclk, cs, mosi;
 
spi_master m1 (clk, newd, rst, din, cs, mosi, sclk);
spi_slave s1  (sclk, cs, mosi, dout, done);
  
 
endmodule

interface spi_if;
  
  logic clk;
  logic newd;
  logic rst;
  logic sclk;
  logic [11:0] din;
  logic [11:0] dout;
  logic done;
   
endinterface