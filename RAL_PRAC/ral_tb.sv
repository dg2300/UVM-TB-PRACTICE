// Code your testbench here
// or browse Examples
interface top_if ();
 
    logic   [31 : 0]    paddr;
    logic   [31 : 0]    pwdata;
    logic   [31 : 0]    prdata;
    logic               pwrite;
    logic               psel;
    logic               penable;
    logic               presetn;
    logic               pclk;
endinterface

 
`include "uvm_macros.svh"
import uvm_pkg::*;
 
 /////////////////Transaction Class

 class transaction extends uvm_sequence_item;
   `uvm_object_utils(transaction)
    rand bit [31:0] paddr;
    rand bit [31:0] pwdata;
         bit [31:0] prdata;
    rand bit        pwrite;

    function new(string name = "transaction");
        super.new(name);
    endfunction

    constraint c_paddr{
        paddr inside {0,4,8,12,16};
    }
 endclass

 ///////////////////Driver Class

 class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)
    transaction tr;
    virtual top_if vif;

    function new(string name = "driver", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        
        if(!uvm_config_db#(virtual top_if)::get(this,"","vif",vif))
            `uvm_error(get_type_name(),"Error getting interface")
    endfunction

    virtual task write(); //why virtual ?
        @(posedge vif.pclk);
        vif.paddr   <= tr.paddr;
        vif.pwdata  <= tr.pwdata;
        vif.pwrite  <= 1'b1;
        vif.psel    <= 1'b1;
        @(posedge vif.pclk);
        vif.penable <= 1'b1;
        `uvm_info(get_type_name(), $sformatf("Mode : Write WDATA : %0d ADDR : %0d", vif.pwdata, vif.paddr), UVM_NONE);         
         @(posedge vif.pclk);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
    endtask

     virtual task read();
        @(posedge vif.pclk);
        vif.paddr   <= tr.paddr;
        vif.pwrite  <= 1'b0;
        vif.psel    <= 1'b1;
        @(posedge vif.pclk);
        vif.penable <= 1'b1;
        `uvm_info(get_type_name(), $sformatf("Mode : Read WDATA : %0d ADDR : %0d RDATA : %0d", vif.pwdata, vif.paddr, vif.prdata), UVM_NONE);
        @(posedge vif.pclk);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        tr.prdata   = vif.prdata;
    endtask 

    virtual task run_phase(uvm_phase phase);
         bit [31:0] data;
        vif.presetn <= 1'b1;
        vif.psel <= 0;
        vif.penable <= 0;
        vif.pwrite <= 0;
        vif.paddr <= 0;
        vif.pwdata <= 0;
        forever begin
          seq_item_port.get_next_item (tr);
          if (tr.pwrite)
            begin
               write();
            end
            else 
            begin   
               read();
            end
            seq_item_port.item_done();
        end
    endtask
 endclass

////////////////////Monitor Class
 class monitor extends uvm_monitor;
    
    `uvm_component_utils(monitor)

    transaction tr;
    virtual top_if vif;

    uvm_analysis_port #(transaction) mon_send;

    function new(string name = "monitor",uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      	mon_send = new("mon_send",this);
        if(!uvm_config_db#(virtual top_if)::get(this,"","vif",vif))
            `uvm_error(get_type_name(),"Error getting intf")

        //NOT HERE//tr = transaction::type_id::create("tr");

    endfunction

    virtual task run_phase(uvm_phase phase);
        
            forever begin
              	tr = transaction::type_id::create("tr");
                @(posedge vif.pclk);
                if(vif.psel && vif.penable && vif.presetn) begin
                    tr = transaction::type_id::create("tr");
                    tr.paddr  = vif.paddr;
                    tr.pwrite = vif.pwrite;
                    if (vif.pwrite) begin
                        tr.pwdata = vif.pwdata;
                        @(posedge vif.pclk);
                        `uvm_info("MON", $sformatf("Mode : Write WDATA : %0d ADDR : %0d", vif.pwdata, vif.paddr), UVM_NONE);
                    end
                    else begin
                        @(posedge vif.pclk);
                        tr.prdata = vif.prdata;
                        `uvm_info("MON", $sformatf("Mode : Write WDATA : %0d ADDR : %0d RDATA : %0d", vif.pwdata, vif.paddr, vif.prdata), UVM_NONE); 
                    end
                  mon_send.write(tr);
                end
            end
        
    endtask
 endclass

////////////////////Scoreboard Class
 class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp#(transaction,scoreboard) sco_recv;
    //array to store
    bit [31:0] arr [17] = '{default:0};
    bit [31:0] temp;

    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sco_recv = new("sco_recv",this);
    endfunction

    virtual function void write(transaction tr);
        if(tr.pwrite == 1) begin
            arr[tr.paddr] = tr.pwdata ;
            `uvm_info(get_type_name(), $sformatf("DATA Stored Addr : %0d Data :%0d", tr.paddr, tr.pwdata), UVM_NONE)
        end 
        else begin
            if(tr.prdata == arr[tr.paddr]) 
                `uvm_info(get_type_name(), $sformatf("Test Passed -> Addr : %0d Data :%0d", tr.paddr, temp), UVM_NONE)
            else 
                `uvm_error(get_type_name(), $sformatf("Test Failed -> Addr : %0d Data :%0d", tr.paddr, temp))
        end
    endfunction
 endclass

////////////////////Agent Class
class agent extends uvm_agent;
    `uvm_component_utils(agent)

    uvm_sequencer #(transaction) seqr;
    driver drv;
    monitor mon;

  	function new(string name = "agent", uvm_component parent = null );
      super.new(name,parent);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      	seqr = uvm_sequencer#(transaction)::type_id::create("seqr",this);
        drv = driver::type_id::create("drv",this);
        mon = monitor::type_id::create("mon",this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass 

////////////////////RAL MODEL

//CNTRL REG
class cntrl_reg extends uvm_reg;
  
  `uvm_object_utils(cntrl_reg) 

    rand uvm_reg_field cntrl;

  	function new(string name = "cntrl_reg"); 
        super.new(name,4,build_coverage(UVM_NO_COVERAGE)); //size
  	endfunction

    virtual function void build();
        cntrl = uvm_reg_field::type_id::create("cntrl");
      	cntrl.configure(this, 4, 0,"RW",0,4'h0,1,1,1);
        //function void configure(		uvm_reg 	parent,
        //int 	unsigned 	size,
        //int 	unsigned 	lsb_pos,
        //string 	access,
        //bit 	volatile,
        //uvm_reg_data_t 	reset,
        //bit 	has_reset,
        //bit 	is_rand,
        //bit 	individually_accessible	)

    endfunction
endclass

//REG*_reg
class reg1_reg extends uvm_reg;
    `uvm_object_utils(reg1_reg)
    
    rand    uvm_reg_field   reg1;
   
    function new(string name = "reg1_reg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction : new
   
    virtual function void build();
        reg1     = uvm_reg_field::type_id::create("reg1");
        reg1.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction 
endclass    

class reg2_reg extends uvm_reg;
  `uvm_object_utils(reg2_reg)
    
    rand    uvm_reg_field   reg2;
   
  function new(string name = "reg2_reg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction : new
   
    virtual function void build();
        reg2     = uvm_reg_field::type_id::create("reg2");
        reg2.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction 
endclass   

class reg3_reg extends uvm_reg;
  `uvm_object_utils(reg3_reg)
    
    rand    uvm_reg_field   reg3;
   
  function new(string name = "reg3_reg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction : new
   
    virtual function void build();
      reg3     = uvm_reg_field::type_id::create("reg3");
        reg3.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction 
endclass  

class reg4_reg extends uvm_reg;
   `uvm_object_utils(reg4_reg)
    
    rand    uvm_reg_field   reg4;
   
   function new(string name = "reg4_reg");
        super.new(name, 32, build_coverage(UVM_NO_COVERAGE));
    endfunction : new
   
    virtual function void build();
      reg4     = uvm_reg_field::type_id::create("reg4");
        reg4.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
    endfunction 
endclass   

//////////////REG Block class
class reg_block extends uvm_reg_block;
    `uvm_object_utils(reg_block)  
  
    cntrl_reg cntrl_inst;
    reg1_reg  reg1_inst;
    reg2_reg  reg2_inst;
    reg3_reg  reg3_inst;
    reg4_reg  reg4_inst;

    function new(string name = "reg_block");
        super.new(name, build_coverage(UVM_NO_COVERAGE));
    endfunction : new 

    virtual function void build();
        default_map = create_map("default_map",0,4,UVM_LITTLE_ENDIAN,0);// name, base, nBytes
    // Create an address map with the specified ~name~, then
    // configures it with the following properties.
    //
    // base_addr - the base address for the map. All registers, memories,
    //             and sub-blocks within the map will be at offsets to this
    //             address
    //
    // n_bytes   - the byte-width of the bus on which this map is used 
    //
    // endian    - the endian format. See <uvm_endianness_e> for possible
    //             values
    //
    // byte_addressing - specifies whether consecutive addresses refer are 1 byte
    //             apart (TRUE) or ~n_bytes~ apart (FALSE). Default is TRUE. 
    
        cntrl_inst = cntrl_reg::type_id::create("cntrl_inst");
        cntrl_inst.build();
        cntrl_inst.configure(this,null);

        reg1_inst = reg1_reg::type_id::create("reg1_inst");
        reg1_inst.build();
        reg1_inst.configure(this,null);


        reg2_inst = reg2_reg::type_id::create("reg2_inst");
        reg2_inst.build();
        reg2_inst.configure(this,null);


        reg3_inst = reg3_reg::type_id::create("reg3_inst");
        reg3_inst.build();
        reg3_inst.configure(this,null);


        reg4_inst = reg4_reg::type_id::create("reg4_inst");
        reg4_inst.build();
        reg4_inst.configure(this,null);

      	default_map.add_reg(cntrl_inst , 'h0, "RW"); //reg , offset, access
        default_map.add_reg(reg1_inst	, 'h4, "RW");  // reg, offset, access
        default_map.add_reg(reg2_inst	, 'h8, "RW");  // reg, offset, access
        default_map.add_reg(reg3_inst	, 'hc, "RW");  // reg, offset, access
        default_map.add_reg(reg4_inst	, 'h10, "RW");  // reg, offset, access
        lock_model();

    endfunction
endclass

//////////////REG Adapter class

class top_adapter extends uvm_reg_adapter;
    `uvm_object_utils(top_adapter)

    function new (string name = "top_adapter");
      super.new (name);
    endfunction

    //when we call .write  or .read
    function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw); //watch return type
        transaction tr;
        tr = transaction::type_id::create("tr");

        tr.pwrite = (rw.kind == UVM_WRITE) ? 1'b1 : 1'b0;
        tr.paddr  = rw.addr;
        tr.pwdata = rw.data;

        //kind	Kind of access: READ or WRITE.
        //addr	The bus address.
        //data	The data to write.
        //n_bits	The number of bits of uvm_reg_item::value being transferred by this transaction.
        //byte_en	Enables for the byte lanes on the bus.
        //status	The result of the transaction: UVM_IS_OK, UVM_HAS_X, UVM_NOT_OK.

        return tr;
    endfunction

    function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        transaction tr;

        assert($cast(tr,bus_item));

        rw.kind = (tr.pwrite == 1'b1) ? UVM_WRITE : UVM_READ;
        rw.data = (tr.pwrite == 1'b1) ? tr.pwdata : tr.prdata;
        rw.addr = tr.paddr;
        rw.status = UVM_IS_OK; //TODO : explore
    endfunction
endclass

////////////////////Environment Class
class env extends uvm_env;
    `uvm_component_utils(env)
    scoreboard scb;
    agent agnt;

    //RAL components:
    reg_block regmodel;
    top_adapter adapter_inst;
    uvm_reg_predictor#(transaction) predictor_inst;

  function new(string name = "env", uvm_component parent = null );
      super.new(name,parent);
    endfunction //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scb = scoreboard::type_id::create("scb",this);
        agnt = agent::type_id::create("agnt",this);

        //Ral comps:
        regmodel = reg_block::type_id::create("reg_model",this);
        regmodel.build();

        predictor_inst = uvm_reg_predictor#(transaction)::type_id::create("predictor_inst",this); //check args
        adapter_inst = top_adapter::type_id::create("adapter_inst",,get_full_name()); //check args
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        //MON <-> SCB
        agnt.mon.mon_send.connect(scb.sco_recv);

        //MON <-> PRED TODO: understand
        agnt.mon.mon_send.connect(predictor_inst.bus_in);

        regmodel.default_map.set_sequencer(.sequencer(agnt.seqr),.adapter(adapter_inst));
        regmodel.default_map.set_base_addr(0);

        predictor_inst.map = regmodel.default_map;
        predictor_inst.adapter = adapter_inst;
    endfunction
endclass //agent extends uvm_agent

////////////////////Reg Sequence Class

class reg_rd_wr_seq extends uvm_sequence;
  `uvm_object_utils(reg_rd_wr_seq)
    
    reg_block regmodel;

    function new(string name = "reg_rd_wr_seq");
        super.new(name);
    endfunction

    task body;
        uvm_status_e status;
        uvm_reg_data_t rdata;
        bit[3:0] wdata;

        //for(int i=0; i<5;i++) begin

            //CNTRL REG
            wdata = $urandom();
            regmodel.cntrl_inst.write(status, wdata);
            `uvm_info(get_type_name(),$sformatf("Write Data of REG : %s : %0h",regmodel.cntrl_inst.get_name(),wdata),UVM_NONE);

            regmodel.cntrl_inst.read(status,rdata);
            `uvm_info(get_type_name(),$sformatf("Read Data of REG : %s : %0h",regmodel.cntrl_inst.get_name(),rdata),UVM_NONE);
        
            //REG 1
            wdata = $urandom();
            regmodel.reg1_inst.write(status, wdata);
            `uvm_info(get_type_name(),$sformatf("Write Data of REG : %s : %0h",regmodel.reg1_inst.get_name(),wdata),UVM_NONE);

            regmodel.reg1_inst.read(status,rdata);
            `uvm_info(get_type_name(),$sformatf("Read Data of REG : %s : %0h",regmodel.reg1_inst.get_name(),rdata),UVM_NONE);
        
            //REG 2
            wdata = $urandom();
            regmodel.reg2_inst.write(status, wdata);
            `uvm_info(get_type_name(),$sformatf("Write Data of REG : %s : %0h",regmodel.reg2_inst.get_name(),wdata),UVM_NONE);

            regmodel.reg2_inst.read(status,rdata);
            `uvm_info(get_type_name(),$sformatf("Read Data of REG : %s : %0h",regmodel.reg2_inst.get_name(),rdata),UVM_NONE);

            //REG 3
            wdata = $urandom();
            regmodel.reg3_inst.write(status, wdata);
            `uvm_info(get_type_name(),$sformatf("Write Data of REG : %s : %0h",regmodel.reg3_inst.get_name(),wdata),UVM_NONE);

            regmodel.reg3_inst.read(status,rdata);
            `uvm_info(get_type_name(),$sformatf("Read Data of REG : %s : %0h",regmodel.reg3_inst.get_name(),rdata),UVM_NONE);

            //REG 4
            wdata = $urandom();
            regmodel.reg4_inst.write(status, wdata);
            `uvm_info(get_type_name(),$sformatf("Write Data of REG : %s : %0h",regmodel.reg4_inst.get_name(),wdata),UVM_NONE);

            regmodel.reg4_inst.read(status,rdata);
            `uvm_info(get_type_name(),$sformatf("Read Data of REG : %s : %0h",regmodel.reg4_inst.get_name(),rdata),UVM_NONE);

        //end

    endtask
endclass

/////////////////////Test Class
class test extends uvm_test;

    `uvm_component_utils(test)
    env env_inst;
    reg_rd_wr_seq rrdwr_seq;

    function new(string name = "test", uvm_component parent = null);
        super.new(name,parent);
    endfunction //new()

  	virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env_inst = env::type_id::create("env_inst",this);
        rrdwr_seq = reg_rd_wr_seq::type_id::create("rrdwr_seq");
    endfunction

    virtual task run_phase(uvm_phase phase);
        
        phase.raise_objection(this);

        rrdwr_seq.regmodel = env_inst.regmodel ; //why ?
        rrdwr_seq.start(env_inst.agnt.seqr) ;

        phase.drop_objection(this);
    endtask
endclass 

////////////////////Module TB 

module tb;

    top_if vif();

    top dut (
        .pclk(vif.pclk),
        .presetn(vif.presetn),
        .paddr(vif.paddr),
        .pwdata(vif.pwdata),
        .psel(vif.psel),
        .pwrite(vif.pwrite),
        .penable(vif.penable),
        .prdata(vif.prdata)
    );

    initial begin
        vif.pclk <= 0;
    end

    always #5 vif.pclk = ~vif.pclk;

    initial begin
        uvm_config_db#(virtual top_if)::set(null,"*","vif",vif);
        run_test("test");
    end
    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule