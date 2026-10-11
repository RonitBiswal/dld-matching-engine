// =============================================================================
// quantity_arithmetic.v          Owner: Saurabhraj (Member 3)
// -----------------------------------------------------------------------------
// Quantity math for ONE trade between the incoming order and the best
// resting order.
//
//   trade_qty = min(in_qty, rest_qty)
//   in_rem    = in_qty   - trade_qty
//   rest_rem  = rest_qty - trade_qty
//   in_done   = (in_rem   == 0)   -> incoming fully filled
//   rest_done = (rest_rem == 0)   -> resting order fully filled (pop + free it)
//
// Because trade_qty <= both inputs, the subtractions can never underflow.
// Both flags can be 1 at the same time (exact fill).
// Purely combinational.
// =============================================================================
module quantity_arithmetic #(
    parameter QTY_W = 16
)(
    input  wire [QTY_W-1:0] in_qty,
    input  wire [QTY_W-1:0] rest_qty,
    output wire [QTY_W-1:0] trade_qty,
    output wire [QTY_W-1:0] in_rem,
    output wire [QTY_W-1:0] rest_rem,
    output wire             in_done,
    output wire             rest_done
);
    assign trade_qty = (in_qty < rest_qty) ? in_qty : rest_qty;   // min
    assign in_rem    = in_qty   - trade_qty;
    assign rest_rem  = rest_qty - trade_qty;
    assign in_done   = (in_rem   == {QTY_W{1'b0}});
    assign rest_done = (rest_rem == {QTY_W{1'b0}});
endmodule
