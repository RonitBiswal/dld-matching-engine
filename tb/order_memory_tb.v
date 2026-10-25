`timescale 1ns/1ps

module order_memory_tb;

    localparam NUM_SLOTS  = 16;
    localparam ID_BITS    = 16;
    localparam QTY_BITS   = 16;
    localparam PRICE_BITS = 6;
    localparam ADDR_BITS  = 4;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    integer err_count = 0;
    integer idx, cycle;

    reg                  drv_wr_en     = 0;
    reg [ADDR_BITS-1:0]  drv_wr_addr   = 0;
    reg [ID_BITS-1:0]    drv_wr_id     = 0;
    reg                  drv_wr_side   = 0;
    reg [PRICE_BITS-1:0] drv_wr_price  = 0;
    reg [QTY_BITS-1:0]   drv_wr_qty    = 0;
    reg                  drv_qty_en    = 0;
    reg [ADDR_BITS-1:0]  drv_qty_addr  = 0;
    reg [QTY_BITS-1:0]   drv_qty_data  = 0;
    reg                  drv_inv_en    = 0;
    reg [ADDR_BITS-1:0]  drv_inv_addr  = 0;
    reg [ADDR_BITS-1:0]  drv_rd_addr   = 0;
    reg [ID_BITS-1:0]    drv_lk_id     = 0;

    wire [ID_BITS-1:0]    got_id;
    wire                  got_side;
    wire [PRICE_BITS-1:0] got_price;
    wire [QTY_BITS-1:0]   got_qty;
    wire                  got_valid;
    wire                  got_found;
    wire [ADDR_BITS-1:0]  got_lk_addr;

    order_memory #(
        .DEPTH(NUM_SLOTS),
        .ID_W(ID_BITS),
        .QTY_W(QTY_BITS),
        .PRICE_W(PRICE_BITS)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(drv_wr_en),
        .wr_addr(drv_wr_addr),
        .wr_id(drv_wr_id),
        .wr_side(drv_wr_side),
        .wr_price(drv_wr_price),
        .wr_qty(drv_wr_qty),
        .qty_wr_en(drv_qty_en),
        .qty_wr_addr(drv_qty_addr),
        .qty_wr_data(drv_qty_data),
        .inv_en(drv_inv_en),
        .inv_addr(drv_inv_addr),
        .rd_addr(drv_rd_addr),
        .rd_id(got_id),
        .rd_side(got_side),
        .rd_price(got_price),
        .rd_qty(got_qty),
        .rd_valid(got_valid),
        .lk_id(drv_lk_id),
        .lk_found(got_found),
        .lk_addr(got_lk_addr)
    );

    reg [ID_BITS-1:0]    exp_id    [0:NUM_SLOTS-1];
    reg                  exp_side  [0:NUM_SLOTS-1];
    reg [PRICE_BITS-1:0] exp_price [0:NUM_SLOTS-1];
    reg [QTY_BITS-1:0]   exp_qty   [0:NUM_SLOTS-1];
    reg                  exp_valid [0:NUM_SLOTS-1];

    task reset_model;
        integer k;
        begin
            for (k = 0; k < NUM_SLOTS; k = k + 1) begin
                exp_id[k]    = 0;
                exp_side[k]  = 0;
                exp_price[k] = 0;
                exp_qty[k]   = 0;
                exp_valid[k] = 0;
            end
        end
    endtask

    function [ADDR_BITS:0] model_lookup(input [ID_BITS-1:0] look_id);
        integer k;
        reg     seen;
        begin
            seen = 0;
            model_lookup = 0;
            for (k = NUM_SLOTS - 1; k >= 0; k = k - 1) begin
                if (exp_valid[k] && exp_id[k] == look_id) begin
                    seen = 1;
                    model_lookup = {1'b1, k[ADDR_BITS-1:0]};
                end
            end
            if (!seen)
                model_lookup = 0;
        end
    endfunction

    task check_all(input [ID_BITS-1:0] probe_id);
        reg [ADDR_BITS:0] want;
        integer k;
        begin
            for (k = 0; k < NUM_SLOTS; k = k + 1) begin
                drv_rd_addr = k;
                #1;

                if (got_valid !== exp_valid[k]) begin
                    err_count = err_count + 1;
                    $display("FAIL valid slot %0d: got %b exp %b", k, got_valid, exp_valid[k]);
                end

                if (exp_valid[k] && (got_id !== exp_id[k] || got_side !== exp_side[k] ||
                                     got_price !== exp_price[k] || got_qty !== exp_qty[k])) begin
                    err_count = err_count + 1;
                    $display("FAIL data slot %0d: got id=%0d s=%b p=%0d q=%0d  exp id=%0d s=%b p=%0d q=%0d",
                             k, got_id, got_side, got_price, got_qty,
                             exp_id[k], exp_side[k], exp_price[k], exp_qty[k]);
                end

                if (exp_valid[k]) begin
                    drv_lk_id = exp_id[k];
                    #1;
                    want = model_lookup(exp_id[k]);
                    if (got_found !== want[ADDR_BITS] || got_lk_addr !== want[ADDR_BITS-1:0]) begin
                        err_count = err_count + 1;
                        $display("FAIL lookup id=%0d: got %b@%0d exp %b@%0d",
                                 drv_lk_id, got_found, got_lk_addr, want[ADDR_BITS], want[ADDR_BITS-1:0]);
                    end
                end
            end

            drv_lk_id = probe_id;
            #1;
            want = model_lookup(probe_id);
            if (got_found !== want[ADDR_BITS] || (want[ADDR_BITS] && got_lk_addr !== want[ADDR_BITS-1:0])) begin
                err_count = err_count + 1;
                $display("FAIL probe lookup id=%0d: got %b@%0d exp %b@%0d",
                         probe_id, got_found, got_lk_addr, want[ADDR_BITS], want[ADDR_BITS-1:0]);
            end
        end
    endtask

    task drive_cycle(
        input                  w_en,
        input [ADDR_BITS-1:0]  w_addr,
        input [ID_BITS-1:0]    w_id,
        input                  w_side,
        input [PRICE_BITS-1:0] w_price,
        input [QTY_BITS-1:0]   w_qty,
        input                  q_en,
        input [ADDR_BITS-1:0]  q_addr,
        input [QTY_BITS-1:0]   q_data,
        input                  i_en,
        input [ADDR_BITS-1:0]  i_addr,
        input [ID_BITS-1:0]    probe_id
    );
        begin
            @(negedge clk);
            drv_wr_en    = w_en;
            drv_wr_addr  = w_addr;
            drv_wr_id    = w_id;
            drv_wr_side  = w_side;
            drv_wr_price = w_price;
            drv_wr_qty   = w_qty;
            drv_qty_en   = q_en;
            drv_qty_addr = q_addr;
            drv_qty_data = q_data;
            drv_inv_en   = i_en;
            drv_inv_addr = i_addr;

            @(negedge clk);
            drv_wr_en  = 0;
            drv_qty_en = 0;
            drv_inv_en = 0;

            if (q_en)
                exp_qty[q_addr] = q_data;

            if (i_en)
                exp_valid[i_addr] = 0;

            if (w_en) begin
                exp_id[w_addr]    = w_id;
                exp_side[w_addr]  = w_side;
                exp_price[w_addr] = w_price;
                exp_qty[w_addr]   = w_qty;
                exp_valid[w_addr] = 1;
            end

            check_all(probe_id);
        end
    endtask

    task WRITE(
        input [ADDR_BITS-1:0]  slot,
        input [ID_BITS-1:0]    id_val,
        input                  side_val,
        input [PRICE_BITS-1:0] price_val,
        input [QTY_BITS-1:0]   qty_val
    );
        drive_cycle(1, slot, id_val, side_val, price_val, qty_val,
                    0, 0, 0,
                    0, 0,
                    id_val);
    endtask

    task QTY_UPDATE(input [ADDR_BITS-1:0] slot, input [QTY_BITS-1:0] qty_val);
        drive_cycle(0, 0, 0, 0, 0, 0,
                    1, slot, qty_val,
                    0, 0,
                    16'hFFF0);
    endtask

    task INVALIDATE(input [ADDR_BITS-1:0] slot);
        drive_cycle(0, 0, 0, 0, 0, 0,
                    0, 0, 0,
                    1, slot,
                    exp_id[slot]);
    endtask

    initial begin
        $dumpfile("sim/order_memory.vcd");
        $dumpvars(0, order_memory_tb);

        reset_model;
        #22 rst_n = 1;

        check_all(0);

        WRITE(3, 101, 1, 50, 100);
        QTY_UPDATE(3, 60);
        INVALIDATE(3);
        check_all(101);

        for (idx = 0; idx < NUM_SLOTS; idx = idx + 1)
            WRITE(idx, 200 + idx, idx[0], idx * 3, 10 + idx);

        WRITE(5, 999, 0, 7, 77);
        check_all(205);

        drive_cycle(1, 6, 1234, 1, 40, 500,  0, 0, 0,  1, 6, 1234);
        drive_cycle(0, 0, 0, 0, 0, 0,        1, 8, 321, 1, 8, 208);
        drive_cycle(1, 9, 4321, 0, 9, 90,    1, 9, 5,   0, 0, 4321);

        drive_cycle(1, 0, 3000, 1, 11, 11,   1, 1, 55,  1, 2, 3000);

        WRITE(12, 4000, 1, 1, 1);
        WRITE(4, 4000, 1, 1, 1);
        INVALIDATE(12);
        INVALIDATE(4);

        WRITE(15, 16'hFFFF, 1, 63, 16'hFFFF);
        WRITE(14, 16'h0000, 0, 0, 16'h0001);
        check_all(0);
        QTY_UPDATE(15, 0);

        for (idx = 0; idx < NUM_SLOTS; idx = idx + 1)
            INVALIDATE(idx);
        check_all(205);

        WRITE(2, 77, 1, 5, 5);
        WRITE(9, 78, 0, 6, 6);
        #3 rst_n = 0;
        #2 reset_model;
        #1 rst_n = 1;
        check_all(77);

        $dumpoff;

        for (cycle = 0; cycle < 3000; cycle = cycle + 1) begin : RANDOM_PHASE
            reg [ADDR_BITS-1:0] slot;
            reg [ID_BITS-1:0]   new_id;
            reg [ADDR_BITS:0]   found;
            integer             pick, attempts;

            pick = $urandom % 10;
            slot = $urandom % NUM_SLOTS;

            if (pick < 4) begin
                attempts = 0;
                new_id   = $urandom % 64;
                found    = model_lookup(new_id);

                while (attempts < 20 && found[ADDR_BITS] && found[ADDR_BITS-1:0] != slot) begin
                    new_id   = $urandom % 64;
                    found    = model_lookup(new_id);
                    attempts = attempts + 1;
                end

                if (found[ADDR_BITS] && found[ADDR_BITS-1:0] != slot)
                    new_id = 16'hF000 + cycle[11:0];

                WRITE(slot, new_id, $urandom, $urandom, $urandom);
            end else if (pick < 6) begin
                QTY_UPDATE(slot, $urandom);
            end else if (pick < 8) begin
                INVALIDATE(slot);
            end else begin
                drive_cycle(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $urandom % 64);
            end
        end

        if (err_count == 0)
            $display("ORDER_MEMORY_TB: PASS");
        else
            $display("ORDER_MEMORY_TB: FAIL (%0d errors)", err_count);

        $finish;
    end

    initial begin
        #50000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
