`timescale 1ns/1ps

module fifo_queue_tb;

    localparam LEVELS = 64, SLOTS = 16, LW = 6, SW = 4;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    integer errors = 0, t, n;

    reg          push_en    = 0;
    reg          pop_en     = 0;
    reg [LW-1:0] push_level = 0;
    reg [LW-1:0] pop_level  = 0;
    reg [LW-1:0] rd_level   = 0;
    reg [SW-1:0] push_slot  = 0;

    wire [SW-1:0] rd_head;
    wire          rd_nonempty, rd_last;

    fifo_queue #(.LEVELS(LEVELS), .SLOTS(SLOTS)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .push_en(push_en),
        .push_level(push_level),
        .push_slot(push_slot),
        .pop_en(pop_en),
        .pop_level(pop_level),
        .rd_level(rd_level),
        .rd_head(rd_head),
        .rd_nonempty(rd_nonempty),
        .rd_last(rd_last)
    );

    reg [SW-1:0] mq   [0:LEVELS*SLOTS-1];
    integer      mlen [0:LEVELS-1];
    reg          inq  [0:SLOTS-1];

    task model_clear;
        integer q;
        begin
            for (q = 0; q < LEVELS; q = q + 1)
                mlen[q] = 0;
            for (q = 0; q < SLOTS; q = q + 1)
                inq[q] = 0;
        end
    endtask

    task audit;
        integer l;
        begin
            for (l = 0; l < LEVELS; l = l + 1) begin
                rd_level = l;
                #1;

                if (rd_nonempty !== (mlen[l] > 0)) begin
                    errors = errors + 1;
                    $display("FAIL nonempty level %0d: got %b exp %b", l, rd_nonempty, mlen[l] > 0);
                end

                if (rd_last !== (mlen[l] == 1)) begin
                    errors = errors + 1;
                    $display("FAIL last level %0d: got %b exp %b", l, rd_last, mlen[l] == 1);
                end

                if (mlen[l] > 0 && rd_head !== mq[l*SLOTS]) begin
                    errors = errors + 1;
                    $display("FAIL head level %0d: got %0d exp %0d", l, rd_head, mq[l*SLOTS]);
                end
            end
        end
    endtask

    task step(
        input          p_en,
        input [LW-1:0] p_l,
        input [SW-1:0] p_s,
        input          o_en,
        input [LW-1:0] o_l
    );
        integer j;
        begin
            @(negedge clk);
            push_en    = p_en;
            push_level = p_l;
            push_slot  = p_s;
            pop_en     = o_en;
            pop_level  = o_l;

            @(negedge clk);
            push_en = 0;
            pop_en  = 0;

            if (o_en && mlen[o_l] > 0) begin
                inq[mq[o_l*SLOTS]] = 0;
                for (j = 0; j < mlen[o_l] - 1; j = j + 1)
                    mq[o_l*SLOTS + j] = mq[o_l*SLOTS + j + 1];
                mlen[o_l] = mlen[o_l] - 1;
            end

            if (p_en) begin
                mq[p_l*SLOTS + mlen[p_l]] = p_s;
                mlen[p_l] = mlen[p_l] + 1;
                inq[p_s] = 1;
            end

            audit;
        end
    endtask

    task PUSH(input [LW-1:0] l, input [SW-1:0] s);
        step(1, l, s, 0, 0);
    endtask

    task POP(input [LW-1:0] l);
        step(0, 0, 0, 1, l);
    endtask

    initial begin
        $dumpfile("sim/fifo_queue.vcd");
        $dumpvars(0, fifo_queue_tb);

        model_clear;
        #22 rst_n = 1;
        audit;

        PUSH(5, 1);
        PUSH(5, 2);
        PUSH(5, 3);
        POP(5);
        POP(5);
        POP(5);
        POP(5);

        PUSH(0, 4);
        PUSH(63, 5);
        PUSH(31, 6);
        POP(31);
        POP(0);
        POP(63);

        step(1, 9, 7, 1, 9);
        step(1, 9, 8, 1, 9);
        PUSH(9, 9);
        step(1, 9, 10, 1, 9);
        step(1, 20, 7, 1, 9);
        POP(9);
        POP(9);
        POP(20);

        PUSH(40, 7);
        PUSH(41, 8);
        POP(40);
        POP(41);

        for (n = 0; n < SLOTS; n = n + 1)
            PUSH(17, n);
        for (n = 0; n < SLOTS; n = n + 1)
            POP(17);

        PUSH(3, 1);
        PUSH(3, 2);
        PUSH(60, 3);
        #3 rst_n = 0;
        #2 model_clear;
        #1 rst_n = 1;
        audit;

        $dumpoff;

        for (t = 0; t < 6000; t = t + 1) begin : RND
            reg          do_push, do_pop;
            reg [LW-1:0] pl, ol;
            reg [SW-1:0] ps;
            integer      tries, pick, l;

            do_push = ($urandom % 100) < 55;
            do_pop  = ($urandom % 100) < 55;

            if (($urandom % 4) == 0)
                pl = $urandom % LEVELS;
            else if (($urandom % 2) == 0)
                pl = 0;
            else
                pl = ($urandom % 3) + 30;

            if (($urandom % 4) == 0)
                ol = $urandom % LEVELS;
            else
                ol = pl;

            if (($urandom % 2) == 0) begin
                pick = $urandom % LEVELS;
                for (l = 0; l < LEVELS; l = l + 1) begin
                    if (mlen[(pick + l) % LEVELS] > 0 && ($urandom % 3) != 0)
                        ol = (pick + l) % LEVELS;
                end
            end

            ps = $urandom % SLOTS;
            tries = 0;
            while (inq[ps] && tries < SLOTS) begin
                ps = (ps + 1) % SLOTS;
                tries = tries + 1;
            end
            if (inq[ps])
                do_push = 0;

            step(do_push, pl, ps, do_pop, ol);
        end

        if (errors == 0)
            $display("FIFO_QUEUE_TB: PASS");
        else
            $display("FIFO_QUEUE_TB: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #200000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
