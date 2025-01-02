// Code your design here
module dff(dff_if vif);
  always_ff @(posedge vif.clk) begin
    if(vif.rst) vif.dout <= 0;
    else vif.dout <= vif.din;
  end
endmodule


interface dff_if;
  logic clk;
  logic rst;
  logic din;
  logic dout;
endinterface