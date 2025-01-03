// Code your testbench here
// or browse Examples
class transaction;
  rand bit oper;
  bit [7:0] data_in;
  bit wr,rd;
  bit [7:0] data_out;
  bit full,empty;
  
  constraint oper_data{
    oper dist {0:/50 , 1:/50};
  }

endclass

class generator;
 
  transaction tr;
  mailbox #(transaction) mbx;
  event done;
  event next;
  int count;
  
  function new( mailbox #(transaction) mbx);
    tr=new(); 
    this.mbx=mbx; 
  endfunction
  
  task run();
    repeat (count) begin
      assert(tr.randomize) else $display("[GEN] : Randomization failed");
      mbx.put(tr);
      @(next);
    end
    -> done;
  endtask
  
endclass
  
class driver;
  transaction datac;
  mailbox #(transaction) mbx;
  virtual fifo_if vif;
   
  function new( mailbox #(transaction) mbx); 
    this.mbx=mbx;  
  endfunction
  
  task reset();
    vif.rst <=1'b1;
    vif.data_in <= 0;
    vif.wr <= 0;
    vif.rd <= 0;
    repeat (5) @(posedge vif.clk);
    vif.rst <=1'b0;  
    @(posedge vif.clk);
    $display("[DRV] : RESET DONE");
  endtask
  
  task write();
    forever begin
      @(posedge vif.clk);
      vif.rst <=1'b0;
      vif.wr <= 1;
      vif.rd <= 0;
      vif.data_in <= $random_range(0,15);
      @(posedge vif.clk);
      $display("[DRV] : DATA WRITE  data : %0d", vif.data_in);  
      vif.wr <= 0;
      @(posedge vif.clk);
    end
  endtask

  task read();
    forever begin
      @(posedge vif.clk);
      vif.rst <=1'b0;
      vif.wr <= 0;
      vif.rd <= 1;
      @(posedge vif.clk);
      $display("[DRV] : DATA READ");  
      vif.rd <= 0;
      @(posedge vif.clk);
    end
  endtask

  task run();
    forever begin
      mbx.get(datac);
      if(datac.oper==1'b1) begin
        write();
      end
      else read();
    end
  endtask

endclass

class monitor;
   transaction tr;
   mailbox #(transaction) mbx;
   virtual fifo_if vif;

  function new( mailbox #(transaction) mbx); 
    this.mbx=mbx;  
  endfunction
  
  task run();
   tr = new();
    forever begin
      repeat (2) @(posedge vif.clk);
     tr.wr = vif.wr;
     tr.rd = vif.rd;
     tr.data_in = vif.data_in;
     tr.full = vif.full;
     tr.empty = vif.empty; 
      @(posedge vif.clk);
      tr.data_out = vif.data_out;
    mbx.put(tr);
      $display("[MON] :Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
    end
  endtask
  
endclass
  
class scoreboard;
  transaction tr;
  mailbox #(transaction) mbx;
  bit [7:0] din[$];
  bit [7:0] temp;
  event next;
  
  function new(mailbox #(transaction) mbx); 
    this.mbx=mbx; 
  endfunction
  
  task run();
    forever begin
      mbx.get(tr);
        $display("[SCO] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
      if(tr.wr==1'b1) begin
        if (tr.full == 1'b0) begin
        din.push_front(tr.data_in);
        $display("[SCO] : DATA STORED IN QUEUE :%0d", tr.data_in);
        end
        else $display("[SCO] : FIFO is full");
        $display("-------------------------------------------------");
      end
      
      if (tr.rd==1'b1) begin
        if (tr.empty == 1'b0) begin
          temp = din.pop_back();
          if (temp == tr.data_out) $display("[SCO] : DATA MATCH");
          else $display("[SCO] : DATA MISMATCH");
        end
        else begin
          $display("[SCO] : FIFO is empty"); 
        end
        $display("-------------------------------------------------");
      end
      -> next;
    end
  endtask

endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event next;
  virtual fifo_if vif;
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) msmbx;
  
  function new(virtual fifo_if vif);
    gdmbx=new();
    msmbx=new();
    gen=new(gdmbx);
    drv=new(gdmbx);
    mon=new(msmbx);
    sco=new(msmbx);
    this.vif=vif;
    drv.vif=this.vif;
    mon.vif=this.vif;
    gen.next=next;
    sco.next=next;
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
  fifo_if vif();
  
  FIFO dut(vif.clk,vif.rst,vif.wr,vif.rd,vif.data_in,vif.full,vif.empty,vif.data_out);
  
  initial begin
    vif.clk <= 1'b0;
  end
    
 always #10 vif.clk=!vif.clk;
  
initial begin
  env=new(vif); 
  env.gen.count = 10;
  env.run();
end
  
initial begin
    $dumpfile("dump.vcd"); // Specify the VCD dump file
    $dumpvars; // Dump all variables
end

endmodule