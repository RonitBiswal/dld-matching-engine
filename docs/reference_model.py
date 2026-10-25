import sys
import random
from collections import deque

DEFAULTS = dict(PRICE_W=6, QTY_W=16, SLOTS=16, MIN_QTY=1, MAX_QTY=1000, PRICE_MIN=1, PRICE_MAX=63, MAX_NOTIONAL=50000)
BUY, SELL = 1, 0

def risk_check(qty, price, cfg=DEFAULTS):
    reason = 0
    if qty < cfg["MIN_QTY"] or qty > cfg["MAX_QTY"]:
        reason |= 1
    if price < cfg["PRICE_MIN"] or price > cfg["PRICE_MAX"]:
        reason |= 2
    if qty * price > cfg["MAX_NOTIONAL"]:
        reason |= 4
    return reason

class Engine:
    def __init__(self, cfg=None):
        self.cfg = dict(DEFAULTS)
        if cfg:
            self.cfg.update(cfg)
        self.bids = {}
        self.asks = {}
        self.live = 0

    def best_bid(self):
        return max(self.bids) if self.bids else None

    def best_ask(self):
        return min(self.asks) if self.asks else None

    def depth(self):
        return {
            "bids": [(p, [tuple(o) for o in self.bids[p]]) for p in sorted(self.bids, reverse=True)],
            "asks": [(p, [tuple(o) for o in self.asks[p]]) for p in sorted(self.asks)],
        }

    def submit(self, oid, side, price, qty):
        ev = []
        reason = risk_check(qty, price, self.cfg)
        if reason:
            ev.append(("REJECT", oid, reason))
            return ev

        rem = qty
        while rem > 0:
            book = self.asks if side == BUY else self.bids
            if not book:
                break
            best = min(book) if side == BUY else max(book)
            crosses = (price >= best) if side == BUY else (price <= best)
            if not crosses:
                break
            q = book[best]
            rest_id, rest_qty = q[0]
            tq = min(rem, rest_qty)
            buy_id, sell_id = (oid, rest_id) if side == BUY else (rest_id, oid)
            ev.append(("TRADE", best, tq, buy_id, sell_id))
            rem -= tq
            q[0][1] -= tq
            if q[0][1] == 0:
                q.popleft()
                self.live -= 1
                if not q:
                    del book[best]

        if rem > 0:
            if self.live >= self.cfg["SLOTS"]:
                ev.append(("REJECT_FULL", oid))
                return ev
            mine = self.bids if side == BUY else self.asks
            mine.setdefault(price, deque()).append([oid, rem])
            self.live += 1
            ev.append(("REST", oid, side, price, rem))
        ev.append(("DONE", oid))
        return ev

def check_invariants(eng):
    bb, ba = eng.best_bid(), eng.best_ask()
    assert bb is None or ba is None or bb < ba, f"book crossed: bid {bb} >= ask {ba}"
    n = 0
    seen = set()
    for book in (eng.bids, eng.asks):
        for p, q in book.items():
            assert len(q) > 0, "empty level left in book"
            for oid, rq in q:
                assert rq > 0, "resting order with zero quantity"
                assert oid not in seen, "duplicate resting id"
                seen.add(oid)
                n += 1
    assert n == eng.live, "slot count mismatch"
    assert n <= eng.cfg["SLOTS"], "more orders than slots"

def selftest():
    ok = True

    def expect(name, cond):
        nonlocal ok
        print(("PASS  " if cond else "FAIL  ") + name)
        ok = ok and cond

    e = Engine()
    for oid, p, q in [(101, 50, 100), (102, 50, 50), (103, 49, 200)]:
        e.submit(oid, BUY, p, q)
    ev = e.submit(201, SELL, 49, 180)
    trades = [x for x in ev if x[0] == "TRADE"]
    expect("worked example trades = (50,100),(50,50),(49,30)", [(t[1], t[2]) for t in trades] == [(50, 100), (50, 50), (49, 30)])
    expect("worked example buy ids 101,102,103 / sell id 201", [(t[3], t[4]) for t in trades] == [(101, 201), (102, 201), (103, 201)])
    expect("B3 left with 170 at 49", e.depth()["bids"] == [(49, [(103, 170)])])
    expect("incoming SELL fully filled, nothing rests", e.best_ask() is None)

    e = Engine()
    e.submit(1, BUY, 40, 10)
    ev = e.submit(2, SELL, 41, 10)
    expect("non-crossing orders both rest", ev[0][0] == "REST" and e.best_bid() == 40 and e.best_ask() == 41)

    ev = e.submit(3, BUY, 45, 4)
    expect("trade at resting price (41, not 45)", ev[0] == ("TRADE", 41, 4, 3, 2))
    expect("partial fill leaves 6 resting", e.depth()["asks"] == [(41, [(2, 6)])])

    e = Engine()
    e.submit(10, SELL, 30, 5)
    e.submit(11, SELL, 30, 5)
    ev = e.submit(12, BUY, 30, 7)
    expect("FIFO: oldest sell (10) filled first", [(t[3], t[4], t[2]) for t in ev if t[0] == "TRADE"] == [(12, 10, 5), (12, 11, 2)])

    e = Engine()
    expect("qty 0 rejected (bit0)", e.submit(1, BUY, 20, 0)[0] == ("REJECT", 1, 1))
    expect("qty 1001 rejected (bit0)", e.submit(2, BUY, 20, 1001)[0] == ("REJECT", 2, 1))
    expect("price 0 rejected (bit1)", e.submit(3, BUY, 0, 10)[0] == ("REJECT", 3, 2))
    expect("notional 51000 rejected (bit2)", e.submit(4, BUY, 51, 1000)[0] == ("REJECT", 4, 4))
    expect("notional exactly 50000 accepted", e.submit(5, BUY, 50, 1000)[0][0] == "REST")
    expect("qty 2000 @40 -> bits 0 and 2", e.submit(6, BUY, 40, 2000)[0] == ("REJECT", 6, 5))
    expect("rejected orders leave book untouched", e.live == 1)

    e = Engine()
    for i in range(16):
        e.submit(100 + i, BUY, 10 + (i % 4), 5)
    expect("16 orders fill all slots", e.live == 16)
    expect("17th resting order -> REJECT_FULL", e.submit(200, BUY, 5, 5)[0] == ("REJECT_FULL", 200))
    e.submit(300, SELL, 10, 5)
    expect("slot freed after a fill, new order rests", e.submit(201, BUY, 5, 5)[0][0] == "REST")

    rng = random.Random(1234)
    e = Engine()
    inv_ok = True
    total_in = total_trade = 0
    for i in range(5000):
        side = rng.randint(0, 1)
        price = rng.randint(0, 63)
        qty = rng.choice([0, 1, 5, 20, 100, 500, 1000, 1001, 2000])
        before = sum(o[1] for b in (e.bids, e.asks) for q in b.values() for o in q)
        ev = e.submit(1000 + i, side, price, qty)
        after = sum(o[1] for b in (e.bids, e.asks) for q in b.values() for o in q)
        traded = sum(x[2] for x in ev if x[0] == "TRADE")
        rested = sum(x[4] for x in ev if x[0] == "REST")
        if after != before - traded + rested:
            inv_ok = False
        try:
            check_invariants(e)
        except AssertionError as ex:
            print("invariant failed:", ex)
            inv_ok = False
            break
        total_in += qty
        total_trade += traded
    expect("5000 random orders: invariants hold + quantity conserved", inv_ok)
    return ok

def stream(n, seed):
    rng = random.Random(seed)
    e = Engine()
    print("# id side price qty   (side: 1=BUY 0=SELL)")
    out = []
    for i in range(n):
        oid = 1 + i
        side = rng.randint(0, 1)
        price = rng.randint(30, 50) if rng.random() < 0.9 else rng.randint(0, 63)
        qty = rng.randint(1, 120) if rng.random() < 0.95 else rng.choice([0, 1001, 2000])
        print(f"ORDER {oid} {side} {price} {qty}")
        out.extend(e.submit(oid, side, price, qty))
    print("# expected events")
    for x in out:
        print("EXPECT", *x)
    print(f"# final best_bid={e.best_bid()} best_ask={e.best_ask()} resting={e.live}")

if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "--stream":
        stream(int(sys.argv[2]), int(sys.argv[3]))
    else:
        good = selftest()
        print("REFERENCE_MODEL: " + ("PASS" if good else "FAIL"))
        sys.exit(0 if good else 1)
