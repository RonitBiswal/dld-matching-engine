`timescale 1ns/1ps

module free_list_tb;

    localparam SLOTS = 16, SW = 4, CW = 5;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    integer errors = 0, t, n;

    reg          alloc_en  = 0;
    reg          free_en   = 0;
    reg [SW-1:0] free_slot = 0;

    wire [SW-1:0] alloc_slot;
    wire          alloc_ok;
    wire [CW-1:0] free_count;

    free_list_allocator #(.SLOTS(SLOTS)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_en(alloc_en),
        .alloc_slot(alloc_slot),
        .alloc_ok(alloc_ok),
        .free_en(free_en),
        .free_slot(free_slot),
        .free_count(free_count)
    );

    reg          used_m [0:SLOTS-1];
    integer      mcount;
    reg [SW-1:0] got;
    reg          got_ok, do_a, do_f;

    task model_clear;
        integer q;
        begin
            for (q = 0; q < SLOTS; q = q + 1)
                used_m[q] = 0;
            mcount = SLOTS;
        end
    endtask

    task step(input a_en, input f_en, input [SW-1:0] f_s);
        begin
            @(negedge clk);
            alloc_en  = a_en;
            free_en   = f_en;
            free_slot = f_s;
            #1;

            got    = alloc_slot;
            got_ok = alloc_ok;

            if (got_ok !== (mcount > 0)) begin
                errors = errors + 1;
                $display("FAIL alloc_ok=%b but model free count=%0d", got_ok, mcount);
            end

            if (got_ok && used_m[got]) begin
                errors = errors + 1;
                $display("FAIL slot %0d offered but already in use", got);
            end

            @(negedge clk);
            alloc_en = 0;
            free_en  = 0;

            do_a = a_en && (mcount > 0);
            do_f = f_en && used_m[f_s];

            if (do_a) begin
                used_m[got] = 1;
                mcount = mcount - 1;
            end

            if (do_f) begin
                used_m[f_s] = 0;
                mcount = mcount + 1;
            end

            if (free_count !== mcount) begin
                errors = errors + 1;
                $display("FAIL free_count=%0d exp %0d", free_count, mcount);
            end
        end
    endtask

    task ALLOC;
        step(1, 0, 0);
    endtask

    task FREE(input [SW-1:0] s);
        step(0, 1, s);
    endtask

    reg [SW-1:0] seen [0:SLOTS-1];

    initial begin
        $dumpfile("sim/free_list.vcd");
        $dumpvars(0, free_list_tb);

        model_clear;
        #22 rst_n = 1;

        if (free_count !== SLOTS || alloc_ok !== 1) begin
            errors = errors + 1;
            $display("FAIL reset state");
        end

        for (n = 0; n < SLOTS; n = n + 1) begin
            ALLOC;
        end

        if (alloc_ok !== 0 || free_count !== 0) begin
            errors = errors + 1;
            $display("FAIL not exhausted");
        end

        ALLOC;
        ALLOC;

        FREE(9);
        if (alloc_slot !== 9 || alloc_ok !== 1) begin
            errors = errors + 1;
            $display("FAIL freed slot not next");
        end

        FREE(9);
        FREE(9);
        ALLOC;

        FREE(0);
        FREE(15);
        FREE(7);

        step(1, 1, 3);

        for (n = 0; n < SLOTS; n = n + 1)
            FREE(n);

        if (free_count !== SLOTS) begin
            errors = errors + 1;
            $display("FAIL not all free");
        end

        FREE(4);
        model_clear;

        for (n = 0; n < SLOTS - 1; n = n + 1)
            ALLOC;

        step(1, 1, 5);
        step(1, 1, 5);

        #3 rst_n = 0;
        #2 model_clear;
        #1 rst_n = 1;
        @(negedge clk);

        if (free_count !== SLOTS || alloc_ok !== 1) begin
            errors = errors + 1;
            $display("FAIL reset restore");
        end

        $dumpoff;

        for (t = 0; t < 5000; t = t + 1) begin : RND
            integer r;

            r = $urandom % 100;

            if (r < 40)
                ALLOC;
            else if (r < 70)
                FREE($urandom % SLOTS);
            else
                step($urandom % 2, $urandom % 2, $urandom % SLOTS);

            if (t % 700 == 699) begin
                for (n = 0; n < SLOTS; n = n + 1)
                    FREE(n);
            end

            if (t % 700 == 349) begin
                for (n = 0; n < SLOTS + 2; n = n + 1)
                    ALLOC;
            end
        end

        if (errors == 0)
            $display("FREE_LIST_TB: PASS");
        else
            $display("FREE_LIST_TB: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #200000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
