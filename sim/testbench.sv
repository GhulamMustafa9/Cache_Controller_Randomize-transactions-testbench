`include "cache_transaction.sv"
`timescale 1ns/1ns
module cache_controller_tb;

reg clk =1'b0;;
reg rst_n;
reg [31:0] cpu_req_addr;
reg [127:0] cpu_req_datain;
wire [31:0] cpu_req_dataout;
reg cpu_req_rw; //1=write, 0=read
reg cpu_req_valid;

wire [31:0] mem_req_addr;
reg [127:0] mem_req_datain;
wire [127:0] mem_req_dataout;
wire mem_req_rw;
wire mem_req_valid;
reg mem_req_ready;

int state_mode;


cache_controller dut (
    .clk	       (clk),
    .rst_n             (rst_n),
    .cpu_req_addr      (cpu_req_addr),  
    .cpu_req_datain    (cpu_req_datain),
    .cpu_req_dataout   (cpu_req_dataout),
    .cpu_req_rw        (cpu_req_rw),
    .cpu_req_valid     (cpu_req_valid),
    .cache_ready       (cache_ready),   
    .mem_req_addr      (mem_req_addr),  
    .mem_req_datain    (mem_req_datain),
    .mem_req_dataout   (mem_req_dataout),
    .mem_req_rw        (mem_req_rw),
    .mem_req_valid     (mem_req_valid),
    .mem_req_ready     (mem_req_ready),
    .state_mode        (state_mode)
	);

reg [127:0] mem [2**16];
int fd_w;
	
always #5 clk = ~clk;

task reset_values ();
begin
  clk = 1'b1; rst_n = 1'b0;
  cpu_req_addr = 32'd0; cpu_req_datain = 128'd0; cpu_req_rw = 1'b0; cpu_req_valid = 1'b0; 
  mem_req_datain = 128'd0; mem_req_ready = 1'b1;
@(posedge clk) 
@(posedge clk) 
 rst_n = 1'b1;
end
endtask

task cache_write (input [31:0]addr, input [127:0]data);
begin
wait(cache_ready);
	cpu_req_addr = addr; 
	cpu_req_rw = 1'b1; 
	cpu_req_valid = 1'b1; 
	cpu_req_datain = data; 
 @(posedge clk) 
	cpu_req_addr = 32'd0; 
	cpu_req_rw = 1'b0; 
	cpu_req_valid = 1'b0; 
	cpu_req_datain = 128'd0;  
        $display (" Write data - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)", addr[31:14], addr[31:14], addr[13:4], addr[13:4], addr[3:0], addr[3:0], addr,addr,addr);	
@(posedge clk) ;

end
endtask

task cache_read (input [31:0]addr);
begin

wait(cache_ready); 
	cpu_req_addr = addr; 
	cpu_req_rw = 1'b0; 
	cpu_req_valid = 1'b1;  
@(posedge clk) 
	cpu_req_addr = 32'd0; 
	cpu_req_rw = 1'b0; 
	cpu_req_valid = 1'b0; 
@(negedge clk)
 if (state_mode == 1)  begin // HIT ;
  	 $display (" Read Hit - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)",  addr[31:14], addr[31:14], addr[13:4], addr[13:4], addr[3:0], addr[3:0], addr,addr,addr);	
@(posedge clk); 
 
end

else if (state_mode == 2 || state_mode == 3) begin 
@(negedge mem_req_valid)

if (state_mode == 2) begin // read clean
 $display (" Read Clean - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)", addr[31:14], addr[31:14], addr[13:4], addr[13:4], addr[3:0], addr[3:0], addr,addr,addr);	
	mem_req_ready = 1'b0;
  	@(posedge clk) 
	mem_req_datain <= mem[mem_req_addr];  
	mem_req_ready = 1'b1;
	@(posedge clk); 
end 
else if (state_mode == 3) begin // read dirty 
 $display (" Read Dirty - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)", addr[31:14], addr[31:14], addr[13:4], addr[13:4], addr[3:0], addr[3:0], addr,addr,addr);	
	mem_req_ready = 1'b0;  
  @(posedge clk)
	mem[mem_req_addr] <= mem_req_dataout;
	mem_req_ready = 1'b1;      
  		@(negedge mem_req_valid) 
		mem_req_ready = 1'b0;
  	@(posedge clk)
	 	mem_req_datain <= mem[mem_req_addr];; 
		mem_req_ready = 1'b1;
end
@(posedge clk);
end

end 
endtask

cache_transaction trans,tr;

initial begin
$readmemh("initial_main_memory.mem", mem);
  reset_values();

trans =new();

	repeat(10) begin
    		if( !trans.randomize() ) $fatal(" Transaction randomization failed");
    		tr = trans.do_copy();
    
	if (tr.cpu_req_rw) cache_write (tr.cpu_req_addr ,tr.cpu_req_datain);
	else cache_read  (tr.cpu_req_addr);
    
                     end


#50
fd_w = $fopen ("Result-main_memory.mem", "w"); 	// Open a new file in write mode and store file descriptor in fd_w
for (int i = 0; i < $size(mem); i++)
	$fwrite (fd_w,"%5d(%4h)	%32h\n",i,i, mem[i] );
#20 $fclose(fd_w);


end //initial end
endmodule








