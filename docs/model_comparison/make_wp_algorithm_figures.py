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


def s44_two_obstacles():
    """Two ridges: ITM far above the two-edge references, P.2001 near them."""
    T = rd("fam_two_obstacles.csv")
    T["itm"] = T.itm_db - T.fs_db; T["p"] = T.p2001_db - T.fs_db
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.3), layout="constrained")
    a = axs[0]
    H = sorted(T.h1_m.unique())
    Z = T.pivot(index="h1_m", columns="h2_m", values="itm").values - T.pivot(index="h1_m", columns="h2_m", values="p").values
    im = a.pcolormesh(np.r_[H, H[-1] + 20] - 10, np.r_[H, H[-1] + 20] - 10, Z, cmap="Purples", vmin=0, vmax=80, shading="flat")
    cs = a.contour(H, H, Z, levels=[10, 20, 40], colors=DB, linewidths=0.8)
    a.clabel(cs, fmt="%d dB", fontsize=7.5)
    a.set_xlabel("Ridge at 20 km, height (m)"); a.set_ylabel("Ridge at 10 km, height (m)")
    a.set_title("ITM minus P.2001 (dB)", loc="left", fontsize=9, color=DB)
    a.set_aspect("equal")
    for sp in a.spines.values():
        sp.set_visible(False)
    b = axs[1]; clean(b)
    q = T[T.h1_m == T.h2_m]
    b.fill_between(q.h1_m, q[["epstein_peterson_db", "deygout_db"]].min(axis=1), q[["epstein_peterson_db", "deygout_db"]].max(axis=1),
                   color=LG2, alpha=0.8, lw=0)
    b.plot(q.h1_m, q.p, color=DB, lw=2.2)
    b.plot(q.h1_m, q.itm, color=LB, lw=2.2)
    b.set_xlabel("Height of both ridges (m)"); b.set_ylabel("Loss above free space (dB)")
    b.set_title("Two equal ridges", loc="left", fontsize=9, color=DB)
    b.set_xlim(0, 300); b.set_ylim(0, 140)
    b.text(300, q.itm.iloc[-1] - 4, "ITM", color=LB, fontsize=8.5, fontweight="semibold", ha="right", va="top")
    b.text(300, q.p.iloc[-1] - 4, "P.2001", color=DB, fontsize=8.5, fontweight="semibold", ha="right", va="top")
    b.text(235, 74, "Two-edge references\n(Epstein-Peterson\nto Deygout)", color=GR, fontsize=7.5, ha="center", va="bottom")
    save(fig, "s44_two_obstacles")


def s45_roughness_grid():
    """Synthetic rough terrain: the gap is set by roughness, and long paths reconverge."""
    G = rd("fam_roughness_grid.csv")
    D = sorted(G.d_km.unique()); DH = sorted(G.target_delta_h_m.unique())
    Z = G.pivot(index="target_delta_h_m", columns="d_km", values="median_gap_db").loc[DH, D].values
    fig, ax = new(h=3.4)
    ax.imshow(Z, cmap="Purples", vmin=0, vmax=70, aspect="auto", origin="lower")
    for i in range(len(DH)):
        for j in range(len(D)):
            v = Z[i, j]
            ax.text(j, i, f"{round(v) + 0:.0f}", ha="center", va="center", fontsize=8.5, color="white" if v > 40 else DB,
                    fontweight="semibold" if v >= 20 else "normal")
    ax.set_xticks(range(len(D)), [f"{d:g}" for d in D]); ax.set_yticks(range(len(DH)), [f"{h:,.0f}" for h in DH])
    ax.set_xlabel("Path length (km)"); ax.set_ylabel("Terrain roughness:\ninterdecile range of heights (m)")
    for sp in ax.spines.values():
        sp.set_visible(False)
    ax.tick_params(length=0)
    ax.set_title("Median ITM minus P.2001 (dB), 20 synthetic profiles per cell", loc="left", fontsize=9, color=DB)
    save(fig, "s45_roughness_grid")


def s46_evaluation_point():
    """Giving P.2001 ITM's construction doesn't close the gap."""
    P = rd("fam_evaluation_point.csv")
    u = P[P.used == 1].copy()
    u["g0"] = u.itm_excess_db - u.p2001_excess_db
    u["g1"] = u.itm_excess_db - u.p2001_line_at_path_db
    fig, ax = new(h=3.2); clean(ax)
    for _, r in u.iterrows():
        ax.plot([0, 1], [r.g0, r.g1], color=LG2, lw=0.8, zorder=1)
    m0, m1 = u.g0.median(), u.g1.median()
    ax.plot([0, 1], [m0, m1], color=PU, lw=2.6, marker="o", zorder=3)
    ax.text(-0.04, m0, f"{m0:.0f} dB", color=PU, ha="right", va="center", fontsize=9, fontweight="semibold")
    ax.text(1.04, m1, f"{m1:.0f} dB median", color=PU, ha="left", va="center", fontsize=9, fontweight="semibold")
    ax.set_xticks([0, 1], ["P.2001 as it stands", "P.2001 evaluated at ITM's\nd₃ and d₄ and extended"])
    ax.set_xlim(-0.35, 1.45); ax.axhline(0, color=DB, lw=0.6)
    ax.set_ylabel("ITM minus P.2001 (dB)")
    save(fig, "s46_evaluation_point")


def s47_smooth_earth_terms():
    """The two smooth-earth diffraction formulas agree within a few decibels."""
    S = rd("term_smooth_earth.csv")
    fig, ax = new(h=2.8); clean(ax)
    for pol, col, ls in [("vertical", DB, "-"), ("horizontal", LB, (0, (4, 2)))]:
        q = S[S.polarization == pol]
        ax.plot(q.d_km, q.itm_a_se_db - q.p2001_ldsph_db, color=col, lw=2.2, ls=ls)
        ax.text(q.d_km.iloc[-1] + 4, (q.itm_a_se_db - q.p2001_ldsph_db).iloc[-1], pol.capitalize() + "\npolarization",
                color=col, fontsize=8, va="center", fontweight="semibold")
    ax.axhline(0, color=DB, lw=0.6)
    ax.set_xlim(40, 340); ax.set_ylim(-1, 4)
    ax.set_xlabel("Distance (km), smooth earth")
    ax.set_ylabel("ITM smooth-earth term minus\nP.2001 spherical-earth loss (dB)")
    save(fig, "s47_smooth_earth_terms")


def s48_gap_waterfall():
    """Where the diffraction gap comes from: the mean ITM minus P.2001, term by term."""
    C = rd("term_gap_components.csv").set_index("component")
    steps = [("Two horizon edges\nagainst one\nBullington edge", "edges"), ("ITM smooth-earth\nterm", "smooth"),
             ("Clutter term against\nempirical add-on", "addon"), ("ITM line\nextension", "extension"),
             ("Gases and\nother P.2001", "other")]
    vals = [C.loc[k, "mean_db"] for _, k in steps]
    total = C.loc["total", "mean_db"]
    fig, ax = new(h=3.2); clean(ax)
    cum = 0
    for i, ((lab, _), v) in enumerate(zip(steps, vals)):
        ax.bar(i, v, bottom=cum, color=PU if v >= 0 else LG2, width=0.62, edgecolor="white")
        ax.text(i, cum + v + (0.8 if v >= 0 else -0.8), f"{v:+.0f}", ha="center", va="bottom" if v >= 0 else "top", fontsize=9,
                color=DB, fontweight="semibold")
        if i < len(steps) - 1:
            ax.plot([i + 0.31, i + 0.69], [cum + v] * 2, color=GR, lw=0.8)
        cum += v
    ax.bar(len(steps), total, color=DB, width=0.62)
    ax.text(len(steps), total + 0.8, f"{total:.0f} dB", ha="center", va="bottom", fontsize=9, color=DB, fontweight="semibold")
    ax.set_xticks(range(len(steps) + 1), [l for l, _ in steps] + ["ITM minus\nP.2001"], fontsize=7.8)
    ax.set_ylabel("Mean contribution (dB)")
    ax.axhline(0, color=DB, lw=0.6)
    save(fig, "s48_gap_waterfall")


def s49_empirical_terms():
    """Each model's empirical add-on: ITM's clutter term sits near its 15 dB cap; P.2001's grows with distance."""
    D = rd("term_diffraction_links.csv")
    D = D[np.isfinite(D.itm_ad_path_db)]
    fig, ax = new(h=2.9); clean(ax)
    ax.scatter(D.d_km, D.itm_afo_db, s=24, color=LB, edgecolor="white", lw=0.4, zorder=3)
    ax.scatter(D.d_km, D.p2001_empirical_db, s=24, color=DB, edgecolor="white", lw=0.4, zorder=3)
    ax.axhline(15, color=LG2, lw=0.8, ls=(0, (3, 2)))
    ax.text(D.d_km.max(), 15.3, "ITM cap, 15 dB", color=GR, fontsize=7.5, ha="right", va="bottom")
    ax.set_ylim(0, 18); ax.set_xlabel("Path length (km)"); ax.set_ylabel("Empirical add-on (dB)")
    ax.text(12, 13.2, "ITM clutter term A_fo", color=LB, fontsize=8.5, fontweight="semibold")
    ax.text(12, 8.6, "P.2001 (1 − e^(−J/6))(10 + 0.02 d)", color=DB, fontsize=8.5, fontweight="semibold")
    save(fig, "s49_empirical_terms")


def s50_ducting_terms():
    """P.2001's ducting loss, term by term, against ITM at 1% of time over smooth earth."""
    T = rd("term_ducting_smooth.csv")
    t = T[T.time_pct == 1]
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.2), layout="constrained")
    a = axs[0]; clean(a)
    a.plot(t.d_km, t.aad_db, color=PU, lw=2)
    a.plot(t.d_km, t.aat_db, color=DB, lw=2)
    a.axhline(0, color=DB, lw=0.6)
    a.set_xlabel("Distance (km)"); a.set_ylabel("dB")
    a.set_title("P.2001 ducting terms at 1% of time", loc="left", fontsize=9, color=DB)
    a.text(t.d_km.iloc[-1], t.aad_db.iloc[-1] - 3, "Angular distance A_ad", color=PU, fontsize=8, ha="right", va="top")
    a.text(t.d_km.iloc[-1] * 0.62, t.aat_db.iloc[-8] + 12, "Time A_at", color=DB, fontsize=8, ha="right")
    a.text(0.03, 0.95, f"Coupling A_ac: {t.aac_db.median():.0f} dB at every distance", transform=a.transAxes, fontsize=7.8,
           color=GR, va="top")
    b = axs[1]; clean(b)
    b.plot(t.d_km, t.lbm1_excess_db, color=GR, lw=1.0)
    b.plot(t.d_km, t.lbm2_excess_db, color=GR, lw=1.0, ls=(0, (4, 2)))
    b.plot(t.d_km, t.p2001_excess_db, color=DB, lw=2.4)
    b.plot(t.d_km, t.itm_excess_db, color=LB, lw=2.0)
    b.set_ylim(-10, 120); b.set_xlabel("Distance (km)"); b.set_ylabel("Loss above free space (dB)")
    b.set_title("Loss above free space at 1%", loc="left", fontsize=9, color=DB)
    b.text(330, t.itm_excess_db[t.d_km == 350].iloc[0] + 5, "ITM", color=LB, fontsize=8.5, fontweight="semibold")
    b.text(400, t.p2001_excess_db[t.d_km == 400].iloc[0] - 6, "P.2001", color=DB, fontsize=8.5, fontweight="semibold", va="top")
    b.text(110, 100, "P.2001 diffraction", color=GR, fontsize=7.5)
    b.text(560, 60, "P.2001\nducting", color=GR, fontsize=7.5, ha="center")
    save(fig, "s50_ducting_terms")


def s51_monte_carlo():
    """The single-percentage blend against the Monte Carlo combination of P.2001's sub-models."""
    M = rd("term_monte_carlo.csv")
    M = M[(M.time_pct >= 0.01) & (M.time_pct <= 99)]
    fig, ax = new(h=3.0); clean(ax)
    names = list(dict.fromkeys(M.path))
    worst = max(names, key=lambda n: (M[M.path == n].monte_carlo_db - M[M.path == n].blend_db).abs().max())
    for n in names:
        q = M[M.path == n]
        d = q.monte_carlo_db - q.blend_db
        hi = n == worst
        ax.plot(q.time_pct, d, color=PU if hi else LG2, lw=2.2 if hi else 1.2, zorder=3 if hi else 2)
        if hi:
            i = d.abs().idxmax()
            ax.text(q.time_pct[i], d[i] - 0.4, n, color=PU, fontsize=8, ha="center", va="top", fontweight="semibold")
    ax.axhline(0, color=DB, lw=0.6)
    xlog(ax, 0.01, 99, [0.01, 0.1, 1, 10, 50, 99])
    ax.set_xlabel("Time percentage (%), log scale")
    ax.set_ylabel("Monte Carlo minus\nsingle-percentage blend (dB)")
    ax.text(0.012, 0.6, "Gray: smooth earth 50, 120, 300 km; rough western link", color=GR, fontsize=7.5)
    save(fig, "s51_monte_carlo")


ALL = [s38_architecture, s39_smooth_mechanisms, s40_itm_anatomy, s41_line_of_sight, s42_time_mechanisms,
       s43_mechanism_agreement, s44_two_obstacles, s45_roughness_grid, s46_evaluation_point,
       s47_smooth_earth_terms, s48_gap_waterfall, s49_empirical_terms, s50_ducting_terms, s51_monte_carlo]

if __name__ == "__main__":
    for fn in ALL:
        fn()
