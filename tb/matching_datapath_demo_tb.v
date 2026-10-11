// Short, screenshot-friendly waveform demo (Stage 1 worked example). Owner: Saurabhraj
// Run: iverilog -g2012 -o sim/demo.vvp src/compatibility_logic.v src/quantity_arithmetic.v tb/matching_datapath_demo_tb.v && vvp sim/demo.vvp
`timescale 1ns/1ps
module matching_datapath_demo_tb;
    reg        in_side;  reg [5:0] in_price, rest_price;  reg rest_valid;
    wire       can_match;
    reg [15:0] in_qty, rest_qty;
    wire [15:0] trade_qty, in_rem, rest_rem;  wire in_done, rest_done;

    compatibility_logic #(.PRICE_W(6))  u_cmp (.*);
    quantity_arithmetic #(.QTY_W(16))   u_qty (.*);

    task show; begin
        $display("t=%4t | %s in@%0d vs rest@%0d valid=%b match=%b | in=%0d rest=%0d -> trade=%0d in_rem=%0d rest_rem=%0d in_done=%b rest_done=%b",
          $time, in_side?"BUY ":"SELL", in_price, rest_price, rest_valid, can_match,
          in_qty, rest_qty, trade_qty, in_rem, rest_rem, in_done, rest_done);
    end endtask

    initial begin
        $dumpfile("sim/matching_datapath_demo_tb.vcd");
        $dumpvars(0, matching_datapath_demo_tb);
        in_side=0; in_price=49; rest_valid=1;
        // ---- SELL 180@49 sweeping bids 100@50, 50@50, 200@49 ----
        rest_price=50; in_qty=180; rest_qty=100; #10 show; #10;   // trade 100, in_rem 80, rest_done
        rest_price=50; in_qty=80;  rest_qty=50;  #10 show; #10;   // trade 50,  in_rem 30, rest_done
        rest_price=49; in_qty=30;  rest_qty=200; #10 show; #10;   // trade 30,  in_rem 0,  in_done
        // ---- next best bid is 48: SELL@49 no longer crosses ----
        rest_price=48; in_qty=1;   rest_qty=1;   #10 show; #10;   // can_match = 0
        // ---- empty opposite book ----
        rest_valid=0;  rest_price=63;            #10 show; #10;   // can_match = 0
        // ---- BUY 60@50 vs ask 50 (equal) then exact fill ----
        in_side=1; in_price=50; rest_valid=1; rest_price=50; in_qty=60; rest_qty=60; #10 show; #10; // both done
        $finish;
    end
endmodule
