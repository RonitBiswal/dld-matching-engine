#!/bin/bash
# Member 5 simulation. Needs Icarus Verilog (iverilog, vvp). Run from the repo root.
mkdir -p sim && cd sim || exit 1
iverilog -g2012 -o risk_filter.vvp ../src/risk_filter.v ../tb/risk_filter_tb.v && vvp risk_filter.vvp | tee risk_filter.log
cd ..
python3 docs/reference_model.py | tee sim/reference_model.log
echo; grep -h -E "_TB:|REFERENCE_MODEL:" sim/*.log
