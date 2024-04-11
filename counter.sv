
/************************************************************************************************

---------------------------- MOD 12 COUNTER PROJECT UVM VERIFICATION-----------------------------

AUTHOR: MVS ABHIRAM

************************************************************************************************/

import uvm_pkg::*;
`include "uvm_macros.svh"

/***********************************************************************************************
---------------------------------------RTL CODE-------------------------------------------------
************************************************************************************************/

module Mod_12_loadable_up_down_counter(clk,rst,load,mode,data_in,data_out);
input clk,rst,load,mode;
input [3:0]data_in;
output reg [3:0]data_out;
always @(posedge clk) begin
        if (rst) begin
            data_out <= 4'b0000; // Reset to 0.
        end
        else if (load) begin
            data_out <= data_in; // Load new value.
        end
        else if (mode) begin
            // Increment (Up) mode, with mod-12 check
            if (data_out == 4'b1011) begin // If data_out is 11, next value should be 0.
                data_out <= 4'b0000;
            end else begin
                data_out <= data_out + 1;
            end
        end
        else begin
            // Decrement (Down) mode, with mod-12 check
            if (data_out == 4'b0000) begin // If data_out is 0, next value should be 11.
                data_out <= 4'b1011;
            end else begin
                data_out <= data_out - 1;
            end
        end
    end
endmodule


/***********************************************************************************************
---------------------------------------INTERFACE BLOCK------------------------------------------
************************************************************************************************/

interface counter_if(input bit clk);

	// Ports decleration
	bit       mode;
	bit       load;
	bit       rst;
	bit [3:0] data_in;
	bit [3:0] data_out;

	// Write Driver Clocking block
	clocking wr_drv_cb @(posedge clk);
		default input #1 output #0;
		output mode;
		output load;
		output rst;
		output data_in;
		//output data_out;
	endclocking : wr_drv_cb;

	// Write Monitor clocking block
	clocking wr_mon_cb @(posedge clk);
		default input #1 output #0;
		input mode;
		input load;
		input rst;
		input data_in;
		//output data_out;
	endclocking : wr_mon_cb

	// Read Monitor Clocking Block
	clocking rd_mon_cb @(posedge clk);
		default input #1 output #0;
		input data_out;
	endclocking: rd_mon_cb

	//Write Driver Modport decleration
	modport WR_DRV_MP (clocking wr_drv_cb);

	//Write Monitor Modport decleration
	modport WR_MON_MP (clocking wr_mon_cb);

	//Read Monnitor Modport delceration
	modport RD_MON_MP (clocking rd_mon_cb);

	modport DUV_MP (input clk,rst,load,mode,data_in, output data_out);
		
endinterface : counter_if



module counter_chip (counter_if.DUV_MP c_if);

	Mod_12_loadable_up_down_counter UUT (.clk(c_if.clk),
						.rst(c_if.rst),
						.load(c_if.load),
						.mode(c_if.mode),
						.data_out(c_if.data_out),
						.data_in(c_if.data_out));
endmodule



/***********************************************************************************************
--------------------------------------READ AGENT CONFIGURATION CLASS CODE---------------------
************************************************************************************************/

class rd_agent_config extends uvm_object;

	`uvm_object_utils(rd_agent_config)

	function new(string name = "rd_agent_config");
		super.new(name);
	endfunction

	uvm_active_passive_enum is_active = UVM_PASSIVE;
	virtual counter_if vif;

endclass: rd_agent_config



/***********************************************************************************************
--------------------------------------WRITE AGENT CONFIGURATION CLASS CODE---------------------
************************************************************************************************/

class wr_agent_config extends uvm_object;

	`uvm_object_utils(wr_agent_config)

	virtual counter_if vif;

	function new(string name ="wr_agent_config");
		super.new(name);
	endfunction

	uvm_active_passive_enum is_active = UVM_ACTIVE;

endclass: wr_agent_config



/***********************************************************************************************
---------------------------------------ENVIRONMENT CONFIGURATION CLASS CODE---------------------
************************************************************************************************/

class env_config extends uvm_object;

	`uvm_object_utils(env_config)

	function new(string name = "env_config");
		super.new(name);
	endfunction

	virtual counter_if vif;

	int has_read_agent = 1;
	int has_write_agent = 1;
	int has_score_board = 1;
	int has_virtual_sequencer = 1;

	rd_agent_config rd_agent_configh;
	wr_agent_config wr_agent_configh;

endclass : env_config

/***********************************************************************************************
--------------------------------------WRITE TRANSCTIONS CLASS CODE------------------------------
************************************************************************************************/

class write_xtn extends uvm_sequence_item;

	`uvm_object_utils(write_xtn)

	function new(string name ="write_xtn");
		super.new(name);
	endfunction

	rand bit rst;
	rand bit load;
	rand bit mode;
	rand bit [3:0] data_in;

	constraint valid_rst {rst dist {0:= 80, 1:= 20};}	
	constraint valid_load {load dist{0:= 80, 1:=20};}
	constraint valid_mode {mode dist{0:= 60, 1:=40};}
	constraint valid_data_in {data_in inside {[0:11]};}

endclass : write_xtn


/***********************************************************************************************
---------------------------------------READ TRANSCATIONS CODE-----------------------------------
************************************************************************************************/

class read_xtn extends uvm_sequence_item;

	`uvm_object_utils(read_xtn)

	function new(string name ="read_xtn");
		super.new(name);
	endfunction

	bit [3:0] data_out;

endclass : read_xtn


/***********************************************************************************************
--------------------------------------SEQUENCE CLASS CODE---------------------------------------
************************************************************************************************/

class my_seq extends uvm_sequence #(write_xtn);

	`uvm_object_utils(my_seq)

	function new(string name = "my_seq");
		super.new(name);
	endfunction

	task body();
		repeat(10) begin
			req = write_xtn::type_id::create("req");
			start_item(req);
			assert(req.randomize());
			finish_item(req);
		end
			
	endtask
endclass: my_seq


/***********************************************************************************************
--------------------------------------TOP MODULE CODE-------------------------------------------
************************************************************************************************/

module top();

	bit clock = 0;
	always #5 clock = ~clock;

	counter_if in0(clock);

	counter_chip ch(in0);

	initial begin
		uvm_config_db#(virtual counter_if)::set(null,"*","in0",in0);
		run_test("my_test");
	end

endmodule: top




/***********************************************************************************************
--------------------------------------WRITE DRIVER CLASS CODE-----------------------------------
************************************************************************************************/

class wr_driver extends uvm_driver #(write_xtn);

	`uvm_component_utils(wr_driver);

	wr_agent_config wr_cfg;

	virtual counter_if.WR_DRV_MP vif;
	
	function new(string name = "wr_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		uvm_config_db#(wr_agent_config)::get(this,"","wr_agent_config",wr_cfg);

	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		vif = wr_cfg.vif;
	endfunction

	task run_phase (uvm_phase phase);
		super.run_phase(phase);

		forever begin
			seq_item_port.get_next_item(req);
			send_to_dut(req);
			seq_item_port.item_done();
		end
	endtask

	task send_to_dut(write_xtn xtn);
		`uvm_info("WR_DRIVER",$sformatf("printing from driver \n %s", xtn.sprint()),UVM_LOW) 
	
		// Driving the data to DUV on the posedge of the clock
		@(vif.wr_drv_cb)

		vif.wr_drv_cb.rst <= xtn.rst;
		vif.wr_drv_cb.load <= xtn.load;
		vif.wr_drv_cb.mode <= xtn.mode;
		vif.wr_drv_cb.data_in <= xtn.data_in;
	endtask

	function void end_of_elaboration_phase(uvm_phase phase);
		uvm_top.print_topology();
	endfunction

endclass: wr_driver



/***********************************************************************************************
--------------------------------------WRITE MONITOR CLASS CODE----------------------------------
************************************************************************************************/

class wr_mon extends uvm_monitor;

	`uvm_component_utils(wr_mon)

	virtual counter_if.WR_MON_MP vif;
	wr_agent_config wr_cfg;

	uvm_analysis_port #(write_xtn) monitor_port;

	function new(string name ="wr_mon", uvm_component parent);
		super.new(name,parent);
		monitor_port = new("monitor_port",this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		uvm_config_db#(wr_agent_config)::get(this,"","wr_agent_config",wr_cfg);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		vif = wr_cfg.vif;
	endfunction

	task run_phase (uvm_phase phase);
		super.run_phase(phase);
		forever 
			monitor();
	endtask

	task monitor();
		write_xtn xtn;
		xtn = write_xtn::type_id::create("xtn");

		//Sampling the singnal for the dut interface
		xtn.rst <= vif.wr_mon_cb.rst;
		xtn.load <= vif.wr_mon_cb.load;
		xtn.mode <= vif.wr_mon_cb.mode;
		xtn.data_in <= vif.wr_mon_cb.data_in;
		`uvm_info("WR_MONITOR",$sformatf("printing from write monitor \n %s", xtn.sprint()),UVM_LOW)

		// Sending data to score Board
		monitor_port.write(xtn);
		
	endtask
endclass: wr_mon


/***********************************************************************************************
--------------------------------------WRITE SEQUENCER CLASS CODE--------------------------------
************************************************************************************************/

class wr_seqr extends uvm_sequencer #(write_xtn);

	`uvm_component_utils(wr_seqr)

	function new(string name ="wr_seqr",uvm_component parent);
		super.new(name,parent);
	endfunction
endclass : wr_seqr




/***********************************************************************************************
--------------------------------------READ MONITOR CLASS CODE----------------------------------
************************************************************************************************/

class rd_mon extends uvm_monitor;

	`uvm_component_utils(rd_mon)

	virtual counter_if.RD_MON_MP vif;
	rd_agent_config rd_cfg;

	uvm_analysis_port #(read_xtn) monitor_port1;

	function new(string name ="rd_mon", uvm_component parent);
		super.new(name,parent);
		monitor_port1 = new("monitor_port1",this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		uvm_config_db#(rd_agent_config)::get(this,"","rd_agent_config",rd_cfg);
	endfunction


	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		vif = rd_cfg.vif;
	endfunction

	task run_phase (uvm_phase phase);
		super.run_phase(phase);
		forever 
			monitor();
	endtask

	task monitor();
		read_xtn xtn; 
		xtn = read_xtn::type_id::create("xtn");

		//Sampling the singnal for the dut interface
		xtn.data_out <= vif.rd_mon_cb.data_out;
		//`uvm_info("RD_MONITOR",$sformatf("printing from read monitor \n %s", xtn.sprint()),UVM_LOW)
		monitor_port1.write(xtn);
	endtask
endclass: rd_mon


/***********************************************************************************************
--------------------------------------READ AGENT CLASS CODE-------------------------------------
************************************************************************************************/

class rd_agent extends uvm_agent;
	
	`uvm_component_utils(rd_agent)

	rd_agent_config rd_cfg;
	rd_mon rd_monh;

	function new(string name ="rd_agent",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		phase.raise_objection(this);

		uvm_config_db#(rd_agent_config)::get(this,"","rd_agent_config",rd_cfg);

		if(rd_cfg.is_active == UVM_PASSIVE)
			rd_monh = rd_mon::type_id::create("rd_monh",this);

		phase.drop_objection(this);
	endfunction
endclass: rd_agent


/***********************************************************************************************
--------------------------------------WRITE AGENT CLASS CODE-------------------------------------
************************************************************************************************/
class wr_agent extends uvm_agent;
	
	`uvm_component_utils(wr_agent)

	wr_driver wr_drvh;
	wr_mon wr_monh;
	wr_seqr wr_seqrh;
	wr_agent_config wr_cfg;

	function new(string name ="wr_agent",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase (uvm_phase phase);

		phase.raise_objection(this);

		uvm_config_db#(wr_agent_config)::get(this,"","wr_agent_config",wr_cfg);

		wr_monh = wr_mon::type_id::create("wr_monh",this);

		if(wr_cfg.is_active == UVM_ACTIVE) begin
			wr_drvh = wr_driver::type_id::create("wr_cfg",this);
			wr_seqrh = wr_seqr::type_id::create("wr_seqrh",this);
		end

		phase.drop_objection(this);
	endfunction

	function void connect_phasse(uvm_phase phase);
		super.connect_phase(phase);

		wr_drvh.seq_item_port.connect(wr_seqrh.seq_item_export);
	endfunction

endclass: wr_agent



/***********************************************************************************************
--------------------------------------AGENT TOP CLASS CODE--------------------------------------
************************************************************************************************/

class agent_top extends uvm_component;
	
	`uvm_component_utils(agent_top)

	env_config m_cfg;

	rd_agent rd_agenth;
	wr_agent wr_agenth;

	function new(string name = "agent_top",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		phase.raise_objection(this);

		uvm_config_db#(env_config)::get(this,"","env_config",m_cfg);

		if(m_cfg.has_read_agent) begin
			rd_agenth = rd_agent::type_id::create("rd_agenth",this); end

		if(m_cfg.has_write_agent) begin
			wr_agenth = wr_agent::type_id::create("wr_agenth",this); end

		phase.drop_objection(this);
	endfunction

	
endclass: agent_top




/***********************************************************************************************
--------------------------------------VIRTUAL SEQUENCER CLASS CODE------------------------------
************************************************************************************************/

class v_sequencer extends uvm_sequencer;

	`uvm_component_utils(v_sequencer)

	wr_seqr wr_seqrh;

	function new(string name ="v_sequencer",uvm_component parent);
		super.new(name,parent);
	endfunction

	

	
endclass : v_sequencer

/***********************************************************************************************
--------------------------------------VIRTUAL SEQUENCE CLASS CODE-------------------------------
************************************************************************************************/

class virtual_seq_base extends uvm_sequence #(uvm_sequence_item);

	`uvm_object_utils(virtual_seq_base)

	wr_seqr wr_seqrh;
	v_sequencer vseqrh;

	function new(string name ="virtual_seq");
		super.new(name);
	endfunction

	task body();
		if(!$cast(vseqrh,m_sequencer))
			`uvm_info("VIRTUAL_SEQUENCE","Casting not Successful",UVM_HIGH)
		wr_seqrh = vseqrh.wr_seqrh;
	endtask

endclass

class rand_seq extends virtual_seq_base;
	
	`uvm_object_utils(rand_seq)

	my_seq my_seqrh;

	function new(string name = "rand_seq");
		super.new(name);
	endfunction

	task body();
		super.body();
		my_seqrh.start(wr_seqrh);
	endtask

endclass : rand_seq

/***********************************************************************************************
--------------------------------------SCOREBOARD CLASS CODE-------------------------------------
************************************************************************************************/

class sb extends uvm_scoreboard;
	
	`uvm_component_utils(sb)

	uvm_tlm_analysis_fifo #(write_xtn) fifo_wr;
	uvm_tlm_analysis_fifo #(read_xtn) fifo_rd;

	write_xtn wr_data;
	read_xtn rd_data;

	static bit [3:0] data_out_sb;

	function new(string name ="sb", uvm_component parent);
		super.new(name,parent);

		fifo_wr = new("fifo_wr",this);
		fifo_rd = new("fifo_rd",this);
	endfunction

	task run_phase(uvm_phase phase);
		fork
			forever begin
				fifo_wr.get(wr_data);
				counter(wr_data);
			end
			forever begin
				fifo_rd.get(rd_data);
				check_data(rd_data);
			end
		join
	endtask

	function void counter (write_xtn wr_data);
		if (wr_data.rst) begin
            		data_out_sb <= 4'b0000; // Reset to 0.
        	end
        	else if (wr_data.load) begin
            		data_out_sb <= wr_data.data_in; // Load new value.
        	end
        	else if (wr_data.mode) begin
            	// Increment (Up) mode, with mod-12 check
            		if (data_out_sb == 4'b1011) begin // If data_out is 11, next value should be 0.
                		data_out_sb <= 4'b0000;
            		end else begin
                		data_out_sb <= data_out_sb + 1;
            		end
        	end
        	else begin
            		// Decrement (Down) mode, with mod-12 check
            		if (data_out_sb == 4'b0000) begin // If data_out is 0, next value should be 11.
                		data_out_sb <= 4'b1011;
            		end else begin
                		data_out_sb <= data_out_sb - 1;
            		end
        	end

	endfunction

	function void check_data(read_xtn rd_data);
		
		if(rd_data.data_out == data_out_sb) begin
			`uvm_info("SB","Data Matched Successful",UVM_HIGH)
			$display("Read Monitor data out %0d",rd_data.data_out);
			$display("Reference Model data out %0d",data_out_sb);
		end
		else begin
			`uvm_info("SB","Data Not Matched UN-Successful",UVM_HIGH)
			$display("Read Monitor data out %0d",rd_data.data_out);
			$display("Reference Model data out %0d",data_out_sb);		
		end	 		
	endfunction
endclass: sb


/***********************************************************************************************
--------------------------------------ENVIRONMENT CLASS CODE------------------------------------
************************************************************************************************/

class my_env extends uvm_env;

	`uvm_component_utils(my_env)

	v_sequencer v_seqrh;

	env_config m_cfg;

	agent_top agent_toph;
	rd_agent rd_agenth;
	wr_agent wr_agenth;
	sb sbh;

	function new(string name ="my_env", uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		phase.raise_objection(this);

		uvm_config_db#(env_config)::get(this,"","env_config",m_cfg);

		agent_toph = agent_top::type_id::create("agent_toph",this);

		if(m_cfg.has_read_agent) begin
			//rd_agenth = rd_agent::type_id::create("rd_agenth",this);
			uvm_config_db#(rd_agent_config)::set(this,"*","rd_agent_config",m_cfg.rd_agent_configh);
		end

		if(m_cfg.has_write_agent) begin
			//wr_agenth = wr_agent::type_id::create("wr_agenth",this);
			uvm_config_db#(wr_agent_config)::set(this,"*","wr_agent_config",m_cfg.wr_agent_configh);
		end

		if(m_cfg.has_score_board)
			sbh = sb::type_id::create("sbh",this);

		if(m_cfg.has_virtual_sequencer)
			v_seqrh = v_sequencer::type_id::create("v_seqrh",this);

	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		
		// COnnect monitor to sb (Monitor is initiator)
		wr_agenth.wr_monh.monitor_port.connect(sbh.fifo_wr.analysis_export);
		rd_agenth.rd_monh.monitor_port1.connect(sbh.fifo_rd.analysis_export);

		// COnnect virtual sequencer handels to physical sequencers
		v_seqrh.wr_seqrh =agent_toph.wr_agenth.wr_seqrh;
	endfunction

endclass: my_env

/***********************************************************************************************
--------------------------------------TEST CLASS CODE-------------------------------------------
************************************************************************************************/
class my_test extends uvm_test;

	`uvm_component_utils(my_test)
	
	rand_seq rand_seqh;
	
	my_env envh;
	env_config m_cfg;
	rd_agent_config rd_cfg;
	wr_agent_config wr_cfg;

	function new(string name = "my_test",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		m_cfg = env_config::type_id::create("m_cfg");

		uvm_config_db#(virtual counter_if)::get(this,"","in0",m_cfg.vif);

		
		if(m_cfg.has_read_agent) begin
			rd_cfg = rd_agent_config::type_id::create("rd_cfg");
			if(!uvm_config_db#(virtual counter_if)::get(this,"","in0",rd_cfg.vif))
				`uvm_fatal("TEST","Getting virtual interface failed in test class for read config");
			m_cfg.rd_agent_configh =rd_cfg;
		end


		if (m_cfg.has_write_agent) begin
			wr_cfg = wr_agent_config::type_id::create("wr_cfg");
			if(!uvm_config_db#(virtual counter_if)::get(this,"","in0",wr_cfg.vif))
				`uvm_fatal("TEST","Getting virtual interface faild in test class for write config")
			m_cfg.wr_agent_configh = wr_cfg;
		end
		

		uvm_config_db#(env_config)::set(this,"*","env_config",m_cfg);

		envh = my_env::type_id::create("envh",this);
					
	endfunction

	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			rand_seqh = rand_seq::type_id::create("rand_seqh");
			rand_seqh.start(envh.v_seqrh);
		phase.drop_objection(this);
	endtask
endclass: my_test

	


