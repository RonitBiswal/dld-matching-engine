# Member 1 (Ronit, 2025csb1511) - Price Discovery
Branch: `feat-price-discovery` | Files: `src/priority_encoder.v`, `src/price_bitmap.v`, `src/comparator_search.v`
Testbenches: `tb/hier_encoder_tb.v`, `tb/bitmap_sizes_tb.v`, `tb/price_discovery_tb.v`

## A. What each file does (use this to prepare for questions)

### priority_encoder.v
- **priority_encoder #(W)**: input vector `in`, output `idx` = index of the HIGHEST set bit, `valid` = any bit set. The for-loop assigns `idx = i` for each set bit and the later (higher) one overrides, so it ends on the highest. Synthesizes to combinational logic, no clock.
- **hier_priority_encoder #(GROUPS, GW)**: splits N = GROUPS x GW bits into GROUPS groups. Each group has its own local encoder (`GW` bits). A global encoder looks only at the "group has any bit" flags and picks the highest non-empty group. The final index is `{group_index, local_index_of_that_group}`. All local encoders work in parallel, so depth is roughly log(GW) + log(GROUPS) instead of log(N) sequential scanning. For the project: 64 levels = 8 groups x 8 bits.

### price_bitmap.v
- One flip-flop per price level: bit = 1 means "at least one order rests at this price".
- `set_en/set_idx` sets a bit (order inserted at that price). `clr_en/clr_idx` clears it (last order at the price consumed).
- `best_hi` = highest set level = best BID. `best_lo` = lowest set level = best ASK. `any` = book side not empty.
- Lowest bit trick: build `rev[k] = bm[LEVELS-1-k]`, find the highest set bit of `rev` with the same encoder (`rev_idx`), then `best_lo = (LEVELS-1) - rev_idx`. This reuses the same hardware idea instead of writing a second encoder.
- Rules: set and clear on the SAME level in the same cycle -> clear wins. Different levels in the same cycle both work. `best_hi/best_lo` are only meaningful when `any = 1` (when empty they show 0 and 63). Requires PRICE_W >= 4.

### comparator_search.v
- The baseline "slow" way: a small FSM scans the bitmap one level per clock (DIR=1 from the top for best bid, DIR=0 from the bottom for best ask). `busy` while scanning, `done` pulses for one cycle, `found/idx` give the result, `cycles` counts scan cycles.
- Purpose: Stage 1 promised to compare sequential price scanning with hierarchical priority encoding. This module is the sequential side.

### How Yash's top module uses your work
`matching_engine_top` has two `price_bitmap` instances (bid, ask). For an incoming BUY it reads the ask bitmap's `best_lo`; for an incoming SELL it reads the bid bitmap's `best_hi`. It sets a bit when it rests an order and clears it when a price level empties. Agree these port names with Yash.

## B. Test results (all PASS, Icarus Verilog 12)
| Testbench | What it checks |
|---|---|
| `hier_encoder_tb` | flat encoder: all 256 (8-bit) and all 16 (4-bit) inputs; hierarchical encoder for 16, 32, 64 (project), 128 levels and 4x4 grouping: empty, every one-hot, staircase, two-hot, 3000 random vectors vs a software loop |
| `bitmap_sizes_tb` | `price_bitmap` with PRICE_W = 4, 5, 6, 7: set/clear edges (level 0 and top), same-level set+clear (clear wins), different-level same-cycle set+clear, 400 random operations vs a software model of the bitmap and best hi/lo |
| `price_discovery_tb` | 64-level bitmap with both sequential scanners next to the hierarchical result: empty, 1, 3, 5 levels, extremes (0 and 63), then 150 random operations vs golden |

Measured search time on 64 levels (clock cycles):
| Book contents | Sequential scan best bid / best ask | Hierarchical encoder |
|---|---|---|
| empty | 64 / 64 | 1 (combinational) |
| level 30 only | 34 / 31 | 1 |
| levels 7, 30, 50 | 14 / 8 | 1 |
| levels 0 and 63 | 1 / 1 | 1 |
The scan is data dependent (1 to 64 cycles); the hierarchical encoder is constant. Trade-off: it uses more logic (extra encoders and the reversed copy) - this is the latency vs area comparison for the report.

## C. Report text (edit into your own words)
**Design methodology.** Price discovery is split into storage and search. Storage is a 64-bit occupancy bitmap, one bit per price tick, updated by set/clear ports. Search is a hierarchical priority encoder: eight 8-bit local encoders run in parallel and a global 8-bit encoder selects the highest non-empty group. The best ask (lowest set bit) is found by reversing the bitmap and reusing the same encoder. A sequential comparator-search module was built as the baseline for the Stage 1 architecture comparison.

**Results.** All encoder inputs (8-bit exhaustive), five encoder sizes, four bitmap sizes and random operation streams match a software golden model. On 64 levels the hierarchical encoder returns the best price in one cycle, whereas the sequential scan needs 1-64 cycles depending on where the best price is.

**Problems encountered (replace with your real ones; these actually occurred).**
- A highest-bit encoder cannot directly give the lowest set bit; solved by bit-reversal.
- The testbench waits for both scanners: they finish at different cycles, so it must wait on `busy` going low, not on both `done` pulses at once (this caused a hanging simulation).
- Same-cycle set and clear on one level needed a defined behaviour (clear wins), documented and tested.
- Hierarchical encoder needs at least 2 groups, so the minimum bitmap is 16 levels.
