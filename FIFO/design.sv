// Code your design here
module FIFO(
  input clk,rst,wr,rd,
  input [7:0] din,
  output full,empty,
  output reg [7:0] dout
);

  reg [3:0] rptr=0,wptr=0;
  reg [7:0] mem [15:0];
  reg [4:0] cnt=0;

  always_ff @(posedge clk) begin
    if(rst) begin
      wptr <= 0;
      rptr <= 0;
      cnt <= 0;    
    end
    else begin
      if(wr && !full) begin
        mem[wptr] <= din;
        cnt <= cnt + 1;
        wptr <= wptr + 1;
      end
      else if(rd && !empty) begin
        dout <= mem[rptr];
        rptr <= rptr + 1;
        cnt <= cnt - 1;
      end
    end
  end
endmodule
  
  interface fifo_if;
    logic clk,rd,wr,rst,full,empty;
    logic [7:0] data_in,data_out;
  endinterface