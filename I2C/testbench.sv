// Code your testbench here
// or browse Examples
class transaction;
  rand bit [7:0] din;
  rand bit op;
  rand bit [6:0] addr;
  bit newd;
  bit [7:0] dout;
  bit busy;
  bit done;
  bit ack_err;
  
  constraint data {din > 1 ; din < 20 ; addr > 1 ; addr <15;}
  constraint data_op {op dist {0:/50 , 1:/50};}
  
endclass

class generator;
 
  transaction tr;
  mailbox #(transaction) mbx;
  event done;
  event sconext;
  event drvnext;
  int count=0;
  
  function new( mailbox #(transaction) mbx);
    tr=new(); 
    this.mbx=mbx;  
  endfunction
  
  task run();
    repeat (count) begin
      assert(tr.randomize) else $error("[GEN] : Randomization failed");
      mbx.put(tr);
      $display("[GEN] : DIN = %0d , OP = %0b, ADDRESS = %0d",tr.din,tr.op,tr.addr);
      @(drvnext);
      @(sconext);      
    end
    -> done;
  endtask
  
endclass
  
class driver;
  virtual i2c_if vif;
  
  transaction tr;
  
  event drvnext;
  
  mailbox #(transaction) mbxgd;
 
  
  function new( mailbox #(transaction) mbxgd );
    this.mbxgd = mbxgd; 
  endfunction
  
  //////////////////Resetting System
  task reset();
    vif.rst <= 1'b1;
    vif.newd <= 1'b0;
    vif.op <= 1'b0;
    vif.din <= 0;
    vif.addr  <= 0;
    repeat(10) @(posedge vif.clk);
    vif.rst <= 1'b0;
    $display("[DRV] : RESET DONE"); 
    $display("---------------------------------"); 
  endtask
  
  task write();
    vif.rst <= 1'b0;
    vif.newd <= 1'b1;
    vif.op <= 1'b0;
    vif.din <= tr.din;
    vif.addr  <= tr.addr;//7'h12;//;
    repeat(5) @(posedge vif.clk);
    vif.newd <= 1'b0;
    @(posedge vif.done);
    $display("[DRV] : OP: WR, ADDR:%0d, DIN : %0d", tr.addr, tr.din);    
    vif.newd <= 1'b0;
    
 
  endtask
  
   task read();
    vif.rst <= 1'b0;
    vif.newd <= 1'b1;
    vif.op <= 1'b1;
    vif.din <= 0;
    vif.addr  <= tr.addr;//7'h12;//tr.addr;
    repeat(5) @(posedge vif.clk);
    
    vif.newd <= 1'b0;
     @(posedge vif.done);
    $display("[DRV] : OP: RD, ADDR:%0d, DOUT : %0d", tr.addr, vif.dout);    
  endtask
  
  
  task run();
    tr = new();
    forever begin
      
      mbxgd.get(tr);
      
     if(tr.op == 1'b0)
       write();
      else
       read();
      
      ->drvnext;
    end
  endtask
  

endclass

class monitor;
   transaction tr;
  mailbox #(transaction) mbx;
   virtual i2c_if vif;
  

  function new(mailbox #(transaction) mbx); 
  this.mbx=mbx;  
  endfunction
  
  task run();
    tr = new();
    forever begin
     @(posedge vif.done);
      tr.din = vif.din;
      tr.addr = vif.addr;
      tr.op = vif.op;
      tr.dout = vif.dout;
      repeat(5) @(posedge vif.clk);
      $display("[MON] op:%0d, addr: %0d, din : %0d, dout:%0d", tr.op, tr.addr, tr.din, tr.dout);
      mbx.put(tr);
    end
  endtask
  
endclass
  
class scoreboard;
  mailbox #(transaction) mbx;
  event sconext;
  bit [7:0] temp;  
  bit [7:0] mem[128] = '{default:0};
   transaction tr;
  
  
  function new(mailbox #(transaction) mbx); 
    this.mbx=mbx; 
    
    for(int i = 0; i < 128; i++)
     begin
     mem[i] <= i;
     end

  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
      temp = mem[tr.addr];
      if(tr.op == 1'b0)
                begin   
                  mem[tr.addr] = tr.din;
                  $display("[SCO]: DATA STORED -> ADDR : %0d DATA : %0d", tr.addr, tr.din);
                  $display("-----------------------------------------------");
                end
       else 
                begin
                 
                  if( (tr.dout == temp))
                    $display("[SCO] :DATA READ -> Data Matched exp: %0d rec:%0d",temp,tr.dout);
                 else
                    $display("[SCO] :DATA READ -> DATA MISMATCHED exp: %0d rec:%0d",temp,tr.dout);
                         
                $display("-----------------------------------------------");
               end
  ->sconext;
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
  virtual i2c_if vif;
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) msmbx;
  
  function new(virtual i2c_if vif);
    gdmbx=new();
    msmbx=new();
    gen=new(gdmbx);
    drv=new(gdmbx);
    mon=new(msmbx);
    sco=new(msmbx);
    this.vif=vif;
    drv.vif=this.vif;
    mon.vif=this.vif;
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;        
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
  i2c_if vif();
  
 i2c_top dut (vif.clk, vif.rst,  vif.newd, vif.op, vif.addr, vif.din, vif.dout, vif.busy, vif.ack_err, vif.done);
  
  initial begin
    vif.clk <= 1'b0;
  end
    
 always #5 vif.clk <=!vif.clk;
  
initial begin
  env=new(vif); 
  env.gen.count = 20;
  env.run();
end
  
initial begin
    $dumpfile("dump.vcd"); // Specify the VCD dump file
    $dumpvars; // Dump all variables
  end

endmodule