# Hardware Limit Order Book and Parallel Matching Engine
## Digital Logic Design (DLD) Hardware Project Report

**Course:** Digital Logic Design / Hardware Design  
**Language:** Verilog HDL (IEEE 1364-2001 / IEEE 1800-2012)  
**Team Members:**
* Member 1: Ronit Biswal (2025csb1511) — Price Discovery & Priority Encoding
* Member 2: Shalin Javaria (2025csb1257) — Order Storage, Queues & Free-List Allocator
* Member 3: Saurabhraj (2025csb1256) — Matching Datapath & Quantity Arithmetic
* Member 4: Yash Kumar (2025csb1268) — Control FSM & Top-Level Integration
* Member 5: Niket (2025csb1446) — Pre-Trade Risk Filter & System Modeling

---

## 1. Project Overview

In this project, we designed and verified a synthesizable hardware limit order book (LOB) and matching engine in Verilog RTL.

Conventional software-based order matching engines implement order books using dynamic heap structures, red-black trees, or doubly linked lists. While flexible, these structures incur variable memory latency due to pointer dereferencing and cache misses. In high-frequency electronic markets, execution determinism and latency are critical. 

Our goal was to translate dynamic order book operations—price priority, time priority (FIFO), partial execution, order cancellation, and pre-trade risk validation—into an explicit, deterministic clocked digital logic circuit.

### Design Conventions
* **Priority Discipline:** Price-Time Priority (orders at better prices execute first; orders at equal prices execute in arrival sequence).
* **Execution Price:** Trades execute strictly at the limit price of the resting order.
* **Side Representation:** `1'b1` represents a BUY order (Bid); `1'b0` represents a SELL order (Ask).
* **Price Width:** Parameterized `PRICE_W = 6` bits, supporting 64 discrete price ticks (levels 0 to 63).
* **Quantity Width:** Parameterized `QTY_W = 16` bits, supporting order quantities from 1 to 65,535.
* **Order Capacity:** Parameterized `SLOTS = 16` concurrent resting order records shared across both sides of the book.

---

## 2. System Architecture and Dataflow

The system is partitioned into five specialized hardware blocks coordinated by a central Moore finite state machine (`master_fsm.v`).

```
                              [Incoming Order Stream]
                                         │
                                         ▼
                            ┌────────────────────────┐
                            │      risk_filter       │
                            └────────────┬───────────┘
                                         │ (risk_ok)
                                         ▼
                            ┌────────────────────────┐
                            │      price_bitmap      │
                            └────────────┬───────────┘
                                         │ (best_px)
                                         ▼
                    ┌────────────────────┴───────────────────┐
                    │                                        │
                    ▼                                        ▼
         ┌────────────────────┐                   ┌────────────────────┐
         │     fifo_queue     │                   │    order_memory    │
         └──────────┬─────────┘                   └──────────┬─────────┘
                    │ (opp_head)                             │ (rd_price, rd_qty)
                    └────────────────────┬───────────────────┘
                                         │
                                         ▼
                            ┌────────────────────────┐
                            │  compatibility_logic   │
                            └────────────┬───────────┘
                                         │ (can_match)
                                         ▼
                            ┌────────────────────────┐
                            │  quantity_arithmetic   │
                            └────────────┬───────────┘
                                         │
                                         ▼
                            ┌────────────────────────┐
                            │  free_list_allocator   │
                            └────────────────────────┘
```

### Operational Cycle Sequence
1. **VALIDATE (Cycle 1):** The incoming order is latched into input registers. `risk_filter` evaluates quantity bounds, price bands, and maximum notional limits purely combinationally. If any limit is violated, the FSM transitions directly to `S_REJECT`.
2. **DISCOVER (Cycle 2):** For an incoming BUY, the ASK occupancy bitmap is evaluated; for an incoming SELL, the BID bitmap is evaluated. The hierarchical priority encoder returns the best active opposite price tick (`best_px`) in 1 clock cycle.
3. **CHECK (Cycle 3):** The FIFO head pointer at price `best_px` is read combinationally from `fifo_queue`. This slot index addresses `order_memory`. `compatibility_logic` compares incoming price against resting price.
4. **EXECUTE (Cycle 4):** If prices cross (`can_match = 1`), `quantity_arithmetic` computes `trade_qty = min(in_qty, rest_qty)`. A registered trade event pulse is asserted. If the resting order is fully exhausted, its slot is freed back to `free_list_allocator`, its queue head is popped, and if the price level becomes empty, the bitmap bit is cleared. If remaining quantity exists, the engine loops back to DISCOVER to sweep subsequent levels.
5. **INSERT / DONE (Cycle 5):** If the incoming order cannot match further and retains remaining quantity, `free_list_allocator` provides an available slot. The order is written into `order_memory`, pushed to the tail of its price FIFO, and its bit in `price_bitmap` is asserted.

---

## 3. Subsystem Implementation by Member

### Member 1: Price Discovery & Occupancy Tracking (Ronit Biswal)
* **Files:** `src/price_bitmap.v`, `src/priority_encoder.v`, `src/comparator_search.v`
* **Implementation Details:**
  * Implemented a 64-bit occupancy bitmap (`price_bitmap.v`) representing active price levels.
  * To eliminate the sequential search latency of software order books, designed an 8×8 hierarchical priority encoder (`hier_priority_encoder`). It partitions 64 price levels into eight 8-bit groups evaluated in parallel by local priority encoders, followed by a global 8-bit encoder. This achieves constant-time ($O(1)$) best-price discovery in 1 clock cycle.
  * To determine the lowest set bit (best ask) without duplicating encoder logic, synthesized a bit-reversed vector `rev[k] = bm[LEVELS-1-k]`. The lowest active price is computed via `best_lo = (LEVELS - 1) - rev_idx`.
  * Designed a sequential comparator scanner (`comparator_search.v`) as a baseline architecture, taking 1 to 64 clock cycles, demonstrating a 64× speedup in the hierarchical design.

### Member 2: Order Storage, Queues & Free-Slot Management (Shalin Javaria)
* **Files:** `src/order_memory.v`, `src/fifo_queue.v`, `src/free_list_allocator.v`
* **Implementation Details:**
  * Implemented `order_memory.v`, a 16-slot multi-field register array storing `{id, side, price, qty, valid}` with combinational read and priority-arbitrated write ports. Includes a 16-way parallel CAM-style associative comparator for order ID lookup.
  * Implemented `fifo_queue.v`, a per-price linked-list structure storing arrival order across all 64 price levels. Rather than instantiating 64 separate FIFOs, each level maintains `head[level]` and `tail[level]` pointers that index into a shared 16-entry `nxt[slot]` pointer array, conserving logic resources.
  * Implemented `free_list_allocator.v`, maintaining free slot indices in a LIFO linked list with double-free protection. Provides combinational peek on `alloc_slot` so the FSM can allocate and write an order record within the same clock edge.

### Member 3: Matching Datapath & Arithmetic Logic (Saurabhraj)
* **Files:** `src/compatibility_logic.v`, `src/quantity_arithmetic.v`
* **Implementation Details:**
  * Implemented `compatibility_logic.v` to evaluate whether an incoming order crosses the resting book. A BUY crosses when $\text{Price}_{\text{in}} \ge \text{Price}_{\text{resting}}$; a SELL crosses when $\text{Price}_{\text{in}} \le \text{Price}_{\text{resting}}$. If the opposite book is empty, match generation is strictly inhibited.
  * Implemented `quantity_arithmetic.v`, evaluating trade execution quantities and residual quantities:
    $$\text{trade\_qty} = \min(\text{in\_qty}, \text{rest\_qty})$$
    $$\text{in\_rem} = \text{in\_qty} - \text{trade\_qty}, \quad \text{rest\_rem} = \text{rest\_qty} - \text{trade\_qty}$$
  * Because `trade_qty` is bounded by the minimum of both inputs, arithmetic underflow is mathematically prevented. Flags `in_done` and `rest_done` indicate order completion.

### Member 4: Control FSM & Top-Level Integration (Yash Kumar)
* **Files:** `src/master_fsm.v`, `src/matching_engine_top.v`
* **Implementation Details:**
  * Implemented `master_fsm.v`, an 8-state Moore machine with state register encoding `S_IDLE` (0) through `S_REJECT` (7). Decoded Moore outputs eliminate combinational hazards on control lines.
  * Integrated all submodule instances into `matching_engine_top.v`, routing datapath buses between the risk filter, bitmaps, memories, FIFOs, and arithmetic units.
  * Built the registered trade output interface (`trade_valid`, `trade_price`, `trade_qty`, `trade_buy_id`, `trade_sell_id`) and order completion signaling (`done_pulse`, `reject_valid`, `reject_code`).

### Member 5: Parallel Risk Filter & System Modeling (Niket)
* **Files:** `src/risk_filter.v`, `docs/reference_model.py`
* **Implementation Details:**
  * Implemented `risk_filter.v`, evaluating incoming order parameters in parallel with zero clock delay:
    1. Quantity boundary check: $\text{MIN\_QTY} \le \text{qty} \le \text{MAX\_QTY}$
    2. Price band check: $\text{PRICE\_MIN} \le \text{price} \le \text{PRICE\_MAX}$
    3. Notional check: $\text{price} \times \text{qty} \le \text{MAX\_NOTIONAL}$
  * Sized the internal multiplier to 22 bits (`QTY_W + PRICE_W`), preventing arithmetic overflow and false acceptance of excessively large orders.
  * Developed `docs/reference_model.py`, an independent software golden model implementing the same price-time priority rules for differential verification.

---

## 4. Verification and Results

We verified our design using individual unit testbenches and an end-to-end integrated system testbench. All testbenches are self-checking.

### Testbench Summary

| Testbench | Target Module | Scope | Result |
|---|---|---|---|
| `tb/hier_encoder_tb.v` | `priority_encoder` | Exhaustive 8-bit & 4-bit; 16/32/64/128-level staircase and random patterns | PASS |
| `tb/bitmap_sizes_tb.v` | `price_bitmap` | Parameterized widths 4 to 7; same-cycle set/clear priority verification | PASS |
| `tb/price_discovery_tb.v` | `price_bitmap` vs `comparator_search` | 64-level comparison between 1-cycle hierarchical encoder and sequential scanner | PASS |
| `tb/order_memory_tb.v` | `order_memory` | 3,000 random operations; 16-way parallel CAM ID lookup | PASS |
| `tb/fifo_queue_tb.v` | `fifo_queue` | 6,000 cycles; linked list queue isolation, same-cycle push/pop | PASS |
| `tb/free_list_tb.v` | `free_list_allocator` | 5,000 random ops; slot reuse, double-free guard | PASS |
| `tb/order_storage_tb.v` | Memory + Queue + Free List | Integrated storage subsystem; 4,000 random operations | PASS |
| `tb/matching_datapath_tb.v` | `compatibility` & `quantity` | 18,920 checks; exhaustive price-crossing & min arithmetic | PASS |
| `tb/master_fsm_tb.v` | `master_fsm` | 20,049 checks; all state transitions & mid-order asynchronous reset | PASS |
| `tb/risk_filter_tb.v` | `risk_filter` | 39,505 checks; 22-bit multiplier overflow trap verification | PASS |
| `tb/matching_engine_top_tb.v` | `matching_engine_top` | Full integration: 3,406 orders, 1,669 trades checked against golden model | PASS |
| `tb/matching_engine_demo_tb.v` | `matching_engine_top` | Multi-level sweeps, risk rejection, and telemetry verification | PASS |

### Hardware Latency Analysis

From our simulation measurements, the clock cycle latency from order presentation to completion is:
* **Pre-Trade Risk Rejection:** 2 clock cycles (`IDLE` $\rightarrow$ `VALIDATE` $\rightarrow$ `REJECT`).
* **Resting Order Insertion (No Match):** 5 clock cycles (`IDLE` $\rightarrow$ `VALIDATE` $\rightarrow$ `DISCOVER` $\rightarrow$ `CHECK` $\rightarrow$ `INSERT` $\rightarrow$ `DONE`).
* **Single Trade Execution:** 5 clock cycles.
* **Multi-Level Matching:** For an order matching across $n$ resting orders, total latency is $3n + 2$ clock cycles.

---

## 5. Instructions for Running Simulations

### Executing All Verilog Hardware Testbenches
From the repository root using Icarus Verilog and Bash:
```bash
bash run_sim.sh
```

### Running the Top-Level Integrated Testbench
```bash
mkdir -p sim
iverilog -g2012 -o sim/matching_engine_top.vvp src/*.v tb/matching_engine_top_tb.v
vvp sim/matching_engine_top.vvp
```

### Running the Python Golden Reference Model
```bash
python docs/reference_model.py
```

### Opening the Interactive Demonstration Console
Open `index.html` in any web browser to inspect order placement, multi-level matching, and queue updates.
