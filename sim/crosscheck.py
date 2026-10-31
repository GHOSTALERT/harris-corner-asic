#!/usr/bin/env python3
"""Cross-check harris_top RTL against model/harris_reference.py at 64x64 (the synthesized size).

Builds a synthetic 64x64 test scene (rectangles, a rotated square, a triangle and light noise),
runs it through the RTL with Icarus Verilog (with and without random input stalls), and compares
every resp_dbg value and corner flag with the Python model bit for bit.
If matplotlib is available it also saves sim/corners_64x64.png with the detected corners.

Needs: python3 + numpy, iverilog >= 11. Run from the repo root:  python3 sim/crosscheck.py
"""
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "model"))
import harris_reference as hr  # noqa: E402

W = H = 64
K_Q = 41  # k = 41/1024 ~ 0.04
BUILD = os.path.join(ROOT, "build")


def scene():
    img = np.full((H, W), 40, np.int64)
    img[6:22, 6:26] = 200                      # rectangle
    img[34:58, 8:20] = 140                     # tall rectangle
    r, c = np.mgrid[0:H, 0:W]
    img[(abs(r - 16) + abs(c - 46)) <= 10] = 230   # diamond (45-degree square)
    img[(r >= 36) & (r <= 58) & (c >= 30) & (c - 30 <= (r - 36))] = 190  # right triangle
    rng = np.random.default_rng(7)
    img = img + rng.integers(-6, 7, img.shape)
    return np.clip(img, 0, 255).astype(np.uint8)


def run_rtl(img_hex, out, thr, gap):
    vvp = os.path.join(BUILD, "tb_harris_dump.vvp")
    if not os.path.exists(vvp):
        rtl = sorted(os.path.join(ROOT, "rtl", f) for f in os.listdir(os.path.join(ROOT, "rtl")))
        subprocess.run(["iverilog", "-g2012", "-o", vvp, "-s", "tb_harris_dump", *rtl,
                        os.path.join(ROOT, "sim", "tb_harris_dump.sv")], check=True)
    res = subprocess.run(["vvp", "-n", vvp, f"+IMG={img_hex}", f"+OUT={out}", f"+KQ={K_Q}",
                          f"+THR={thr}", f"+GAP={gap}"], check=True, capture_output=True, text=True)
    print("  " + next(l for l in res.stdout.splitlines() if l.startswith("DUMP DONE")))
    rows = [l.split() for l in open(out) if l.strip()]
    return [int(a) for a, _ in rows], [int(b) for _, b in rows]


def main():
    os.makedirs(BUILD, exist_ok=True)
    img = scene()
    img_hex = os.path.join(BUILD, "scene_64x64.hex")
    with open(img_hex, "w") as f:
        f.writelines(f"{p:02x}\n" for p in img.flatten())

    m0 = hr.run(img, k_q=K_Q, thr=0)
    vals = sorted(int(x) for x in m0["R_s"][m0["valid"]])
    thr = vals[-1] // 50                       # 2 % of the strongest response
    m = hr.run(img, k_q=K_Q, thr=thr)
    exp_r = [int(m["R_s"][r, c]) for r in range(H) for c in range(W) if m["valid"][r, c]]
    exp_c = [int(m["corner"][r, c]) for r in range(H) for c in range(W) if m["valid"][r, c]]
    print(f"model: {len(exp_r)} interior outputs, {sum(exp_c)} corners (k_q={K_Q}, thr={thr})")

    ok = True
    centres = [(r, c) for r in range(H) for c in range(W) if m["valid"][r, c]]
    rtl_corner = np.zeros((H, W), bool)
    for gap in (0, 35):
        print(f"RTL run, {gap}% input stalls:")
        got_r, got_c = run_rtl(img_hex, os.path.join(BUILD, f"rtl_out_gap{gap}.txt"), thr, gap)
        bad = sum(1 for a, b, x, y in zip(got_r, exp_r, got_c, exp_c) if a != b or x != y)
        bad += abs(len(got_r) - len(exp_r))
        print(f"  {len(got_r)} outputs, {sum(got_c)} corners, mismatches vs model: {bad}")
        ok &= bad == 0
        if gap == 0:
            got_r0 = got_r
            for (r, c), f in zip(centres, got_c):
                rtl_corner[r, c] = bool(f)

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        rr, cc = np.nonzero(rtl_corner)
        fig, ax = plt.subplots(1, 2, figsize=(9, 4.6))
        ax[0].imshow(img, cmap="gray", vmin=0, vmax=255)
        ax[0].scatter(cc, rr, s=22, facecolors="none", edgecolors="red", linewidths=1.2)
        ax[0].set_title(f"RTL corner_out = 1 ({len(rr)} px)")
        resp = np.zeros((H, W))
        for (r, c), v in zip(centres, got_r0):
            resp[r, c] = v
        ax[1].imshow(np.sign(resp) * np.log1p(abs(resp)), cmap="RdBu_r")
        ax[1].set_title("RTL resp_dbg (signed log scale)")
        for a in ax:
            a.set_xticks([]); a.set_yticks([])
        fig.suptitle("harris_top 64x64, k = 41/1024: RTL output, identical to the Python model")
        fig.tight_layout()
        fig.savefig(os.path.join(ROOT, "sim", "corners_64x64.png"), dpi=110)
        print("saved sim/corners_64x64.png")
    except ImportError:
        print("matplotlib not installed: skipping the plot")

    print("CROSSCHECK PASS" if ok else "CROSSCHECK FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
