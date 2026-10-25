`timescale 1ns/1ps
module enc_check #(parameter GROUPS=8, GW=8) (output reg done, output reg [31:0] errs);
localparam N = GROUPS*GW, IW = $clog2(N);
reg [N-1:0] in; wire [IW-1:0] idx; wire valid;
hier_priority_encoder #(.GROUPS(GROUPS), .GW(GW)) dut (.in(in), .idx(idx), .valid(valid));
integer k, t; reg [IW-1:0] exp_i; reg exp_v;
task chk; begin
#1; exp_v = 0; exp_i = 0;
for (k = 0; k < N; k = k + 1) if (in[k]) begin exp_v = 1; exp_i = k; end
if (valid !== exp_v || (exp_v && idx !== exp_i)) begin
errs = errs + 1; $display("FAIL N=%0d in=%h idx=%0d exp=%0d", N, in, idx, exp_i); end
end endtask
initial begin
errs = 0; done = 0;
in = 0; chk;
for (t = 0; t < N; t = t + 1) begin in = 0; in[t] = 1; chk; end
for (t = 0; t < N; t = t + 1) begin in = {N{1'b1}} >> t; chk; end
for (t = 0; t < N-1; t = t + 1) begin in = 0; in[t] = 1; in[N-1-t] = 1; chk; end
for (t = 0; t < 3000; t = t + 1) begin in = {$urandom,$urandom,$urandom,$urandom} & {$urandom,$urandom,$urandom,$urandom}; chk; end
done = 1;
end
endmodule
module hier_encoder_tb;
reg [7:0] f8; wire [2:0] i8; wire v8;
reg [3:0] f4; wire [1:0] i4; wire v4;
priority_encoder #(.W(8)) u8 (.in(f8), .idx(i8), .valid(v8));
priority_encoder #(.W(4)) u4 (.in(f4), .idx(i4), .valid(v4));
integer errors = 0, i, b; reg [2:0] e8; reg [1:0] e4;
wire d0,d1,d2,d3,d4; wire [31:0] e0,e1,e2,e3,e4_;
enc_check #(2,8)  c0 (d0,e0);
enc_check #(4,8)  c1 (d1,e1);
enc_check #(8,8)  c2 (d2,e2);
enc_check #(16,8) c3 (d3,e3);
enc_check #(4,4)  c4 (d4,e4_);
initial begin
$dumpfile("sim/hier_encoder.vcd"); $dumpvars(0, hier_encoder_tb);
for (i = 0; i < 256; i = i + 1) begin
f8 = i; #1; e8 = 0; for (b = 0; b < 8; b = b + 1) if (i[b]) e8 = b;
if (v8 !== (i != 0) || (i != 0 && i8 !== e8)) begin errors = errors + 1; $display("FAIL flat8 %0d", i); end
end
for (i = 0; i < 16; i = i + 1) begin
f4 = i; #1; e4 = 0; for (b = 0; b < 4; b = b + 1) if (i[b]) e4 = b;
if (v4 !== (i != 0) || (i != 0 && i4 !== e4)) begin errors = errors + 1; $display("FAIL flat4 %0d", i); end
end
wait (d0 && d1 && d2 && d3 && d4);
errors = errors + e0 + e1 + e2 + e3 + e4_;
if (errors == 0) $display("HIER_ENCODER_TB: PASS"); else $display("HIER_ENCODER_TB: FAIL (%0d errors)", errors);
$finish;
end
initial begin #50000000 $display("TIMEOUT"); $finish; end
endmodule
