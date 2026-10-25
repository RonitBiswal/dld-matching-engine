`timescale 1ns/1ps

module matching_engine_demo_tb;

    localparam PRICE_W = 6, QTY_W = 16, ID_W = 16, SLOTS = 16;
    localparam MIN_QTY = 1, MAX_QTY = 1000, PRICE_MIN = 1, PRICE_MAX = 63, MAX_NOTIONAL = 50000;

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

    task submit_and_display;
        input [ID_W-1:0]    id;
        input               side;
        input [PRICE_W-1:0] price;
        input [QTY_W-1:0]   qty;
        integer cycles, trades_seen;
        reg [8*4-1:0]  side_str;
        reg [8*17-1:0] reason_str;
        begin
            @(negedge clk);
            while (!in_ready)
                @(negedge clk);

            if (side)
                side_str = "BUY ";
            else
                side_str = "SELL";

            $display("----------------------------------------------------------------------------------------");
            $display(">>> NEW ORDER IN: ID=%0d | Side=%s | Price=%0d | Qty=%0d",
                     id, side_str, price, qty);

            in_valid = 1;
            in_id    = id;
            in_side  = side;
            in_price = price;
            in_qty   = qty;

            @(negedge clk);
            in_valid = 0;

            cycles      = 1;
            trades_seen = 0;

            while (!done_pulse && !reject_valid) begin
                if (trade_valid) begin
                    trades_seen = trades_seen + 1;
                    $display("    *** TRADE #%0d EXECUTED! Price=%0d, Qty=%0d | BuyID=%0d, SellID=%0d",
                             trades_seen, trade_price, trade_qty, trade_buy_id, trade_sell_id);
                end
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (trade_valid) begin
                trades_seen = trades_seen + 1;
                $display("    *** TRADE #%0d EXECUTED! Price=%0d, Qty=%0d | BuyID=%0d, SellID=%0d",
                         trades_seen, trade_price, trade_qty, trade_buy_id, trade_sell_id);
            end

            if (done_pulse) begin
                if (trades_seen == 0)
                    $display(">>> RESULT: Order rested in order book (no immediate trade). Latency: %0d cycles.", cycles);
                else
                    $display(">>> RESULT: Order finished processing (%0d trade(s)). Latency: %0d cycles.", trades_seen, cycles);
            end else if (reject_valid) begin
                if (reject_code == 4'b1000)
                    reason_str = "Book Full";
                else if (reject_code[0])
                    reason_str = "Invalid Qty";
                else if (reject_code[1])
                    reason_str = "Price Out of Band";
                else
                    reason_str = "Notional Exceeded";

                $display(">>> RESULT: Order REJECTED! Code = %b (%0s). Latency: %0d cycles.",
                         reject_code, reason_str, cycles);
            end

            $display(">>> MARKET STATUS: Best Bid = %0d (Valid: %b) | Best Ask = %0d (Valid: %b) | Free Slots: %0d/%0d",
                     best_bid, best_bid_valid, best_ask, best_ask_valid, free_count, SLOTS);
        end
    endtask

    initial begin
        $display("========================================================================================");
        $display("          DLD HARDWARE MATCHING ENGINE - LIVE PRESENTATION DEMO");
        $display("========================================================================================");

        #22;
        rst_n = 1;
        @(negedge clk);

        $display("\n[SCENARIO 1] Building the Order Book (Resting Limit Orders)");
        submit_and_display(101, 1, 50, 100);
        submit_and_display(102, 1, 50,  50);
        submit_and_display(103, 1, 49, 200);
        submit_and_display(104, 0, 55,  80);

        $display("\n[SCENARIO 2] Incoming Crossing Order: Multi-Level Price-Time Sweep");
        $display("Incoming aggressive SELL 180 @ 49 sweeps bids at 50 (101, 102) and 49 (103)...");
        submit_and_display(201, 0, 49, 180);

        $display("\n[SCENARIO 3] Hardware Pre-Trade Risk Filter in Action (Zero-latency rejection)");
        submit_and_display(301, 1, 50, 0);
        submit_and_display(302, 1, 70, 10);
        submit_and_display(303, 1, 60, 900);

        $display("\n[SCENARIO 4] Clearing the Remaining Order");
        submit_and_display(401, 0, 49, 170);

        $display("\n========================================================================================");
        $display("                      ALL DEMO SCENARIOS COMPLETED SUCCESSFULLY!");
        $display("========================================================================================");

        $finish;
    end

endmodule
