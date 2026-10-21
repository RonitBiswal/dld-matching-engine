# Low-Latency Hardware Limit Order Book & Parallel Matching Engine
### Synthesizable Verilog RTL Architecture for Digital Logic Design (DLD)

[![Verilog](https://img.shields.io/badge/Language-Verilog--2001%2F2012-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Simulation](https://img.shields.io/badge/Simulator-Icarus%20Verilog%20%2F%20Vivado-green.svg)](http://iverilog.icarus.com/)
[![Tests](https://img.shields.io/badge/Testbenches-12%20PASS-brightgreen.svg)]()
[![Hardware](https://img.shields.io/badge/FPGA-Synthesizable%20RTL-orange.svg)]()

---

## 1. Project Overview

This project implements a high-performance, deterministic hardware **Limit Order Book (LOB) and Matching Engine** in synthesizable Verilog RTL.

In traditional financial markets, order matching software relies on linked lists and binary trees that introduce unpredictable software latency. This hardware engine implements matching directly in digital logic using **parallel price-occupancy bitmaps**, **hierarchical priority encoders (O(1) price discovery)**, **per-price linked FIFOs**, **CAM-style associative order memory**, and a **cycle-accurate Moore FSM**.

### Key Rules & Conventions
* **Priority Rule:** **Price-Time Priority** (best price first; oldest order at identical price).
* **Execution Price:** Trades execute strictly at the **resting order's price**.
* **Sides:** `1 = BUY` (Bid), `0 = SELL` (Ask).
* **Quantities:** Integer units (`QTY_W = 16`, 1 to 65,535).
* **Prices:** Integer price ticks (`PRICE_W = 6`, levels 1 to 63).
* **Capacity:** `SLOTS = 16` concurrent resting orders shared between both books.
* **Pre-Trade Risk Checks:** Purely combinational parallel check for quantity bounds, price bands, and max notional before touching memory.

---

## 2. Team Members and Work Division

| # | Member | Roll No. | Subsystem Ownership | Key Source Files | Testbenches |
|---|---|---|---|---|---|
| **1** | **Ronit Biswal** *(Lead)* | `2025csb1511` | **Price Discovery & Occupancy** | `price_bitmap.v`<br>`priority_encoder.v`<br>`comparator_search.v` | `hier_encoder_tb.v`<br>`bitmap_sizes_tb.v`<br>`price_discovery_tb.v` |
| **2** | **Shalin Javaria** | `2025csb1257` | **Order Storage & Memory** | `order_memory.v`<br>`fifo_queue.v`<br>`free_list_allocator.v` | `order_memory_tb.v`<br>`fifo_queue_tb.v`<br>`free_list_tb.v`<br>`order_storage_tb.v` |
| **3** | **Saurabhraj** | `2025csb1256` | **Matching Datapath & Arithmetic** | `compatibility_logic.v`<br>`quantity_arithmetic.v` | `matching_datapath_tb.v`<br>`matching_datapath_demo_tb.v` |
| **4** | **Yash Kumar** | `2025csb1268` | **Control FSM & Top Integration** | `master_fsm.v`<br>`matching_engine_top.v` | `master_fsm_tb.v`<br>`matching_engine_top_tb.v`<br>`matching_engine_demo_tb.v` |
| **5** | **Niket** | `2025csb1446` | **Risk Filter & Software Modeling** | `risk_filter.v`<br>`reference_model.py` | `risk_filter_tb.v`<br>`demo_market.py` |

---

## 3. High-Level Hardware Architecture

```
                    +-------------------------------------------------+
                    |               INCOMING ORDER STREAM             |
                    | [in_valid, in_id, in_side, in_price, in_qty]    |
                    +------------------------+------------------------+
                                             |
                                    [1] VALIDATE (Cycle 1)
                                             v
                             +-------------------------------+
                             |    risk_filter.v (Niket)     |
                             |  - Qty: [1..1000]             |
                             |  - Price: [1..63]             |
                             |  - Notional: Price*Qty<=50000 |
                             +---------------+---------------+
                                             |  (risk_ok == 1)
                                    [2] DISCOVER (Cycle 2)
                                             v
                      +----------------------------------------------+
                      |          price_bitmap.v (Ronit)              |
                      |  - 64-bit occupancy bitmap                   |
                      |  - hier_priority_encoder: 1-cycle best price  |
                      |    (Highest Bid / Lowest Ask)                |
                      +----------------------+-----------------------+
                                             | (best_px found)
                                      [3] CHECK (Cycle 3)
                                             v
          +----------------------------------+----------------------------------+
          |                                                                     |
          v                                                                     v
+-------------------------+                                           +-------------------------+
|   fifo_queue.v (Shalin) |                                           |  order_memory.v (Shalin)|
| - Finds oldest order    |                                           | - Reads resting order   |
|   at price level best_px| ----> [slot pointer: opp_head] ---------> |   quantity, id, price   |
+-------------------------+                                           +------------+------------+
                                                                                   |
                                                                                   v
                                                              +-------------------------------------+
                                                              |   compatibility_logic.v (Saurabh)   |
                                                              |   - BUY:  in_price >= rest_price    |
                                                              |   - SELL: in_price <= rest_price    |
                                                              +--------------------+----------------+
                                                                                   |
                                                                    [4] EXECUTE or INSERT
                                                                                   |
                       +-----------------------------------------------------------+
                       |                                                           |
          (Match crosses: can_match = 1)                             (No match crosses: can_match = 0)
                       v                                                           v
  +-------------------------------------------+               +-------------------------------------------+
  |      quantity_arithmetic.v (Saurabh)      |               |     free_list_allocator.v (Shalin)        |
  |  - trade_qty = min(in_qty, rest_qty)      |               |  - Allocates next free slot               |
  |  - in_rem    = in_qty   - trade_qty       |               |  - Writes remainder to order_memory       |
  |  - rest_rem  = rest_qty - trade_qty       |               |  - Pushes slot to FIFO & sets Bitmap bit  |
  +--------------------+----------------------+               +---------------------+---------------------+
                       |                                                           |
                       v                                                           v
          [5] EMIT TRADE PULSE (Reg)                                  [6] ORDER RESTS IN BOOK
        (trade_valid, price, qty, ids)                                  (done_pulse emitted)
```

---

## 4. Master Control FSM (8-State Moore Machine)

The brain of the matching engine is [`src/master_fsm.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/src/master_fsm.v), a glitch-free 3-bit Moore state machine:

| State | Code | Function & Datapath Action | Next State Condition |
|---|---|---|---|
| **`S_IDLE`** | `3'd0` | Waits for `in_valid`. Assert `in_ready = 1`. Latches order on clock edge. | `in_valid ? S_VALIDATE : S_IDLE` |
| **`S_VALIDATE`** | `3'd1` | Risk filter checks quantity, price band, and notional limits combinationally. | `risk_ok ? S_DISCOVER : S_REJECT` |
| **`S_DISCOVER`** | `3'd2` | Queries opposite book price bitmap; hierarchical encoder discovers `best_px`. | Unconditional -> `S_CHECK` |
| **`S_CHECK`** | `3'd3` | Reads FIFO head and memory at `best_px`. Compatibility logic tests price cross. | `can_match ? S_EXECUTE : S_INSERT` |
| **`S_EXECUTE`** | `3'd4` | Computes trade qty, updates memory, pops FIFO if resting filled. Emits trade pulse. | `in_done ? S_DONE : S_DISCOVER` *(loops for multi-level)* |
| **`S_INSERT`** | `3'd5` | Unmatched remainder claims free slot, writes memory, pushes to price FIFO. | `room_ok ? S_DONE : S_REJECT` *(book full)* |
| **`S_DONE`** | `3'd6` | Emits 1-cycle `done_pulse` signaling successful processing. | Unconditional -> `S_IDLE` |
| **`S_REJECT`** | `3'd7` | Emits 1-cycle `reject_valid` pulse and sets `reject_code[3:0]`. | Unconditional -> `S_IDLE` |

---

## 5. Verification & Test Results

All testbenches are self-checking and print deterministic `PASS` or `FAIL` status:

| Testbench File | Target Module | Scope & Checks | Status |
|---|---|---|---|
| [`tb/price_discovery_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/price_discovery_tb.v) | `price_bitmap` & `comparator_search` | Compares 1-cycle hierarchical encoder against 1-to-64 cycle sequential scan | **PASS** |
| [`tb/hier_encoder_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/hier_encoder_tb.v) | `hier_priority_encoder` | Exhaustive 8-bit & 4-bit; 16/32/64/128-level staircase & random vectors | **PASS** |
| [`tb/bitmap_sizes_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/bitmap_sizes_tb.v) | `price_bitmap` | Parameterized width 4..7; same-cycle set/clear priority | **PASS** |
| [`tb/order_memory_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/order_memory_tb.v) | `order_memory` | 3,000 random operations; 16-way parallel CAM ID lookup | **PASS** |
| [`tb/fifo_queue_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/fifo_queue_tb.v) | `fifo_queue` | 6,000 cycles; linked list queue isolation, same-cycle push/pop | **PASS** |
| [`tb/free_list_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/free_list_tb.v) | `free_list_allocator` | 5,000 random ops; slot reuse, double-free protection | **PASS** |
| [`tb/order_storage_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/order_storage_tb.v) | Memory + Queue + Free List | Integrated storage subsystem; 4,000 random operations | **PASS** |
| [`tb/matching_datapath_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/matching_datapath_tb.v) | `compatibility` & `quantity` | 18,920 checks; exhaustive crossing & min arithmetic | **PASS** |
| [`tb/master_fsm_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/master_fsm_tb.v) | `master_fsm` | 20,049 checks; all state transitions & mid-order async reset | **PASS** |
| [`tb/risk_filter_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/risk_filter_tb.v) | `risk_filter` | 39,505 checks; 22-bit multiplier overflow trap verification | **PASS** |
| [`tb/matching_engine_top_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/matching_engine_top_tb.v) | `matching_engine_top` | **Full Integration:** 3,406 orders, 1,669 trades vs golden model | **PASS** |
| [`tb/matching_engine_demo_tb.v`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/tb/matching_engine_demo_tb.v) | `matching_engine_top` | Presentation Demo: multi-level sweeps, risk rejects, clean receipt logs | **PASS** |

---

## 6. How to Run the Simulations

### Option A: Run the Live Presentation Demo (Python)
If you don't have Icarus Verilog installed, you can run the live interactive visual demo directly:
```bash
python docs/demo_market.py
```
Or run the reference model self-tests:
```bash
python docs/reference_model.py
```

### Option B: Run Verilog RTL Simulations (Icarus Verilog + GTKWave)
From Git Bash or terminal:
```bash
# Run all Member 2 tests:
bash run_sim.sh

# Run Member 4 FSM & Integrated Top-Level tests:
bash run_sim_member4.sh

# Run the Live Visual Verilog Demo:
mkdir -p sim
iverilog -g2012 -o sim/demo.vvp src/*.v tb/matching_engine_demo_tb.v
vvp sim/demo.vvp
```

---

## 7. Measured Hardware Metrics

* **Matching Latency:**
  * Risk Rejection: **2 clock cycles** (`IDLE -> VALIDATE -> REJECT`).
  * Resting Order Insertion (no cross): **5 clock cycles** (`IDLE -> VALIDATE -> DISCOVER -> CHECK -> INSERT -> DONE`).
  * 1 Trade Execution: **5 clock cycles**.
  * Multi-Trade Execution Formula: **$3n + 2$ clock cycles** (where $n$ is number of matched resting orders).
* **Price Discovery Comparison (64 Levels):**
  * Sequential Scan Baseline (`comparator_search.v`): **1 to 64 clock cycles**.
  * Hierarchical Priority Encoder (`price_bitmap.v`): **1 clock cycle (constant time O(1))**.
