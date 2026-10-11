// priority_encoder.v  (Member 1 - Ronit)
// Flat priority encoder: returns index of the HIGHEST set bit.
// Also contains the hierarchical version (GROUPS local encoders + 1 global encoder).
module priority_encoder #(parameter W = 8, parameter IDXW = $clog2(W)) (
    input  wire [W-1:0]    in,
    output reg  [IDXW-1:0] idx,
    output wire            valid
);
    integer i;
    assign valid = |in;
    always @* begin
        idx = {IDXW{1'b0}};
        for (i = 0; i < W; i = i + 1)
            if (in[i]) idx = i[IDXW-1:0];   // later (higher) bit overrides
    end
endmodule

// Hierarchical: e.g. 64 levels = 8 groups x 8 bits.
module hier_priority_encoder #(
    parameter GROUPS = 8,
    parameter GW     = 8,
    parameter N      = GROUPS*GW,
    parameter IDXW   = $clog2(N)
) (
    input  wire [N-1:0]    in,
    output wire [IDXW-1:0] idx,
    output wire            valid
);
    localparam LW = $clog2(GW);
    localparam GIW = $clog2(GROUPS);
    wire [GROUPS-1:0]    grp_valid;
    wire [GROUPS*LW-1:0] loc_idx;
    genvar g;
    generate
        for (g = 0; g < GROUPS; g = g + 1) begin : LOCAL
            priority_encoder #(.W(GW)) u_loc (
                .in(in[g*GW +: GW]), .idx(loc_idx[g*LW +: LW]), .valid(grp_valid[g]));
        end
    endgenerate
    wire [GIW-1:0] gidx;
    priority_encoder #(.W(GROUPS)) u_glob (.in(grp_valid), .idx(gidx), .valid(valid));
    assign idx = {gidx, loc_idx[gidx*LW +: LW]};
endmodule
