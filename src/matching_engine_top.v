module matching_engine_top #(
    parameter PRICE_W      = 6,
    parameter QTY_W        = 16,
    parameter ID_W         = 16,
    parameter SLOTS        = 16,
    parameter MIN_QTY      = 1,
    parameter MAX_QTY      = 1000,
    parameter PRICE_MIN    = 1,
    parameter PRICE_MAX    = 63,
    parameter MAX_NOTIONAL = 50000
) (
    input  wire                   clk,
    input  wire                   rst_n,

    input  wire                   in_valid,
    output wire                   in_ready,
    input  wire [ID_W-1:0]        in_id,
    input  wire                   in_side,
    input  wire [PRICE_W-1:0]     in_price,
    input  wire [QTY_W-1:0]       in_qty,

    output reg                    trade_valid,
    output reg  [PRICE_W-1:0]     trade_price,
    output reg  [QTY_W-1:0]       trade_qty,
    output reg  [ID_W-1:0]        trade_buy_id,
    output reg  [ID_W-1:0]        trade_sell_id,

    output wire                   done_pulse,
    output wire                   reject_valid,
    output reg  [3:0]             reject_code,

    output wire [PRICE_W-1:0]     best_bid,
    output wire                   best_bid_valid,
    output wire [PRICE_W-1:0]     best_ask,
    output wire                   best_ask_valid,

    output wire [$clog2(SLOTS):0] free_count,
    output wire [2:0]             fsm_state,
    output reg                    err_flag
);

    localparam SLOT_W = $clog2(SLOTS);
    localparam LEVELS = (1 << PRICE_W);

    wire risk_ok;
    wire can_match;
    wire in_done;
    wire room_ok;

    wire st_idle;
    wire st_validate;
    wire st_discover;
    wire st_check;
    wire st_execute;
    wire st_insert;
    wire st_done;
    wire st_reject;

    wire accept;
    wire reject_pulse;

    master_fsm u_fsm (
        .clk          (clk),
        .rst_n        (rst_n),
        .in_valid     (in_valid),
        .risk_ok      (risk_ok),
        .can_match    (can_match),
        .in_done      (in_done),
        .room_ok      (room_ok),
        .state        (fsm_state),
        .st_idle      (st_idle),
        .st_validate  (st_validate),
        .st_discover  (st_discover),
        .st_check     (st_check),
        .st_execute   (st_execute),
        .st_insert    (st_insert),
        .st_done      (st_done),
        .st_reject    (st_reject),
        .in_ready     (in_ready),
        .accept       (accept),
        .done_pulse   (done_pulse),
        .reject_pulse (reject_pulse)
    );

    assign reject_valid = reject_pulse;

    reg [ID_W-1:0]    cur_id;
    reg               cur_side;
    reg [PRICE_W-1:0] cur_price;
    reg [QTY_W-1:0]   cur_qty;
    reg [PRICE_W-1:0] best_px;
    reg               opp_any;

    wire [2:0] risk_reason;

    risk_filter #(
        .QTY_W        (QTY_W),
        .PRICE_W      (PRICE_W),
        .MIN_QTY      (MIN_QTY),
        .MAX_QTY      (MAX_QTY),
        .PRICE_MIN    (PRICE_MIN),
        .PRICE_MAX    (PRICE_MAX),
        .MAX_NOTIONAL (MAX_NOTIONAL)
    ) u_risk (
        .qty    (cur_qty),
        .price  (cur_price),
        .ok     (risk_ok),
        .reason (risk_reason)
    );

    wire               bid_set_en;
    wire               bid_clr_en;
    wire               ask_set_en;
    wire               ask_clr_en;
    wire [PRICE_W-1:0] bid_best_hi;
    wire [PRICE_W-1:0] ask_best_lo;
    wire               bid_any;
    wire               ask_any;
    wire [LEVELS-1:0]  bid_bitmap;
    wire [LEVELS-1:0]  ask_bitmap;
    wire [PRICE_W-1:0] bid_best_lo_unused;
    wire [PRICE_W-1:0] ask_best_hi_unused;

    price_bitmap #(.PRICE_W(PRICE_W)) u_bid_bm (
        .clk     (clk),
        .rst_n   (rst_n),
        .set_en  (bid_set_en),
        .set_idx (cur_price),
        .clr_en  (bid_clr_en),
        .clr_idx (best_px),
        .bitmap  (bid_bitmap),
        .any     (bid_any),
        .best_hi (bid_best_hi),
        .best_lo (bid_best_lo_unused)
    );

    price_bitmap #(.PRICE_W(PRICE_W)) u_ask_bm (
        .clk     (clk),
        .rst_n   (rst_n),
        .set_en  (ask_set_en),
        .set_idx (cur_price),
        .clr_en  (ask_clr_en),
        .clr_idx (best_px),
        .bitmap  (ask_bitmap),
        .any     (ask_any),
        .best_hi (ask_best_hi_unused),
        .best_lo (ask_best_lo)
    );

    assign best_bid       = bid_best_hi;
    assign best_bid_valid = bid_any;
    assign best_ask       = ask_best_lo;
    assign best_ask_valid = ask_any;

    wire               bid_push_en;
    wire               bid_pop_en;
    wire               ask_push_en;
    wire               ask_pop_en;
    wire [SLOT_W-1:0]  alloc_slot;
    wire [SLOT_W-1:0]  bid_head;
    wire [SLOT_W-1:0]  ask_head;
    wire               bid_nonempty;
    wire               ask_nonempty;
    wire               bid_last;
    wire               ask_last;

    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) u_bid_q (
        .clk         (clk),
        .rst_n       (rst_n),
        .push_en     (bid_push_en),
        .push_level  (cur_price),
        .push_slot   (alloc_slot),
        .pop_en      (bid_pop_en),
        .pop_level   (best_px),
        .rd_level    (best_px),
        .rd_head     (bid_head),
        .rd_nonempty (bid_nonempty),
        .rd_last     (bid_last)
    );

    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) u_ask_q (
        .clk         (clk),
        .rst_n       (rst_n),
        .push_en     (ask_push_en),
        .push_level  (cur_price),
        .push_slot   (alloc_slot),
        .pop_en      (ask_pop_en),
        .pop_level   (best_px),
        .rd_level    (best_px),
        .rd_head     (ask_head),
        .rd_nonempty (ask_nonempty),
        .rd_last     (ask_last)
    );

    wire [SLOT_W-1:0] opp_head     = cur_side ? ask_head     : bid_head;
    wire              opp_nonempty = cur_side ? ask_nonempty : bid_nonempty;
    wire              opp_last     = cur_side ? ask_last     : bid_last;

    wire [ID_W-1:0]    rd_id;
    wire               rd_side;
    wire               rd_valid;
    wire [PRICE_W-1:0] rd_price;
    wire [QTY_W-1:0]   rd_qty;
    wire               lk_found_unused;
    wire [SLOT_W-1:0]  lk_addr_unused;

    wire               wr_en;
    wire               qty_wr_en;
    wire               inv_en;
    wire [QTY_W-1:0]   rest_rem;

    order_memory #(
        .DEPTH   (SLOTS),
        .ID_W    (ID_W),
        .QTY_W   (QTY_W),
        .PRICE_W (PRICE_W)
    ) u_mem (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (wr_en),
        .wr_addr     (alloc_slot),
        .wr_id       (cur_id),
        .wr_side     (cur_side),
        .wr_price    (cur_price),
        .wr_qty      (cur_qty),
        .qty_wr_en   (qty_wr_en),
        .qty_wr_addr (opp_head),
        .qty_wr_data (rest_rem),
        .inv_en      (inv_en),
        .inv_addr    (opp_head),
        .rd_addr     (opp_head),
        .rd_id       (rd_id),
        .rd_side     (rd_side),
        .rd_price    (rd_price),
        .rd_qty      (rd_qty),
        .rd_valid    (rd_valid),
        .lk_id       ({ID_W{1'b0}}),
        .lk_found    (lk_found_unused),
        .lk_addr     (lk_addr_unused)
    );

    wire                   alloc_ok_unused;
    wire                   alloc_en;
    wire                   free_en;
    wire [$clog2(SLOTS):0] free_cnt;

    free_list_allocator #(.SLOTS(SLOTS)) u_free (
        .clk        (clk),
        .rst_n      (rst_n),
        .alloc_en   (alloc_en),
        .alloc_slot (alloc_slot),
        .alloc_ok   (alloc_ok_unused),
        .free_en    (free_en),
        .free_slot  (opp_head),
        .free_count (free_cnt)
    );

    assign free_count = free_cnt;
    assign room_ok    = (free_cnt != 0);

    wire [QTY_W-1:0] trade_q;
    wire [QTY_W-1:0] in_rem;
    wire             rest_done;
    wire             rest_valid = opp_any & opp_nonempty & rd_valid;

    compatibility_logic #(.PRICE_W(PRICE_W)) u_compat (
        .in_side    (cur_side),
        .in_price   (cur_price),
        .rest_price (rd_price),
        .rest_valid (rest_valid),
        .can_match  (can_match)
    );

    quantity_arithmetic #(.QTY_W(QTY_W)) u_qty (
        .in_qty    (cur_qty),
        .rest_qty  (rd_qty),
        .trade_qty (trade_q),
        .in_rem    (in_rem),
        .rest_rem  (rest_rem),
        .in_done   (in_done),
        .rest_done (rest_done)
    );

    wire do_insert = st_insert & room_ok;
    wire do_exec   = st_execute;

    assign alloc_en    = do_insert;
    assign wr_en       = do_insert;
    assign bid_push_en = do_insert &  cur_side;
    assign ask_push_en = do_insert & ~cur_side;
    assign bid_set_en  = do_insert &  cur_side;
    assign ask_set_en  = do_insert & ~cur_side;

    wire rest_used_up = do_exec & rest_done;

    assign qty_wr_en  = do_exec & ~rest_done;
    assign inv_en     = rest_used_up;
    assign free_en    = rest_used_up;
    assign ask_pop_en = rest_used_up &  cur_side;
    assign bid_pop_en = rest_used_up & ~cur_side;
    assign ask_clr_en = rest_used_up &  cur_side & opp_last;
    assign bid_clr_en = rest_used_up & ~cur_side & opp_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_id        <= {ID_W{1'b0}};
            cur_side      <= 1'b0;
            cur_price     <= {PRICE_W{1'b0}};
            cur_qty       <= {QTY_W{1'b0}};
            best_px       <= {PRICE_W{1'b0}};
            opp_any       <= 1'b0;
            trade_valid   <= 1'b0;
            trade_price   <= {PRICE_W{1'b0}};
            trade_qty     <= {QTY_W{1'b0}};
            trade_buy_id  <= {ID_W{1'b0}};
            trade_sell_id <= {ID_W{1'b0}};
            reject_code   <= 4'd0;
            err_flag      <= 1'b0;
        end else begin
            trade_valid <= do_exec;

            if (accept) begin
                cur_id    <= in_id;
                cur_side  <= in_side;
                cur_price <= in_price;
                cur_qty   <= in_qty;
            end

            if (st_discover) begin
                best_px <= cur_side ? ask_best_lo : bid_best_hi;
                opp_any <= cur_side ? ask_any     : bid_any;
            end

            if (do_exec) begin
                trade_price   <= rd_price;
                trade_qty     <= trade_q;
                trade_buy_id  <= cur_side ? cur_id : rd_id;
                trade_sell_id <= cur_side ? rd_id  : cur_id;
                cur_qty       <= in_rem;

                if (!rd_valid || !opp_nonempty || (rd_price != best_px) || (rd_side == cur_side)) begin
                    err_flag <= 1'b1;
                end
            end

            if (st_validate && !risk_ok) begin
                reject_code <= {1'b0, risk_reason};
            end

            if (st_insert && !room_ok) begin
                reject_code <= 4'b1000;
            end
        end
    end

endmodule
