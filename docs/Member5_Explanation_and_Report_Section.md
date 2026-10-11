# Member 5 – Risk Filter & Reference Model (Stage 2)
Roll no. 2025csb1446 · Branch `feat-risk-filter` · Files: `src/risk_filter.v`, `tb/risk_filter_tb.v`, `docs/reference_model.py`

> HONEST STATUS (read first)
> * `reference_model.py` **was run** (19 self-tests PASS) and the 30 hand-written expected values in the testbench were cross-checked against it (0 mismatches).
> * `risk_filter.v` and `risk_filter_tb.v` **have NOT been run in a Verilog simulator** (no Icarus/Vivado in the environment where they were written). They were reviewed by hand only. You must run them (Section 4) and use YOUR real output/waveforms in the report. Fix any compile error and write it under "Problems encountered" – that is a legitimate real problem.
> * Your name: the team documents say "Niket", you typed "Nikait". Use your correct spelling everywhere.

---------------------------------------------------------------------------------------------------
## 1. Plain-language explanation (for the viva)

**Where the risk filter sits.** Stage 1 architecture: Order Input → **Risk Filter** → Order Book → Matching → Trades. The filter is a gate. Before the engine touches the book, it asks three yes/no questions about the incoming order. If any answer is "bad", the order is thrown out (REJECT) and the book is untouched.

**`risk_filter.v` (hardware).** Inputs: `qty`, `price`. Outputs: `ok` and `reason[2:0]`.

| reason bit | meaning | rule |
|---|---|---|
| bit0 | bad quantity | `qty < MIN_QTY` or `qty > MAX_QTY` |
| bit1 | price outside band | `price < PRICE_MIN` or `price > PRICE_MAX` |
| bit2 | notional too large | `qty × price > MAX_NOTIONAL` |

`ok = 1` only when all three bits are 0. Several bits can be 1 together (`101` = bad qty AND notional too big).
* **Combinational** – no clock, no memory; answer appears as soon as inputs settle. Master FSM (Yash) reads it in state VALIDATE.
* **Parallel** – the three checks do not depend on each other, so the hardware is three comparator groups side by side (plus one multiplier), then a small OR gate. That is the "parallel risk filter" promised in the Stage 1 proposal (section 6.9).
* **Key trick:** the multiplier output is `QTY_W + PRICE_W = 22` bits wide. A 16-bit result would wrap around (e.g. 2000×40 = 80000 becomes 14464) and a huge order would wrongly pass. Full width makes overflow impossible.
* Limits are **inclusive** (qty = 1000, price = 63, notional = exactly 50000 are all allowed).
* Default parameters (my choice, tell the team): `MIN_QTY=1, MAX_QTY=1000, PRICE_MIN=1, PRICE_MAX=63, MAX_NOTIONAL=50000`. With these, 1000 × 63 = 63000 > 50000, so the notional check really matters.

**`reference_model.py` (software).** A plain Python version of the whole engine using the same rules (risk check, price-time priority, trade at the resting price, 16 slots). It is the "expected answer" for Stage 3, when the same orders will be fed to the Verilog top level and to this model and the trades compared. In Stage 2 it already has self-tests (worked example from the proposal, FIFO priority, risk rejects, book-full, 5000 random orders with invariant checks), and a `--stream N SEED` mode that prints a random order list plus the events expected.

**`risk_filter_tb.v` (testbench).** Three copies of the filter with different parameters (default / small custom / "all limits open"), directed tests, an exhaustive sweep of every input of the small ones, a sweep of every price × 20 important quantities, 30 000 random vectors, and a golden function written separately from the DUT. Prints PASS/FAIL, dumps a VCD.

---------------------------------------------------------------------------------------------------
## 2. What to tell the team (2 minutes, tonight)
* To **Yash**: instantiate as `risk_filter #(.QTY_W(16),.PRICE_W(6)) u_risk (.qty(in_qty), .price(in_price), .ok(risk_ok), .reason(risk_reason));` Defaults are listed above; `reject_code` can just be `risk_reason`. `REJECT_FULL` (book full) is not a risk-filter code – agree a code for it with him (the Python model reports it as a separate event).
* To **Ronit**: since Yash reviews/merges, tell him which files are in your pull request.

---------------------------------------------------------------------------------------------------
## 3. Git – exact steps (beginner)

**One-time setup (skip if already done)**
```
git config --global user.name  "Your Name"
git config --global user.email "2025csb1446@iitrpr.ac.in"
```
(Use the e-mail linked to your GitHub account.)

**Step 0 – accept the invitation.** Open the invitation e-mail from GitHub → "View invitation" → **Accept**. Or go to https://github.com/RonitBiswal/dld-matching-engine/invitations . Without this, pushing fails.

**Step 1 – clone and enter the folder**
```
git clone https://github.com/RonitBiswal/dld-matching-engine.git
cd dld-matching-engine
```
When asked to log in: GitHub no longer accepts your password in the terminal. Use a *Personal Access Token* (GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate, tick `repo`) as the password, or install GitHub Desktop / run `gh auth login`.

**Step 2 – create YOUR branch**
```
git checkout -b feat-risk-filter
```

**Step 3 – put your files in place** (copy from where you saved the package)
```
src/risk_filter.v
tb/risk_filter_tb.v
docs/reference_model.py
docs/Member5_Explanation_and_Report_Section.md
run_sim.sh            (optional, repo root)
```
Windows File Explorer copy-paste is fine. Do not copy other members' files; don't edit them.

**Step 4 – check, add, commit, push**
```
git status
git add .
git commit -m "Member 5: add risk_filter, testbench and Python reference model"
git push origin feat-risk-filter
```
`git status` should list only your files in red/green. If it lists `.vvp` or big `.vcd` files you don't want, run `git rm --cached <file>` or just don't put them in the repo folder.

**Step 5 – pull request.** Open the repo on GitHub. A yellow banner "feat-risk-filter had recent pushes – **Compare & pull request**" appears; click it. Title: `Member 5: risk filter + reference model`. Base must be `main` (or `master` – whatever the repo's default is), compare = `feat-risk-filter`. Click **Create pull request**. Yash merges. If no banner: **Pull requests → New pull request**, choose the branches yourself.

**If something goes wrong**
| Problem | Fix |
|---|---|
| `Permission denied` / `403` / `repository not found` when pushing | You have not accepted the invitation (Step 0), or you are logged in as another GitHub account. Accept it; if no invitation e-mail exists ask Ronit to add you again (Settings → Collaborators) with your exact GitHub username. Sign out of old credentials (Windows: Credential Manager → remove `git:https://github.com`) and retry. |
| `fatal: could not read Username` / authentication failed | Use the token as password (Step 1) |
| `rejected … (fetch first)` / non-fast-forward | `git pull --rebase origin feat-risk-filter` then push again |
| **Merge conflict** (`CONFLICT (content): Merge conflict in <file>`) | It only happens if two people changed the same file – you should be alone in yours. Open the file; delete the markers `<<<<<<<`, `=======`, `>>>>>>>` keeping the right lines; then `git add <file>`, `git commit -m "Resolve conflict"`, `git push origin feat-risk-filter`. If it is a file that isn't yours, keep THEIR version: `git checkout --theirs <file>` (during a merge) and tell the owner. GitHub's pull-request page also has a "Resolve conflicts" button. |
| `error: pathspec 'feat-risk-filter' did not match` | Run `git checkout -b feat-risk-filter` (with `-b`) only the first time; later use `git checkout feat-risk-filter` |
| Pushed to the wrong branch | `git branch` shows the current branch (star). Switch with `git checkout feat-risk-filter` |

---------------------------------------------------------------------------------------------------
## 4. Running the simulation

### Option A – Vivado
1. Create Project → RTL Project; tick *Do not specify sources at this time*; any part (e.g. xc7a35t) → Finish.
2. **Add Sources → Add or create design sources → Add Files** → select `src/risk_filter.v`. (Do NOT add the testbench here.)
3. **Add Sources → Add or create simulation sources → Add Files** → select `tb/risk_filter_tb.v`.
4. In the *Sources* panel, expand *Simulation Sources → sim_1*, right-click `risk_filter_tb` → **Set as Top**.
5. **Flow Navigator → Run Simulation → Run Behavioral Simulation**.
6. Vivado runs only 1000 ns by default. In the Tcl console type `run all` (or click the "Run All" button). The Tcl console prints the lines `risk_filter_tb: … checks, 0 errors` and `RISK_FILTER_TB: PASS`. (`$finish` ends the run; a popup "Simulation finished" is normal – close it.)
7. If a `risk_filter.vcd` write error appears it is harmless; the Vivado waveform window does not need it.

### Option B – Icarus Verilog + GTKWave (fastest)
Install: Windows – iverilog installer (tick "add to PATH", includes GTKWave); Ubuntu – `sudo apt install iverilog gtkwave`.
From the repo root:
```
mkdir -p sim
cd sim
iverilog -g2012 -o risk_filter.vvp ../src/risk_filter.v ../tb/risk_filter_tb.v
vvp risk_filter.vvp
gtkwave risk_filter.vcd
```
(or `./run_sim.sh`, which also runs the Python model). Expected last lines (the count comes from the code, not from a run I did):
```
risk_filter_tb: 39505 checks, 0 errors
RISK_FILTER_TB: PASS
```
If the number is different or errors > 0, copy the first `FAIL […]` line – it prints qty, price, actual and expected reason – and debug that case.

Python model (no install beyond Python 3): `python3 docs/reference_model.py` → ends with `REFERENCE_MODEL: PASS`.

---------------------------------------------------------------------------------------------------
## 5. Waveform signals and screenshots

**Signals to add** (Vivado: drag from *Objects* panel; GTKWave: select module `risk_filter_tb` in the tree, then the signals, **Append**):
`label` (set radix = **ASCII**), `qa` (radix **Unsigned decimal**), `pa` (Unsigned decimal), `rA` (Binary), `okA`. Optionally `DUT_A.notional` (Unsigned decimal) – it shows the product directly.

**Screenshot A – directed tests (the main one).** Zoom to **40 ns – 340 ns**. In this window each vector lasts 10 ns and `rA` follows `qa/pa` almost instantly. The signal `label` changes about 8 ns *before* each group's first vector (it is set just before the vector is applied). Exact moments to zoom/point at (vector applied at that time):

| time | qty, price | what to show | expected `rA` |
|---|---|---|---|
| 40–70 ns | 100@50 … 180@49 | Stage 1 worked-example orders accepted | 000, `okA`=1 |
| 80 ns | 0 @ 30 | zero quantity rejected | 001 |
| 110 / 120 ns | 1000 / 1001 @ 10 | upper qty boundary | 000 / 001 |
| 130 / 140 ns | 10 @ 0 / 10 @ 1 | price band | 010 / 000 |
| 170 / 180 ns | 1000@50 / 1000@51 | **notional exactly 50000 accepted / 51000 rejected** | 000 / 100 |
| 240 ns | 2000 @ 40 | two reasons at once | 101 |
| 290–310 ns | 2000@40, 4096@16, 65535@63 | **16-bit overflow trap** (add `notional` signal) | 101 each |

Take two shots: one wide (40–340 ns) and one zoomed (160–230 ns) around the notional boundary.

**Screenshot B – exhaustive/random phase.** After the directed part, zoom out to the whole run (Vivado "Zoom Fit", GTKWave "Zoom Fit"). Shows `rA` toggling – proof the sweeps/random ran. Add the label signal so "exhaustive B and C" and "random" are readable. (Optional: also add `rB`, `okB`, `qb`, `pb`.)

**Screenshot C – terminal/Tcl console** with `RISK_FILTER_TB: PASS` and the number of checks (shows the testbench is self-checking). Also a screenshot of `REFERENCE_MODEL: PASS` output.

**Code screenshots (report "Initial implementation")**: one for `risk_filter.v` (whole file, if too long split in 2), one for `risk_filter_tb.v` (first ~60 lines: header, DUT instances, golden function; second shot: directed tests), one for `reference_model.py` (the `risk_check` function + `Engine.submit`). Use a light theme with line numbers; make sure the file name is visible (tab title or a first-line comment). Also one screenshot of the GitHub **pull request page** or `git log --oneline` showing your commit on `feat-risk-filter` (proof of own work).

---------------------------------------------------------------------------------------------------
## 6. My section of the Stage 2 report (edit into your own words)

### 6.1 Initial implementation (Member 5 – Risk Filter & Reference Model)
I implemented the pre-trade risk filter and a software reference model.
* **`src/risk_filter.v`** – a parameterised combinational module. It receives the incoming order's quantity and price and produces `ok` and a 3-bit `reason`. Three checks run in parallel: quantity range (bit0), price band (bit1) and notional = price × quantity ≤ limit (bit2). The product is computed at full width (QTY_W + PRICE_W bits) so it cannot overflow. All limits are module parameters.
* **`tb/risk_filter_tb.v`** – a self-checking testbench.
* **`docs/reference_model.py`** – a Python model of the full order book (price-time priority, trades at the resting price, 16 slots, same risk rules) with self-tests and a random-stream generator for differential checking in Stage 3.

[Paste code screenshots here]

### 6.2 Design methodology
1. Wrote down the rule of each check from the Stage 1 proposal (section 6.9) and the team conventions (reason bits, port names).
2. Chose a purely combinational design: the check needs no memory and must not add a clock cycle to VALIDATE; the three checks are independent so they are naturally parallel.
3. Chose widths: product width = QTY_W + PRICE_W so the multiplication never wraps; comparisons made with the limits as inclusive.
4. Made every limit a parameter so Stage 3/4 can change the limits without editing the logic.
5. Wrote the testbench independently from the design: a golden function with 64-bit integer arithmetic checks the DUT; three DUT instances with different parameters prove the parameters really work.
6. Wrote the Python reference model with the same rules to be the "expected answer" for the integrated design.

### 6.3 Simulation / test results
Fill in the *Result* column from YOUR run. (Python-model rows were run; Verilog rows must come from your own run.)

| Test | What it checks | Expected | Result |
|---|---|---|---|
| Worked example orders (4 vectors) | Stage 1 orders pass the filter | all `ok=1` | *your run* |
| Qty boundaries (0, 1, 999, 1000, 1001) | inclusive limits | 001 only for 0 and 1001 | *your run* |
| Price boundaries (0, 1, 62, 63) | price band | 010 only for 0 | *your run* |
| Notional boundary (1000×50 = 50000 / 1000×51) | exactly-at-limit accepted, one over rejected | 000 / 100 | *your run* |
| Multi-reason cases (e.g. 2000@40) | several bits at once | 101 | *your run* |
| 16-bit overflow trap (2000@40, 4096@16, 65535@63) | full-width product | 101 | *your run* |
| Price sweep, 20 quantities × 64 prices (1280) | whole price range at all boundaries | = golden | *your run* |
| Exhaustive DUT_B and DUT_C (4096 inputs each, other parameters) | parameters work, limits can be disabled | = golden | *your run* |
| Random, 30 000 vectors | general correctness | = golden | *your run* |
| Total | 39 505 checks | 0 errors, `RISK_FILTER_TB: PASS` | *your run* |
| `reference_model.py` self-tests (19) | worked example → trades (50,100),(50,50),(49,30), B3 left with 170; trade at resting price; FIFO; 7 risk cases; 16-slot full and slot reuse; 5000 random orders keep invariants | all pass | **PASS (run)** |

[Paste waveform screenshots A and B and console screenshot C here]

Observation to write: the output `reason` changes in the same time-step as the inputs (no clock needed), `ok` is exactly `reason == 000`, and the trap vectors are rejected because the product is wider than 16 bits.

### 6.4 Problems / challenges encountered (keep only the ones that really happened to you; examples below are real design issues from this work)
* **Overflow of the notional product.** A 16-bit product would wrap (2000 × 40 = 80000 → 14464) and let a too-large order through. Solved by making the product 22 bits wide, and added directed tests that would fail with a narrow product.
* **Boundary rules (inclusive vs exclusive).** Decided that a notional of exactly MAX_NOTIONAL is accepted; the testbench checks 50000 accepted and 51000 rejected.
* **Which parameter values to use.** Stage 1 gave no numbers; I chose qty 1..1000, price 1..63, notional ≤ 50000 and told the integration owner so the top-level tests agree.
* **Independent checking.** Making the golden model independent of the DUT (64-bit integer arithmetic) so the testbench does not just copy the DUT's logic.
* **Git / tool issues** – add yours here (invitation not accepted, token for push, a syntax error you fixed, etc.).
* **Open issues:** a book-full reject is not a risk-filter reason (needs its own code in the FSM); limits are fixed at compile time (could be made runtime-configurable); the Verilog was verified by testbench only, not by synthesis timing yet.

### 6.5 My work as a team member (brief)
Member 5 (2025csb1446): designed and coded the parallel risk filter (`risk_filter.v`) and its self-checking testbench, wrote the Python reference model (`docs/reference_model.py`) that will be used for differential testing in Stage 3, ran/recorded the simulations, and pushed everything on branch `feat-risk-filter` for review and merge by Yash. I did not write other members' modules.

---------------------------------------------------------------------------------------------------
## 7. Likely viva questions and short answers
1. **What does your module do?** Checks an incoming order's quantity, price and price×quantity against limits and says OK or gives a reason code, before the order reaches the book.
2. **Why combinational, not clocked?** The decision depends only on current inputs, and a register would cost an extra cycle in VALIDATE. The FSM already registers the order.
3. **What "parallel" means here?** The three checks do not depend on each other, so they are separate hardware evaluated simultaneously; delay is the slowest one (the multiplier + compare), not the sum.
4. **Why is `reason` 3 bits and `ok` separate?** One bit per failed check so several can be reported together; `ok` = NOR of them (reason == 0), convenient for the FSM branch.
5. **Why must the product be 22 bits?** The product of a 16-bit and a 6-bit number needs up to 22 bits; a narrower result wraps, e.g. 2000 × 40 → 14464, and would wrongly pass.
6. **Is the limit inclusive?** Yes: qty = MAX_QTY, price = PRICE_MIN/MAX and notional = MAX_NOTIONAL are accepted.
7. **How would you change the limits?** Override the parameters when instantiating; no logic changes.
8. **What if MIN_QTY = 0?** Then zero quantity is allowed (DUT_C in my testbench shows all limits open).
9. **What about synthesis?** `*` on two unsigned vectors becomes a multiplier (DSP slice or LUTs); the compares are magnitude comparators. For a constant price band the tool simplifies them.
10. **How do you test it?** Directed boundary tests, exhaustive for small widths, full price sweep, 30 000 random vectors; every result compared with an independent golden function; self-checking PASS/FAIL.
11. **Why three DUT instances?** To prove parameters work and that the filter is not only correct for one set of numbers.
12. **What is the reference model for?** It defines the expected behaviour of the whole engine in software; in Stage 3 the same orders go to the Verilog top level and the model and the trades are compared.
13. **State the matching rules in the model.** Best price first, oldest first at a price; trade quantity = min; trade at the resting order's price; remainder rests; filled orders freed; 16 slots.
14. **How does the model check itself?** Self-tests (worked example, FIFO, risk, full book) and invariants on 5000 random orders: best bid < best ask, no zero-quantity resting order, unique IDs, quantity conserved.
15. **What did you not test?** Timing/synthesis results; integration with Yash's FSM (to be done when merged).

---------------------------------------------------------------------------------------------------
## 8. Final checklist (deadline: Monday 2:50 PM)
- [ ] Invitation accepted; `git clone` done; on branch `feat-risk-filter` (`git branch` shows `*`)
- [ ] Files in place: `src/risk_filter.v`, `tb/risk_filter_tb.v`, `docs/reference_model.py`, this document in `docs/`
- [ ] Simulation run **by me**; `RISK_FILTER_TB: PASS` and `REFERENCE_MODEL: PASS` seen; if not, fixed and noted under problems
- [ ] `git status` → `git add .` → `git commit` → `git push origin feat-risk-filter` succeeded
- [ ] Pull request opened on GitHub (Compare & pull request); Yash told, plus the default limits message
- [ ] Screenshots taken: code (3 files), waveform A (40–340 ns), waveform B (full run), console PASS, PR/commit page
- [ ] Pasted into the shared Google Doc: screenshots + sections 6.1–6.5 in my own words, with my real results table
- [ ] Name and roll number correct (2025csb1446) on my part
- [ ] Re-read the viva answers (Section 7) once; be able to explain every line of `risk_filter.v`
- [ ] Final check of the shared doc before 2:50 PM – leave margin; Google Doc → File → Download → PDF if the team needs it
