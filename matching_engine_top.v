// matching_engine_top.v  (Member 4 - Yash, 2025csb1268)
// -----------------------------------------------------------------------------
// Top level of the Stage 2 limit-order-book matching engine.
//
// Conventions: side 1 = BUY, 0 = SELL. Prices are integer ticks (PRICE_W bits).
// One order is processed at a time. Trades happen at the RESTING order's price.
// Price-time priority: best price first (bitmap), oldest first at equal price (FIFO).
//
// Datapath idea (see master_fsm.v for the control sequence):
//   * The incoming order is held in registers cur_*; it is NOT in order memory
//     unless a remainder has to rest in the book (INSERT).
//   * Two books, one per side: price bitmap + per-price FIFO of slot numbers.
//     Order memory and the free list are SHARED (a slot belongs to one side).
//   * For an incoming BUY the "opposite" book is the ASK book (best = lowest);
//     for an incoming SELL it is the BID book (best = highest).
//
// Cycle by cycle:
//   VALIDATE : risk_filter checks cur_qty / cur_price (combinational) -> risk_ok
//   DISCOVER : register best opposite price (best_px) and "opposite book not empty"
//   CHECK    : read FIFO head at level best_px -> order_memory -> compatibility_logic
//   EXECUTE  : one trade: update quantities, pop/free the resting order if it is
//              used up, clear bitmap bit if that was the last order of the level
//   INSERT   : allocate a slot, write the order, push it on its price FIFO, set bitmap bit
//   DONE / REJECT : one-cycle pulses
// -----------------------------------------------------------------------------
module matching_engine_top #(
    parameter PRICE_W      = 6,
    parameter QTY_W        = 16,
    parameter ID_W         = 16,
    parameter SLOTS        = 16,
    // risk limits (forwarded to risk_filter)
    parameter MIN_QTY      = 1,
    parameter MAX_QTY      = 1000,
    parameter PRICE_MIN    = 1,
    parameter PRICE_MAX    = 63,
    parameter MAX_NOTIONAL = 50000
) (
    input  wire                 clk,
    input  wire                 rst_n,
    // order input (valid/ready)
    input  wire                 in_valid,
    output wire                 in_ready,
    input  wire [ID_W-1:0]      in_id,
    input  wire                 in_side,
    input  wire [PRICE_W-1:0]   in_price,
    input  wire [QTY_W-1:0]     in_qty,
    // trade output (one-cycle pulse per trade, registered)
    output reg                  trade_valid,
    output reg  [PRICE_W-1:0]   trade_price,
    output reg  [QTY_W-1:0]     trade_qty,
    output reg  [ID_W-1:0]      trade_buy_id,
    output reg  [ID_W-1:0]      trade_sell_id,
    // order completion
    output wire                 done_pulse,     // order fully processed
    output wire                 reject_valid,   // order rejected
    output reg  [3:0]           reject_code,    // [2:0]=risk reason, 4'b1000 = book full
    // market data
    output wire [PRICE_W-1:0]   best_bid,
    output wire                 best_bid_valid,
    output wire [PRICE_W-1:0]   best_ask,
    output wire                 best_ask_valid,
    // observability (extra, not in the shared spec)
    output wire [$clog2(SLOTS):0] free_count,
    output wire [2:0]           fsm_state,
    output reg                  err_flag        // sticky: internal consistency check failed
);
    localparam SLOT_W = $clog2(SLOTS);
    localparam LEVELS = (1 << PRICE_W);

    // ------------------------------------------------------------------
    // 1. Control FSM
    // ------------------------------------------------------------------
    wire risk_ok, can_match, in_done, room_ok;
    wire st_idle, st_validate, st_discover, st_check, st_execute, st_insert, st_done, st_reject;
    wire accept, reject_pulse;

    master_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .risk_ok(risk_ok), .can_match(can_match),
        .in_done(in_done), .room_ok(room_ok),
        .state(fsm_state),
        .st_idle(st_idle), .st_validate(st_validate), .st_discover(st_discover),
        .st_check(st_check), .st_execute(st_execute), .st_insert(st_insert),
        .st_done(st_done), .st_reject(st_reject),
        .in_ready(in_ready), .accept(accept),
        .done_pulse(done_pulse), .reject_pulse(reject_pulse)
    );
    assign reject_valid = reject_pulse;

    // ------------------------------------------------------------------
    // 2. Registers holding the incoming order and the discovered best price
    // ------------------------------------------------------------------
    reg [ID_W-1:0]    cur_id;
    reg               cur_side;
    reg [PRICE_W-1:0] cur_price;
    reg [QTY_W-1:0]   cur_qty;          // remaining quantity of the incoming order
    reg [PRICE_W-1:0] best_px;          // best opposite price found in DISCOVER
    reg               opp_any;          // opposite book had at least one order in DISCOVER

    // ------------------------------------------------------------------
    // 3. Risk filter (Niket) - combinational on the latched order
    // ------------------------------------------------------------------
    wire [2:0] risk_reason;
    risk_filter #(.QTY_W(QTY_W), .PRICE_W(PRICE_W), .MIN_QTY(MIN_QTY), .MAX_QTY(MAX_QTY),
                  .PRICE_MIN(PRICE_MIN), .PRICE_MAX(PRICE_MAX), .MAX_NOTIONAL(MAX_NOTIONAL))
        u_risk (.qty(cur_qty), .price(cur_price), .ok(risk_ok), .reason(risk_reason));

    // ------------------------------------------------------------------
    // 4. Price bitmaps (Ronit): bid book (best = highest), ask book (best = lowest)
    // ------------------------------------------------------------------
    wire              bid_set_en, bid_clr_en, ask_set_en, ask_clr_en;
    wire [PRICE_W-1:0] bid_best_hi, ask_best_lo;
    wire              bid_any, ask_any;
    wire [LEVELS-1:0] bid_bitmap, ask_bitmap;
    wire [PRICE_W-1:0] bid_best_lo_unused, ask_best_hi_unused;

    price_bitmap #(.PRICE_W(PRICE_W)) u_bid_bm (
        .clk(clk), .rst_n(rst_n),
        .set_en(bid_set_en), .set_idx(cur_price),
        .clr_en(bid_clr_en), .clr_idx(best_px),
        .bitmap(bid_bitmap), .any(bid_any),
        .best_hi(bid_best_hi), .best_lo(bid_best_lo_unused));
    price_bitmap #(.PRICE_W(PRICE_W)) u_ask_bm (
        .clk(clk), .rst_n(rst_n),
        .set_en(ask_set_en), .set_idx(cur_price),
        .clr_en(ask_clr_en), .clr_idx(best_px),
        .bitmap(ask_bitmap), .any(ask_any),
        .best_hi(ask_best_hi_unused), .best_lo(ask_best_lo));

    assign best_bid       = bid_best_hi;
    assign best_bid_valid = bid_any;
    assign best_ask       = ask_best_lo;
    assign best_ask_valid = ask_any;

    // ------------------------------------------------------------------
    // 5. Per-price FIFOs (Shalin): one for bids, one for asks
    // ------------------------------------------------------------------
    wire                bid_push_en, bid_pop_en, ask_push_en, ask_pop_en;
    wire [SLOT_W-1:0]   alloc_slot;                    // from free list
    wire [SLOT_W-1:0]   bid_head, ask_head;
    wire                bid_nonempty, ask_nonempty, bid_last, ask_last;

    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) u_bid_q (
        .clk(clk), .rst_n(rst_n),
        .push_en(bid_push_en), .push_level(cur_price), .push_slot(alloc_slot),
        .pop_en(bid_pop_en),   .pop_level(best_px),
        .rd_level(best_px), .rd_head(bid_head), .rd_nonempty(bid_nonempty), .rd_last(bid_last));
    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) u_ask_q (
        .clk(clk), .rst_n(rst_n),
        .push_en(ask_push_en), .push_level(cur_price), .push_slot(alloc_slot),
        .pop_en(ask_pop_en),   .pop_level(best_px),
        .rd_level(best_px), .rd_head(ask_head), .rd_nonempty(ask_nonempty), .rd_last(ask_last));

    // Pick the OPPOSITE side's queue (incoming BUY -> ask queue, incoming SELL -> bid queue)
    wire [SLOT_W-1:0] opp_head     = cur_side ? ask_head     : bid_head;
    wire              opp_nonempty = cur_side ? ask_nonempty : bid_nonempty;
    wire              opp_last     = cur_side ? ask_last     : bid_last;

    // ------------------------------------------------------------------
    // 6. Order memory (Shalin) and free list (Shalin)
    // ------------------------------------------------------------------
    wire [ID_W-1:0]    rd_id;
    wire               rd_side, rd_valid;
    wire [PRICE_W-1:0] rd_price;
    wire [QTY_W-1:0]   rd_qty;
    wire               lk_found_unused;
    wire [SLOT_W-1:0]  lk_addr_unused;

    wire               wr_en, qty_wr_en, inv_en;
    wire [QTY_W-1:0]   rest_rem;

    order_memory #(.DEPTH(SLOTS), .ID_W(ID_W), .QTY_W(QTY_W), .PRICE_W(PRICE_W)) u_mem (
        .clk(clk), .rst_n(rst_n),
        // INSERT: write a whole new record
        .wr_en(wr_en), .wr_addr(alloc_slot), .wr_id(cur_id), .wr_side(cur_side),
        .wr_price(cur_price), .wr_qty(cur_qty),
        // EXECUTE (partial fill of resting order): update quantity only
        .qty_wr_en(qty_wr_en), .qty_wr_addr(opp_head), .qty_wr_data(rest_rem),
        // EXECUTE (resting order used up): invalidate record
        .inv_en(inv_en), .inv_addr(opp_head),
        // combinational read of the best resting order
        .rd_addr(opp_head),
        .rd_id(rd_id), .rd_side(rd_side), .rd_price(rd_price), .rd_qty(rd_qty), .rd_valid(rd_valid),
        // ID lookup: unused in Stage 2 (cancel arrives in Stage 3)
        .lk_id({ID_W{1'b0}}), .lk_found(lk_found_unused), .lk_addr(lk_addr_unused));

    wire               alloc_ok_unused;
    wire               alloc_en, free_en;
    wire [$clog2(SLOTS):0] free_cnt;
    free_list_allocator #(.SLOTS(SLOTS)) u_free (
        .clk(clk), .rst_n(rst_n),
        .alloc_en(alloc_en), .alloc_slot(alloc_slot), .alloc_ok(alloc_ok_unused),
        .free_en(free_en), .free_slot(opp_head),
        .free_count(free_cnt));
    assign free_count = free_cnt;
    // Decide "is there room" from free_count (not alloc_ok) so there can be no
    // combinational loop between alloc_en and alloc_ok.
    assign room_ok = (free_cnt != 0);

    // ------------------------------------------------------------------
    // 7. Matching datapath (Saurabhraj)
    // ------------------------------------------------------------------
    wire [QTY_W-1:0] trade_q, in_rem;
    wire             rest_done;
    wire             rest_valid = opp_any & opp_nonempty & rd_valid;

    compatibility_logic #(.PRICE_W(PRICE_W)) u_compat (
        .in_side(cur_side), .in_price(cur_price),
        .rest_price(rd_price), .rest_valid(rest_valid),
        .can_match(can_match));

    quantity_arithmetic #(.QTY_W(QTY_W)) u_qty (
        .in_qty(cur_qty), .rest_qty(rd_qty),
        .trade_qty(trade_q), .in_rem(in_rem), .rest_rem(rest_rem),
        .in_done(in_done), .rest_done(rest_done));

    // ------------------------------------------------------------------
    // 8. Control strobes derived from the FSM state
    // ------------------------------------------------------------------
    wire do_insert = st_insert & room_ok;       // INSERT succeeds only if a slot is free
    wire do_exec   = st_execute;                // EXECUTE is only entered when can_match was 1

    // INSERT: allocate + write order + push to FIFO of its own side + set its bitmap bit
    assign alloc_en    = do_insert;
    assign wr_en       = do_insert;
    assign bid_push_en = do_insert &  cur_side;
    assign ask_push_en = do_insert & ~cur_side;
    assign bid_set_en  = do_insert &  cur_side;
    assign ask_set_en  = do_insert & ~cur_side;

    // EXECUTE: resting order is on the OPPOSITE side of the incoming order
    wire rest_used_up = do_exec & rest_done;
    assign qty_wr_en  = do_exec & ~rest_done;                    // partial fill: store new qty
    assign inv_en     = rest_used_up;                            // full fill: invalidate record
    assign free_en    = rest_used_up;                            //            return slot to free list
    assign ask_pop_en = rest_used_up &  cur_side;                //            pop its FIFO
    assign bid_pop_en = rest_used_up & ~cur_side;
    assign ask_clr_en = rest_used_up &  cur_side & opp_last;     //            level empty -> clear bit
    assign bid_clr_en = rest_used_up & ~cur_side & opp_last;

    // ------------------------------------------------------------------
    // 9. Registers updated by the FSM steps
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_id <= {ID_W{1'b0}};   cur_side <= 1'b0;
            cur_price <= {PRICE_W{1'b0}}; cur_qty <= {QTY_W{1'b0}};
            best_px <= {PRICE_W{1'b0}};   opp_any <= 1'b0;
            trade_valid <= 1'b0; trade_price <= {PRICE_W{1'b0}}; trade_qty <= {QTY_W{1'b0}};
            trade_buy_id <= {ID_W{1'b0}}; trade_sell_id <= {ID_W{1'b0}};
            reject_code <= 4'd0;
            err_flag <= 1'b0;
        end else begin
            // one-cycle trade pulse: high in the cycle AFTER EXECUTE
            trade_valid <= do_exec;

            // latch the incoming order when the FSM accepts it
            if (accept) begin
                cur_id <= in_id;  cur_side <= in_side;
                cur_price <= in_price;  cur_qty <= in_qty;
            end

            // DISCOVER: remember where the best opposite price is
            if (st_discover) begin
                best_px <= cur_side ? ask_best_lo : bid_best_hi;
                opp_any <= cur_side ? ask_any     : bid_any;
            end

            // EXECUTE: trade record (price = RESTING order's price) and shrink the incoming qty
            if (do_exec) begin
                trade_price   <= rd_price;
                trade_qty     <= trade_q;
                trade_buy_id  <= cur_side ? cur_id : rd_id;
                trade_sell_id <= cur_side ? rd_id  : cur_id;
                cur_qty       <= in_rem;
                // sanity checks: the resting order must be what DISCOVER said it is
                if (!rd_valid || !opp_nonempty || (rd_price != best_px) || (rd_side == cur_side))
                    err_flag <= 1'b1;
            end

            // rejection reason (visible in the REJECT cycle)
            if (st_validate && !risk_ok) reject_code <= {1'b0, risk_reason};
            if (st_insert   && !room_ok) reject_code <= 4'b1000;    // book full
        end
    end
endmodule
