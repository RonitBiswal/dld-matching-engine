`timescale 1ns/1ps

module matching_engine_top_tb;

    localparam PRICE_W = 6, QTY_W = 16, ID_W = 16, SLOTS = 16;
    localparam MIN_QTY = 1, MAX_QTY = 1000, PRICE_MIN = 1, PRICE_MAX = 60, MAX_NOTIONAL = 50000;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    reg                in_valid = 0;
    reg  [ID_W-1:0]    in_id    = 0;
    reg                in_side  = 0;
    reg  [PRICE_W-1:0] in_price = 0;
    reg  [QTY_W-1:0]   in_qty   = 0;

    wire                   in_ready, trade_valid, done_pulse, reject_valid;
    wire [PRICE_W-1:0]     trade_price, best_bid, best_ask;
    wire [QTY_W-1:0]       trade_qty;
    wire [ID_W-1:0]        trade_buy_id, trade_sell_id;
    wire [3:0]             reject_code;
    wire                   best_bid_valid, best_ask_valid;
    wire [$clog2(SLOTS):0] free_count;
    wire [2:0]             fsm_state;
    wire                   err_flag;

    matching_engine_top #(
        .PRICE_W(PRICE_W),
        .QTY_W(QTY_W),
        .ID_W(ID_W),
        .SLOTS(SLOTS),
        .MIN_QTY(MIN_QTY),
        .MAX_QTY(MAX_QTY),
        .PRICE_MIN(PRICE_MIN),
        .PRICE_MAX(PRICE_MAX),
        .MAX_NOTIONAL(MAX_NOTIONAL)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_id(in_id),
        .in_side(in_side),
        .in_price(in_price),
        .in_qty(in_qty),
        .trade_valid(trade_valid),
        .trade_price(trade_price),
        .trade_qty(trade_qty),
        .trade_buy_id(trade_buy_id),
        .trade_sell_id(trade_sell_id),
        .done_pulse(done_pulse),
        .reject_valid(reject_valid),
        .reject_code(reject_code),
        .best_bid(best_bid),
        .best_bid_valid(best_bid_valid),
        .best_ask(best_ask),
        .best_ask_valid(best_ask_valid),
        .free_count(free_count),
        .fsm_state(fsm_state),
        .err_flag(err_flag)
    );

    integer errors = 0, checks = 0;

    integer g_valid [0:SLOTS-1];
    integer g_side  [0:SLOTS-1];
    integer g_price [0:SLOTS-1];
    integer g_qty   [0:SLOTS-1];
    integer g_id    [0:SLOTS-1];
    integer g_seq   [0:SLOTS-1];
    integer g_seqc;

    integer e_cnt, e_kind, e_code;
    integer e_p [0:127];
    integer e_q [0:127];
    integer e_b [0:127];
    integer e_s [0:127];

    task g_reset;
        integer i;
        begin
            for (i = 0; i < SLOTS; i = i + 1)
                g_valid[i] = 0;
            g_seqc = 0;
        end
    endtask

    function integer g_active;
        input dummy;
        integer i;
        begin
            g_active = 0;
            for (i = 0; i < SLOTS; i = i + 1) begin
                if (g_valid[i])
                    g_active = g_active + 1;
            end
        end
    endfunction

    task g_process;
        input integer id, side, price, qty;
        integer rem, i, best, tq, rc, notional, keep, j;
        begin
            e_cnt  = 0;
            e_kind = 1;
            e_code = 0;
            rc     = 0;

            if (qty < MIN_QTY || qty > MAX_QTY)
                rc = rc | 1;
            if (price < PRICE_MIN || price > PRICE_MAX)
                rc = rc | 2;

            notional = price * qty;
            if (notional > MAX_NOTIONAL)
                rc = rc | 4;

            if (rc != 0) begin
                e_kind = 2;
                e_code = rc;
            end else begin
                rem  = qty;
                keep = 1;

                while (rem > 0 && keep) begin
                    best = -1;

                    for (i = 0; i < SLOTS; i = i + 1) begin
                        if (g_valid[i] && g_side[i] != side) begin
                            if (best < 0) begin
                                best = i;
                            end else if (side == 1) begin
                                if (g_price[i] < g_price[best] ||
                                   (g_price[i] == g_price[best] && g_seq[i] < g_seq[best]))
                                    best = i;
                            end else begin
                                if (g_price[i] > g_price[best] ||
                                   (g_price[i] == g_price[best] && g_seq[i] < g_seq[best]))
                                    best = i;
                            end
                        end
                    end

                    if (best < 0) begin
                        keep = 0;
                    end else if ((side == 1 && price >= g_price[best]) ||
                                 (side == 0 && price <= g_price[best])) begin
                        if (rem < g_qty[best])
                            tq = rem;
                        else
                            tq = g_qty[best];

                        e_p[e_cnt] = g_price[best];
                        e_q[e_cnt] = tq;

                        if (side == 1) begin
                            e_b[e_cnt] = id;
                            e_s[e_cnt] = g_id[best];
                        end else begin
                            e_b[e_cnt] = g_id[best];
                            e_s[e_cnt] = id;
                        end

                        e_cnt = e_cnt + 1;
                        rem   = rem - tq;
                        g_qty[best] = g_qty[best] - tq;

                        if (g_qty[best] == 0)
                            g_valid[best] = 0;
                    end else begin
                        keep = 0;
                    end
                end

                if (rem > 0) begin
                    if (g_active(0) >= SLOTS) begin
                        e_kind = 2;
                        e_code = 8;
                    end else begin
                        j = 0;
                        while (g_valid[j])
                            j = j + 1;

                        g_valid[j] = 1;
                        g_side[j]  = side;
                        g_price[j] = price;
                        g_qty[j]   = rem;
                        g_id[j]    = id;
                        g_seq[j]   = g_seqc;
                        g_seqc     = g_seqc + 1;
                    end
                end
            end
        end
    endtask

    integer gb_v, gb_p, ga_v, ga_p;

    task g_best;
        integer i;
        begin
            gb_v = 0;
            gb_p = 0;
            ga_v = 0;
            ga_p = 0;

            for (i = 0; i < SLOTS; i = i + 1) begin
                if (g_valid[i]) begin
                    if (g_side[i] == 1) begin
                        if (!gb_v || g_price[i] > gb_p) begin
                            gb_v = 1;
                            gb_p = g_price[i];
                        end
                    end else begin
                        if (!ga_v || g_price[i] < ga_p) begin
                            ga_v = 1;
                            ga_p = g_price[i];
                        end
                    end
                end
            end
        end
    endtask

    integer o_cnt, o_kind, o_code, o_lat;
    integer o_p [0:127];
    integer o_q [0:127];
    integer o_b [0:127];
    integer o_s [0:127];

    integer n_orders = 0, n_trades = 0, n_rej_risk = 0, n_rej_full = 0, n_rest = 0, n_fullfill = 0;
    integer lat_min_ins = 999, lat_rej = 0, lat_full = 0, lat_1trade = 0, lat_max = 0;

    reg junk_en = 0;
    reg verbose = 0;

    function [71:0] sname;
        input [2:0] st;
        begin
            case (st)
                3'd0:    sname = "IDLE    ";
                3'd1:    sname = "VALIDATE";
                3'd2:    sname = "DISCOVER";
                3'd3:    sname = "CHECK   ";
                3'd4:    sname = "EXECUTE ";
                3'd5:    sname = "INSERT  ";
                3'd6:    sname = "DONE    ";
                default: sname = "REJECT  ";
            endcase
        end
    endfunction

    task submit;
        input integer id, side, price, qty;
        integer fin, i;
        begin
            @(negedge clk);
            while (!in_ready)
                @(negedge clk);

            in_valid = 1;
            in_id    = id;
            in_side  = side;
            in_price = price;
            in_qty   = qty;

            if (id == 101 || id == 201 || id == 301 || id == 711 ||
                id == 900 || id == 1300 || id == 1403 || id == 1401)
                $display("  [waveform marker] order %0d is presented at t=%0d ns", id, $time);

            @(negedge clk);

            if (junk_en) begin
                in_valid = 1;
                in_id    = 16'hDEAD;
                in_side  = ~side;
                in_price = 5;
                in_qty   = 7;
            end else begin
                in_valid = 0;
            end

            o_cnt = 0;
            o_lat = 1;
            fin   = 0;

            while (!fin) begin
                if (verbose) begin
                    $display("  t=%0d ns  cycle %2d  state=%0s  trade_valid=%b px=%0d qty=%0d buy=%0d sell=%0d | best_bid=%0d(%b) best_ask=%0d(%b) free=%0d",
                             $time, o_lat, sname(fsm_state), trade_valid, trade_price, trade_qty,
                             trade_buy_id, trade_sell_id,
                             best_bid, best_bid_valid, best_ask, best_ask_valid, free_count);
                end

                if (trade_valid) begin
                    o_p[o_cnt] = trade_price;
                    o_q[o_cnt] = trade_qty;
                    o_b[o_cnt] = trade_buy_id;
                    o_s[o_cnt] = trade_sell_id;
                    o_cnt = o_cnt + 1;
                end

                if (done_pulse) begin
                    o_kind = 1;
                    fin    = 1;
                end else if (reject_valid) begin
                    o_kind = 2;
                    o_code = reject_code;
                    fin    = 1;
                end else begin
                    @(negedge clk);
                    o_lat    = o_lat + 1;
                    in_valid = 0;

                    if (o_lat > 400) begin
                        errors = errors + 1;
                        $display("FAIL: timeout waiting for order %0d", id);
                        fin    = 1;
                        o_kind = 0;
                    end
                end
            end

            @(negedge clk);
            in_valid = 0;
            checks   = checks + 1;

            if (!in_ready || trade_valid || done_pulse || reject_valid) begin
                errors = errors + 1;
                $display("FAIL: order %0d: DUT not idle/quiet after completion (rdy=%b tv=%b dn=%b rj=%b)",
                         id, in_ready, trade_valid, done_pulse, reject_valid);
            end
        end
    endtask

    reg strict_reason = 1;

    task compare;
        input integer id;
        input [255:0] tag;
        integer i;
        begin
            checks = checks + 1;

            if (o_kind !== e_kind) begin
                errors = errors + 1;
                $display("FAIL [%0s] order %0d: kind exp %0d got %0d", tag, id, e_kind, o_kind);
            end

            if (o_cnt !== e_cnt) begin
                errors = errors + 1;
                $display("FAIL [%0s] order %0d: trade count exp %0d got %0d", tag, id, e_cnt, o_cnt);
            end else begin
                for (i = 0; i < e_cnt; i = i + 1) begin
                    if (o_p[i] !== e_p[i] || o_q[i] !== e_q[i] ||
                        o_b[i] !== e_b[i] || o_s[i] !== e_s[i]) begin
                        errors = errors + 1;
                        $display("FAIL [%0s] order %0d trade %0d: exp (px %0d qty %0d buy %0d sell %0d) got (px %0d qty %0d buy %0d sell %0d)",
                                 tag, id, i, e_p[i], e_q[i], e_b[i], e_s[i],
                                 o_p[i], o_q[i], o_b[i], o_s[i]);
                    end
                end
            end

            if (e_kind == 2 && o_kind == 2) begin
                if (e_code == 8) begin
                    if (o_code !== 8) begin
                        errors = errors + 1;
                        $display("FAIL [%0s] order %0d: reject code exp 8 (book full) got %0d", tag, id, o_code);
                    end
                end else if (strict_reason) begin
                    if (o_code !== e_code) begin
                        errors = errors + 1;
                        $display("FAIL [%0s] order %0d: reject code exp %0d got %0d", tag, id, e_code, o_code);
                    end
                end else begin
                    if (o_code[3] || o_code[2:0] == 0) begin
                        errors = errors + 1;
                        $display("FAIL [%0s] order %0d: risk reject code bad (%0d)", tag, id, o_code);
                    end
                end
            end

            g_best;

            if (best_bid_valid !== gb_v[0] || (gb_v && best_bid !== gb_p[PRICE_W-1:0])) begin
                errors = errors + 1;
                $display("FAIL [%0s] order %0d: best bid exp (%0d,%0d) got (%b,%0d)",
                         tag, id, gb_v, gb_p, best_bid_valid, best_bid);
            end

            if (best_ask_valid !== ga_v[0] || (ga_v && best_ask !== ga_p[PRICE_W-1:0])) begin
                errors = errors + 1;
                $display("FAIL [%0s] order %0d: best ask exp (%0d,%0d) got (%b,%0d)",
                         tag, id, ga_v, ga_p, best_ask_valid, best_ask);
            end

            if (free_count !== (SLOTS - g_active(0))) begin
                errors = errors + 1;
                $display("FAIL [%0s] order %0d: free_count exp %0d got %0d",
                         tag, id, SLOTS - g_active(0), free_count);
            end

            if (err_flag) begin
                errors = errors + 1;
                $display("FAIL [%0s] order %0d: DUT internal err_flag is set", tag, id);
            end

            n_orders = n_orders + 1;
            n_trades = n_trades + e_cnt;

            if (e_kind == 2 && e_code == 8)
                n_rej_full = n_rej_full + 1;

            if (e_kind == 2 && e_code != 8) begin
                n_rej_risk = n_rej_risk + 1;
                lat_rej    = o_lat;
            end

            if (e_kind == 2 && e_code == 8 && e_cnt == 0)
                lat_full = o_lat;

            if (e_kind == 1 && e_cnt == 0) begin
                n_rest = n_rest + 1;
                if (o_lat < lat_min_ins)
                    lat_min_ins = o_lat;
            end

            if (o_lat > lat_max)
                lat_max = o_lat;
        end
    endtask

    task order;
        input integer id, side, price, qty;
        input [255:0] tag;
        begin
            g_process(id, side, price, qty);
            submit(id, side, price, qty);
            compare(id, tag);
        end
    endtask

    task expect_trade;
        input integer idx, price, qty, buy, sell;
        begin
            checks = checks + 1;
            if (idx >= o_cnt || o_p[idx] !== price || o_q[idx] !== qty ||
                o_b[idx] !== buy || o_s[idx] !== sell) begin
                errors = errors + 1;
                $display("FAIL explicit: trade %0d expected (px %0d qty %0d buy %0d sell %0d)",
                         idx, price, qty, buy, sell);
            end
        end
    endtask

    task expect_count;
        input integer n;
        begin
            checks = checks + 1;
            if (o_cnt !== n) begin
                errors = errors + 1;
                $display("FAIL explicit: expected %0d trades got %0d", n, o_cnt);
            end
        end
    endtask

    task expect_best;
        input bv;
        input integer bp;
        input av;
        input integer ap;
        begin
            checks = checks + 1;
            if (best_bid_valid !== bv || (bv && best_bid !== bp) ||
                best_ask_valid !== av || (av && best_ask !== ap)) begin
                errors = errors + 1;
                $display("FAIL explicit: best bid/ask exp (%b,%0d)/(%b,%0d) got (%b,%0d)/(%b,%0d)",
                         bv, bp, av, ap, best_bid_valid, best_bid, best_ask_valid, best_ask);
            end
        end
    endtask

    task do_reset;
        begin
            @(negedge clk);
            rst_n    = 0;
            in_valid = 0;
            @(negedge clk);
            @(negedge clk);
            rst_n = 1;
            g_reset;
        end
    endtask

    reg [31:0] rng = 32'h2025_1268;

    task rr;
        input integer lo, hi;
        output integer v;
        begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            v = lo + (rng[30:0] % (hi - lo + 1));
        end
    endtask

    integer n, id_ctr, side_r, price_r, qty_r, kind_r, base, k;

    initial begin
`ifdef __ICARUS__
        $dumpfile("sim/matching_engine_top.vcd");
        $dumpvars(0, matching_engine_top_tb);
`endif
        g_reset;
        #22 rst_n = 1;
        repeat (2) @(negedge clk);

        checks = checks + 1;
        if (in_ready !== 1 || free_count !== SLOTS || best_bid_valid !== 0 || best_ask_valid !== 0) begin
            errors = errors + 1;
            $display("FAIL: bad state after reset");
        end

        $display("--- 1. directed tests ---");

        order(101, 1, 50, 100, "worked B1");
        expect_count(0);
        order(102, 1, 50,  50, "worked B2");
        order(103, 1, 49, 200, "worked B3");
        expect_best(1, 50, 0, 0);

        $display("trace of the worked example order S1 (SELL 180 @ 49):");
        verbose = 1;
        order(201, 0, 49, 180, "worked S1");
        verbose = 0;

        expect_count(3);
        expect_trade(0, 50, 100, 101, 201);
        expect_trade(1, 50,  50, 102, 201);
        expect_trade(2, 49,  30, 103, 201);
        expect_best(1, 49, 0, 0);
        $display("worked example latency (3 trades, incoming fully filled): %0d cycles", o_lat);
        lat_1trade = o_lat;

        order(202, 0, 49, 170, "clear B3");
        expect_count(1);
        expect_trade(0, 49, 170, 103, 202);
        expect_best(0, 0, 0, 0);

        checks = checks + 1;
        if (free_count !== SLOTS) begin
            errors = errors + 1;
            $display("FAIL: slots leaked after clearing book (%0d free)", free_count);
        end

        order(301, 0, 55, 10, "ask rests");
        expect_count(0);
        expect_best(0, 0, 1, 55);
        order(302, 1, 54, 10, "bid below ask");
        expect_count(0);
        expect_best(1, 54, 1, 55);
        $display("latency of an insert with no match: %0d cycles", o_lat);
        lat_min_ins = o_lat;

        order(303, 1, 55, 10, "exact match");
        expect_count(1);
        expect_trade(0, 55, 10, 303, 301);
        expect_best(1, 54, 0, 0);

        order(304, 0, 56, 5, "ask 56");
        order(305, 1, 60, 5, "aggressive buy");
        expect_count(1);
        expect_trade(0, 56, 5, 305, 304);

        order(306, 0, 50, 4, "aggressive sell");
        expect_count(1);
        expect_trade(0, 54, 4, 302, 306);
        expect_best(1, 54, 0, 0);

        order(307, 0, 53, 20, "sell sweeps+rests");
        expect_count(1);
        expect_trade(0, 54, 6, 302, 307);
        expect_best(0, 0, 1, 53);

        order(308, 1, 53, 4, "partial of resting");
        expect_count(1);
        expect_trade(0, 53, 4, 308, 307);
        order(309, 1, 53, 10, "finish resting");
        expect_count(1);
        expect_trade(0, 53, 10, 309, 307);
        expect_best(0, 0, 0, 0);

        order(401, 0, 40, 10, "fifo a1");
        order(402, 0, 40, 10, "fifo a2");
        order(403, 0, 40, 10, "fifo a3");
        order(404, 1, 40, 15, "fifo buy");
        expect_count(2);
        expect_trade(0, 40, 10, 404, 401);
        expect_trade(1, 40, 5, 404, 402);
        order(405, 1, 40, 20, "fifo buy2");
        expect_count(2);
        expect_trade(0, 40, 5, 405, 402);
        expect_trade(1, 40, 10, 405, 403);
        expect_best(1, 40, 0, 0);
        order(406, 0, 40, 5, "clear 405");
        expect_count(1);
        expect_best(0, 0, 0, 0);

        order(501, 0, 30, 5, "lvl30");
        order(502, 0, 31, 5, "lvl31");
        order(503, 0, 33, 5, "lvl33");
        order(504, 0, 35, 50, "lvl35");
        order(505, 1, 34, 40, "buy sweep");
        expect_count(3);
        expect_trade(0, 30, 5, 505, 501);
        expect_trade(1, 31, 5, 505, 502);
        expect_trade(2, 33, 5, 505, 503);
        expect_best(1, 34, 1, 35);

        order(506, 1, 20, 5, "bid20");
        order(507, 1, 25, 5, "bid25");
        order(508, 1, 28, 5, "bid28");
        order(509, 0, 10, 100, "sell sweep");
        expect_count(4);
        expect_trade(0, 34, 25, 505, 509);
        expect_trade(1, 28, 5, 508, 509);
        expect_trade(2, 25, 5, 507, 509);
        expect_trade(3, 20, 5, 506, 509);

        order(510, 1, 35, 110, "clear both asks");
        expect_count(2);
        expect_trade(0, 10, 60, 510, 509);
        expect_trade(1, 35, 50, 510, 504);
        expect_best(0, 0, 0, 0);

        checks = checks + 1;
        if (free_count !== SLOTS) begin
            errors = errors + 1;
            $display("FAIL: slots leaked after directed 1 (%0d free)", free_count);
        end

        order(601, 0, PRICE_MAX, 10, "ask at max");
        order(602, 1, PRICE_MIN, 10, "bid at min");
        expect_best(1, PRICE_MIN, 1, PRICE_MAX);
        order(603, 1, PRICE_MAX, 10, "hit max");
        expect_count(1);
        expect_trade(0, PRICE_MAX, 10, 603, 601);
        order(604, 0, PRICE_MIN, 10, "hit min");
        expect_count(1);
        expect_trade(0, PRICE_MIN, 10, 602, 604);
        expect_best(0, 0, 0, 0);

        $display("--- 2. risk rejects ---");
        strict_reason = 1;

        order(701, 1, 50, 0,    "qty 0");
        order(702, 1, 50, 1001, "qty > max");
        order(703, 0, 0,  5,    "price 0");
        order(704, 0, 61, 5,    "price > max");
        order(705, 1, 51, 1000, "notional only");
        order(706, 1, 50, 1000, "notional == max");
        expect_best(1, 50, 0, 0);
        order(707, 0, 50, 1000, "clear 706");
        expect_count(1);
        order(708, 1, 51, 980,  "notional 49980");
        order(709, 0, 51, 980,  "clear 708");

        order(710, 1, 45, 10, "bid 45");
        order(711, 0, 45, 0,  "reject must not trade");
        expect_count(0);
        expect_best(1, 45, 0, 0);
        order(712, 0, 45, 10, "clear 45");

        $display("--- 3. capacity ---");

        for (n = 0; n < SLOTS; n = n + 1)
            order(800 + n, 1, 10 + n, 5, "fill book");

        checks = checks + 1;
        if (free_count !== 0) begin
            errors = errors + 1;
            $display("FAIL: free_count should be 0, is %0d", free_count);
        end

        order(900, 1, 12, 5, "book full: buy");
        checks = checks + 1;
        if (o_kind !== 2 || o_code !== 8) begin
            errors = errors + 1;
            $display("FAIL: expected book-full reject, got kind %0d code %0d", o_kind, o_code);
        end

        order(901, 0, 50, 5, "book full: sell above bids -> full");
        checks = checks + 1;
        if (o_kind !== 2 || o_code !== 8) begin
            errors = errors + 1;
            $display("FAIL: expected book-full reject for SELL, got kind %0d code %0d", o_kind, o_code);
        end

        order(902, 0, 23, 20, "sell frees slots then rests");
        expect_count(3);
        expect_trade(0, 25, 5, 815, 902);
        expect_trade(1, 24, 5, 814, 902);
        expect_trade(2, 23, 5, 813, 902);
        expect_best(1, 22, 1, 23);

        order(903, 0, PRICE_MIN, 65, "sweep rest of bids");
        expect_count(13);
        order(904, 1, 23, 5, "clear the last ask");
        expect_count(1);
        expect_best(0, 0, 0, 0);

        checks = checks + 1;
        if (free_count !== SLOTS) begin
            errors = errors + 1;
            $display("FAIL: slots leaked after capacity test (%0d free)", free_count);
        end

        for (n = 0; n < SLOTS; n = n + 1)
            order(1000 + n, 0, 40 + (n % 5), 3, "refill asks");

        order(1100, 1, 44, 1000, "16-trade-ish sweep");
        expect_best(1, 44, 0, 0);
        order(1101, 0, 44, 952, "clear remaining");

        for (n = 0; n < SLOTS; n = n + 1)
            order(1200 + n, 0, 30 + n, 1, "ask ladder");

        order(1300, 1, 60, 16, "sweep 16 levels");
        expect_count(16);
        $display("16-trade sweep latency: %0d cycles", o_lat);

        checks = checks + 1;
        if (free_count !== SLOTS) begin
            errors = errors + 1;
            $display("FAIL: slots leaked after sweep (%0d free)", free_count);
        end

        $display("--- 4. handshake and reset ---");

        junk_en = 1;
        order(1401, 1, 33, 10, "junk while busy 1");
        order(1402, 0, 33, 4,  "junk while busy 2");
        expect_count(1);
        expect_trade(0, 33, 4, 1401, 1402);
        order(1403, 1, 0, 3,   "junk while rejecting");
        junk_en = 0;

        @(negedge clk);
        in_valid = 1;
        in_id    = 1500;
        in_side  = 1;
        in_price = 20;
        in_qty   = 5;
        @(negedge clk);
        in_valid = 0;
        @(negedge clk);

        rst_n = 0;
        @(negedge clk);
        @(negedge clk);
        rst_n = 1;
        g_reset;
        @(negedge clk);

        checks = checks + 1;
        if (in_ready !== 1 || free_count !== SLOTS || best_bid_valid !== 0 ||
            best_ask_valid !== 0 || trade_valid !== 0 || err_flag !== 0) begin
            errors = errors + 1;
            $display("FAIL: DUT not clean after mid-order reset");
        end

        order(1501, 1, 20, 5, "after reset");
        expect_count(0);
        expect_best(1, 20, 0, 0);
        do_reset;
        expect_best(0, 0, 0, 0);

        $display("--- 5. random streams ---");
        strict_reason = 0;
        id_ctr = 10000;

        for (n = 0; n < 1000; n = n + 1) begin
            rr(0, 99, kind_r);
            rr(0, 1, side_r);
            rr(45, 55, price_r);
            id_ctr = id_ctr + 1;

            if (kind_r < 70)
                rr(1, 30, qty_r);
            else
                rr(40, 150, qty_r);

            order(id_ctr, side_r, price_r, qty_r, "rand A");
        end
        $display("after phase A: orders %0d trades %0d risk-rej %0d full-rej %0d",
                 n_orders, n_trades, n_rej_risk, n_rej_full);
        do_reset;

        for (n = 0; n < 700; n = n + 1) begin
            rr(0, 99, kind_r);
            rr(0, 1, side_r);
            rr(1, 20, qty_r);
            id_ctr = id_ctr + 1;

            if (kind_r < 85) begin
                if (side_r == 1)
                    rr(20, 40, price_r);
                else
                    rr(41, 60, price_r);
            end else begin
                if (side_r == 1)
                    rr(41, 60, price_r);
                else
                    rr(20, 40, price_r);
            end

            order(id_ctr, side_r, price_r, qty_r, "rand B");
        end
        $display("after phase B: orders %0d trades %0d risk-rej %0d full-rej %0d",
                 n_orders, n_trades, n_rej_risk, n_rej_full);
        do_reset;

        for (n = 0; n < 1000; n = n + 1) begin
            rr(0, 9, kind_r);
            rr(0, 1, side_r);
            rr(0, 63, price_r);
            id_ctr = id_ctr + 1;

            if (kind_r < 7)
                rr(1, 30, qty_r);
            else if (kind_r < 9)
                rr(1, 1100, qty_r);
            else
                rr(0, 2, qty_r);

            order(id_ctr, side_r, price_r, qty_r, "rand C");
        end
        $display("after phase C: orders %0d trades %0d risk-rej %0d full-rej %0d",
                 n_orders, n_trades, n_rej_risk, n_rej_full);
        do_reset;

        for (n = 0; n < 600; n = n + 1) begin
            rr(0, 9, kind_r);
            rr(0, 1, side_r);
            rr(25, 45, price_r);
            id_ctr = id_ctr + 1;

            if (kind_r < 8)
                rr(1, 12, qty_r);
            else
                rr(60, 300, qty_r);

            order(id_ctr, side_r, price_r, qty_r, "rand D");
        end

        $display("");
        $display("orders sent: %0d | trades checked: %0d | risk rejects: %0d | book-full rejects: %0d | orders that only rested: %0d",
                 n_orders, n_trades, n_rej_risk, n_rej_full, n_rest);
        $display("latency (cycles, accept -> done/reject): risk reject %0d | book-full reject (no trades) %0d | insert-only %0d | 3-trade worked example %0d | max seen %0d",
                 lat_rej, lat_full, lat_min_ins, lat_1trade, lat_max);
        $display("matching_engine_top_tb: %0d checks, %0d errors", checks, errors);

        if (errors == 0)
            $display("MATCHING_ENGINE_TOP_TB: PASS");
        else
            $display("MATCHING_ENGINE_TOP_TB: FAIL");

        $finish;
    end

    initial begin
        #200000000;
        $display("MATCHING_ENGINE_TOP_TB: FAIL (global timeout)");
        $finish;
    end

endmodule
