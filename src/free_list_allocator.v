module free_list_allocator #(
    parameter SLOTS = 16,
    parameter SW = $clog2(SLOTS),
    parameter CW = $clog2(SLOTS + 1)
)(
    input wire clk,
    input wire rst_n,
    input wire alloc_en,
    output wire [SW-1:0] alloc_slot,
    output wire alloc_ok,
    input wire free_en,
    input wire [SW-1:0] free_slot,
    output wire [CW-1:0] free_count
);

    reg [SW-1:0] fhead;
    reg [SW-1:0] nxt [0:SLOTS-1];
    reg [SLOTS-1:0] used;
    reg [CW-1:0] cnt;

    assign alloc_slot = fhead;
    assign alloc_ok = (cnt != 0);
    assign free_count = cnt;

    wire do_alloc = alloc_en && alloc_ok;
    wire do_free = free_en && used[free_slot];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fhead <= 0;
            cnt <= SLOTS;
            used <= 0;

            for (i = 0; i < SLOTS; i = i + 1)
                nxt[i] <= i + 1;

        end else begin
            if (do_alloc) begin
                used[fhead] <= 1'b1;
                fhead <= nxt[fhead];
            end

            if (do_free) begin
                used[free_slot] <= 1'b0;

                if (do_alloc)
                    nxt[free_slot] <= nxt[fhead];
                else
                    nxt[free_slot] <= fhead;

                fhead <= free_slot;
            end

            cnt <= cnt + do_free - do_alloc;
        end
    end

endmodule
