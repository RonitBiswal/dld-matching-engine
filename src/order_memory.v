module order_memory #(
    parameter DEPTH   = 16,
    parameter ID_W    = 16,
    parameter QTY_W   = 16,
    parameter PRICE_W = 6,
    parameter AW      = $clog2(DEPTH)
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               wr_en,
    input  wire [AW-1:0]      wr_addr,
    input  wire [ID_W-1:0]    wr_id,
    input  wire               wr_side,
    input  wire [PRICE_W-1:0] wr_price,
    input  wire [QTY_W-1:0]   wr_qty,
    input  wire               qty_wr_en,
    input  wire [AW-1:0]      qty_wr_addr,
    input  wire [QTY_W-1:0]   qty_wr_data,
    input  wire               inv_en,
    input  wire [AW-1:0]      inv_addr,
    input  wire [AW-1:0]      rd_addr,
    output wire [ID_W-1:0]    rd_id,
    output wire               rd_side,
    output wire [PRICE_W-1:0] rd_price,
    output wire [QTY_W-1:0]   rd_qty,
    output wire               rd_valid,
    input  wire [ID_W-1:0]    lk_id,
    output wire               lk_found,
    output wire [AW-1:0]      lk_addr
);

    reg [ID_W-1:0]    id_q    [0:DEPTH-1];
    reg [DEPTH-1:0]   side_q;
    reg [PRICE_W-1:0] price_q [0:DEPTH-1];
    reg [QTY_W-1:0]   qty_q   [0:DEPTH-1];
    reg [DEPTH-1:0]   valid_q;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                id_q[i]    <= 0;
                price_q[i] <= 0;
                qty_q[i]   <= 0;
            end
            side_q  <= 0;
            valid_q <= 0;
        end else begin
            if (qty_wr_en)
                qty_q[qty_wr_addr] <= qty_wr_data;

            if (inv_en)
                valid_q[inv_addr] <= 1'b0;

            if (wr_en) begin
                id_q[wr_addr]    <= wr_id;
                side_q[wr_addr]  <= wr_side;
                price_q[wr_addr] <= wr_price;
                qty_q[wr_addr]   <= wr_qty;
                valid_q[wr_addr] <= 1'b1;
            end
        end
    end

    assign rd_id    = id_q[rd_addr];
    assign rd_side  = side_q[rd_addr];
    assign rd_price = price_q[rd_addr];
    assign rd_qty   = qty_q[rd_addr];
    assign rd_valid = valid_q[rd_addr];

    wire [DEPTH-1:0] hit;
    genvar g;

    generate
        for (g = 0; g < DEPTH; g = g + 1) begin : CAM
            assign hit[g] = valid_q[g] && (id_q[g] == lk_id);
        end
    endgenerate

    reg [AW-1:0] la;
    integer j;

    always @* begin
        la = 0;
        for (j = DEPTH - 1; j >= 0; j = j - 1) begin
            if (hit[j])
                la = j;
        end
    end

    assign lk_found = |hit;
    assign lk_addr  = la;

endmodule
