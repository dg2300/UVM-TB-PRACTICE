//TODO: MONITOR SCOREBOARD
//TODO: Fix why read data is 0 
////TESTBENCH CODE

`include "uvm_macros.svh"
import uvm_pkg::*;

typedef enum bit [2:0] {   //TODO : difference or coreelation between tyedef and enum
    wrrdfixed = 0 , 
    wrrdincr = 1, 
    wrrdwrap = 2,
    wrrderrfix = 3,
    rstdut = 4
} oper_mode;

class transaction extends uvm_sequence_item;

    function new(string name = "transaction");
        super.new(name);
    endfunction

    oper_mode op;
    int len = 0;
    rand bit [3:0] id; // TODO : what for ?
  
  ///////////////////write address channel
    rand bit  awvalid;  /// master is sending new address  
    bit awready;  /// slave is ready to accept request
    rand bit [3:0] awid; ////// unique ID for each transaction
    rand bit [3:0] awlen; ////// burst length AXI3 : 1 to 16; AXI4 : 1 to 256
    rand bit [2:0] awsize; ////unique transaction size : 1;2;4;8;16 ...128 bytes
    rand bit [31:0] awaddr; ////write adress of transaction
    rand bit [1:0] awburst; ////burst type : 0 fixed ; 1 INCR ; 2 WRAP
  //TOTAL BYTE TRANSFERED = (2^awsize)*(awlen+1) //TODO : does it have correlation with wdata?
  //Answer :  max(2^awsize) = wdith of wdata 

  /////////////////////write data channel
  
    rand bit wvalid; //// master is sending new data
    bit wready; //// slave is ready to accept new data 
    bit [3:0] wid; /// unique id for transaction
    rand bit [31:0] wdata; //// data 
    rand bit [3:0] wstrb; //// lane having valid data
    bit wlast; //// last transfer in write burst
 
  ///////////////write response channel
  
    bit bready; ///master is ready to accept response
    bit bvalid; //// slave has valid response
    bit [3:0] bid; ////unique id for transaction
    bit [1:0] bresp; /// status of write transaction 
  
  ////////////// read address channel
  
    bit	arready;  //read address ready signal from slave
    bit [3:0]	arid;      //read address id
    rand bit [31:0]	araddr;		//read address signal
    rand bit [3:0]	arlen;      //length of the burst
    bit [2:0]	arsize;		//number of bytes in a transfer
    rand bit [1:0]	arburst;	//burst type - fixed; incremental; wrapping
    rand bit	arvalid;	//address read valid signal
	
 ///////////////////read data channel
   	bit [3:0] rid;		//read data id
	  bit [31:0]rdata;     //read data from slave
 	  bit [1:0] rresp;		//read response signal
	  bit rlast;		//read data last signal
	  bit rvalid;		//read data valid signal
	  bit rready;

    `uvm_object_utils_begin(transaction)
            `uvm_field_enum(oper_mode, op, UVM_DEFAULT)
            `uvm_field_int(awvalid,UVM_ALL_ON)
            `uvm_field_int(awready,UVM_ALL_ON)
            `uvm_field_int(awid,UVM_ALL_ON)
            `uvm_field_int(awlen,UVM_ALL_ON)
            `uvm_field_int(awsize,UVM_ALL_ON)
            `uvm_field_int(awaddr,UVM_ALL_ON)
            `uvm_field_int(awburst ,UVM_ALL_ON)
            `uvm_field_int(wvalid,UVM_ALL_ON)
            `uvm_field_int(wready,UVM_ALL_ON)
            `uvm_field_int(wid,UVM_ALL_ON)
            `uvm_field_int(wdata,UVM_ALL_ON)
            `uvm_field_int(wstrb,UVM_ALL_ON)
            `uvm_field_int(wlast,UVM_ALL_ON)
            `uvm_field_int(bready,UVM_ALL_ON)
            `uvm_field_int(bvalid,UVM_ALL_ON)
            `uvm_field_int(bid,UVM_ALL_ON)
            `uvm_field_int(bresp,UVM_ALL_ON)
            `uvm_field_int(arready,UVM_ALL_ON)
            `uvm_field_int(arid,UVM_ALL_ON)
            `uvm_field_int(araddr,UVM_ALL_ON)
            `uvm_field_int(arlen,UVM_ALL_ON)
            `uvm_field_int(arsize,UVM_ALL_ON)
            `uvm_field_int(arburst,UVM_ALL_ON)
            `uvm_field_int(arvalid,UVM_ALL_ON)
            `uvm_field_int(rid,UVM_ALL_ON)
            `uvm_field_int(rdata,UVM_ALL_ON)
            `uvm_field_int(rresp,UVM_ALL_ON)
            `uvm_field_int(rlast,UVM_ALL_ON)
            `uvm_field_int(rvalid,UVM_ALL_ON)
            `uvm_field_int(rready,UVM_ALL_ON)
    `uvm_object_utils_end

  //constraint txid { awid == id; wid == id; bid == id; arid == id; rid == id;  } // planning not to use this
  constraint burst {awburst inside {0,1,2}; arburst inside {0,1,2};} // there is no support for 3 
  constraint valid {awvalid != arvalid;} // why ?
  constraint length {awlen == arlen;}

endclass : transaction

/* CODE TO CHECK IF PACKETS ARE RANDOMIZED 
module tb;
  transaction tr;

  initial begin
    tr = new();
    assert(tr.randomize);
    tr.print();
  end

endmodule
*/


////SEQUENCES///////

class valid_wrrd_fixed extends uvm_sequence#(transaction);
  `uvm_object_utils(valid_wrrd_fixed)

  function new(string name = "valid_wrrd_fixed");
    super.new(name);
  endfunction

  transaction tr;

  virtual task body();
    tr = transaction::type_id::create("tr");
    `uvm_info(get_type_name,"Inside task body of wrrd_fixed sequence",UVM_NONE)
    
    repeat(2)begin
      start_item(tr);
      assert(tr.randomize);
      tr.op = wrrdfixed;
      tr.awlen = 7;    //burst length  7 + 1 = no of transfers = 8
      tr.awburst = 0; // address fold type 0 fixed
      tr.awsize = 2; //2 bytes per unique transaction // This combo : 32 bytes = 256 bits
      tr.print();  // Visualize packet
      finish_item(tr);
    end  
    `uvm_info(get_type_name,"Inside task body of wrrd_fixed sequence",UVM_NONE)
  endtask
endclass : valid_wrrd_fixed

class driver extends uvm_driver#(transaction);
  `uvm_component_utils(driver)

  transaction tr;
  virtual axi_if vif;

  function new(string name = "driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase (uvm_phase phase );
    tr = transaction::type_id::create("tr"); 
    if(!uvm_config_db#(virtual axi_if)::get(this,"","vif",vif))
      `uvm_error(get_type_name,"Cannot get interface handle");
  endfunction : build_phase

  task wrrd_fixed_mode();    //TODO: find if task is blocking or nonblocking with nba 
    `uvm_info(get_type_name(),"Driving back to back write and read in fixed mode",UVM_NONE)
    ////WRITE
    vif.resetn  <= 1'b1; 
    vif.awvalid <= 1'b1;
    vif.awid    <= tr.awid; // random
    vif.awlen   <= tr.awlen;
    vif.awsize  <= tr.awsize;
    vif.awaddr  <= tr.awaddr;
    vif.awburst <= tr.awburst;

    vif.wvalid  <= 1'b1;
    vif.wid     <= tr.awid; // want to be same 
    vif.wdata   <= tr.wdata;
    vif.wstrb   <= tr.wstrb; // keeping it random for now
    vif.wlast   <= 0;

    vif.arvalid <= 1'b0; //turn off read ? is it required ??
    vif.rready  <= 1'b0;
    vif.bready  <= 1'b0;

    @(posedge vif.clk);         
    @(posedge vif.wready);  //wait for slave ready to accept
    @(posedge vif.clk);

    for(int i=0; i < vif.awlen ; i++) begin  // 7 times
      vif.wdata   <= tr.wdata; // same data think how instead of using $urandom(0,10)
    end
    vif.awvalid     <= 1'b0;   //deassert awvalid 
    vif.wvalid      <= 1'b0;   //deassert wavalid 
    vif.wlast       <= 1'b1;   //send last packet indicator 
    vif.bready      <= 1'b1;   //notify slave ready to recieve response
    @(negedge vif.bvalid); 
    vif.wlast       <= 1'b0;   //deassert wlast after getting slave ready to send response
    vif.bready      <= 1'b0;   //deassert bready for master

    `uvm_info(get_type_name(), "Fixed Mode Read Transaction Started", UVM_NONE);

    @(posedge vif.clk);

    vif.arid        <= tr.awid;
    vif.arlen       <= tr.arlen;
    vif.arsize      <= tr.awsize;  //keeping it same as wr
    vif.araddr      <= tr.awaddr;  //keeping it same as wr
    vif.arburst     <= tr.awburst; //keeping it same as wr
    vif.arvalid     <= 1'b1;
    vif.rready      <= 1'b1;  //master ready to read

    for(int i=0; i< (vif.arlen +1); i++)begin
      @(posedge vif.arready);  //read addrss ready from slave
      @(posedge vif.clk);
    end

    @(negedge vif.rlast);      
     vif.arvalid <= 1'b0;
     vif.rready  <= 1'b0;

  endtask

  virtual task run_phase (uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(tr);
      wrrd_fixed_mode();
      seq_item_port.item_done();
    end
  endtask : run_phase
endclass : driver

class agent extends uvm_agent;

 `uvm_component_utils(agent)

 driver drv;
 uvm_sequencer#(transaction) seqr;

 function new(string name = "agent", uvm_component parent = null);
  super.new(name, parent);
 endfunction 

 function void build_phase(uvm_phase phase);
    drv = driver::type_id::create("drv",this);
    seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
 endfunction

 virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
 endfunction
endclass

class env extends uvm_env;

  `uvm_component_utils(env)

  agent agnt;

  function new(string name = "env", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agnt = agent::type_id::create("agnt",this);
  endfunction

endclass

class test extends uvm_test;
  `uvm_component_utils(test)

  env envh;
  valid_wrrd_fixed v_wwrd_fxd_h;
  function new( string name = " test", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    envh = env::type_id::create("envh",this);  //TODO: why this getting added here : for components ?
    v_wwrd_fxd_h = valid_wrrd_fixed::type_id::create("v_wwrd_fxd_h");
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
      v_wwrd_fxd_h.start(envh.agnt.seqr);
    phase.drop_objection(this);
  endtask
endclass

module tb();
  axi_if vif();
  axi_slave dut (
    .awvalid  			(vif.awvalid ),
    .awready  			(vif.awready),
    .awid 				  (vif.awid),
    .awlen 				  (vif.awlen),
    .awsize 				(vif.awsize),
    .awaddr 				(vif.awaddr),
    .awburst 			  (vif.awburst),
    .wvalid 				(vif.wvalid ),
    .wready 				(vif.wready),
    .wid 				    (vif.wid),
    .wdata 				  (vif.wdata),
    .wstrb 				  (vif.wstrb),
    .wlast 				  (vif.wlast),
    .bready 				(vif.bready),
    .bvalid 				(vif.bvalid),
    .bid 				    (vif.bid ),
    .bresp 				  (vif.bresp),
    .arvalid  			(vif.arvalid),
    .arready  			(vif.arready),
    .arid 				  (vif.arid),
    .arlen 				  (vif.arlen),
    .arsize 				(vif.arsize),
    .araddr 				(vif.araddr),
    .arburst 			  (vif.arburst),
    .rvalid 				(vif.rvalid),
    .rready 				(vif.rready),
    .rid 				    (vif.rid),
    .rdata 				  (vif.rdata),
    //.rstrb 				  (vif.rstrb),
    .rlast 				  (vif.rlast),
    .rresp 				  (vif.rresp),
    .clk				    (vif.clk),
    .resetn				  (vif.resetn)
    //.nextaddr		(vif.nextaddrwr)
    //.rdnextaddr	  (vif.nextaddrrd)
  );

  initial begin
      uvm_config_db#(virtual axi_if)::set(null,"*","vif",vif);  //TODO :Understand better
      vif.clk <= 0;
      run_test("test");
  end

  always #1 vif.clk = ~vif.clk ;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    $fsdbDumpvars(0,axi_slave, axi_if, tb);
  end

  assign vif.nextaddrwr = dut.nextaddr;    //TODO : why assigning ?
  assign vif.nextaddrrd = dut.rdnextaddr;

endmodule