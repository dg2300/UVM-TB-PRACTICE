////////////////CONFIG ENV/////////////////////////////////////
class apb_config extends uvm_object;
	`uvm_object_utils(apb_config)

  	function new (string name= "apb_config");
		super.new(name);
	endfunction 

	uvm_active_passive_enum is_active = UVM_ACTIVE; 

endclass

typedef enum bit [1:0] {read=0, writed=1, rst=2} oper_mode; 

///////////////TRANSACTION CLASS///////////////////////////////
class transaction extends uvm_sequence_item;
	
	
	function new(string name = "transaction");
      super.new(name);
	endfunction 
	
	//input
	//logic presetn,
    //logic pclk,
    //rand logic psel,
    
	rand oper_mode op;
    rand logic PWRITE;
    rand logic [31:0] PADDR, PWDATA;
	
	//output 
	logic [31:0] PRDATA;
    logic PREADY, PSLVERR;
	 
	 
	`uvm_object_utils_begin(transaction)
		`uvm_field_int(PWRITE,UVM_ALL_ON)
		`uvm_field_int(PADDR,UVM_ALL_ON)
		`uvm_field_int(PWDATA,UVM_ALL_ON)
		`uvm_field_int(PRDATA,UVM_ALL_ON)
		`uvm_field_int(PREADY,UVM_ALL_ON)
		`uvm_field_int(PSLVERR,UVM_ALL_ON)
		`uvm_field_enum(oper_mode, op, UVM_DEFAULT)  
	`uvm_object_utils_end
	
	constraint addr_c { PADDR <= 31; }
	constraint addr_c_err { PADDR > 31; }
	
	
endclass

////////////////////SEQUENCES/////////////////////////////////////

class write_data extends uvm_sequence#(transaction);
	
	`uvm_object_utils(write_data)
	
	transaction tr; //NOTE: by default you could have used REQ 
	
	function new(string name = "write_data");
      super.new(name);
    endfunction
  
	virtual task body(); 
		repeat(15)
		begin
			tr = transaction::type_id::create("tr") ;  
			tr.addr_c.constraint_mode(1);
			tr.addr_c_err.constraint_mode(0);
			
			start_item(tr);
			assert(tr.randomize);
			tr.op = writed;
			finish_item(tr);
		end
	endtask
	
endclass

/////////////////////////////////////////////

class read_data extends uvm_sequence#(transaction);
  `uvm_object_utils(read_data)
  
  transaction tr;
 
  function new(string name = "read_data");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(15)
      begin
        tr = transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);
        tr.addr_c_err.constraint_mode(0);//disable
        start_item(tr);
        assert(tr.randomize);
        tr.op = read;
        finish_item(tr);
      end
  endtask
  
 
endclass
 
 
 
/////////////////////////////////////////////
 
class write_read extends uvm_sequence#(transaction); //////read after write
  `uvm_object_utils(write_read)
  
  transaction tr;
 
  function new(string name = "write_read");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(15)
      begin
        tr = transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);
        tr.addr_c_err.constraint_mode(0);
        
        start_item(tr);
        assert(tr.randomize);
        tr.op = writed;
        finish_item(tr);
        
        start_item(tr);
        assert(tr.randomize);
        tr.op = read;
        finish_item(tr);
      end
  endtask
  
 
endclass
////////////////////// DRIVER ///////////////////////

class driver extends uvm_driver#(transaction);
	`uvm_component_utils(driver)
	
	transaction tr;
	virtual apb_if vif;  
	
	function new (input string path = "driver" , uvm_component parent = null); 
		super.new(path,parent);
	endfunction
  
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tr = transaction::type_id::create("tr");
		
		//Interface handle mapping 
		if(!uvm_config_db#(virtual apb_if)::get(this,"","vif",vif))  
		`uvm_error("driver","Unable to access Interface");
		
	endfunction
	 
	task reset_dut();
 
			vif.presetn   <= 1'b0;
			vif.paddr     <= 'h0;
			vif.pwdata    <= 'h0;
			vif.pwrite    <= 'b0;
			vif.psel      <= 'b0;
			vif.penable   <= 'b0; 
		`uvm_info("DRV", "System Reset : Start of Simulation", UVM_MEDIUM);
		
	endtask
	
	task drive();
		reset_dut();
		repeat(5) @(posedge vif.pclk); //wait for 5 clock cycles
		
		forever begin 
			seq_item_port.get_next_item(tr); //getting from sequencer 
			
			if(tr.op == rst)begin
				reset_dut();
				@(posedge vif.pclk);
			end
			if(tr.op == writed)begin   
				vif.psel <= 1'b1;
				vif.paddr <= tr.PADDR ;
				vif.pwdata <= tr.PWDATA;
				vif.presetn <= 1'b1;
                vif.pwrite  <= 1'b1;
				@(posedge vif.pclk);
				vif.penable <= 1'b1;
				
				`uvm_info(get_type_name(), $sformatf("mode:%0s, addr:%0d, wdata:%0d, rdata:%0d, slverr:%0d",tr.op.name(),tr.PADDR,tr.PWDATA,tr.PRDATA,tr.PSLVERR), UVM_NONE);
				
				@(negedge vif.pready);
				vif.penable <= 1'b0;
				tr.PSLVERR = vif.pslverr;   
			end
			if(tr.op == read)begin 
				vif.psel <= 1'b1;
				vif.paddr <= tr.PADDR;
				vif.presetn <= 1'b1;
				vif.pwrite <= 1'b0;
				@(posedge vif.pclk);
				vif.penable <= 1'b1;
				
				`uvm_info(get_type_name(), $sformatf("mode:%0s, addr:%0d, wdata:%0d, rdata:%0d, slverr:%0d",tr.op.name(),tr.PADDR,tr.PWDATA,tr.PRDATA,tr.PSLVERR), UVM_NONE);  //watch enum print format specifier
				
				@(negedge vif.pready);
				vif.penable <= 1'b0;
				tr.PRDATA = vif.prdata;   // getting data in the packet
				tr.PSLVERR = vif.pslverr; 
			end
			
			seq_item_port.item_done(); // telling done
			
		end
	endtask
	
	virtual task run_phase(uvm_phase phase);
		drive();
	endtask
	
endclass

////////////////////// MONITOR ///////////////////////

class monitor extends uvm_monitor; 

	`uvm_component_utils(monitor);
	
	uvm_analysis_port#(transaction) send;
	transaction tr;
	virtual apb_if vif;
	
  	function new(input string path = "monitor", uvm_component parent = null);
		super.new(path,parent);
	endfunction
	
  	virtual function void build_phase(uvm_phase phase); 
		super.build_phase(phase);
		tr = transaction::type_id::create("tr");
		send = new("send",this);
		
      if(!uvm_config_db#(virtual apb_if)::get(this,"","vif",vif))    //this.vif = top.....vif
          `uvm_error(get_type_name(),"Failed to get virtual interface");
  	endfunction
	
	virtual task run_phase(uvm_phase phase);
		forever begin
			@(posedge vif.pclk);
			if(!vif.presetn)begin  //why active high ??
				tr.op = rst;
				`uvm_info(get_type_name(),"SYSTEM RESET DETECTED",UVM_NONE);
				send.write(tr); //putting transaction in the send port	
			end
			else if(vif.presetn && vif.pwrite)begin
				@(negedge vif.pready);
				tr.op = writed;
				tr.PWDATA = vif.pwdata;
				tr.PADDR = vif.paddr;
				tr.PSLVERR = vif.pslverr;
				
				`uvm_info(get_type_name(),$sformatf("DATA WRITE addr=%0h data=%0d slverr=%0d", tr.PADDR, tr.PWDATA, tr.PSLVERR),UVM_NONE);
				send.write(tr);
			end
			else if(vif.presetn && !vif.pwrite)begin
				@(negedge vif.pready);
				tr.op = read;
				
				tr.PADDR = vif.paddr;
				tr.PSLVERR = vif.pslverr;
				tr.PRDATA = vif.prdata;
				
				`uvm_info(get_type_name(),$sformatf("DATA READ addr=%0h data=%0d slverr=%0d", tr.PADDR, tr.PRDATA, tr.PSLVERR),UVM_NONE);
				send.write(tr);
			end
		end	
	endtask
	
endclass
///////////////////// SCOREBOARD ///////////////////////

class scoreboard extends uvm_scoreboard;
	`uvm_component_utils(scoreboard);
	
	uvm_analysis_imp#(transaction,scoreboard) recv;  
	
  bit [31:0] arr[32] = '{default:0}; //making array of 32 address space with width 32bit and initializing with 0
	bit [31:0] addr = 0;
	bit [31:0] data_rd = 0;
	
	
	function new(string name = "scoreboard", uvm_component parent = null);
		super.new(name,parent);
	endfunction
	
  	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		recv = new("recv",this);
	endfunction
	
	virtual function void write(transaction tr);  
      	if(tr.op == rst)begin
			`uvm_info(get_type_name(), "SYSTEM RESET DETECTED", UVM_NONE);
      	end
		else if(tr.op == writed) begin
			if(tr.PSLVERR == 1'b1) `uvm_info(get_type_name(),"SLV error encountered while write",UVM_NONE) //TODO : find when slverr comes
			else begin
				arr[tr.PADDR] = tr.PWDATA ;
              `uvm_info(get_type_name(),$sformatf("DATA WRITE OP addr:%0h , wdata:%0d, arr_wr:%0d",tr.PADDR, tr.PWDATA, arr[tr.PADDR]),UVM_NONE);
			end		
		end
		else if(tr.op == read) begin
			if(tr.PSLVERR == 1'b1) `uvm_info(get_type_name(),"SLV error encountered while read",UVM_NONE)
			else begin
			data_rd = arr[tr.PADDR]; 
                if (data_rd == tr.PRDATA)
                    `uvm_info(get_type_name(), $sformatf("DATA MATCHED : addr:%0d, rdata:%0d data_rd_arr:%0d",tr.PADDR,tr.PRDATA,data_rd), UVM_NONE)
                else
                    `uvm_error(get_type_name(),$sformatf("TEST FAILED : addr:%0d, rdata:%0d data_rd_arr:%0d",tr.PADDR,tr.PRDATA,data_rd)) 
			end
		end
		$display("----------------------------------------------------------------");
	endfunction

endclass

//////////////////////AGENT//////////////////////////////////

class agent extends uvm_agent;
	
	`uvm_component_utils(agent)
	monitor mon;
	driver drv;
	apb_config cfg;
	uvm_sequencer#(transaction) seqr;
	
	function new(string name = "agent" , uvm_component parent = null);
      super.new(name,parent);
    endfunction
  
	virtual function void build_phase ( uvm_phase phase);
		super.build_phase(phase);
		cfg = apb_config::type_id::create("cfg");
      mon = monitor::type_id::create("mon",this);
		
		if(cfg.is_active == UVM_ACTIVE)begin
			drv = driver::type_id::create("drv",this);
          seqr = uvm_sequencer#(transaction)::type_id::create("seqr",this);
		end
	endfunction
	
	virtual function void connect_phase ( uvm_phase phase);
		super.connect_phase(phase);
		if(cfg.is_active == UVM_ACTIVE)begin
			drv.seq_item_port.connect(seqr.seq_item_export);
		end
	endfunction

endclass

/////////////ENVIRONMENT/////////////////////////////

class environment extends uvm_env;

	`uvm_component_utils(environment)
	
	function new(string name = "environment", uvm_component parent = null);
		super.new(name,parent);
	endfunction
	
	agent agnt;
	scoreboard scb;
	
  	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agnt = agent::type_id::create("agnt",this); 
		scb = scoreboard::type_id::create("scb",this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		agnt.mon.send.connect(scb.recv);
	endfunction
endclass		
///////////////////TEST///////////////////////////////

class test extends uvm_test;
	
	`uvm_component_utils(test)
  
  	environment env;
	write_read wrrd;
	write_data wdata;  
	read_data rdata;
	
	function new(string name = "test" , uvm_component parent = null);
      super.new(name,parent);
	endfunction
	
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		env    = environment::type_id::create("env",this);
		wrrd   = write_read::type_id::create("wrrd");
		wdata  = write_data::type_id::create("wdata");
		rdata  = read_data::type_id::create("rdata");
	endfunction
	
  virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			wrrd.start(env.agnt.seqr);
			#20;
		phase.drop_objection(this);
	endtask
endclass		

///////////////////TESTBENCH///////////////////////////////	
module tb;
  
  
  apb_if vif();
  
  apb_ram dut (.presetn(vif.presetn), .pclk(vif.pclk), .psel(vif.psel), .penable(vif.penable), .pwrite(vif.pwrite), .paddr(vif.paddr), .pwdata(vif.pwdata), .prdata(vif.prdata), .pready(vif.pready), .pslverr(vif.pslverr));
  
  initial begin
    vif.pclk <= 0;
  end
 
   always #10 vif.pclk <= ~vif.pclk;
 
  
  
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", vif);
    run_test("test");
   end
  
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
 
  
endmodule
