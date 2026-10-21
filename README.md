# Low-Latency Hardware Limit Order Book & Parallel Matching Engine

Synthesizable Verilog RTL Architecture for Digital Logic Design (DLD).

* [Interactive Order Book Simulator (index.html)](./index.html)
* [Project Architecture & Verification Report (docs/Project_Report.md)](./docs/Project_Report.md)

---

## 1. Project Overview

In this project, we implemented a synthesizable hardware **Limit Order Book (LOB) and Parallel Matching Engine** in Verilog RTL.

Conventional electronic exchanges rely on software order books that introduce non-deterministic latency spikes due to memory allocation, cache misses, and pointer indirection. Our design translates order matching into deterministic clocked digital logic. The engine processes incoming limit orders under **Price-Time Priority**, executes partial and multi-level fills, and maintains active book occupancy in hardware.

### System Specifications
* **Priority Rule:** Price-Time Priority (orders at better prices execute first; equal prices match in arrival order).
* **Execution Price:** Trades execute strictly at the limit price of the resting order.
* **Side Representation:** `1'b1` = BUY (Bid), `1'b0` = SELL (Ask).
* **Price Width:** Parameterized `PRICE_W = 6` (64 discrete price ticks, levels 0 to 63).
* **Quantity Width:** Parameterized `QTY_W = 16` (unsigned integers, 1 to 65,535).
* **Capacity:** Parameterized `SLOTS = 16` concurrent resting orders shared across both books.
* **Pre-Trade Risk Checks:** Purely combinational parallel validation of quantity ranges, price bands, and notional limits before touching memory.

---

## 2. Team Members and Work Division

| Member | Roll Number | Subsystem Ownership | Key Source Files |
|---|---|---|---|
| **Ronit Biswal** | `2025csb1511` | Price Discovery & Occupancy Tracking | `price_bitmap.v`, `priority_encoder.v`, `comparator_search.v` |
| **Shalin Javaria** | `2025csb1257` | Order Storage, Queues & Free-List Allocator | `order_memory.v`, `fifo_queue.v`, `free_list_allocator.v` |
| **Saurabhraj** | `2025csb1256` | Matching Datapath & Quantity Arithmetic | `compatibility_logic.v`, `quantity_arithmetic.v` |
| **Yash Kumar** | `2025csb1268` | Control FSM & Top-Level Integration | `master_fsm.v`, `matching_engine_top.v` |
| **Niket** | `2025csb1446` | Pre-Trade Risk Filter & System Modeling | `risk_filter.v`, `reference_model.py` |

---

## 3. Hardware Architecture and Dataflow

The top-level module (`src/matching_engine_top.v`) integrates the five team subsystems into an explicit datapath coordinated by an 8-state Moore finite state machine (`src/master_fsm.v`):

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
| - Reads oldest slot at  |                                           | - Reads resting order   |
|   price level best_px   | ----> [slot pointer: opp_head] ---------> |   quantity, id, price   |
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
            EMIT TRADE OUTPUT PULSE                                     ORDER RESTS IN BOOK
        (trade_valid, price, qty, ids)                                  (done_pulse emitted)
```

---

## 4. Master Control FSM States

The central Moore FSM (`master_fsm.v`) uses an explicit 3-bit state register:

| State | Encoding | Description | Transition |
|---|---|---|---|
| `S_IDLE` | `3'd0` | Asserts `in_ready = 1`. Awaits `in_valid` to latch incoming order. | `in_valid ? S_VALIDATE : S_IDLE` |
| `S_VALIDATE` | `3'd1` | Risk filter checks limits combinationally. | `risk_ok ? S_DISCOVER : S_REJECT` |
| `S_DISCOVER` | `3'd2` | Priority encoder discovers best opposite price (`best_px`). | Unconditional -> `S_CHECK` |
| `S_CHECK` | `3'd3` | Evaluates price crossing against resting order at level `best_px`. | `can_match ? S_EXECUTE : S_INSERT` |
| `S_EXECUTE` | `3'd4` | Executes one trade, updates memory, pops queue if filled. | `in_done ? S_DONE : S_DISCOVER` |
| `S_INSERT` | `3'd5` | Allocates slot, writes order record, enqueues to price FIFO. | `room_ok ? S_DONE : S_REJECT` |
| `S_DONE` | `3'd6` | Emits 1-cycle `done_pulse` signaling successful processing. | Unconditional -> `S_IDLE` |
| `S_REJECT` | `3'd7` | Emits 1-cycle `reject_valid` pulse and sets `reject_code[3:0]`. | Unconditional -> `S_IDLE` |

---

## 5. Verification and Results

All testbenches are self-checking and print deterministic PASS or FAIL status:

| Testbench File | Target Module | Scope | Status |
|---|---|---|---|
| `tb/hier_encoder_tb.v` | `hier_priority_encoder` | Exhaustive 8-bit & 4-bit; 16/32/64/128-level staircase and random vectors | PASS |
| `tb/bitmap_sizes_tb.v` | `price_bitmap` | Parameterized width 4..7; same-cycle set/clear priority | PASS |
| `tb/price_discovery_tb.v` | `price_bitmap` & `comparator_search` | Compares 1-cycle hierarchical encoder against 1-to-64 cycle sequential scan | PASS |
| `tb/order_memory_tb.v` | `order_memory` | 3,000 random operations; 16-way parallel CAM ID lookup | PASS |
| `tb/fifo_queue_tb.v` | `fifo_queue` | 6,000 cycles; linked list queue isolation, same-cycle push/pop | PASS |
| `tb/free_list_tb.v` | `free_list_allocator` | 5,000 random ops; slot reuse, double-free protection | PASS |
| `tb/order_storage_tb.v` | Storage subsystem | Integrated storage; 4,000 random operations | PASS |
| `tb/matching_datapath_tb.v` | `compatibility` & `quantity` | 18,920 checks; exhaustive crossing & min arithmetic | PASS |
| `tb/master_fsm_tb.v` | `master_fsm` | 20,049 checks; all state transitions & mid-order async reset | PASS |
| `tb/risk_filter_tb.v` | `risk_filter` | 39,505 checks; 22-bit multiplier overflow trap verification | PASS |
| `tb/matching_engine_top_tb.v` | `matching_engine_top` | Full integration: 3,406 orders, 1,669 trades vs golden model | PASS |
| `tb/matching_engine_demo_tb.v` | `matching_engine_top` | Multi-level sweeps, risk rejection, and market depth telemetry | PASS |

### Hardware Latency
* **Risk Rejection:** 2 clock cycles (`IDLE` -> `VALIDATE` -> `REJECT`).
* **Resting Order Insertion (No Cross):** 5 clock cycles (`IDLE` -> `VALIDATE` -> `DISCOVER` -> `CHECK` -> `INSERT` -> `DONE`).
* **Single Trade Execution:** 5 clock cycles.
* **Multi-Level Matching:** For an incoming order matching across $n$ resting orders, latency is $3n + 2$ clock cycles.

---

## 6. How to Run

### Running Verilog Simulations (Icarus Verilog)
```bash
# Run all testbenches across all members:
bash run_sim.sh

# Run the top-level integrated testbench individually:
mkdir -p sim
iverilog -g2012 -o sim/matching_engine_top.vvp src/*.v tb/matching_engine_top_tb.v
vvp sim/matching_engine_top.vvp

# Run the live hardware simulation demo:
iverilog -g2012 -o sim/demo.vvp src/*.v tb/matching_engine_demo_tb.v
vvp sim/demo.vvp
```

### Running the Python Golden Model
```bash
python docs/reference_model.py
```

### Viewing the Interactive Order Book Console
Open `index.html` in any modern web browser to interactively test limit order submissions, FIFO arrival priority, and multi-level matching execution.
