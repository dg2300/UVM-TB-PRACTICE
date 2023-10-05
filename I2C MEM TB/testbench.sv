`include "uvm_macros.svh"
 import uvm_pkg::*;

//Global variable declaration
typedef enum bit [1:0]   {readd = 0, writed = 1, rstdut = 2} oper_mode;

 class transaction extends uvm_sequence_item;
  
  oper_mode op;
  logic wr;
  randc logic [6:0] addr;
  rand logic [7:0] din;
  logic [7:0] datard;
  logic done;
         
  constraint addr_c { addr <= 10;}
 
    `uvm_object_utils_begin(transaction)
        `uvm_field_int(wr,UVM_ALL_ON)
        `uvm_field_int(addr,UVM_ALL_ON)
        `uvm_field_int(din,UVM_ALL_ON)
        `uvm_field_int(datard,UVM_ALL_ON)
        `uvm_field_int(done,UVM_ALL_ON)
        `uvm_field_enum(oper_mode, op,UVM_ALL_ON)
    `uvm_object_utils_end

  function new(string name = "transaction");
    super.new(name);
  endfunction
endclass : transaction

///////////WRITE SEQUENCE/////////////
class write_sequence extends uvm_sequence#(transaction);
    `uvm_object_utils(write_sequence)

    transaction tr;

    function new(string name = "write_data");
        super.new(name);
    endfunction

    virtual task body();
        repeat(10) begin
            tr = transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            tr.op = writed;
          `uvm_info(get_type_name(),$sformatf("MODE : WRITE DIN : %0d ADDR : %0d",tr.din,tr.addr),UVM_NONE)
            finish_item(tr);
        end
    endtask
endclass

///////////READ SEQUENCE/////////////
class read_sequence extends uvm_sequence#(transaction);
    `uvm_object_utils(read_sequence)

    transaction tr;

    function new(string name = "read_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat(10) begin
            tr = transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            tr.op = readd;
          `uvm_info(get_type_name(),$sformatf("MODE : READ ADDR : %0d",tr.addr),UVM_NONE)
            finish_item(tr);
        end
    endtask
endclass

class reset_dut extends uvm_sequence#(transaction);
    `uvm_object_utils(reset_dut)
  
  	transaction tr;
    
    function new(string name = "reset_dut");
        super.new(name);
    endfunction

    virtual task body();
        repeat(10) begin
            tr = transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            tr.op = rstdut;
            `uvm_info(get_type_name(),"MODE : RSTDUT",UVM_NONE)
          	finish_item(tr);
        end

    endtask
endclass

class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    transaction tr;
    //vif
    virtual i2c_i vif;

    function new(string name = "driver", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        if(!uvm_config_db#(virtual i2c_i)::get(this,"","vif",vif))
            `uvm_error(get_type_name(),"Unable to get intf inf")
    endfunction

    task reset_dut();
      `uvm_info(get_type_name(),"Reset Dut",UVM_NONE)
        vif.rst       <= 1'b1;  ///active high reset
        vif.addr      <= 0;
        vif.din       <= 0; 
        vif.wr        <= 0;
        @(posedge vif.clk);
    endtask

    task read_d();
      `uvm_info(get_type_name(),"Read drive",UVM_NONE)
        vif.rst  <= 1'b0;
        vif.wr   <= 1'b0;
        vif.addr <= tr.addr;
        vif.din  <= 0;
        @(posedge vif.done); //??
    endtask

    task write_d();
      `uvm_info(get_type_name(),"Write drive",UVM_NONE)
        vif.rst  <= 1'b0;
        vif.wr   <= 1'b1;
        vif.addr <= tr.addr;
        vif.din  <= tr.din;
        @(posedge vif.done); //??
    endtask


    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(tr);
            `uvm_info(get_type_name(),"Inside Driver",UVM_NONE)
          if(tr.op == rstdut) begin reset_dut(); end
          else if(tr.op == writed) begin write_d(); end
          else if(tr.op == readd) begin read_d(); end
            `uvm_info(get_type_name(),"End of Driver",UVM_NONE)
            seq_item_port.item_done();
        end
    endtask
endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    transaction tr;
    uvm_analysis_port#(transaction) send_port;
    virtual i2c_i vif;

    function new(string name = "agent", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        send_port = new("send_port",this);
        if(!uvm_config_db#(virtual i2c_i)::get(this,"","vif",vif))
            `uvm_error(get_type_name(),"Unable to get intf inf")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if(vif.rst) begin
                tr.op      = rstdut; 
              	send_port.write(tr); 
            end
        
            else begin
                if(vif.wr == 1) begin
                    tr.op         = writed;
                  	tr.din        = vif.din; 
                  	tr.wr         = vif.wr;
                	tr.addr       = vif.addr;
                  	@(posedge vif.done);
                  	send_port.write(tr); 
                end else begin
                    tr.op         = readd;
                  	tr.wr         = vif.wr;
                	tr.addr       = vif.addr;
                  	@(posedge vif.done);  
                    tr.datard = vif.datard;
                  	send_port.write(tr); 
                end     
                
            end
                   
        end
    endtask
endclass

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)
    reg [7:0] mem[128] = '{default:0};

    uvm_analysis_imp#(transaction,scoreboard) recv_imp;

    function new (string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        recv_imp = new("recv_imp",this);
    endfunction

    virtual function void write(transaction tr);
        if(tr.op == writed)begin
            mem[tr.addr] = tr.din;
        end 
        else if(tr.op == readd) begin
            if(tr.datard == mem[tr.addr]) begin
                `uvm_info(get_type_name(), $sformatf("DATA MATCHED : addr:%0d, rdata:%0d",tr.addr,tr.datard), UVM_NONE)
            end else begin
                `uvm_error(get_type_name(),$sformatf("TEST FAILED : addr:%0d, rdata:%0d data_rd_arr:%0d",tr.addr,tr.datard,mem[tr.addr]))
            end
        end
    endfunction
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    driver drv;
    uvm_sequencer#(transaction) seqr;
    monitor mon;

    function new(string name = "agent", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv",this);
        mon = monitor::type_id::create("mon",this);
        seqr = uvm_sequencer#(transaction)::type_id::create("seqr",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass


class env extends uvm_env;
    `uvm_component_utils(env)

    agent agnt;
    scoreboard sco;

    function new(string name = "env", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agnt = agent::type_id::create("agnt",this);
        sco = scoreboard::type_id::create("sco",this);
        
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agnt.mon.send_port.connect(sco.recv_imp);
    endfunction
endclass
      
class test extends uvm_test;
    `uvm_component_utils(test)

    write_sequence wr_seq;
    read_sequence  rd_seq;
    reset_dut      rst_seq;
    env envh;

    function new (string name = "test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      envh = env::type_id::create("env",this);
        wr_seq = write_sequence::type_id::create("wr_seq");
        rd_seq = read_sequence::type_id::create("rd_seq");
        rst_seq = reset_dut::type_id::create("rst_seq");
    endfunction 


  virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
            rst_seq.start(envh.agnt.seqr);
            wr_seq.start(envh.agnt.seqr);
            rd_seq.start(envh.agnt.seqr);
        phase.drop_objection(this);
    endtask

endclass

module tb;

    //interface
    i2c_i vif();

    i2c_mem dut(.clk(vif.clk), 
                .rst(vif.rst), 
                .wr(vif.wr), 
                .addr(vif.addr), 
                .din(vif.din), 
                .datard(vif.datard), 
                .done(vif.done));
  
initial begin
    vif.clk <= 0;
  end
 
  always #10 vif.clk <= ~vif.clk;

initial begin
    uvm_config_db#(virtual i2c_i)::set(null,"*","vif",vif);
  run_test("test");
end

initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

endmodule