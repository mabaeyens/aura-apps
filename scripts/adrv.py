#!/usr/bin/env python3
"""Aura screenshot driver: closed-loop scroll + tap + capture via idb + simctl."""
import json, subprocess, sys, time, os

IDB = os.path.expanduser("~/.local/bin/idb")

def sh(*a, capture=False):
    return subprocess.run(a, capture_output=capture, text=True)

def describe(udid):
    r = subprocess.run([IDB, "ui", "describe-all", "--udid", udid, "--json"],
                       capture_output=True, text=True)
    try:
        d = json.loads(r.stdout)
    except Exception:
        return []
    out = []
    for e in d:
        f = e.get("frame") or {}
        lbl = e.get("AXLabel")
        if lbl is None:
            continue
        out.append({"label": lbl, "x": f.get("x", 0), "y": f.get("y", 0),
                    "w": f.get("width", 0), "h": f.get("height", 0),
                    "role": e.get("role", "")})
    return out

def find(elems, substr, near_y=None):
    matches = [e for e in elems if substr.lower() in e["label"].lower()]
    if not matches:
        return None
    if near_y is not None:
        matches.sort(key=lambda e: abs(e["y"] - near_y))
    return matches[0]

def swipe(udid, x, y1, y2, dur=0.8):
    sh(IDB, "ui", "swipe", "--udid", udid,
       str(round(x)), str(round(y1)), str(round(x)), str(round(y2)),
       "--duration", str(dur))

def tap(udid, x, y):
    sh(IDB, "ui", "tap", "--udid", udid, str(round(x)), str(round(y)))

def screenshot(udid, path):
    sh("xcrun", "simctl", "io", udid, "screenshot", path)

def scroll_to(udid, anchor, target_y, cx=220, tol=16, max_iter=9, dur=0.8):
    """Bring element containing `anchor` to on-screen y≈target_y."""
    for i in range(max_iter):
        els = describe(udid)
        e = find(els, anchor)
        if e is None:
            # anchor not materialized yet: nudge down and retry
            swipe(udid, cx, 700, 300, dur)
            time.sleep(0.6)
            continue
        cur = e["y"]
        delta = cur - target_y
        if abs(delta) <= tol:
            return e
        # slow drag by -delta (drag up to scroll content up). Clamp travel to stay on-screen.
        y1 = 620
        y2 = max(80, min(900, y1 - delta))
        # if delta tiny relative to travel, shorten
        swipe(udid, cx, y1, y2, dur)
        time.sleep(0.6)
    return find(describe(udid), anchor)

def raw_swipe(udid, x1, y1, x2, y2, dur=0.7):
    sh(IDB, "ui", "swipe", "--udid", udid, str(round(x1)), str(round(y1)),
       str(round(x2)), str(round(y2)), "--duration", str(dur))

def scroll_to_ipad(udid, anchor, target_y, tol=24, max_iter=14, iny=516):
    """Landscape iPad: idb input axis is transposed vs describe output. A HORIZONTAL
    swipe scrolls the content; describe reports the scroll position in output-y. Bring
    `anchor` to on-screen output-y ~= target_y."""
    for _ in range(max_iter):
        e = find(describe(udid), anchor)
        if e is None:
            raw_swipe(udid, 760, iny, 300, iny, 0.6); time.sleep(0.6); continue
        delta = e["y"] - target_y
        if abs(delta) <= tol:
            return e
        travel = max(-660, min(660, delta * 0.5))  # +delta (below target) -> swipe x high->low -> scroll up
        x1 = 740
        raw_swipe(udid, x1, iny, x1 - travel, iny, 0.7)
        time.sleep(0.55)
    return find(describe(udid), anchor)

def reset_top_ipad(udid, iny=516):
    for _ in range(7):
        raw_swipe(udid, 200, iny, 900, iny, 0.5); time.sleep(0.3)
    time.sleep(0.4)

def reset_top(udid, cx=220):
    for _ in range(6):
        swipe(udid, cx, 250, 900, 0.5)
        time.sleep(0.3)
    time.sleep(0.4)

if __name__ == "__main__":
    # dev harness: python adrv.py <udid> <cmd> ...
    udid = sys.argv[1]; cmd = sys.argv[2]
    if cmd == "scroll":
        anchor = sys.argv[3]; ty = int(sys.argv[4])
        e = scroll_to(udid, anchor, ty)
        print("landed:", e)
    elif cmd == "top":
        reset_top(udid); print("at top")
    elif cmd == "shot":
        screenshot(udid, sys.argv[3]); print("shot", sys.argv[3])
    elif cmd == "list":
        for e in sorted(describe(udid), key=lambda z: z["y"]):
            if e["label"].strip():
                print(f"y={round(e['y']):5} x={round(e['x']):3} h={round(e['h']):3} {e['role'][:12]:12} {e['label'][:44]}")
    elif cmd == "tapnear":
        anchor = sys.argv[3]
        els = describe(udid); e = find(els, anchor)
        print("tapping near", e)
        tap(udid, e["x"]+e["w"]/2, e["y"]+e["h"]/2)
