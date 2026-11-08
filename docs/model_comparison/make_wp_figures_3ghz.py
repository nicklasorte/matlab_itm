"""Simple figures for the 3 GHz working paper.

One idea per figure, one panel where possible, direct labels, NTIA colors:
ITM light blue, P.2001 dark blue, P.452 gray; mechanism classes gray (line
of sight), light blue (diffraction), and purple (troposcatter).

Draws only: every number and derived quantity comes from CSV files the
MATLAB analysis writes (chart_data/figures/fig_*.csv from
figure_data_3ghz_rev1; chart_data/ from export_deep_dive_data_rev1,
uncertainty_rev1, sensitivity_rev1, grid_separation_rev1,
grid_convergence_rev1, and paper_numbers_3ghz_rev1;
figures/table_*.csv from make_wp_figures_rev1, diffraction_decomposition_rev1,
compare_dbsg3_rev1, and compare_dbsg3_area_rev1). The study frequency
is read from the data (3000 MHz after run_3ghz_rev1). Writes figures/sNN_*.png.

Run:  run_3ghz_rev1 in MATLAB, then python3 make_wp_figures_3ghz.py
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import make_wp_charts_rev1 as C
from make_wp_charts_rev1 import DB, LB, PU, GR, LG, PANEL, CD, FIG

mpl.rcParams.update({"font.size": 9.5, "axes.titlesize": 10})
F0 = int(C.FREQS[0])
FT = f"{F0 / 1000:g} GHz"
MC = {"itm": LB, "p452": GR, "p2001": DB}
ML = {"itm": "ITM", "p452": "P.452", "p2001": "P.2001"}
CC = {"Line of sight": "#9AA0A6", "Diffraction": LB, "Troposcatter": PU}
CLS = ["Line of sight", "Diffraction", "Troposcatter"]
YL = "ITM minus P.2001 (dB)"
W, H = 6.5, 3.2


def new(h=H, w=W, **kw):
    fig, ax = plt.subplots(figsize=(w, h), layout="constrained", **kw)
    return fig, ax


def clean(ax, grid="y"):
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    if grid:
        getattr(ax, f"{grid}axis").grid(True, color="#E9E9E9", lw=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)


def save(fig, name):
    fig.savefig(FIG / f"{name}.png", dpi=220)
    plt.close(fig)
    print("wrote", name)


def label_end(ax, x, y, text, color, dy=0, **kw):
    ax.text(x, y + dy, " " + text, color=color, va="center", fontsize=9, fontweight="semibold", **kw)


def stack_labels(ax, x, items, gap=None):
    """items: list of (y, text, color); places end labels without overlap."""
    lo, hi = ax.get_ylim(); gap = gap or (hi - lo) * 0.06
    last = -1e9
    for y, t, c in sorted(items):
        y = max(y, last + gap); last = y
        label_end(ax, x, y, t, c)


# ---------- data: tables written by figure_data_3ghz_rev1.m ----------
FD = CD / "figures"
rf = lambda f: pd.read_csv(FD / f)


# ===================== models =====================
def s01_smooth_earth():
    s = rf("fig_s01_smooth_earth.csv")
    fig, ax = new(); clean(ax)
    for m in ["p452", "p2001", "itm"]:
        ax.plot(s.d_km, s[f"{m}_above_fs_db"], color=MC[m], lw=2.4 if m == "itm" else 1.8, ls="-" if m != "p452" else (0, (4, 2)))
    label_end(ax, s.d_km.iloc[-1], s.itm_above_fs_db.iloc[-1], "ITM", LB, dy=-2.5)
    label_end(ax, s.d_km.iloc[-1], s.p2001_above_fs_db.iloc[-1], "P.2001 and P.452", DB, dy=2.5)
    ax.set_xlim(0, 230); ax.set_xlabel("Distance (km)"); ax.set_ylabel("Loss above free space (dB)")
    save(fig, "s01_smooth_earth")


def s02_knife_edge():
    k = rf("fig_s02_knife_edge.csv")
    fig, ax = new(); clean(ax)
    ax.plot(k.v, k.J_db, color="#222222", lw=1.2, ls=(0, (2, 2)))
    for m in ["p452", "p2001", "itm"]:
        ax.plot(k.v, k[f"{m}_db"], color=MC[m], lw=2.4 if m == "itm" else 1.8)
    x = k.v.iloc[-1]
    label_end(ax, x, k.itm_db.iloc[-1], "ITM", LB)
    label_end(ax, x, k.p2001_db.iloc[-1], "P.2001 and P.452", DB)
    label_end(ax, x, k.J_db.iloc[-1], "J(v), ITU-R P.526", "#222222", dy=-2)
    ax.set_xlim(-1, x * 1.35); ax.set_xlabel("Fresnel-Kirchhoff parameter v"); ax.set_ylabel("Loss above free space (dB)")
    save(fig, "s02_knife_edge")


def s03_knife_edge_function():
    k = rf("fig_s03_knife_edge_function.csv")
    fig, ax = new(); clean(ax)
    ax.plot(k.v, k.J_db, color=LG, lw=6, solid_capstyle="round")
    ax.plot(k.v, k.itu_db, color=DB, lw=1.6); ax.plot(k.v, k.itm_one_edge_db, color=LB, lw=1.6, ls=(0, (4, 2)))
    ax.plot(k.v, k.itm_two_edges_db, color=LB, lw=2.4)
    label_end(ax, k.v.iloc[-1], k.itm_two_edges_db.iloc[-1], "ITM's two edges, added", LB)
    label_end(ax, k.v.iloc[-1], k.itu_db.iloc[-1], "One edge: J(v) and both approximations", DB)
    ax.set_xlim(0, 13); ax.set_ylim(0, 65); ax.set_xlabel("Fresnel-Kirchhoff parameter v"); ax.set_ylabel("Knife-edge loss (dB)")
    save(fig, "s03_knife_edge_function")


def s04_gap_by_mechanism():
    L = rf("fig_links_gap.csv"); M = rf("fig_s04_class_medians.csv").set_index("itm_class")
    fig, ax = new(2.6); clean(ax, "x")
    rng = np.random.default_rng(3)          # horizontal jitter for display only
    for i, c in enumerate(CLS):
        v = L[L.itm_class == c].itm_minus_p2001_db.values
        ax.scatter(v, i + rng.uniform(-0.18, 0.18, v.size), s=24, color=CC[c], edgecolor="white", linewidth=0.4, zorder=3)
        m = M.loc[c, "median_db"]
        ax.plot([m, m], [i - 0.3, i + 0.3], color=DB, lw=2.4, zorder=4)
        ax.text(m, i - 0.36, f"{0 if abs(m) < 0.5 else m:.0f} dB", ha="center", va="bottom", fontsize=9, fontweight="bold")
    ax.axvline(0, color=DB, lw=0.8)
    ax.set_yticks(range(3), [f"{c} ({int(M.loc[c, 'links'])})" for c in CLS]); ax.set_ylim(2.6, -0.7)
    ax.set_xlim(-12, 100); ax.set_xlabel(f"{YL}, {FT}, 50 % of time")
    save(fig, "s04_gap_by_mechanism")


def s05_gap_vs_terrain():
    L = rf("fig_links_gap.csv")
    fig, ax = new(); clean(ax)
    for c in CLS:
        d = L[L.itm_class == c]
        ax.scatter(np.maximum(d.delta_h_m, 3), d.itm_minus_p2001_db, s=26, color=CC[c], edgecolor="white", linewidth=0.4, label=c, zorder=3)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(3, 3000)
    ax.set_xticks([10, 100, 1000], ["10", "100", "1,000"])
    ax.set_xlabel("ITM terrain irregularity Δh (m), log scale"); ax.set_ylabel(YL)
    ax.legend(fontsize=8.5, loc="upper left")
    save(fig, "s05_gap_vs_terrain")


def s06_frequency_sweep():
    s = rf("fig_s06_frequency_sweep.csv")
    fig, ax = new(); clean(ax)
    cols = {"Line of sight": "#9AA0A6", "Single-horizon diffraction": LB, "Double-horizon diffraction": DB}
    offs = {"Line of sight": 5, "Single-horizon diffraction": -4, "Double-horizon diffraction": 0}
    for pth, d in s.groupby("path", sort=False):
        ax.plot(d.freq_mhz / 1000, d.itm_minus_p2001_db, color=cols[pth], lw=2.2)
        label_end(ax, d.freq_mhz.iloc[-1] / 1000, d.itm_minus_p2001_db.iloc[-1], pth, cols[pth], dy=offs[pth])
    ax.axvline(F0 / 1000, color=PU, lw=0.8, ls=(0, (3, 3))); ax.text(F0 / 1000 * 1.05, 0.93, FT, color=PU, transform=ax.get_xaxis_transform())
    ax.axvspan(1, 10, color="#F4F6FB", zorder=0)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(0.1, 60)
    ax.set_xticks([0.1, 0.3, 1, 3, 10], ["0.1", "0.3", "1", "3", "10"])
    ax.set_xlabel("Frequency (GHz), log scale"); ax.set_ylabel(f"{YL}, 50 % of time")
    save(fig, "s06_frequency_sweep")


def s07_terrain_resolution():
    G = rf("fig_s07_terrain_resolution.csv")
    res = ["30 m", "90 m", "1 km smoothed"]
    fig, ax = new(w=4.6); clean(ax)
    for _, r in G.iterrows():
        mv = bool(r.moved_over_10db)
        ax.plot(range(3), [r[c] for c in res], color=PU if mv else LG, lw=1.4 if mv else 0.9, alpha=0.9, zorder=2 if mv else 1)
    ax.axhline(0, color=DB, lw=0.8)
    ax.set_xticks(range(3), res); ax.set_xlim(-0.2, 2.2); ax.set_ylabel(YL)
    ax.text(0.02, 0.97, f"{len(G)} diffraction links; purple: moved more than 10 dB", transform=ax.transAxes, fontsize=8, color=GR, va="top")
    save(fig, "s07_terrain_resolution")


def s08_diffraction_terms():
    t = rf("fig_s08_diffraction_terms.csv")
    col = {"smooth earth × w": "#C9D3EE", "two knife edges × (1 − w)": LB, "clutter": DB, "one knife edge": GR, "spherical-earth excess": LG}
    fig, ax = new(2.2); clean(ax, "x")
    xmax = 0
    for i, name in enumerate(["ITM", "P.452"]):
        x = 0
        for _, r in t[t.model == name].iterrows():
            ax.barh(i, r.median_db, left=x, height=0.6, color=col[r.term], edgecolor="white", linewidth=1.5)
            if r.median_db > 12:
                ax.text(x + r.median_db / 2, i, r.term, ha="center", va="center", fontsize=8, color="white" if col[r.term] in (LB, DB, GR) else DB)
            x += r.median_db
        ax.text(x + 1.5, i, f"{x:.0f} dB", va="center", fontweight="bold"); xmax = max(xmax, x)
    ax.set_yticks([0, 1], ["ITM", "P.452"]); ax.set_ylim(1.6, -0.6); ax.set_xlim(0, max(xmax, 120) * 1.15)
    ax.set_xlabel(f"Median diffraction loss above free space on the diffraction links, {FT} (dB)")
    save(fig, "s08_diffraction_terms")


def s09_ablation():
    a = C.abl[C.abl.freq_mhz == F0]
    cases = [("ITM as is", "ITM as published"), ("2 no clutter term", "Without the clutter term"),
             ("3 evaluated at the path", "Evaluated at the path"), ("1 single edge", "One knife edge, not two"),
             ("4 all three", "All three removed")]
    fig, ax = new(2.6); clean(ax, "x")
    for i, (c, lab) in enumerate(cases):
        v = a[a["case"] == c].median_gap_db.iloc[0]
        ax.plot([0, v], [i, i], color=LG, lw=2.5, zorder=1)
        ax.scatter([v], [i], s=70, color=LB if i == 0 else DB, zorder=3, edgecolor="white")
        ax.text(v + (2 if v >= 0 else -2), i, f"{v:.0f} dB", va="center", ha="left" if v >= 0 else "right", fontsize=9, fontweight="semibold")
    ax.axvline(0, color=DB, lw=0.8)
    ax.set_yticks(range(5), [l for _, l in cases]); ax.set_ylim(4.6, -0.6); ax.set_xlim(-20, 60)
    ax.set_xlabel(f"Median ITM minus P.452 diffraction loss, {FT} (dB)")
    save(fig, "s09_ablation")


# ===================== where they diverge =====================
def s10_radials():
    R = rf("fig_s10_radials.csv")
    fig, ax = new(); clean(ax)
    names = {0: "North", 90: "East", 180: "South", 270: "West (Appalachians)", -1: "Smooth earth"}
    cols = {0: "#A9B8E3", 90: GR, 180: "#B9BDC2", 270: DB, -1: PU}
    ends = []
    for az, d in R.groupby("azimuth_deg"):
        ax.plot(d.d_km, d.gap_smoothed, color=cols[az], lw=2.4 if az == 270 else 1.6, ls=(0, (4, 2)) if az == -1 else "-")
        ends.append((d.gap_smoothed.iloc[-1], names[az], cols[az] if az != 180 else GR))
    ax.axhline(0, color=DB, lw=0.8); ax.set_xlim(0, 195)
    stack_labels(ax, 150, ends)
    ax.set_xlabel("Distance from 38.90 N, 77.45 W (km)"); ax.set_ylabel(YL)
    save(fig, "s10_radials")


def s11_window_by_length():
    L = rf("fig_links_gap.csv"); Mp = rf("fig_measured_paths.csv")
    fig, ax = new(); clean(ax)
    ax.axvspan(15, 150, color="#EEF1FA", zorder=0)
    ax.text(16, 0.95, "Divergence window", transform=ax.get_xaxis_transform(), fontsize=8.5, color=LB, fontweight="semibold")
    ax.scatter(Mp.d_km, Mp.itm_minus_p2001_db, s=16, facecolor="none", edgecolor=GR, linewidth=0.7, zorder=2, label="Measured paths, 30 MHz-10 GHz")
    ax.scatter(L.length_km, L.itm_minus_p2001_db, s=24, color=LB, edgecolor="white", linewidth=0.4, zorder=3, label=f"Calculated links, {FT}")
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(8, 900)
    ax.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel(YL); ax.legend(fontsize=8.5, loc="upper right")
    save(fig, "s11_window_by_length")


def s12_the_jump():
    d = rf("fig_diffraction_links.csv")
    fig, ax = new(); clean(ax)
    ax.axvspan(0, 0.12, color="#EEF1FA", zorder=0)
    ax.scatter(d.w_d3, d.itm_minus_p2001_db, s=30, color=LB, edgecolor="white", linewidth=0.5, zorder=3)
    lo = d[d.group == "w under 0.12"]; hi = d[d.group == "w 0.12 or more"]
    ax.text(0.006, 0.95, f"w under 0.12:\nmedian {lo.group_median_db.iloc[0]:.0f} dB, {len(lo)} links", transform=ax.get_xaxis_transform(), va="top",
            fontsize=8.5, color=LB, fontweight="semibold")
    ax.text(0.3, hi.group_median_db.iloc[0] + 12, f"w 0.12 or more: median {hi.group_median_db.iloc[0]:.0f} dB, {len(hi)} links", fontsize=8.5, color=DB)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xlim(0, 0.6)
    ax.set_xlabel("ITM's weight on smooth-earth diffraction, w"); ax.set_ylabel(YL)
    save(fig, "s12_the_jump")


def s13_anatomy():
    pr = rf("fig_s13_profile.csv"); g = rf("fig_s13_geometry.csv").set_index("point"); t = rf("fig_s13_terms.csv")
    d, z = pr.d_km, pr.height_with_bulge_m
    D = g.loc["rx", "d_km"]
    fig = plt.figure(figsize=(6.5, 5.4), layout="constrained")
    gs = fig.add_gridspec(2, 1, height_ratios=[1.25, 1])
    ax = fig.add_subplot(gs[0])
    top = z.max() + 700
    ax.fill_between(d, z.min() - 50, z, color="#E4E7EC", lw=0); ax.plot(d, z, color=GR, lw=0.8)
    for e in ("tx", "rx"):
        ax.plot([g.loc[e, "d_km"], g.loc[e + "_horizon", "d_km"]], [g.loc[e, "z_m"], g.loc[e + "_horizon", "z_m"]], color=LB, lw=1.4)
        ax.plot([g.loc[e + "_horizon", "d_km"], g.loc["bullington", "d_km"]], [g.loc[e + "_horizon", "z_m"], g.loc["bullington", "z_m"]], color=GR, lw=1, ls=(0, (3, 2)))
        ax.scatter([g.loc[e + "_horizon", "d_km"]], [g.loc[e + "_horizon", "z_m"]], s=60, marker="^", color=LB, zorder=4, edgecolor="white")
        ax.text(g.loc[e + "_horizon", "d_km"], g.loc[e + "_horizon", "z_m"] + 40, ("Transmitter's" if e == "tx" else "Receiver's") + "\nhorizon", ha="center", fontsize=8, color=LB)
    ax.scatter([0, D], [g.loc["tx", "z_m"], g.loc["rx", "z_m"]], s=30, color=DB, zorder=4)
    xb, zb = g.loc["bullington", "d_km"], g.loc["bullington", "z_m"]
    ax.annotate(f"The two rays meet {zb / 1000:.1f} km up at {xb:.0f} km:\nthe Bullington point P.452 and P.2001 use", xy=(xb, top - 20),
                xytext=(xb - 2, top - 330), ha="right", fontsize=8, color=DB, arrowprops=dict(arrowstyle="->", color=DB, lw=0.8))
    ax.set_xlim(-1, D + 1); ax.set_ylim(z.min() - 50, top)
    ax.set_xlabel("Distance (km)"); ax.set_ylabel("Height with earth bulge (m)")
    ax.set_title(f"Double-horizon diffraction link, {D:.0f} km, Appalachians", loc="left")
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    a2 = fig.add_subplot(gs[1]); clean(a2, "x")
    col = {"smooth earth × w": "#C9D3EE", "two knife edges × (1 − w)": LB, "clutter": DB}
    for i, mdl in enumerate(["ITM", "P.452", "P.2001"]):
        x = 0
        q = t[t.model == mdl]
        for _, r in q.iterrows():
            c = col.get(r.term, GR)
            a2.barh(i, r.value_db, left=x, height=0.7, color=c, edgecolor="white", linewidth=1.5)
            a2.text(x + r.value_db / 2, i, r.term, ha="center", va="center", fontsize=6.8, color="white" if c in (LB, DB, GR) else DB)
            x += r.value_db
        a2.text(x + 2, i, f"{q.model_total_db.iloc[0]:.0f} dB at 50 %", va="center", fontsize=8.5, fontweight="semibold")
    a2.set_yticks(range(3), ["ITM", "P.452", "P.2001"]); a2.set_ylim(2.6, -0.6); a2.set_xlim(0, 185)
    a2.set_xlabel(f"Diffraction loss above free space at {FT} (dB)")
    save(fig, "s13_anatomy")


def s14_where_window_falls():
    L = rf("fig_links_gap.csv"); Mp = rf("fig_measured_paths.csv")
    fig, ax = new(3.6); clean(ax, None)
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.scatter(Mp.d_km, np.maximum(Mp.delta_h_m, 3), s=16, facecolor="none", edgecolor=GR, linewidth=0.7, label="Measured paths, 30 MHz-10 GHz")
    big = L.over_20db.astype(bool)
    ax.scatter(L.length_km[~big], np.maximum(L.delta_h_m[~big], 3), s=34, color=LG, edgecolor="white", label="Calculated links, under 20 dB apart", zorder=3)
    ax.scatter(L.length_km[big], np.maximum(L.delta_h_m[big], 3), s=34, color=DB, edgecolor="white", label="Calculated links, over 20 dB apart", zorder=3)
    ax.axhline(150, color=PU, lw=0.8, ls=(0, (3, 3))); ax.axvline(150, color=PU, lw=0.8, ls=(0, (3, 3)))
    ax.set_xlim(8, 900); ax.set_ylim(3, 3000)
    ax.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"]); ax.set_yticks([10, 100, 1000], ["10", "100", "1,000"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel("Terrain irregularity Δh (m), log scale")
    ax.legend(fontsize=8, loc="lower right")
    save(fig, "s14_where_window_falls")


def s15_window_over_time():
    T = rf("fig_s15_time_by_class.csv")
    fig, ax = new(); clean(ax)
    ends = []
    for c in CLS:
        q = T[(T.itm_class == c) & (T.time_pct <= 99)]
        ax.plot(q.time_pct, q.median_itm_minus_p2001_db, color=CC[c], lw=2.6)
        ends.append((q.median_itm_minus_p2001_db.iloc[-1], c, CC[c]))
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(0.001, 2000)
    stack_labels(ax, 99, ends)
    ax.set_xticks([0.001, 0.01, 0.1, 1, 10, 50, 99], ["0.001", "0.01", "0.1", "1", "10", "50", "99"])
    ax.set_xlabel("Percentage of time the loss is not exceeded"); ax.set_ylabel(f"{YL}, median over the links")
    save(fig, "s15_window_over_time")


def s16_itm_vs_p452():
    d = rf("fig_diffraction_links.csv")
    fig, ax = new(3.6, 4.4); clean(ax)
    ax.scatter(d.p452_excess_db, d.itm_excess_db, s=28, color=LB, edgecolor="white", linewidth=0.4, zorder=3)
    x = np.array([0, 110]); ax.plot(x, x, color=GR, lw=1); ax.plot(x, 2 * x, color=GR, lw=0.8, ls=(0, (3, 3)))
    ax.text(95, 88, "equal", color=GR, fontsize=8, ha="right"); ax.text(62, 130, "twice", color=GR, fontsize=8)
    ax.set_xlim(0, 100); ax.set_ylim(0, 170)
    ax.set_xlabel("P.452 diffraction loss above free space (dB)"); ax.set_ylabel("ITM diffraction loss above free space (dB)")
    save(fig, "s16_itm_vs_p452")


# ===================== ducting =====================
def _time_axis(ax):
    ax.set_xscale("log"); ax.set_xlim(0.001, 99.99)
    ax.set_xticks([0.001, 0.01, 0.1, 1, 10, 50, 99], ["0.001", "0.01", "0.1", "1", "10", "50", "99"])
    ax.set_xlabel("Percentage of time the loss is not exceeded")


def s17_over_sea():
    a = rf("fig_archetypes_time.csv").query("path == 'Over-sea coastal'").sort_values("time_pct")
    p = a.time_pct.values; fs = a.free_space_db.iloc[0]
    fig, ax = new(); clean(ax)
    ax.plot(p, a.itm_db, color=LB, lw=2.6); ax.plot(p[p <= 50], a.p452_db[p <= 50], color=GR, lw=1.8, ls=(0, (4, 2)))
    ax.plot(p, a.p2001_db, color=DB, lw=2.2)
    ax.axhline(fs, color=GR, lw=0.8, ls=(0, (2, 2))); ax.text(0.0013, fs + 1.5, "free space", color=GR, fontsize=8)
    label_end(ax, 0.001, a.itm_db.iloc[0] + 5, "ITM", LB, ha="left")
    label_end(ax, 0.001, a.p2001_db.iloc[0] - 6, "P.2001", DB, ha="left")
    r1 = a[a.time_pct == 1].iloc[0]
    ax.annotate("", xy=(1, r1.p2001_db), xytext=(1, r1.itm_db), arrowprops=dict(arrowstyle="<->", color=PU))
    ax.text(1.2, (r1.p2001_db + r1.itm_db) / 2, f"{r1.itm_db - r1.p2001_db:.0f} dB at 1 %", color=PU, fontweight="semibold", va="center")
    _time_axis(ax); ax.set_ylabel("Basic transmission loss (dB)")
    save(fig, "s17_over_sea")


def s18_ducting_takeover():
    s = rf("fig_s18_ducting_takeover.csv")
    fig, ax = new(); clean(ax)
    for surf, col in (("sea", DB), ("land", GR)):
        q = s[s.surface == surf]
        ax.step(q.d_km, q.max_ducting_time_pct, where="mid", color=col, lw=2.4)
        label_end(ax, 200, q.max_ducting_time_pct.dropna().iloc[-1], f"Over {surf}", col)
    ax.set_yscale("log"); ax.set_ylim(0.05, 60); ax.set_xlim(0, 240)
    ax.set_yticks([0.1, 1, 10, 50], ["0.1 %", "1 %", "10 %", "50 %"])
    ax.set_xlabel("Distance (km)"); ax.set_ylabel("P.2001 uses ducting below\nthis time percentage")
    save(fig, "s18_ducting_takeover")


def s19_enhancement_real():
    r = rf("fig_s19_enhancement_real.csv").set_index("itm_class")
    fig, ax = new(2.6); clean(ax, "x")
    for i, c in enumerate(CLS):
        a1, a2 = r.loc[c, "itm_50_minus_1_db"], r.loc[c, "p2001_50_minus_1_db"]
        ax.plot([a1, a2], [i, i], color=LG, lw=3)
        ax.scatter([a1], [i], s=70, color=LB, zorder=3, edgecolor="white"); ax.scatter([a2], [i], s=70, color=DB, zorder=3, edgecolor="white")
        if i == 0:
            ax.text(a1, i - 0.32, "ITM", ha="center", color=LB, fontsize=8.5, fontweight="semibold")
            ax.text(a2, i - 0.32, "P.2001", ha="center", color=DB, fontsize=8.5, fontweight="semibold")
    ax.set_yticks(range(3), CLS); ax.set_ylim(2.6, -0.8); ax.set_xlim(0, 25)
    ax.set_xlabel(f"Median loss at 50 % minus loss at 1 % of time, {FT} (dB)")
    save(fig, "s19_enhancement_real")


def s20_enhancement_measured():
    t = pd.read_csv(CD / "meas_enhancement_by_distance.csv")
    fig, ax = new(); clean(ax); ends = []
    for key, col, lab, lw in (("meas", "#222222", "Measured", 3), ("itm", LB, "ITM", 2.2), ("p2001", DB, "P.2001", 2.2)):
        q = t[(t.series == key) & (t.n >= 3)]
        ax.plot(q.d_mid_km, q.median_db, "-o", color=col, lw=lw, ms=5, mec="white")
        ends.append((q.median_db.iloc[-1], lab, col)); xe = q.d_mid_km.iloc[-1]
    ax.set_xscale("log"); ax.set_xlim(20, 1500); ax.set_ylim(0, 35)
    stack_labels(ax, xe, ends)
    ax.set_xticks([30, 100, 300, 1000], ["30", "100", "300", "1,000"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel("Median loss at 50 % minus\nloss at 1 % of time (dB)")
    save(fig, "s20_enhancement_measured")


def s21_archetypes():
    a = rf("fig_archetypes_time.csv")
    paths = list(dict.fromkeys(a.path))
    fig, axs = plt.subplots(1, len(paths), figsize=(W, 2.6), layout="constrained")
    for ax, pth in zip(axs, paths):
        clean(ax)
        q = a[a.path == pth].sort_values("time_pct")
        for m in ["itm", "p2001"]:
            ax.plot(q.time_pct, q[f"{m}_minus_50_db"], color=MC[m], lw=2)
        ax.axhline(0, color=DB, lw=0.6); ax.set_xscale("log"); ax.set_xlim(0.001, 99.99); ax.set_ylim(-80, 30)
        ax.set_xticks([0.01, 1, 50], ["0.01", "1", "50"]); ax.set_title(pth.replace(" diffraction", "\ndiffraction").replace(" coastal", "\ncoastal"), fontsize=8.5)
        if ax is not axs[0]:
            ax.set_yticklabels([])
    axs[0].set_ylabel("Loss minus its 50 % value (dB)")
    axs[0].text(0.002, 18, "ITM", color=LB, fontweight="bold", fontsize=8.5); axs[0].text(0.002, -60, "P.2001", color=DB, fontweight="bold", fontsize=8.5)
    fig.supxlabel("Percentage of time", fontsize=9)
    save(fig, "s21_archetypes")



def s22_distance_threshold():
    t = pd.read_csv(FIG / "table_distance_to_threshold.csv").query("freq_mhz == @F0")
    fig, ax = new(w=4.6); clean(ax)
    for m, mk in (("p452", "s"), ("p2001", "o"), ("itm", "o")):
        ax.plot(t.threshold_db, t[f"land_{m}_km"], marker=mk, color=MC[m], lw=2, ms=6, mec="white")
    label_end(ax, t.threshold_db.iloc[-1], t.land_itm_km.iloc[-1] + 2, "ITM", LB)
    label_end(ax, t.threshold_db.iloc[-1], t.land_p2001_km.iloc[-1] - 2, "P.2001, P.452", DB)
    ax.set_xlim(t.threshold_db.min() - 2, t.threshold_db.max() + 9)
    ax.set_xlabel("Loss threshold (dB)"); ax.set_ylabel("Distance to reach it,\nsmooth land (km)")
    save(fig, "s22_distance_threshold")


# ===================== measurements =====================
def s23_error_vs_frequency():
    t = pd.read_csv(CD / "meas_error_by_band.csv")
    bins = C.BINS
    fig, ax = new(); clean(ax); ends = []
    for m in ["p452", "p2001", "itm"]:
        q = t[t.model == m].set_index("band").reindex(bins)
        y = np.where(q.n >= 3, q.median_error_db, np.nan)
        ax.plot(range(6), y, "-o", color=MC[m], lw=2.4 if m == "itm" else 1.8, ms=6, mec="white")
        ends.append((y[-1], ML[m], MC[m]))
    ax.axhline(0, color=DB, lw=0.8)
    stack_labels(ax, 5, ends)
    ax.set_xticks(range(6), bins); ax.set_xlim(-0.3, 6.1)
    ax.set_ylabel("Median predicted minus\nmeasured loss at 50 % (dB)")
    save(fig, "s23_error_vs_frequency")


def s24_error_vs_time():
    t = pd.read_csv(CD / "meas_error_by_time.csv")
    pv = [1, 10, 50, 90, 99]
    fig, ax = new(); clean(ax); ends = []
    for m in ["p452", "p2001", "itm"]:
        q = t[(t.model == m) & (t.n > 0)]
        ax.plot(q.time_pct, q.mean_error_db, "-o", color=MC[m], lw=2.4 if m == "itm" else 1.8, ms=6, mec="white")
        ends.append((q.mean_error_db.iloc[-1], ML[m], MC[m]))
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(0.8, 250)
    stack_labels(ax, 99, ends)
    ax.set_xticks(pv, ["1 %", "10 %", "50 %", "", "99 %"]); ax.set_xlabel("Percentage of time")
    ax.set_ylabel("Mean predicted minus\nmeasured loss (dB)")
    save(fig, "s24_error_vs_time")


def s25_error_vs_terrain():
    t = pd.read_csv(CD / "meas_error_by_dh.csv")
    fig, ax = new(); clean(ax); ends = []
    for m in ["p452", "p2001", "itm"]:
        q = t[t.model == m]
        y = np.where(q.n >= 3, q.median_error_db, np.nan)
        ax.plot(q.dh_mid_m, y, "-o", color=MC[m], lw=2.4 if m == "itm" else 1.8, ms=6, mec="white")
        ends.append((y[-1], ML[m], MC[m])); xe = q.dh_mid_m.iloc[-1]
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(10, 3000)
    stack_labels(ax, xe, ends)
    ax.set_xticks([10, 100, 1000], ["10", "100", "1,000"]); ax.set_xlabel("Terrain irregularity Δh (m), log scale")
    ax.set_ylabel("Median predicted minus\nmeasured loss at 50 % (dB)")
    save(fig, "s25_error_vs_terrain")



# ===================== uncertainty, sensitivity, grids, point-to-area =====================
def s26_uncertainty_gap():
    U = pd.read_csv(CD / "uncertainty_summary.csv")
    fig, ax = new(2.9); clean(ax, "x")
    for i, r in U.iterrows():
        col = CC.get(r.quantity.replace(" links", ""), DB if "under" in r.quantity else LB)
        ax.plot([r.ci_low_db, r.ci_high_db], [i, i], color=col, lw=6, alpha=0.35, solid_capstyle="round")
        ax.scatter([r.median_db], [i], s=60, color=col, edgecolor="white", zorder=3)
        z = lambda x: f"{0 if abs(x) < 0.5 else x:.0f}"
        ax.text(r.ci_high_db + 1.5, i, f"{z(r.median_db)} dB ({z(r.ci_low_db)} to {z(r.ci_high_db)})", va="center", fontsize=8.5)
    ax.axvline(0, color=DB, lw=0.8)
    ax.set_yticks(range(len(U)), [f"{q} ({n})" for q, n in zip(U.quantity, U.n)]); ax.set_ylim(len(U) - 0.4, -0.6)
    ax.set_xlim(-10, 80); ax.set_xlabel(f"Median ITM minus P.2001 at {FT} with its 95 % bootstrap interval (dB)")
    save(fig, "s26_uncertainty_gap")


def s27_uncertainty_measured():
    M = pd.read_csv(CD / "uncertainty_measurements.csv")
    fig, ax = new(3.0); clean(ax, "x")
    y, ticks, labs = 0, [], []
    for g in ["All", "30 MHz-1 GHz", "1-10 GHz"]:
        for m in ["itm", "p452", "p2001"]:
            r = M[(M.group == g) & (M.model == m)]
            if r.empty:
                continue
            r = r.iloc[0]
            ax.plot([r.ci_low_db, r.ci_high_db], [y, y], color=MC[m], lw=6, alpha=0.35, solid_capstyle="round")
            ax.scatter([r.mean_error_db], [y], s=55, color=MC[m], edgecolor="white", zorder=3)
            ticks.append(y); labs.append(f"{ML[m]}, {g}"); y += 1
        y += 0.6
    ax.axvline(0, color=DB, lw=0.8)
    ax.set_yticks(ticks, labs); ax.set_ylim(y - 0.4, -0.6); ax.set_xlim(-6, 4)
    ax.set_xlabel("Mean predicted minus measured loss at 50 %, with 95 % interval (dB)")
    save(fig, "s27_uncertainty_measured")


def s28_sensitivity():
    S = pd.read_csv(CD / "sensitivity_summary.csv")
    q = S[(S.itm_class == "Diffraction") & (S.model == "itm")].copy()
    base = q[q["case"] == "baseline"].median_gap_to_p2001_db.iloc[0]
    q = q.iloc[::-1]
    fig, ax = new(4.4); clean(ax, "x")
    ax.axvspan(base - 3, base + 3, color="#EEF1FA", zorder=0)
    for i, (_, r) in enumerate(q.iterrows()):
        b0 = r["case"] == "baseline"
        ax.plot([base, r.median_gap_to_p2001_db], [i, i], color=LG, lw=2)
        ax.scatter([r.median_gap_to_p2001_db], [i], s=60 if b0 else 44, color=DB if b0 else LB, edgecolor="white", zorder=3)
        ax.text(max(base, r.median_gap_to_p2001_db) + 1, i, f"{r.median_gap_to_p2001_db:.0f} dB", va="center", fontsize=8.5)
    ax.set_yticks(range(len(q)), [("ITM " + c if c != "baseline" else "ITM baseline") for c in q["case"]])
    ax.set_xlim(0, 60); ax.set_xlabel(f"Median ITM minus P.2001 on the diffraction links, {FT} (dB); band: baseline ± 3 dB")
    save(fig, "s28_sensitivity")


def s29_grid_maps():
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.7), layout="constrained")
    cmap = mpl.colors.LinearSegmentedColormap.from_list("gap", ["#F2F3F5", "#A9B8E3", LB, DB])
    norm = mpl.colors.Normalize(0, 60)
    for ax, site, title in ((axs[0], "dc", "Washington, DC"), (axs[1], "la", "Los Angeles")):
        G = rf(f"fig_grid_{site}.csv"); Bm = rf(f"fig_grid_{site}_basemap.csv")
        x = np.sort(G.dx_km.unique()); y = np.sort(G.dy_km.unique())
        piv = lambda c: G.pivot_table(index="dy_km", columns="dx_km", values=c).reindex(index=y, columns=x).values
        ax.pcolormesh(x, y, np.clip(piv("itm_minus_p2001_db"), 0, None), cmap=cmap, norm=norm, shading="nearest", rasterized=True)
        ax.plot(Bm.dx_km, Bm.dy_km, color="white", lw=0.9, alpha=0.9); ax.plot(Bm.dx_km, Bm.dy_km, color=GR, lw=0.5)
        for c, col, ls in (("p2001_excluded_160", PU, "-"), ("itm_excluded_160", "#222222", (0, (3, 2)))):
            ax.contour(x, y, piv(c).astype(float), levels=[0.5], colors=[col], linewidths=1.6, linestyles=[ls])
        ax.scatter([0], [0], marker="*", s=150, color=PU, edgecolor="white", zorder=4)
        ax.set_aspect("equal"); ax.set_xlim(-152, 152); ax.set_ylim(-152, 152)
        ax.set_xticks([-150, 0, 150]); ax.set_yticks([-150, 0, 150]); ax.tick_params(length=0)
        for sp in ax.spines.values():
            sp.set_visible(False)
        ax.set_title(title, loc="left"); ax.set_xlabel("km east of the receiver")
    axs[0].set_ylabel("km north of the receiver")
    axs[1].text(0.02, 0.02, "Purple line: P.2001 exclusion at 160 dB\nBlack dashed line: ITM exclusion at 160 dB", transform=axs[1].transAxes,
                fontsize=7.5, color=DB, va="bottom", bbox=dict(boxstyle="round,pad=0.25", fc="white", ec="none", alpha=0.85))
    cb = fig.colorbar(mpl.cm.ScalarMappable(norm, cmap), ax=axs, shrink=0.8, pad=0.01)
    cb.outline.set_visible(False); cb.set_label(f"ITM minus P.2001 at {FT}, 50 % (dB)")
    save(fig, "s29_grid_maps")


def s30_grid_exclusion():
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.0), sharey=True, layout="constrained")
    for ax, site, title in ((axs[0], "dc", "Washington, DC"), (axs[1], "la", "Los Angeles")):
        clean(ax)
        E = pd.read_csv(CD / f"grid_{site}_150km_2p5km_exclusion.csv").query("time_pct == 50")
        for m in ("p2001", "itm"):
            q = E[E.model == m]
            ax.plot(q.required_loss_db, q.area_km2 / 1000, color=MC[m], lw=2.4)
            label_end(ax, q.required_loss_db.iloc[-1], q.area_km2.iloc[-1] / 1000, ML[m] if m == "itm" else "P.2001, P.452", MC[m])
        ax.set_title(title, loc="left"); ax.set_xlabel("Required loss (dB)"); ax.set_xlim(110, 222)
    axs[0].set_ylabel("Area where a single transmitter\nwould exceed the criterion (1,000 km²)")
    save(fig, "s30_grid_exclusion")


def s32_grid_convergence():
    Cv = pd.read_csv(CD / "grid_convergence.csv").query("required_loss_db == 160 and model in ['itm', 'p2001']")
    fig, axs = plt.subplots(1, 2, figsize=(W, 2.9), sharey=True, layout="constrained")
    for ax, site, title in ((axs[0], "dc", "Washington, DC"), (axs[1], "la", "Los Angeles")):
        clean(ax)
        for m in ("p2001", "itm"):
            q = Cv[(Cv.site == site) & (Cv.model == m)]
            a25 = q[q.step_km == 2.5].sort_values("half_width_km"); a5 = q[q.step_km == 5].sort_values("half_width_km"); a1 = q[q.step_km == 1]
            ax.plot(2 * a25.half_width_km, a25.area_km2 / 1000, "-o", color=MC[m], lw=2.2, ms=6, mec="white")
            ax.scatter(2 * a5.half_width_km, a5.area_km2 / 1000, s=40, facecolor="white", edgecolor=MC[m], linewidth=1.4, zorder=3)
            ax.scatter(2 * a1.half_width_km, a1.area_km2 / 1000, s=40, marker="D", color=MC[m], edgecolor="white", zorder=3)
            label_end(ax, 300, a25.area_km2.iloc[-1] / 1000, ML[m] if m == "itm" else "P.2001", MC[m])
        ax.set_title(title, loc="left"); ax.set_xticks([100, 200, 300]); ax.set_xlim(80, 360); ax.set_xlabel("Grid width (km)")
    axs[0].set_ylabel("Exclusion area at 160 dB\n(1,000 km²)")
    axs[0].text(0.03, 0.97, "filled circle: 2.5 km step\nopen circle: 5 km step\ndiamond: 1 km step", transform=axs[0].transAxes, fontsize=7.5, color=GR, va="top")
    save(fig, "s32_grid_convergence")



def s31_area_measurements():
    f = CD / "meas_area_error_by_band.csv"
    if not f.exists():
        return
    t = pd.read_csv(f)
    bins = [b for b in ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-2 GHz", "2-3 GHz"] if (t[t.band == b].n >= 5).any()]
    fig, ax = new(); clean(ax); ends = []
    for m in ["p452", "p2001", "itm"]:
        q = t[t.model == m].set_index("band").reindex(bins)
        y = np.where(q.n >= 5, q.mean_error_db, np.nan)
        ax.plot(range(len(bins)), y, "-o", color=MC[m], lw=2.4 if m == "itm" else 1.8, ms=6, mec="white")
        ok = ~np.isnan(y)
        ends.append((y[ok][-1], ML[m], MC[m])); xe = np.arange(len(bins))[ok][-1]
    ax.axhline(0, color=DB, lw=0.8)
    stack_labels(ax, xe, ends)
    ax.set_xticks(range(len(bins)), bins); ax.set_xlim(-0.3, len(bins) + 0.3)
    ax.set_ylabel("Mean predicted minus measured\nlocation-median loss (dB)")
    save(fig, "s31_area_measurements")


ALL = [s01_smooth_earth, s02_knife_edge, s03_knife_edge_function, s04_gap_by_mechanism, s05_gap_vs_terrain, s06_frequency_sweep,
       s07_terrain_resolution, s08_diffraction_terms, s09_ablation, s10_radials, s11_window_by_length, s12_the_jump, s13_anatomy,
       s14_where_window_falls, s15_window_over_time, s16_itm_vs_p452, s17_over_sea, s18_ducting_takeover, s19_enhancement_real,
       s20_enhancement_measured, s21_archetypes, s22_distance_threshold, s23_error_vs_frequency, s24_error_vs_time, s25_error_vs_terrain,
       s26_uncertainty_gap, s27_uncertainty_measured, s28_sensitivity, s29_grid_maps, s30_grid_exclusion, s31_area_measurements, s32_grid_convergence]

if __name__ == "__main__":
    for fn in ALL:
        fn()
