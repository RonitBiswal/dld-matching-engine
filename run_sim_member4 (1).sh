#!/bin/bash
# Member 4 (Yash) simulations. Needs Icarus Verilog (iverilog, vvp).
# Run from the repository root:  bash run_sim_member4.sh
mkdir -p sim
echo "=== master_fsm_tb (FSM alone) ==="
iverilog -g2012 -o sim/master_fsm.vvp src/master_fsm.v tb/master_fsm_tb.v && timeout 300 vvp sim/master_fsm.vvp | tee sim/master_fsm.log
echo
echo "=== matching_engine_top_tb (needs ALL team modules in src/) ==="
iverilog -g2012 -o sim/matching_engine_top.vvp src/*.v tb/matching_engine_top_tb.v && timeout 600 vvp sim/matching_engine_top.vvp | tee sim/matching_engine_top.log
echo
grep -h "_TB:" sim/master_fsm.log sim/matching_engine_top.log
