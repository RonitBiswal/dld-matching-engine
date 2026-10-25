`timescale 1ns/1ps

module master_fsm_tb;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    reg in_valid  = 0;
    reg risk_ok   = 0;
    reg can_match = 0;
    reg in_done   = 0;
    reg room_ok   = 0;

    wire [2:0] state;
    wire st_idle, st_validate, st_discover, st_check;
    wire st_execute, st_insert, st_done, st_reject;
    wire in_ready, accept, done_pulse, reject_pulse;

    master_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .risk_ok(risk_ok),
        .can_match(can_match),
        .in_done(in_done),
        .room_ok(room_ok),
        .state(state),
        .st_idle(st_idle),
        .st_validate(st_validate),
        .st_discover(st_discover),
        .st_check(st_check),
        .st_execute(st_execute),
        .st_insert(st_insert),
        .st_done(st_done),
        .st_reject(st_reject),
        .in_ready(in_ready),
        .accept(accept),
        .done_pulse(done_pulse),
        .reject_pulse(reject_pulse)
    );

    localparam [2:0] IDLE     = 0,
                     VALIDATE = 1,
                     DISCOVER = 2,
                     CHECK    = 3,
                     EXECUTE  = 4,
                     INSERT   = 5,
                     DONE     = 6,
                     REJECT   = 7;

    integer errors = 0, checks = 0, i;

    function [2:0] golden_next;
        input [2:0] s;
        input iv, rok, cm, idn, room;
        begin
            case (s)
                IDLE: begin
                    if (iv)
                        golden_next = VALIDATE;
                    else
                        golden_next = IDLE;
                end
                VALIDATE: begin
                    if (rok)
                        golden_next = DISCOVER;
                    else
                        golden_next = REJECT;
                end
                DISCOVER: begin
                    golden_next = CHECK;
                end
                CHECK: begin
                    if (cm)
                        golden_next = EXECUTE;
                    else
                        golden_next = INSERT;
                end
                EXECUTE: begin
                    if (idn)
                        golden_next = DONE;
                    else
                        golden_next = DISCOVER;
                end
                INSERT: begin
                    if (room)
                        golden_next = DONE;
                    else
                        golden_next = REJECT;
                end
                default: begin
                    golden_next = IDLE;
                end
            endcase
        end
    endfunction

    task check_state(input [2:0] exp, input [511:0] name);
        begin
            #1;
            checks = checks + 1;

            if (state !== exp) begin
                errors = errors + 1;
                $display("FAIL: %0s expected state %0d got %0d (t=%0t)", name, exp, state, $time);
            end

            if ({st_reject, st_done, st_insert, st_execute,
                 st_check, st_discover, st_validate, st_idle} !== (8'b1 << state)) begin
                errors = errors + 1;
                $display("FAIL: one-hot decode wrong in state %0d", state);
            end

            if (in_ready !== (state == IDLE) ||
                done_pulse !== (state == DONE) ||
                reject_pulse !== (state == REJECT)) begin
                errors = errors + 1;
                $display("FAIL: in_ready/done/reject decode wrong in state %0d", state);
            end

            if (accept !== ((state == IDLE) && in_valid)) begin
                errors = errors + 1;
                $display("FAIL: accept wrong in state %0d (in_valid=%b)", state, in_valid);
            end
        end
    endtask

    task tick;
        begin
            @(negedge clk);
        end
    endtask

    task set_in(input iv, input rok, input cm, input idn, input room);
        begin
            in_valid  = iv;
            risk_ok   = rok;
            can_match = cm;
            in_done   = idn;
            room_ok   = room;
        end
    endtask

    integer    seed_state;
    reg [2:0]  model;
    reg [31:0] rng;

    initial begin
`ifdef __ICARUS__
        $dumpfile("sim/master_fsm.vcd");
        $dumpvars(0, master_fsm_tb);
`endif

        set_in(0,0,0,0,0);
        #22;
        check_state(IDLE, "state during reset");
        rst_n = 1;
        tick;
        check_state(IDLE, "IDLE after reset");

        tick;
        check_state(IDLE, "IDLE hold");

        set_in(0,1,1,1,1);
        tick;
        check_state(IDLE, "IDLE ignores other inputs");

        set_in(1,0,0,0,0);
        check_state(IDLE, "A: IDLE with in_valid");
        tick;
        check_state(VALIDATE, "A: VALIDATE");
        set_in(0,1,0,0,1);
        tick;
        check_state(DISCOVER, "A: DISCOVER");
        tick;
        check_state(CHECK, "A: CHECK");
        set_in(0,1,0,0,1);
        tick;
        check_state(INSERT, "A: INSERT (no match)");
        tick;
        check_state(DONE, "A: DONE");
        tick;
        check_state(IDLE, "A: back to IDLE");

        set_in(1,0,0,0,0);
        tick;
        check_state(VALIDATE, "B: VALIDATE");
        set_in(0,0,0,0,0);
        tick;
        check_state(REJECT, "B: REJECT (risk)");
        tick;
        check_state(IDLE, "B: back to IDLE");

        set_in(1,1,1,1,1);
        tick;
        check_state(VALIDATE, "C: VALIDATE");
        tick;
        check_state(DISCOVER, "C: DISCOVER");
        tick;
        check_state(CHECK, "C: CHECK");
        tick;
        check_state(EXECUTE, "C: EXECUTE (can_match=1)");
        tick;
        check_state(DONE, "C: DONE (in_done=1)");
        set_in(0,1,1,1,1);
        tick;
        check_state(IDLE, "C: back to IDLE");

        set_in(1,1,0,0,1);
        tick;
        check_state(VALIDATE, "D: VALIDATE");
        set_in(0,1,1,0,1);
        tick;
        check_state(DISCOVER, "D: DISCOVER #1");
        tick;
        check_state(CHECK, "D: CHECK #1");
        tick;
        check_state(EXECUTE, "D: EXECUTE #1");
        tick;
        check_state(DISCOVER, "D: loop back to DISCOVER #2");
        tick;
        check_state(CHECK, "D: CHECK #2");
        tick;
        check_state(EXECUTE, "D: EXECUTE #2");
        tick;
        check_state(DISCOVER, "D: loop back to DISCOVER #3");
        tick;
        check_state(CHECK, "D: CHECK #3");
        set_in(0,1,0,0,1);
        tick;
        check_state(INSERT, "D: INSERT after matching stopped");
        tick;
        check_state(DONE, "D: DONE");
        tick;
        check_state(IDLE, "D: IDLE");

        set_in(1,1,0,0,0);
        tick;
        check_state(VALIDATE, "E: VALIDATE");
        set_in(0,1,0,0,0);
        tick;
        tick;
        check_state(CHECK, "E: CHECK");
        tick;
        check_state(INSERT, "E: INSERT");
        tick;
        check_state(REJECT, "E: REJECT (room_ok=0)");
        tick;
        check_state(IDLE, "E: IDLE");

        set_in(1,1,0,0,1);
        tick;
        check_state(VALIDATE, "F: VALIDATE");
        set_in(1,1,0,0,1);
        tick;
        check_state(DISCOVER, "F: in_valid ignored in VALIDATE->DISCOVER");
        tick;
        check_state(CHECK, "F: CHECK, in_valid still high");
        tick;
        check_state(INSERT, "F: INSERT");
        tick;
        check_state(DONE, "F: DONE");
        tick;
        check_state(IDLE, "F: IDLE (in_valid still held high)");
        tick;
        check_state(VALIDATE, "F: held in_valid accepted in the IDLE cycle");
        set_in(0,0,0,0,0);
        tick;
        check_state(REJECT, "F: risk_ok=0 -> REJECT");
        tick;
        check_state(IDLE, "F: IDLE");

        set_in(1,1,1,0,1);
        tick;
        set_in(0,1,1,0,1);
        tick;
        check_state(DISCOVER, "R: mid-order");
        #2 rst_n = 0;
        #1;
        check_state(IDLE, "R: async reset takes effect without a clock edge");
        #3 rst_n = 1;
        tick;
        check_state(IDLE, "R: stays IDLE after reset release");

        rng   = 32'hC0FFEE01;
        model = IDLE;
        set_in(0,0,0,0,0);
        tick;

        for (i = 0; i < 20000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);

            set_in(rng[0], rng[1], rng[2], rng[3], rng[4]);
            model = golden_next(state, rng[0], rng[1], rng[2], rng[3], rng[4]);

            @(negedge clk);
            checks = checks + 1;

            if (state !== model) begin
                errors = errors + 1;
                $display("FAIL random cycle %0d: expected %0d got %0d", i, model, state);
            end
        end

        $display("master_fsm_tb: %0d checks, %0d errors", checks, errors);

        if (errors == 0)
            $display("MASTER_FSM_TB: PASS");
        else
            $display("MASTER_FSM_TB: FAIL");

        $finish;
    end

    initial begin
        #5000000;
        $display("MASTER_FSM_TB: FAIL (timeout)");
        $finish;
    end

endmodule
