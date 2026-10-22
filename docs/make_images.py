import os
from PIL import Image, ImageDraw, ImageFont

img_dir = "C:/Users/ronit/dld-matching-engine/docs/images"
os.makedirs(img_dir, exist_ok=True)

def get_font(size, bold=False):
    # Try common Windows fonts, fallback to default
    font_names = ["segoeui.ttf", "arial.ttf", "calibri.ttf"]
    if bold:
        font_names = ["segoeuib.ttf", "arialbd.ttf", "calibrib.ttf"]
    
    for name in font_names:
        path = os.path.join("C:/Windows/Fonts", name)
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()

def get_mono_font(size):
    font_names = ["consola.ttf", "cour.ttf", "lucon.ttf"]
    for name in font_names:
        path = os.path.join("C:/Windows/Fonts", name)
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                pass
    return ImageFont.load_default()

# -------------------------------------------------------------
# 1. System Architecture Diagram (PNG)
# -------------------------------------------------------------
w, h = 1200, 720
img = Image.new("RGB", (w, h), "#ffffff")
d = ImageDraw.Draw(img)

# Title Header
d.rectangle([30, 20, w-30, 80], fill="#ebf8ff", outline="#3182ce", width=2)
d.text((w//2, 50), "Hardware Limit Order Book: Top-Level RTL Architecture & Dataflow", 
       font=get_font(22, bold=True), fill="#2b6cb0", anchor="mm")

# Input Box
d.rectangle([40, 120, 260, 230], fill="#edf2f7", outline="#4a5568", width=2)
d.text((150, 145), "Order Input Bus", font=get_font(18, bold=True), fill="#2d3748", anchor="mm")
d.text((150, 175), "order_valid, order_id", font=get_mono_font(14), fill="#4a5568", anchor="mm")
d.text((150, 200), "side, price[5:0], qty[15:0]", font=get_mono_font(14), fill="#4a5568", anchor="mm")

# Member 5: Risk Filter Box
d.rectangle([320, 120, 560, 230], fill="#fffaf0", outline="#dd6b20", width=2)
d.text((440, 145), "risk_filter (Member 5)", font=get_font(18, bold=True), fill="#9c4221", anchor="mm")
d.text((440, 175), "Quantity Bounds (1 to 65k)", font=get_font(14), fill="#7b341e", anchor="mm")
d.text((440, 195), "Price Band (Ticks 1-62)", font=get_font(14), fill="#7b341e", anchor="mm")
d.text((440, 215), "22-bit Notional (Px * Qty)", font=get_font(14), fill="#7b341e", anchor="mm")

# Member 4: Master FSM Box
d.rectangle([620, 120, 1150, 230], fill="#faf5ff", outline="#805ad5", width=2)
d.text((885, 145), "master_fsm Controller (Member 4)", font=get_font(20, bold=True), fill="#553c9a", anchor="mm")
d.text((885, 175), "8-State Moore Machine (IDLE, VAL, DISC, CHECK, EXEC, INSERT, DONE, REJ)", font=get_font(14), fill="#44337a", anchor="mm")
d.text((885, 200), "Glitch-Free Registered Control Strobes to All Blocks", font=get_font(14), fill="#44337a", anchor="mm")

# Middle Subsystems
# Member 1: Price Discovery
d.rectangle([40, 300, 370, 470], fill="#ebf8ff", outline="#3182ce", width=2)
d.text((205, 330), "Price Discovery (Member 1)", font=get_font(18, bold=True), fill="#2b6cb0", anchor="mm")
d.text((205, 365), "Dual 64-bit Bitmaps (Bid & Ask)", font=get_font(15), fill="#2c5282", anchor="mm")
d.text((205, 395), "8x8 Hierarchical Priority Encoder", font=get_font(15, bold=True), fill="#2b6cb0", anchor="mm")
d.text((205, 425), "Bit-Reversed Vector for Best Ask", font=get_font(14), fill="#2c5282", anchor="mm")
d.text((205, 450), "Latency: 1 Clock Cycle (O(1))", font=get_font(14, bold=True), fill="#22543d", anchor="mm")

# Member 2: Storage Subsystem
d.rectangle([420, 300, 770, 470], fill="#f0fff4", outline="#38a169", width=2)
d.text((595, 330), "Storage Subsystem (Member 2)", font=get_font(18, bold=True), fill="#22543d", anchor="mm")
d.text((595, 365), "order_memory (16 Slots + CAM ID Match)", font=get_font(14), fill="#276749", anchor="mm")
d.text((595, 395), "fifo_queue (Head/Tail Pointers per Tick)", font=get_font(14), fill="#276749", anchor="mm")
d.text((595, 425), "free_list_allocator (LIFO Stack)", font=get_font(14), fill="#276749", anchor="mm")
d.text((595, 450), "Double-Free Hardware Safety Guard", font=get_font(14, bold=True), fill="#22543d", anchor="mm")

# Member 3: Matching Datapath
d.rectangle([820, 300, 1150, 470], fill="#fff5f5", outline="#e53e3e", width=2)
d.text((985, 330), "Matching Datapath (Member 3)", font=get_font(18, bold=True), fill="#9b2c2c", anchor="mm")
d.text((985, 365), "compatibility_logic (Price Cross Check)", font=get_font(14), fill="#742a2a", anchor="mm")
d.text((985, 395), "quantity_arithmetic: min(In, Rest)", font=get_font(14, bold=True), fill="#9b2c2c", anchor="mm")
d.text((985, 425), "Residuals: in_rem & rest_rem", font=get_font(14), fill="#742a2a", anchor="mm")
d.text((985, 450), "Zero-Underflow Bounded Logic", font=get_font(14, bold=True), fill="#22543d", anchor="mm")

# Bottom: Registered Outputs
d.rectangle([300, 560, 900, 680], fill="#f7fafc", outline="#2d3748", width=2)
d.text((600, 590), "Registered Trade Execution & Status Outputs", font=get_font(19, bold=True), fill="#1a202c", anchor="mm")
d.text((600, 620), "trade_valid, trade_price[5:0], trade_qty[15:0], trade_buy_id, trade_sell_id", font=get_mono_font(13), fill="#2d3748", anchor="mm")
d.text((600, 650), "done_pulse, reject_valid, reject_code[3:0], book_empty, book_full", font=get_mono_font(13), fill="#4a5568", anchor="mm")

# Connectors / Arrows
d.line([(260, 175), (320, 175)], fill="#2d3748", width=3)
d.line([(560, 175), (620, 175)], fill="#2d3748", width=3)
d.text((590, 160), "risk_ok", font=get_font(12, bold=True), fill="#38a169", anchor="mm")

# FSM to subsystems
d.line([(700, 230), (205, 300)], fill="#805ad5", width=2)
d.line([(885, 230), (595, 300)], fill="#805ad5", width=2)
d.line([(1050, 230), (985, 300)], fill="#805ad5", width=2)

# Subsystems to each other
d.line([(370, 385), (420, 385)], fill="#3182ce", width=3)
d.text((395, 370), "best_px", font=get_font(12, bold=True), fill="#3182ce", anchor="mm")

d.line([(770, 385), (820, 385)], fill="#3182ce", width=3)
d.text((795, 370), "rd_px/qty", font=get_font(12, bold=True), fill="#3182ce", anchor="mm")

# Subsystems to output
d.line([(595, 470), (595, 560)], fill="#2d3748", width=3)
d.line([(985, 470), (750, 560)], fill="#e53e3e", width=3)

img.save(f"{img_dir}/architecture_diagram.png")

# -------------------------------------------------------------
# 2. Timing Waveform Diagram (PNG)
# -------------------------------------------------------------
w2, h2 = 1200, 600
img2 = Image.new("RGB", (w2, h2), "#ffffff")
d2 = ImageDraw.Draw(img2)

# Header
d2.rectangle([30, 20, w2-30, 70], fill="#2d3748")
d2.text((w2//2, 45), "RTL Simulation Waveform: Multi-Cycle Limit Order Execution", 
        font=get_font(20, bold=True), fill="#ffffff", anchor="mm")

col_w = 140
start_x = 180
y_top = 80
y_bot = 540

# Grid lines
for i in range(7):
    x = start_x + i * col_w
    d2.line([(x, y_top), (x, y_bot)], fill="#edf2f7", width=2)
    d2.text((x + col_w//2, 95), f"Cycle {i+1}", font=get_font(14, bold=True), fill="#718096", anchor="mm")

signals = [
    ("clk", 140),
    ("order_valid", 195),
    ("in_order", 255),
    ("fsm_state", 320),
    ("trade_valid", 390),
    ("trade_price/qty", 450),
    ("done_pulse", 510)
]

for name, y in signals:
    d2.text((160, y), name, font=get_mono_font(14), fill="#2d3748", anchor="rm")

# clk trace
for i in range(7):
    x1 = start_x + i * col_w
    xm = x1 + col_w // 2
    x2 = x1 + col_w
    d2.line([(x1, 150), (xm, 150), (xm, 130), (x2, 130), (x2, 150)], fill="#3182ce", width=2)

# order_valid pulse in Cycle 1
d2.line([(start_x, 205), (start_x + col_w, 205)], fill="#4a5568", width=2) # low before
d2.line([(start_x + 10, 205), (start_x + 10, 185), (start_x + col_w - 10, 185), (start_x + col_w - 10, 205)], fill="#38a169", width=3)
d2.line([(start_x + col_w, 205), (start_x + 7*col_w, 205)], fill="#4a5568", width=2)
d2.text((start_x + col_w//2, 180), "PULSE", font=get_font(11, bold=True), fill="#22543d", anchor="mm")

# in_order box in Cycle 1-2
d2.rectangle([start_x + 10, 240, start_x + 2*col_w - 10, 270], fill="#edf2f7", outline="#4a5568", width=1)
d2.text((start_x + col_w, 255), "BUY Px=50, Qty=100", font=get_mono_font(12), fill="#2d3748", anchor="mm")
d2.line([(start_x + 2*col_w - 10, 255), (start_x + 7*col_w, 255)], fill="#cbd5e0", width=1)

# FSM state boxes
states = [
    ("S_VAL", "#feebc8", "#dd6b20"),
    ("S_DISC", "#edf2f7", "#4a5568"),
    ("S_CHECK", "#edf2f7", "#4a5568"),
    ("S_EXEC", "#fed7d7", "#e53e3e"),
    ("S_INSERT", "#feebc8", "#dd6b20"),
    ("S_DONE", "#c6f6d5", "#38a169"),
    ("S_IDLE", "#faf5ff", "#805ad5")
]

for i, (st_name, bg, stroke) in enumerate(states):
    x1 = start_x + i * col_w + 5
    x2 = x1 + col_w - 10
    d2.rectangle([x1, 305, x2, 335], fill=bg, outline=stroke, width=2)
    d2.text(((x1+x2)//2, 320), st_name, font=get_font(12, bold=True), fill=stroke, anchor="mm")

# trade_valid pulse in Cycle 4 (S_EXEC)
d2.line([(start_x, 400), (start_x + 3*col_w, 400)], fill="#4a5568", width=2)
d2.line([(start_x + 3*col_w + 10, 400), (start_x + 3*col_w + 10, 380), 
         (start_x + 4*col_w - 10, 380), (start_x + 4*col_w - 10, 400)], fill="#e53e3e", width=3)
d2.line([(start_x + 4*col_w, 400), (start_x + 7*col_w, 400)], fill="#4a5568", width=2)
d2.text((start_x + 3*col_w + col_w//2, 375), "TRADE STROBE", font=get_font(11, bold=True), fill="#c53030", anchor="mm")

# trade_price/qty in Cycle 4
d2.rectangle([start_x + 3*col_w + 10, 435, start_x + 4*col_w - 10, 465], fill="#fed7d7", outline="#e53e3e", width=1)
d2.text((start_x + 3*col_w + col_w//2, 450), "Px=50, Qty=100", font=get_mono_font(11), fill="#9b2c2c", anchor="mm")

# done_pulse in Cycle 6 (S_DONE)
d2.line([(start_x, 520), (start_x + 5*col_w, 520)], fill="#4a5568", width=2)
d2.line([(start_x + 5*col_w + 10, 520), (start_x + 5*col_w + 10, 500), 
         (start_x + 6*col_w - 10, 500), (start_x + 6*col_w - 10, 520)], fill="#38a169", width=3)
d2.line([(start_x + 6*col_w, 520), (start_x + 7*col_w, 520)], fill="#4a5568", width=2)
d2.text((start_x + 5*col_w + col_w//2, 495), "DONE PULSE", font=get_font(11, bold=True), fill="#22543d", anchor="mm")

img2.save(f"{img_dir}/waveform_diagram.png")

# -------------------------------------------------------------
# 3. FSM State Transition Diagram (PNG)
# -------------------------------------------------------------
w3, h3 = 1200, 500
img3 = Image.new("RGB", (w3, h3), "#ffffff")
d3 = ImageDraw.Draw(img3)

d3.rectangle([30, 20, w3-30, 70], fill="#faf5ff", outline="#805ad5", width=2)
d3.text((w3//2, 45), "Master Control Moore FSM: State Sequencing & Guard Conditions", 
        font=get_font(20, bold=True), fill="#553c9a", anchor="mm")

fsm_circles = [
    ("S_IDLE\n(0)", 100, 200, "#ebf8ff", "#3182ce"),
    ("S_VAL\n(1)", 260, 200, "#feebc8", "#dd6b20"),
    ("S_DISC\n(2)", 420, 200, "#edf2f7", "#4a5568"),
    ("S_CHECK\n(3)", 580, 200, "#edf2f7", "#4a5568"),
    ("S_EXEC\n(4)", 740, 200, "#fed7d7", "#e53e3e"),
    ("S_INSERT\n(5)", 580, 360, "#feebc8", "#dd6b20"),
    ("S_DONE\n(6)", 920, 200, "#c6f6d5", "#38a169"),
    ("S_REJECT\n(7)", 260, 360, "#fed7d7", "#e53e3e")
]

for label, cx, cy, bg, border in fsm_circles:
    r = 50
    d3.ellipse([cx-r, cy-r, cx+r, cy+r], fill=bg, outline=border, width=3)
    d3.text((cx, cy), label, font=get_font(13, bold=True), fill=border, anchor="mm", align="center")

# Draw connectors and labels
d3.line([(150, 200), (210, 200)], fill="#4a5568", width=2)
d3.text((180, 185), "valid", font=get_font(11, bold=True), fill="#2d3748", anchor="mm")

d3.line([(310, 200), (370, 200)], fill="#38a169", width=2)
d3.text((340, 185), "risk_ok", font=get_font(11, bold=True), fill="#38a169", anchor="mm")

d3.line([(260, 250), (260, 310)], fill="#e53e3e", width=2)
d3.text((295, 280), "!risk_ok", font=get_font(11, bold=True), fill="#e53e3e", anchor="mm")

d3.line([(470, 200), (530, 200)], fill="#4a5568", width=2)
d3.text((500, 185), "opp_found", font=get_font(11, bold=True), fill="#2d3748", anchor="mm")

d3.line([(630, 200), (690, 200)], fill="#38a169", width=2)
d3.text((660, 185), "cross_ok", font=get_font(11, bold=True), fill="#38a169", anchor="mm")

d3.line([(580, 250), (580, 310)], fill="#4a5568", width=2)
d3.text((620, 280), "!cross_ok", font=get_font(11), fill="#718096", anchor="mm")

d3.line([(790, 200), (870, 200)], fill="#38a169", width=2)
d3.text((830, 185), "in_done", font=get_font(11, bold=True), fill="#38a169", anchor="mm")

d3.line([(630, 360), (920, 250)], fill="#4a5568", width=2)
d3.text((760, 330), "inserted", font=get_font(11), fill="#4a5568", anchor="mm")

# Loop multi-level: S_EXEC back to S_DISC
d3.line([(740, 250), (740, 280), (420, 280), (420, 250)], fill="#3182ce", width=2)
d3.text((580, 270), "Multi-Level Sweep (in_qty > 0)", font=get_font(11, bold=True), fill="#3182ce", anchor="mm")

img3.save(f"{img_dir}/fsm_diagram.png")
print("All 3 PNG diagrams generated successfully.")
