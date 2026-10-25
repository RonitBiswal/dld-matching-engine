`timescale 1ns/1ps
module risk_filter_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg [15:0] qa; reg [5:0] pa; wire okA; wire [2:0] rA;
    reg [7:0] qb; reg [3:0] pb; wire okB; wire [2:0] rB;
                                    wire okC; wire [2:0] rC;

    reg [8*28-1:0] label;

    integer errors = 0;
    integer checks = 0;
    integer i, j, n, pr;

    risk_filter #(.QTY_W(16), .PRICE_W(6), .MIN_QTY(1), .MAX_QTY(1000),
                  .PRICE_MIN(1), .PRICE_MAX(63), .MAX_NOTIONAL(50000))
        DUT_A (.qty(qa), .price(pa), .ok(okA), .reason(rA));

    risk_filter #(.QTY_W(8), .PRICE_W(4), .MIN_QTY(2), .MAX_QTY(200),
                  .PRICE_MIN(3), .PRICE_MAX(12), .MAX_NOTIONAL(1000))
        DUT_B (.qty(qb), .price(pb), .ok(okB), .reason(rB));

    risk_filter #(.QTY_W(8), .PRICE_W(4), .MIN_QTY(0), .MAX_QTY(255),
                  .PRICE_MIN(0), .PRICE_MAX(15), .MAX_NOTIONAL(3825))
        DUT_C (.qty(qb), .price(pb), .ok(okC), .reason(rC));

    function [2:0] golden;
        input [63:0] q, p, minq, maxq, pmin, pmax, maxn;
        reg [63:0] notional;
        reg b0, b1, b2;
        begin
            notional = q * p;
            b0 = 0; b1 = 0; b2 = 0;
            if (q < minq) b0 = 1;
            else if (q > maxq) b0 = 1;
            if (p < pmin) b1 = 1;
            else if (p > pmax) b1 = 1;
            if (notional > maxn) b2 = 1;
            golden = {b2, b1, b0};
        end
    endfunction

    task test_a;
        input [15:0] q;
        input [5:0] p;
        input [2:0] exp_reason;
        reg [2:0] g;
        begin
            @(negedge clk);
            qa = q; pa = p;
            #2;
            g = golden(q, p, 1, 1000, 1, 63, 50000);
            checks = checks + 1;
            if (rA !== exp_reason || okA !== (exp_reason == 3'b000) || g !== exp_reason) begin
                errors = errors + 1;
                $display("FAIL [%0s] qty=%0d price=%0d : reason=%b ok=%b  expected reason=%b (golden %b)",
                         label, q, p, rA, okA, exp_reason, g);
            end
        end
    endtask

    task auto_a;
        input [15:0] q;
        input [5:0] p;
        reg [2:0] g;
        begin
            @(negedge clk);
            qa = q; pa = p;
            #2;
            g = golden(q, p, 1, 1000, 1, 63, 50000);
            checks = checks + 1;
            if (rA !== g || okA !== (g == 3'b000)) begin
                errors = errors + 1;
                $display("FAIL [%0s] qty=%0d price=%0d : reason=%b ok=%b  golden=%b", label, q, p, rA, okA, g);
            end
        end
    endtask

    task auto_bc;
        input [7:0] q;
        input [3:0] p;
        reg [2:0] gb, gc;
        begin
            @(negedge clk);
            qb = q; pb = p;
            #2;
            gb = golden(q, p, 2, 200, 3, 12, 1000);
            gc = golden(q, p, 0, 255, 0, 15, 3825);
            checks = checks + 2;
            if (rB !== gb || okB !== (gb == 3'b000)) begin
                errors = errors + 1;
                $display("FAIL [DUT_B] qty=%0d price=%0d : reason=%b ok=%b golden=%b", q, p, rB, okB, gb);
            end
            if (rC !== gc || okC !== (gc == 3'b000)) begin
                errors = errors + 1;
                $display("FAIL [DUT_C] qty=%0d price=%0d : reason=%b ok=%b golden=%b", q, p, rC, okC, gc);
            end
        end
    endtask

    reg [15:0] qlist [0:19];
    initial begin
        qlist[0] = 0; qlist[1] = 1; qlist[2] = 2; qlist[3] = 49;
        qlist[4] = 50; qlist[5] = 100; qlist[6] = 500; qlist[7] = 794;
        qlist[8] = 795; qlist[9] = 796; qlist[10] = 999; qlist[11] = 1000;
        qlist[12] = 1001; qlist[13] = 1024; qlist[14] = 2000; qlist[15] = 4096;
        qlist[16] = 32768; qlist[17] = 40000; qlist[18] = 65534; qlist[19] = 65535;
    end

    initial begin
        $dumpfile("risk_filter.vcd");
        $dumpvars(0, risk_filter_tb);
        label = "start"; qa = 0; pa = 0; qb = 0; pb = 0;
        repeat (3) @(negedge clk);

        label = "worked example";
        test_a(100, 50, 3'b000);
        test_a(50, 50, 3'b000);
        test_a(200, 49, 3'b000);
        test_a(180, 49, 3'b000);

        label = "qty lower boundary";
        test_a(0, 30, 3'b001);
        test_a(1, 30, 3'b000);
        label = "qty upper boundary";
        test_a(999, 10, 3'b000);
        test_a(1000, 10, 3'b000);
        test_a(1001, 10, 3'b001);

        label = "price lower boundary";
        test_a(10, 0, 3'b010);
        test_a(10, 1, 3'b000);
        label = "price upper boundary";
        test_a(10, 62, 3'b000);
        test_a(10, 63, 3'b000);

        label = "notional boundary";

        test_a(1000, 50, 3'b000);
        test_a(1000, 51, 3'b100);
        test_a(999, 50, 3'b000);

        test_a(793, 63, 3'b000);
        test_a(794, 63, 3'b100);

        test_a(1000, 25, 3'b000);

        label = "multiple reasons";
        test_a(0, 0, 3'b011);
        test_a(2000, 40, 3'b101);
        test_a(65535, 1, 3'b101);
        test_a(1001, 0, 3'b011);
        test_a(0, 63, 3'b001);
        test_a(1001, 63, 3'b101);

        label = "16-bit overflow trap";

        test_a(2000, 40, 3'b101);

        test_a(4096, 16, 3'b101);

        test_a(65535, 63, 3'b101);

        label = "bad qty and bad price";
        test_a(0, 0, 3'b011);
        test_a(65535, 0, 3'b011);

        label = "sweep price x qty list";
        for (i = 0; i < 20; i = i + 1)
            for (j = 0; j < 64; j = j + 1)
                auto_a(qlist[i], j[5:0]);

        label = "exhaustive B and C";
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 16; j = j + 1)
                auto_bc(i[7:0], j[3:0]);

        label = "random";
        for (n = 0; n < 30000; n = n + 1) begin
            case ($urandom % 4)
                0: auto_a($urandom, $urandom);
                1: auto_a($urandom % 1100, $urandom);
                2: begin
                       pr = ($urandom % 63) + 1;
                       auto_a(50000 / pr + ($urandom % 5) - 2, pr);
                   end
                3: auto_a($urandom % 8, $urandom % 4);
            endcase
        end

        label = "widest product";
        auto_a(16'hFFFF, 6'h3F);
        auto_a(16'hFFFF, 6'h01);
        auto_a(16'h8000, 6'h3F);

        @(negedge clk);
        label = "done";
        $display("risk_filter_tb: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("RISK_FILTER_TB: PASS");
        else $display("RISK_FILTER_TB: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #100000000;
        $display("RISK_FILTER_TB: TIMEOUT");
        $finish;
    end
endmodule
