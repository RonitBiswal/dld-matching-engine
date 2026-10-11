// free_list_allocator.v  (Member 2 - Shalin)
// Keeps track of which order-memory slots are free, as a linked free list:
//   free_head -> slot -> nxt[slot] -> ...        (free_count says how many are really in the list)
//  * alloc : alloc_slot always shows the slot that WOULD be given next (= free_head) and alloc_ok says
//            one exists (free_count != 0). Pulse alloc_en in the same cycle you use alloc_slot; the slot
//            is consumed at the clock edge. alloc_en with no free slot is ignored (alloc_ok = 0 = "book full").
//  * free  : pulse free_en with free_slot to give a slot back (it becomes the next one handed out, LIFO).
//  * Extra safety (my addition): an in-use bit per slot, so freeing a slot that is already free
//    (double free) is ignored and cannot corrupt the list.
//  * alloc and free in the same cycle are both handled; the freed slot is the next one allocated.
module free_list_allocator #(
    parameter SLOTS = 16,
    parameter SW    = $clog2(SLOTS),
    parameter CW    = $clog2(SLOTS + 1)
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          alloc_en,
    output wire [SW-1:0] alloc_slot,
    output wire          alloc_ok,
    input  wire          free_en,
    input  wire [SW-1:0] free_slot,
    output wire [CW-1:0] free_count
);
    reg [SW-1:0]    fhead;
    reg [SW-1:0]    nxt [0:SLOTS-1];
    reg [SLOTS-1:0] used;
    reg [CW-1:0]    cnt;

    assign alloc_slot = fhead;
    assign alloc_ok   = (cnt != 0);
    assign free_count = cnt;

    wire do_alloc = alloc_en & alloc_ok;
    wire do_free  = free_en & used[free_slot];     // only slots that are really in use can be freed

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fhead <= {SW{1'b0}};
            cnt   <= SLOTS;
            used  <= {SLOTS{1'b0}};
            for (k = 0; k < SLOTS; k = k + 1) nxt[k] <= k + 1;   // 0->1->2->...->SLOTS-1
        end else begin
            if (do_alloc) begin
                used[fhead] <= 1'b1;
                fhead       <= nxt[fhead];
            end
            if (do_free) begin
                used[free_slot] <= 1'b0;
                // new list head = freed slot; it points at whatever head is after this cycle's alloc
                if (do_alloc) nxt[free_slot] <= nxt[fhead];
                else          nxt[free_slot] <= fhead;
                fhead           <= free_slot;
            end
            cnt <= cnt + do_free - do_alloc;
        end
    end
endmodule
