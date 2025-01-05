// Code your testbench here
// or browse Examples
class transaction;
  rand bit [11:0] din;
  bit newd;
  bit [11:0] dout; 

function transaction copy();
  copy = new();
  copy.din = this.din;
  copy.dout =this.dout;
  copy.newd = this.newd;
endfunction


endclass

class generator;
 
  transaction tr;
  mailbox #(transaction) mbx;
  event done;
  event sconext;
  int count=0;
  
  function new( mailbox #(transaction) mbx);
    tr=new(); 
    this.mbx=mbx;  
  endfunction
  
  task run();
    repeat (count) begin
      assert(tr.randomize) else $error("[GEN] : Randomization failed");
      mbx.put(tr.copy);
      $display("[GEN] : DIN = %0d",tr.din);
      @(sconext);
    end
    -> done;
  endtask
  
endclass
  
class driver;
  transaction tr;
  mailbox #(transaction) mbx;
  mailbox #(bit [11:0]) mbxds;
  virtual spi_if vif;
   
  function new( mailbox #(transaction) mbx, mailbox #(bit [11:0]) mbxds); 
    this.mbx=mbx; 
    this.mbxds=mbxds;
  endfunction
  
  task reset();
    vif.rst <=1'b1;
    vif.newd <=1'b0;
    vif.din <= 0;
    repeat (10) @(posedge vif.clk);
    vif.rst <=1'b0;  
    repeat (5) @(posedge vif.clk);
    $display("[DRV] : RESET DONE");
    $display("-----------------------------------------");
  endtask
  
  task run();
    forever begin
      mbx.get(tr);//creates another object tr for driver class separate from tr in generator class
      vif.newd <= 1'b1;
      vif.din <= tr.din;
      mbxds.put(tr.din);
      @(posedge vif.sclk); 
      vif.newd <= 1'b0;
      @(posedge vif.done);
      $display("[DRV] : DATA SENT TO DAC : %0d",tr.din);
      @(posedge vif.sclk);
    end
  endtask
  
endclass

class monitor;
   transaction tr;
  mailbox #(bit [11:0]) mbx;
   virtual spi_if vif;
   bit [11:0] srx;

  function new(mailbox #(bit [11:0]) mbx); 
  this.mbx=mbx;  
  endfunction
  
  task run();
    tr = new();
    forever begin
     @(posedge vif.sclk);
     @(posedge vif.done);
      tr.dout = vif.dout;
     @(posedge vif.sclk);
      $display("[MON] : DATA SENT : %0d", tr.dout);
      mbx.put(tr.dout);
    end
  endtask
  
endclass
  
class scoreboard;
  bit [11:0] ds;
  bit [11:0] ms;
  mailbox #(bit [11:0]) mbx;
  mailbox #(bit [11:0]) mbxds;
  event sconext;
  
    function new(mailbox #(bit [11:0]) mbx,mailbox #(bit [11:0]) mbxds); 
    this.mbx=mbx;
    this.mbxds=mbxds;  
  endfunction
  
  task run();
    forever begin
      mbx.get(ms);
      mbxds.get(ds);
      $display("[SCO] : DRV : %0d MON : %0d", ds, ms);
      if(ms == ds) $display("[SCO] DATA MATCHED");
      else $display("[SCO] DATA NOT MATCHED");
      $display("-------------------------------------------------");
      -> sconext;
    end
  endtask

endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event nextgd;
  event nextgs;
  virtual spi_if vif;
  mailbox #(transaction) gdmbx;
  mailbox #(bit [11:0]) dsmbx;
  mailbox #(bit [11:0]) msmbx;
  
  function new(virtual spi_if vif);
    gdmbx=new();
    dsmbx=new();
    msmbx=new();
    gen=new(gdmbx);
    drv=new(gdmbx,dsmbx);
    mon=new(msmbx);
    sco=new(msmbx,dsmbx);
    this.vif=vif;
    drv.vif=this.vif;
    mon.vif=this.vif;
    gen.sconext=nextgs;   
    sco.sconext=nextgs;
  endfunction

  task pretest();
    drv.reset();
  endtask

  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task posttest();
    wait(gen.done.triggered);
    $finish();
  endtask

  task run();
    pretest();
    test();
    posttest();
  endtask

endclass

module tb();
  environment env;
  spi_if vif();
  top dut(vif.clk,vif.rst,vif.newd,vif.din,vif.dout,vif.done);
  
  initial begin
    vif.clk <= 1'b0;
  end
    
 always #10 vif.clk=!vif.clk;
 assign vif.sclk = dut.sclk;
  
initial begin
  env=new(vif); 
  env.gen.count = 4;
  env.run();
end
  
initial begin
    $dumpfile("dump.vcd"); // Specify the VCD dump file
    $dumpvars; // Dump all variables
  end

endmodule