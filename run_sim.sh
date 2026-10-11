#!/bin/bash
# Member 2 simulations. Needs Icarus Verilog (iverilog, vvp). Run from the repo root.
mkdir -p sim
for tb in order_memory fifo_queue free_list order_storage; do
  echo "=== $tb ==="
  iverilog -g2012 -o sim/$tb.vvp src/*.v tb/${tb}_tb.v && timeout 300 vvp sim/$tb.vvp | tee sim/$tb.log
done
echo; grep -h "_TB:" sim/*.log
