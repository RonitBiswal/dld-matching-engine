// price_discovery_tb.v (Member 1) - 64-level bitmap + sequential scan vs hierarchical encoder.
// This is the testbench to screenshot for the report (sim/price_discovery.vcd).
`timescale 1ns/1ps
module price_discovery_tb;
    reg clk = 0, rst_n = 0; always #5 clk = ~clk;
    integer errors = 0, t, k;
    reg set_en = 0, clr_en = 0; reg [5:0] set_idx = 0, clr_idx = 0;
    wire [63:0] bm; wire any; wire [5:0] hi, lo;
    price_bitmap #(.PRICE_W(6)) u_bm (.clk(clk), .rst_n(rst_n), .set_en(set_en), .set_idx(set_idx),
        .clr_en(clr_en), .clr_idx(clr_idx), .bitmap(bm), .any(any), .best_hi(hi), .best_lo(lo));
    reg start = 0;
    wire busy_h, done_h, found_h, busy_l, done_l, found_l; wire [5:0] idx_h, idx_l; wire [15:0] cyc_h, cyc_l;
    comparator_search #(.W(64), .DIR(1)) u_sh (.clk(clk), .rst_n(rst_n), .start(start), .bitmap(bm),
        .busy(busy_h), .done(done_h), .found(found_h), .idx(idx_h), .cycles(cyc_h));
    comparator_search #(.W(64), .DIR(0)) u_sl (.clk(clk), .rst_n(rst_n), .start(start), .bitmap(bm),
        .busy(busy_l), .done(done_l), .found(found_l), .idx(idx_l), .cycles(cyc_l));

    task setb(input [5:0] p); begin @(negedge clk); set_en = 1; set_idx = p; @(negedge clk); set_en = 0; end endtask
    task clrb(input [5:0] p); begin @(negedge clk); clr_en = 1; clr_idx = p; @(negedge clk); clr_en = 0; end endtask

    reg [5:0] gh, gl; reg ga;
    task golden; begin   // software answer from the bitmap contents
        ga = 0; gh = 0; gl = 0;
        for (k = 0; k < 64; k = k + 1) if (bm[k]) begin gh = k; ga = 1; end
        for (k = 63; k >= 0; k = k - 1) if (bm[k]) gl = k;
    end endtask

    task check_all; begin
        #1 golden;
        if (any !== ga || (ga && (hi !== gh || lo !== gl))) begin
            errors = errors + 1; $display("FAIL hierarchical: any=%b hi=%0d lo=%0d exp %b %0d %0d", any, hi, lo, ga, gh, gl); end
        @(negedge clk); start = 1; @(negedge clk); start = 0;     // run both sequential scans
        wait (!busy_h && !busy_l); @(negedge clk);
        if (found_h !== ga || found_l !== ga || (ga && (idx_h !== gh || idx_l !== gl))) begin
            errors = errors + 1; $display("FAIL scan: h=%0d l=%0d exp %0d %0d", idx_h, idx_l, gh, gl); end
        $display("book bits=%0d | best hi=%0d lo=%0d | scan cycles: hi=%0d lo=%0d | hierarchical: 1 cycle",
                 $countones(bm), hi, lo, cyc_h, cyc_l);
    end endtask

    initial begin
        $dumpfile("sim/price_discovery.vcd"); $dumpvars(0, price_discovery_tb);
        #22 rst_n = 1;
        check_all;                                    // empty book
        setb(30); check_all;                          // single level
        setb(50); setb(7); check_all;
        setb(63); setb(0); check_all;                 // extreme levels
        clrb(63); clrb(0); check_all;
        clrb(50); clrb(7); check_all;
        clrb(30); check_all;                          // empty again
        for (t = 0; t < 150; t = t + 1) begin         // random set/clear, hierarchical vs golden
            setb($urandom % 64); if (t % 3 == 0) clrb($urandom % 64);
            #1 golden;
            if (any !== ga || (ga && (hi !== gh || lo !== gl))) begin errors = errors + 1; $display("FAIL random t=%0d", t); end
        end
        if (errors == 0) $display("PRICE_DISCOVERY_TB: PASS"); else $display("PRICE_DISCOVERY_TB: FAIL (%0d errors)", errors);
        $finish;
    end
    initial begin #50000000 $display("TIMEOUT"); $finish; end
endmodule
