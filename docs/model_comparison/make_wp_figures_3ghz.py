"""Simple figures for the 3 GHz working paper.

One idea per figure, one panel where possible, direct labels, NTIA colors:
ITM light blue, P.2001 dark blue, P.452 gray; mechanism classes gray (line
of sight), light blue (diffraction), and purple (troposcatter).

Draws only: every number comes from CSV files the MATLAB analysis writes
(chart_data/ from export_deep_dive_data_rev1, uncertainty_rev1,
sensitivity_rev1, grid_separation_rev1, and paper_numbers_3ghz_rev1;
figures/table_*.csv from make_wp_figures_rev1, diffraction_decomposition_rev1,
compare_dbsg3_rev1, and compare_dbsg3_area_rev1). The study frequency
is read from the data (3000 MHz after run_3ghz_rev1). Writes figures/sNN_*.png.

Run:  run_3ghz_rev1 in MATLAB, then python3 make_wp_figures_3ghz.py
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.special import fresnel

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


def cls(code):
    return "Diffraction" if code in (4, 5, 8, 9) else ("Troposcatter" if code in (6, 10) else "Line of sight")


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


# ---------- data ----------
b = C.bylink[C.bylink.freq_mhz == F0].copy()
b["apart"] = b.itm_50_db - b.p2001_50_db
terms = C.terms[C.terms.freq_mhz == F0].copy()
db = C.db
db1 = db.copy()   # all measured datasets, 30 MHz to 10 GHz
db1["apart"] = db1.itm_50 - db1.p2001_50


# ===================== models =====================
def s01_smooth_earth():
    s = pd.read_csv(CD / "deep_smooth_earth.csv").query("freq_mhz == @F0 and surface == 'land'")
    fig, ax = new(); clean(ax)
    for m in ["p452", "p2001", "itm"]:
        y = s[f"{m}_50_db"] - s.free_space_db
        ax.plot(s.d_km, y, color=MC[m], lw=2.4 if m == "itm" else 1.8, ls="-" if m != "p452" else (0, (4, 2)))
    yl = {m: (s[f"{m}_50_db"] - s.free_space_db).iloc[-1] for m in MC}
    label_end(ax, s.d_km.iloc[-1], yl["itm"], "ITM", LB, dy=-2.5)
    label_end(ax, s.d_km.iloc[-1], yl["p2001"], "P.2001 and P.452", DB, dy=2.5)
    ax.set_xlim(0, 230); ax.set_xlabel("Distance (km)"); ax.set_ylabel("Loss above free space (dB)")
    save(fig, "s01_smooth_earth")


def s02_knife_edge():
    k = pd.read_csv(CD / "deep_knife_edge.csv").query("freq_mhz == @F0 and v >= -1")
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


def J_exact(v):
    S, Cc = fresnel(v)
    return -20 * np.log10(np.sqrt((1 - Cc - S) ** 2 + (Cc - S) ** 2) / 2)


def s03_knife_edge_function():
    v = np.linspace(0, 8, 600)
    itu = 6.9 + 20 * np.log10(np.sqrt((v - 0.1) ** 2 + 1) + v - 0.1)
    itm = np.where(v ** 2 < 5.76, 6.02 + 9.11 * v - 1.27 * v ** 2, 12.953 + 10 * np.log10(np.maximum(v ** 2, 1e-12)))
    fig, ax = new(); clean(ax)
    ax.plot(v, J_exact(v), color=LG, lw=6, solid_capstyle="round")
    ax.plot(v, itu, color=DB, lw=1.6); ax.plot(v, itm, color=LB, lw=1.6, ls=(0, (4, 2)))
    ax.plot(v, 2 * itm, color=LB, lw=2.4)
    label_end(ax, 8, 2 * itm[-1], "ITM's two edges, added", LB)
    label_end(ax, 8, itu[-1], "One edge: J(v) and both approximations", DB)
    ax.set_xlim(0, 13); ax.set_ylim(0, 65); ax.set_xlabel("Fresnel-Kirchhoff parameter v"); ax.set_ylabel("Knife-edge loss (dB)")
    save(fig, "s03_knife_edge_function")


def s04_gap_by_mechanism():
    fig, ax = new(2.6); clean(ax, "x")
    rng = np.random.default_rng(3)
    for i, c in enumerate(CLS):
        v = b[b.itm_class == c].apart.values
        ax.scatter(v, i + rng.uniform(-0.18, 0.18, v.size), s=24, color=CC[c], edgecolor="white", linewidth=0.4, zorder=3)
        m = np.median(v)
        ax.plot([m, m], [i - 0.3, i + 0.3], color=DB, lw=2.4, zorder=4)
        ax.text(m, i - 0.36, f"{0 if abs(m) < 0.5 else m:.0f} dB", ha="center", va="bottom", fontsize=9, fontweight="bold")
    ax.axvline(0, color=DB, lw=0.8)
    ax.set_yticks(range(3), [f"{c} ({(b.itm_class == c).sum()})" for c in CLS]); ax.set_ylim(2.6, -0.7)
    ax.set_xlim(-12, 100); ax.set_xlabel(f"{YL}, {FT}, 50 % of time")
    save(fig, "s04_gap_by_mechanism")


def s05_gap_vs_terrain():
    fig, ax = new(); clean(ax)
    for c in CLS:
        d = b[b.itm_class == c]
        ax.scatter(np.maximum(d.delta_h_m, 3), d.apart, s=26, color=CC[c], edgecolor="white", linewidth=0.4, label=c, zorder=3)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(3, 3000)
    ax.set_xticks([10, 100, 1000], ["10", "100", "1,000"])
    ax.set_xlabel("ITM terrain irregularity Δh (m), log scale"); ax.set_ylabel(YL)
    ax.legend(fontsize=8.5, loc="upper left")
    save(fig, "s05_gap_vs_terrain")


def s06_frequency_sweep():
    s = pd.read_csv(CD / "deep_freq_sweep.csv")
    fig, ax = new(); clean(ax)
    cols = {"Line of sight": "#9AA0A6", "Single-horizon diffraction": LB, "Double-horizon diffraction": DB}
    offs = {"Line of sight": 5, "Single-horizon diffraction": -4, "Double-horizon diffraction": 0}
    for pth, d in s.groupby("path", sort=False):
        g = d.itm_db - d.p2001_db
        ax.plot(d.freq_mhz / 1000, g, color=cols[pth], lw=2.2)
        label_end(ax, d.freq_mhz.iloc[-1] / 1000, g.iloc[-1], pth, cols[pth], dy=offs[pth])
    ax.axvline(F0 / 1000, color=PU, lw=0.8, ls=(0, (3, 3))); ax.text(F0 / 1000 * 1.05, 0.93, FT, color=PU, transform=ax.get_xaxis_transform())
    ax.axvspan(1, 10, color="#F4F6FB", zorder=0)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(0.1, 60)
    ax.set_xticks([0.1, 0.3, 1, 3, 10], ["0.1", "0.3", "1", "3", "10"])
    ax.set_xlabel("Frequency (GHz), log scale"); ax.set_ylabel(f"{YL}, 50 % of time")
    save(fig, "s06_frequency_sweep")


def s07_terrain_resolution():
    T = pd.read_csv(CD / "terrain_resolution_by_link.csv")
    T["apart"] = T.itm_50_db - T.p2001_50_db
    res = ["30 m", "90 m", "1 km smoothed"]
    G = T.pivot(index="link", columns="resolution", values="apart")[res]
    fig, ax = new(w=4.6); clean(ax)
    for _, r in G.iterrows():
        moved = abs(r.iloc[2] - r.iloc[0]) > 10
        ax.plot(range(3), r.values, color=PU if moved else LG, lw=1.4 if moved else 0.9, alpha=0.9, zorder=2 if moved else 1)
    ax.axhline(0, color=DB, lw=0.8)
    ax.set_xticks(range(3), res); ax.set_xlim(-0.2, 2.2); ax.set_ylabel(YL)
    ax.text(0.02, 0.97, f"{len(G)} diffraction links; purple: moved more than 10 dB", transform=ax.transAxes, fontsize=8, color=GR, va="top")
    save(fig, "s07_terrain_resolution")


def s08_diffraction_terms():
    q = terms
    w = q.w_d3
    itm = [(np.median(w * q.A_se_d3), "#C9D3EE", "smooth earth × w"), (np.median((1 - w) * q.A_k_d3), LB, "two knife edges × (1 − w)"),
           (np.median(q.A_fo), DB, "clutter")]
    p452 = [(np.median(q.Lbulla), GR, "one knife edge"), (np.median(np.maximum(q.Ldsph - q.Lbulls, 0)), LG, "")]
    fig, ax = new(2.2); clean(ax, "x")
    for i, (name, parts) in enumerate((("ITM", itm), ("P.452", p452))):
        x = 0
        for v, col, lab in parts:
            ax.barh(i, v, left=x, height=0.6, color=col, edgecolor="white", linewidth=1.5)
            if v > 12:
                ax.text(x + v / 2, i, lab, ha="center", va="center", fontsize=8, color="white" if col in (LB, DB, GR) else DB)
            x += v
        ax.text(x + 1.5, i, f"{x:.0f} dB", va="center", fontweight="bold")
    ax.set_yticks([0, 1], ["ITM", "P.452"]); ax.set_ylim(1.6, -0.6); ax.set_xlim(0, max(x, 120) * 1.15)
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
    rad = pd.read_csv(CD / "deep_radials.csv").query("freq_mhz == @F0")
    se = pd.read_csv(CD / "deep_smooth_earth.csv").query("freq_mhz == @F0 and surface == 'land' and d_km <= 150")
    fig, ax = new(); clean(ax)
    names = {0: "North", 90: "East", 180: "South", 270: "West (Appalachians)"}
    cols = {0: "#A9B8E3", 90: GR, 180: "#B9BDC2", 270: DB}
    ends = {}
    for az, d in rad.groupby("azimuth_deg"):
        g = (d.itm_50_db - d.p2001_50_db).rolling(5, center=True, min_periods=1).median()
        ax.plot(d.d_km, g, color=cols[az], lw=2.4 if az == 270 else 1.6)
        ends[az] = g.iloc[-1]
    gse = se.itm_50_db - se.p2001_50_db
    ax.plot(se.d_km, gse, color=PU, lw=1.6, ls=(0, (4, 2)))
    ys = sorted([(v, k) for k, v in ends.items()] + [(gse.iloc[-1], "se")])
    last = -99
    for v, k in ys:
        y = max(v, last + 5); last = y
        if k == "se":
            label_end(ax, 150, y, "Smooth earth", PU)
        else:
            label_end(ax, 150, y, names[k], cols[k] if k != 180 else GR)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xlim(0, 195)
    ax.set_xlabel("Distance from 38.90 N, 77.45 W (km)"); ax.set_ylabel(YL)
    save(fig, "s10_radials")


def s11_window_by_length():
    fig, ax = new(); clean(ax)
    ax.axvspan(15, 150, color="#EEF1FA", zorder=0)
    ax.text(16, 0.95, "Divergence window", transform=ax.get_xaxis_transform(), fontsize=8.5, color=LB, fontweight="semibold")
    ax.scatter(db1.d_km, db1.apart, s=16, facecolor="none", edgecolor=GR, linewidth=0.7, zorder=2, label="Measured paths, 30 MHz-10 GHz")
    ax.scatter(b.length_km, b.apart, s=24, color=LB, edgecolor="white", linewidth=0.4, zorder=3, label=f"Calculated links, {FT}")
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(8, 900)
    ax.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel(YL); ax.legend(fontsize=8.5, loc="upper right")
    save(fig, "s11_window_by_length")


def s12_the_jump():
    d = terms
    fig, ax = new(); clean(ax)
    ax.axvspan(0, 0.12, color="#EEF1FA", zorder=0)
    ax.scatter(d.w_d3, d.itm_excess_50 - d.p2001_excess_50, s=30, color=LB, edgecolor="white", linewidth=0.5, zorder=3)
    lo = (d.itm_excess_50 - d.p2001_excess_50)[d.w_d3 < 0.12]; hi = (d.itm_excess_50 - d.p2001_excess_50)[d.w_d3 >= 0.12]
    ax.text(0.006, 0.95, f"w under 0.12:\nmedian {lo.median():.0f} dB, {lo.size} links", transform=ax.get_xaxis_transform(), va="top", fontsize=8.5, color=LB, fontweight="semibold")
    ax.text(0.3, hi.median() + 12, f"w 0.12 or more: median {hi.median():.0f} dB, {hi.size} links", fontsize=8.5, color=DB)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xlim(0, 0.6)
    ax.set_xlabel("ITM's weight on smooth-earth diffraction, w"); ax.set_ylabel(YL)
    save(fig, "s12_the_jump")


def s13_anatomy():
    import make_wp_deep_dive_rev1 as D
    D.F0 = F0
    D.fig35()
    import shutil
    shutil.copy(FIG / "fig35_anatomy_of_a_link.png", FIG / "s13_anatomy.png")


def s14_where_window_falls():
    fig, ax = new(3.6); clean(ax, None)
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.scatter(db1.d_km, np.maximum(db1.itm_delta_h_m, 3), s=16, facecolor="none", edgecolor=GR, linewidth=0.7, label="Measured paths, 30 MHz-10 GHz")
    big = b.apart > 20
    ax.scatter(b.length_km[~big], np.maximum(b.delta_h_m[~big], 3), s=34, color=LG, edgecolor="white", label="Calculated links, under 20 dB apart", zorder=3)
    ax.scatter(b.length_km[big], np.maximum(b.delta_h_m[big], 3), s=34, color=DB, edgecolor="white", label="Calculated links, over 20 dB apart", zorder=3)
    ax.axhline(150, color=PU, lw=0.8, ls=(0, (3, 3))); ax.axvline(150, color=PU, lw=0.8, ls=(0, (3, 3)))
    ax.set_xlim(8, 900); ax.set_ylim(3, 3000)
    ax.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"]); ax.set_yticks([10, 100, 1000], ["10", "100", "1,000"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel("Terrain irregularity Δh (m), log scale")
    ax.legend(fontsize=8, loc="lower right")
    save(fig, "s14_where_window_falls")


def s15_window_over_time():
    T = pd.read_csv(CD / "deep_time_by_link.csv").query("freq_mhz == @F0")
    T["c"] = T.itm_mode_code.map(cls); T["apart"] = T.itm_db - T.p2001_db
    fig, ax = new(); clean(ax)
    ends = []
    for c in CLS:
        q = T[(T.c == c) & (T.time_pct <= 99)].groupby("time_pct").apart.median()
        ax.plot(q.index, q.values, color=CC[c], lw=2.6)
        ends.append((q.values[-1], c))
    last = -99
    for v, c in sorted(ends):
        y = max(v, last + 4); last = y
        label_end(ax, 99, y, c, CC[c])
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log"); ax.set_xlim(0.001, 2000)
    ax.set_xticks([0.001, 0.01, 0.1, 1, 10, 50, 99], ["0.001", "0.01", "0.1", "1", "10", "50", "99"])
    ax.set_xlabel("Percentage of time the loss is not exceeded"); ax.set_ylabel(f"{YL}, median over the links")
    save(fig, "s15_window_over_time")


def s16_itm_vs_p452():
    fig, ax = new(3.6, 4.4); clean(ax)
    ax.scatter(terms.p452_excess_50, terms.itm_excess_50, s=28, color=LB, edgecolor="white", linewidth=0.4, zorder=3)
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
    a = pd.read_csv(CD / "deep_archetype_time.csv").query("path == 'Over-sea coastal' and freq_mhz == @F0").sort_values("time_pct")
    fs = 32.45 + 20 * np.log10(F0) + 20 * np.log10(a.length_km.iloc[0])
    p = a.time_pct.values
    fig, ax = new(); clean(ax)
    ax.plot(p, a.itm_db, color=LB, lw=2.6); ax.plot(p[p <= 50], a.p452_db[p <= 50], color=GR, lw=1.8, ls=(0, (4, 2)))
    ax.plot(p, a.p2001_db, color=DB, lw=2.2)
    ax.axhline(fs, color=GR, lw=0.8, ls=(0, (2, 2))); ax.text(0.0013, fs + 1.5, "free space", color=GR, fontsize=8)
    label_end(ax, 0.001, a.itm_db.iloc[0] + 5, "ITM", LB, ha="left")
    label_end(ax, 0.001, a.p2001_db.iloc[0] - 6, "P.2001", DB, ha="left")
    i1 = np.argmin(abs(p - 1))
    ax.annotate("", xy=(1, a.p2001_db.iloc[i1]), xytext=(1, a.itm_db.iloc[i1]), arrowprops=dict(arrowstyle="<->", color=PU))
    ax.text(1.2, (a.p2001_db.iloc[i1] + a.itm_db.iloc[i1]) / 2, f"{a.itm_db.iloc[i1] - a.p2001_db.iloc[i1]:.0f} dB at 1 %", color=PU,
            fontweight="semibold", va="center")
    _time_axis(ax); ax.set_ylabel("Basic transmission loss (dB)")
    save(fig, "s17_over_sea")


def s18_ducting_takeover():
    s = pd.read_csv(CD / "deep_smooth_earth_time.csv").query("freq_mhz == @F0")
    fig, ax = new(); clean(ax)
    for surf, col in (("sea", DB), ("land", GR)):
        q = s[s.surface == surf]
        t = q[q.p2001_mech == 2].groupby("d_km").time_pct.max().reindex(sorted(q.d_km.unique()))
        ax.step(t.index, t.values, where="mid", color=col, lw=2.4)
        label_end(ax, 200, t.dropna().values[-1], f"Over {surf}", col)
    ax.set_yscale("log"); ax.set_ylim(0.05, 60); ax.set_xlim(0, 240)
    ax.set_yticks([0.1, 1, 10, 50], ["0.1 %", "1 %", "10 %", "50 %"])
    ax.set_xlabel("Distance (km)"); ax.set_ylabel("P.2001 uses ducting below\nthis time percentage")
    save(fig, "s18_ducting_takeover")


def s19_enhancement_real():
    T = pd.read_csv(CD / "deep_time_by_link.csv").query("freq_mhz == @F0")
    T["c"] = T.itm_mode_code.map(cls)
    g = T.set_index(["link", "c", "time_pct"])
    r = pd.DataFrame({"itm": g.itm_db.xs(50.0, level=2) - g.itm_db.xs(1.0, level=2),
                      "p2001": g.p2001_db.xs(50.0, level=2) - g.p2001_db.xs(1.0, level=2)}).reset_index()
    fig, ax = new(2.6); clean(ax, "x")
    for i, c in enumerate(CLS):
        q = r[r.c == c]
        a1, a2 = q.itm.median(), q.p2001.median()
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
    a = pd.read_csv(CD / "deep_archetype_time.csv").query("freq_mhz == @F0")
    paths = list(dict.fromkeys(a.path))
    fig, axs = plt.subplots(1, len(paths), figsize=(W, 2.6), layout="constrained")
    for ax, pth in zip(axs, paths):
        clean(ax)
        q = a[a.path == pth].sort_values("time_pct")
        q50 = q[q.time_pct == 50]
        for m in ["itm", "p2001"]:
            ax.plot(q.time_pct, q[f"{m}_db"] - q50[f"{m}_db"].iloc[0], color=MC[m], lw=2)
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
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.5), layout="constrained")
    cmap = mpl.colors.LinearSegmentedColormap.from_list("gap", ["#F2F3F5", "#A9B8E3", LB, DB])
    norm = mpl.colors.Normalize(0, 60)
    for ax, site, title in ((axs[0], "dc", "Washington, DC"), (axs[1], "la", "Los Angeles")):
        G = pd.read_csv(CD / f"grid_{site}.csv")
        gap = (G.itm_50 - G.p2001_50).clip(lower=0)
        ax.scatter(G.dx_km, G.dy_km, c=gap, cmap=cmap, norm=norm, s=62, marker="s", linewidths=0)
        ax.scatter([0], [0], marker="*", s=160, color=PU, edgecolor="white", zorder=3)
        ax.set_aspect("equal"); ax.set_xlim(-53, 53); ax.set_ylim(-53, 53)
        ax.set_xticks([-50, 0, 50]); ax.set_yticks([-50, 0, 50]); ax.tick_params(length=0)
        for sp in ax.spines.values():
            sp.set_visible(False)
        ax.set_title(title, loc="left"); ax.set_xlabel("km east of the receiver")
    axs[0].set_ylabel("km north of the receiver")
    cb = fig.colorbar(mpl.cm.ScalarMappable(norm, cmap), ax=axs, shrink=0.8, pad=0.01)
    cb.outline.set_visible(False); cb.set_label(f"ITM minus P.2001 at {FT}, 50 % (dB)")
    save(fig, "s29_grid_maps")


def s30_grid_exclusion():
    fig, axs = plt.subplots(1, 2, figsize=(W, 3.0), sharey=True, layout="constrained")
    for ax, site, title in ((axs[0], "dc", "Washington, DC"), (axs[1], "la", "Los Angeles")):
        clean(ax)
        E = pd.read_csv(CD / f"grid_{site}_exclusion.csv").query("time_pct == 50")
        for m, ls in (("p2001", "-"), ("itm", "-")):
            q = E[E.model == m]
            ax.plot(q.required_loss_db, q.area_km2 / 1000, color=MC[m], lw=2.4, ls=ls)
            label_end(ax, q.required_loss_db.iloc[-1], q.area_km2.iloc[-1] / 1000, ML[m] if m == "itm" else "P.2001, P.452", MC[m])
        ax.set_title(title, loc="left"); ax.set_xlabel("Required loss (dB)"); ax.set_xlim(110, 198)
    axs[0].set_ylabel("Area where a single transmitter\nwould exceed the criterion (1,000 km²)")
    save(fig, "s30_grid_exclusion")


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
       s26_uncertainty_gap, s27_uncertainty_measured, s28_sensitivity, s29_grid_maps, s30_grid_exclusion, s31_area_measurements]

if __name__ == "__main__":
    for fn in ALL:
        fn()
