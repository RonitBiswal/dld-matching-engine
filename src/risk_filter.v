module risk_filter #(
    parameter QTY_W = 16,
    parameter PRICE_W = 6,
    parameter MIN_QTY = 1,
    parameter MAX_QTY = 1000,
    parameter PRICE_MIN = 1,
    parameter PRICE_MAX = 63,
    parameter MAX_NOTIONAL = 50000
) (
    input wire [QTY_W-1:0] qty,
    input wire [PRICE_W-1:0] price,
    output wire ok,
    output wire [2:0] reason
);

localparam NW = QTY_W + PRICE_W;
localparam [63:0] MAXN = MAX_NOTIONAL;

wire qty_bad = (qty < MIN_QTY) || (qty > MAX_QTY);
wire price_bad = (price < PRICE_MIN) || (price > PRICE_MAX);

wire [NW-1:0] notional = qty * price;
wire [63:0] notional_ext = {{(64-NW){1'b0}}, notional};
wire notional_bad = (notional_ext > MAXN);

assign reason = {notional_bad, price_bad, qty_bad};
assign ok = ~(qty_bad | price_bad | notional_bad);


initial begin
    if (MIN_QTY > MAX_QTY)
        $display("risk_filter WARNING: MIN_QTY (%0d) > MAX_QTY (%0d): every order will be rejected", MIN_QTY, MAX_QTY);
    if (PRICE_MIN > PRICE_MAX)
        $display("risk_filter WARNING: PRICE_MIN (%0d) > PRICE_MAX (%0d): every order will be rejected", PRICE_MIN, PRICE_MAX);
    if (NW >= 64)
        $display("risk_filter WARNING: QTY_W+PRICE_W must be < 64");
end


endmodule
