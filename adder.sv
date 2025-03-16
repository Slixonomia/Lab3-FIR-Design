`timescale 10ns/100ps

module adder(
  input  [63:0] a,
  input  [63:0] b,
  output [63:0] sum,
  output        cout
);

wire [63:0] p = a ^ b;
wire [63:0] g = a & b;

wire [63:0] p1, g1;
assign p1[0] = p[0];
assign g1[0] = g[0];

generate
  genvar i;
    for (i=1; i<64; i=i+1) begin : stage1
      assign p1[i] = p[i] & p[i-1];
      assign g1[i] = g[i] | (p[i] & g[i-1]);
    end
  endgenerate

wire [63:0] p2, g2;
assign p2[1:0] = p1[1:0];
assign g2[1:0] = g1[1:0];
generate
  for (i=2; i<64; i=i+1) begin : stage2
    if (i % 2 == 0) begin
      assign p2[i] = p1[i] & p1[i-2];
      assign g2[i] = g1[i] | (p1[i] & g1[i-2]);
    end else begin
      assign p2[i] = p1[i];
      assign g2[i] = g1[i];
    end
  end
endgenerate

wire [63:0] p3, g3;
assign p3[3:0] = p2[3:0];
assign g3[3:0] = g2[3:0];
generate
  for (i=4; i<64; i=i+1) begin : stage3
    assign p3[i] = p2[i] & p2[i-4];
    assign g3[i] = g2[i] | (p2[i] & g2[i-4]);
  end
endgenerate

wire [63:0] p4, g4;
assign p4[7:0] = p3[7:0];
assign g4[7:0] = g3[7:0];
generate
  for (i=8; i<64; i=i+1) begin : stage4
    assign p4[i] = p3[i] & p3[i-8];
    assign g4[i] = g3[i] | (p3[i] & g3[i-8]);
  end
endgenerate

wire [63:0] p5, g5;
assign p5[15:0] = p4[15:0];
assign g5[15:0] = g4[15:0];
generate
  for (i=16; i<64; i=i+1) begin : stage5
    assign p5[i] = p4[i] & p4[i-16];
    assign g5[i] = g4[i] | (p4[i] & g4[i-16]);
  end
endgenerate

wire [63:0] p6, g6;
assign p6[31:0] = p5[31:0];
assign g6[31:0] = g5[31:0];
generate
  for (i=32; i<64; i=i+1) begin : stage6
    assign p6[i] = p5[i] & p5[i-32];
      assign g6[i] = g5[i] | (p5[i] & g5[i-32]);
  end
endgenerate

wire [63:0] carry;
assign carry[0] = 1'b0;
generate
  for (i=1; i<64; i=i+1) begin : carry_gen
    assign carry[i] = g6[i] | (p6[i] & carry[i-1]);
  end
endgenerate
  
assign cout = carry[63];
assign sum = p ^ {carry[63:1], 1'b0};

endmodule
