//////////////////////////////////////////////
 
interface axi_if();
  
  ////////write address channel (aw)
  
  logic awvalid;  /// master is sending new address  
  logic awready;  /// slave is ready to accept request
  logic [3:0] awid; ////// unique ID for each transaction
  logic [3:0] awlen; ////// burst length AXI3 : 1 to 16, AXI4 : 1 to 256
  logic [2:0] awsize; ////unique transaction size : 1,2,4,8,16 ...128 bytes
  logic [31:0] awaddr; ////write adress of transaction
  logic [1:0] awburst; ////burst type : fixed , INCR , WRAP
  
  
  //////////write data channel (w)
  logic wvalid; //// master is sending new data
  logic wready; //// slave is ready to accept new data 
  logic [3:0] wid; /// unique id for transaction
  logic [31:0] wdata; //// data 
  logic [3:0] wstrb; //// lane having valid data
  logic wlast; //// last transfer in write burst
  
  
  //////////write response channel (b) 
  logic bready; ///master is ready to accept response
  logic bvalid; //// slave has valid response
  logic [3:0] bid; ////unique id for transaction
  logic [1:0] bresp; /// status of write transaction 
  
  ///////////////read address channel (ar)
 
  logic arvalid;  /// master is sending new address  
  logic arready;  /// slave is ready to accept request
  logic [3:0] arid; ////// unique ID for each transaction
  logic [3:0] arlen; ////// burst length AXI3 : 1 to 16, AXI4 : 1 to 256
  logic [2:0] arsize; ////unique transaction size : 1,2,4,8,16 ...128 bytes
  logic [31:0] araddr; ////write adress of transaction
  logic [1:0] arburst; ////burst type : fixed , INCR , WRAP
  
  /////////// read data channel (r)
  
  logic rvalid; //// master is sending new data
  logic rready; //// slave is ready to accept new data 
  logic [3:0] rid; /// unique id for transaction
  logic [31:0] rdata; //// data 
  logic [3:0] rstrb; //// lane having valid data
  logic rlast; //// last transfer in write burst
  logic [1:0] rresp; ///status of read transfer
  
  ////////////////
  
  logic clk;
  logic resetn;
  
  //////////////////
  logic [31:0] nextaddrwr;
  logic [31:0] nextaddrrd;

endinterface

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
  constraint addrrng {awaddr <= 'h80;} //lesser than 128 because mem array 

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
    
    //repeat(2)begin
      start_item(tr);
      assert(tr.randomize);
      tr.op = wrrdfixed;
      tr.awlen = 7;    //burst length  7 + 1 = no of transfers = 8
      tr.arlen = 7;    //burst length  7 + 1 = no of transfers = 8
      tr.awburst = 0; // address fold type 0 fixed
      tr.awsize = 2; //2 bytes per unique transaction // This combo : 32 bytes = 256 bits
      tr.print();  // Visualize packet
      finish_item(tr);
    //end  
    `uvm_info(get_type_name,"Inside task body of wrrd_fixed sequence",UVM_NONE)
  endtask
endclass : valid_wrrd_fixed

////DRIVER///////

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
 task wrrd_fixed_wr();
            `uvm_info("DRV", "Fixed Mode Write Transaction Started", UVM_NONE);
    /////////////////////////write logic
            vif.resetn      <= 1'b1;
            vif.awvalid     <= 1'b1;
            vif.awid        <= tr.id;
            vif.awlen       <= 7;
            vif.awsize      <= 2;
            vif.awaddr      <= tr.awaddr;
            vif.awburst     <= 0;
     
     
            vif.wvalid      <= 1'b1;
            vif.wid         <= tr.id;
            vif.wdata       <= $urandom_range(0,10);
            vif.wstrb       <= 4'b1111;
            vif.wlast       <= 0;
     
            vif.arvalid     <= 1'b0;  ///turn off read 
            vif.rready      <= 1'b0;
            vif.bready      <= 1'b0;
             @(posedge vif.clk);
            
             @(posedge vif.wready);
             @(posedge vif.clk);
 
     for(int i = 0; i < (vif.awlen); i++)//0 - 6 -> 7
         begin
            //vif.wdata       <= $urandom_range(0,10);
            vif.wdata       <= 'ha + i;
            vif.wstrb       <= 4'b1111;
            @(posedge vif.wready);
            @(posedge vif.clk);
         end
         vif.awvalid     <= 1'b0;
         vif.wvalid      <= 1'b0;
         vif.wlast       <= 1'b1;
         vif.bready      <= 1'b1;
         @(negedge vif.bvalid); 
         vif.wlast       <= 1'b0;
         vif.bready      <= 1'b0;  
   endtask
    
   
        task  wrrd_fixed_rd(); 
        `uvm_info("DRV", "Fixed Mode Read Transaction Started", UVM_NONE);   
        @(posedge vif.clk);
 
        vif.arid        <= tr.id;
        vif.arlen       <= 7;
        vif.arsize      <= 2;
        vif.araddr      <= tr.awaddr;
        vif.arburst     <= 0; 
        vif.arvalid     <= 1'b1;  
        vif.rready      <= 1'b1;
       
        
     for(int i = 0; i < (vif.arlen + 1); i++) begin // 0 1  2 3 4 5 6 7
       @(posedge vif.arready);
       @(posedge vif.clk);
      end
      
     @(negedge vif.rlast);      
     vif.arvalid <= 1'b0;
     vif.rready  <= 1'b0; 
 
  endtask

  virtual task run_phase (uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info("DRV", $sformatf("Fixed Mode Write -> Read WLEN:%0d WSIZE:%0d",tr.awlen+1,tr.awsize), UVM_MEDIUM);
             wrrd_fixed_wr();
             wrrd_fixed_rd();
      seq_item_port.item_done();
    end
  endtask : run_phase
endclass : driver
//////////////MONITOR/////////////
class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)

  transaction tr;
  virtual axi_if vif;
  uvm_analysis_port#(transaction) sendpktfrmon;

  
  function new(string name = "monitor", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase); //TODO: Difference between buildphase func and build func
    super.build_phase(phase);
    tr = transaction::type_id::create("tr");
    sendpktfrmon = new("sendpktfrmon",this);
    if(!uvm_config_db#(virtual axi_if)::get(this,"","vif",vif))
      `uvm_error(get_type_name(),"Cannot get handle to interface");
    
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      if(vif.resetn)begin
        //WRITE
        if(vif.awready) begin
          tr.awready = vif.awready;
          tr.awaddr = vif.awaddr;
          tr.wdata = vif.wdata;
        end
        //READ
        else if(vif.arready) begin
          tr.arready = vif.arready;
          tr.araddr = vif.araddr;
          tr.rdata = vif.rdata;
        end

        sendpktfrmon.write(tr);
       end
    end
  endtask
endclass

//////////////SCOREBOARD/////////////
class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)

  uvm_analysis_imp#(transaction,scoreboard) recvpktfrmon ;
  //Array
  bit[31:0]mem[128] = '{default:0};
  bit[31:0] addr ;

  function new (string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase (uvm_phase phase);
    super.build_phase(phase);
    recvpktfrmon = new("recvpktfrmon",this);
  endfunction

  virtual function void write(transaction tr);
    //WRITE
    if(tr.awready) begin
      addr = tr.awaddr ;
      mem[addr] = tr.wdata ;
    end
    //READ
    if(tr.arready) begin
      addr = tr.araddr ;
      mem[addr] = tr.rdata ;
      if(tr.rdata == mem[addr]) begin
        `uvm_info(get_type_name(),$sformatf("DATA_MATCHED rdata = %0h mem[%0h] = %0h",tr.rdata,addr,mem[addr]),UVM_NONE);
      end else begin
        `uvm_error(get_type_name(),$sformatf("DATA_MISS_MATCHED rdata = %0h mem[%0h] = %0h",tr.rdata,addr,mem[addr]));
      end
    end
  endfunction

endclass

////AGENT///////

class agent extends uvm_agent;

 `uvm_component_utils(agent)

 driver drv;
 monitor mon;
 uvm_sequencer#(transaction) seqr;

 function new(string name = "agent", uvm_component parent = null);
  super.new(name, parent);
 endfunction 

 function void build_phase(uvm_phase phase);
    drv = driver::type_id::create("drv",this);
    mon = monitor::type_id::create("mon",this);
    seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
 endfunction

 virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
 endfunction
endclass

////ENV///////


class env extends uvm_env;

  `uvm_component_utils(env)

  agent agnt;
  scoreboard scb;

  function new(string name = "env", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agnt = agent::type_id::create("agnt",this);
    scb = scoreboard::type_id::create("scb",this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agnt.mon.sendpktfrmon.connect(scb.recvpktfrmon);
	endfunction

endclass

////TB TOP//////

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

  always #5 vif.clk = ~vif.clk ;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    $fsdbDumpvars(0,axi_slave, axi_if, tb);
  end

  assign vif.nextaddrwr = dut.nextaddr;    //TODO : why assigning ?
  assign vif.nextaddrrd = dut.rdnextaddr;

endmodule
