// fifo_queue.v  (Member 2 - Shalin)
// One FIFO of order SLOT NUMBERS for every price level, built as linked lists:
//   head[level] -> slot -> nxt[slot] -> ... -> tail[level]
// Orders at the same price keep arrival order (time priority): push at the tail, pop at the head.
// The queue stores only slot numbers; the order data lives in order_memory.
// A slot is in at most ONE queue at a time, so a single nxt[] table (one entry per slot) is enough.
//
// Read port : rd_level selects a level (combinational) -> rd_head (oldest slot), rd_nonempty,
//             rd_last (that slot is the ONLY order at the level -> popping empties the level,
//             so the top level should clear the price-bitmap bit).
// Same-cycle push+pop is legal, on the same or different levels:
//   * pop on an empty level is ignored (underflow protection)
//   * pop empties a 1-entry level while a push hits it -> the level ends up holding just the pushed slot
// Caller rules: never push a slot that is already queued; never push onto a full level
// (cannot happen when SLOTS orders are shared, because there are only SLOTS slots).
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
    reg [LEVELS-1:0] ne;                    // level non-empty
    reg [SW-1:0]     nxt  [0:SLOTS-1];      // next-slot pointer of every slot

    // ---- facts about the levels touched this cycle (values BEFORE the clock edge) ----
    wire pop_ok     = pop_en & ne[pop_level];                       // pop on empty level is ignored
    wire pop_single = (head[pop_level] == tail[pop_level]);         // only meaningful if level non-empty
    // this pop empties the very level that is being pushed to
    wire push_after_empty = pop_ok & pop_single & (pop_level == push_level);

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ne <= {LEVELS{1'b0}};
            for (k = 0; k < LEVELS; k = k + 1) begin
                head[k] <= {SW{1'b0}};
                tail[k] <= {SW{1'b0}};
            end
            for (k = 0; k < SLOTS; k = k + 1) nxt[k] <= {SW{1'b0}};
        end else begin
            // ---- POP: move head to the next slot, or mark the level empty ----
            if (pop_ok) begin
                if (pop_single) ne[pop_level]   <= 1'b0;
                else            head[pop_level] <= nxt[head[pop_level]];
            end
            // ---- PUSH (written after POP so its assignments win on the same level) ----
            if (push_en) begin
                if (!ne[push_level] || push_after_empty) begin      // level will be empty -> new 1-entry list
                    head[push_level] <= push_slot;
                    tail[push_level] <= push_slot;
                    ne[push_level]   <= 1'b1;
                end else begin                                      // append behind the current tail
                    nxt[tail[push_level]] <= push_slot;
                    tail[push_level]      <= push_slot;
                end
            end
        end
    end

    assign rd_head     = head[rd_level];
    assign rd_nonempty = ne[rd_level];
    assign rd_last     = ne[rd_level] & (head[rd_level] == tail[rd_level]);
endmodule
