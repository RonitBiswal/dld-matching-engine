module fifo_queue #(
    parameter LEVELS = 64,
    parameter SLOTS  = 16,
    parameter LW     = $clog2(LEVELS),
    parameter SW     = $clog2(SLOTS)
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          push_en,
    input  wire [LW-1:0] push_level,
    input  wire [SW-1:0] push_slot,
    input  wire          pop_en,
    input  wire [LW-1:0] pop_level,
    input  wire [LW-1:0] rd_level,
    output wire [SW-1:0] rd_head,
    output wire          rd_nonempty,
    output wire          rd_last
);

    reg [SW-1:0]     head [0:LEVELS-1];
    reg [SW-1:0]     tail [0:LEVELS-1];
    reg [SW-1:0]     nxt  [0:SLOTS-1];
    reg [LEVELS-1:0] ne;

    wire pop_ok           = pop_en && ne[pop_level];
    wire pop_single       = (head[pop_level] == tail[pop_level]);
    wire push_after_empty = pop_ok && pop_single && (pop_level == push_level);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ne <= 0;
            for (i = 0; i < LEVELS; i = i + 1) begin
                head[i] <= 0;
                tail[i] <= 0;
            end
            for (i = 0; i < SLOTS; i = i + 1)
                nxt[i] <= 0;
        end else begin
            if (pop_ok && pop_single)
                ne[pop_level] <= 1'b0;
            else if (pop_ok)
                head[pop_level] <= nxt[head[pop_level]];

            if (push_en && (!ne[push_level] || push_after_empty)) begin
                head[push_level] <= push_slot;
                tail[push_level] <= push_slot;
                ne[push_level]   <= 1'b1;
            end else if (push_en) begin
                nxt[tail[push_level]] <= push_slot;
                tail[push_level]      <= push_slot;
            end
        end
    end

    assign rd_head     = head[rd_level];
    assign rd_nonempty = ne[rd_level];
    assign rd_last     = ne[rd_level] && (head[rd_level] == tail[rd_level]);

endmodule
