`include "uvm_macros.svh"
import uvm_pkg::*;

class transaction extends uvm_sequence_item;
    rand bit [3:0] a;
    rand bit [3:0] b;
    rand bit [3:0] c;
    rand bit [3:0] d;
    rand bit [1:0] sel;
            bit [3:0] y;
        
   function new(input string path = "transaction");
    super.new(path);
   endfunction
  
  `uvm_object_utils_begin(transaction)
  `uvm_field_int(a, UVM_DEFAULT)
  `uvm_field_int(b, UVM_DEFAULT)
  `uvm_field_int(c, UVM_DEFAULT)
  `uvm_field_int(d, UVM_DEFAULT)
  `uvm_field_int(sel, UVM_DEFAULT)
  `uvm_field_int(y, UVM_DEFAULT)
  `uvm_object_utils_end
endclass

class sequence_1 extends uvm_sequence#(transaction);
  `uvm_object_utils(sequence_1)

  function new(string name = "sequence_1");
        super.new(name);
    endfunction

    task body();
        `uvm_info(get_type_name(),$sformatf("Inside Sequence"),UVM_LOW)
        repeat(15) begin
            transaction tr = transaction::type_id::create("tr"); //this not required
            start_item(tr);
            assert(tr.randomize());
            //tr.print();
            finish_item(tr);
        end
    endtask
endclass

class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)
 
  transaction tr; //no need to create this 
  virtual mux_if mif;
 
  function new(input string path = "driver", uvm_component parent = null);
    super.new(path,parent);
  endfunction
 
  virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    if(!uvm_config_db#(virtual mux_if)::get(this,"","mif",mif))//uvm_test_top.env.agent.drv.aif
      `uvm_error(get_type_name(),"Unable to access Interface");
  endfunction
  
   virtual task run_phase(uvm_phase phase);
     `uvm_info(get_type_name(),$sformatf("Inside Driver"),UVM_LOW)
     forever begin
        seq_item_port.get_next_item(tr);
        mif.a   <= tr.a;
        mif.b   <= tr.b;
        mif.c   <= tr.c;
        mif.d   <= tr.d;
        mif.sel <= tr.sel;
      `uvm_info(get_type_name(), $sformatf("a:%0d  b:%0d c:%0d d:%0d sel:%0d y:%0d", tr.a, tr.b,tr.c,tr.d,tr.sel,tr.y), UVM_NONE);
       seq_item_port.item_done();
        #20;   
      end
   endtask
endclass

class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)
    transaction tr;
    virtual mux_if mif;
    uvm_analysis_port#(transaction) mon_port;

  	function new(string name = "monitor", uvm_component  parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
        if(!uvm_config_db#(virtual mux_if)::get(this,"","mif",mif)) `uvm_error(get_type_name(),$sformatf("Unable to get interface handle"));
        tr = transaction::type_id::create("tr");
        mon_port = new("mon_port",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
      `uvm_info(get_type_name(),$sformatf("Inside Monitor"),UVM_LOW)
     	forever begin
       	#10;
        tr.a    = mif.a;
        tr.b    = mif.b;
        tr.c    = mif.c;
        tr.d    = mif.d;
        tr.sel  = mif.sel;
        tr.y    = mif.y;     
        
        mon_port.write(tr);
     	end
    endtask
endclass

class reference_monitor extends uvm_monitor;
  `uvm_component_utils(reference_monitor)
    transaction tr;
    uvm_analysis_port#(transaction) ref_mon_port;
    virtual mux_if mif;

  function new(string name = "ref_monitor", uvm_component  parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(virtual mux_if)::get(this,"","mif",mif)) `uvm_error(get_type_name(),$sformatf("Unable to get interface handle"));
        tr = transaction::type_id::create("tr");
        ref_mon_port = new("ref_mon_port",this);
    endfunction

    function void predict();
        case(tr.sel)
            2'b00 : tr.y = mif.a;
            2'b01 : tr.y = mif.b;
            2'b10 : tr.y = mif.c;
            2'b11 : tr.y = mif.d;
            default : tr.y = 4'b0000;
        endcase
    endfunction

    virtual task run_phase(uvm_phase phase);
      `uvm_info(get_type_name(),$sformatf("Inside Refrence Monitor"),UVM_LOW)
     forever begin
        #10;
        tr.a    = mif.a;
        tr.b    = mif.b;
        tr.c    = mif.c;
        tr.d    = mif.d;
        tr.sel  = mif.sel;
        predict();
        `uvm_info(get_type_name(), $sformatf("a:%0d  b:%0d c:%0d d:%0d sel:%0d y:%0d", tr.a, tr.b,tr.c,tr.d,tr.sel,tr.y), UVM_NONE); 
        ref_mon_port.write(tr);
     end
    endtask
endclass


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_tlm_analysis_fifo#(transaction) sco_mon;
    uvm_tlm_analysis_fifo#(transaction) sco_ref_mon;

    transaction tr, trref;

  function new(string name = "scoreboard" , uvm_component parent = null);
         super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        tr          = transaction::type_id::create("tr");
        trref       = transaction::type_id::create("trref");
        sco_mon     = new("sco_data", this);
        sco_ref_mon = new("sco_ref_data", this);
    endfunction

    virtual task run_phase( uvm_phase phase);
      `uvm_info(get_type_name(),$sformatf("Inside Scoreboard"),UVM_LOW)
        forever begin
          `uvm_info(get_type_name(),$sformatf("Inside Scoreboard Floop"),UVM_LOW)
            sco_mon.get(tr);
          `uvm_info(get_type_name(),$sformatf("Inside Scoreboard get tr"),UVM_LOW)
            sco_ref_mon.get(trref);
          `uvm_info(get_type_name(),$sformatf("Inside Scoreboard get trref"),UVM_LOW)

          if(tr.compare(trref)) begin 
               
                `uvm_info("SCO", "Test Passed", UVM_NONE)
          end
            else
                `uvm_info("SCO", "Test Failed", UVM_NONE)
        end
    endtask
endclass


class agent extends uvm_agent;
    `uvm_component_utils(agent)
 
    function new(input string inst = "agent", uvm_component parent = null);
        super.new(inst,parent);
    endfunction
  
    driver drv;
    uvm_sequencer#(transaction) seqr;
    monitor mon;
    reference_monitor mref;
 
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv     = driver::type_id::create("drv",this);
        mon     = monitor::type_id::create("mon",this);
        mref    = reference_monitor::type_id::create("mref",this); 
        seqr    = uvm_sequencer#(transaction)::type_id::create("seqr", this);
    endfunction
 
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

class environment extends uvm_env;

  `uvm_component_utils(environment)

    agent agnt;
    scoreboard sco;
  
  	function new(string name = "environment", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agnt    = agent::type_id::create("agnt",this);
        sco     = scoreboard::type_id::create("sco", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
      agnt.mon.mon_port.connect(sco.sco_mon.analysis_export);
      agnt.mref.ref_mon_port.connect(sco.sco_ref_mon.analysis_export);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    environment env;
    sequence_1 seq;

    function new(string name = "test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        env = environment::type_id::create("env",this);
        seq = sequence_1::type_id::create("seq",this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
      `uvm_info(get_type_name(),$sformatf("Inside TEST"),UVM_LOW)
            seq.start(env.agnt.seqr);
      		#20;
        phase.drop_objection(this);
    endtask


endclass
          
module tb();
  
  mux_if mif();
  mux dut(.a(mif.a), .b(mif.b), .c(mif.c), .d(mif.d), .sel(mif.sel), .y(mif.y));
 
	initial 
  	begin
  		uvm_config_db #(virtual mux_if)::set(null, "*", "mif", mif);
  		run_test("test"); 
  	end
 
  	initial begin
    	$dumpfile("dump.vcd");
    	$dumpvars;
  	end
endmodule
