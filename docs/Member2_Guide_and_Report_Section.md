# Member 2 (Shalin Javaria, 2025csb1257) - Order Storage: guide + report section
Branch: `feat-order-storage` | Files: `src/order_memory.v`, `src/fifo_queue.v`, `src/free_list_allocator.v`
Testbenches: `tb/order_memory_tb.v`, `tb/fifo_queue_tb.v`, `tb/free_list_tb.v`, `tb/order_storage_tb.v`

---------------------------------------------------------------------------------------------------
## 0. What was actually tested (read this first - be honest in the viva)
* Simulator used: **Icarus Verilog 12.0** (`iverilog -g2012`, `vvp`). All four testbenches were run and print **PASS**.
* RTL also compiles in strict Verilog-2005 mode (`iverilog -g2005`) with no warnings.
* **NOT tested:** Vivado (not available to me). The code is plain synthesizable Verilog, so it should work, but you must run it once yourself and tell me/fix if Vivado complains.
* **No real GTKWave/Vivado screenshots exist yet.** I produced the `.vcd` waveform files only; you take the screenshots (section 4c).
* **Bug-injection check (mutation test):** I deliberately broke my RTL 9 ways (e.g. lookup ignoring the valid bit, wrong rd_last, no double-free guard, wrong list pointer on alloc+free). The unit testbenches FAILED on 8 of 9. The 9th ("pop on an empty level not ignored") is not detectable by any test because it is behaviourally identical - that gate is just defensive logic. The integration test alone does not exercise same-cycle push+pop / double-free; the *unit* tests cover those.

Real output of `./run_sim.sh`:
```
ORDER_MEMORY_TB: PASS      (3000 random ops + directed, every slot and lookup compared after every cycle)
FIFO_QUEUE_TB:   PASS      (6000 random cycles, all 64 levels compared after every cycle)
FREE_LIST_TB:    PASS      (5000 random ops + directed)
ORDER_STORAGE_TB: PASS     worked example OK: B1,B2 removed in time order, B3 left with 170
                           stats: inserts=507 full-fills=507 partial-fills=526 lookups=69555 rejected-when-full=1160
```

---------------------------------------------------------------------------------------------------
## 1. Plain-language explanation (for the viva)

**The big picture.** The engine must remember every resting order. Instead of sorting orders, we split the memory job into three small blocks:
1. *order_memory* = the **filing cabinet**: 16 numbered drawers (slots), one order per drawer.
2. *free_list_allocator* = the **receptionist** who knows which drawers are empty and hands out an empty one.
3. *fifo_queue* = the **waiting line** for each price. It does not hold orders, only drawer numbers, in arrival order.

An order's life: allocator gives drawer 7 -> order_memory writes the order into drawer 7 -> fifo_queue for that side/price adds "7" to the back of its line. A trade looks at the front of the line (oldest order at the best price = price-time priority), reads drawer 7. Fully filled: remove 7 from the line, mark drawer 7 invalid, give 7 back to the allocator. Partly filled: just rewrite the quantity in drawer 7.

**order_memory.v** - register array of DEPTH=16 slots with fields id, side, price, qty + a valid bit.
* Read is combinational (address in -> fields out, same cycle).
* Three write ports: full write (`wr_en`, sets valid), qty-only update (`qty_wr_en`, partial fill), invalidate (`inv_en`).
* **ID lookup (CAM-style):** 16 comparators run at the same time, each `valid & (stored_id == lk_id)`. `lk_found` = any hit, `lk_addr` = which slot (lowest if several). Needed for cancel in Stage 3. Invalid slots can never match, so stale IDs are not found.
* Same slot hit by several ports in one cycle: qty update < invalidate < full write (full write wins).

**fifo_queue.v** - for each of the 64 price levels store `head`, `tail` and a `nonempty` bit; for each slot a `nxt` pointer. So a level is a linked list `head -> nxt -> ... -> tail`.
* push: if level empty, head=tail=slot; else `nxt[tail]=slot; tail=slot` (O(1), no shifting).
* pop: if only one entry, level becomes empty; else `head = nxt[head]`.
* `rd_head` = oldest slot, `rd_nonempty`, `rd_last` = "only one order left here" -> the top level uses it to clear the price-bitmap bit when it pops.
* Push and pop in the same cycle work, including on the same level (the one tricky case: popping the last entry while pushing to that same level leaves just the new slot).
* Pop on an empty level is ignored. One `nxt[]` table is enough because a slot is in only one queue at a time. Because BUY and SELL are separate books, Yash should instantiate **two** fifo_queues (one per side) sharing one order_memory.

**free_list_allocator.v** - linked list of free slots. After reset: 0->1->2->...->15, count=16.
* `alloc_slot` always shows the next free slot (the list head), `alloc_ok` = count != 0. Pulse `alloc_en` the same cycle you use `alloc_slot`. If no slot is free, `alloc_ok=0` -> top FSM should REJECT ("book full").
* free: the returned slot becomes the new head (LIFO reuse). Alloc and free in the same cycle both work.
* My extra safety: an *in-use bit* per slot so freeing a slot that is already free (double free) is ignored instead of corrupting the list.

**How it fits Stage 1 architecture:** it is the "Order Memory + FIFO/linked queue + Free List" boxes of Figure 1. Ronit's price_bitmap tells *which price*; my fifo_queue tells *which order at that price*; order_memory gives *its data*.

**Interface notes for Yash (integration):**
* Widths: slot = 4 bits, level (price) = 6 bits, count = 5 bits (0..16).
* Insert in ONE cycle: `alloc_en=1; wr_en=1; wr_addr=alloc_slot; push_en=1; push_slot=alloc_slot; push_level=price` (+ set price_bitmap bit). `order_storage_tb` does exactly this.
* Full fill in ONE cycle: `pop_en=1,pop_level=price; inv_en=1,inv_addr=head; free_en=1,free_slot=head`; clear bitmap bit if `rd_last` was 1 before the pop.
* Partial fill: `qty_wr_en=1, qty_wr_addr=head, qty_wr_data=new_qty`.

---------------------------------------------------------------------------------------------------
## 2. The code
Already in `src/` (heavily commented). Read each file top to bottom once; every line has a comment or is a one-line assignment.

---------------------------------------------------------------------------------------------------
## 3. Testbenches (what each one covers)
| Testbench | Directed / edge cases | Random vs golden model |
|---|---|---|
| order_memory_tb | reset state; id 0 not found in empty memory; write/qty-update/invalidate; stale id misses; fill all 16 slots; overwrite occupied slot; same-cycle write+invalidate, qty+invalidate, write+qty on one slot; different slots same cycle; duplicate-id -> lowest slot; id/qty 0xFFFF, price 0/63, qty 0; async reset mid-use | 3000 random ops; after EVERY cycle all 16 slots read + every valid id looked up |
| fifo_queue_tb | empty after reset; FIFO order; underflow pop; levels 0/31/63 isolation; push+pop on empty level, 1-entry level, 2-entry level, different levels; slot reuse; a level holding all 16 slots; async reset | 6000 random cycles with concurrent push/pop; after EVERY cycle all 64 levels compared (head, nonempty, last) |
| free_list_tb | 16 distinct allocs; alloc when empty ignored; freed slot is next; double free ignored; free of never-used slot ignored; LIFO reuse; alloc+free same cycle; one-slot-left case; async reset | 5000 random ops with periodic drain/fill; checks "offered slot is free", "never offered twice", count |
| order_storage_tb | Stage 1 worked example (B1 100@50, B2 50@50, B3 200@49 -> B1,B2 removed in order, B3 = 170); SELL side | 4000 random inserts/fills/lookups across both sides with ID-based model; full book (1160 rejects); ends by draining to an empty book and checking everything is clean |

Run: `./run_sim.sh` from the repo root (needs Icarus: `sudo apt install iverilog gtkwave`).

---------------------------------------------------------------------------------------------------
## 4. Step-by-step instructions (beginner)

### 4a. Git
Do this on YOUR computer. Put my files in a folder on your PC first (the unzipped `shalin/` folder).
1. **Accept the invitation (once):** open the email "Ronit invited you to collaborate" (or go to https://github.com/RonitBiswal/dld-matching-engine/invitations while logged in) and click **Accept invitation**.
2. Open a terminal (Windows: "Git Bash" or PowerShell; Mac/Linux: Terminal). Check git exists: `git --version`. If not, install from https://git-scm.com. One-time identity:
   ```
   git config --global user.name "Shalin Javaria"
   git config --global user.email "your-github-email@example.com"
   ```
3. Clone and enter the repo:
   ```
   git clone https://github.com/RonitBiswal/dld-matching-engine.git
   cd dld-matching-engine
   ```
   (A login window/browser may pop up: log in with your GitHub account. If it asks for a password in the terminal, use a Personal Access Token, see "permission error" below.)
4. Create and switch to your branch:
   ```
   git checkout -b feat-order-storage
   ```
5. Copy the files in (File Explorer is fine):
   * `order_memory.v`, `fifo_queue.v`, `free_list_allocator.v`  ->  `dld-matching-engine/src/`
   * `order_memory_tb.v`, `fifo_queue_tb.v`, `free_list_tb.v`, `order_storage_tb.v`  ->  `dld-matching-engine/tb/`
   * optional: `run_sim.sh` (repo root), this guide -> `docs/`
   Do NOT touch other people's files.
6. Check, stage, commit, push:
   ```
   git status                      # your files should show in red as "untracked"
   git add .
   git commit -m "Add order_memory, fifo_queue, free_list_allocator and testbenches"
   git push origin feat-order-storage
   ```
   Tip: if you made `.vcd`/`.vvp` files in `sim/`, they are big and not needed; either leave `sim/` out (`git add src tb docs run_sim.sh` instead of `git add .`) or keep only the `.vcd` files.
7. Open GitHub -> the repo page -> yellow banner "feat-order-storage had recent pushes" -> **Compare & pull request** -> title "Member 2: order storage" -> **Create pull request**. Yash merges.

**If something goes wrong**
* *Permission error* (`remote: Permission denied`, `fatal: unable to access ... 403`): you have not accepted the invitation (step 1), or you are logged in with a different GitHub account than the invited one. Fix that, then retry the push. If the terminal asks for a password, GitHub no longer takes your account password: GitHub -> Settings -> Developer settings -> Personal access tokens -> generate one with "repo" scope and paste it as the password.
* *Invitation never arrived / expired:* ask Ronit (Settings -> Collaborators) to re-invite the exact username.
* *"fatal: not a git repository":* you are not inside the `dld-matching-engine` folder; `cd` into it.
* *Push rejected ("non-fast-forward" / "fetch first"):* `git pull --rebase origin feat-order-storage`, then push again.
* *Merge conflict* (only happens if two people edit the same file; you only edit your own files, so it should not): git says `CONFLICT (content): Merge conflict in <file>`. Open that file; find the markers `<<<<<<<`, `=======`, `>>>>>>>`; keep the correct text and delete the three marker lines; then `git add <file>` and `git commit` (or `git rebase --continue`). If unsure, do not guess: ask Yash, and keep a copy of your own file first.
* *Committed on the wrong branch:* `git branch` shows the current branch (star). Make sure it is `feat-order-storage` before step 6.

### 4b. Run the simulation
**Option 1 - Icarus + GTKWave (what I used):**
```
cd dld-matching-engine
iverilog -g2012 -o sim/order_storage.vvp src/*.v tb/order_storage_tb.v
vvp sim/order_storage.vvp          # prints ORDER_STORAGE_TB: PASS
gtkwave sim/order_storage.vcd      # opens waveform viewer
```
(create the `sim` folder first if missing: `mkdir sim`). Same pattern for `order_memory_tb`, `fifo_queue_tb`, `free_list_tb`, or just `./run_sim.sh` (Git Bash).

**Option 2 - Vivado (not tested by me):** keep tb files out of "Design Sources".
1. Create Project -> RTL Project, *Do not specify sources at this time* -> pick any part (e.g. xc7a35tcpg236-1) -> Finish.
2. *Add Sources* -> **Add or create design sources** -> add the 3 files from `src/`. (If Ronit's files are also in `src/`, add only mine, or add all - extra modules are fine.)
3. *Add Sources* -> **Add or create simulation sources** -> add ONE testbench, e.g. `order_storage_tb.v`.
4. In *Sources -> Simulation Sources -> sim_1*, right-click the testbench -> **Set as Top**.
5. *Flow Navigator -> Run Simulation -> Run Behavioral Simulation*. The `.vcd` dumps are harmless; Vivado uses its own waveform.
6. The testbenches finish with `$finish`, but the random part is long: use *Run All* (the "play to end" button), then read the **Tcl Console** for the `..._TB: PASS` line. Note: Vivado's waveform window will show the whole run, including the random part; to screenshot the directed part, type e.g. `restart` then `run 400 ns` in the Tcl console and zoom there (the VCD files avoid this, which is why GTKWave is easier for screenshots).
7. If Vivado complains about `$urandom` with a seed or `$clog2`, tell me the exact message. Both are normally accepted.

### 4c. Waveform screenshots for the report
In GTKWave: left panel -> click `order_storage_tb` -> select signals in the lower-left list -> **Append** (or drag them into the Signals pane). Use **View -> Zoom Fit**, then the zoom buttons or drag a time range. Set the radix of the multi-bit buses to Decimal (select -> right-click -> Data Format -> Decimal).

**Screenshot 1 (best one) - `sim/order_storage.vcd`, ns 0-330** (this tells the whole story). Signals, in this order:
`clk, alloc_en, alloc_slot, free_count, wr_en, wr_addr, wr_id, wr_price, wr_qty, push_b, push_s, push_level, push_slot, pop_b, pop_s, pop_level, inv_en, inv_addr, free_en, qty_wr_en, qty_wr_data, rd_level, head_b, ne_b, last_b`
* 25-90 ns: three inserts (wr_id 101, 102, 103 at 30/50/70 ns). `free_count` goes 16->15->14->13 and `alloc_slot` changes each time; `push_b` pulses and the slot numbers match `wr_addr`.
* 95-130 ns: the two full fills (`pop_b`, `inv_en`, `free_en` at 100 and 120 ns): `free_count` rises 13->14->15 (B1 then B2 removed, in arrival order).
* 140-150 ns: `qty_wr_en` pulse, `qty_wr_data`=170 (B3 partial fill, 200->170).
* 165-220 ns: SELL inserts (104-106) now use `push_s`.  235-310 ns: SELL drain and B3 removed, `free_count` back to 16.
Caption: "Stage 1 worked example on the storage blocks: slots allocated, orders written, FIFO pops in time order, slots reclaimed."

**Screenshot 2 - `sim/order_memory.vcd`, ns 30-110:** `clk, wr_en, wr_addr, wr_id, wr_price, wr_qty, qty_wr_en, qty_wr_data, inv_en, inv_addr, rd_addr, rd_valid, rd_id, rd_qty, lk_id, lk_found, lk_addr`. Moments: write at ~40 ns, qty update at 70 ns, invalidate at 100 ns (`rd_valid` falls, `lk_found` falls for the stale id). Also zoom ~ 880-1100 ns for the same-cycle collision tests.

**Screenshot 3 - `sim/fifo_queue.vcd`, ns 80-600:** `clk, push_en, push_level, push_slot, pop_en, pop_level, rd_level, rd_head, rd_nonempty, rd_last`. Push 1,2,3 on level 5 at 90/170/250 ns, then pops from 330 ns; `rd_head` shows 1 -> 2 -> 3 and `rd_last` rises on the last one. Second zoom ~1100-1300 ns: cycles where `push_en` and `pop_en` are both 1.

**Screenshot 4 - `sim/free_list.vcd`, ns 20-700:** `clk, alloc_en, alloc_slot, alloc_ok, free_en, free_slot, free_count`. Sixteen allocs (30-290 ns): `free_count` 16->0, `alloc_ok` falls; frees from 390 ns; `alloc_slot` shows the freed slot as next.

**Code screenshots:** one per file (3 RTL + the 4 testbenches, or at least the RTL + `order_storage_tb`). Open the file in VS Code, light theme, font size ~14, line numbers on; if a file is longer than one screen take 2 screenshots. Paste under the heading "Member 2 - ..." in the shared Google Doc, with the filename as caption.

---------------------------------------------------------------------------------------------------
## 5. Report section (edit into your own words)

### Member 2 - Order Storage, Queues and Free List (Shalin Javaria, 2025csb1257)

**Initial implementation.** I implemented the three storage blocks of the architecture:
* `order_memory.v`: a 16-slot register file storing id, side, price and quantity with a valid bit; combinational read, three write ports (full write, quantity update, invalidate) and a CAM-style order-ID lookup made of 16 parallel comparators.
* `fifo_queue.v`: a per-price-level linked FIFO of slot numbers (head, tail, next-pointer table) that keeps time priority within a price level. It supports push, pop, same-cycle push+pop and reports head, non-empty and "last entry" so the top level can clear the price bitmap.
* `free_list_allocator.v`: a linked free list of storage slots with allocate, reclaim, a free counter and a double-free guard.
All modules are parameterized (DEPTH/SLOTS, LEVELS, widths) and use the agreed ports, async active-low reset and 16-slot / 64-level configuration.

**Design methodology.** Bottom-up: first the smallest block (free list), then the memory, then the queue; each had its own self-checking testbench with directed edge cases plus randomized tests against a simple software-style model in the testbench, then an integration testbench that uses all three together exactly as the matching engine will (insert, partial fill, full fill, ID lookup, BUY and SELL queues) and replays the Stage 1 worked example. To check that the tests are strong, I injected deliberate bugs into the RTL and confirmed the testbenches fail.

**Simulation / test results** (Icarus Verilog 12):
| Testbench | What it checks | Result |
|---|---|---|
| order_memory_tb | write/read/update/invalidate, same-slot write collisions, ID lookup hit/miss/stale/duplicate, boundary values, async reset, 3000 random ops vs model | PASS |
| fifo_queue_tb | FIFO order, underflow, level isolation, simultaneous push+pop (same and different level), slot reuse, 16-deep level, 6000 random cycles vs model | PASS |
| free_list_tb | exhaustion, reuse, double free, alloc+free same cycle, reset, 5000 random ops vs model | PASS |
| order_storage_tb | all three together: worked example (B1, B2 removed in order, B3 left with 170), 4000 random ops on both sides, full-book rejects (1160), end-state empty | PASS |
(Insert the waveform screenshots here.)

**Problems / challenges encountered** (replace/extend with your real ones - the ones below are what I actually hit while building it):
* Same-cycle push and pop on the same price level was the hardest case: when the popped entry is the only one in the level, the push must start a fresh list instead of appending to a tail that is being removed. I handled it with a `push_after_empty` condition and tested all queue-length cases (0, 1, 2 entries).
* Several write ports hitting one memory slot in the same cycle needed a fixed priority (qty update < invalidate < full write), which I documented and tested.
* Keeping the linked free list correct when allocate and free happen in the same cycle (the freed slot has to point at the list head *after* the allocation); and protecting against double free using an in-use bit.
* The testbench has to predict results without knowing which slot the allocator picks, so the model checks properties (slot was free, never given twice, count correct) instead of exact numbers; in the integration test the model is indexed by order ID.
* Git/tool issues: (write your own - e.g. accepting the invitation, branch setup).
* Known limitation: the queue has only `next` pointers, so removing an order from the *middle* of a queue (cancel) is not supported yet; it needs `prev` pointers (Stage 3).

**My work as a team member.** I designed, coded and verified the order memory with ID lookup, the per-price linked FIFO and the free-list allocator, plus four testbenches, and defined how the top level should drive them (single-cycle insert, full fill, partial fill) so Yash can integrate them with the FSM and Ronit's price bitmap.

---------------------------------------------------------------------------------------------------
## 6. Likely viva questions (short answers)
1. **Why not store the order inside the queue?** The queue only needs to know the ORDER of orders, so it stores slot numbers. Keeping the data in one shared memory means one copy, one place to update quantity or invalidate, and any slot can be reused by any price level.
2. **What is a CAM / how does ID lookup work?** Content-addressable lookup: compare the searched ID with the ID in every slot at once (16 comparators + valid bit), then an encoder gives the slot. One cycle instead of scanning 16 entries.
3. **Why a valid bit in the comparison?** Reset/old data stays in the register after an order is removed; without `valid &` a cancelled order's ID would still be found.
4. **Why a linked list instead of a shifting array for the FIFO?** Push and pop touch only head/tail pointers (constant time) and one `nxt` entry; shifting would move up to 16 entries and could not remove a middle entry cheaply.
5. **Why one `nxt` table for all levels?** A slot is in at most one queue, so its next pointer is unambiguous. Memory = SLOTS pointers rather than LEVELS x SLOTS.
6. **What does `rd_last` do?** Says the head is the only entry at that price. The top level then clears the price-bitmap bit when it pops, so the bitmap and queues stay consistent.
7. **What happens on push+pop to the same level in one cycle?** Pop is applied first (head moves or level empties), then push; if the pop emptied the level, the pushed slot becomes both head and tail.
8. **What happens on pop of an empty level?** Ignored (no underflow).
9. **How does the free list avoid giving the same slot twice?** Each allocation moves the head to its next pointer; an in-use bit marks the slot taken; a double free is ignored because the in-use bit is already 0.
10. **Why is alloc_slot combinational?** So the FSM can allocate and write the order in the same cycle (insert takes one cycle in my storage blocks).
11. **Why LIFO reuse of freed slots?** Simplest hardware: freed slot becomes the new head. Slot number has no effect on priority, since priority comes from queue order, not the slot index.
12. **Reset behaviour?** Asynchronous active-low: all slots invalid, all queues empty, free list full (0..15).
13. **What if the memory is full?** `alloc_ok`=0; the FSM should reject the order ("book full"). My integration test does this 1160 times.
14. **What are the limits?** One cancel from the middle of a queue is not supported yet (needs prev pointers); one operation per port per cycle; DEPTH>=2.
15. **How do you know it works?** Self-checking tests with directed edge cases and random tests against a model, after every cycle full state comparison; I also injected bugs and the tests caught them.
16. **Reading is combinational but writes are clocked - why?** Reads must feed the matching logic in the same cycle (best price -> head slot -> order data); writes happen at the clock edge so state changes are well defined.
17. **Why registers and not block RAM?** The CAM lookup and combinational read need parallel access to all slots; only 16 slots, so registers are fine. A larger design would need RAM + a different lookup (hash/tag).

---------------------------------------------------------------------------------------------------
## 7. Final checklist (due Monday 2:50 PM)
- [ ] Accepted the GitHub invitation
- [ ] Cloned repo, on branch `feat-order-storage` (`git branch` shows a star next to it)
- [ ] 3 files in `src/`, 4 testbenches in `tb/`
- [ ] Ran `./run_sim.sh` (or each testbench) on MY machine and saw 4 x PASS
- [ ] (If you use Vivado) ran Behavioral Simulation once without errors
- [ ] `git add` / `git commit` / `git push origin feat-order-storage` succeeded
- [ ] Pull request opened on GitHub ("Compare & pull request"), Yash told
- [ ] Code screenshots (one per file) pasted in the shared Google Doc
- [ ] 3-4 waveform screenshots pasted with captions
- [ ] Report section 5 pasted into the doc, rewritten in my own words, Git problems added
- [ ] Told Yash: use two fifo_queues (BUY/SELL), same slot/level widths, insert and fill sequences from section 1 "Interface notes"
- [ ] Told the team the draft report text about my part is accurate (see note in chat: queue now supports simultaneous push/pop)
- [ ] Read the viva Q&A once; can explain `push_after_empty`, the CAM, and the free list without looking
