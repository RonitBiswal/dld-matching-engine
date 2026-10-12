# Member 3 (Saurabhraj Singh, 2025csb1256) - Matching Datapath
Branch: `feat-matching-datapath` (merged to `main`, PR #1) | Files: `src/compatibility_logic.v`, `src/quantity_arithmetic.v`
Testbenches: `tb/matching_datapath_tb.v`, `tb/matching_datapath_demo_tb.v`

> **Honest status (read first)**
> * Both modules and both testbenches were **really simulated** in Icarus Verilog 12. I re-ran `matching_datapath_tb` on my own machine and got `checks run: 18920   errors: 0` and `matching_datapath_tb: PASS`.
> * The two waveform screenshots come from my own GTKWave run of `matching_datapath_demo_tb`.
> * **Mutation tests** (5 deliberately broken versions of the RTL, all caught) were run while the testbench was being developed, not by me on my own machine. Before the viva, reproduce one yourself (section 3b) so you can say you saw it.
> * **Not tested:** Vivado (only Icarus + GTKWave were used), synthesis timing/area.
> * The modules were tested **alone**. Integration with the FSM is Yash's testbench (`matching_engine_top_tb`).

---

## 1. Plain-language explanation (for the viva)

**The idea.** The matching engine has to answer two questions every time an order arrives:
1. Can the incoming order trade with the best order already in the book? -> `compatibility_logic`
2. If yes, how much trades and what is left over? -> `quantity_arithmetic`

**Example (Stage 1 worked example).** Bids in the book: B1 100@50, B2 50@50, B3 200@49. A SELL 180@49 arrives.

| Step | compatibility_logic | quantity_arithmetic |
|---|---|---|
| vs B1 (100@50) | SELL 49 <= bid 50, so `can_match`=1 | trade = min(180,100) = 100, incoming left 80, B1 left 0 (`rest_done`=1) |
| vs B2 (50@50) | 49 <= 50, so 1 | trade = min(80,50) = 50, incoming left 30, B2 done |
| vs B3 (200@49) | 49 <= 49, so 1 (equal price counts) | trade = min(30,200) = 30, incoming left 0 (`in_done`=1), B3 left 170 |

The trade price is always the **resting** order's price (50, 50, 49), not the incoming 49.

### compatibility_logic.v
Inputs `in_side` (1=BUY, 0=SELL), `in_price`, `rest_price` (best price on the opposite side), `rest_valid`. Output `can_match`.
* BUY crosses when `in_price >= rest_price` (willing to pay at least the ask).
* SELL crosses when `in_price <= rest_price` (willing to sell for at most the bid).
* `rest_valid` is ANDed in: if the opposite side is empty, `rest_price` is garbage, so the result is forced to 0.
* Purely **combinational**: two comparators, a 2:1 mux on `in_side`, and one AND gate. No clock, no reset.

### quantity_arithmetic.v
Inputs `in_qty`, `rest_qty`. Outputs `trade_qty`, `in_rem`, `rest_rem`, `in_done`, `rest_done`.
* `trade_qty = min(in_qty, rest_qty)` (a comparator plus a 2:1 mux).
* `in_rem = in_qty - trade_qty`, `rest_rem = rest_qty - trade_qty` (two subtractors).
* `in_done = (in_rem == 0)`, `rest_done = (rest_rem == 0)`.
* Because `trade_qty` is never bigger than either input, the subtractions **cannot underflow**. Example: 30 - 100 would wrap to 65466 in 16-bit unsigned, but 30 - min(30,100) = 0.
* Both flags can be 1 together (exact fill, e.g. 100 vs 100).
* Purely **combinational**.

### How it fits the architecture
The master FSM (Yash) reads `can_match` in state **CHECK**. If 1 it goes to **EXECUTE**, which uses `trade_qty`, `in_rem`, `rest_rem` and the done flags: if `rest_done` it pops the FIFO, invalidates the memory slot, frees the slot and clears the bitmap bit if the level emptied; otherwise it writes `rest_rem` back. If `in_done` the order is finished; otherwise the FSM loops back to DISCOVER for the next price level. Since both blocks are combinational, they add no clock cycles of their own.

### Ports (as agreed, unchanged)
| Module | Parameter | Inputs | Outputs |
|---|---|---|---|
| `compatibility_logic` | `PRICE_W`=6 | `in_side`, `in_price`, `rest_price`, `rest_valid` | `can_match` |
| `quantity_arithmetic` | `QTY_W`=16 | `in_qty`, `rest_qty` | `trade_qty`, `in_rem`, `rest_rem`, `in_done`, `rest_done` |

---

## 2. The code
Already in `src/` (commented line by line). Read each file top to bottom once; each is about 10 lines of logic.

---

## 3. Testbenches

### 3a. What each testbench covers
| Testbench | Covers |
|---|---|
| `matching_datapath_tb` | **Compatibility:** 17 directed cases (BUY and SELL with price greater/equal/less, empty book for both sides, prices 0 and 63, Stage 1 example prices), then **all 16,384 input combinations** (2 sides x 64 x 64 x 2), then 500 random cases. **Quantity:** 13 directed cases (3 worked-example trades, exact fills, 0 vs 0, zero on either side, 0xFFFF extremes, 0x8000/0x7FFF boundary) plus 2 explicit value checks, 2,000 random pairs (half small values so equal and exact fills actually occur, half full 16-bit), and a combined 3-trade sweep (total traded 180, incoming ends at 0, B3 left with 170). **Total 18,920 checks.** Every check is compared with an independent behavioural golden model; the testbench prints PASS/FAIL and dumps a VCD. |
| `matching_datapath_demo_tb` | Short (about 120 ns) waveform demo: the Stage 1 sweep plus the empty-book and equal-price cases. Used only for the waveform screenshots. |

**Where the number 16,384 comes from:** `compatibility_logic` has 1 + 6 + 6 + 1 = 14 input bits, and 2^14 = 16,384. Testing every input pattern of a combinational circuit means nothing is left untested for that module. Quantity arithmetic has two 16-bit inputs (2^32 patterns, about 4.3 billion), so it uses directed edge cases plus random tests instead.

### 3b. Reproduce the mutation test yourself (2 minutes, do this once before the viva)
1. Open `src/compatibility_logic.v` and change `(in_price >= rest_price)` to `(in_price > rest_price)`. Do **not** commit this.
2. Re-run the testbench (commands in section 4a). It should print `FAIL [...]` lines and `matching_datapath_tb: FAIL`.
3. Undo the change (`git checkout src/compatibility_logic.v`) and confirm it prints PASS again.
The other mutations that were caught: `<=` to `<`, removing `rest_valid`, min changed to max, and `in_done` stuck at 0.

---

## 4. Running the simulation

### 4a. Icarus Verilog + GTKWave (what I used)
From the repo root in Git Bash:
```
mkdir -p sim
iverilog -g2012 -o sim/dp.vvp src/compatibility_logic.v src/quantity_arithmetic.v tb/matching_datapath_tb.v
vvp sim/dp.vvp                      # expect: checks run: 18920  errors: 0  /  matching_datapath_tb: PASS

iverilog -g2012 -o sim/demo.vvp src/compatibility_logic.v src/quantity_arithmetic.v tb/matching_datapath_demo_tb.v
vvp sim/demo.vvp                    # prints the worked example
gtkwave sim/matching_datapath_demo_tb.vcd
```
A "no explicit time unit" warning from the modules is harmless.

### 4b. Vivado (not tested by me)
Add the two `src` files as design sources, add the testbench as a simulation source, set it as top, Run Behavioral Simulation, then `run all`. The demo testbench uses `.*` port connections, so if Vivado complains set the file type to SystemVerilog.

### 4c. Waveform setup in GTKWave
Left panel: click `matching_datapath_demo_tb`, select signals in the lower-left list (Ctrl+click), press **Append**, then Zoom Fit. To read numbers in decimal, select them in the **middle** Signals column (not the bottom-left list), right-click, **Data Format -> Decimal**.

* **Waveform 1 (quantity):** `in_qty`, `rest_qty`, `trade_qty`, `in_rem`, `rest_rem`, `in_done`, `rest_done`. 0-20 ns: 180 vs 100 gives trade 100, rem 80, `rest_done`=1. 20-40 ns: 80 vs 50 gives 50, rem 30. 40-60 ns: 30 vs 200 gives 30, `in_done`=1, rest_rem 170. After that, the 1 vs 1 and 60 vs 60 exact-fill cases.
* **Waveform 2 (compatibility):** `in_side`, `in_price`, `rest_price`, `rest_valid`, `can_match`. 0-60 ns: SELL@49 vs rest 50, 50, 49 gives `can_match`=1. 60-80 ns: rest 48 gives 0. 80-100 ns: `rest_valid`=0 gives 0 even with rest 63. 100-120 ns: BUY@50 vs ask 50 (equal price) gives 1.

---

## 5. Git (what was done, for reference)
```
git clone https://github.com/RonitBiswal/dld-matching-engine.git
cd dld-matching-engine
git checkout -b feat-matching-datapath
mkdir src tb                         # folders did not exist (Git does not store empty folders)
# copy 2 modules into src/, 2 testbenches into tb/
git status
git add .
git commit -m "Add compatibility_logic, quantity_arithmetic and datapath testbenches"
git push origin feat-matching-datapath
# GitHub: Compare & pull request -> PR #1 (merged into main)
```
Real problems I hit: `git clone` failed with "Permission denied" because I ran it inside `C:\Program Files` (fixed by `cd ~/Documents`); the repo had no `src/` or `tb/`; Yash's files had landed in the repo root, so I moved them with a `fix-folder-layout` branch (PR #6); `iverilog` was "command not found" until I installed it with "Add to PATH" ticked and opened a new Git Bash.

---

## 6. My section of the Stage 2 report (already in the team Doc; edit into your own words)

### 6.1 Initial implementation
`compatibility_logic.v` decides whether the incoming order can trade against the best resting order on the opposite side: a BUY crosses when its price is at least the resting ask, a SELL when its price is at most the resting bid, and an extra `rest_valid` input forces the result to 0 for an empty book. `quantity_arithmetic.v` works out one trade: the trade quantity is the smaller of the two quantities, the remainders are found by subtracting it from both, and `in_done` / `rest_done` flag an order that reached zero. Both are combinational, so they add no clock cycles; the FSM reads `can_match` in CHECK and the arithmetic outputs in EXECUTE. *[code screenshots of both files]*

### 6.2 Design methodology
Bottom-up, starting from the smallest primitives (comparators and min/subtract logic) before the storage and FSM. The Stage 1 example was worked by hand first and used as the first directed test. Verification uses a self-checking testbench with an independent behavioural golden model, with directed, exhaustive and random cases, and the testbench itself was checked by breaking the RTL on purpose (mutation tests).

### 6.3 Results (Icarus Verilog 12)
| Test | What it covers | Result |
|---|---|---|
| Compatibility, directed (17) | BUY/SELL greater, equal, less; empty book; prices 0 and 63; Stage 1 prices | PASS |
| Compatibility, exhaustive (16,384) | every input combination vs golden model | PASS |
| Compatibility, random (500) | random inputs | PASS |
| Quantity, directed (15) | worked-example trades, exact fills, zeros, 0xFFFF, MSB boundary | PASS |
| Quantity, random (2,000) | small and full-width pairs vs golden model | PASS |
| Combined sweep | 180 across 100, 50, 200: total 180, remaining 0, B3 left with 170 | PASS |
| Mutation tests | 5 deliberate RTL bugs | all 5 caught |
| **Total** | **18,920 checks** | **0 errors, PASS** |

*[terminal PASS screenshot, waveform 1, waveform 2]*

### 6.4 Problems / challenges
* **Equal prices:** easy to write `>` instead of `>=`; a BUY at 50 must trade with an ask at 50. Covered by the exhaustive test and a mutation test.
* **Empty book:** with nothing on the opposite side, the best-price output is meaningless, so `compatibility_logic` has `rest_valid`.
* **Underflow:** unsigned subtraction wraps (30 - 100 gives 65466); taking the minimum first makes both subtractions safe.
* **Testbench timing:** the first demo printed garbage values because it printed in the same time step as the input change; fixed by waiting for the signals to settle.
* **Git and tools:** see section 5.

### 6.5 My work as a team member
Wrote and verified `compatibility_logic.v` and `quantity_arithmetic.v`, wrote the self-checking datapath testbench and a short waveform demo testbench, ran the simulations, pushed branch `feat-matching-datapath` (PR #1), and moved the misplaced Member 4 files into `src/`, `tb/` and `docs/` (PR #6).

---

## 7. Likely viva questions and short answers
1. **What does `compatibility_logic` do?** Tells the FSM whether the incoming order's price crosses the best resting price on the opposite side.
2. **Why `>=` for BUY?** A buyer at 50 will trade with a seller asking 50. Equal price is a valid trade.
3. **What is `rest_valid` for?** If the opposite side is empty there is no resting order; without it a stale `rest_price` could create a fake match.
4. **Why combinational (no clock)?** It is only comparators and subtractors, so it adds no cycles; the FSM's state register supplies the timing.
5. **How is `trade_qty` computed?** `min(in_qty, rest_qty)`: a comparator and a 2:1 multiplexer.
6. **Can the subtraction underflow?** No. `trade_qty` is at most each input, so `qty - trade_qty` is always at least 0.
7. **Can `in_done` and `rest_done` both be 1?** Yes, on an exact fill (100 vs 100); both orders finish.
8. **What does the FSM do with `rest_done`?** Pops the FIFO, invalidates the memory slot, frees the slot, clears the bitmap bit if `rd_last` says the level is now empty. Otherwise it writes `rest_rem` back.
9. **What does the FSM do with `in_done`?** Stops matching and goes to DONE; if it is 0 and no more orders cross, the leftover rests in the book (INSERT).
10. **At what price does a trade happen?** The resting order's price, not the incoming order's limit (50, 50, 49 in the worked example).
11. **Walk through the worked example.** SELL 180@49: trade 100 (B1), 80 left; trade 50 (B2), 30 left; trade 30 (B3), 0 left, B3 has 170.
12. **Which test cases did you run?** Compatibility: 17 directed, all 16,384 input combinations, 500 random. Quantity: 13 directed plus 2 explicit checks, 2,000 random, and the 3-trade sweep. All against a golden model: 18,920 checks, 0 errors.
13. **Where does 16,384 come from?** 14 input bits (1 + 6 + 6 + 1), and 2^14 = 16,384.
14. **Why is quantity not exhaustive?** Two 16-bit inputs give 2^32 (about 4.3 billion) patterns, so it uses directed edge cases plus random tests.
15. **Who wrote the golden model, and does PASS prove it is correct?** I wrote it, separately from the RTL. PASS means the hardware matches my model; the model's rules come from the Stage 1 spec, and the Stage 1 worked example is included as a check against the spec itself.
16. **What is a mutation test?** Deliberately breaking the RTL (for example `>=` to `>`) and checking the testbench fails, to prove the tests can catch bugs.
17. **How does the widths choice matter?** `PRICE_W`=6 gives 64 price ticks and `QTY_W`=16 gives quantities up to 65535; both are parameters, shared with the team.
18. **What are the limits?** Tested alone (integration is in Yash's testbench), no synthesis or timing results yet, one trade per EXECUTE cycle in the FSM.
19. **How does this fit the whole system?** Ronit finds the best price, Shalin stores orders and queues, my blocks decide the match and trade size, Yash's FSM controls the steps, Niket filters risky orders and wrote the Python reference model.

---

## 8. Stage 3 (what is next)
My two modules should not need changes. Possible work: assertions for them (for example `trade_qty <= in_qty` and `trade_qty <= rest_qty`), and checking the integrated engine against Niket's `reference_model.py`. Wait for the team's Stage 3 split before starting.

---

## 9. Final checklist (deadline 2:50 PM)
- [x] Files pushed, PR #1 merged, folder-layout fix merged (PR #6)
- [x] Simulation run on my own machine; PASS seen (`checks run: 18920   errors: 0`)
- [x] Waveforms 1 and 2 taken from my own GTKWave run
- [ ] Code screenshots of `compatibility_logic.v` and `quantity_arithmetic.v` pasted in the shared Doc
- [ ] Terminal PASS screenshot and both waveforms pasted with captions
- [ ] Section 6 text pasted and rewritten in my own words; `[TO FILL]` and `[INSERT]` lines removed
- [ ] Team told my part is ready for the PDF
- [ ] Mutation test reproduced once (section 3b) so I can say I saw it
- [ ] Read the viva Q&A once; can explain every line of both modules without looking
