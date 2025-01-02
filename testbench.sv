// Code your testbench here
// or browse Examples
class transaction;
  rand bit din;
  bit dout;

function transaction copy();
  copy = new();
  copy.din = this.din;
  copy.dout =this.dout;
endfunction

function void display(input string tag);
  $display("[%0s] : din = %0b & dout = %0b",tag,din,dout);
endfunction

endclass

class generator;
 
  transaction tr;
  mailbox #(transaction) mbx;
  mailbox #(transaction) mbxref;
  event done;
  event sconext;
  int count;
  
  function new( mailbox #(transaction) mbx,mailbox #(transaction) mbxref);
    tr=new(); 
    this.mbx=mbx;
    this.mbxref=mbxref;  
  endfunction
  
  task run();
    repeat (count) begin
      assert(tr.randomize) else $display("[GEN] : Randomization failed");
      mbx.put(tr.copy);
      mbxref.put(tr.copy);
      @(sconext);
    end
    -> done;
  endtask
  
endclass
  
class driver;
  transaction tr;
  mailbox #(transaction) mbx;
  virtual dff_if vif;
   
  function new( mailbox #(transaction) mbx); 
    this.mbx=mbx;  
  endfunction
  
  task reset();
    vif.rst <=1'b1;
    repeat (5) @(posedge vif.clk);
    vif.rst <=1'b0;  
    @(posedge vif.clk);
    $display("[DRV] : RESET DONE");
  endtask
  
  task run();
    forever begin
      mbx.get(tr);//creates another object tr for driver class separate from tr in generator class
    vif.din <= tr.din;
    @(posedge vif.clk);
    tr.display("DRV");  
    vif.din <=1'b0;
      @(posedge vif.clk);
    end
  endtask
endclass

class monitor;
   transaction tr;
   mailbox #(transaction) mbx;
   virtual dff_if vif;

  function new( mailbox #(transaction) mbx); 
    this.mbx=mbx;  
  endfunction
  
  task run();
   tr = new();
    forever begin
      repeat (2) @(posedge vif.clk);
     tr.dout = vif.dout;
    mbx.put(tr);
    tr.display("MON");
    end
  endtask
  
endclass
  
class scoreboard;
 transaction tr;
  transaction trref;
  mailbox #(transaction) mbx;
  mailbox #(transaction) mbxref;
  event sconext;
  
  function new(mailbox #(transaction) mbx,mailbox #(transaction) mbxref); 
    this.mbx=mbx;
    this.mbxref=mbxref;  
  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
      mbxref.get(trref);
      tr.display("SCO");
      trref.display("REF");
      if(tr.dout == trref.din) $display("DATA MATCHED");
      else $display("DATA NOT MATCHED");
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
  event next;
  virtual dff_if vif;
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) gsmbx;
  mailbox #(transaction) msmbx;
  
  function new(virtual dff_if vif);
    gdmbx=new();
    gsmbx=new();
    msmbx=new();
    gen=new(gdmbx,gsmbx);
    drv=new(gdmbx);
    mon=new(msmbx);
    sco=new(msmbx,gsmbx);
    this.vif=vif;
    drv.vif=this.vif;
    mon.vif=this.vif;
    gen.sconext=next;
    sco.sconext=next;
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
  dff_if vif();
  
  dff dut(vif);
  
  initial begin
    vif.clk <= 1'b0;
  end
    
 always #10 vif.clk=!vif.clk;
  
initial begin
  env=new(vif); 
  env.gen.count = 30;
  env.run();
end
  
initial begin
    $dumpfile("dump.vcd"); // Specify the VCD dump file
    $dumpvars; // Dump all variables
  end

endmodule