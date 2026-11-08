"""Deep dive: where ITM and the ITU models start to diverge, at 2.7 GHz.

Six report figures, all at one frequency (2.7 GHz) and 50 % of time unless
noted, from CSV only (chart_data/ and figures/table_*.csv):
  fig32  the divergence window: ITM minus P.2001 against distance on four
         real-terrain radials and smooth earth, and on the real-terrain
         links and measured databank paths out to 800 km
  fig33  the jump: ITM minus P.2001 against ITM's smooth-earth weight w
  fig34  two groups: each diffraction link at 30 m and 1 km smoothed
  fig35  anatomy of one link: the profile, the horizons, and how each
         model's diffraction loss adds up
  fig36  where the window falls: path length against terrain irregularity
  fig37  the window over the time distribution

Run:  python3 export_deep_dive_data_rev1.py; python3 make_wp_deep_dive_rev1.py
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import make_wp_charts_rev1 as C
from make_wp_charts_rev1 import DB, LB, PU, GR, LG, PANEL, CD, FIG, soft

mpl.rcParams.update({"font.size": 9, "axes.titlesize": 9.5})
F0 = 2700
CC = {"Line of sight": "#9AA0A6", "Diffraction": LB, "Troposcatter": PU}
YL = "ITM minus P.2001 (dB)"


def cls(code):
    return "Diffraction" if code in (4, 5, 8, 9) else ("Troposcatter" if code in (6, 10) else "Line of sight")


def save(fig, name):
    fig.savefig(FIG / f"{name}.png", dpi=220)
    plt.close(fig)
    print("wrote", name)


b = C.bylink[C.bylink.freq_mhz == F0].copy()
b["apart"] = b.itm_50_db - b.p2001_50_db
terms = C.terms[C.terms.freq_mhz == F0].copy()
terms["apart"] = terms.itm_excess_50 - terms.p2001_excess_50
db = C.db[C.db.freq_mhz >= 1000].copy()
db["apart"] = db.itm_50 - db.p2001_50


# ---------- fig32: the divergence window ----------
def fig32():
    rad = pd.read_csv(CD / "deep_radials.csv").query("freq_mhz == @F0")
    se = pd.read_csv(CD / "deep_smooth_earth.csv").query("freq_mhz == @F0 and surface == 'land'")
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 3.4), gridspec_kw=dict(width_ratios=[1.05, 1]), layout="constrained")
    soft(a1, "y")
    names = {0: "North", 90: "East (coastal plain)", 180: "South (Piedmont)", 270: "West (Appalachians)"}
    cols = {0: "#9DB0E3", 90: GR, 180: "#B9BDC2", 270: DB}
    for az, d in rad.groupby("azimuth_deg"):
        g = d.itm_50_db - d.p2001_50_db
        a1.plot(d.d_km, g, color=cols[az], lw=2.4 if az == 270 else 1.6, zorder=3 if az == 270 else 2)
        yl = {0: g.iloc[-1], 90: -1, 180: -6.5, 270: g.iloc[-1]}[az]
        a1.text(152, yl, names[az], color=cols[az] if az != 180 else GR, fontsize=8, va="center",
                fontweight="semibold" if az == 270 else "normal")
    a1.plot(se.d_km, se.itm_50_db - se.p2001_50_db, color=PU, lw=1.6, ls=(0, (4, 2)))
    a1.text(152, -12, "Smooth earth", color=PU, fontsize=8, va="center")
    a1.axhline(0, color=DB, lw=0.8)
    a1.set_xlim(0, 150); a1.set_ylim(-15, 75); a1.set_xlabel("Distance from 38.90 N, 77.45 W (km)"); a1.set_ylabel(YL)
    a1.set_title("Four radials, 30 m and 10 m antennas", loc="left")
    a1.annotate("East and south split,\nthen rejoin past 80 km", xy=(38, 20), xytext=(85, 12), fontsize=8, color=GR,
                arrowprops=dict(arrowstyle="->", color=GR, lw=0.8))
    soft(a2, "y")
    a2.axvspan(15, 150, color="#EEF1FA", zorder=0)
    a2.text(17, 70, "Divergence window", fontsize=8, color=LB, fontweight="semibold")
    for c in ["Line of sight", "Diffraction", "Troposcatter"]:
        d = b[b.itm_class == c]
        a2.scatter(d.length_km, d.apart, s=20, color=CC[c], edgecolor="white", linewidth=0.4, zorder=3, label=f"{c}, calculated links")
    a2.scatter(db.d_km, db.apart, s=18, facecolor="none", edgecolor=GR, linewidth=0.8, zorder=2, label="Measured paths, 1-10 GHz")
    a2.axhline(0, color=DB, lw=0.8)
    a2.set_xscale("log"); a2.set_xlim(8, 900); a2.set_ylim(-25, 75)
    a2.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"])
    a2.set_xlabel("Path length (km), log scale"); a2.set_title("Links and measured paths", loc="left")
    h, l = a2.get_legend_handles_labels()
    fig.legend(h, ["Line of sight (calculated)", "Diffraction (calculated)", "Troposcatter (calculated)", "Measured paths, 1-10 GHz"],
               loc="outside lower center", ncol=4, fontsize=7.5, handletextpad=0.2, columnspacing=1)
    save(fig, "fig32_divergence_window")


# ---------- fig33: the jump ----------
def fig33():
    d = terms.copy()
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 3.1), gridspec_kw=dict(width_ratios=[3, 1], wspace=0.05),
                                 sharey=True, layout="constrained")
    soft(a1, "y")
    a1.axvspan(0, 0.12, color="#EEF1FA", zorder=0)
    sh = d.itm_mode_code == 5
    a1.scatter(d.w_d3[~sh], d.apart[~sh], s=34, color=LB, edgecolor="white", linewidth=0.5, zorder=3, label="Two horizons")
    a1.scatter(d.w_d3[sh], d.apart[sh], s=34, marker="D", color=DB, edgecolor="white", linewidth=0.5, zorder=3, label="One horizon")
    lo, hi = d.apart[d.w_d3 < 0.12], d.apart[d.w_d3 >= 0.12]
    a1.text(0.005, 72, f"w under 0.12: median {lo.median():.0f} dB\n({lo.size} links)", fontsize=8.5, color=LB, fontweight="semibold", va="top")
    a1.text(0.3, 30, f"w 0.12 or more: median {hi.median():.0f} dB\n({hi.size} links)", fontsize=8.5, color=DB, va="top")
    a1.axhline(0, color=DB, lw=0.8)
    a1.set_xlim(0, 0.6); a1.set_ylim(-8, 85)
    a1.set_xlabel("ITM's weight on smooth-earth diffraction, w at $d_3$"); a1.set_ylabel(YL)
    a1.legend(fontsize=8, loc="center right")
    a2.hist(d.apart, bins=np.arange(-10, 90, 5), orientation="horizontal", color=LG, edgecolor="white")
    a2.set_xlabel("Links"); a2.spines["left"].set_visible(False); a2.tick_params(labelleft=False)
    save(fig, "fig33_the_jump")


# ---------- fig34: two groups ----------
def fig34():
    T = pd.read_csv(CD / "terrain_resolution_by_link.csv")
    T["apart"] = T.itm_50_db - T.p2001_50_db
    G = T.pivot(index="link", columns="resolution", values="apart").sort_values("30 m")
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 3.9), gridspec_kw=dict(width_ratios=[1.5, 1]), layout="constrained")
    soft(a1)
    for i, (k, r) in enumerate(G.iterrows()):
        moved = abs(r["1 km smoothed"] - r["30 m"]) > 10
        col = PU if moved else LG
        a1.plot([r["30 m"], r["1 km smoothed"]], [i, i], color=col, lw=1.6 if moved else 1.2, zorder=1)
        a1.scatter([r["30 m"]], [i], s=22, color="white", edgecolor=DB, linewidth=1.2, zorder=3)
        a1.scatter([r["1 km smoothed"]], [i], s=22, color=PU if moved else DB, zorder=3)
    a1.axvline(0, color=DB, lw=0.8); a1.set_yticks([]); a1.spines["left"].set_visible(False)
    a1.set_xlabel(YL); a1.set_xlim(-12, 85)
    a1.text(84, 1, "open: 30 m profile\nfilled: smoothed over 1 km\npurple: moved more than 10 dB", fontsize=7.5, color=GR, ha="right")
    a1.set_title(f"{len(G)} diffraction links, sorted by the 30 m result", loc="left")
    soft(a2, "y")
    ed = np.arange(-10, 90, 5)
    a2.hist(G["30 m"], ed, color=LB, alpha=0.9, label="30 m")
    a2.hist(G["1 km smoothed"], ed, histtype="step", color=PU, lw=1.8, label="1 km smoothed")
    a2.set_xlabel(YL); a2.set_ylabel("Links"); a2.legend(fontsize=8)
    a2.set_title(f"Median {G['30 m'].median():.0f} dB → {G['1 km smoothed'].median():.0f} dB", loc="left")
    save(fig, "fig34_two_groups")


# ---------- fig35: anatomy of one link ----------
def fig35():
    pr = pd.read_csv(CD / "deep_archetype_profiles.csv").query("path == 'Double-horizon diffraction'")
    t = C.terms[(C.terms.link == pr.link.iloc[0]) & (C.terms.freq_mhz == F0)].iloc[0]
    d, h = pr.d_km.values, pr.h_m.values
    D, a = d[-1], 8500.0
    bulge = d * (D - d) / (2 * a) * 1000
    z = h + bulge
    ztx, zrx = z[0] + pr.htx_m.iloc[0], z[-1] + pr.hrx_m.iloc[0]
    st = (z[1:-1] - ztx) / d[1:-1]; i1 = 1 + np.argmax(st)
    sr = (z[1:-1] - zrx) / (D - d[1:-1]); i2 = 1 + np.argmax(sr)
    # Bullington point: intersection of the two horizon rays
    s1, s2 = st[i1 - 1], -sr[i2 - 1]
    xb = (zrx - s2 * D - ztx) / (s1 - s2); zb = ztx + s1 * xb
    fig = plt.figure(figsize=(6.5, 5.4), layout="constrained")
    gs = fig.add_gridspec(2, 1, height_ratios=[1.25, 1])
    ax = fig.add_subplot(gs[0])
    ax.fill_between(d, z.min() - 50, z, color="#E4E7EC", lw=0)
    ax.plot(d, z, color=GR, lw=0.8)
    ax.plot([0, d[i1]], [ztx, z[i1]], color=LB, lw=1.4); ax.plot([D, d[i2]], [zrx, z[i2]], color=LB, lw=1.4)
    ax.plot([d[i1], xb], [z[i1], zb], color=GR, lw=1, ls=(0, (3, 2))); ax.plot([d[i2], xb], [z[i2], zb], color=GR, lw=1, ls=(0, (3, 2)))
    ax.scatter([d[i1], d[i2]], [z[i1], z[i2]], s=60, marker="^", color=LB, zorder=4, edgecolor="white")
    ax.scatter([xb], [zb], s=60, marker="v", color=DB, zorder=4, edgecolor="white")
    ax.scatter([0, D], [ztx, zrx], s=30, color=DB, zorder=4)
    ax.text(d[i1], z[i1] + 40, "Transmitter's\nhorizon", ha="center", fontsize=8, color=LB)
    ax.text(d[i2], z[i2] + 40, "Receiver's\nhorizon", ha="center", fontsize=8, color=LB)
    top = z.max() + 700
    ax.annotate(f"The two rays meet {zb / 1000:.1f} km up at {xb:.0f} km:\nthe Bullington point P.452 and P.2001 use", xy=(xb, top - 20),
                xytext=(xb - 2, top - 330), ha="right", fontsize=8, color=DB, arrowprops=dict(arrowstyle="->", color=DB, lw=0.8))
    ax.text(0.5, ztx - 90, "Tx", fontsize=8); ax.text(D - 3, zrx - 90, "Rx", fontsize=8)
    ax.set_xlim(-1, D + 1); ax.set_ylim(z.min() - 50, top)
    ax.set_xlabel("Distance (km)"); ax.set_ylabel("Height with earth bulge (m)")
    ax.set_title(f"Double-horizon diffraction link, {D:.0f} km, Appalachians, Δh {t.delta_h_m:.0f} m", loc="left")
    for s in ["top", "right"]:
        ax.spines[s].set_visible(False)
    a2 = fig.add_subplot(gs[1]); soft(a2)
    w = t.w_d3
    itm = [(w * t.A_se_d3, "#C9D3EE", f"smooth earth × w\n({t.A_se_d3:.0f} dB × {w:.3f})"),
           ((1 - w) * t.A_k_d3, LB, f"two knife edges × (1 − w)\n({t.A_k_d3:.0f} dB × {1 - w:.3f})"),
           (t.A_fo, DB, "clutter")]
    rows = [("ITM", itm, t.itm_excess_50), ("P.452", [(t.Lbulla, GR, "one knife edge\n(Bullington)")], t.p452_excess_50),
            ("P.2001", [(t.p2001_excess_50, GR, "Bullington and\nspherical earth")], t.p2001_excess_50)]
    for i, (name, parts, tot) in enumerate(rows):
        x = 0
        for v, col, lab in parts:
            a2.barh(i, v, left=x, height=0.7, color=col, edgecolor="white", linewidth=1.5)
            a2.text(x + v / 2, i, lab, ha="center", va="center", fontsize=6.8, color="white" if col in (LB, DB, GR) else DB)
            x += v
        a2.text(x + 2, i, f"{tot:.0f} dB at 50 %", va="center", fontsize=8.5, fontweight="semibold")
    a2.set_yticks(range(3), [r[0] for r in rows]); a2.set_ylim(2.6, -0.6); a2.set_xlim(0, 185)
    a2.set_xlabel(f"Diffraction loss above free space at {F0 / 1000:g} GHz (dB)")
    save(fig, "fig35_anatomy_of_a_link")


# ---------- fig36: where the window falls ----------
def fig36():
    fig, ax = plt.subplots(figsize=(6.5, 3.8), layout="constrained")
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.scatter(db.d_km, np.maximum(db.itm_delta_h_m, 3), s=20, facecolor="none", edgecolor=GR, linewidth=0.7,
               label="Measured paths, 1-10 GHz (ITM and P.2001 within a few dB)")
    norm = mpl.colors.Normalize(0, 50)
    cmap = mpl.colors.LinearSegmentedColormap.from_list("gap", ["#D9DCE0", LB, DB])
    sc = ax.scatter(b.length_km, np.maximum(b.delta_h_m, 3), c=np.clip(b.apart, 0, 50), cmap=cmap, norm=norm, s=46,
                    edgecolor="white", linewidth=0.5, zorder=3, label="Calculated links, colored by ITM minus P.2001")
    cb = fig.colorbar(sc, ax=ax, shrink=0.75, pad=0.01); cb.outline.set_visible(False); cb.set_label(YL, fontsize=8.5)
    ax.axhline(150, color=PU, lw=0.8, ls=(0, (3, 3))); ax.axvline(150, color=PU, lw=0.8, ls=(0, (3, 3)))
    ax.text(11, 170, "Δh over about 150 m and under about 150 km:\nwhere the large gaps are", fontsize=8, color=PU)
    ax.set_xlim(8, 900); ax.set_ylim(3, 3000)
    ax.set_xticks([10, 30, 100, 300], ["10", "30", "100", "300"]); ax.set_yticks([10, 100, 1000], ["10", "100", "1,000"])
    ax.set_xlabel("Path length (km), log scale"); ax.set_ylabel("ITM terrain irregularity Δh (m), log scale")
    ax.legend(fontsize=7.5, loc="lower right")
    for s in ["top", "right"]:
        ax.spines[s].set_visible(False)
    save(fig, "fig36_where_the_window_falls")


# ---------- fig37: the window over time ----------
def fig37():
    T = pd.read_csv(CD / "deep_time_by_link.csv").query("freq_mhz == @F0")
    T["cls"] = T.itm_mode_code.map(cls)
    T["apart"] = T.itm_db - T.p2001_db
    fig, ax = plt.subplots(figsize=(6.5, 3.3), layout="constrained"); soft(ax, "y")
    for c in ["Line of sight", "Diffraction", "Troposcatter"]:
        g = T[T.cls == c].groupby("time_pct").apart
        q = g.quantile([0.25, 0.5, 0.75]).unstack()
        ax.fill_between(q.index, q[0.25], q[0.75], color=CC[c], alpha=0.18, lw=0)
        ax.plot(q.index, q[0.5], color=CC[c], lw=2.6)
        ax.text(0.0008, q[0.5].iloc[0], c, color=CC[c], fontweight="bold", ha="right", va="center", fontsize=8.5)
    ax.axhline(0, color=DB, lw=0.8); ax.set_xscale("log")
    ax.set_xticks([0.001, 0.01, 0.1, 1, 10, 50, 99], ["0.001", "0.01", "0.1", "1", "10", "50", "99"]); ax.set_xlim(0.0002, 99.99)
    ax.set_xlabel("Percentage of time the loss is not exceeded"); ax.set_ylabel(YL)
    ax.text(0.97, 0.95, "Lines: median over the links; bands: middle half", transform=ax.transAxes, ha="right", fontsize=8, color=GR)
    save(fig, "fig37_window_over_time")


if __name__ == "__main__":
    for fn in [fig32, fig33, fig34, fig35, fig36, fig37]:
        fn()
