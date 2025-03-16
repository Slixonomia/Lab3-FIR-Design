`timescale 10ns / 100ps

module fir_core #(
  parameter pADDR_WIDTH = 12,
  parameter pDATA_WIDTH = 32,
  parameter Tape_Num    = 11
)(
  input  wire                     clk,
  input  wire                     rst_n,
  // AXI-Lite
  output wire                     awready,
  input  wire                     awvalid,
  input  wire [pADDR_WIDTH-1:0]   awaddr,
  output wire                     wready,
  input  wire                     wvalid,
  input  wire [pDATA_WIDTH-1:0]   wdata,
  output wire                     arready,
  input  wire                     arvalid,
  input  wire [pADDR_WIDTH-1:0]   araddr,
  output wire [pDATA_WIDTH-1:0]   rdata,
  output wire                     rvalid,
  // AXI-Stream
  input  wire                     ss_tvalid,
  input  wire [pDATA_WIDTH-1:0]   ss_tdata,
  output wire                     ss_tready,
  output wire                     sm_tvalid,
  output wire [pDATA_WIDTH-1:0]   sm_tdata,
  // BRAM
  output wire [3:0]               tap_WE,
  output wire [pADDR_WIDTH-1:0]   tap_A,
  input  wire [pDATA_WIDTH-1:0]   tap_Do,
  output wire [3:0]               data_WE,
  output wire [pADDR_WIDTH-1:0]   data_A,
  input  wire [pDATA_WIDTH-1:0]   data_Do
);

reg ap_start;
reg [pDATA_WIDTH-1:0] coeff [0:Tape_Num-1];

reg [pDATA_WIDTH-1:0] data_buf [0:Tape_Num-1];
reg [63:0] accumulator;
reg [4:0] calc_cnt;

wire [63:0] mult_result, add_result;
reg  [31:0] mult_a, mult_b;
reg  [63:0] add_a;

mul u_mult (
  .a(mult_a),
  .b(mult_b),
  .result(mult_result)
);

adder u_adder (
  .a(add_a),
  .b(mult_result),
  .sum(add_result),
  .cout()
);

reg state;
localparam IDLE = 1'b0;
localparam OPERATION = 1'b1;
reg [pDATA_WIDTH-1:0] sm_tdata_reg;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    ap_start <= 0;
    calc_cnt <= 0;
    accumulator <= 0;
    for (integer i=0; i<Tape_Num; i=i+1) begin
      coeff[i] <= 0;
      data_buf[i] <= 0;
    end
  end else begin
    case(state)
      IDLE: if (ap_start) begin
        state <= OPERATION;
        calc_cnt <= 0;
      end
            
      OPERATION: begin
        if (ss_tvalid && ss_tready) begin
          for (integer i=Tape_Num-1; i>0; i=i-1)
            data_buf[i] <= data_buf[i-1];
          data_buf[0] <= ss_tdata;
        end
                
        if (calc_cnt < Tape_Num) begin
          mult_a <= coeff[calc_cnt];
          mult_b <= data_buf[calc_cnt];
          add_a <= accumulator;
          accumulator <= add_result;
          calc_cnt <= calc_cnt + 1;
        end else begin
          sm_tdata_reg <= accumulator[63:32];
          accumulator <= 0;
          calc_cnt <= 0;
        end
      end
    endcase
  end
end
assign  sm_tdata =  sm_tdata_reg;

assign awready = (state == IDLE);
assign wready = (state == IDLE);

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    coeff[awaddr[3:2]] <= 0;
    ap_start <= 0;
  end else if (awvalid && wvalid) begin
    if (awaddr[11:4] == 8'h40)
      coeff[awaddr[3:2]] <= wdata;
    else if (awaddr == 12'h0)
      ap_start <= wdata[0];
  end
end

assign arready = 1'b1;
assign rvalid = arvalid;
assign rdata = (araddr[11:4] == 8'h40) ? coeff[araddr[3:2]] : (araddr == 12'h0) ? {31'b0, ap_start} : 32'h0;

assign tap_WE = (awvalid && wvalid && (awaddr[11:4] == 8'h40)) ? 4'b1111 : 0;
assign tap_A = awaddr;
assign data_WE = (state == OPERATION && ss_tvalid) ? 4'b1111 : 0;
assign data_A = calc_cnt;

assign ss_tready = (state == OPERATION);
assign sm_tvalid = (calc_cnt == Tape_Num);

endmodule
