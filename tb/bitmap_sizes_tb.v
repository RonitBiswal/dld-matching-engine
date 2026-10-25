`timescale 1ns/1ps
module bm_check #(parameter PW = 6) (input clk, input rst_n, output reg done, output reg [31:0] errs);
localparam L = 1 << PW;
reg set_en = 0, clr_en = 0; reg [PW-1:0] s = 0, c = 0;
wire [L-1:0] bm; wire any; wire [PW-1:0] hi, lo;
price_bitmap #(.PRICE_W(PW)) dut (.clk(clk), .rst_n(rst_n), .set_en(set_en), .set_idx(s),
.clr_en(clr_en), .clr_idx(c), .bitmap(bm), .any(any), .best_hi(hi), .best_lo(lo));
reg [L-1:0] model; integer k, t; reg [PW-1:0] gh, gl; reg ga;
task check; begin
#1; ga = 0; gh = 0; gl = 0;
for (k = 0; k < L; k = k + 1) if (model[k]) begin gh = k; ga = 1; end
for (k = L-1; k >= 0; k = k - 1) if (model[k]) gl = k;
if (bm !== model || any !== ga || (ga && (hi !== gh || lo !== gl))) begin
errs = errs + 1; $display("FAIL PW=%0d bm=%h model=%h hi=%0d/%0d lo=%0d/%0d", PW, bm, model, hi, gh, lo, gl); end
end endtask
task op(input se, input [PW-1:0] si, input ce, input [PW-1:0] ci); begin
@(negedge clk); set_en = se; s = si; clr_en = ce; c = ci;
if (se) model[si] = 1'b1;
if (ce) model[ci] = 1'b0;
@(negedge clk); set_en = 0; clr_en = 0; check;
end endtask
initial begin
errs = 0; done = 0; model = 0;
wait (rst_n === 1'b1); @(negedge clk); check;
op(1, 3, 0, 0); op(1, L-1, 0, 0); op(0, 0, 1, 3); op(0, 0, 1, L-1);
op(1, 5, 1, 5);
op(1, 5, 0, 0); op(1, 9, 1, 5);
op(0, 0, 1, 9);
for (t = 0; t < 400; t = t + 1) op($urandom % 3 != 0, $urandom % L, $urandom % 3 == 0, $urandom % L);
done = 1;
end
endmodule
module bitmap_sizes_tb;
reg clk = 0, rst_n = 0; always #5 clk = ~clk;
wire d4,d5,d6,d7; wire [31:0] e4,e5,e6,e7;
bm_check #(4) b4 (clk, rst_n, d4, e4);
bm_check #(5) b5 (clk, rst_n, d5, e5);
bm_check #(6) b6 (clk, rst_n, d6, e6);
bm_check #(7) b7 (clk, rst_n, d7, e7);
integer errors;
initial begin
$dumpfile("sim/bitmap_sizes.vcd"); $dumpvars(0, bitmap_sizes_tb);
#22 rst_n = 1;
wait (d4 && d5 && d6 && d7);
errors = e4 + e5 + e6 + e7;
if (errors == 0) $display("BITMAP_SIZES_TB: PASS (16/32/64/128 levels, same-cycle set/clr)"); else $display("BITMAP_SIZES_TB: FAIL (%0d errors)", errors);
$finish;
end
initial begin #50000000 $display("TIMEOUT"); $finish; end
endmodule
