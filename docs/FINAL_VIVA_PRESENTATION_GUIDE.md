# Final Stage Viva & Presentation Guide
## Low-Latency Hardware Limit Order Book & Matching Engine (DLD Project)

---

## 1. Executive Summary for Presentation
* **Project Title:** Synthesizable Verilog Hardware Limit Order Book (LOB) & Parallel Matching Engine.
* **Core Problem:** Software matching engines suffer from non-deterministic latency spikes due to sequential memory scans, pointer indirection, and OS interrupts.
* **Our Solution:** A custom digital hardware architecture that processes orders under **Price-Time Priority** with deterministic **$5\text{--}11$ clock cycle latency**, using:
  1. **Hierarchical Priority Encoders:** $O(1)$ constant 1-cycle best price discovery across 64 levels (versus 1 to 64 cycles in sequential scan).
  2. **Linked-List Queue Architecture:** Exact arrival-time FIFO ordering without dedicating separate hardware memories per level.
  3. **Parallel Risk Filtering:** Zero-latency combinational validation for quantities, price bands, and notional limits.
  4. **Associative CAM Search:** Parallel slot lookup across all valid orders.

---

## 2. Team Member Division & Viva Q&A

### Member 1: Ronit Biswal (Lead) — Roll: `2025csb1511`
* **Subsystem:** Price Discovery (`src/price_bitmap.v`, `src/priority_encoder.v`, `src/comparator_search.v`).
* **1-Minute Speech:**
  > *"I implemented the 64-bit price occupancy bitmap and the hierarchical priority encoder. My module tracks active orders with 1 bit per price level and discovers the highest bid and lowest ask in a single clock cycle. I also implemented a sequential scanner as an architectural baseline to demonstrate the latency improvement."*
* **Top Viva Questions & Answers:**
  * **Q:** *Why is a hierarchical priority encoder faster than a standard priority encoder?*
    * **A:** *A flat 64-bit encoder has a long combinational delay ($\approx 64$ gate levels). Decomposing it into eight 8-bit local encoders in parallel followed by one 8-bit global encoder reduces logic depth to $\log(8) + \log(8)$, executing in under 1 clock cycle.*
  * **Q:** *How do you get lowest ask if priority encoders find the highest set bit?*
    * **A:** *I create a reversed wire vector `rev[k] = bm[LEVELS-1-k]`. The lowest set bit in `bm` becomes the highest set bit in `rev`, so the same priority encoder logic finds it without duplicating gates.*

---

### Member 2: Shalin Javaria — Roll: `2025csb1257`
* **Subsystem:** Order Storage, FIFOs & Free-List Allocator (`src/order_memory.v`, `src/fifo_queue.v`, `src/free_list_allocator.v`).
* **1-Minute Speech:**
  > *"I designed the shared 16-slot order memory array, the per-price linked FIFOs to enforce arrival-time priority, and the free-list allocator that manages slot recycling. My allocator features double-free protection to prevent memory corruption."*
* **Top Viva Questions & Answers:**
  * **Q:** *Why not create 64 independent hardware FIFOs for the 64 price levels?*
    * **A:** *64 full FIFOs of depth 16 would require $64 \times 16 = 1024$ order slots, which is wasteful since only 16 orders exist at once. Using head/tail pointers per level into a single shared `nxt[slot]` array allows all 64 levels to share 16 physical slots with zero waste.*
  * **Q:** *What happens when all 16 slots are full?*
    * **A:** *The free list counter drops to 0, which immediately deasserts `alloc_ok` and `room_ok`. The FSM transitions to `S_REJECT` with reject code `4'b1000` (Book Full).*

---

### Member 3: Saurabhraj — Roll: `2025csb1256`
* **Subsystem:** Matching Datapath & Quantity Arithmetic (`src/compatibility_logic.v`, `src/quantity_arithmetic.v`).
* **1-Minute Speech:**
  > *"I built the combinational matching datapath. `compatibility_logic` verifies whether an incoming order crosses the resting order's price, and `quantity_arithmetic` computes the trade execution size and the remaining balances."*
* **Top Viva Questions & Answers:**
  * **Q:** *What is the crossing condition for buys and sells?*
    * **A:** *For an incoming BUY, it crosses if $\text{Price}_{\text{in}} \ge \text{Price}_{\text{resting}}$ (willing to pay at least the ask). For an incoming SELL, it crosses if $\text{Price}_{\text{in}} \le \text{Price}_{\text{resting}}$ (willing to sell at or below the bid).*
  * **Q:** *Can your subtraction ever result in negative numbers?*
    * **A:** *No. Because trade quantity is strictly $\min(\text{in\_qty}, \text{rest\_qty})$, subtracting it from either operand is mathematically guaranteed never to underflow.*

---

### Member 4: Yash Kumar — Roll: `2025csb1268`
* **Subsystem:** Control FSM & Top-Level Integration (`src/master_fsm.v`, `src/matching_engine_top.v`).
* **1-Minute Speech:**
  > *"I designed the 8-state Moore control FSM and wired all subcomponents together in `matching_engine_top.v`. The FSM coordinates the handshaking, manages multi-level sweep loops, and emits registered trade records and reject codes."*
* **Top Viva Questions & Answers:**
  * **Q:** *Why is a Moore machine preferable here over a Mealy machine?*
    * **A:** *Moore machine outputs depend only on the current state register, not directly on inputs. This eliminates combinational feedthrough and prevents glitches on critical control signals like memory write enables and trade pulses.*
  * **Q:** *What is the latency formula for an order?*
    * **A:** *An order that rests without matching takes 5 cycles. Rejection takes 2 cycles. Multi-level matching takes $3n + 2$ cycles for $n$ executed trades.*

---

### Member 5: Niket — Roll: `2025csb1446`
* **Subsystem:** Pre-Trade Risk Filter & Software Reference Model (`src/risk_filter.v`, `docs/reference_model.py`).
* **1-Minute Speech:**
  > *"I implemented the parallel pre-trade risk filter that checks order legality before touching memory, and the Python reference model for golden differential verification across 30,000+ random orders."*
* **Top Viva Questions & Answers:**
  * **Q:** *What checks does your risk filter perform in parallel?*
    * **A:** *Three checks: Quantity bounds ($1 \le \text{qty} \le 1000$), Price band ($1 \le \text{price} \le 63$), and Notional check ($\text{price} \times \text{qty} \le 50000$).*
  * **Q:** *Why is the internal multiplier 22 bits wide?*
    * **A:** *The product of a 16-bit quantity and a 6-bit price requires $16 + 6 = 22$ bits. If we used a 16-bit multiplier, large numbers would wrap around and erroneously pass the risk filter.*

---

## 3. How to Demonstrate During Viva

### Option A: Open the Interactive Web Console
Open [`index.html`](file:///C:/Users/ronit/.gemini/antigravity/scratch/dld-matching-engine/index.html) in your browser:
* Click **"Worked Example"**: Shows orders #101, #102, #103 entering the book, followed by incoming aggressive Sell #201 sweeping through 3 trades.
* Click **"FIFO Time-Priority Test"**: Shows that orders at equal price ($50) match in first-come, first-served order.
* Click **"Pre-Trade Risk Filter Reject"**: Shows that illegal orders (qty 0, price > 63, or notional > 50,000) are rejected in 2 cycles.

### Option B: Run Verilog Hardware Simulation
In terminal:
```bash
bash run_sim.sh
```
All 12 testbenches will compile and output clean `PASS` lines.
