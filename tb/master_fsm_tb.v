// master_fsm_tb.v  (Member 4 - Yash)
// Self-checking testbench for master_fsm ONLY (needs no teammate modules).
//   1. directed: every state and every transition, every path through the machine
//   2. async reset in the middle of an order
//   3. Moore output decode check in every state
//   4. 20000 random cycles compared with an independent next-state model
// Prints "MASTER_FSM_TB: PASS" or "FAIL". Waveform: sim/master_fsm.vcd
`timescale 1ns/1ps
module master_fsm_tb;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg in_valid = 0, risk_ok = 0, can_match = 0, in_done = 0, room_ok = 0;
    wire [2:0] state;
    wire st_idle, st_validate, st_discover, st_check, st_execute, st_insert, st_done, st_reject;
    wire in_ready, accept, done_pulse, reject_pulse;

    master_fsm dut (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .risk_ok(risk_ok),
        .can_match(can_match), .in_done(in_done), .room_ok(room_ok), .state(state),
        .st_idle(st_idle), .st_validate(st_validate), .st_discover(st_discover), .st_check(st_check),
        .st_execute(st_execute), .st_insert(st_insert), .st_done(st_done), .st_reject(st_reject),
        .in_ready(in_ready), .accept(accept), .done_pulse(done_pulse), .reject_pulse(reject_pulse));

    localparam [2:0] IDLE=0, VALIDATE=1, DISCOVER=2, CHECK=3, EXECUTE=4, INSERT=5, DONE=6, REJECT=7;

    integer errors = 0, checks = 0, i;

    // ---------- independent golden next-state function ----------
    function [2:0] golden_next;
        input [2:0] s; input iv, rok, cm, idn, room;
        begin
            case (s)
                IDLE:     golden_next = iv  ? VALIDATE : IDLE;
                VALIDATE: golden_next = rok ? DISCOVER : REJECT;
                DISCOVER: golden_next = CHECK;
                CHECK:    golden_next = cm  ? EXECUTE  : INSERT;
                EXECUTE:  golden_next = idn ? DONE     : DISCOVER;
                INSERT:   golden_next = room ? DONE    : REJECT;
                default:  golden_next = IDLE;           // DONE, REJECT
            endcase
        end
    endfunction

    // check state and decoded outputs (called at negedge, signals are stable)
    task check_state(input [2:0] exp, input [511:0] name);
        begin
            #1;   // let combinational outputs settle after inputs changed
            checks = checks + 1;
            if (state !== exp) begin
                errors = errors + 1; $display("FAIL: %0s expected state %0d got %0d (t=%0t)", name, exp, state, $time);
            end
            // Moore decode: exactly the one-hot flag of the current state, plus derived outputs
            if ({st_reject, st_done, st_insert, st_execute, st_check, st_discover, st_validate, st_idle}
                !== (8'b1 << state)) begin
                errors = errors + 1; $display("FAIL: one-hot decode wrong in state %0d", state);
            end
            if (in_ready !== (state == IDLE) || done_pulse !== (state == DONE) || reject_pulse !== (state == REJECT)) begin
                errors = errors + 1; $display("FAIL: in_ready/done/reject decode wrong in state %0d", state);
            end
            if (accept !== ((state == IDLE) && in_valid)) begin
                errors = errors + 1; $display("FAIL: accept wrong in state %0d (in_valid=%b)", state, in_valid);
            end
        end
    endtask

    // advance one clock and wait for the next negedge (inputs are changed only at negedge)
    task tick; begin @(negedge clk); end endtask

    task set_in(input iv, input rok, input cm, input idn, input room);
        begin in_valid = iv; risk_ok = rok; can_match = cm; in_done = idn; room_ok = room; end
    endtask

    integer seed_state;
    reg [2:0] model;
    reg [31:0] rng;

    initial begin
`ifdef __ICARUS__          // VCD only for Icarus; Vivado uses its own waveform window
        $dumpfile("sim/master_fsm.vcd"); $dumpvars(0, master_fsm_tb);
`endif
        // ---------------- reset ----------------
        set_in(0,0,0,0,0);
        #22; check_state(IDLE, "state during reset");
        rst_n = 1; tick;
        check_state(IDLE, "IDLE after reset");

        // IDLE stays IDLE without in_valid
        tick; check_state(IDLE, "IDLE hold");
        // other inputs must be ignored in IDLE
        set_in(0,1,1,1,1); tick; check_state(IDLE, "IDLE ignores other inputs");

        // ---------- Path A: no match, order rests: IDLE V D C I DONE IDLE ----------
        set_in(1,0,0,0,0);  check_state(IDLE, "A: IDLE with in_valid");   // accept is high now
        tick; check_state(VALIDATE, "A: VALIDATE");
        set_in(0,1,0,0,1);  tick; check_state(DISCOVER, "A: DISCOVER");
        tick; check_state(CHECK, "A: CHECK");
        set_in(0,1,0,0,1);  tick; check_state(INSERT, "A: INSERT (no match)");
        tick; check_state(DONE, "A: DONE");
        tick; check_state(IDLE, "A: back to IDLE");

        // ---------- Path B: risk reject: IDLE V REJECT IDLE ----------
        set_in(1,0,0,0,0);  tick; check_state(VALIDATE, "B: VALIDATE");
        set_in(0,0,0,0,0);  tick; check_state(REJECT, "B: REJECT (risk)");
        tick; check_state(IDLE, "B: back to IDLE");

        // ---------- Path C: one trade, incoming done: IDLE V D C E DONE IDLE ----------
        set_in(1,1,1,1,1);  tick; check_state(VALIDATE, "C: VALIDATE");
        tick; check_state(DISCOVER, "C: DISCOVER");
        tick; check_state(CHECK, "C: CHECK");
        tick; check_state(EXECUTE, "C: EXECUTE (can_match=1)");
        tick; check_state(DONE, "C: DONE (in_done=1)");
        set_in(0,1,1,1,1);  tick; check_state(IDLE, "C: back to IDLE");

        // ---------- Path D: 3 trades then rest: E loops to D while in_done=0 ----------
        set_in(1,1,0,0,1);  tick; check_state(VALIDATE, "D: VALIDATE");
        set_in(0,1,1,0,1);  tick; check_state(DISCOVER, "D: DISCOVER #1");
        tick; check_state(CHECK, "D: CHECK #1");
        tick; check_state(EXECUTE, "D: EXECUTE #1");
        tick; check_state(DISCOVER, "D: loop back to DISCOVER #2");
        tick; check_state(CHECK, "D: CHECK #2");
        tick; check_state(EXECUTE, "D: EXECUTE #2");
        tick; check_state(DISCOVER, "D: loop back to DISCOVER #3");
        tick; check_state(CHECK, "D: CHECK #3");
        set_in(0,1,0,0,1);  tick; check_state(INSERT, "D: INSERT after matching stopped");
        tick; check_state(DONE, "D: DONE");
        tick; check_state(IDLE, "D: IDLE");

        // ---------- Path E: remainder cannot rest (book full): ... INSERT REJECT ----------
        set_in(1,1,0,0,0);  tick; check_state(VALIDATE, "E: VALIDATE");
        set_in(0,1,0,0,0);  tick; tick; check_state(CHECK, "E: CHECK");
        tick; check_state(INSERT, "E: INSERT");
        tick; check_state(REJECT, "E: REJECT (room_ok=0)");
        tick; check_state(IDLE, "E: IDLE");

        // ---------- in_valid is ignored while busy ----------
        set_in(1,1,0,0,1);  tick; check_state(VALIDATE, "F: VALIDATE");
        set_in(1,1,0,0,1);  tick; check_state(DISCOVER, "F: in_valid ignored in VALIDATE->DISCOVER");
        tick; check_state(CHECK, "F: CHECK, in_valid still high");
        tick; check_state(INSERT, "F: INSERT");
        tick; check_state(DONE, "F: DONE");
        tick; check_state(IDLE, "F: IDLE (in_valid still held high)");
        tick; check_state(VALIDATE, "F: held in_valid accepted in the IDLE cycle");
        set_in(0,0,0,0,0);  tick; check_state(REJECT, "F: risk_ok=0 -> REJECT");
        tick; check_state(IDLE, "F: IDLE");

        // ---------- async reset in the middle of an order ----------
        set_in(1,1,1,0,1);  tick; set_in(0,1,1,0,1); tick; check_state(DISCOVER, "R: mid-order");
        #2 rst_n = 0; #1;
        check_state(IDLE, "R: async reset takes effect without a clock edge");
        #3 rst_n = 1; tick; check_state(IDLE, "R: stays IDLE after reset release");

        // ---------- 20000 random cycles vs golden model ----------
        rng = 32'hC0FFEE01; model = IDLE;
        set_in(0,0,0,0,0); tick;
        for (i = 0; i < 20000; i = i + 1) begin
            rng = rng ^ (rng << 13); rng = rng ^ (rng >> 17); rng = rng ^ (rng << 5);
            set_in(rng[0], rng[1], rng[2], rng[3], rng[4]);
            model = golden_next(state, rng[0], rng[1], rng[2], rng[3], rng[4]);
            // predicted next state is compared after the next clock edge
            @(negedge clk);
            checks = checks + 1;
            if (state !== model) begin
                errors = errors + 1; $display("FAIL random cycle %0d: expected %0d got %0d", i, model, state);
            end
        end

        $display("master_fsm_tb: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("MASTER_FSM_TB: PASS"); else $display("MASTER_FSM_TB: FAIL");
        $finish;
    end

    // global timeout so a hang can never freeze the simulator
    initial begin #5000000; $display("MASTER_FSM_TB: FAIL (timeout)"); $finish; end
endmodule
