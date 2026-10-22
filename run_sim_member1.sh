#!/usr/bin/env bash
# Member 1 (Ronit Biswal): Price Discovery, Hierarchical Priority Encoder, Bitmaps & HI/LO Search Suite
set -e

export PATH="$PATH:/c/iverilog/bin:/c/iverilog/gtkwave/bin"
mkdir -p sim

echo "========================================================================"
echo "          MEMBER 1 VERIFICATION SUITE: PRICE DISCOVERY (RONIT)"
echo "========================================================================"

echo ""
echo "[1/3] Running Hierarchical Priority Encoder Test (HI & LO sweeps)..."
iverilog -g2012 -o sim/he.vvp src/priority_encoder.v tb/hier_encoder_tb.v
vvp sim/he.vvp

echo ""
echo "[2/3] Running Bitmap Parameterization Test (16, 32, 64, 128 levels)..."
iverilog -g2012 -o sim/bs.vvp src/priority_encoder.v src/price_bitmap.v tb/bitmap_sizes_tb.v
vvp sim/bs.vvp

echo ""
echo "[3/3] Running Head-to-Head Comparison: 1-Cycle Hierarchical vs 64-Cycle Sequential Scan..."
iverilog -g2012 -o sim/pd.vvp src/priority_encoder.v src/price_bitmap.v src/comparator_search.v tb/price_discovery_tb.v
vvp sim/pd.vvp

echo ""
echo "========================================================================"
echo "          MEMBER 1 TEST SUITE: ALL TESTS PASSED SUCCESSFULLY!"
echo "========================================================================"
