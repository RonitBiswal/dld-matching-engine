module compatibility_logic #(
    parameter PRICE_W = 6
)(
    input  wire                in_side,
    input  wire [PRICE_W-1:0]  in_price,
    input  wire [PRICE_W-1:0]  rest_price,
    input  wire                rest_valid,
    output wire                can_match
);
    // a buy needs a price at or above the ask, a sell at or below the bid
    wire buy_ok  = (in_price >= rest_price);
    wire sell_ok = (in_price <= rest_price);

    assign can_match = rest_valid & (in_side ? buy_ok : sell_ok);
endmodule