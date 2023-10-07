// Code your testbench here
// or browse Examples
class transaction;
 
  randc bit [1:0] opmode; /// write = 0, read = 1, //NOT USED: random =2
  rand bit we;
  rand bit strb;
  rand bit [7:0] addr;
  rand bit [7:0] wdata;
  bit [7:0] rdata;
  bit ack;

  constraint opmode_c {
    opmode inside {[0:1]};
  }

    constraint wdata_c {
       wdata > 0; 
   }

   function transaction copy();
        copy        = new();
        copy.opmode = this.opmode;
        copy.we     = this.we;
        copy.strb   = this.strb;
        copy.addr   = this.addr;
        copy.wdata  = this.wdata;
        copy.rdata  = this.rdata;
        copy.ack    = this.ack;
   endfunction

   function void display(input string tag);
     $display("[%0s] : MODE  :%0d",tag,opmode);
        $display("[%0s] : WE    :%0d",tag,we);
        $display("[%0s] : STRB  :%0d",tag,strb);
        $display("[%0s] : ADDR  :%0d",tag,addr);
        $display("[%0s] : WDATA :%0d",tag,wdata);
        $display("[%0s] : RDATA :%0d",tag,rdata);
   endfunction
endclass

class generator;

    transaction tr;
    mailbox #(transaction) mbx_gen_drv;

    event gen_done; //  generator done sending req transaction
    event drv_next; //  driver asking for next , done with curr exec
    event sco_next;  

    function new(mailbox #(transaction) mbx_gen_drv);
        this.mbx_gen_drv = mbx_gen_drv;
        tr = new();
    endfunction

    task run();
        repeat (10) begin
            assert(tr.randomize) ;
            tr.display("GENERATOR");
            mbx_gen_drv.put(tr.copy);
            @(drv_next);  //blocking wait for drv_next event
            @(sco_next);
        end

        ->gen_done; //blocking trigger done from generator packet sending
    endtask
endclass

class driver;

    virtual wb_if vif;
    transaction tr;
    event drv_next;

    mailbox #(transaction) mbx_gen_drv;

    function new(mailbox #(transaction) mbx_gen_drv);
        this.mbx_gen_drv = mbx_gen_drv;
    endfunction

    task reset();
        vif.rst   <= 1'b1; //active high 
        vif.we    <= 0;
        vif.addr  <= 0;
        vif.wdata <= 0;
        vif.strb  <= 0;
        repeat(10) @(posedge vif.clk);
        vif.rst <= 1'b0;
        repeat(5) @(posedge vif.clk);
        $display("[DRV] : RESET DONE");
    endtask

    task write();
        @(posedge vif.clk);
        $display("[DRV] : DATA WRITE MODE");
        vif.rst   <= 1'b0;
        vif.we    <= 1'b1;
        vif.strb  <= 1'b1;
        vif.addr  <= tr.addr;
        vif.wdata <= tr.wdata;
        ->drv_next; //trigger drive next event to unblock wait in gen
    endtask

    task read();
        @(posedge vif.clk);
        $display("[DRV] : DATA READ MODE");
        vif.rst   <= 1'b0;
        vif.we    <= 1'b0;
        vif.strb  <= 1'b1;
        vif.addr  <= tr.addr;
        @(posedge vif.ack);
        @(posedge vif.clk);
        ->drv_next;  //trigger drive next event to unblock wait in gen
    endtask

    task run();
        forever begin
          mbx_gen_drv.get(tr);
          if(tr.opmode == 0) begin
            write();
          end  
          else if (tr.opmode == 1) begin
            read();
          end   
        end
    endtask
endclass

class monitor;

    virtual wb_if vif;
    transaction tr;
    

    mailbox#(transaction) mbx_mon_sco;

    function new(mailbox #(transaction) mbx_mon_sco);
        this.mbx_mon_sco = mbx_mon_sco;
    endfunction

    task run();

        tr = new();

        forever begin
            wait(vif.rst == 1'b0);
            @(posedge vif.ack);
            tr.we   = vif.we;
            tr.strb = vif.strb;
            tr.wdata= vif.wdata;
            tr.addr = vif.addr;
            tr.rdata= vif.rdata;
            @(posedge vif.clk);
            $display("[MONITOR] : Sending data to sco");
            mbx_mon_sco.put(tr);          
        end
    endtask     
endclass

class scoreboard;
    transaction tr;
    event sco_next;

    mailbox #(transaction) mbx_mon_sco;

  bit[7:0] data[256] ='{default:'h11};

    function new(mailbox #(transaction) mbx_mon_sco);
        this.mbx_mon_sco = mbx_mon_sco;
    endfunction

    task run();
        forever begin
            mbx_mon_sco.get(tr);
            if(tr.we == 1'b1)begin
                data[tr.addr] = tr.wdata; 
              $display("[SCO] : DATA WRITE : %0h ADDR : %0h", tr.wdata, tr.addr);
            end else if (tr.we == 1'b0)begin
                if(tr.rdata == data[tr.addr])begin
                  $display("[SCO] : DATA MATCHED DATA : %0h ADDR : %0h mem_array : %0h", tr.rdata, tr.addr,data[tr.addr]);
                end else begin
                  $display("[SCO] : DATA MISMATCHED DATA : %0h ADDR : %0h mem_array : %0h ", tr.rdata, tr.addr,data[tr.addr]);
                end
            end
            ->sco_next;
        end
    endtask
endclass

module tb;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;

    event drv_next, sco_next;
    event gen_done;

    mailbox #(transaction) mbx_gen_drv;
    mailbox #(transaction) mbx_mon_sco;

    wb_if vif();
    mem_wb dut (vif.clk, vif.we, vif.strb, vif.rst, vif.addr, vif.wdata, vif.rdata, vif.ack);

    initial begin
    vif.clk <= 0;
    end
  
    always #5 vif.clk <= ~vif.clk;

    initial begin
        mbx_gen_drv = new();
        mbx_mon_sco = new();
        gen = new(mbx_gen_drv);
        drv = new(mbx_gen_drv);
        mon = new(mbx_mon_sco);
        sco = new(mbx_mon_sco);
        
        drv.vif = vif;
        mon.vif = vif;

        drv.drv_next = drv_next; //local event assigned to driver
        gen.drv_next = drv_next;
    
        gen.sco_next = sco_next;
        sco.sco_next = sco_next; //local event assigned to driver

    end

    initial begin
        drv.reset();
        fork
        gen.run();
        drv.run();
        mon.run();
        sco.run();
        join_none  
      wait(gen.gen_done.triggered);
        $finish();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars; 
    end
    
endmodule



