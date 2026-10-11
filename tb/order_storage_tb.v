// order_storage_tb.v (Member 2 - Shalin)
// INTEGRATION test of my three modules working together the way the matching engine will use them:
//   free_list_allocator hands out a slot -> order_memory stores the order -> the BUY or SELL
//   fifo_queue (one instance per side, indexed by price) remembers arrival order.
// "fill" operations mimic the matching engine: read the head of a level, then either reduce its
// quantity (partial fill) or pop + invalidate + free (full fill).
// Part 1: the Stage 1 worked example (B1 100@50, B2 50@50, B3 200@49 ... trades) - this is the one to
//         screenshot (sim/order_storage.vcd). Part 2: 4000 random operations vs an ID-based model,
//         including a completely full book (insert rejected) and ID-lookup checks.
`timescale 1ns/1ps
module order_storage_tb;
    localparam SLOTS = 16, SW = 4, LEVELS = 64, LW = 6, IDW = 16, QW = 16;
    reg clk = 0, rst_n = 0; always #5 clk = ~clk;
    integer errors = 0;

    // ---- allocator ----
    reg alloc_en = 0, free_en = 0; reg [SW-1:0] free_slot = 0;
    wire [SW-1:0] alloc_slot; wire alloc_ok; wire [4:0] free_count;
    free_list_allocator #(.SLOTS(SLOTS)) u_fl (.clk(clk), .rst_n(rst_n), .alloc_en(alloc_en), .alloc_slot(alloc_slot),
        .alloc_ok(alloc_ok), .free_en(free_en), .free_slot(free_slot), .free_count(free_count));
    // ---- memory ----
    reg wr_en = 0, wr_side = 0, qty_wr_en = 0, inv_en = 0;
    reg [SW-1:0] wr_addr = 0, qty_wr_addr = 0, inv_addr = 0, rd_addr = 0;
    reg [IDW-1:0] wr_id = 0, lk_id = 0; reg [LW-1:0] wr_price = 0; reg [QW-1:0] wr_qty = 0, qty_wr_data = 0;
    wire [IDW-1:0] rd_id; wire rd_side, rd_valid, lk_found; wire [LW-1:0] rd_price; wire [QW-1:0] rd_qty; wire [SW-1:0] lk_addr;
    order_memory #(.DEPTH(SLOTS), .ID_W(IDW), .QTY_W(QW), .PRICE_W(LW)) u_mem (.clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_id(wr_id), .wr_side(wr_side), .wr_price(wr_price), .wr_qty(wr_qty),
        .qty_wr_en(qty_wr_en), .qty_wr_addr(qty_wr_addr), .qty_wr_data(qty_wr_data), .inv_en(inv_en), .inv_addr(inv_addr),
        .rd_addr(rd_addr), .rd_id(rd_id), .rd_side(rd_side), .rd_price(rd_price), .rd_qty(rd_qty), .rd_valid(rd_valid),
        .lk_id(lk_id), .lk_found(lk_found), .lk_addr(lk_addr));
    // ---- two queues: BUY and SELL ----
    reg push_b = 0, push_s = 0, pop_b = 0, pop_s = 0; reg [LW-1:0] push_level = 0, pop_level = 0, rd_level = 0; reg [SW-1:0] push_slot = 0;
    wire [SW-1:0] head_b, head_s; wire ne_b, ne_s, last_b, last_s;
    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) u_qb (.clk(clk), .rst_n(rst_n), .push_en(push_b), .push_level(push_level),
        .push_slot(push_slot), .pop_en(pop_b), .pop_level(pop_level), .rd_level(rd_level), .rd_head(head_b), .rd_nonempty(ne_b), .rd_last(last_b));
    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) u_qs (.clk(clk), .rst_n(rst_n), .push_en(push_s), .push_level(push_level),
        .push_slot(push_slot), .pop_en(pop_s), .pop_level(pop_level), .rd_level(rd_level), .rd_head(head_s), .rd_nonempty(ne_s), .rd_last(last_s));

    // ---------------- model, indexed by order ID (independent of slot numbers) ----------------
    reg [QW-1:0] m_qty [0:65535]; reg m_side [0:65535]; reg [LW-1:0] m_price [0:65535]; reg m_live [0:65535];
    reg [IDW-1:0] mq [0:2*LEVELS*SLOTS-1]; integer mlen [0:2*LEVELS-1];     // queue index = side*LEVELS + level
    integer live = 0, idc = 100;
    integer n_ins = 0, n_full = 0, n_part = 0, n_look = 0, n_rej = 0;
    task model_clear; integer q; begin
        for (q = 0; q < 2*LEVELS; q = q + 1) mlen[q] = 0;
        for (q = 0; q < 65536; q = q + 1) m_live[q] = 0;
        live = 0;
    end endtask

    // ---------------- operations ----------------
    // insert a new order. Returns via errors only; counts a reject if the book (all 16 slots) is full.
    task insert(input [IDW-1:0] id, input s, input [LW-1:0] p, input [QW-1:0] q); reg [SW-1:0] sl; integer qi; begin
        @(negedge clk);
        if (!alloc_ok) begin
            if (live !== SLOTS) begin errors = errors + 1; $display("FAIL alloc_ok=0 but model has %0d live", live); end
            n_rej = n_rej + 1;
        end else begin
            sl = alloc_slot;
            alloc_en = 1; wr_en = 1; wr_addr = sl; wr_id = id; wr_side = s; wr_price = p; wr_qty = q;
            push_slot = sl; push_level = p; push_b = s; push_s = !s;
            @(negedge clk);
            alloc_en = 0; wr_en = 0; push_b = 0; push_s = 0;
            qi = s * LEVELS + p;
            mq[qi*SLOTS + mlen[qi]] = id; mlen[qi] = mlen[qi] + 1;
            m_live[id] = 1; m_side[id] = s; m_price[id] = p; m_qty[id] = q; live = live + 1; n_ins = n_ins + 1;
        end
    end endtask

    // look at the head of side s / level lv and check it, then fill it: full (force_full or random) or partial
    task fill(input s, input [LW-1:0] lv, input force_full); reg [SW-1:0] hs; reg [IDW-1:0] hid; integer qi, j; reg [QW-1:0] nq; reg do_full; begin
        qi = s * LEVELS + lv;
        if (mlen[qi] > 0) begin
            hid = mq[qi*SLOTS];
            rd_level = lv; #1;
            if (s) hs = head_b; else hs = head_s;
            if (s && (ne_b !== 1 || last_b !== (mlen[qi] == 1))) begin errors = errors + 1; $display("FAIL BUY level %0d flags", lv); end
            if (!s && (ne_s !== 1 || last_s !== (mlen[qi] == 1))) begin errors = errors + 1; $display("FAIL SELL level %0d flags", lv); end
            rd_addr = hs; #1;
            if (rd_valid !== 1 || rd_id !== hid || rd_side !== s || rd_price !== lv || rd_qty !== m_qty[hid]) begin
                errors = errors + 1; $display("FAIL head of %0d/%0d: mem id=%0d q=%0d exp id=%0d q=%0d", s, lv, rd_id, rd_qty, hid, m_qty[hid]); end
            do_full = force_full || (m_qty[hid] <= 1) || (($urandom % 2) == 0);
            @(negedge clk);
            if (do_full) begin
                pop_level = lv; pop_b = s; pop_s = !s; inv_en = 1; inv_addr = hs; free_en = 1; free_slot = hs;
                @(negedge clk);
                pop_b = 0; pop_s = 0; inv_en = 0; free_en = 0;
                for (j = 0; j < mlen[qi] - 1; j = j + 1) mq[qi*SLOTS + j] = mq[qi*SLOTS + j + 1];
                mlen[qi] = mlen[qi] - 1; m_live[hid] = 0; live = live - 1; n_full = n_full + 1;
            end else begin
                nq = 1 + ($urandom % (m_qty[hid] - 1));          // 1 .. qty-1 remains
                qty_wr_en = 1; qty_wr_addr = hs; qty_wr_data = nq;
                @(negedge clk); qty_wr_en = 0;
                m_qty[hid] = nq; n_part = n_part + 1;
            end
        end
    end endtask

    // ID lookup check for one id
    task look(input [IDW-1:0] id); begin
        lk_id = id; #1;
        if (lk_found !== m_live[id]) begin errors = errors + 1; $display("FAIL lookup id=%0d found=%b exp %b", id, lk_found, m_live[id]); end
        if (m_live[id] && lk_found) begin
            rd_addr = lk_addr; #1;
            if (rd_id !== id || rd_side !== m_side[id] || rd_price !== m_price[id] || rd_qty !== m_qty[id]) begin
                errors = errors + 1; $display("FAIL lookup data id=%0d", id); end
        end
        n_look = n_look + 1;
    end endtask

    // global consistency check: slot count, every id ever used
    task audit; integer q; begin
        @(negedge clk);
        if (free_count !== SLOTS - live) begin errors = errors + 1; $display("FAIL free_count=%0d exp %0d", free_count, SLOTS - live); end
        for (q = 100; q <= idc; q = q + 1) look(q);
    end endtask

    // pick a non-empty level of a side (random start), return 1 if found
    reg found_lv; reg [LW-1:0] lvl;
    task pick_level(input s); integer st, l; begin
        found_lv = 0; st = $urandom % LEVELS;
        for (l = 0; l < LEVELS; l = l + 1) if (!found_lv && mlen[s*LEVELS + ((st + l) % LEVELS)] > 0) begin found_lv = 1; lvl = (st + l) % LEVELS; end
    end endtask

    integer t, phase, r, sd;
    reg [LW-1:0] pr;
    initial begin
        $dumpfile("sim/order_storage.vcd"); $dumpvars(0, order_storage_tb);
        model_clear; #22 rst_n = 1;
        // ---------- Part 1: Stage 1 worked example (prices scaled 500 -> 50) ----------
        insert(101, 1, 50, 100);        // B1 BUY 100 @50
        insert(102, 1, 50, 50);         // B2 BUY  50 @50   (same level, later)
        insert(103, 1, 49, 200);        // B3 BUY 200 @49
        audit;
        // incoming SELL 201 @49 qty 180 would match: B1 (100) full, B2 (50) full, B3 partial (30) -> 170 left
        fill(1, 50, 1);                 // trade 1: B1 fully filled (head of level 50 must be B1)
        fill(1, 50, 1);                 // trade 2: B2 fully filled (next head must be B2, level 50 now empty)
        rd_level = 50; #1; if (ne_b !== 0) begin errors = errors + 1; $display("FAIL level 50 should be empty"); end
        @(negedge clk); qty_wr_en = 1; qty_wr_addr = u_qb.head[49]; qty_wr_data = 170;      // trade 3: B3 200 -> 170
        @(negedge clk); qty_wr_en = 0; m_qty[103] = 170;
        audit;
        rd_addr = u_qb.head[49]; #1;
        if (rd_id !== 103 || rd_qty !== 170) begin errors = errors + 1; $display("FAIL B3 should have 170 left"); end
        else $display("worked example OK: B1,B2 removed in time order, B3 left with %0d", rd_qty);
        // resting SELL side and slot reuse
        insert(104, 0, 55, 40); insert(105, 0, 55, 60); insert(106, 0, 57, 10);
        audit;
        fill(0, 55, 1); fill(0, 55, 1); fill(0, 57, 1); fill(1, 49, 1);
        audit;
        $dumpoff;
        // ---------- Part 2: random flow ----------
        for (t = 0; t < 4000; t = t + 1) begin
            phase = (t / 300) % 3;                                 // 0 insert-heavy, 1 fill-heavy, 2 balanced
            r = $urandom % 100; sd = $urandom % 2;
            if (phase == 0) begin
                r = r / 2;                                         // mostly inserts
                if ((t % 5) == 0) r = r + 50;                      // plus an occasional fill/lookup
            end else if (phase == 1) begin
                r = 40 + r / 2;                                    // mostly fills
                if ((t % 5) != 0) r = r + 10;
            end
            if (r < 45) begin
                idc = idc + 1;
                if (($urandom % 8) == 0) pr = ($urandom % 2) * 63;      // extreme prices 0 / 63
                else                     pr = 20 + ($urandom % 8);      // dense: many orders per level
                insert(idc, sd, pr, 1 + ($urandom % 1000));
            end else if (r < 85) begin
                pick_level(sd); if (found_lv) fill(sd, lvl, 0);
            end else begin
                look(100 + ($urandom % (idc - 99)));
            end
            if (t % 50 == 49) audit;
        end
        // ---------- drain everything, book must end completely empty ----------
        for (sd = 0; sd < 2; sd = sd + 1) begin
            pick_level(sd);
            while (found_lv) begin fill(sd, lvl, 1); pick_level(sd); end
        end
        audit;
        if (live !== 0 || free_count !== SLOTS) begin errors = errors + 1; $display("FAIL not empty at end: live=%0d free=%0d", live, free_count); end
        for (r = 0; r < SLOTS; r = r + 1) begin rd_addr = r; #1; if (rd_valid !== 0) begin errors = errors + 1; $display("FAIL slot %0d still valid", r); end end
        for (r = 0; r < LEVELS; r = r + 1) begin rd_level = r; #1; if (ne_b !== 0 || ne_s !== 0) begin errors = errors + 1; $display("FAIL level %0d not empty", r); end end
        $display("stats: inserts=%0d full-fills=%0d partial-fills=%0d lookups=%0d rejected-when-full=%0d", n_ins, n_full, n_part, n_look, n_rej);
        if (n_rej == 0) begin errors = errors + 1; $display("FAIL: random test never hit a full book (coverage hole)"); end
        if (errors == 0) $display("ORDER_STORAGE_TB: PASS"); else $display("ORDER_STORAGE_TB: FAIL (%0d errors)", errors);
        $finish;
    end
    initial begin #500000000 $display("TIMEOUT"); $finish; end
endmodule
