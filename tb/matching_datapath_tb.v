// =============================================================================
// matching_datapath_tb.v   Self-checking testbench for compatibility_logic and
// quantity_arithmetic.  Owner: Saurabhraj (Member 3)
// Run: iverilog -g2012 -o sim/dp.vvp src/compatibility_logic.v \
//        src/quantity_arithmetic.v tb/matching_datapath_tb.v && vvp sim/dp.vvp
// =============================================================================
`timescale 1ns/1ps
module matching_datapath_tb;
    localparam PRICE_W = 6;
    localparam QTY_W   = 16;

    reg                in_side;
    reg  [PRICE_W-1:0] in_price, rest_price;
    reg                rest_valid;
    wire               can_match;

    reg  [QTY_W-1:0]   in_qty, rest_qty;
    wire [QTY_W-1:0]   trade_qty, in_rem, rest_rem;
    wire               in_done, rest_done;

    compatibility_logic #(.PRICE_W(PRICE_W)) u_cmp (
        .in_side(in_side), .in_price(in_price), .rest_price(rest_price),
        .rest_valid(rest_valid), .can_match(can_match));

    quantity_arithmetic #(.QTY_W(QTY_W)) u_qty (
        .in_qty(in_qty), .rest_qty(rest_qty), .trade_qty(trade_qty),
        .in_rem(in_rem), .rest_rem(rest_rem),
        .in_done(in_done), .rest_done(rest_done));

    integer errors = 0, checks = 0;

    // ---------- golden models (behavioural, written independently) ----------
    function golden_match(input s, input [PRICE_W-1:0] ip, rp, input v);
        begin
            if (!v) golden_match = 1'b0;
            else if (s) golden_match = (ip >= rp);
            else        golden_match = (ip <= rp);
        end
    endfunction

    // ---------- checkers ----------
    task chk_cmp(input s, input [PRICE_W-1:0] ip, rp, input v, input exp, input [255:0] name);
        begin
            in_side = s; in_price = ip; rest_price = rp; rest_valid = v;
            #1; checks = checks + 1;
            if (can_match !== exp) begin
                errors = errors + 1;
                $display("FAIL [%0s] side=%b in=%0d rest=%0d valid=%b -> %b (exp %b)",
                         name, s, ip, rp, v, can_match, exp);
            end
        end
    endtask

    task chk_qty(input [QTY_W-1:0] iq, rq, input [255:0] name);
        reg [QTY_W-1:0] et, ei, er;
        begin
            in_qty = iq; rest_qty = rq; #1;
            et = (iq < rq) ? iq : rq;
            ei = iq - et;  er = rq - et;
            checks = checks + 1;
            if (trade_qty !== et || in_rem !== ei || rest_rem !== er ||
                in_done !== (ei == 0) || rest_done !== (er == 0)) begin
                errors = errors + 1;
                $display("FAIL [%0s] in=%0d rest=%0d -> t=%0d ir=%0d rr=%0d id=%b rd=%b",
                         name, iq, rq, trade_qty, in_rem, rest_rem, in_done, rest_done);
            end
        end
    endtask

    integer i;
    reg [31:0] r;
    reg        gs, gv;
    reg [PRICE_W-1:0] gp, gr;

    initial begin
        $dumpfile("sim/matching_datapath_tb.vcd");
        $dumpvars(0, matching_datapath_tb);
        in_side = 0; in_price = 0; rest_price = 0; rest_valid = 0;
        in_qty = 0; rest_qty = 0;
        #5;

        // ---------------- compatibility: directed ----------------
        // BUY: crosses when price >= ask
        chk_cmp(1, 50, 49, 1, 1, "BUY greater");
        chk_cmp(1, 50, 50, 1, 1, "BUY equal");
        chk_cmp(1, 49, 50, 1, 0, "BUY less");
        // SELL: crosses when price <= bid
        chk_cmp(0, 49, 50, 1, 1, "SELL less");
        chk_cmp(0, 50, 50, 1, 1, "SELL equal");
        chk_cmp(0, 51, 50, 1, 0, "SELL greater");
        // empty opposite side must never match
        chk_cmp(1, 63, 0, 0, 0, "BUY empty book");
        chk_cmp(0, 0, 63, 0, 0, "SELL empty book");
        // price extremes
        chk_cmp(1, 0, 0, 1, 1, "BUY 0/0");
        chk_cmp(1, 63, 63, 1, 1, "BUY 63/63");
        chk_cmp(1, 0, 63, 1, 0, "BUY min vs max");
        chk_cmp(0, 63, 0, 1, 0, "SELL max vs min");
        chk_cmp(1, 63, 0, 1, 1, "BUY max vs min");
        chk_cmp(0, 0, 63, 1, 1, "SELL min vs max");
        // Stage 1 worked example: SELL 180@49 vs bids at 50, 50, 49
        chk_cmp(0, 49, 50, 1, 1, "worked ex lvl 50");
        chk_cmp(0, 49, 49, 1, 1, "worked ex lvl 49");
        chk_cmp(0, 49, 48, 1, 0, "worked ex stops below");

        // ---------------- compatibility: exhaustive (2*64*64*2 = 16384) ----------------
        begin : exhaust
            integer s, a, b, v;
            for (s = 0; s < 2; s = s + 1)
              for (a = 0; a < 64; a = a + 1)
                for (b = 0; b < 64; b = b + 1)
                  for (v = 0; v < 2; v = v + 1)
                    chk_cmp(s[0], a[PRICE_W-1:0], b[PRICE_W-1:0], v[0],
                            golden_match(s[0], a[PRICE_W-1:0], b[PRICE_W-1:0], v[0]),
                            "exhaustive");
        end

        // ---------------- compatibility: 500 random ----------------
        for (i = 0; i < 500; i = i + 1) begin
            r = $random;
            gs = r[0]; gv = r[1]; gp = r[8:3]; gr = r[14:9];
            chk_cmp(gs, gp, gr, gv, golden_match(gs, gp, gr, gv), "random");
        end

        // ---------------- quantity: directed ----------------
        chk_qty(180, 100, "worked trade 1");   // t=100 in_rem=80 rest_rem=0
        chk_qty(80,  50,  "worked trade 2");   // t=50  in_rem=30 rest_rem=0
        chk_qty(30,  200, "worked trade 3");   // t=30  in_rem=0  rest_rem=170
        chk_qty(100, 100, "exact fill");       // both done
        chk_qty(1,   1,   "1 vs 1");
        chk_qty(0,   0,   "0 vs 0");
        chk_qty(0,   55,  "in zero");
        chk_qty(55,  0,   "rest zero");
        chk_qty(16'hFFFF, 16'hFFFF, "max vs max");
        chk_qty(16'hFFFF, 1,        "max vs 1");
        chk_qty(1, 16'hFFFF,        "1 vs max");
        chk_qty(16'h8000, 16'h7FFF, "MSB boundary a");
        chk_qty(16'h7FFF, 16'h8000, "MSB boundary b");

        // explicit value check of the worked example
        in_qty = 180; rest_qty = 100; #1;
        checks = checks + 1;
        if (trade_qty !== 100 || in_rem !== 80 || rest_rem !== 0 || in_done !== 0 || rest_done !== 1) begin
            errors = errors + 1; $display("FAIL explicit worked example #1");
        end
        in_qty = 30; rest_qty = 200; #1;
        checks = checks + 1;
        if (trade_qty !== 30 || in_rem !== 0 || rest_rem !== 170 || in_done !== 1 || rest_done !== 0) begin
            errors = errors + 1; $display("FAIL explicit worked example #3");
        end

        // ---------------- quantity: 2000 random (mixed small/large) ----------------
        for (i = 0; i < 2000; i = i + 1) begin
            r = $random;
            if (i % 2) chk_qty(r[15:0], r[31:16], "random wide");
            else       chk_qty({12'b0, r[3:0]}, {12'b0, r[7:4]}, "random small");
        end

        // ---------------- combined sweep: simulate the 3-trade example ----------------
        begin : sweep
            reg [QTY_W-1:0] inc;
            reg [QTY_W-1:0] bids [0:2];
            reg [QTY_W-1:0] tot;
            integer k;
            bids[0] = 100; bids[1] = 50; bids[2] = 200;
            inc = 180; tot = 0;
            for (k = 0; k < 3; k = k + 1) begin
                in_qty = inc; rest_qty = bids[k]; #1;
                tot = tot + trade_qty; inc = in_rem;
                checks = checks + 1;
                if (in_done && k != 2) begin
                    errors = errors + 1; $display("FAIL sweep: finished too early");
                end
            end
            checks = checks + 1;
            if (tot !== 180 || inc !== 0) begin
                errors = errors + 1; $display("FAIL sweep: total %0d rem %0d", tot, inc);
            end
        end

        $display("--------------------------------------------");
        $display("checks run: %0d   errors: %0d", checks, errors);
        if (errors == 0) $display("matching_datapath_tb: PASS");
        else             $display("matching_datapath_tb: FAIL");
        $finish;
    end
endmodule
