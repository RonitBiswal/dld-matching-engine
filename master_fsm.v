// master_fsm.v  (Member 4 - Yash, 2025csb1268)
// -----------------------------------------------------------------------------
// Control FSM of the matching engine. It only decides WHICH STEP we are in;
// matching_engine_top.v does the actual data movement for each step.
//
//   IDLE --in_valid--> VALIDATE --risk_ok--> DISCOVER --> CHECK --can_match--> EXECUTE
//                          |                    ^           |                    |
//                          |                    |           +--no match--> INSERT |
//                          |                    +----- not in_done ---------------+
//                          |                                         in_done --> DONE
//   VALIDATE --!risk_ok--> REJECT        INSERT --room_ok--> DONE ; INSERT --!room_ok--> REJECT
//   DONE -> IDLE ; REJECT -> IDLE
//
// All outputs are decoded straight from the state register (Moore machine), so
// they are glitch-free and stay stable for the whole clock cycle.
// 3 bits give 8 codes and we use all 8, so there is no illegal state to recover from.
// -----------------------------------------------------------------------------
module master_fsm (
    input  wire       clk,
    input  wire       rst_n,        // async, active low
    // status from the datapath
    input  wire       in_valid,     // a new order is being offered
    input  wire       risk_ok,      // risk_filter says the latched order is legal
    input  wire       can_match,    // compatibility_logic: incoming crosses best resting order
    input  wire       in_done,      // quantity_arithmetic: incoming order has 0 left after this trade
    input  wire       room_ok,      // a free order slot exists (free_count != 0)
    // state and decoded outputs
    output reg  [2:0] state,
    output wire       st_idle, st_validate, st_discover, st_check,
    output wire       st_execute, st_insert, st_done, st_reject,
    output wire       in_ready,     // high only in IDLE
    output wire       accept,       // IDLE and in_valid: datapath latches the order on this edge
    output wire       done_pulse,   // 1 cycle: order fully processed (not rejected)
    output wire       reject_pulse  // 1 cycle: order rejected
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

    // ---- next-state logic (purely combinational) ----
    always @* begin
        next_state = S_IDLE;
        case (state)
            S_IDLE:     next_state = in_valid  ? S_VALIDATE : S_IDLE;
            S_VALIDATE: next_state = risk_ok   ? S_DISCOVER : S_REJECT;
            S_DISCOVER: next_state = S_CHECK;
            S_CHECK:    next_state = can_match ? S_EXECUTE  : S_INSERT;
            S_EXECUTE:  next_state = in_done   ? S_DONE     : S_DISCOVER;   // loop for multi-level fills
            S_INSERT:   next_state = room_ok   ? S_DONE     : S_REJECT;
            S_DONE:     next_state = S_IDLE;
            S_REJECT:   next_state = S_IDLE;
            default:    next_state = S_IDLE;
        endcase
    end

    // ---- state register ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    // ---- Moore output decode ----
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
