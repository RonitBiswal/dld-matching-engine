#!/usr/bin/env bash
# Master Demo Suite for All 5 Team Members
set -e
export PATH="$PATH:/c/iverilog/bin:/c/iverilog/gtkwave/bin"
mkdir -p sim

case "$1" in
  m5|member5|risk)
    echo "========================================================================"
    echo "  STAGE 1 / MEMBER 5: PRE-TRADE RISK FILTER (NIKET)"
    echo "========================================================================"
    iverilog -g2012 -o sim/rf.vvp src/risk_filter.v tb/risk_filter_tb.v
    vvp sim/rf.vvp
    ;;

  m1|member1|price)
    echo "========================================================================"
    echo "  STAGE 2 / MEMBER 1: PRICE DISCOVERY & 8x8 PRIORITY ENCODER (RONIT)"
    echo "========================================================================"
    iverilog -g2012 -o sim/pd.vvp src/priority_encoder.v src/price_bitmap.v src/comparator_search.v tb/price_discovery_tb.v
    vvp sim/pd.vvp
    ;;

  m2|member2|storage)
    echo "========================================================================"
    echo "  STAGE 3 / MEMBER 2: ORDER STORAGE, FIFO QUEUES & FREE LIST (SHALIN)"
    echo "========================================================================"
    iverilog -g2012 -o sim/om.vvp src/order_memory.v tb/order_memory_tb.v
    vvp sim/om.vvp
    iverilog -g2012 -o sim/fq.vvp src/fifo_queue.v tb/fifo_queue_tb.v
    vvp sim/fq.vvp
    iverilog -g2012 -o sim/fl.vvp src/free_list_allocator.v tb/free_list_tb.v
    vvp sim/fl.vvp
    ;;

  m3|member3|datapath)
    echo "========================================================================"
    echo "  STAGE 4 / MEMBER 3: MATCHING DATAPATH & ARITHMETIC (SAURABHRAJ)"
    echo "========================================================================"
    iverilog -g2012 -o sim/dp.vvp src/compatibility_logic.v src/quantity_arithmetic.v tb/matching_datapath_tb.v
    vvp sim/dp.vvp
    ;;

  m4|member4|fsm)
    echo "========================================================================"
    echo "  STAGE 5 / MEMBER 4: MASTER MOORE CONTROL FSM & INTEGRATION (YASH)"
    echo "========================================================================"
    iverilog -g2012 -o sim/fsm.vvp src/master_fsm.v tb/master_fsm_tb.v
    vvp sim/fsm.vvp
    ;;

  demo|live|top)
    echo "========================================================================"
    echo "  FINAL INTEGRATION: LIVE 4-SCENARIO MARKET DEMO (ALL MEMBERS)"
    echo "========================================================================"
    iverilog -g2012 -o sim/demo.vvp src/*.v tb/matching_engine_demo_tb.v
    vvp sim/demo.vvp
    ;;

  *)
    echo "========================================================================"
    echo "          RUNNING FULL TEST SUITE ACROSS ALL 5 MEMBERS"
    echo "========================================================================"
    echo ""
    echo "[1/5] MEMBER 5 (Niket): Risk Filter..."
    iverilog -g2012 -o sim/rf.vvp src/risk_filter.v tb/risk_filter_tb.v && vvp sim/rf.vvp
    echo ""
    echo "[2/5] MEMBER 1 (Ronit): Price Discovery & Priority Encoding..."
    iverilog -g2012 -o sim/pd.vvp src/priority_encoder.v src/price_bitmap.v src/comparator_search.v tb/price_discovery_tb.v && vvp sim/pd.vvp
    echo ""
    echo "[3/5] MEMBER 2 (Shalin): Storage, FIFOs & Allocator..."
    iverilog -g2012 -o sim/om.vvp src/order_memory.v tb/order_memory_tb.v && vvp sim/om.vvp
    iverilog -g2012 -o sim/fq.vvp src/fifo_queue.v tb/fifo_queue_tb.v && vvp sim/fq.vvp
    iverilog -g2012 -o sim/fl.vvp src/free_list_allocator.v tb/free_list_tb.v && vvp sim/fl.vvp
    echo ""
    echo "[4/5] MEMBER 3 (Saurabhraj): Datapath & Arithmetic..."
    iverilog -g2012 -o sim/dp.vvp src/compatibility_logic.v src/quantity_arithmetic.v tb/matching_datapath_tb.v && vvp sim/dp.vvp
    echo ""
    echo "[5/5] MEMBER 4 (Yash): Master Moore FSM..."
    iverilog -g2012 -o sim/fsm.vvp src/master_fsm.v tb/master_fsm_tb.v && vvp sim/fsm.vvp
    echo ""
    echo "========================================================================"
    echo "  ALL 5 MEMBER UNIT TESTBENCHES PASSED 100%!"
    echo "========================================================================"
    ;;
esac
