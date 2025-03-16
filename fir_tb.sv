`timescale 10ns / 100ps

module fir_tb;

parameter CLK_PERIOD = 10;
parameter DATA_FILE = "input.dat";
parameter GOLDEN_FILE = "golden.dat";
parameter TAPS_FILE = "taps.dat";
parameter TEST_CYCLES = 3;

reg clk;
reg rst_n;
// AXI-Lite
wire awready;
reg awvalid;
reg [11:0] awaddr;
wire wready;
reg wvalid;
reg [31:0] wdata;
wire arready;
reg arvalid;
reg [11:0] araddr;
wire [31:0] rdata;
wire rvalid;
// AXI-Stream
reg ss_tvalid;
reg [31:0] ss_tdata;
wire ss_tready;
wire sm_tvalid;
wire [31:0] sm_tdata;

reg [31:0] input_data [0:1023];
reg [31:0] golden_data [0:1023];
reg [31:0] taps_data [0:31];
reg [31:0] output_data [0:1023];
integer data_length;
integer latency_start, latency_end;

fir_core u_fir_core (
  .clk(clk),
  .rst_n(rst_n),
  .awready(awready),
  .awvalid(awvalid),
  .awaddr(awaddr),
  .wready(wready),
  .wvalid(wvalid),
  .wdata(wdata),
  .arready(arready),
  .arvalid(arvalid),
  .araddr(araddr),
  .rdata(rdata),
  .rvalid(rvalid),
  .ss_tvalid(ss_tvalid),
  .ss_tdata(ss_tdata),
  .ss_tready(ss_tready),
  .sm_tvalid(sm_tvalid),
  .sm_tdata(sm_tdata),
  
  .tap_WE(),
  .tap_A(),
  .tap_Do(32'h0),
  
  .data_WE(),
  .data_A(),
  .data_Do(32'h0)
);

//clk
initial begin
  clk = 0;
  forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
  rst_n = 0;
  awvalid = 0; wvalid = 0; arvalid = 0;
  ss_tvalid = 0; ss_tdata = 0;
  #100 rst_n = 1;
    
  // Setup
  $readmemh(DATA_FILE, input_data);
  $readmemh(GOLDEN_FILE, golden_data);
  $readmemh(TAPS_FILE, taps_data);
  data_length = $size(input_data);
    
  program_registers();
  verify_registers();
  
  check_status(1, 0, 0);
  
  repeat(TEST_CYCLES) begin
  // Execution
  $display("===== Test Cycle %0d Start =====", $time);
  
  axilite_write(12'h00, 32'h1);
        
  latency_start = $time;
  
  fork
    stream_in_task();     // Task1
    stream_out_task();    // Task2
    axilite_monitor();    // Task3
  join
        
  $display("===== Checking Phase =====");
  // Latency
  latency_end = $time;
  $display("Latency: %0d ns", latency_end - latency_start);
  
  verify_output();
  end
    
  $display("All tests passed!");
  $finish;
end

task program_registers;
  begin
    //Tap_num
    for (int i=0; i<$size(taps_data); i++) begin
      axilite_write(12'h40 + i*4, taps_data[i]);
    end
    // Data_length
    axilite_write(12'h10, data_length);
  end
endtask

task stream_in_task;
  integer i;
  begin
    for (i=0; i<data_length; i++) begin
      @(posedge clk);
      ss_tvalid <= 1;
      ss_tdata <= input_data[i];
      wait(ss_tready);
      @(posedge clk);
      ss_tvalid <= 0;
    end
  end
endtask

task stream_out_task;
  integer i;
  begin
    for (i=0; i<data_length; i++) begin
      @(negedge clk);
      while(!sm_tvalid) @(posedge clk);
      output_data[i] = sm_tdata;
      @(posedge clk);
    end
  end
endtask

task axilite_monitor;
  begin
    forever begin
      axilite_read(12'h00);
      if (rdata[1]) begin
        disable stream_in_task;
        disable stream_out_task;
        disable axilite_monitor;
      end
      
      axilite_read(12'h40);
      if (rdata !== 32'hFFFF_FFFF)
        $error("Invalid tap read value: %h", rdata);
            
      axilite_write(12'h40, 32'hDEADBEEF);
    end
  end
endtask

//AXI Operation
task axilite_write;
  input [11:0] addr;
  input [31:0] data;
  begin
    @(posedge clk);
    awvalid <= 1;
    awaddr <= addr;
    wvalid <= 1;
    wdata <= data;
    wait(awready && wready);
    @(posedge clk);
    awvalid <= 0;
    wvalid <= 0;
  end
endtask

task axilite_read;
  input [11:0] addr;
  begin
    @(posedge clk);
    arvalid <= 1;
    araddr <= addr;
    wait(arready);
    @(posedge clk);
    arvalid <= 0;
    wait(rvalid);
  end
endtask

task verify_registers;
  begin
    axilite_read(12'h10);
    if (rdata !== data_length)
      $error("Data length mismatch! Exp:%0d Got:%0d", data_length, rdata);
    
    for (int i=0; i<$size(taps_data); i++) begin
      axilite_read(12'h40 + i*4);
      if (rdata !== taps_data[i])
      $error("Tap %0d mismatch! Exp:%h Got:%h", i, taps_data[i], rdata);
    end
  end
endtask

task check_status;
  input idle, done, start;
  begin
    axilite_read(12'h00);
    if ({rdata[2], rdata[1], rdata[0]} !== {idle, done, start})
      $error("Status error! IDLE:%b DONE:%b START:%b", rdata[2], rdata[1], rdata[0]);
  end
endtask

task verify_output;
  integer err_count;
  begin
    err_count = 0;
    for (int i=0; i<data_length; i++) begin
      if (output_data[i] !== golden_data[i]) begin
        $display("Error at output[%0d]: Exp:%h Got:%h", i, golden_data[i], output_data[i]);
        err_count++;
      end
    end
    if (err_count)
      $error("%0d mismatches found!", err_count);
    else
      $display("Output verification passed!");
  end
endtask

endmodule
