#!/bin/bash
# ==============================================================================
# DLD Matching Engine - Master Simulation Suite
# Runs all unit testbenches and the integrated matching engine across all members.
# Requires: Icarus Verilog (iverilog, vvp).
# Run from repository root: bash run_sim.sh
# ==============================================================================

mkdir -p sim
echo "========================================================================"
echo "          RUNNING ALL HARDWARE MATCHING ENGINE SIMULATIONS"
echo "========================================================================"

# 1. Member 1: Price Discovery (Ronit Biswal)
echo -e "\n[Member 1 - Ronit] Running price discovery & priority encoder tests..."
iverilog -g2012 -o sim/hier_encoder.vvp src/priority_encoder.v tb/hier_encoder_tb.v && vvp sim/hier_encoder.vvp | tee sim/hier_encoder.log
iverilog -g2012 -o sim/bitmap_sizes.vvp src/priority_encoder.v src/price_bitmap.v tb/bitmap_sizes_tb.v && vvp sim/bitmap_sizes.vvp | tee sim/bitmap_sizes.log
iverilog -g2012 -o sim/price_discovery.vvp src/priority_encoder.v src/price_bitmap.v src/comparator_search.v tb/price_discovery_tb.v && vvp sim/price_discovery.vvp | tee sim/price_discovery.log

# 2. Member 2: Order Storage (Shalin Javaria)
echo -e "\n[Member 2 - Shalin] Running order memory, FIFO, and allocator tests..."
for tb in order_memory fifo_queue free_list order_storage; do
  iverilog -g2012 -o sim/$tb.vvp src/*.v tb/${tb}_tb.v && timeout 300 vvp sim/$tb.vvp | tee sim/$tb.log
done

# 3. Member 3: Matching Datapath (Saurabhraj)
echo -e "\n[Member 3 - Saurabhraj] Running matching datapath tests..."
iverilog -g2012 -o sim/matching_datapath.vvp src/compatibility_logic.v src/quantity_arithmetic.v tb/matching_datapath_tb.v && vvp sim/matching_datapath.vvp | tee sim/matching_datapath.log

# 4. Member 4: Control FSM & Top-Level Integration (Yash Kumar)
echo -e "\n[Member 4 - Yash] Running Master FSM & Top-Level integrated engine tests..."
iverilog -g2012 -o sim/master_fsm.vvp src/master_fsm.v tb/master_fsm_tb.v && vvp sim/master_fsm.vvp | tee sim/master_fsm.log
iverilog -g2012 -o sim/matching_engine_top.vvp src/*.v tb/matching_engine_top_tb.v && vvp sim/matching_engine_top.vvp | tee sim/matching_engine_top.log

# 5. Member 5: Pre-Trade Risk Filter (Niket)
echo -e "\n[Member 5 - Niket] Running parallel risk filter tests..."
iverilog -g2012 -o sim/risk_filter.vvp src/risk_filter.v tb/risk_filter_tb.v && vvp sim/risk_filter.vvp | tee sim/risk_filter.log

# 6. Live Presentation Visual Demo
echo -e "\n[Presentation Demo] Running Live Order Book & Trade Demo..."
iverilog -g2012 -o sim/demo.vvp src/*.v tb/matching_engine_demo_tb.v && vvp sim/demo.vvp | tee sim/demo.log

echo -e "\n========================================================================"
echo "                     SUMMARY OF TESTBENCH RESULTS"
echo "========================================================================"
grep -h -E "(PASS|FAIL)" sim/*.log | sort -u
echo "========================================================================"
