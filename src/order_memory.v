// order_memory.v  (Member 2 - Shalin)
// Shared storage for all resting orders: DEPTH slots, each holding
// {id, side, price, qty} plus a valid bit.
//  * Combinational read  : put an address on rd_addr, the fields appear in the same cycle.
//  * Synchronous writes  : full-record write (wr_en), qty-only update (qty_wr_en), invalidate (inv_en).
//  * CAM-style ID lookup : lk_id is compared with EVERY valid slot in parallel (one comparator
//                          per slot). lk_found says if some valid slot holds that ID, lk_addr says which.
// Conventions: side 1 = BUY, 0 = SELL. Price is an integer tick index.
//
// If several write ports hit the SAME slot in the same cycle the priority is
//   qty update  <  invalidate  <  full write      (the full write wins)
// If two valid slots hold the same ID (should never happen) lk_addr is the LOWEST such slot.
// Requires DEPTH >= 2. AW is derived - do not override it.
module order_memory #(
    parameter DEPTH   = 16,
    parameter ID_W    = 16,
    parameter QTY_W   = 16,
    parameter PRICE_W = 6,
    parameter AW      = $clog2(DEPTH)
)(
    input  wire               clk,
    input  wire               rst_n,
    // full-record write (allocate / overwrite a slot, marks it valid)
    input  wire               wr_en,
    input  wire [AW-1:0]      wr_addr,
    input  wire [ID_W-1:0]    wr_id,
    input  wire               wr_side,
    input  wire [PRICE_W-1:0] wr_price,
    input  wire [QTY_W-1:0]   wr_qty,
    // quantity-only update (partial fill)
    input  wire               qty_wr_en,
    input  wire [AW-1:0]      qty_wr_addr,
    input  wire [QTY_W-1:0]   qty_wr_data,
    // invalidate (full fill / cancel)
    input  wire               inv_en,
    input  wire [AW-1:0]      inv_addr,
    // combinational read port
    input  wire [AW-1:0]      rd_addr,
    output wire [ID_W-1:0]    rd_id,
    output wire               rd_side,
    output wire [PRICE_W-1:0] rd_price,
    output wire [QTY_W-1:0]   rd_qty,
    output wire               rd_valid,
    // order-ID lookup (CAM style)
    input  wire [ID_W-1:0]    lk_id,
    output wire               lk_found,
    output wire [AW-1:0]      lk_addr
);
    // ---------------- storage arrays ----------------
    reg [ID_W-1:0]    id_q    [0:DEPTH-1];
    reg [DEPTH-1:0]   side_q;
    reg [PRICE_W-1:0] price_q [0:DEPTH-1];
    reg [QTY_W-1:0]   qty_q   [0:DEPTH-1];
    reg [DEPTH-1:0]   valid_q;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                id_q[i]    <= {ID_W{1'b0}};
                price_q[i] <= {PRICE_W{1'b0}};
                qty_q[i]   <= {QTY_W{1'b0}};
            end
            side_q  <= {DEPTH{1'b0}};
            valid_q <= {DEPTH{1'b0}};
        end else begin
            // order of the three ifs = priority (later one wins on the same slot)
            if (qty_wr_en) qty_q[qty_wr_addr] <= qty_wr_data;
            if (inv_en)    valid_q[inv_addr]  <= 1'b0;
            if (wr_en) begin
                id_q[wr_addr]    <= wr_id;
                side_q[wr_addr]  <= wr_side;
                price_q[wr_addr] <= wr_price;
                qty_q[wr_addr]   <= wr_qty;
                valid_q[wr_addr] <= 1'b1;
            end
        end
    end

    // ---------------- combinational read ----------------
    assign rd_id    = id_q[rd_addr];
    assign rd_side  = side_q[rd_addr];
    assign rd_price = price_q[rd_addr];
    assign rd_qty   = qty_q[rd_addr];
    assign rd_valid = valid_q[rd_addr];

    // ---------------- ID lookup: one comparator per slot, all in parallel ----------------
    wire [DEPTH-1:0] hit;
    genvar g;
    generate for (g = 0; g < DEPTH; g = g + 1) begin : CAM
        assign hit[g] = valid_q[g] & (id_q[g] == lk_id);   // invalid slots can never match
    end endgenerate

    // priority-pick the lowest matching slot (loop runs high->low so the lowest index wins)
    reg [AW-1:0] la;
    integer j;
    always @* begin
        la = {AW{1'b0}};
        for (j = DEPTH - 1; j >= 0; j = j - 1)
            if (hit[j]) la = j;
    end
    assign lk_found = |hit;
    assign lk_addr  = la;
endmodule
