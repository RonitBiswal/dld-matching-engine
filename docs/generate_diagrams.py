import os

images_dir = "C:/Users/ronit/dld-matching-engine/docs/images"
os.makedirs(images_dir, exist_ok=True)

# 1. System Architecture Diagram
arch_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 950 560" width="950" height="560" style="background:#ffffff; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#2d3748" />
    </marker>
    <marker id="arrow-blue" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#2b6cb0" />
    </marker>
    <marker id="arrow-red" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#c53030" />
    </marker>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="2" dy="2" stdDeviation="3" flood-opacity="0.1" />
    </filter>
  </defs>

  <!-- Title Header -->
  <rect x="20" y="15" width="910" height="45" rx="6" fill="#ebf8ff" stroke="#3182ce" stroke-width="1.5" />
  <text x="475" y="43" text-anchor="middle" font-size="17" font-weight="bold" fill="#2b6cb0">Hardware Limit Order Book: Top-Level RTL Architecture &amp; Subsystem Dataflow</text>

  <!-- Inputs Box -->
  <g filter="url(#shadow)">
    <rect x="30" y="85" width="160" height="85" rx="6" fill="#edf2f7" stroke="#4a5568" stroke-width="1.5" />
    <text x="110" y="108" text-anchor="middle" font-size="13" font-weight="bold" fill="#2d3748">Order Input Bus</text>
    <text x="110" y="128" text-anchor="middle" font-size="11" fill="#4a5568">order_valid, order_id</text>
    <text x="110" y="145" text-anchor="middle" font-size="11" fill="#4a5568">side, price, qty</text>
  </g>

  <!-- Member 5: Risk Filter -->
  <g filter="url(#shadow)">
    <rect x="240" y="85" width="200" height="85" rx="6" fill="#fffaf0" stroke="#dd6b20" stroke-width="1.5" />
    <text x="340" y="108" text-anchor="middle" font-size="13" font-weight="bold" fill="#9c4221">risk_filter (Member 5)</text>
    <text x="340" y="128" text-anchor="middle" font-size="11" fill="#7b341e">Price &amp; Qty Bounds</text>
    <text x="340" y="145" text-anchor="middle" font-size="11" fill="#7b341e">22-bit Notional (Px * Qty)</text>
  </g>

  <!-- Member 4: Master FSM Controller -->
  <g filter="url(#shadow)">
    <rect x="500" y="85" width="410" height="85" rx="6" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
    <text x="705" y="108" text-anchor="middle" font-size="14" font-weight="bold" fill="#553c9a">master_fsm Controller (Member 4)</text>
    <text x="705" y="128" text-anchor="middle" font-size="11" fill="#44337a">8-State Moore Machine (IDLE, VAL, DISC, CHECK, EXEC, INSERT, DONE, REJECT)</text>
    <text x="705" y="145" text-anchor="middle" font-size="11" fill="#44337a">Generates Glitch-Free Registered Control Strobes</text>
  </g>

  <!-- Middle Row: Subsystems -->
  <!-- Member 1: Price Bitmap & Hier Priority Encoder -->
  <g filter="url(#shadow)">
    <rect x="30" y="225" width="260" height="110" rx="6" fill="#ebf8ff" stroke="#3182ce" stroke-width="1.5" />
    <text x="160" y="248" text-anchor="middle" font-size="13" font-weight="bold" fill="#2b6cb0">Price Discovery (Member 1)</text>
    <text x="160" y="268" text-anchor="middle" font-size="11" fill="#2c5282">price_bitmap.v (64-bit Bid/Ask)</text>
    <text x="160" y="286" text-anchor="middle" font-size="11" fill="#2c5282">hier_priority_encoder (8x8 Parallel)</text>
    <text x="160" y="304" text-anchor="middle" font-size="11" fill="#2c5282">1-Cycle Best Price Extraction</text>
  </g>

  <!-- Member 2: Order Memory, FIFO & Allocator -->
  <g filter="url(#shadow)">
    <rect x="340" y="225" width="270" height="110" rx="6" fill="#f0fff4" stroke="#38a169" stroke-width="1.5" />
    <text x="475" y="248" text-anchor="middle" font-size="13" font-weight="bold" fill="#22543d">Storage Subsystem (Member 2)</text>
    <text x="475" y="268" text-anchor="middle" font-size="11" fill="#276749">order_memory (16 Slots + CAM ID)</text>
    <text x="475" y="286" text-anchor="middle" font-size="11" fill="#276749">fifo_queue (Linked-List Pointers)</text>
    <text x="475" y="304" text-anchor="middle" font-size="11" fill="#276749">free_list_allocator (LIFO Reclaim)</text>
  </g>

  <!-- Member 3: Datapath & Arithmetic -->
  <g filter="url(#shadow)">
    <rect x="660" y="225" width="250" height="110" rx="6" fill="#fff5f5" stroke="#e53e3e" stroke-width="1.5" />
    <text x="785" y="248" text-anchor="middle" font-size="13" font-weight="bold" fill="#9b2c2c">Matching Datapath (Member 3)</text>
    <text x="785" y="268" text-anchor="middle" font-size="11" fill="#742a2a">compatibility_logic (Cross Check)</text>
    <text x="785" y="286" text-anchor="middle" font-size="11" fill="#742a2a">quantity_arithmetic: min(In, Rest)</text>
    <text x="785" y="304" text-anchor="middle" font-size="11" fill="#742a2a">Residual Updates (In_rem, Rest_rem)</text>
  </g>

  <!-- Bottom Row: Output Stage -->
  <g filter="url(#shadow)">
    <rect x="250" y="410" width="450" height="90" rx="6" fill="#f7fafc" stroke="#2d3748" stroke-width="1.5" />
    <text x="475" y="435" text-anchor="middle" font-size="14" font-weight="bold" fill="#1a202c">Registered Trade Execution &amp; Status Outputs</text>
    <text x="475" y="458" text-anchor="middle" font-size="12" fill="#2d3748">trade_valid, trade_price [5:0], trade_qty [15:0], trade_buy_id, trade_sell_id</text>
    <text x="475" y="478" text-anchor="middle" font-size="12" fill="#4a5568">done_pulse, reject_valid, reject_code [3:0], book_empty, book_full</text>
  </g>

  <!-- Connectors -->
  <!-- Input to Risk Filter -->
  <line x1="190" y1="127" x2="236" y2="127" stroke="#2d3748" stroke-width="2" marker-end="url(#arrow)" />
  <!-- Risk Filter to FSM -->
  <line x1="440" y1="127" x2="496" y2="127" stroke="#2d3748" stroke-width="2" marker-end="url(#arrow)" />
  <text x="468" y="120" text-anchor="middle" font-size="10" font-weight="bold" fill="#c53030">risk_ok</text>

  <!-- FSM to Blocks Control Bus -->
  <line x1="570" y1="170" x2="160" y2="221" stroke="#805ad5" stroke-width="1.5" stroke-dasharray="4" marker-end="url(#arrow)" />
  <line x1="705" y1="170" x2="475" y2="221" stroke="#805ad5" stroke-width="1.5" stroke-dasharray="4" marker-end="url(#arrow)" />
  <line x1="840" y1="170" x2="785" y2="221" stroke="#805ad5" stroke-width="1.5" stroke-dasharray="4" marker-end="url(#arrow)" />

  <!-- Discovery to Storage (Price to Head Lookup) -->
  <line x1="290" y1="280" x2="336" y2="280" stroke="#2b6cb0" stroke-width="2" marker-end="url(#arrow-blue)" />
  <text x="315" y="272" text-anchor="middle" font-size="10" font-weight="bold" fill="#2b6cb0">best_px</text>

  <!-- Storage to Datapath (Resting Order Read to Comp/Arith) -->
  <line x1="610" y1="280" x2="656" y2="280" stroke="#2b6cb0" stroke-width="2" marker-end="url(#arrow-blue)" />
  <text x="635" y="272" text-anchor="middle" font-size="10" font-weight="bold" fill="#2b6cb0">rd_px/qty</text>

  <!-- Datapath to Output -->
  <line x1="760" y1="335" x2="610" y2="406" stroke="#2d3748" stroke-width="2" marker-end="url(#arrow)" />
  <text x="705" y="375" text-anchor="middle" font-size="10" font-weight="bold" fill="#2d3748">trade_qty</text>

  <!-- Storage to Output -->
  <line x1="475" y1="335" x2="475" y2="406" stroke="#2d3748" stroke-width="2" marker-end="url(#arrow)" />

  <!-- Feedback: Datapath to Storage & Bitmap (Residual / Pop) -->
  <path d="M 785 335 L 785 365 L 160 365 L 160 339" fill="none" stroke="#c53030" stroke-width="1.5" stroke-dasharray="4" marker-end="url(#arrow-red)" />
  <text x="340" y="360" text-anchor="middle" font-size="10" font-weight="bold" fill="#c53030">in_rem, rest_rem, slot_free, queue_pop</text>
</svg>"""

with open(f"{images_dir}/system_architecture.svg", "w", encoding="utf-8") as f:
    f.write(arch_svg)

# 2. Timing Waveform Diagram
waveform_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 950 480" width="950" height="480" style="background:#ffffff; font-family:'Courier New',Courier,monospace;">
  <!-- Title Header -->
  <rect x="20" y="15" width="910" height="40" rx="4" fill="#2d3748" />
  <text x="475" y="40" text-anchor="middle" font-family="-apple-system,sans-serif" font-size="15" font-weight="bold" fill="#ffffff">RTL Execution Waveform: Multi-Cycle Limit Order Matching &amp; Execution</text>

  <defs>
    <pattern id="grid" width="105" height="400" patternUnits="userSpaceOnUse">
      <line x1="105" y1="0" x2="105" y2="400" stroke="#edf2f7" stroke-width="1.5" stroke-dasharray="2" />
    </pattern>
  </defs>
  <rect x="160" y="65" width="735" height="390" fill="url(#grid)" />

  <!-- Cycle Headers -->
  <g font-family="-apple-system,sans-serif" font-size="12" font-weight="bold" fill="#718096" text-anchor="middle">
    <text x="212" y="80">Cycle 1</text>
    <text x="317" y="80">Cycle 2</text>
    <text x="422" y="80">Cycle 3</text>
    <text x="527" y="80">Cycle 4</text>
    <text x="632" y="80">Cycle 5</text>
    <text x="737" y="80">Cycle 6</text>
    <text x="842" y="80">Cycle 7</text>
  </g>

  <!-- Signal 1: clk -->
  <text x="145" y="115" text-anchor="end" font-size="13" font-weight="bold" fill="#2d3748">clk</text>
  <path d="M 160 120 L 212 120 L 212 98 L 265 98 L 265 120 L 317 120 L 317 98 L 370 98 L 370 120 L 422 120 L 422 98 L 475 98 L 475 120 L 527 120 L 527 98 L 580 98 L 580 120 L 632 120 L 632 98 L 685 98 L 685 120 L 737 120 L 737 98 L 790 98 L 790 120 L 842 120 L 842 98 L 895 98" fill="none" stroke="#3182ce" stroke-width="2" />

  <!-- Signal 2: order_valid -->
  <text x="145" y="155" text-anchor="end" font-size="13" font-weight="bold" fill="#2d3748">order_valid</text>
  <path d="M 160 162 L 212 162 L 212 142 L 317 142 L 317 162 L 895 162" fill="none" stroke="#38a169" stroke-width="2" />
  <text x="265" y="156" text-anchor="middle" font-size="11" fill="#22543d">PULSE</text>

  <!-- Signal 3: in_price / in_qty -->
  <text x="145" y="195" text-anchor="end" font-size="13" font-weight="bold" fill="#2d3748">in_order[px,qty]</text>
  <polygon points="160,202 212,202 217,192 312,192 317,202 895,202" fill="#edf2f7" stroke="#4a5568" stroke-width="1.5" />
  <polygon points="217,192 222,182 307,182 312,192 217,192" fill="#e2e8f0" stroke="#4a5568" stroke-width="1.5" />
  <text x="265" y="196" text-anchor="middle" font-size="11" font-weight="bold" fill="#2d3748">BUY Px=50, Q=100</text>

  <!-- Signal 4: FSM state -->
  <text x="145" y="245" text-anchor="end" font-size="13" font-weight="bold" fill="#805ad5">fsm_state</text>
  <polygon points="160,240 212,240 215,250 160,250" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <polygon points="160,240 212,240 215,230 160,230" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <text x="186" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#553c9a">IDLE</text>

  <polygon points="215,240 265,240 268,250 212,250" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <polygon points="215,240 265,240 268,230 212,230" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <text x="240" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#553c9a">VALIDATE</text>

  <polygon points="268,240 370,240 373,250 265,250" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <polygon points="268,240 370,240 373,230 265,230" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <text x="319" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#553c9a">DISCOVER</text>

  <polygon points="373,240 475,240 478,250 370,250" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <polygon points="373,240 475,240 478,230 370,230" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <text x="424" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#553c9a">CHECK</text>

  <polygon points="478,240 580,240 583,250 475,250" fill="#fed7d7" stroke="#e53e3e" stroke-width="1.5" />
  <polygon points="478,240 580,240 583,230 475,230" fill="#fed7d7" stroke="#e53e3e" stroke-width="1.5" />
  <text x="529" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#9b2c2c">EXECUTE</text>

  <polygon points="583,240 685,240 688,250 580,250" fill="#feebc8" stroke="#dd6b20" stroke-width="1.5" />
  <polygon points="583,240 685,240 688,230 580,230" fill="#feebc8" stroke="#dd6b20" stroke-width="1.5" />
  <text x="634" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#9c4221">INSERT</text>

  <polygon points="688,240 790,240 793,250 685,250" fill="#c6f6d5" stroke="#38a169" stroke-width="1.5" />
  <polygon points="688,240 790,240 793,230 685,230" fill="#c6f6d5" stroke="#38a169" stroke-width="1.5" />
  <text x="739" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#22543d">DONE</text>

  <polygon points="793,240 895,240 895,250 790,250" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <polygon points="793,240 895,240 895,230 790,230" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <text x="842" y="244" text-anchor="middle" font-size="10" font-weight="bold" fill="#553c9a">IDLE</text>

  <!-- Signal 5: trade_valid -->
  <text x="145" y="295" text-anchor="end" font-size="13" font-weight="bold" fill="#e53e3e">trade_valid</text>
  <path d="M 160 302 L 475 302 L 475 282 L 580 282 L 580 302 L 895 302" fill="none" stroke="#e53e3e" stroke-width="2.5" />
  <text x="528" y="295" text-anchor="middle" font-size="11" font-weight="bold" fill="#c53030">MATCH PULSE</text>

  <!-- Signal 6: trade_price & qty -->
  <text x="145" y="345" text-anchor="end" font-size="13" font-weight="bold" fill="#2d3748">trade_price/qty</text>
  <polygon points="160,352 470,352 475,342 580,342 585,352 895,352" fill="#edf2f7" stroke="#4a5568" stroke-width="1.5" />
  <polygon points="475,342 480,332 575,332 580,342 475,342" fill="#fed7d7" stroke="#e53e3e" stroke-width="1.5" />
  <text x="528" y="346" text-anchor="middle" font-size="10" font-weight="bold" fill="#9b2c2c">Px=48, Qty=40</text>

  <!-- Signal 7: done_pulse -->
  <text x="145" y="395" text-anchor="end" font-size="13" font-weight="bold" fill="#38a169">done_pulse</text>
  <path d="M 160 402 L 685 402 L 685 382 L 790 382 L 790 402 L 895 402" fill="none" stroke="#38a169" stroke-width="2.5" />
  <text x="738" y="395" text-anchor="middle" font-size="11" font-weight="bold" fill="#22543d">ORDER COMPLETED</text>

  <!-- Annotations / Notes -->
  <g font-family="-apple-system,sans-serif" font-size="11" fill="#4a5568">
    <text x="212" y="440" text-anchor="middle">1. Latch &amp; Check Risk</text>
    <text x="317" y="440" text-anchor="middle">2. Priority Enc (O(1))</text>
    <text x="422" y="440" text-anchor="middle">3. Read FIFO &amp; Memory</text>
    <text x="527" y="440" text-anchor="middle">4. Min Arithmetic &amp; Trade</text>
    <text x="632" y="440" text-anchor="middle">5. Remainder Inserted</text>
    <text x="737" y="440" text-anchor="middle">6. Latch Ready</text>
  </g>
</svg>"""

with open(f"{images_dir}/simulation_waveform.svg", "w", encoding="utf-8") as f:
    f.write(waveform_svg)

# 3. Master FSM State Transition Diagram
fsm_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 950 480" width="950" height="480" style="background:#ffffff; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
  <defs>
    <marker id="fsm-arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#4a5568" />
    </marker>
    <marker id="fsm-arrow-red" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#e53e3e" />
    </marker>
    <marker id="fsm-arrow-green" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#38a169" />
    </marker>
    <filter id="fsm-shadow" x="-8%" y="-8%" width="116%" height="116%">
      <feDropShadow dx="1" dy="2" stdDeviation="2" flood-opacity="0.12" />
    </filter>
  </defs>

  <!-- Title -->
  <rect x="20" y="15" width="910" height="40" rx="4" fill="#faf5ff" stroke="#805ad5" stroke-width="1.5" />
  <text x="475" y="41" text-anchor="middle" font-size="16" font-weight="bold" fill="#553c9a">Master Control Moore FSM: State Transitions and Guard Conditions</text>

  <!-- State 0: S_IDLE -->
  <g filter="url(#fsm-shadow)">
    <circle cx="90" cy="220" r="45" fill="#ebf8ff" stroke="#3182ce" stroke-width="2" />
    <text x="90" y="215" text-anchor="middle" font-size="13" font-weight="bold" fill="#2b6cb0">S_IDLE</text>
    <text x="90" y="233" text-anchor="middle" font-size="11" fill="#4a5568">State 0</text>
  </g>

  <!-- State 1: S_VALIDATE -->
  <g filter="url(#fsm-shadow)">
    <circle cx="240" cy="220" r="45" fill="#feebc8" stroke="#dd6b20" stroke-width="2" />
    <text x="240" y="215" text-anchor="middle" font-size="12" font-weight="bold" fill="#9c4221">S_VALIDATE</text>
    <text x="240" y="233" text-anchor="middle" font-size="11" fill="#4a5568">State 1</text>
  </g>

  <!-- State 7: S_REJECT -->
  <g filter="url(#fsm-shadow)">
    <circle cx="240" cy="380" r="42" fill="#fed7d7" stroke="#e53e3e" stroke-width="2" />
    <text x="240" y="375" text-anchor="middle" font-size="12" font-weight="bold" fill="#9b2c2c">S_REJECT</text>
    <text x="240" y="393" text-anchor="middle" font-size="11" fill="#4a5568">State 7</text>
  </g>

  <!-- State 2: S_DISCOVER -->
  <g filter="url(#fsm-shadow)">
    <circle cx="390" cy="220" r="45" fill="#edf2f7" stroke="#4a5568" stroke-width="2" />
    <text x="390" y="215" text-anchor="middle" font-size="12" font-weight="bold" fill="#2d3748">S_DISCOVER</text>
    <text x="390" y="233" text-anchor="middle" font-size="11" fill="#4a5568">State 2</text>
  </g>

  <!-- State 3: S_CHECK -->
  <g filter="url(#fsm-shadow)">
    <circle cx="540" cy="220" r="45" fill="#edf2f7" stroke="#4a5568" stroke-width="2" />
    <text x="540" y="215" text-anchor="middle" font-size="12" font-weight="bold" fill="#2d3748">S_CHECK</text>
    <text x="540" y="233" text-anchor="middle" font-size="11" fill="#4a5568">State 3</text>
  </g>

  <!-- State 4: S_EXECUTE -->
  <g filter="url(#fsm-shadow)">
    <circle cx="690" cy="220" r="45" fill="#fed7d7" stroke="#e53e3e" stroke-width="2" />
    <text x="690" y="215" text-anchor="middle" font-size="12" font-weight="bold" fill="#9b2c2c">S_EXECUTE</text>
    <text x="690" y="233" text-anchor="middle" font-size="11" fill="#4a5568">State 4</text>
  </g>

  <!-- State 5: S_INSERT -->
  <g filter="url(#fsm-shadow)">
    <circle cx="540" cy="90" r="45" fill="#feebc8" stroke="#dd6b20" stroke-width="2" />
    <text x="540" y="85" text-anchor="middle" font-size="12" font-weight="bold" fill="#9c4221">S_INSERT</text>
    <text x="540" y="103" text-anchor="middle" font-size="11" fill="#4a5568">State 5</text>
  </g>

  <!-- State 6: S_DONE -->
  <g filter="url(#fsm-shadow)">
    <circle cx="840" cy="220" r="45" fill="#c6f6d5" stroke="#38a169" stroke-width="2" />
    <text x="840" y="215" text-anchor="middle" font-size="12" font-weight="bold" fill="#22543d">S_DONE</text>
    <text x="840" y="233" text-anchor="middle" font-size="11" fill="#4a5568">State 6</text>
  </g>

  <!-- Transitions -->
  <!-- IDLE -> VALIDATE -->
  <line x1="135" y1="220" x2="189" y2="220" stroke="#4a5568" stroke-width="2" marker-end="url(#fsm-arrow)" />
  <text x="162" y="212" text-anchor="middle" font-size="10" font-weight="bold" fill="#2d3748">order_valid</text>

  <!-- VALIDATE -> DISCOVER (risk_ok) -->
  <line x1="285" y1="220" x2="339" y2="220" stroke="#4a5568" stroke-width="2" marker-end="url(#fsm-arrow)" />
  <text x="312" y="212" text-anchor="middle" font-size="10" font-weight="bold" fill="#38a169">risk_ok</text>

  <!-- VALIDATE -> REJECT (!risk_ok) -->
  <line x1="240" y1="265" x2="240" y2="332" stroke="#e53e3e" stroke-width="2" marker-end="url(#fsm-arrow-red)" />
  <text x="275" y="302" text-anchor="middle" font-size="10" font-weight="bold" fill="#e53e3e">!risk_ok</text>

  <!-- REJECT -> IDLE -->
  <path d="M 198 380 Q 90 380 90 271" fill="none" stroke="#4a5568" stroke-width="1.5" stroke-dasharray="3" marker-end="url(#fsm-arrow)" />
  <text x="130" y="370" text-anchor="middle" font-size="10" fill="#718096">reject_pulsed</text>

  <!-- DISCOVER -> CHECK (opp_found) -->
  <line x1="435" y1="220" x2="489" y2="220" stroke="#4a5568" stroke-width="2" marker-end="url(#fsm-arrow)" />
  <text x="462" y="212" text-anchor="middle" font-size="10" font-weight="bold" fill="#2d3748">opp_found</text>

  <!-- DISCOVER -> INSERT (!opp_found) -->
  <path d="M 390 175 Q 390 90 489 90" fill="none" stroke="#4a5568" stroke-width="1.5" marker-end="url(#fsm-arrow)" />
  <text x="410" y="125" text-anchor="middle" font-size="10" font-weight="bold" fill="#718096">!opp_found</text>

  <!-- CHECK -> EXECUTE (can_match) -->
  <line x1="585" y1="220" x2="639" y2="220" stroke="#4a5568" stroke-width="2" marker-end="url(#fsm-arrow)" />
  <text x="612" y="212" text-anchor="middle" font-size="10" font-weight="bold" fill="#38a169">can_match</text>

  <!-- CHECK -> INSERT (!can_match) -->
  <line x1="540" y1="175" x2="540" y2="141" stroke="#4a5568" stroke-width="1.5" marker-end="url(#fsm-arrow)" />
  <text x="575" y="160" text-anchor="middle" font-size="10" font-weight="bold" fill="#718096">!can_match</text>

  <!-- EXECUTE -> DISCOVER (in_rem > 0, loop for multi-level) -->
  <path d="M 690 265 Q 690 320 540 320 Q 390 320 390 271" fill="none" stroke="#2b6cb0" stroke-width="2" marker-end="url(#fsm-arrow)" />
  <text x="540" y="335" text-anchor="middle" font-size="11" font-weight="bold" fill="#2b6cb0">Multi-Level Sweep (in_qty remaining &gt; 0)</text>

  <!-- EXECUTE -> DONE (in_done) -->
  <line x1="735" y1="220" x2="789" y2="220" stroke="#38a169" stroke-width="2" marker-end="url(#fsm-arrow-green)" />
  <text x="762" y="212" text-anchor="middle" font-size="10" font-weight="bold" fill="#38a169">in_done</text>

  <!-- INSERT -> DONE -->
  <path d="M 585 90 Q 840 90 840 169" fill="none" stroke="#4a5568" stroke-width="1.5" marker-end="url(#fsm-arrow)" />
  <text x="710" y="80" text-anchor="middle" font-size="10" font-weight="bold" fill="#2d3748">slot_allocated &amp; queued</text>

  <!-- DONE -> IDLE -->
  <path d="M 840 265 Q 840 440 475 440 Q 90 440 90 271" fill="none" stroke="#38a169" stroke-width="2" marker-end="url(#fsm-arrow-green)" />
  <text x="475" y="455" text-anchor="middle" font-size="11" font-weight="bold" fill="#22543d">done_pulse asserted, Ready for Next Order</text>
</svg>"""

with open(f"{images_dir}/fsm_state_diagram.svg", "w", encoding="utf-8") as f:
    f.write(fsm_svg)

# 4. Price-Time Priority and Execution Flow Diagram
book_svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 950 420" width="950" height="420" style="background:#ffffff; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
  <defs>
    <marker id="bk-arrow" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 1 L 10 5 L 0 9 z" fill="#2d3748" />
    </marker>
  </defs>

  <!-- Title -->
  <rect x="20" y="15" width="910" height="40" rx="4" fill="#edf2f7" stroke="#cbd5e0" stroke-width="1.5" />
  <text x="475" y="40" text-anchor="middle" font-size="16" font-weight="bold" fill="#2d3748">Hardware Order Book Depth: Price-Time Priority &amp; Sweep Matching</text>

  <!-- Bids Table (Left) -->
  <g transform="translate(40, 75)">
    <rect x="0" y="0" width="400" height="310" rx="6" fill="#f0fff4" stroke="#38a169" stroke-width="1.5" />
    <rect x="0" y="0" width="400" height="35" rx="6" fill="#38a169" />
    <text x="200" y="24" text-anchor="middle" font-size="14" font-weight="bold" fill="#ffffff">BID BOOK (Buy Orders - Sorted Descending Price)</text>
    
    <!-- Table Header -->
    <text x="50" y="55" font-size="11" font-weight="bold" fill="#276749">PRICE</text>
    <text x="130" y="55" font-size="11" font-weight="bold" fill="#276749">QTY</text>
    <text x="230" y="55" font-size="11" font-weight="bold" fill="#276749">QUEUE ORDER (FIFO)</text>
    <text x="360" y="55" font-size="11" font-weight="bold" fill="#276749">PRIORITY</text>

    <!-- Row 1 -->
    <rect x="10" y="65" width="380" height="45" rx="4" fill="#c6f6d5" stroke="#68d391" stroke-width="1" />
    <text x="50" y="92" font-size="14" font-weight="bold" fill="#22543d">Tick 48</text>
    <text x="130" y="92" font-size="13" fill="#22543d">150</text>
    <text x="230" y="92" font-size="12" fill="#22543d">Order #101 (Head)</text>
    <text x="360" y="92" font-size="11" font-weight="bold" fill="#2f855a">Best Bid (1)</text>

    <!-- Row 2 -->
    <rect x="10" y="120" width="380" height="45" rx="4" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" />
    <text x="50" y="147" font-size="13" fill="#2d3748">Tick 47</text>
    <text x="130" y="147" font-size="13" fill="#2d3748">200</text>
    <text x="230" y="147" font-size="12" fill="#2d3748">Order #102 -&gt; Order #104</text>
    <text x="360" y="147" font-size="11" fill="#718096">Level 2</text>

    <!-- Row 3 -->
    <rect x="10" y="175" width="380" height="45" rx="4" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" />
    <text x="50" y="202" font-size="13" fill="#2d3748">Tick 45</text>
    <text x="130" y="202" font-size="13" fill="#2d3748">80</text>
    <text x="230" y="202" font-size="12" fill="#2d3748">Order #106 (Head)</text>
    <text x="360" y="202" font-size="11" fill="#718096">Level 3</text>

    <!-- Info text -->
    <text x="200" y="280" text-anchor="middle" font-size="11" fill="#276749">price_bitmap tracks active bit indices (bits 48, 47, 45 = 1)</text>
    <text x="200" y="298" text-anchor="middle" font-size="10" fill="#4a5568">Hierarchical Priority Encoder outputs highest active bit = 48</text>
  </g>

  <!-- Asks Table (Right) -->
  <g transform="translate(510, 75)">
    <rect x="0" y="0" width="400" height="310" rx="6" fill="#fff5f5" stroke="#e53e3e" stroke-width="1.5" />
    <rect x="0" y="0" width="400" height="35" rx="6" fill="#e53e3e" />
    <text x="200" y="24" text-anchor="middle" font-size="14" font-weight="bold" fill="#ffffff">ASK BOOK (Sell Orders - Sorted Ascending Price)</text>
    
    <!-- Table Header -->
    <text x="50" y="55" font-size="11" font-weight="bold" fill="#9b2c2c">PRICE</text>
    <text x="130" y="55" font-size="11" font-weight="bold" fill="#9b2c2c">QTY</text>
    <text x="230" y="55" font-size="11" font-weight="bold" fill="#9b2c2c">QUEUE ORDER (FIFO)</text>
    <text x="360" y="55" font-size="11" font-weight="bold" fill="#9b2c2c">PRIORITY</text>

    <!-- Row 1 -->
    <rect x="10" y="65" width="380" height="45" rx="4" fill="#fed7d7" stroke="#feb2b2" stroke-width="1" />
    <text x="50" y="92" font-size="14" font-weight="bold" fill="#9b2c2c">Tick 50</text>
    <text x="130" y="92" font-size="13" fill="#9b2c2c">60</text>
    <text x="230" y="92" font-size="12" fill="#9b2c2c">Order #201 (Head)</text>
    <text x="360" y="92" font-size="11" font-weight="bold" fill="#c53030">Best Ask (1)</text>

    <!-- Row 2 -->
    <rect x="10" y="120" width="380" height="45" rx="4" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" />
    <text x="50" y="147" font-size="13" fill="#2d3748">Tick 52</text>
    <text x="130" y="147" font-size="13" fill="#2d3748">110</text>
    <text x="230" y="147" font-size="12" fill="#2d3748">Order #203 -&gt; Order #205</text>
    <text x="360" y="147" font-size="11" fill="#718096">Level 2</text>

    <!-- Row 3 -->
    <rect x="10" y="175" width="380" height="45" rx="4" fill="#ffffff" stroke="#e2e8f0" stroke-width="1" />
    <text x="50" y="202" font-size="13" fill="#2d3748">Tick 55</text>
    <text x="130" y="202" font-size="13" fill="#2d3748">300</text>
    <text x="230" y="202" font-size="12" fill="#2d3748">Order #207 (Head)</text>
    <text x="360" y="202" font-size="11" fill="#718096">Level 3</text>

    <!-- Info text -->
    <text x="200" y="280" text-anchor="middle" font-size="11" fill="#9b2c2c">Bit-reversal encoder finds lowest set bit in Ask bitmap = 50</text>
    <text x="200" y="298" text-anchor="middle" font-size="10" fill="#4a5568">Incoming BUY @ 52 matches Tick 50 (60 shares), then Tick 52</text>
  </g>
</svg>"""

with open(f"{images_dir}/price_time_priority_flow.svg", "w", encoding="utf-8") as f:
    f.write(book_svg)

print("Created all 4 SVG diagrams in docs/images/")
