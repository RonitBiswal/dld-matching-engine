import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
blank_layout = prs.slide_layouts[6]

# Color Palette: Clean Student Theme
C_NAVY   = RGBColor(0x1A, 0x36, 0x5D)
C_BLUE   = RGBColor(0x2B, 0x6C, 0xB0)
C_DARK   = RGBColor(0x2D, 0x37, 0x48)
C_MUTED  = RGBColor(0x71, 0x80, 0x96)
C_LIGHT  = RGBColor(0xF7, 0xFA, 0xFC)
C_WHITE  = RGBColor(0xFF, 0xFF, 0xFF)
C_GREEN  = RGBColor(0x27, 0x67, 0x49)

def add_header(slide, title_text, category="DLD Hardware Project | Group 15"):
    # Header box
    tb = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.7), Inches(1.1))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
    
    p0 = tf.paragraphs[0]
    p0.text = category.upper()
    p0.font.name = "Calibri"
    p0.font.size = Pt(11)
    p0.font.bold = True
    p0.font.color.rgb = C_BLUE
    p0.space_after = Pt(2)
    
    p1 = tf.add_paragraph()
    p1.text = title_text
    p1.font.name = "Calibri"
    p1.font.size = Pt(24)
    p1.font.bold = True
    p1.font.color.rgb = C_NAVY

# -----------------------------------------------------------------------------
# SLIDE 1: Title Slide
# -----------------------------------------------------------------------------
s1 = prs.slides.add_slide(blank_layout)

# Background accent
bg = s1.shapes.add_shape(1, Inches(0), Inches(0), Inches(13.333), Inches(7.5))
bg.fill.solid()
bg.fill.fore_color.rgb = C_LIGHT
bg.line.fill.background()

tb = s1.shapes.add_textbox(Inches(1.0), Inches(1.2), Inches(11.3), Inches(2.2))
tf = tb.text_frame
tf.word_wrap = True

p_sub = tf.paragraphs[0]
p_sub.text = "DIGITAL LOGIC DESIGN (DLD) HARDWARE PROJECT"
p_sub.font.name = "Calibri"
p_sub.font.size = Pt(13)
p_sub.font.bold = True
p_sub.font.color.rgb = C_BLUE
p_sub.space_after = Pt(6)

p_main = tf.add_paragraph()
p_main.text = "Hardware Limit Order Book &\nParallel Matching Engine in Verilog RTL"
p_main.font.name = "Calibri"
p_main.font.size = Pt(36)
p_main.font.bold = True
p_main.font.color.rgb = C_NAVY
p_main.space_after = Pt(10)

p_desc = tf.add_paragraph()
p_desc.text = "Synthesizable Clocked Architecture for Sub-50ns Deterministic Price-Time Order Matching"
p_desc.font.name = "Calibri"
p_desc.font.size = Pt(16)
p_desc.font.color.rgb = C_DARK

# Student Details Box
tb_team = s1.shapes.add_textbox(Inches(1.0), Inches(4.3), Inches(11.3), Inches(2.5))
tf_team = tb_team.text_frame
tf_team.word_wrap = True

pt0 = tf_team.paragraphs[0]
pt0.text = "Project Team Members & Roll Numbers:"
pt0.font.name = "Calibri"
pt0.font.size = Pt(13)
pt0.font.bold = True
pt0.font.color.rgb = C_NAVY
pt0.space_after = Pt(6)

members = [
    ("Member 1 (Presenter): Ronit Biswal", "2025csb1511", "Price Discovery & Priority Encoding"),
    ("Member 2: Shalin Javaria", "2025csb1257", "Order Storage, Queues & Allocator"),
    ("Member 3: Saurabhraj", "2025csb1256", "Matching Datapath & Arithmetic"),
    ("Member 4: Yash Kumar", "2025csb1268", "Master Control FSM & Top Integration"),
    ("Member 5: Niket", "2025csb1446", "Pre-Trade Risk Filter & Golden Model")
]

for name, roll, role in members:
    pm = tf_team.add_paragraph()
    pm.text = f"•  {name} ({roll})  —  {role}"
    pm.font.name = "Calibri"
    pm.font.size = Pt(11)
    pm.font.color.rgb = C_DARK
    pm.space_after = Pt(2)

# -----------------------------------------------------------------------------
# SLIDE 2: Project Motivation & Why Hardware?
# -----------------------------------------------------------------------------
s2 = prs.slides.add_slide(blank_layout)
add_header(s2, "Motivation: Why Build a Matching Engine in Hardware?")

# Left Column: Software Problems
tb_left = s2.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.6), Inches(5.0))
tf_left = tb_left.text_frame
tf_left.word_wrap = True

p = tf_left.paragraphs[0]
p.text = "Traditional Software Order Books"
p.font.name = "Calibri"
p.font.size = Pt(18)
p.font.bold = True
p.font.color.rgb = RGBColor(0x9B, 0x2C, 0x2C)
p.space_after = Pt(10)

sw_points = [
    ("Dynamic Heap / Tree Structures: ", "Software implementations use red-black trees, skiplists, or heaps in CPU memory."),
    ("CPU Cache Misses & Pointer Chasing: ", "Traversing pointers across large order books causes frequent L2/L3 cache misses."),
    ("OS Thread Preemption & Jitter: ", "Variable execution delay ranging from 1 to 15 microseconds, causing unpredictable trading latency.")
]
for t, d in sw_points:
    p = tf_left.add_paragraph()
    r1 = p.add_run()
    r1.text = t
    r1.font.bold = True
    r1.font.size = Pt(13)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = d
    r2.font.size = Pt(12)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(10)

# Right Column: Our Hardware Solution
tb_right = s2.shapes.add_textbox(Inches(6.8), Inches(1.8), Inches(5.7), Inches(5.0))
tf_right = tb_right.text_frame
tf_right.word_wrap = True

p = tf_right.paragraphs[0]
p.text = "Our Verilog RTL Hardware Design"
p.font.name = "Calibri"
p.font.size = Pt(18)
p.font.bold = True
p.font.color.rgb = C_GREEN
p.space_after = Pt(10)

hw_points = [
    ("Dedicated On-Chip Registers: ", "64-bit occupancy bitmaps and 16-slot order memory reside directly in flip-flops."),
    ("1-Cycle Best Price Discovery: ", "8x8 parallel hierarchical priority encoder extracts best bid/ask in 1 clock cycle (O(1))."),
    ("Deterministic Clocked Latency: ", "No cache misses, no OS overhead. Execution takes exactly 5 clock cycles (50ns at 100 MHz).")
]
for t, d in hw_points:
    p = tf_right.add_paragraph()
    r1 = p.add_run()
    r1.text = t
    r1.font.bold = True
    r1.font.size = Pt(13)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = d
    r2.font.size = Pt(12)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(10)

# -----------------------------------------------------------------------------
# SLIDE 3: System Architecture
# -----------------------------------------------------------------------------
s3 = prs.slides.add_slide(blank_layout)
add_header(s3, "Top-Level Hardware Architecture & Dataflow")

arch_path = "C:/Users/ronit/dld-matching-engine/docs/images/architecture_diagram.png"
if os.path.exists(arch_path):
    s3.shapes.add_picture(arch_path, Inches(0.8), Inches(1.8), width=Inches(7.2))

tb_arch = s3.shapes.add_textbox(Inches(8.3), Inches(1.8), Inches(4.2), Inches(5.0))
tf_arch = tb_arch.text_frame
tf_arch.word_wrap = True

p = tf_arch.paragraphs[0]
p.text = "Subsystem Coordination:"
p.font.name = "Calibri"
p.font.size = Pt(16)
p.font.bold = True
p.font.color.rgb = C_NAVY
p.space_after = Pt(8)

blocks = [
    ("1. Risk Filter: ", "Checks price bands, quantities, and 22-bit notional limits in 0 cycles."),
    ("2. Price Discovery: ", "64-bit Bid/Ask bitmaps find best active prices in 1 cycle."),
    ("3. Order Storage: ", "16-slot memory, per-price FIFO linked-lists, and LIFO slot allocator."),
    ("4. Datapath Arithmetic: ", "Checks price crossing and calculates min(in_qty, rest_qty)."),
    ("5. Master Moore FSM: ", "8-state controller generating glitch-free registered control pulses.")
]
for b, desc in blocks:
    p = tf_arch.add_paragraph()
    r1 = p.add_run()
    r1.text = b
    r1.font.bold = True
    r1.font.size = Pt(12)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = desc
    r2.font.size = Pt(11)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(6)

# -----------------------------------------------------------------------------
# SLIDE 4: Member 1 (Ronit Biswal) - Price Discovery
# -----------------------------------------------------------------------------
s4 = prs.slides.add_slide(blank_layout)
add_header(s4, "Member 1 (Ronit Biswal): Price Discovery & Priority Encoding", 
           "Subsystem Deep Dive | Member 1")

tb_m1 = s4.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(11.7), Inches(5.2))
tf_m1 = tb_m1.text_frame
tf_m1.word_wrap = True

m1_bullets = [
    ("Dual 64-Bit Occupancy Bitmaps (price_bitmap.v): ", 
     "Each bit represents one discrete price tick (ticks 0 to 63). Bit is set to 1 when an order arrives; cleared to 0 when that price level empties."),
    ("8x8 Hierarchical Priority Encoder (priority_encoder.v): ", 
     "Partitions 64 price ticks into eight 8-bit groups evaluated in parallel by local priority encoders. A global 8-bit encoder selects the highest active group. Achieves 1 clock cycle (O(1)) price discovery."),
    ("The Bit-Reversal Technique for Best Ask: ", 
     "Best Bid is the highest set bit, while Best Ask is the lowest set bit. Rather than building a second 64-bit encoder tree, we invert the bit-vector wire: rev[k] = bm[63-k]. Finding the highest bit of rev yields the lowest ask via (63 - rev_idx), saving over 40% FPGA gates."),
    ("Sequential Scan Baseline vs Hierarchical Encoder: ", 
     "In comparator_search.v, sequential scanning took 14 to 64 clock cycles. Our 8x8 hierarchical design achieves a 64x speedup in hardware.")
]

for i, (head, body) in enumerate(m1_bullets):
    p = tf_m1.paragraphs[0] if i == 0 else tf_m1.add_paragraph()
    r1 = p.add_run()
    r1.text = head
    r1.font.name = "Calibri"
    r1.font.size = Pt(15)
    r1.font.bold = True
    r1.font.color.rgb = C_BLUE
    
    r2 = p.add_run()
    r2.text = body
    r2.font.name = "Calibri"
    r2.font.size = Pt(13)
    r2.font.color.rgb = C_DARK
    p.space_after = Pt(12)

# -----------------------------------------------------------------------------
# SLIDE 5: Member 2 (Shalin) & Member 3 (Saurabhraj)
# -----------------------------------------------------------------------------
s5 = prs.slides.add_slide(blank_layout)
add_header(s5, "Storage, FIFO Queues & Matching Datapath", 
           "Subsystems Deep Dive | Members 2 & 3")

# Left Column: Member 2
tb_m2 = s5.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.6), Inches(5.0))
tf_m2 = tb_m2.text_frame
tf_m2.word_wrap = True

p = tf_m2.paragraphs[0]
p.text = "Member 2: Order Storage (Shalin)"
p.font.name = "Calibri"
p.font.size = Pt(17)
p.font.bold = True
p.font.color.rgb = C_NAVY
p.space_after = Pt(8)

m2_pts = [
    ("order_memory.v: ", "16-slot multi-field register array storing {id, side, price, qty, valid}. Features 16-way associative CAM search for 1-cycle order cancellation."),
    ("fifo_queue.v: ", "Shared linked-list pointer architecture. Each of the 64 levels maintains 4-bit head and tail pointers into a shared 16-entry next pointer table, saving 75% memory logic."),
    ("free_list_allocator.v: ", "LIFO slot allocation stack with double-free protection guard (in_use bitmask).")
]
for t, d in m2_pts:
    p = tf_m2.add_paragraph()
    r1 = p.add_run()
    r1.text = t
    r1.font.bold = True
    r1.font.size = Pt(12)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = d
    r2.font.size = Pt(11)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(6)

# Right Column: Member 3
tb_m3 = s5.shapes.add_textbox(Inches(6.8), Inches(1.8), Inches(5.7), Inches(5.0))
tf_m3 = tb_m3.text_frame
tf_m3.word_wrap = True

p = tf_m3.paragraphs[0]
p.text = "Member 3: Datapath & Arithmetic (Saurabhraj)"
p.font.name = "Calibri"
p.font.size = Pt(17)
p.font.bold = True
p.font.color.rgb = C_NAVY
p.space_after = Pt(8)

m3_pts = [
    ("compatibility_logic.v: ", "Combinational price crossing evaluation: BUY matches if Price_in >= Price_rest; SELL matches if Price_in <= Price_rest. Inhibits matching if opposite book is empty."),
    ("quantity_arithmetic.v: ", "Computes trade execution volume: trade_qty = min(in_qty, rest_qty)."),
    ("Underflow Immunity: ", "Remaining residual quantities: in_rem = in_qty - trade_qty and rest_rem = rest_qty - trade_qty. Underflow is mathematically impossible since trade_qty is bounded by the minimum.")
]
for t, d in m3_pts:
    p = tf_m3.add_paragraph()
    r1 = p.add_run()
    r1.text = t
    r1.font.bold = True
    r1.font.size = Pt(12)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = d
    r2.font.size = Pt(11)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(6)

# -----------------------------------------------------------------------------
# SLIDE 6: Member 4 (Yash) & Member 5 (Niket)
# -----------------------------------------------------------------------------
s6 = prs.slides.add_slide(blank_layout)
add_header(s6, "Master Control FSM & Pre-Trade Risk Filter", 
           "Subsystems Deep Dive | Members 4 & 5")

# Left: Member 4
tb_m4 = s6.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.6), Inches(5.0))
tf_m4 = tb_m4.text_frame
tf_m4.word_wrap = True

p = tf_m4.paragraphs[0]
p.text = "Member 4: Control FSM (Yash)"
p.font.name = "Calibri"
p.font.size = Pt(17)
p.font.bold = True
p.font.color.rgb = C_NAVY
p.space_after = Pt(8)

m4_pts = [
    ("8-State Moore Sequencer: ", "IDLE, VALIDATE, DISCOVER, CHECK, EXECUTE, INSERT, DONE, REJECT."),
    ("Glitch-Free Output Decoding: ", "All control strobes (wr_en, pop_queue) are decoded strictly from registered state, preventing combinational glitches."),
    ("Multi-Level Sweeping: ", "Loops between EXECUTE and DISCOVER if remaining incoming quantity exists, sweeping multiple resting price levels.")
]
for t, d in m4_pts:
    p = tf_m4.add_paragraph()
    r1 = p.add_run()
    r1.text = t
    r1.font.bold = True
    r1.font.size = Pt(12)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = d
    r2.font.size = Pt(11)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(6)

# Right: Member 5
tb_m5 = s6.shapes.add_textbox(Inches(6.8), Inches(1.8), Inches(5.7), Inches(5.0))
tf_m5 = tb_m5.text_frame
tf_m5.word_wrap = True

p = tf_m5.paragraphs[0]
p.text = "Member 5: Risk Filter & Modeling (Niket)"
p.font.name = "Calibri"
p.font.size = Pt(17)
p.font.bold = True
p.font.color.rgb = C_NAVY
p.space_after = Pt(8)

m5_pts = [
    ("Pre-Trade Risk Filter (0 Cycles): ", "Evaluates order sanity combinationally before memory is touched. Rejects invalid quantities (qty=0) and sentinel price ticks (0, 63)."),
    ("22-Bit Multiplier Sizing: ", "Computes price * qty without 16-bit integer wrap-around, trapping oversized notional volume violations."),
    ("Python Golden Reference Model: ", "Independent software model (reference_model.py) used for differential cycle-by-cycle testing against Verilog RTL.")
]
for t, d in m5_pts:
    p = tf_m5.add_paragraph()
    r1 = p.add_run()
    r1.text = t
    r1.font.bold = True
    r1.font.size = Pt(12)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = d
    r2.font.size = Pt(11)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(6)

# -----------------------------------------------------------------------------
# SLIDE 7: RTL Timing Waveform & Execution Latency
# -----------------------------------------------------------------------------
s7 = prs.slides.add_slide(blank_layout)
add_header(s7, "RTL Simulation Waveform & Clock-by-Clock Latency")

wf_path = "C:/Users/ronit/dld-matching-engine/docs/images/waveform_diagram.png"
if os.path.exists(wf_path):
    s7.shapes.add_picture(wf_path, Inches(0.8), Inches(1.8), width=Inches(7.2))

tb_wf = s7.shapes.add_textbox(Inches(8.3), Inches(1.8), Inches(4.2), Inches(5.0))
tf_wf = tb_wf.text_frame
tf_wf.word_wrap = True

p = tf_wf.paragraphs[0]
p.text = "Execution Latency Breakdown:"
p.font.name = "Calibri"
p.font.size = Pt(16)
p.font.bold = True
p.font.color.rgb = C_NAVY
p.space_after = Pt(8)

cycles = [
    ("Pre-Trade Risk Rejection: ", "2 clock cycles (20ns at 100MHz)."),
    ("Resting Order Insertion: ", "5 clock cycles (50ns at 100MHz)."),
    ("Single Trade Match: ", "5 clock cycles (50ns at 100MHz)."),
    ("Multi-Level Sweeps: ", "3M + 2 clock cycles for M matched orders (e.g., 3 levels in 11 cycles = 110ns).")
]
for c_title, c_desc in cycles:
    p = tf_wf.add_paragraph()
    r1 = p.add_run()
    r1.text = c_title
    r1.font.bold = True
    r1.font.size = Pt(12)
    r1.font.color.rgb = C_DARK
    r2 = p.add_run()
    r2.text = c_desc
    r2.font.size = Pt(11)
    r2.font.color.rgb = C_MUTED
    p.space_after = Pt(6)

# -----------------------------------------------------------------------------
# SLIDE 8: Verification & Simulation Results
# -----------------------------------------------------------------------------
s8 = prs.slides.add_slide(blank_layout)
add_header(s8, "Verification Framework & Simulation Results")

tb_v = s8.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(11.7), Inches(5.2))
tf_v = tb_v.text_frame
tf_v.word_wrap = True

v_pts = [
    ("12 Comprehensive Self-Checking Testbenches: ", 
     "All 11 submodules and top-level engine verified in Icarus Verilog with automated failure assertion counters. Zero failures detected."),
    ("107,000+ Automated Assertion Checks Passed: ", 
     "Rigorous testing covering read-after-write hazards, same-cycle set/clear collision, slot exhaustion, and mid-transaction asynchronous reset recovery."),
    ("Golden Model Differential Testing: ", 
     "In matching_engine_top_tb.v, 3,406 randomized orders generating 1,669 trades were verified cycle-by-cycle against our Python golden model with exactly 0 mismatches."),
    ("Demonstration Testbench (matching_engine_demo_tb.v): ", 
     "Automated verification of 4 realistic market scenarios: passive order placement, aggressive multi-level price-time sweeps, risk filter rejections, and CAM order cancellations.")
]

for i, (head, body) in enumerate(v_pts):
    p = tf_v.paragraphs[0] if i == 0 else tf_v.add_paragraph()
    r1 = p.add_run()
    r1.text = head
    r1.font.name = "Calibri"
    r1.font.size = Pt(15)
    r1.font.bold = True
    r1.font.color.rgb = C_BLUE
    
    r2 = p.add_run()
    r2.text = body
    r2.font.name = "Calibri"
    r2.font.size = Pt(13)
    r2.font.color.rgb = C_DARK
    p.space_after = Pt(12)

# -----------------------------------------------------------------------------
# SLIDE 9: Project Conclusion & Performance Summary
# -----------------------------------------------------------------------------
s9 = prs.slides.add_slide(blank_layout)
add_header(s9, "Summary & Key Takeaways", "Conclusion | Stage 3 Final")

tb_c = s9.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(11.7), Inches(5.2))
tf_c = tb_c.text_frame
tf_c.word_wrap = True

conc = [
    ("Fully Synthesizable Verilog RTL: ", 
     "All 11 modules written strictly using synthesizable IEEE 1364-2001 digital constructs."),
    ("Extreme Throughput: ", 
     "At a conservative 100 MHz clock frequency, achieves up to 20,000,000 order operations per second."),
    ("Compact FPGA Resource Footprint: ", 
     "Consumes under 1,500 flip-flops and 3,200 LUTs, easily fitting on standard educational FPGA boards (Artix-7 / Cyclone IV)."),
    ("Readiness for Viva & Submission: ", 
     "Complete codebase, live demonstration suite, interactive HTML visualizer, and technical report ready for evaluation.")
]

for i, (head, body) in enumerate(conc):
    p = tf_c.paragraphs[0] if i == 0 else tf_c.add_paragraph()
    r1 = p.add_run()
    r1.text = head
    r1.font.name = "Calibri"
    r1.font.size = Pt(15)
    r1.font.bold = True
    r1.font.color.rgb = C_GREEN
    
    r2 = p.add_run()
    r2.text = body
    r2.font.name = "Calibri"
    r2.font.size = Pt(13)
    r2.font.color.rgb = C_DARK
    p.space_after = Pt(12)

out_pptx = "C:/Users/ronit/dld-matching-engine/docs/DLD_Matching_Engine_Presentation.pptx"
prs.save(out_pptx)
print("PPTX generated successfully at", out_pptx)
