// =============================================================================
// compatibility_logic.v          Owner: Saurabhraj (Member 3)
// -----------------------------------------------------------------------------
// Decides whether an incoming order can trade against the best RESTING order
// on the opposite side of the book.
//
//   Incoming BUY  (in_side = 1): trades if in_price >= rest_price (resting ASK)
//   Incoming SELL (in_side = 0): trades if in_price <= rest_price (resting BID)
//
// rest_valid = 1 only when the opposite side actually has an order. If the
// opposite book is empty, rest_price is garbage, so can_match is forced to 0.
//
// Purely combinational: no clock, no reset. The FSM samples can_match in its
// CHECK state.
// =============================================================================
module compatibility_logic #(
    parameter PRICE_W = 6
)(
    input  wire                in_side,     // 1 = BUY, 0 = SELL
    input  wire [PRICE_W-1:0]  in_price,    // limit price of incoming order
    input  wire [PRICE_W-1:0]  rest_price,  // price of best resting order (opposite side)
    input  wire                rest_valid,  // 1 = opposite side is non-empty
    output wire                can_match
);
    wire buy_crosses  = (in_price >= rest_price);  // BUY  willing to pay >= ask
    wire sell_crosses = (in_price <= rest_price);  // SELL willing to take <= bid

    assign can_match = rest_valid & (in_side ? buy_crosses : sell_crosses);
endmodule
