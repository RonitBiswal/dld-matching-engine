// order_memory_tb.v (Member 2 - Shalin)
// Self-checking test of order_memory: directed cases, edge cases, then 3000 random operations
// compared against a behavioural model (arrays m_*). Prints PASS/FAIL. Waveform: sim/order_memory.vcd
// (dumping is switched off after the directed part so the VCD stays small and readable).
`timescale 1ns/1ps
module order_memory_tb;
    localparam DEPTH = 16, IDW = 16, QW = 16, PW = 6, AW = 4;
    reg clk = 0, rst_n = 0; always #5 clk = ~clk;
    integer errors = 0, n, a, t;

    reg               wr_en = 0; reg [AW-1:0] wr_addr = 0; reg [IDW-1:0] wr_id = 0;
    reg               wr_side = 0; reg [PW-1:0] wr_price = 0; reg [QW-1:0] wr_qty = 0;
    reg               qty_wr_en = 0; reg [AW-1:0] qty_wr_addr = 0; reg [QW-1:0] qty_wr_data = 0;
    reg               inv_en = 0; reg [AW-1:0] inv_addr = 0;
    reg  [AW-1:0]     rd_addr = 0; reg [IDW-1:0] lk_id = 0;
    wire [IDW-1:0]    rd_id; wire rd_side; wire [PW-1:0] rd_price; wire [QW-1:0] rd_qty; wire rd_valid;
    wire              lk_found; wire [AW-1:0] lk_addr;

    order_memory #(.DEPTH(DEPTH), .ID_W(IDW), .QTY_W(QW), .PRICE_W(PW)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_id(wr_id), .wr_side(wr_side), .wr_price(wr_price), .wr_qty(wr_qty),
        .qty_wr_en(qty_wr_en), .qty_wr_addr(qty_wr_addr), .qty_wr_data(qty_wr_data),
        .inv_en(inv_en), .inv_addr(inv_addr),
        .rd_addr(rd_addr), .rd_id(rd_id), .rd_side(rd_side), .rd_price(rd_price), .rd_qty(rd_qty), .rd_valid(rd_valid),
        .lk_id(lk_id), .lk_found(lk_found), .lk_addr(lk_addr));

    // ---------------- golden model ----------------
    reg [IDW-1:0] m_id [0:DEPTH-1]; reg m_side [0:DEPTH-1]; reg [PW-1:0] m_price [0:DEPTH-1];
    reg [QW-1:0]  m_qty [0:DEPTH-1]; reg m_v [0:DEPTH-1];
    task model_clear; integer q; begin
        for (q = 0; q < DEPTH; q = q + 1) begin m_id[q]=0; m_side[q]=0; m_price[q]=0; m_qty[q]=0; m_v[q]=0; end
    end endtask
    // {found, addr} of the LOWEST valid slot holding id
    function [AW:0] mfind(input [IDW-1:0] id); integer q; reg f; begin
        f = 0; mfind = 0;
        for (q = DEPTH-1; q >= 0; q = q - 1) if (m_v[q] && m_id[q] == id) begin f = 1; mfind = {1'b1, q[AW-1:0]}; end
        if (!f) mfind = 0;
    end endfunction

    // compare EVERY slot (read port) and a lookup of every valid id + the supplied probe id
    task audit(input [IDW-1:0] probe); reg [AW:0] e; integer q; begin
        for (q = 0; q < DEPTH; q = q + 1) begin
            rd_addr = q; #1;
            if (rd_valid !== m_v[q]) begin errors = errors + 1; $display("FAIL valid slot %0d: got %b exp %b", q, rd_valid, m_v[q]); end
            if (m_v[q] && (rd_id !== m_id[q] || rd_side !== m_side[q] || rd_price !== m_price[q] || rd_qty !== m_qty[q])) begin
                errors = errors + 1;
                $display("FAIL data slot %0d: got id=%0d s=%b p=%0d q=%0d  exp id=%0d s=%b p=%0d q=%0d",
                         q, rd_id, rd_side, rd_price, rd_qty, m_id[q], m_side[q], m_price[q], m_qty[q]);
            end
            if (m_v[q]) begin
                lk_id = m_id[q]; #1; e = mfind(m_id[q]);
                if (lk_found !== e[AW] || lk_addr !== e[AW-1:0]) begin errors = errors + 1;
                    $display("FAIL lookup id=%0d: got %b@%0d exp %b@%0d", lk_id, lk_found, lk_addr, e[AW], e[AW-1:0]); end
            end
        end
        lk_id = probe; #1; e = mfind(probe);
        if (lk_found !== e[AW] || (e[AW] && lk_addr !== e[AW-1:0])) begin errors = errors + 1;
            $display("FAIL probe lookup id=%0d: got %b@%0d exp %b@%0d", probe, lk_found, lk_addr, e[AW], e[AW-1:0]); end
    end endtask

    // one clock cycle with any mix of the three write ports; model is updated in RTL priority order
    task apply(input w_en, input [AW-1:0] w_a, input [IDW-1:0] w_id, input w_s, input [PW-1:0] w_p, input [QW-1:0] w_q,
               input q_en, input [AW-1:0] q_a, input [QW-1:0] q_d, input i_en, input [AW-1:0] i_a, input [IDW-1:0] probe); begin
        @(negedge clk);
        wr_en = w_en; wr_addr = w_a; wr_id = w_id; wr_side = w_s; wr_price = w_p; wr_qty = w_q;
        qty_wr_en = q_en; qty_wr_addr = q_a; qty_wr_data = q_d; inv_en = i_en; inv_addr = i_a;
        @(negedge clk);
        wr_en = 0; qty_wr_en = 0; inv_en = 0;
        if (q_en) m_qty[q_a] = q_d;
        if (i_en) m_v[i_a] = 0;
        if (w_en) begin m_id[w_a] = w_id; m_side[w_a] = w_s; m_price[w_a] = w_p; m_qty[w_a] = w_q; m_v[w_a] = 1; end
        audit(probe);
    end endtask
    task W(input [AW-1:0] ad, input [IDW-1:0] id, input s, input [PW-1:0] p, input [QW-1:0] q);
        apply(1,ad,id,s,p,q, 0,0,0, 0,0, id); endtask
    task QU(input [AW-1:0] ad, input [QW-1:0] q);   apply(0,0,0,0,0,0, 1,ad,q, 0,0, 16'hFFF0); endtask
    task INV(input [AW-1:0] ad);                    apply(0,0,0,0,0,0, 0,0,0, 1,ad, m_id[ad]); endtask

    initial begin
        $dumpfile("sim/order_memory.vcd"); $dumpvars(0, order_memory_tb);
        model_clear;
        #22 rst_n = 1;
        // 1. after reset everything invalid; id 0 must NOT be found even though stored data is all-zero
        audit(0);
        // 2. single write / update / invalidate
        W(3, 101, 1, 50, 100);
        QU(3, 60);
        INV(3);
        audit(101);                                   // stale id must miss after invalidate
        // 3. fill all 16 slots, then read/lookup everything
        for (n = 0; n < DEPTH; n = n + 1) W(n, 200 + n, n[0], n * 3, 10 + n);
        // 4. overwrite an occupied slot: old id must disappear, new id appears
        W(5, 999, 0, 7, 77);
        audit(205);
        // 5. same-cycle collisions on ONE slot
        apply(1,6,1234,1,40,500, 0,0,0, 1,6, 1234);   // write + invalidate  -> write wins (slot valid)
        apply(0,0,0,0,0,0, 1,8,321, 1,8, 208);        // qty update + invalidate -> invalid
        apply(1,9,4321,0,9,90, 1,9,5,0,0, 4321);      // write + qty update  -> write wins (qty 90)
        // 6. different slots in the same cycle
        apply(1,0,3000,1,11,11, 1,1,55, 1,2, 3000);
        // 7. duplicate id (illegal in use, but lookup must pick the LOWEST slot)
        W(12, 4000, 1, 1, 1); W(4, 4000, 1, 1, 1);
        INV(12); INV(4);
        // 8. boundary values
        W(15, 16'hFFFF, 1, 63, 16'hFFFF);
        W(14, 16'h0000, 0, 0, 16'h0001);             // id 0 stored in a valid slot IS found
        audit(0);
        QU(15, 0);                                    // quantity zero is storable
        // 9. empty everything one by one
        for (n = 0; n < DEPTH; n = n + 1) INV(n);
        audit(205);
        // 10. asynchronous reset in the middle of operation clears everything
        W(2, 77, 1, 5, 5); W(9, 78, 0, 6, 6);
        #3 rst_n = 0; #2 model_clear; #1 rst_n = 1;
        audit(77);
        $dumpoff;                                     // keep the VCD small: random part is not dumped
        // 11. random operations vs model
        for (t = 0; t < 3000; t = t + 1) begin : RND
            reg [AW-1:0] ad; reg [IDW-1:0] id; reg [AW:0] e; integer r, tries;
            r = $urandom % 10; ad = $urandom % DEPTH;
            if (r < 4) begin                          // write with a unique id
                tries = 0; id = $urandom % 64; e = mfind(id);
                while (tries < 20 && e[AW] && e[AW-1:0] != ad) begin id = $urandom % 64; e = mfind(id); tries = tries + 1; end
                if (e[AW] && e[AW-1:0] != ad) id = 16'hF000 + t[11:0];     // could not find a free id quickly: use a fresh one
                W(ad, id, $urandom, $urandom, $urandom);
            end else if (r < 6) QU(ad, $urandom);
            else if (r < 8)     INV(ad);
            else                apply(0,0,0,0,0,0,0,0,0,0,0, $urandom % 64);   // pure lookup of random id
        end
        if (errors == 0) $display("ORDER_MEMORY_TB: PASS"); else $display("ORDER_MEMORY_TB: FAIL (%0d errors)", errors);
        $finish;
    end
    initial begin #50000000 $display("TIMEOUT"); $finish; end
endmodule
