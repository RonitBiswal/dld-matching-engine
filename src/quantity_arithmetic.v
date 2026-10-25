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
    assign trade_qty = (in_qty < rest_qty) ? in_qty : rest_qty;

    assign in_rem   = in_qty   - trade_qty;
    assign rest_rem = rest_qty - trade_qty;

    assign in_done   = (in_rem   == 0);
    assign rest_done = (rest_rem == 0);
endmodule