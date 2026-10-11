// price_bitmap.v  (Member 1 - Ronit)
// One bit per price level. Set when a level gets an order, cleared when it empties.
// Gives highest and lowest active level using hierarchical encoders.
// Requires PRICE_W >= 4 (LEVELS/8 groups must be >= 2).
// If set_en and clr_en target the SAME level in the same cycle, CLEAR wins
// (the clr assignment comes last). Different levels in the same cycle both work.
module price_bitmap #(parameter PRICE_W = 6, parameter LEVELS = (1<<PRICE_W)) (
    input  wire               clk, rst_n,
    input  wire               set_en,  input wire [PRICE_W-1:0] set_idx,
    input  wire               clr_en,  input wire [PRICE_W-1:0] clr_idx,
    output wire [LEVELS-1:0]  bitmap,
    output wire               any,
    output wire [PRICE_W-1:0] best_hi,   // highest active price (best BID)
    output wire [PRICE_W-1:0] best_lo    // lowest  active price (best ASK)
);
    reg [LEVELS-1:0] bm;
    assign bitmap = bm;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) bm <= {LEVELS{1'b0}};
        else begin
            if (set_en) bm[set_idx] <= 1'b1;
            if (clr_en) bm[clr_idx] <= 1'b0;
        end
    end
    // reversed copy so the same "highest-bit" encoder finds the lowest bit
    wire [LEVELS-1:0] rev;
    genvar k;
    generate for (k = 0; k < LEVELS; k = k + 1) begin : REV
        assign rev[k] = bm[LEVELS-1-k];
    end endgenerate
    wire [PRICE_W-1:0] hi_idx, rev_idx;
    wire v_hi, v_lo;
    hier_priority_encoder #(.GROUPS(LEVELS/8), .GW(8)) u_hi (.in(bm),  .idx(hi_idx),  .valid(v_hi));
    hier_priority_encoder #(.GROUPS(LEVELS/8), .GW(8)) u_lo (.in(rev), .idx(rev_idx), .valid(v_lo));
    assign any     = v_hi;
    assign best_hi = hi_idx;
    assign best_lo = (LEVELS-1) - rev_idx;
endmodule
