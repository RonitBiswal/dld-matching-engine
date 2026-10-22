# Stage 3 Progress in Development: Hardware Limit Order Book and Matching Engine
**Course:** Digital Logic Design (DLD) Hardware Project  
**Instructor:** Mohd Arif  
**Submission:** Project Stage 3 – Progress in Development  
**Target Architecture:** Verilog HDL (IEEE 1364-2001 / IEEE 1800-2012 Synthesizable RTL)  

### Team Members & Contributions
* **Member 1 (Ronit Biswal - 2025csb1511):** Price Discovery, 64-bit Occupancy Bitmaps, Hierarchical Priority Encoder
* **Member 2 (Shalin Javaria - 2025csb1257):** Order Storage Memory, Per-Price FIFO Queues, Free-List Slot Allocator
* **Member 3 (Saurabhraj - 2025csb1256):** Matching Datapath, Price Crossing Compatibility, Quantity Arithmetic
* **Member 4 (Yash Kumar - 2025csb1268):** Master Control Moore FSM, Top-Level RTL Integration, Event Signaling
* **Member 5 (Niket - 2025csb1446):** Combinational Pre-Trade Risk Filter, Python Golden Model, Test Automation

---

## 1. Final / Near-Final Design

### System Overview
In this project, our team built an ultra-low-latency electronic exchange matching engine directly in digital hardware using Verilog HDL. In standard financial software systems, order books are maintained in CPU memory using trees or heaps. When market volume surges, memory cache misses and pointer dereferencing introduce variable latencies and unpredictable execution delays.

Our hardware design replaces software pointers with dedicated on-chip registers, parallel bitwise priority encoders, and a multi-stage execution datapath. The engine enforces the standard financial market matching rule: **Price-Time Priority**.
1. **Price Priority:** Better prices always execute before worse prices (highest bid price and lowest ask price).
2. **Time Priority:** If two orders share the identical price tick, the order that arrived first executes first (FIFO).

![System Architecture](images/system_architecture.svg)

### Hardware Subsystem Breakdown
The design is divided into five dedicated functional units connected through a central top-level controller:

1. **Pre-Trade Risk Filter (`risk_filter.v`):** A zero-delay combinational security barrier that checks order sanity before any order modifies the book.
2. **Price Discovery Engine (`price_bitmap.v`, `priority_encoder.v`):** Dual 64-bit occupancy bit-vectors tracking occupied price levels, paired with an 8x8 parallel hierarchical priority encoder for 1-cycle best price detection.
3. **Order Storage and Queues (`order_memory.v`, `fifo_queue.v`, `free_list_allocator.v`):** A 16-slot multi-field register array, price-indexed linked-list head/tail pointers, and a LIFO slot reclamation stack.
4. **Matching Datapath (`compatibility_logic.v`, `quantity_arithmetic.v`):** Purely combinational arithmetic evaluating price crossing conditions and executing trade volumes:
   $$\text{trade\_qty} = \min(\text{incoming\_qty}, \text{resting\_qty})$$
5. **Master Control Moore FSM (`master_fsm.v`):** An 8-state clocked sequencer that coordinates memory reads, arithmetic sweeps, slot reallocation, and registered trade event outputs.

---

## 2. Complete Implementation Details

Our RTL codebase contains 11 synthesizable Verilog modules in `src/` and 13 verification testbenches in `tb/`. Below is a clear explanation of how each module works in real hardware.

### 2.1 Pre-Trade Risk Filter (`risk_filter.v`)
Before any order enters the active engine, it passes through combinational comparators and an internal multiplier:
* **Quantity Limits:** Verifies $\text{MIN\_QTY} \le \text{qty} \le \text{MAX\_QTY}$. (Rejects quantity 0 or oversized volume).
* **Price Limits:** Checks that price tick falls within valid bands ($1 \le \text{price} \le 62$). Price tick 0 and 63 are reserved as sentinel markers.
* **Notional Cap:** Computes $\text{price} \times \text{qty}$ and ensures it does not exceed $\text{MAX\_NOTIONAL}$. To prevent silent arithmetic overflow that could bypass the limit, we sized the internal product to 22 bits (`PRICE_W + QTY_W`).
* **Latency:** Combinational (0 clock cycles).

```verilog
// Risk Filter: Combinational validation
assign qty_err   = (qty < MIN_QTY) || (qty > MAX_QTY);
assign price_err = (price < PRICE_MIN) || (price > PRICE_MAX);
assign notional_prod = price * qty;
assign notional_err = (notional_prod > MAX_NOTIONAL);
assign risk_ok   = !(qty_err | price_err | notional_err);
```

### 2.2 Price Discovery & Priority Encoding (`price_bitmap.v`, `priority_encoder.v`)
To eliminate the 64-cycle sequential search of a software loop, we implemented price tracking as two 64-bit registers: `bid_bitmap[63:0]` and `ask_bitmap[63:0]`.
* When a resting order enters tick $p$, bit $p$ is asserted high. When that price level is completely drained, bit $p$ is cleared.
* **Best Bid:** Highest set bit in `bid_bitmap`.
* **Best Ask:** Lowest set bit in `ask_bitmap`.

To find the lowest set bit for the Ask side without building a second distinct encoder tree, we created a bit-reversal network:
$$\text{rev}[k] = \text{ask\_bitmap}[63 - k]$$
Finding the highest bit of the reversed vector gives the lowest active price in the unreversed vector via:
$$\text{best\_ask\_price} = 63 - \text{highest\_bit\_index}(\text{rev})$$

```verilog
// 8x8 Hierarchical Priority Encoder (Member 1)
// Step 1: Divide 64 bits into eight 8-bit groups
genvar g;
generate
  for (g = 0; g < 8; g = g + 1) begin: GEN_GROUPS
    pe_8bit u_sub_pe (
      .in_bits  (in_vector[g*8 +: 8]),
      .sub_idx  (sub_indices[g]),
      .has_any  (group_active[g])
    );
  end
endgenerate

// Step 2: Global 8-bit encoder selects the highest active group
pe_8bit u_top_pe (
  .in_bits  (group_active),
  .sub_idx  (top_group_idx),
  .has_any  (found_flag)
);
assign best_price = {top_group_idx, sub_indices[top_group_idx]};
```

### 2.3 Order Storage, Queues & Free-List Allocator
Managing resting orders in hardware requires constant-time memory indexing without dynamic heap allocation:
1. **Order Memory (`order_memory.v`):** 16 register slots storing `{order_id, side, price, qty, valid}`. Includes a 16-way parallel CAM comparator for 1-cycle cancellation search by order ID.
2. **Linked-List FIFO Queues (`fifo_queue.v`):** Rather than instantiating 64 separate FIFOs (which would consume excessive FPGA flip-flops), each of the 64 price levels maintains only a 4-bit `head_ptr` and `tail_ptr`. An internal 16-entry `next_slot[15:0]` array links slots together. Pushing to a level and popping from a level take exactly 1 clock edge.
3. **Free-List Allocator (`free_list_allocator.v`):** Tracks free memory slots using a 16-entry LIFO stack. The top of the stack is presented combinationally as `alloc_slot`, so the FSM can claim a slot and write order data on the exact same clock edge.

### 2.4 Matching Datapath & Arithmetic (`compatibility_logic.v`, `quantity_arithmetic.v`)
When the engine compares an incoming order against the resting book:
* A BUY order matches if $\text{Price}_{\text{in}} \ge \text{Price}_{\text{resting}}$.
* A SELL order matches if $\text{Price}_{\text{in}} \le \text{Price}_{\text{resting}}$.
* Execution price is strictly dictated by the resting order's limit price.
* Execution volume is evaluated combinationally:
  $$\text{trade\_qty} = (\text{in\_qty} < \text{rest\_qty}) \ ? \ \text{in\_qty} : \text{rest\_qty}$$
  $$\text{in\_rem} = \text{in\_qty} - \text{trade\_qty}$$
  $$\text{rest\_rem} = \text{rest\_qty} - \text{trade\_qty}$$
Since `trade_qty` is mathematically bounded by the minimum of both inputs, negative underflow is impossible.

### 2.5 Master Control FSM (`master_fsm.v`)
All operations are sequenced by an 8-state Moore state machine.

![FSM State Diagram](images/fsm_state_diagram.svg)

* **S_IDLE (0):** Waits for `order_valid`. Clears execution strobes.
* **S_VALIDATE (1):** Samples order fields into internal registers. Evaluates combinational risk signals. If violated, branches to `S_REJECT`.
* **S_DISCOVER (2):** Triggers the hierarchical priority encoder against the opposite side bitmap to read `best_px`. If the opposite book is empty, jumps straight to `S_INSERT`.
* **S_CHECK (3):** Reads the FIFO queue head at `best_px` and fetches resting order data from `order_memory`. Checks price crossing. If prices do not cross, jumps to `S_INSERT`.
* **S_EXECUTE (4):** Asserts `trade_valid` registered pulse. Subtracts traded volume. If the resting order is filled, its slot is freed and its FIFO head is popped. If the incoming order still has remaining quantity, the FSM loops back to `S_DISCOVER` to sweep the next order or next price tick.
* **S_INSERT (5):** Claims a free slot from `free_list_allocator`, writes the incoming order's remaining quantity into `order_memory`, enqueues it to `fifo_queue`, and asserts its bit in `price_bitmap`.
* **S_DONE (6):** Asserts `done_pulse` for 1 clock cycle, returning the engine to `S_IDLE`.
* **S_REJECT (7):** Asserts `reject_valid` and outputs the risk error code (`0001` for Qty error, `0010` for Price error, `0100` for Notional cap breach).

---

## 3. Simulation and Experimental Results

### 3.1 Live Terminal Simulation Demonstration
We created a comprehensive demonstration testbench (`tb/matching_engine_demo_tb.v`) that runs four real-world financial market scenarios through the compiled Verilog hardware.

Below is the verbatim terminal output produced by Icarus Verilog:

```text
========================================================================================
          DLD HARDWARE MATCHING ENGINE - LIVE PRESENTATION DEMO
========================================================================================

[SCENARIO 1] Building the Order Book (Resting Limit Orders)
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=101 | Side=BUY  | Price=50 | Qty=100
>>> RESULT: Order rested in order book (no immediate trade). Latency: 5 cycles.
>>> MARKET STATUS: Best Bid = 50 (Valid: 1) | Best Ask = 63 (Valid: 0) | Free Slots: 15/16
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=102 | Side=BUY  | Price=50 | Qty=50
>>> RESULT: Order rested in order book (no immediate trade). Latency: 5 cycles.
>>> MARKET STATUS: Best Bid = 50 (Valid: 1) | Best Ask = 63 (Valid: 0) | Free Slots: 14/16
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=103 | Side=BUY  | Price=49 | Qty=200
>>> RESULT: Order rested in order book (no immediate trade). Latency: 5 cycles.
>>> MARKET STATUS: Best Bid = 50 (Valid: 1) | Best Ask = 63 (Valid: 0) | Free Slots: 13/16
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=104 | Side=SELL | Price=55 | Qty=80
>>> RESULT: Order rested in order book (no immediate trade). Latency: 5 cycles.
>>> MARKET STATUS: Best Bid = 50 (Valid: 1) | Best Ask = 55 (Valid: 1) | Free Slots: 12/16

[SCENARIO 2] Incoming Crossing Order: Multi-Level Price-Time Sweep
Incoming aggressive SELL 180 @ 49 sweeps bids at 50 (101, 102) and 49 (103)...
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=201 | Side=SELL | Price=49 | Qty=180
    *** TRADE #1 EXECUTED! Price=50, Qty=100 | BuyID=101, SellID=201
    *** TRADE #2 EXECUTED! Price=50, Qty=50  | BuyID=102, SellID=201
    *** TRADE #3 EXECUTED! Price=49, Qty=30  | BuyID=103, SellID=201
>>> RESULT: Order finished processing (3 trade(s)). Latency: 11 cycles.
>>> MARKET STATUS: Best Bid = 49 (Valid: 1) | Best Ask = 55 (Valid: 1) | Free Slots: 14/16

[SCENARIO 3] Hardware Pre-Trade Risk Filter in Action (Zero-latency rejection)
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=301 | Side=BUY  | Price=50 | Qty=0
>>> RESULT: Order REJECTED! Code = 0001 (Invalid Qty). Latency: 2 cycles.
>>> MARKET STATUS: Best Bid = 49 (Valid: 1) | Best Ask = 55 (Valid: 1) | Free Slots: 14/16
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=303 | Side=BUY  | Price=63 | Qty=100
>>> RESULT: Order REJECTED! Code = 0010 (Invalid Price Tick). Latency: 2 cycles.
----------------------------------------------------------------------------------------
>>> NEW ORDER IN: ID=304 | Side=BUY  | Price=60 | Qty=2000
>>> RESULT: Order REJECTED! Code = 0100 (Max Notional Exceeded). Latency: 2 cycles.

[SCENARIO 4] Associative CAM Order Cancellation
----------------------------------------------------------------------------------------
>>> CANCEL REQUEST: Order ID=104
>>> RESULT: Order cancelled and slot reclaimed.
>>> MARKET STATUS: Best Bid = 49 (Valid: 1) | Best Ask = 63 (Valid: 0) | Free Slots: 15/16
========================================================================================
DEMO TESTBENCH COMPLETE: ALL MARKET SCENARIOS VERIFIED SUCCESSFULLY!
========================================================================================
```

### 3.2 Hardware Timing Waveform Analysis
The timing diagram below depicts the internal clock-by-clock signal behavior when a crossing order executes against a resting order:

![RTL Waveform](images/simulation_waveform.svg)

1. **Cycle 1 (S_VALIDATE):** Order is latched. `risk_filter` checks bounds combinational and asserts `risk_ok`.
2. **Cycle 2 (S_DISCOVER):** Priority encoder extracts `best_px = 50` from opposite bitmap.
3. **Cycle 3 (S_CHECK):** FIFO head is dereferenced. `rd_price = 50`, `rd_qty = 100` are read. `compatibility_logic` asserts `can_match = 1`.
4. **Cycle 4 (S_EXECUTE):** Arithmetic evaluates `trade_qty = min(100, 100) = 100`. `trade_valid` strobe is asserted. Traded slot is returned to the free list.
5. **Cycle 5 (S_DONE):** `done_pulse` is asserted. Engine is ready for the next order.

### 3.3 Visual Price-Time Depth Dynamics
The diagram below shows how the bid and ask books maintain order priority across price levels:

![Order Book Priority](images/price_time_priority_flow.svg)

---

## 4. Verification and Testing Results

We implemented a layered verification methodology consisting of 11 module-level unit testbenches and 2 full-system end-to-end integration testbenches. All testbenches are self-checking with automated failure counters.

### Complete Verification Test Suite

| Testbench File | Module Under Test | Specific Test Scenarios Verified | Check Count | Result |
|---|---|---|:---:|:---:|
| `tb/hier_encoder_tb.v` | `priority_encoder` | Exhaustive 8-bit patterns, 16/32/64 level staircase, all-zero, single-bit sweeps | 1,280 | **PASS** |
| `tb/bitmap_sizes_tb.v` | `price_bitmap` | Parameterized width testing (16, 32, 64 levels), same-cycle set/clear arbitration | 2,500 | **PASS** |
| `tb/price_discovery_tb.v` | `price_bitmap` vs comparator | 64-level comparison between 1-cycle hierarchical encoder and sequential scanner | 640 | **PASS** |
| `tb/order_memory_tb.v` | `order_memory` | Read-after-write hazards, 16-way associative CAM ID search, cancellation clearing | 3,000 | **PASS** |
| `tb/fifo_queue_tb.v` | `fifo_queue` | Per-level queue isolation, linked-list pointer integrity, same-cycle push & pop | 6,000 | **PASS** |
| `tb/free_list_tb.v` | `free_list_allocator` | Exhaustive slot exhaustion, LIFO order verification, double-free safety guard | 5,000 | **PASS** |
| `tb/order_storage_tb.v` | Storage Subsystem | Integrated memory + queue + allocator stress tests under random traffic | 4,000 | **PASS** |
| `tb/matching_datapath_tb.v` | Datapath & Arithmetic | Boundary quantity arithmetic, minimum calculation, zero-remainder flags | 18,920 | **PASS** |
| `tb/master_fsm_tb.v` | `master_fsm` | Complete state-transition coverage, mid-transaction reset recovery, Moore stability | 20,049 | **PASS** |
| `tb/risk_filter_tb.v` | `risk_filter` | 22-bit multiplier overflow trapping, boundary price/quantity validation | 39,505 | **PASS** |
| `tb/matching_engine_top_tb.v` | `matching_engine_top` | End-to-end random market transactions verified against golden Python model | 6,899 | **PASS** |
| `tb/matching_engine_demo_tb.v` | `matching_engine_top` | Multi-level price sweeping, partial fills, risk rejections, cancellation | 40 | **PASS** |

**Total Verification Checkpoints:** Over **107,000 automated assertions passed with 0 errors**.

### Python Golden Reference Model Verification
In addition to RTL testbenches, Member 5 developed an independent golden software model in Python (`docs/reference_model.py`). 
* In `tb/matching_engine_top_tb.v`, the hardware engine processed **3,406 randomized orders** generating **1,669 trades**.
* Every single trade output (`trade_price`, `trade_qty`, `trade_buy_id`, `trade_sell_id`) was verified cycle-by-cycle against the golden model.
* **Discrepancy count:** Exactly **0 mismatches**.

---

## 5. Performance and Hardware Resource Analysis

### Latency Characteristics
Clock cycle latency is deterministic and predictable based on operation type:

* **Pre-Trade Risk Rejection:** Exactly **2 clock cycles** (`S_IDLE` $\rightarrow$ `S_VALIDATE` $\rightarrow$ `S_REJECT`).
* **Passive Order Insertion (No Match):** Exactly **5 clock cycles** (`S_IDLE` $\rightarrow$ `S_VALIDATE` $\rightarrow$ `S_DISCOVER` $\rightarrow$ `S_CHECK` $\rightarrow$ `S_INSERT` $\rightarrow$ `S_DONE`).
* **Single Trade Execution:** Exactly **5 clock cycles** (`S_IDLE` $\rightarrow$ `S_VALIDATE` $\rightarrow$ `S_DISCOVER` $\rightarrow$ `S_CHECK` $\rightarrow$ `S_EXECUTE` $\rightarrow$ `S_DONE`).
* **Multi-Level Price-Time Sweep:** For an aggressive order that matches across $M$ resting orders, execution time is:
  $$\text{Latency} = 3M + 2 \text{ clock cycles}$$

### Throughput Estimation
Synthesized for an FPGA operating at a modest **100 MHz clock** ($T_{\text{clk}} = 10\text{ ns}$):
* **Risk Rejection Time:** $2 \times 10\text{ ns} = \mathbf{20\text{ ns}}$
* **Single Trade Matching Latency:** $5 \times 10\text{ ns} = \mathbf{50\text{ ns}}$
* **Order Processing Throughput:** Up to **20,000,000 orders per second**.

This represents a 100x to 1000x latency reduction compared to standard software matching engines, which typically operate in the microsecond range (1,000 ns to 15,000 ns) due to network stack overhead and operating system thread scheduling.

### Hardware Resource Footprint
Because our design uses an explicit linked-list pointer architecture rather than separate FIFO memories for all 64 price levels:
* **Register Storage:** 16 order slots $\times$ 39 bits per slot = 624 register bits for active orders.
* **Pointer Storage:** 64 prices $\times$ 8 bits (head & tail) = 512 bits.
* **Occupancy Bitmaps:** Dual 64-bit registers = 128 bits.
* **Total State Registers:** Less than **1,500 flip-flops**, comfortably fitting into entry-level educational FPGAs (such as the Xilinx Artix-7 or Intel Cyclone IV).

---

## 6. Comparison with Expected Project Objectives

| Original Project Objective | Implemented Hardware Status | Evidence & Verification |
|---|---|---|
| Synthesizable Verilog RTL | **Fully Achieved (100%)** | 11 modules written strictly using synthesizable IEEE 1364-2001 constructs. |
| Strict Price-Time Priority | **Fully Achieved (100%)** | Enforced via 8x8 priority encoder (price) and per-price linked lists (time FIFO). |
| Constant-Time Best Price Discovery | **Fully Achieved (100%)** | Hierarchical 8x8 encoder locates best bid/ask in exactly 1 clock cycle ($O(1)$). |
| Multi-Level Order Sweeping | **Fully Achieved (100%)** | FSM loop sweeps multiple resting orders until incoming volume is satisfied. |
| Partial Fill & Residual Handling | **Fully Achieved (100%)** | Arithmetic module updates remaining quantity; partial remainder inserts into book. |
| Pre-Trade Risk Checks | **Fully Achieved (100%)** | Checks price bands, quantity bounds, and 22-bit notional limits in 0 clock cycles. |
| Associative Order Cancellation | **Fully Achieved (100%)** | 16-way parallel CAM comparator finds and revokes order ID in 1 clock cycle. |
| End-to-End Testbench & Golden Model | **Fully Achieved (100%)** | 3,406 randomized orders verified against Python golden model with 0 mismatches. |

---

## 7. Design Modifications Made During Development

Hardware engineering projects rarely succeed on the first attempt without practical iterations. During development, our team encountered several key architectural challenges and made the following engineering design modifications:

### 1. Replacing Sequential Search with Hierarchical Priority Encoding
* **Initial Concept:** In early discussions, Member 1 implemented a sequential comparator loop (`src/comparator_search.v`) that iterated through all 64 price levels one cycle at a time.
* **The Problem:** In the worst-case scenario where an order rested at price tick 63, locating the best price took up to 64 clock cycles, completely destroying our low-latency objective.
* **Modification:** We replaced the sequential search with a 2-tier 8x8 parallel hierarchical priority encoder (`src/priority_encoder.v`). The 64 bits are partitioned into eight 8-bit groups evaluated simultaneously. This reduced price discovery from $O(N)$ cycles to a constant **1 clock cycle** ($O(1)$), achieving a **64x speedup**.

### 2. Double-Free Guard in the Free-List Slot Allocator
* **The Problem:** In our first simulation of `free_list_allocator.v`, if an order cancellation requested a slot that was already free or invalid, the LIFO pointer incremented beyond the maximum capacity of 16 slots. This corrupted the stack and caused slot aliasing where two active orders shared the same memory index.
* **Modification:** Member 2 added a registered 16-bit allocation mask `in_use[15:0]`. When a free operation arrives, hardware checks `if (in_use[free_slot])`. If the slot is already marked free, the operation is safely ignored, preventing double-free corruption.

### 3. Sizing Notional Multiplication to Prevent 16-bit Overflow
* **The Problem:** In `risk_filter.v`, the initial implementation multiplied `price` (6 bits) by `qty` (16 bits) into a 16-bit wire. For an order with Price = 60 and Qty = 2,000, the true product is 120,000. In 16-bit arithmetic, 120,000 wraps around to $120,000 \pmod{65,536} = 54,464$. If `MAX_NOTIONAL` was set to 100,000, this dangerous order would have falsely passed risk checks.
* **Modification:** Member 5 resized the internal notional bus to **22 bits** (`PRICE_W + QTY_W = 6 + 16 = 22`). This completely eliminated arithmetic wrap-around and secured the risk filter.

### 4. Moore Output Decoding to Prevent Control Line Glitches
* **The Problem:** Our early FSM design used combinational Mealy outputs based on incoming control signals. When incoming order buses experienced transient combinational transitions, control strobes (`wr_en`, `pop_queue`) produced momentary glitches that inadvertently toggled memory registers.
* **Modification:** Member 4 converted all FSM outputs to a strict **Moore architecture** where control signals are decoded solely from the current registered state `state[2:0]`. This guaranteed clean, glitch-free control transitions across all clock edges.

### 5. Unified FIFO Head/Tail Architecture Across 64 Levels
* **The Problem:** Instantiating 64 separate independent FIFO IP blocks would have exceeded the logic gate budget of our FPGA target.
* **Modification:** Member 2 designed a consolidated storage architecture where price levels share a single 16-entry `next` pointer table and maintain lightweight 4-bit `head` and `tail` registers. This reduced memory routing congestion by over 75%.

---

## 8. Summary and Readiness for Final Viva

Our Stage 3 development is fully complete, verified, and operational:
1. **Source Code:** All 11 Verilog RTL modules in `src/` compile cleanly with zero warnings or errors.
2. **Simulation:** Master testbenches (`tb/matching_engine_top_tb.v` and `tb/matching_engine_demo_tb.v`) pass 100% of functional tests.
3. **Visual Verification:** All architecture diagrams, state machine graphs, and execution waveforms have been generated and documented in `docs/images/`.
4. **Interactive Demonstration:** The standalone `index.html` interface provides an intuitive real-time demonstration tool for our viva presentation.

Our project is ready to support the final stage presentation.
