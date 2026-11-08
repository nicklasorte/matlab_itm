"""Figures for the ITM and P.2001 algorithm comparison (working paper, revision 4).

Draws only: every value comes from chart_data/alg_*.csv, which
algorithm_comparison_rev1.m writes. Same style as make_wp_figures_3ghz.py:
ITM light blue, P.2001 dark blue, P.2001 sub-models thin gray, one idea per
figure. Writes figures/s38_*.png to figures/s43_*.png.

Run:  algorithm_comparison_rev1 in MATLAB, then python3 make_wp_algorithm_figures.py
"""

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.patches import FancyBboxPatch

from make_wp_figures_3ghz import new, clean, save, W, DB, LB, PU, GR, CD

LG2 = "#C9CCD1"
SUB = {"p2001_lbm1_db": ("Line of sight and diffraction", "-"),
       "p2001_lbm2_db": ("Anomalous (ducting)", (0, (4, 2))),
       "p2001_lbm3_db": ("Troposcatter", (0, (1, 1.5)))}


def rd(name):
    return pd.read_csv(CD / name)


def xlog(ax, lo, hi, ticks):
    ax.set_xscale("log")
    ax.set_xlim(lo, hi)
    ax.set_xticks(ticks, [f"{t:g}" for t in ticks])
    ax.minorticks_off()


def s38_architecture():
    """How each model builds its answer: one reference line versus four sub-models combined."""
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.5), layout="constrained")

    def box(ax, x, y, w, h, text, fc="white", ec=GR, tc=DB, bold=False):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.01,rounding_size=0.02", fc=fc, ec=ec, lw=1))
        ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=7.6, color=tc,
                fontweight="semibold" if bold else "normal", linespacing=1.15)

    def arrow(ax, x0, y0, x1, y1):
        ax.annotate("", (x1, y1), (x0, y0), arrowprops=dict(arrowstyle="-|>", color=GR, lw=0.9, shrinkA=0, shrinkB=0))

    a = axs[0]
    a.set_title("ITM: choose one region, then add variability", loc="left", fontsize=9, color=LB, fontweight="semibold")
    box(a, 0.05, 0.84, 0.9, 0.12, "Profile: horizons, effective heights, Δh")
    arrow(a, 0.5, 0.84, 0.5, 0.77)
    box(a, 0.05, 0.62, 0.27, 0.15, "Line of sight\nd < d_sML\ntwo-ray fit")
    box(a, 0.365, 0.62, 0.27, 0.15, "Diffraction\nd_sML ≤ d ≤ d_x\nline through d₃, d₄")
    box(a, 0.68, 0.62, 0.27, 0.15, "Troposcatter\nd > d_x\nline through d₅, d₆")
    for x in (0.185, 0.5, 0.815):
        arrow(a, x, 0.62, 0.5, 0.48)
    box(a, 0.2, 0.36, 0.6, 0.12, "Reference attenuation A_ref (one value)", fc="#EEF1FA", ec=LB, bold=True)
    arrow(a, 0.5, 0.36, 0.5, 0.29)
    box(a, 0.05, 0.14, 0.9, 0.15, "Time variability: climate curves of\neffective distance, added to A_ref")
    arrow(a, 0.5, 0.14, 0.5, 0.07)
    a.text(0.5, 0.02, "Loss at p % of time", ha="center", fontsize=8, color=DB, fontweight="semibold")

    a = axs[1]
    a.set_title("P.2001: compute every mechanism, then combine", loc="left", fontsize=9, color=DB, fontweight="semibold")
    box(a, 0.05, 0.84, 0.9, 0.12, "Profile and ITU-R maps: refractivity, ducting, rain, gases")
    xs = [0.03, 0.27, 0.51, 0.75]
    labs = ["1 Line of sight\nand diffraction\n(+ fading, gases)", "2 Anomalous:\nducting, layer\nreflection",
            "3 Tropo-\nscatter", "4 Sporadic-E\n(low frequency)"]
    for x, t in zip(xs, labs):
        arrow(a, 0.5, 0.84, x + 0.11, 0.79)
        box(a, x, 0.57, 0.22, 0.22, t)
        arrow(a, x + 0.11, 0.57, 0.5, 0.48)
    box(a, 0.12, 0.36, 0.76, 0.12, "Each at p % of time, from its own statistics", fc="#EEF1FA", ec=DB)
    arrow(a, 0.5, 0.36, 0.5, 0.29)
    box(a, 0.05, 0.14, 0.9, 0.15, "Power sum: the lowest loss dominates,\nnear-equal losses add (up to 3 dB)", bold=True)
    arrow(a, 0.5, 0.14, 0.5, 0.07)
    a.text(0.5, 0.02, "Loss at p % of time", ha="center", fontsize=8, color=DB, fontweight="semibold")
    for a in axs:
        a.set_xlim(0, 1); a.set_ylim(0, 1); a.axis("off")
    save(fig, "s38_architecture")


def s39_smooth_mechanisms():
    """Smooth earth at 50 % and 1 % of time: ITM's one line against P.2001's sub-models."""
    S = rd("alg_smooth_sweep.csv")
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.3), layout="constrained", sharey=True)
    for ax, p in zip(axs, [50, 1]):
        clean(ax)
        q = S[S.time_pct == p]
        fs = q.p2001_fs_db
        for col, (lab, ls) in SUB.items():
            ax.plot(q.d_km, q[col] - fs, color=GR, lw=1.0, ls=ls)
        ax.plot(q.d_km, q.p2001_lb_db - fs, color=DB, lw=2.4)
        ax.plot(q.d_km, q.itm_lb_db - q.itm_fs_db, color=LB, lw=2.0)
        ax.axvline(q.itm_d_sml_km.iloc[0], color=LG2, lw=0.8)
        dx = q.itm_d_x_km.max()
        ax.axvline(dx, color=LG2, lw=0.8)
        ax.text(q.itm_d_sml_km.iloc[0] * 0.97, 118, "ITM horizon", fontsize=7, color=GR, rotation=90, va="top", ha="right")
        ax.text(dx * 0.97, 118, "ITM scatter from here", fontsize=7, color=GR, rotation=90, va="top", ha="right")
        xlog(ax, 3, 700, [3, 10, 30, 100, 300, 700])
        ax.set_ylim(-10, 120)
        ax.set_title(f"{p}% of time", loc="left", fontsize=9.5, color=DB)
        ax.set_xlabel("Distance (km), log scale")
    axs[0].set_ylabel("Loss above free space (dB)")
    a = axs[0]
    a.text(250, 47, "P.2001 troposcatter\n(dotted)", fontsize=7.5, color=GR, ha="center")
    a.text(120, 112, "P.2001 diffraction", fontsize=7.5, color=GR)
    a.text(3.3, 86, "P.2001 anomalous (dashed)", fontsize=7.5, color=GR)
    a.text(4, 22, "ITM", color=LB, fontsize=8.5, fontweight="semibold")
    a.text(4, 10, "P.2001 (all sub-models\ncombined)", color=DB, fontsize=8, fontweight="semibold")
    b = axs[1]
    b.text(120, 3, "P.2001 anomalous\ntakes over", fontsize=7.5, color=DB, ha="center")
    save(fig, "s39_smooth_mechanisms")


def s40_itm_anatomy():
    """How ITM builds the loss on one path: straight lines through a few anchor points."""
    A = rd("alg_itm_anatomy.csv")
    names = list(dict.fromkeys(A.path))
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.3), layout="constrained")
    for ax, nm in zip(axs, names):
        clean(ax)
        a = A[A.path == nm]
        c = a[a.kind == "curve"]
        ax.plot(c.d_km, c.diffraction_line_db, color=LB, lw=1.4, ls=(0, (4, 2)))
        if c.scatter_line_db.notna().any():
            ax.plot(c.d_km, c.scatter_line_db, color=PU, lw=1.4, ls=(0, (1, 1.5)))
        if c.los_fit_db.notna().any():
            sml = a.set_index("kind").loc["d_sML", "d_km"]
            q = c[c.d_km <= sml]
            ax.plot(q.d_km, q.los_fit_db, color=GR, lw=1.6)
        pt = a.set_index("kind")
        for k, col in [("d_3", LB), ("d_4", LB), ("d_5", PU), ("d_6", PU), ("d_0", GR), ("d_1", GR)]:
            if k in pt.index and np.isfinite(pt.loc[k, "value_db"]):
                ax.scatter(pt.loc[k, "d_km"], pt.loc[k, "value_db"], s=26, color=col, zorder=3, edgecolor="white")
                lab = k.replace("_", "")
                ax.text(pt.loc[k, "d_km"], pt.loc[k, "value_db"], (lab + "  ") if k == "d_0" else ("  " + lab), fontsize=7.5,
                        color=col, va="top", ha="right" if k == "d_0" else "left")
        d = pt.loc["itm_at_path", "d_km"]
        ax.axvline(d, color=LG2, lw=0.8)
        ax.scatter([d], [pt.loc["itm_at_path", "value_db"]], s=60, marker="D", color=LB, zorder=4, edgecolor="white")
        ax.scatter([d], [pt.loc["p2001_at_path", "value_db"]], s=60, marker="D", color=DB, zorder=4, edgecolor="white")
        ax.text(d - 8, pt.loc["itm_at_path", "value_db"] + 14, f"ITM {pt.loc['itm_at_path', 'value_db']:.0f} dB", color=LB,
                fontsize=8, fontweight="semibold", va="bottom", ha="right")
        ax.text(d, pt.loc["p2001_at_path", "value_db"], f"  P.2001 {pt.loc['p2001_at_path', 'value_db']:.0f} dB", color=DB,
                fontsize=8, fontweight="semibold", va="top")
        ax.set_title(nm[0].upper() + nm[1:], loc="left", fontsize=9, color=DB)
        ax.set_xlabel("Distance (km)")
        ax.set_xlim(0, c.d_km.max())
        ax.set_ylim(0, max(np.nanmax(c.diffraction_line_db.clip(upper=250)), 100) * 1.05)
    axs[0].set_ylabel("Loss above free space (dB)")
    axs[0].text(0.03, 0.95, "Diffraction line", transform=axs[0].transAxes, color=LB, fontsize=8)
    axs[0].text(0.03, 0.88, "Scatter line: slope from d5 and d6,\njoined to the diffraction line at d_x", transform=axs[0].transAxes,
                color=PU, fontsize=8, va="top")
    axs[1].text(0.97, 0.05, "Line-of-sight fit through d0, d1,\nand the smooth-earth horizon", transform=axs[1].transAxes,
                color=GR, fontsize=8, ha="right")
    save(fig, "s40_itm_anatomy")


def s41_line_of_sight():
    """Line of sight over smooth earth: neither model follows the two-ray lobes."""
    L = rd("alg_los_sweep.csv")
    fig, ax = new(); clean(ax)
    ax.plot(L.d_km, L.tworay_excess_db, color=LG2, lw=1.0)
    ax.plot(L.d_km, L.p2001_excess_db, color=DB, lw=2.2)
    ax.plot(L.d_km, L.itm_excess_db, color=LB, lw=2.0, ls=(0, (4, 2)))
    ax.axhline(0, color=DB, lw=0.6)
    ax.set_xlim(1, 40); ax.set_ylim(-10, 30)
    ax.set_xlabel("Distance (km)"); ax.set_ylabel("Loss above free space (dB)")
    ax.text(6, -8.5, "Two-ray reference (direct plus ground-reflected ray)", color=GR, fontsize=8)
    ax.text(38, 24.5, "P.2001", color=DB, fontsize=8.5, fontweight="semibold", ha="right")
    ax.text(38, 17, "ITM", color=LB, fontsize=8.5, fontweight="semibold", ha="right")
    save(fig, "s41_line_of_sight")


def s42_time_mechanisms():
    """Over the year: ITM's variability curve against P.2001's competing sub-models."""
    T = rd("alg_time_sweep.csv")
    names = list(dict.fromkeys(T.path))
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.3), layout="constrained")
    for ax, nm in zip(axs, names):
        clean(ax)
        t = T[T.path == nm]
        x = t.time_pct
        for col, (lab, ls) in SUB.items():
            ax.plot(x, t[col], color=GR, lw=1.0, ls=ls)
        ax.plot(x, t.p2001_lb_db, color=DB, lw=2.4)
        ax.plot(x, t.itm_lb_db, color=LB, lw=2.0)
        xlog(ax, 0.01, 99, [0.01, 0.1, 1, 10, 50, 99])
        lo = min(t.p2001_lb_db.min(), t.itm_lb_db.min()) - 10
        hi = max(t.p2001_lb_db.max(), t.itm_lb_db.max()) + 25
        ax.set_ylim(lo, hi)
        ax.set_title(nm[0].upper() + nm[1:], loc="left", fontsize=9, color=DB)
        ax.set_xlabel("Time percentage (%), log scale")
    axs[0].set_ylabel("Basic transmission loss (dB)")
    t = T[T.path == names[0]]
    a = axs[0]
    a.text(0.012, t.itm_lb_db.iloc[0] + 3, "ITM", color=LB, fontsize=8.5, fontweight="semibold")
    a.text(0.4, t.p2001_lb_db.iloc[5] - 9, "P.2001", color=DB, fontsize=8.5, fontweight="semibold")
    a.text(25, t.p2001_lbm2_db.iloc[11] + 4, "anomalous", color=GR, fontsize=7.5)
    a.text(0.012, t.p2001_lbm3_db.iloc[0] + 3, "troposcatter", color=GR, fontsize=7.5)
    a.text(0.03, t.p2001_lbm1_db.iloc[2] + 4, "diffraction", color=GR, fontsize=7.5, rotation=28)
    t2 = T[T.path == names[1]]; b = axs[1]
    b.text(0.012, t2.itm_lb_db.iloc[0] + 4, "ITM", color=LB, fontsize=8.5, fontweight="semibold")
    b.text(0.012, t2.p2001_lb_db.iloc[0] + 4, "P.2001 (diffraction dominates)", color=DB, fontsize=8.5, fontweight="semibold")
    save(fig, "s42_time_mechanisms")


def s43_mechanism_agreement():
    """Do the models agree on the mechanism? ITM's mode against P.2001's dominant sub-model, 120 links."""
    M = rd("alg_mechanism_links.csv")
    rows = [("Line of sight", [0]), ("Diffraction", [4, 5, 8, 9]), ("Troposcatter", [6, 10])]
    cols = [("Line of\nsight", 0), ("Diffraction", 1), ("Anomalous", 2), ("Tropo-\nscatter", 3)]
    fig, axs = plt.subplots(1, 2, figsize=(W, 2.6), layout="constrained")
    for ax, p in zip(axs, [50, 1]):
        m = M[M.time_pct == p]
        Z = np.array([[((m.itm_mode_code.isin(r)) & (m.p2001_mech == c)).sum() for _, c in cols] for _, r in rows])
        agree = np.zeros_like(Z, dtype=bool); agree[0, 0] = agree[1, 1] = agree[2, 3] = True
        for i in range(Z.shape[0]):
            for j in range(Z.shape[1]):
                fc = "#EEF1FA" if agree[i, j] else ("#F3EEF8" if Z[i, j] else "white")
                ax.add_patch(plt.Rectangle((j, -i), 1, 1, fc=fc, ec="#E0E0E0"))
                if Z[i, j]:
                    ax.text(j + 0.5, -i + 0.5, str(Z[i, j]), ha="center", va="center", fontsize=10,
                            color=DB if agree[i, j] else PU, fontweight="semibold")
        ax.set_xlim(0, 4); ax.set_ylim(-2, 1)
        ax.set_xticks(np.arange(4) + 0.5, [c for c, _ in cols], fontsize=7.5)
        ax.xaxis.tick_top()
        ax.set_yticks([0.5, -0.5, -1.5], [r for r, _ in rows] if p == 50 else ["", "", ""], fontsize=8)
        for s in ax.spines.values():
            s.set_visible(False)
        ax.tick_params(length=0)
        ax.set_xlabel(f"{p}% of time", fontsize=9, color=DB)
    axs[0].set_ylabel("ITM mode", fontsize=8.5)
    fig.suptitle("P.2001 dominant mechanism", fontsize=8.5, color=GR, x=0.62)
    save(fig, "s43_mechanism_agreement")


ALL = [s38_architecture, s39_smooth_mechanisms, s40_itm_anatomy, s41_line_of_sight, s42_time_mechanisms,
       s43_mechanism_agreement]

if __name__ == "__main__":
    for fn in ALL:
        fn()
