"""Diffraction and ducting sections of the working paper: seven report figures.

Diffraction
  fig38  the knife-edge function: ITU-R P.526 J(v) from the Fresnel
         integrals, the P.452 and P.2001 approximation, and ITM's
         approximation, with each one's difference from J(v)
  fig39  frequency scaling: dB of extra diffraction loss per doubling of
         frequency on each diffraction link, one edge against two
  fig40  ITM's diffraction loss against P.452's on every diffraction link
Ducting
  fig41  the over-sea coastal archetype over the time distribution
  fig42  the time percentage below which ducting is P.2001's and P.452's
         lowest-loss mechanism, against distance, over land and sea
  fig43  how much stronger the signal gets 1 % of the time on each real
         link, P.2001 against ITM, by mechanism
  fig44  the same enhancement on the measured databank paths

Reads CSV only (chart_data/, figures/table_*.csv). Writes figures/fig38-44.
Run:  python3 export_deep_dive_data_rev1.py; python3 make_wp_mechanisms_rev1.py
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.special import fresnel

import make_wp_charts_rev1 as C
from make_wp_charts_rev1 import DB, LB, PU, GR, LG, PANEL, CD, FIG, FREQS, FLAB, FCOL, soft

mpl.rcParams.update({"font.size": 9, "axes.titlesize": 9.5})
CC = {"Line of sight": "#9AA0A6", "Diffraction": LB, "Troposcatter": PU}
F0 = 2700


def cls(code):
    return "Diffraction" if code in (4, 5, 8, 9) else ("Troposcatter" if code in (6, 10) else "Line of sight")


def save(fig, name):
    fig.savefig(FIG / f"{name}.png", dpi=220)
    plt.close(fig)
    print("wrote", name)


# ---------------- diffraction ----------------
def J_exact(v):
    S, Cc = fresnel(v)
    return -20 * np.log10(np.sqrt((1 - Cc - S) ** 2 + (Cc - S) ** 2) / 2)


def J_itu(v):
    return 6.9 + 20 * np.log10(np.sqrt((v - 0.1) ** 2 + 1) + v - 0.1)


def J_itm(v):
    v2 = v ** 2
    return np.where(v2 < 5.76, 6.02 + 9.11 * v - 1.27 * v2, 12.953 + 10 * np.log10(np.maximum(v2, 1e-12)))


def fig38():
    v = np.linspace(0, 10, 800)
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(6.5, 4.6), sharex=True, gridspec_kw=dict(height_ratios=[2, 1]),
                                 layout="constrained")
    soft(a1, "y"); soft(a2, "y")
    a1.plot(v, J_exact(v), color=GR, lw=4, alpha=0.5)
    a1.plot(v, J_itu(v), color=DB, lw=1.8)
    a1.plot(v, J_itm(v), color=LB, lw=1.8, ls=(0, (4, 2)))
    a1.text(9.8, J_exact(9.8) - 4.5, "J(v), Fresnel integrals (wide gray)", color=GR, ha="right", fontsize=8.5)
    a1.text(4.6, 9.5, "ITM, per edge: 6.02 + 9.11v − 1.27v² below v = 2.4,\n12.953 + 20 log v above; ITM adds two edges", color=LB, fontsize=8.5)
    a1.text(4.6, 3.0, "P.452 and P.2001, one edge:\n6.9 + 20 log(√((v − 0.1)² + 1) + v − 0.1)", color=DB, fontsize=8.5)
    a1.set_ylabel("Knife-edge loss (dB)"); a1.set_ylim(0, 35)
    a2.axhline(0, color=DB, lw=0.8)
    a2.plot(v, J_itu(v) - J_exact(v), color=DB, lw=1.8, label="P.452 and P.2001")
    a2.plot(v, J_itm(v) - J_exact(v), color=LB, lw=1.8, ls=(0, (4, 2)), label="ITM")
    a2.set_ylabel("Minus J(v) (dB)"); a2.set_ylim(-1.5, 1.5); a2.set_xlabel("Fresnel-Kirchhoff parameter v")
    a2.legend(fontsize=8, loc="lower right", ncol=2)
    a2.set_xlim(0, 10)
    save(fig, "fig38_knife_edge_function")


def fig39():
    t = C.terms
    P = t.pivot_table(index="link", columns="freq_mhz", values=["Lbulla", "A_k_d3", "itm_excess_50", "p452_excess_50"])
    o = np.log2(7250 / 2700)
    rows = [("P.452 one knife edge (Bullington)", (P.Lbulla[7250] - P.Lbulla[2700]) / o, GR),
            ("P.452 total diffraction", (P.p452_excess_50[7250] - P.p452_excess_50[2700]) / o, GR),
            ("ITM two knife edges, A_k", (P.A_k_d3[7250] - P.A_k_d3[2700]) / o, LB),
            ("ITM total diffraction", (P.itm_excess_50[7250] - P.itm_excess_50[2700]) / o, LB)]
    fig, ax = plt.subplots(figsize=(6.5, 2.9), layout="constrained"); soft(ax)
    for x0, lab, ha, dx in ((3.01, "3 dB: one edge", "right", -0.15), (6.02, "6 dB: two edges", "left", 0.15)):
        ax.axvline(x0, color=PU, lw=0.8, ls=(0, (3, 3)))
        ax.text(x0 + dx, 3.5, lab, color=PU, fontsize=8, ha=ha, va="center")
    rng = np.random.default_rng(1)
    for i, (lab, s, col) in enumerate(rows):
        s = s.dropna().values
        ax.scatter(s, i + rng.uniform(-0.18, 0.18, s.size), s=16, color=col, alpha=0.75, edgecolor="none")
        m = np.median(s)
        ax.plot([m, m], [i - 0.3, i + 0.3], color=DB, lw=2.2)
        ax.text(m, i - 0.36, f"{m:.1f}", ha="center", va="bottom", fontsize=8.5, fontweight="semibold")
    ax.set_yticks(range(4), [r[0] for r in rows]); ax.set_ylim(3.75, -0.7); ax.set_xlim(-1, 18)
    ax.set_xlabel("Extra diffraction loss per doubling of frequency, 2.7 GHz to 7.25 GHz (dB)")
    save(fig, "fig39_frequency_scaling")


def fig40():
    t = C.terms
    fig, ax = plt.subplots(figsize=(5.2, 4.2), layout="constrained"); soft(ax, "y")
    for f in FREQS:
        q = t[t.freq_mhz == f]
        ax.scatter(q.p452_excess_50, q.itm_excess_50, s=22, color=FCOL[f], edgecolor="white", linewidth=0.4, label=FLAB[f], zorder=3)
    x = np.array([0, 110])
    ax.plot(x, x, color=GR, lw=1); ax.plot(x, 2 * x, color=GR, lw=0.8, ls=(0, (3, 3)))
    ax.text(100, 96, "equal", color=GR, fontsize=8, ha="right"); ax.text(72, 150, "twice", color=GR, fontsize=8)
    ax.set_xlim(0, 105); ax.set_ylim(0, 175)
    ax.set_xlabel("P.452 diffraction loss above free space (dB)"); ax.set_ylabel("ITM diffraction loss above free space (dB)")
    ax.legend(fontsize=8, loc="upper left")
    save(fig, "fig40_itm_against_p452_diffraction")


# ---------------- ducting ----------------
def fig41():
    a = pd.read_csv(CD / "deep_archetype_time.csv").query("path == 'Over-sea coastal' and freq_mhz == @F0").sort_values("time_pct")
    fs = 32.45 + 20 * np.log10(F0) + 20 * np.log10(a.length_km.iloc[0])
    p = a.time_pct.values
    fig, ax = plt.subplots(figsize=(6.5, 3.5), layout="constrained"); soft(ax, "y")
    duct = a.p2001_mech.values == 2
    edges = np.where(np.diff(np.r_[0, duct.astype(int), 0]))[0]
    for s0, s1 in zip(edges[::2], edges[1::2]):
        ax.axvspan(p[s0], p[min(s1, len(p) - 1)], color="#F1ECF6", zorder=0)
    ax.text(0.0012, 207, "Ducting is P.2001's lowest-loss mechanism", color=PU, fontsize=8)
    ax.fill_between(p, a.itm_c10_db, a.itm_c90_db, color=LB, alpha=0.15, lw=0)
    ax.plot(p, a.itm_db, color=LB, lw=2.6)
    ax.plot(p[p <= 50], a.p452_db[p <= 50], color=GR, lw=2)
    ax.plot(p, a.p2001_db, color=DB, lw=2.2)
    ax.axhline(fs, color=GR, lw=0.8, ls=(0, (2, 2)))
    ax.text(0.0012, fs + 2, "free space", color=GR, fontsize=8)
    i1 = np.argmin(abs(p - 1))
    ax.annotate("", xy=(1, a.p2001_db.iloc[i1]), xytext=(1, a.itm_db.iloc[i1]), arrowprops=dict(arrowstyle="<->", color=PU, lw=1))
    ax.text(1.15, (a.p2001_db.iloc[i1] + a.itm_db.iloc[i1]) / 2, f"{a.itm_db.iloc[i1] - a.p2001_db.iloc[i1]:.0f} dB at 1 %",
            color=PU, fontsize=8.5, fontweight="semibold", va="center")
    ax.text(99.99, a.itm_db.iloc[-1] - 13, "ITM (band: 10 % to 90 %\nconfidence)", color=LB, fontsize=8, ha="right")
    ax.text(0.0012, a.p2001_db.iloc[0] - 6, "P.2001", color=DB, fontsize=8.5, fontweight="semibold")
    ax.text(0.004, a.p452_db.iloc[0] + 4, "P.452", color=GR, fontsize=8.5, fontweight="semibold")
    ax.set_xscale("log"); ax.set_xlim(0.001, 99.99)
    ax.set_xticks([0.001, 0.01, 0.1, 1, 10, 50, 99], ["0.001", "0.01", "0.1", "1", "10", "50", "99"])
    ax.set_xlabel("Percentage of time the loss is not exceeded"); ax.set_ylabel("Basic transmission loss (dB)")
    ax.set_title(f"Over-sea coastal path, {a.length_km.iloc[0]:.0f} km, 2.7 GHz", loc="left")
    save(fig, "fig41_over_sea_time_distribution")


def fig42():
    s = pd.read_csv(CD / "deep_smooth_earth_time.csv").query("freq_mhz == @F0")
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 3.0), sharey=True, layout="constrained")
    for ax, surf in ((a1, "land"), (a2, "sea")):
        soft(ax, "y")
        q = s[s.surface == surf]
        for m, col, lab, ls in (("p2001", DB, "P.2001", "-"), ("p452", GR, "P.452", (0, (4, 2)))):
            t = q[q[f"{m}_mech"] == 2].groupby("d_km").time_pct.max().reindex(sorted(q.d_km.unique()))
            ax.step(t.index, t.values, where="mid", color=col, lw=2.2, ls=ls, label=lab)
        ax.set_yscale("log"); ax.set_ylim(0.05, 60); ax.set_xlim(0, 200)
        ax.set_yticks([0.1, 1, 10, 50], ["0.1 %", "1 %", "10 %", "50 %"])
        ax.set_title(f"Smooth {surf}, 2.7 GHz", loc="left"); ax.set_xlabel("Distance (km)")
    a1.set_ylabel("Ducting is the lowest loss\nbelow this time percentage")
    a2.legend(fontsize=8, loc="lower right")
    a1.text(5, 0.07, "ITM: no ducting at any percentage", color=LB, fontsize=8)
    save(fig, "fig42_where_ducting_takes_over")


def fig43():
    T = pd.read_csv(CD / "deep_time_by_link.csv").query("freq_mhz == @F0")
    T["cls"] = T.itm_mode_code.map(cls)
    W = T.pivot_table(index=["link", "cls"], columns="time_pct", values=["itm_db", "p2001_db"]).reset_index()
    itm = W[("itm_db", 50.0)] - W[("itm_db", 1.0)]
    p01 = W[("p2001_db", 50.0)] - W[("p2001_db", 1.0)]
    fig, ax = plt.subplots(figsize=(5.4, 4.2), layout="constrained"); soft(ax, "y")
    for c in ["Line of sight", "Diffraction", "Troposcatter"]:
        s = W.cls == c
        ax.scatter(itm[s], p01[s], s=30, color=CC[c], edgecolor="white", linewidth=0.5, label=c, zorder=3)
    ax.plot([0, 40], [0, 40], color=GR, lw=1); ax.text(33, 35, "equal", color=GR, fontsize=8, rotation=35)
    ax.set_xlim(-1, 40); ax.set_ylim(-1, 40)
    ax.set_xlabel("ITM: loss at 50 % minus loss at 1 % (dB)"); ax.set_ylabel("P.2001: loss at 50 % minus loss at 1 % (dB)")
    ax.legend(fontsize=8, loc="upper left")
    ax.text(0.97, 0.03, "60 real-terrain links, 2.7 GHz", transform=ax.transAxes, ha="right", fontsize=8, color=GR)
    save(fig, "fig43_enhancement_by_mechanism")


def fig44():
    d = C.db[C.db.freq_mhz >= 1000].copy()
    fig, ax = plt.subplots(figsize=(6.5, 3.4), layout="constrained"); soft(ax, "y")
    ed = np.array([0, 60, 120, 200, 300, 450, 900]); xm = np.sqrt(np.maximum(ed[:-1], 20) * ed[1:])
    ax.scatter(d.d_km, d.meas_50 - d.meas_01, s=14, facecolor="none", edgecolor=GR, linewidth=0.7, label="Measured, each dataset")
    for key, col, lab, lw in (("meas", "#222222", "Measured", 2.8), ("itm", LB, "ITM", 2.2), ("p452", GR, "P.452", 1.8), ("p2001", DB, "P.2001", 2.2)):
        v = d[f"{key}_50"] - d[f"{key}_01"]
        b = np.digitize(d.d_km, ed) - 1
        m = [np.nanmedian(v[b == i]) if (b == i).sum() >= 3 else np.nan for i in range(len(xm))]
        ax.plot(xm, m, "-o", color=col, lw=lw, ms=5, mec="white", label=f"{lab}, median by distance", zorder=4)
    ax.set_xscale("log"); ax.set_xlim(8, 900); ax.set_ylim(-2, 50)
    ax.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel("Loss at 50 % minus loss at 1 % (dB)")
    ax.legend(fontsize=7.5, loc="upper left", ncol=2)
    save(fig, "fig44_enhancement_measured")


if __name__ == "__main__":
    for fn in [fig38, fig39, fig40, fig41, fig42, fig43, fig44]:
        fn()
