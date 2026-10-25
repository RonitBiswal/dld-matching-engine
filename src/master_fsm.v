module master_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,
    input  wire       risk_ok,
    input  wire       can_match,
    input  wire       in_done,
    input  wire       room_ok,
    output reg  [2:0] state,
    output wire       st_idle, st_validate, st_discover, st_check,
    output wire       st_execute, st_insert, st_done, st_reject,
    output wire       in_ready,
    output wire       accept,
    output wire       done_pulse,
    output wire       reject_pulse
);
    localparam [2:0] S_IDLE     = 3'd0,
                     S_VALIDATE = 3'd1,
                     S_DISCOVER = 3'd2,
                     S_CHECK    = 3'd3,
                     S_EXECUTE  = 3'd4,
                     S_INSERT   = 3'd5,
                     S_DONE     = 3'd6,
                     S_REJECT   = 3'd7;

    reg [2:0] next_state;

    always @* begin
        next_state = S_IDLE;
        case (state)
            S_IDLE:     next_state = in_valid  ? S_VALIDATE : S_IDLE;
            S_VALIDATE: next_state = risk_ok   ? S_DISCOVER : S_REJECT;
            S_DISCOVER: next_state = S_CHECK;
            S_CHECK:    next_state = can_match ? S_EXECUTE  : S_INSERT;
            S_EXECUTE:  next_state = in_done   ? S_DONE     : S_DISCOVER;
            S_INSERT:   next_state = room_ok   ? S_DONE     : S_REJECT;
            S_DONE:     next_state = S_IDLE;
            S_REJECT:   next_state = S_IDLE;
            default:    next_state = S_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    assign st_idle     = (state == S_IDLE);
    assign st_validate = (state == S_VALIDATE);
    assign st_discover = (state == S_DISCOVER);
    assign st_check    = (state == S_CHECK);
    assign st_execute  = (state == S_EXECUTE);
    assign st_insert   = (state == S_INSERT);
    assign st_done     = (state == S_DONE);
    assign st_reject   = (state == S_REJECT);
    
    assign in_ready     = st_idle;
    assign accept       = st_idle & in_valid;
    assign done_pulse   = st_done;
    assign reject_pulse = st_reject;
endmodule
