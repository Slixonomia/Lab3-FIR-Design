`timescale 10ns / 100ps

module mul(
  input  [31:0] a,
  input  [31:0] b,
  output [63:0] result
);

// Radix-4 Booth Parameter
localparam PP_COUNT = 17;

wire [64:0] pp [PP_COUNT-1:0];

generate
  genvar i;
  for (i = 0; i < PP_COUNT; i = i + 1) begin : booth_encoder
    wire [2:0] booth_bits;
    if (i == 0) begin
      assign booth_bits = {b[1:0], 1'b0};
    end else begin
      assign booth_bits = b[2*i+1:2*i-1];
    end

  reg [33:0] pp_raw;
  always @(*) begin
    case (booth_bits)
      3'b000, 3'b111: pp_raw = 34'h0;
      3'b001, 3'b010: pp_raw = {2'b0, a, 1'b0};
      3'b011:          pp_raw = {a, 2'b0};
      3'b100:          pp_raw = {~a + 1, 2'b0};
      3'b101, 3'b110: pp_raw = {~{2'b0, a} + 1, 1'b0};
      default:        pp_raw = 34'h0;
    endcase
  end

    assign pp[i] = {31'b0, pp_raw} << (2*i);
  end
endgenerate

wire [64:0] sum_stage1 [8:0];
generate
  for (i = 0; i < 9; i = i + 1) begin : stage1
    if (2*i+1 < PP_COUNT) begin
      assign sum_stage1[i] = pp[2*i] + pp[2*i+1];
    end else begin
      assign sum_stage1[i] = pp[2*i];
    end
  end
endgenerate


wire [64:0] sum_stage2 [4:0];
generate
  for (i = 0; i < 5; i = i + 1) begin : stage2
    if (2*i+1 < 9) begin
      assign sum_stage2[i] = sum_stage1[2*i] + sum_stage1[2*i+1];
    end else begin
      assign sum_stage2[i] = sum_stage1[2*i];
    end
  end
endgenerate

wire [64:0] sum_stage3 [2:0];
generate
  for (i = 0; i < 3; i = i + 1) begin : stage3
    if (2*i+1 < 5) begin
      assign sum_stage3[i] = sum_stage2[2*i] + sum_stage2[2*i+1];
    end else begin
      assign sum_stage3[i] = sum_stage2[2*i];
    end
  end
endgenerate

wire [64:0] sum_stage4 [1:0];
generate
  for (i = 0; i < 2; i = i + 1) begin : stage4
    if (2*i+1 < 3) begin
      assign sum_stage4[i] = sum_stage3[2*i] + sum_stage3[2*i+1];
    end else begin
      assign sum_stage4[i] = sum_stage3[2*i];
    end
  end
endgenerate

wire [64:0] final_sum = sum_stage4[0] + sum_stage4[1];
assign result = final_sum[63:0];

endmodule
