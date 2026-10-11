# Member 4 (Yash Kumar, 2025csb1268) - Control FSM and Integration
Branch: `feat-integration` | Files: `src/master_fsm.v`, `src/matching_engine_top.v`
Testbenches: `tb/master_fsm_tb.v`, `tb/matching_engine_top_tb.v` | Script: `run_sim_member4.sh`

> **Honest status (read first)**
> * `master_fsm.v` + `master_fsm_tb.v`: **really simulated, PASS** (Icarus Verilog 12, 20,049 checks).
> * `matching_engine_top.v` + `matching_engine_top_tb.v`: they **compile and the testbench logic is proven**, but I could not run them against your teammates' *real* modules (not written yet). I dry-ran them against throw-away stand-in models that I wrote only for my own checking (not in your repo, not for submission): 6,899 checks, 0 errors, and 11 deliberate bugs injected into the design were all caught. **The real result only exists after you run `bash run_sim_member4.sh` with Shalin's, Saurabhraj's, Niket's and Ronit's real files in `src/`.** Do not put a PASS in the report until you have seen it yourself.
> * Vivado was not available to me. The Icarus steps are tested; the Vivado steps are standard but untested by me.
> * Ronit's `Stage2_Report_Draft` already contains results for `matching_engine_top_tb` and latency numbers (e.g. "3 + 4 x trades"). Those are **not from your design** (yours is 3 cycles per trade, see below). Use only numbers from your own run.

---

## A. What your part does (use this for the viva)

**Idea in one sentence.** The matching engine is a *datapath* (storage + comparators + arithmetic, built by your four teammates) and your part is the *brain and the wiring*: `master_fsm` decides which step comes next, and `matching_engine_top` connects every module and moves the data for each step.

### master_fsm.v - the control brain
A Moore state machine (outputs depend only on the current state) with 8 states in a 3-bit register (all 8 codes used, so there is no illegal state):

| State | Code | What happens | Next state |
|---|---|---|---|
| IDLE | 0 | `in_ready = 1`, waiting. When `in_valid` the order is latched | VALIDATE if `in_valid` |
| VALIDATE | 1 | risk filter looks at the latched order | DISCOVER if `risk_ok`, else REJECT |
| DISCOVER | 2 | find best price of the *opposite* book and remember it | CHECK |
| CHECK | 3 | read the best resting order, ask compatibility logic "do they cross?" | EXECUTE if `can_match`, else INSERT |
| EXECUTE | 4 | do ONE trade | DONE if incoming order is used up (`in_done`), else DISCOVER (loop = multi-level fill) |
| INSERT | 5 | put the leftover into the book | DONE if a free slot exists (`room_ok`), else REJECT |
| DONE | 6 | one-cycle `done_pulse` | IDLE |
| REJECT | 7 | one-cycle `reject_valid` | IDLE |

Style choices you can defend: next-state logic in one `always @*`, state register in one clocked block with async active-low reset, outputs decoded from the state (no glitches, easy to see in a waveform).

### matching_engine_top.v - the integration
* **Incoming order lives in registers** (`cur_id/side/price/qty`). It only enters order memory if a remainder must rest (INSERT).
* **Two books**, one per side: a price bitmap (Ronit) + a per-price FIFO of slot numbers (Shalin). **One shared** order memory and free list (a slot belongs to exactly one side).
* For an incoming **BUY** the opposite book is the **ask** book (best = lowest price, `best_lo`); for an incoming **SELL** it is the **bid** book (best = highest, `best_hi`). The top muxes between them with `cur_side`.
* **Trades happen at the resting order's price**, taken from order memory (`rd_price`). Time priority comes for free: the FIFO head is the oldest order at that price.

What each state does to the hardware:

| State | Datapath action (all on the clock edge at the end of that state) |
|---|---|
| IDLE + `in_valid` | latch `in_*` into `cur_*` |
| VALIDATE | nothing stored; `risk_filter` is combinational on `cur_qty/cur_price`. On failure `reject_code` <= risk reason |
| DISCOVER | `best_px` <= best opposite price; `opp_any` <= opposite book not empty |
| CHECK | no side effects. FIFO head at level `best_px` -> `order_memory` read -> `compatibility_logic` |
| EXECUTE | `trade_*` <= (resting price, `min` qty, ids); `cur_qty` <= remaining. If resting order used up: pop its FIFO, invalidate its memory record, return slot to free list, clear bitmap bit if it was the last order at that level (`rd_last`). Otherwise write its reduced quantity back |
| INSERT | allocate slot, write the record, push slot on the FIFO of its own side at `cur_price`, set its bitmap bit - all in one cycle |

Reject codes: `reject_code[2:0]` = risk reason from Niket (bit0 bad quantity, bit1 price outside band, bit2 notional too large), `4'b1000` = book full.

**Cycle counts of this design** (accept -> done): insert with no match = **5**, risk reject = **2**, book-full reject = **5**, n trades fully filling the order = **3n + 2**, n trades then the remainder rests = **3n + 5**.

**Design decisions worth knowing**
1. `room_ok = (free_count != 0)` instead of `alloc_ok`, so there is no combinational loop between `alloc_en` and `alloc_ok`.
2. One trade per EXECUTE cycle; CHECK has no side effects, so EXECUTE can safely re-read the same values.
3. I never push and pop the same FIFO in one cycle (that was an open issue in the draft report), so the queue does not need that case.
4. A sticky `err_flag` in the top is set if EXECUTE ever finds the resting order inconsistent (invalid, wrong side, or price different from `best_px`). It catches bitmap/queue disagreement.

---

## B. Interface contract - confirm these with your teammates

The shared port list fixes names, not exact behaviour. My code assumes the following. **Send this table to the owners (message at the end of this section) and re-check each point when you paste their finished files.**

| Module (owner) | What my top assumes |
|---|---|
| `price_bitmap` (Ronit) - read from his real code | `set`/`clr` take effect on the clock edge; `best_hi/best_lo` combinational; only valid when `any = 1`. I never set and clear in the same cycle. |
| `fifo_queue` (Shalin) | `rd_head/rd_nonempty/rd_last` are **combinational** functions of `rd_level`; `rd_last` = head is the only order at that level; `push`/`pop` take effect on the clock edge. I use two instances (bid, ask); same `rd_level` for both. |
| `order_memory` (Shalin) | `rd_*` is **combinational** from `rd_addr`; `wr_en` writes the whole record and sets valid; `qty_wr_en` changes only the quantity; `inv_en` clears valid. All writes on the clock edge. `lk_*` unused in Stage 2 (`lk_id` tied to 0). |
| `free_list_allocator` (Shalin) | **`alloc_slot` is the slot that will be handed out if `alloc_en=1` in this same cycle (combinational "peek"), and is consumed at the clock edge.** `free_en/free_slot` returns a slot at the edge. `free_count` = number of free slots, width `$clog2(SLOTS)+1`. *This is the assumption most likely to differ.* If `alloc_slot` appears one cycle AFTER `alloc_en`, tell me - INSERT must become two cycles. |
| `compatibility_logic` (Saurabhraj) | combinational; `can_match = 0` whenever `rest_valid = 0` |
| `quantity_arithmetic` (Saurabhraj) | combinational; `in_done = (in_rem == 0)`, `rest_done = (rest_rem == 0)` |
| `risk_filter` (Niket) | combinational; `ok = (reason == 0)`; the three reason bits are independent (e.g. quantity 1001 at price 50 sets both bit0 and bit2) |

Message to send (edit as you like):
> "Yash here. My top assumes: (1) free_list alloc_slot is a combinational peek of the next free slot, consumed when alloc_en=1 at the clock edge, free_count has $clog2(SLOTS)+1 bits; (2) fifo_queue rd_head/rd_nonempty/rd_last and order_memory rd_* are combinational; (3) quantity_arithmetic in_done/rest_done mean remaining == 0; (4) risk_filter reason bits are independent and ok = (reason==0). If your module behaves differently, tell me tonight. Please push your branch and open the pull request as soon as your files compile."

---

## C. Git, step by step (beginner)

### C1. One-time setup
1. Install Git (https://git-scm.com). Check: `git --version`.
2. Tell Git who you are (only once; if you skip it `git commit` will complain "Please tell me who you are"):
   ```
   git config --global user.name "Yash Kumar"
   git config --global user.email "your-github-email@example.com"
   ```
3. **Accept the GitHub invitation.** Open the email "Ronit invited you to collaborate", or go to https://github.com/RonitBiswal/dld-matching-engine/invitations while logged in and click **Accept invitation**.

### C2. Clone and create your branch
```
git clone https://github.com/RonitBiswal/dld-matching-engine.git
cd dld-matching-engine
git checkout -b feat-integration
```
(`checkout -b` creates the branch and switches to it. Check with `git branch` - the star must be next to `feat-integration`.)

### C3. Put your files in place
```
dld-matching-engine/
  src/master_fsm.v
  src/matching_engine_top.v
  tb/master_fsm_tb.v
  tb/matching_engine_top_tb.v
  run_sim_member4.sh
  docs/Member4_Yash_Explanation_and_Report_Section.md   (optional)
```
Create `sim/` yourself when you simulate (`mkdir sim`); do not commit `.vvp` files.

### C4. Save to GitHub
```
git status
git add src tb run_sim_member4.sh docs
git commit -m "Member 4: master FSM, matching engine top, testbenches"
git push origin feat-integration
```
`git status` should list only your files in green after `git add`. (The team workflow says `git add .`; I use explicit folders so a stray `sim/*.vcd` or `.vvp` does not get committed. If you use `git add .`, delete those first.)

Then on GitHub: open the repo, click the yellow banner **Compare & pull request**, check base = `main`, compare = `feat-integration`, write a title, click **Create pull request**.

### C5. Your extra job: you merge everyone's pull requests
1. Repo -> **Pull requests** tab -> open a teammate's request.
2. **Files changed** tab: check only their own files are changed (their `src/` and `tb/` files, nothing of yours).
3. Back on **Conversation**: if it says "This branch has no conflicts", click **Merge pull request** -> **Confirm merge**.
4. After all four teammates are merged, get the real modules into your branch and run the integrated test:
   ```
   git checkout feat-integration
   git pull origin main
   bash run_sim_member4.sh
   ```
   If it passes, `git push origin feat-integration` again, then merge your own pull request.
5. Update the block diagram (changes listed in section F).

### C6. When something goes wrong
* **Merge conflict** (message "CONFLICT ... Automatic merge failed" or GitHub says "This branch has conflicts"). Since everybody edits different files this should be rare (most likely cause: two people committed a file with the same name, e.g. `run_sim.sh`). Run `git status`; the conflicted files are marked "both added/modified". Open each file; you will see
  ```
  <<<<<<< HEAD
  your version
  =======
  their version
  >>>>>>> main
  ```
  Keep what is right (or keep both, renamed), delete the three marker lines, save, then `git add THAT_FILE`, `git commit -m "Resolve conflict"`, `git push origin feat-integration`. If you are stuck, `git merge --abort` goes back to before the merge.
* **Permission error** (`403`, "Permission denied", "repository not found"). Almost always the invitation is not accepted yet (C1 step 3), or you are logged in to a different GitHub account than the one invited. On `git push`, Git no longer accepts your password: use the browser login popup, or GitHub Desktop, or create a Personal Access Token (GitHub -> Settings -> Developer settings -> Personal access tokens) and paste it as the password.
* **"Updates were rejected ... fetch first"** on push: `git pull origin feat-integration` then push again.
* **"nothing to commit"**: files are not inside the repo folder; check with `git status` and `ls`.
* **Pushed to the wrong branch**: `git branch` shows where you are. Tell the team; do not force-push.

---

## D. Running the simulation

### D1. Icarus Verilog + GTKWave (quickest, what I tested)
Install: Windows - installer from https://bleyer.org/icarus/ (includes GTKWave; tick "Add to PATH"); Ubuntu - `sudo apt install iverilog gtkwave`; macOS - `brew install icarus-verilog gtkwave`.
```
cd dld-matching-engine
bash run_sim_member4.sh          # (Windows: use "Git Bash" for bash)
gtkwave sim/matching_engine_top.vcd
```
The script runs the FSM testbench (needs only `master_fsm.v`) and then the integrated testbench (needs every file in `src/`). Look for the lines `MASTER_FSM_TB: PASS` and `MATCHING_ENGINE_TOP_TB: PASS`. Any line starting with `FAIL` names the order and what was expected vs seen.

### D2. Vivado
1. **Create Project** -> RTL Project, tick "Do not specify sources at this time", choose any part (e.g. `xc7a35tcpg236-1`).
2. **Add Sources** -> *Add or create design sources* -> add every file in `src/`.
3. **Add Sources** -> *Add or create simulation sources* -> add `tb/master_fsm_tb.v` and `tb/matching_engine_top_tb.v`.
4. In **Sources** -> **Simulation Sources** -> `sim_1`, right-click `matching_engine_top_tb` -> **Set as Top**. (Only one top at a time; repeat for `master_fsm_tb` separately.)
5. **Flow Navigator** -> **Run Simulation** -> **Run Behavioral Simulation**.
6. The default run time is only 1000 ns. Click **Run All** (the "play with infinity" toolbar button) or type `run all` in the Tcl console. The simulation stops by itself at `$finish`; the PASS/FAIL line appears in the **Tcl Console**.
7. If compilation complains about a file that is not a design file, check it is under Design Sources (and the testbenches under Simulation Sources only).

---

## E. Waveform signals and screenshots

### E1. Signals to add (integrated testbench)
Add in this order (top to bottom): `clk`, `rst_n`, `in_valid`, `in_ready`, `in_id`, `in_side`, `in_price`, `in_qty`, **`dut/fsm_state`** (set radix to Unsigned Decimal; 0 IDLE, 1 VALIDATE, 2 DISCOVER, 3 CHECK, 4 EXECUTE, 5 INSERT, 6 DONE, 7 REJECT), `trade_valid`, `trade_price`, `trade_qty`, `trade_buy_id`, `trade_sell_id`, `done_pulse`, `reject_valid`, `reject_code`, `best_bid`, `best_bid_valid`, `best_ask`, `best_ask_valid`, `free_count`, plus from the DUT: `dut/cur_qty`, `dut/best_px`, `dut/err_flag`. In GTKWave: expand `matching_engine_top_tb` -> select the signals -> **Append**. In Vivado: right-click in the Scope window -> **Add to Wave Window**. Use **Zoom Fit**, then drag-zoom.

For `master_fsm_tb`: `clk, rst_n, in_valid, risk_ok, can_match, in_done, room_ok, state, in_ready, accept, done_pulse, reject_pulse`. Zoom on the first ~300 ns (paths A-E).

### E2. Which moments to zoom on (times from my dry run; with your real modules the cycle counts should be identical if the assumptions in section B hold; otherwise search for the `in_valid` pulse of the order)
The testbench prints `[waveform marker]` lines with the start time of key orders.

| Screenshot | Where | What it shows |
|---|---|---|
| W1 - worked example | ~260 to ~380 ns (order 201, SELL 180 @ 49) | state goes `1,2,3,4,2,3,4,2,3,4,6`; `trade_valid` pulses 3 times: (50,100,buy 101), (50,50,102), (49,30,103); `best_bid` drops 50 -> 49; `free_count` rises 13 -> 15; `done_pulse` at the end; `cur_qty` 180 -> 80 -> 30 -> 0 |
| W2 - insert, no match | ~460 ns (order 301) | states `1,2,3,5,6`, `best_ask_valid` rises, `free_count` falls by 1, no `trade_valid` |
| W3 - risk reject | ~3400 ns (order 711, qty 0) | states `1,7` only, `reject_valid` with `reject_code = 1`, no change in `best_*` |
| W4 - book full | ~4630 ns (order 900) | states `1,2,3,5,7`, `reject_code = 8` (binary 1000), `free_count = 0` |
| W5 - 16-trade sweep | ~8290 ns (order 1300), 50 cycles | 16 `trade_valid` pulses, `free_count` goes back up to 16, `best_ask_valid` falls to 0 |
| W6 - FSM alone | `master_fsm_tb`, first 300 ns | the 5 paths A-E |

Also take a screenshot of the terminal showing both PASS lines.

### E3. Screenshots for the shared Google Doc
1. **Code screenshots** (one per file, readable font): `master_fsm.v`, `matching_engine_top.v`, `master_fsm_tb.v`, `matching_engine_top_tb.v`. Long files: 2 screenshots each (top half / bottom half). Put your name/branch name visible if possible (editor title bar).
2. **Waveforms**: W1 to W6 above, with the signal-name column visible, each with a one-line caption.
3. **Terminal** with PASS lines and the latency summary line.
4. **GitHub**: screenshot of your pull request page and of the merged PRs list (proof of the workflow).

---

## F. Your section of the Stage 2 report (edit into your own words)

### Updated block diagram / design changes (you own this section)
Insert the Stage 1 figure and mark these changes:
1. Input/output FIFOs, arbiter and backpressure postponed to Stage 4; Stage 2 uses a plain `in_valid`/`in_ready` handshake.
2. The Stage 1 states READ and DISCOVER_BEST were merged/renamed: order latching happens at the IDLE->VALIDATE transition (`accept`), and the FSM is IDLE, VALIDATE, DISCOVER, CHECK, EXECUTE, INSERT, DONE, REJECT.
3. The incoming order is held in registers, not in order memory, until a remainder must rest.
4. Separate BUY/SELL price bitmaps and per-price FIFOs; shared order memory and free list.
5. Fixed parameters: 6-bit price (64 ticks), 16-bit quantity and ID, 16 slots. Stage 1 prices 500/499 are scaled to ticks 50/49.
6. Trades execute at the resting order's price, one trade per EXECUTE cycle; EXECUTE loops back to DISCOVER for multi-level fills.
7. Reject paths: risk failure (VALIDATE) and book full (INSERT). Cancel and ID lookup postponed to Stage 3.

### Initial implementation (my part)
I wrote `master_fsm.v` (8-state Moore controller with async reset and decoded outputs) and `matching_engine_top.v`, which instantiates and connects the whole datapath: risk filter, two price bitmaps, two per-price FIFOs, shared order memory, free-list allocator, compatibility logic and quantity arithmetic. The top latches the incoming order, tracks the best opposite price, emits registered trade records, writes reduced quantities back, frees used-up slots, inserts remainders and reports reject codes. I also wrote two self-checking testbenches and a run script. [paste code screenshots]

### Design methodology
Bottom-up, as in the Stage 1 plan. The control (FSM) was separated from the datapath so the FSM could be verified alone first (directed path tests, mid-order async reset, Moore decode check, 20,000 random cycles against an independent next-state function). The integrated testbench drives the DUT through the valid/ready interface and compares every order against a software golden order book written in the testbench (plain loops over the slots: best price, oldest first, trade at resting price, book-full rule). It checks trades, reject codes, best bid/ask, free-slot count and handshake behaviour after every order. Interfaces between modules were agreed in writing with the module owners before integration.

### Simulation / test results
| Testbench | Covers | Result |
|---|---|---|
| `master_fsm_tb` | every transition, five complete paths (rest, risk reject, one trade, multi-trade loop then rest, book-full reject), `in_valid` ignored while busy, async reset mid-order, one-hot decode, 20,000 random cycles vs model | **PASS** - 20,049 checks, 0 errors (real run) |
| `matching_engine_top_tb` | Stage 1 worked example (trades (50,100), (50,50), (49,30)); empty-book insert; non-crossing; exact match; trade at resting price for aggressive BUY and SELL; partial fill of incoming and of resting; equal-price FIFO order; multi-level sweeps both sides; extreme prices; risk rejects (qty 0, over max, price below/above band, notional over, notional exactly at limit); rejected order does not change book; book full (reject with code 8); slot reuse; 16-level sweep; junk `in_valid` while busy; reset mid-order; 3,300 random orders in 4 phases vs golden | **[fill in from YOUR run with the real modules: PASS/FAIL, number of checks]** |

Latency (clock cycles from accept to done/reject), from the testbench summary line: insert with no match = 5; risk reject = 2; book-full reject = 5; worked example (3 trades, fully filled) = 11; 16-level sweep = 50. General formula: 3n + 2 for n trades that fill the order, 3n + 5 if a remainder rests. **[Replace with the numbers printed by your own run.]** The FSM-only numbers (20,049 checks) are from a real run.

### Problems / challenges (keep only what you really experienced; these happened while building this code)
- **Interface ambiguity.** The shared port list does not say whether `alloc_slot` is a combinational peek or a registered output, or which outputs are combinational. I wrote the assumptions down (section B) and asked each owner to confirm.
- **Combinational loop risk.** Using `alloc_ok` to decide whether to allocate could loop with `alloc_en`; I decide with `free_count != 0` instead.
- **Testbench race.** My first FSM testbench checked a combinational output in the same time step in which I changed its input, which gave a false FAIL. Fixed by sampling at the falling clock edge (inputs are changed at the falling edge, the design samples at the rising edge).
- **Wrong hand-calculated expectations.** I mis-computed a remainder (60 instead of 65) and an ID in my own directed tests; the golden model disagreed with my hand numbers and exposed it. Lesson: golden model first, hand-written checks second.
- **Test scenario bug.** A leftover resting order from an earlier step used up a slot, so a "16 orders fill the book" test saw only 15 free slots; fixed by making the previous step clear the book exactly.
- **Git.** Branch setup, accepting the invitation, reviewing and merging four pull requests; a shared script name (`run_sim.sh`) could collide, so mine is `run_sim_member4.sh`.
- **Open issues.** Long combinational path bitmap -> FIFO -> memory -> compare in CHECK/EXECUTE (to register or pipeline in Stage 4-5); one order at a time; cancel from the middle of a queue is Stage 3; duplicate order IDs are not checked.

### My work as a team member
Designed and coded the control FSM and the top-level integration, wrote the FSM and integrated testbenches with a golden model, defined the interface assumptions between modules, reviewed and merged the team's pull requests, ran the integrated simulation and updated the block diagram.

---

## G. Likely viva questions

1. **Why separate the FSM from the datapath?** The FSM only chooses the step; the datapath does the work. It makes the FSM testable alone and keeps each module's job small.
2. **Moore or Mealy? Why?** Moore: outputs depend only on the state register, so no glitches and outputs are stable for a full cycle.
3. **Why 3 state bits, and what about illegal states?** 8 states = 3 bits, all codes used, so there is no unused code; the `default` branch still returns to IDLE.
4. **Why async reset?** Matches the team convention `rst_n`; the machine goes to IDLE immediately even without a clock edge (tested).
5. **Walk through the worked example.** S1 sells 180@49. DISCOVER finds best bid 50, CHECK sees 49 <= 50 so EXECUTE trades 100 at 50 (resting price), B1 is used up and removed. Loop: B2 trades 50 at 50; loop: best bid is now 49 (B3), trades 30 at 49; S1 is used up, DONE. B3 stays with 170.
6. **At which price does a trade occur?** The resting order's price (`rd_price`), not the incoming order's limit.
7. **How is time priority achieved?** Per-price FIFO: the head is the oldest order at that price; new orders are pushed at the tail.
8. **How does the top know which book to look at?** `cur_side`: BUY -> ask book (lowest), SELL -> bid book (highest). Muxes select head/nonempty/last.
9. **When is a bitmap bit cleared?** When a resting order is used up and `rd_last` says it was the last order at that price.
10. **Why is the incoming order not stored in memory first?** Most orders trade or reject immediately; only the unmatched remainder needs a slot (saves slots and cycles).
11. **Why one cycle per state, and why is there a CHECK state with no side effects?** It separates "read and compare" from "modify state", so EXECUTE acts on the exact values CHECK approved.
12. **How many cycles per order?** Insert 5, risk reject 2, `3n+2` for n trades filling the order (11 for the worked example).
13. **What happens when the book is full?** After matching, if a remainder remains and `free_count == 0` the order goes to REJECT with code `1000`; trades already done stay valid.
14. **How do you detect a slot leak?** The testbench compares `free_count` to the golden model after every order, and checks it returns to 16 after clearing the book.
15. **Why decide `room_ok` from `free_count`?** `alloc_ok` could depend on `alloc_en` and create a combinational loop.
16. **What does `err_flag` check?** That the resting order read in EXECUTE is valid, on the opposite side, and at the price DISCOVER found; it signals bitmap/queue inconsistency.
17. **What are the limits of this design?** One order at a time, 3 cycles per trade, long combinational path through bitmap -> FIFO -> memory, no cancel yet, no duplicate-ID check.
18. **How did you verify it?** FSM alone (directed + random vs model), then integrated golden-model comparison for directed and 3,300 random orders, plus injected-bug (mutation) runs that the testbench detected.

---

## H. Final checklist (deadline Monday 2:50 PM)

**Tonight**
- [ ] GitHub invitation accepted; `git clone` done; branch `feat-integration` created
- [ ] Files copied to `src/`, `tb/`, `run_sim_member4.sh` at repo root
- [ ] `bash run_sim_member4.sh` shows `MASTER_FSM_TB: PASS`
- [ ] Interface message (section B) sent to Shalin, Saurabhraj, Niket, Ronit
- [ ] Commit pushed to `feat-integration`; pull request opened
- [ ] Teammates' pull requests reviewed and merged into `main`
- [ ] `git pull origin main` into your branch; **integrated run done with the real modules**; if anything FAILs, paste the failing output and the teammates' files into the chat so the integration can be fixed
- [ ] Your own PR merged after the integrated run passes

**Before 2:50 PM Monday**
- [ ] Code screenshots of your 4 files in the shared Google Doc
- [ ] Waveform screenshots W1-W6 with captions; terminal screenshot with PASS lines
- [ ] Updated block diagram inserted with the changes listed in F
- [ ] Your report section pasted and rewritten in your own words, with YOUR measured numbers
- [ ] Section 6 (work by each member) reviewed; whole document exported to one PDF and submitted
- [ ] You can explain every line of `master_fsm.v` and the top without reading
