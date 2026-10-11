// risk_filter_tb.v  (Member 5 - Niket / 2025csb1446)
// Self-checking testbench for risk_filter.
//
//  DUT_A : default team settings  (QTY_W=16, PRICE_W=6, qty 1..1000, price 1..63, notional <= 50000)
//  DUT_B : small custom settings  (QTY_W=8,  PRICE_W=4, qty 2..200,  price 3..12, notional <= 1000)
//  DUT_C : "all limits open"      (QTY_W=8,  PRICE_W=4, qty 0..255,  price 0..15, notional <= 3825)
//
//  Phases
//   1. directed tests on DUT_A (Stage 1 worked example, every limit boundary, multi-reason cases,
//      the 16-bit overflow trap)
//   2. exhaustive sweep of every price (0..63) x a set of important quantities on DUT_A
//   3. exhaustive sweep of ALL 256 x 16 inputs on DUT_B and DUT_C
//   4. random test (30000 vectors) on DUT_A
//   5. wide-product check (largest possible qty*price) on DUT_A
//
//  The golden model below is written separately from the DUT: it uses 64-bit integer
//  arithmetic and if/else, not the DUT's wire expressions.
//
//  Run (from the repo root):  cd sim && iverilog -g2012 -o risk_filter.vvp ../src/risk_filter.v ../tb/risk_filter_tb.v
//        vvp risk_filter.vvp        (waveform written to sim/risk_filter.vcd)
`timescale 1ns/1ps
module risk_filter_tb;

    // ---------------- clock only used to space out the test vectors ----------------
    reg clk = 0;
    always #5 clk = ~clk;

    // ---------------- signals ----------------
    reg  [15:0] qa;  reg [5:0] pa;  wire okA; wire [2:0] rA;
    reg  [7:0]  qb;  reg [3:0] pb;  wire okB; wire [2:0] rB;
                                    wire okC; wire [2:0] rC;   // DUT_C shares qb/pb

    reg [8*28-1:0] label;          // text label visible in the waveform (set radix to ASCII)

    integer errors = 0;
    integer checks = 0;
    integer i, j, n, pr;

    // ---------------- devices under test ----------------
    risk_filter #(.QTY_W(16), .PRICE_W(6), .MIN_QTY(1), .MAX_QTY(1000),
                  .PRICE_MIN(1), .PRICE_MAX(63), .MAX_NOTIONAL(50000))
        DUT_A (.qty(qa), .price(pa), .ok(okA), .reason(rA));

    risk_filter #(.QTY_W(8), .PRICE_W(4), .MIN_QTY(2), .MAX_QTY(200),
                  .PRICE_MIN(3), .PRICE_MAX(12), .MAX_NOTIONAL(1000))
        DUT_B (.qty(qb), .price(pb), .ok(okB), .reason(rB));

    risk_filter #(.QTY_W(8), .PRICE_W(4), .MIN_QTY(0), .MAX_QTY(255),
                  .PRICE_MIN(0), .PRICE_MAX(15), .MAX_NOTIONAL(3825))
        DUT_C (.qty(qb), .price(pb), .ok(okC), .reason(rC));

    // ---------------- golden model (independent of the DUT code) ----------------
    function [2:0] golden;
        input [63:0] q, p, minq, maxq, pmin, pmax, maxn;
        reg [63:0] notional;
        reg b0, b1, b2;
        begin
            notional = q * p;                       // 64-bit math: cannot overflow
            b0 = 0; b1 = 0; b2 = 0;
            if (q < minq)         b0 = 1;
            else if (q > maxq)    b0 = 1;
            if (p < pmin)         b1 = 1;
            else if (p > pmax)    b1 = 1;
            if (notional > maxn)  b2 = 1;
            golden = {b2, b1, b0};
        end
    endfunction

    // ---------------- check helpers ----------------
    // Drive DUT_A, wait for the combinational logic to settle, compare.
    task test_a;
        input [15:0] q;
        input [5:0]  p;
        input [2:0]  exp_reason;        // expected reason supplied by hand (directed tests)
        reg   [2:0]  g;
        begin
            @(negedge clk);
            qa = q; pa = p;
            #2;
            g = golden(q, p, 1, 1000, 1, 63, 50000);
            checks = checks + 1;
            if (rA !== exp_reason || okA !== (exp_reason == 3'b000) || g !== exp_reason) begin
                errors = errors + 1;
                $display("FAIL [%0s] qty=%0d price=%0d : reason=%b ok=%b  expected reason=%b (golden %b)",
                         label, q, p, rA, okA, exp_reason, g);
            end
        end
    endtask

    // Same, but the expected value comes only from the golden model (sweeps / random).
    task auto_a;
        input [15:0] q;
        input [5:0]  p;
        reg   [2:0]  g;
        begin
            @(negedge clk);
            qa = q; pa = p;
            #2;
            g = golden(q, p, 1, 1000, 1, 63, 50000);
            checks = checks + 1;
            if (rA !== g || okA !== (g == 3'b000)) begin
                errors = errors + 1;
                $display("FAIL [%0s] qty=%0d price=%0d : reason=%b ok=%b  golden=%b", label, q, p, rA, okA, g);
            end
        end
    endtask

    task auto_bc;
        input [7:0] q;
        input [3:0] p;
        reg   [2:0] gb, gc;
        begin
            @(negedge clk);
            qb = q; pb = p;
            #2;
            gb = golden(q, p, 2, 200, 3, 12, 1000);
            gc = golden(q, p, 0, 255, 0, 15, 3825);
            checks = checks + 2;
            if (rB !== gb || okB !== (gb == 3'b000)) begin
                errors = errors + 1;
                $display("FAIL [DUT_B] qty=%0d price=%0d : reason=%b ok=%b golden=%b", q, p, rB, okB, gb);
            end
            if (rC !== gc || okC !== (gc == 3'b000)) begin
                errors = errors + 1;
                $display("FAIL [DUT_C] qty=%0d price=%0d : reason=%b ok=%b golden=%b", q, p, rC, okC, gc);
            end
        end
    endtask

    // quantities that sit on every interesting boundary of DUT_A
    // (0, 1, 2, 999, 1000, 1001, notional edges for several prices, 2000, 4096, 65535)
    reg [15:0] qlist [0:19];
    initial begin
        qlist[0]  = 0;     qlist[1]  = 1;     qlist[2]  = 2;     qlist[3]  = 49;
        qlist[4]  = 50;    qlist[5]  = 100;   qlist[6]  = 500;   qlist[7]  = 794;
        qlist[8]  = 795;   qlist[9]  = 796;   qlist[10] = 999;   qlist[11] = 1000;
        qlist[12] = 1001;  qlist[13] = 1024;  qlist[14] = 2000;  qlist[15] = 4096;
        qlist[16] = 32768; qlist[17] = 40000; qlist[18] = 65534; qlist[19] = 65535;
    end

    // ---------------- main sequence ----------------
    initial begin
        $dumpfile("risk_filter.vcd");
        $dumpvars(0, risk_filter_tb);
        label = "start"; qa = 0; pa = 0; qb = 0; pb = 0;
        repeat (3) @(negedge clk);

        // ============ Phase 1 : directed tests on DUT_A ============
        // reason bits: [2]=notional [1]=price band [0]=qty
        label = "worked example";                    // Stage 1 proposal, section 7 (500 scaled to 50)
        test_a(100, 50, 3'b000);                     // B1 100 @ 50   notional 5000
        test_a(50,  50, 3'b000);                     // B2  50 @ 50
        test_a(200, 49, 3'b000);                     // B3 200 @ 49   notional 9800
        test_a(180, 49, 3'b000);                     // S1 180 @ 49   notional 8820

        label = "qty lower boundary";
        test_a(0, 30, 3'b001);                       // zero qty -> bad qty
        test_a(1, 30, 3'b000);                       // MIN_QTY itself is allowed
        label = "qty upper boundary";
        test_a(999,  10, 3'b000);
        test_a(1000, 10, 3'b000);                    // MAX_QTY itself is allowed
        test_a(1001, 10, 3'b001);                    // one over -> bad qty

        label = "price lower boundary";
        test_a(10, 0, 3'b010);                       // price 0 -> outside band
        test_a(10, 1, 3'b000);                       // PRICE_MIN itself allowed
        label = "price upper boundary";
        test_a(10, 62, 3'b000);
        test_a(10, 63, 3'b000);                      // PRICE_MAX itself allowed (6-bit max)

        label = "notional boundary";
        // price 50: 1000*50 = 50000 -> exactly the limit -> allowed
        test_a(1000, 50, 3'b000);                    // EXACTLY 50000 : OK
        test_a(1000, 51, 3'b100);                    // 51000 > 50000 : notional too large
        test_a(999,  50, 3'b000);                    // 49950
        // price 63: 794*63 = 50022 (>50000), 793*63 = 49959 (ok)
        test_a(793, 63, 3'b000);
        test_a(794, 63, 3'b100);
        // price 25: 1000*25 = 25000 fine
        test_a(1000, 25, 3'b000);

        label = "multiple reasons";
        test_a(0,    0,  3'b011);                    // bad qty + bad price (notional 0 is fine)
        test_a(2000, 40, 3'b101);                    // bad qty + notional 80000
        test_a(65535, 1, 3'b101);                    // bad qty + notional 65535
        test_a(1001, 0,  3'b011);                    // bad qty + bad price
        test_a(0,    63, 3'b001);                    // only bad qty (0 * 63 = 0)
        test_a(1001, 63, 3'b101);                    // bad qty + notional 63063

        label = "16-bit overflow trap";
        // 2000 * 40 = 80000. If the product were kept in 16 bits it would wrap to 14464 (<50000)
        // and the notional check would WRONGLY pass. Full-width product must flag it.
        test_a(2000, 40, 3'b101);
        // 4096 * 16 = 65536 -> wraps to exactly 0 in 16 bits (!) : must still be flagged
        test_a(4096, 16, 3'b101);
        // 65535 * 63 = 4128705 needs 22 bits: must be flagged, not wrapped
        test_a(65535, 63, 3'b101);

        label = "bad qty and bad price";
        test_a(0, 0, 3'b011);                        // (notional 0) -> bits 0,1 only
        test_a(65535, 0, 3'b011);                    // price 0 => notional 0 -> bits 0,1

        // ============ Phase 2 : price sweep on DUT_A ============
        label = "sweep price x qty list";
        for (i = 0; i < 20; i = i + 1)
            for (j = 0; j < 64; j = j + 1)
                auto_a(qlist[i], j[5:0]);

        // ============ Phase 3 : exhaustive sweep on small DUTs ============
        label = "exhaustive B and C";
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                auto_bc(i[7:0], j[3:0]);

        // ============ Phase 4 : random on DUT_A ============
        label = "random";
        for (n = 0; n < 30000; n = n + 1) begin
            case ($urandom % 4)
                0: auto_a($urandom, $urandom);                    // fully random
                1: auto_a($urandom % 1100, $urandom);             // around the qty limits
                2: begin                                          // hugging the notional limit
                       pr = ($urandom % 63) + 1;                  // price 1..63
                       auto_a(50000 / pr + ($urandom % 5) - 2, pr);
                   end
                3: auto_a($urandom % 8, $urandom % 4);            // tiny values
            endcase
        end

        // ============ Phase 5 : widest product ============
        label = "widest product";
        auto_a(16'hFFFF, 6'h3F);
        auto_a(16'hFFFF, 6'h01);
        auto_a(16'h8000, 6'h3F);

        // ---------------- summary ----------------
        @(negedge clk);
        label = "done";
        $display("risk_filter_tb: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("RISK_FILTER_TB: PASS");
        else             $display("RISK_FILTER_TB: FAIL (%0d errors)", errors);
        $finish;
    end

    // safety net so a hung simulation cannot run forever
    initial begin
        #100000000;
        $display("RISK_FILTER_TB: TIMEOUT");
        $finish;
    end
endmodule
