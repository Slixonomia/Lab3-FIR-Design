`timescale 10ns/100ps

module mux_2to1 #(
  parameter WIDTH = 32
)(
  input  wire [WIDTH-1:0] data0,
  input  wire [WIDTH-1:0] data1,
  input  wire             sel,
  output wire [WIDTH-1:0] dout
);
  assign dout = sel ? data1 : data0;

endmodule
