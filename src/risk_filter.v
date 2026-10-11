// risk_filter.v  (Member 5 - Niket / 2025csb1446)
// -----------------------------------------------------------------------------
// Parallel pre-trade risk filter. PURELY COMBINATIONAL (no clock, no state).
// Three independent checks run at the same time on the incoming order:
//
//   reason[0]  bad quantity        : qty < MIN_QTY  OR  qty > MAX_QTY
//   reason[1]  outside price band  : price < PRICE_MIN  OR  price > PRICE_MAX
//   reason[2]  notional too large  : qty * price > MAX_NOTIONAL
//
//   ok = 1 only when ALL three checks pass (reason == 3'b000).
//
// Because the three checks do not depend on each other, the hardware is three
// comparator groups side by side + one multiplier, joined by a small OR/NOR.
// More than one reason bit can be set at once (e.g. 3'b101 = bad qty AND notional).
//
// The master FSM (Member 4) uses it in the VALIDATE state:
//   ok = 1  -> go on to DISCOVER (matching)
//   ok = 0  -> go to REJECT and report reason[2:0] as reject_code.
//
// Notes
//  * The multiplier output is QTY_W+PRICE_W bits wide, so the product can never
//    overflow (max qty * max price always fits). A narrower product would WRAP
//    AROUND and wrongly accept huge orders - the testbench has a test for this.
//  * Limits are INCLUSIVE: qty == MAX_QTY, price == PRICE_MIN and
//    qty*price == MAX_NOTIONAL are all accepted.
//  * Default values are the Stage 2 team settings (see report). The top level
//    may override them when it instantiates this module.
// -----------------------------------------------------------------------------
module risk_filter #(
    parameter QTY_W        = 16,
    parameter PRICE_W      = 6,
    parameter MIN_QTY      = 1,       // smallest allowed quantity (1 -> rejects qty = 0)
    parameter MAX_QTY      = 1000,    // largest allowed quantity
    parameter PRICE_MIN    = 1,       // lowest allowed price tick
    parameter PRICE_MAX    = 63,      // highest allowed price tick (2^6 - 1)
    parameter MAX_NOTIONAL = 50000    // largest allowed price*quantity
) (
    input  wire [QTY_W-1:0]   qty,
    input  wire [PRICE_W-1:0] price,
    output wire               ok,
    output wire [2:0]         reason    // bit0 bad qty, bit1 price band, bit2 notional
);
    // Product width = sum of operand widths -> the multiply can never overflow.
    localparam NW = QTY_W + PRICE_W;

    // 64-bit copy of the limit so the compare is always unsigned and never truncated.
    localparam [63:0] MAXN = MAX_NOTIONAL;

    // ---- check 0: quantity range -------------------------------------------
    wire qty_bad   = (qty < MIN_QTY) || (qty > MAX_QTY);

    // ---- check 1: price band -----------------------------------------------
    wire price_bad = (price < PRICE_MIN) || (price > PRICE_MAX);

    // ---- check 2: notional (price * quantity) ------------------------------
    wire [NW-1:0] notional = qty * price;                    // full-width product
    wire [63:0]   notional_ext = {{(64-NW){1'b0}}, notional}; // zero-extend for compare
    wire notional_bad = (notional_ext > MAXN);

    // ---- combine ------------------------------------------------------------
    assign reason = {notional_bad, price_bad, qty_bad};
    assign ok     = ~(qty_bad | price_bad | notional_bad);   // all three passed

    // Simulation-only sanity check of the parameters (ignored by synthesis).
    // synthesis translate_off
    initial begin
        if (MIN_QTY > MAX_QTY)
            $display("risk_filter WARNING: MIN_QTY (%0d) > MAX_QTY (%0d): every order will be rejected", MIN_QTY, MAX_QTY);
        if (PRICE_MIN > PRICE_MAX)
            $display("risk_filter WARNING: PRICE_MIN (%0d) > PRICE_MAX (%0d): every order will be rejected", PRICE_MIN, PRICE_MAX);
        if (NW >= 64)
            $display("risk_filter WARNING: QTY_W+PRICE_W must be < 64");
    end
    // synthesis translate_on
endmodule
