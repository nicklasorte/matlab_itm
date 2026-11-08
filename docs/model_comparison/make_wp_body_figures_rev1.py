"""Body figures for the ITM / P.2001 / P.452 working paper, redrawn in Python.

Replaces the MATLAB grouped-bar figures and the world map with dot plots,
slope charts, and three regional maps. Report-figure style: the image holds
the chart only; the takeaway and caption are text in the document.

Reads CSV only (chart_data/ and figures/table_*.csv); writes
figures/figNN_*_v2.png. Shares styles and data with make_wp_charts_rev1.py.

Run:  python3 make_wp_body_figures_rev1.py
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LogNorm, Normalize
from matplotlib.patches import Rectangle

import make_wp_charts_rev1 as C
from make_wp_charts_rev1 import DB, LB, PU, GR, LG, PANEL, MCOL, MLAB, FREQS, FLAB, FCOL, BINS, CD, FIG, db, terms, abl, basemap

mpl.rcParams.update({"font.size": 9, "axes.titlesize": 9.5})
ORDER3 = ["itm", "p452", "p2001"]
MK = {"itm": "o", "p452": "s", "p2001": "o"}
FULL = {"itm": "ITM v1.4", "p452": "P.452-18", "p2001": "P.2001-6"}

# The three measurement regions (the databank also has one Australian path, 2 datasets)
REGIONS = {
    "North America": dict(lon=(-125, -54), lat=(24, 53), us=True),
    "Europe": dict(lon=(-11, 16), lat=(42.5, 61.5), us=False),
    "Japan": dict(lon=(128, 146.5), lat=(26, 46.5), us=False),
}


def region_of(lon, lat):
    for name, r in REGIONS.items():
        if r["lon"][0] <= lon <= r["lon"][1] and r["lat"][0] <= lat <= r["lat"][1]:
            return name
    return "Other"


# Regions and counts come from figure_data_3ghz_rev1.m
REG = pd.read_csv(CD / "figures" / "fig25_measured_regions.csv")
CNT = pd.read_csv(CD / "figures" / "fig25_region_counts.csv").set_index("region")


def save(fig, name):
    fig.savefig(FIG / f"{name}.png", dpi=220)
    plt.close(fig)
    print("wrote", name)


def soft(ax, grid="x"):
    C.soft(ax, grid)


def model_key(ax, x, y, models=ORDER3, dy=0.07):
    for k, m in enumerate(models):
        ax.scatter([x], [y - dy * k], s=45, marker=MK[m], color=MCOL[m], edgecolor="white", transform=ax.transAxes, clip_on=False)
        ax.text(x + 0.03, y - dy * k, FULL[m], va="center", transform=ax.transAxes, fontsize=8.5)


# ---------- fig03: terrain resolution ----------
def fig03():
    T = pd.read_csv(CD / "terrain_resolution_by_link.csv")
    res = ["30 m", "90 m", "1 km smoothed"]
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 2.9), gridspec_kw=dict(width_ratios=[1, 1.15], wspace=0.45),
                                 layout="constrained")
    soft(a1)
    base = T[T.resolution == "30 m"].set_index("link")
    for i, m in enumerate(ORDER3):
        ch = [np.median(T[T.resolution == r].set_index("link")[f"{m}_50_db"] - base[f"{m}_50_db"]) for r in res[1:]]
        a1.plot(ch, [i, i], color=LG, lw=3, zorder=1)
        a1.scatter([ch[0]], [i], s=55, color="white", edgecolor=MCOL[m], linewidth=1.8, marker=MK[m], zorder=3)
        a1.scatter([ch[1]], [i], s=55, color=MCOL[m], edgecolor="white", marker=MK[m], zorder=3)
        a1.text(ch[1], i - 0.3, f"{ch[1]:.1f} dB", ha="center", va="bottom", fontsize=8.5)
    a1.text(0.02, 0.03, "open: 90 m    filled: 1 km smoothed", transform=a1.transAxes, ha="left", fontsize=8, color=GR)
    a1.axvline(0, color=DB, lw=0.8)
    a1.set_yticks(range(3), [FULL[m] for m in ORDER3]); a1.set_ylim(-0.75, 2.9); a1.invert_yaxis(); a1.set_xlim(-5, 0.6)
    a1.set_xlabel("Median change from the 30 m result (dB)")
    soft(a2, "y")
    G = T.assign(gap=T.p2001_50_db - T.itm_50_db).pivot(index="link", columns="resolution", values="gap")[res]
    for _, r in G.iterrows():
        a2.plot(range(3), r.values, color=LG, lw=0.8, alpha=0.8, zorder=1)
    a2.scatter(np.repeat(range(3), len(G)), G.values.T.ravel(), s=12, color=LB, alpha=0.7, edgecolor="none", zorder=2)
    md = G.median().values
    a2.plot(range(3), md, "-o", color=DB, lw=2.2, ms=6, mec="white", zorder=3)
    for x, v in enumerate(md):
        a2.text(x, v + 4, f"{v:.0f} dB", fontsize=8.5, fontweight="semibold", ha="center", va="bottom",
                bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none"), zorder=5)
    a2.axhline(0, color=DB, lw=0.8)
    a2.set_xticks(range(3), res); a2.set_xlim(-0.3, 2.5); a2.set_ylabel("P.2001 minus ITM (dB)")
    a2.set_title(f"{len(G)} diffraction links, 2.7 GHz, 50 %", color=GR, fontweight="normal", fontsize=8.5)
    0 and a2.text(0.98, 0.04, f"{len(G)} diffraction links, 2.7 GHz, 50 %", transform=a2.transAxes, ha="right", color=GR, fontsize=8)
    save(fig, "fig03_terrain_resolution_v2")


# ---------- fig14: ITM diffraction terms ----------
def fig14():
    fig = plt.figure(figsize=(6.5, 5.6), layout="constrained")
    gs = fig.add_gridspec(2, 2, height_ratios=[1, 0.95])
    a1, a2, a3 = fig.add_subplot(gs[0, 0]), fig.add_subplot(gs[0, 1]), fig.add_subplot(gs[1, :])
    soft(a1, "y"); soft(a2, "y")
    for f in FREQS:
        q = terms[terms.freq_mhz == f]
        a1.scatter(q.Lbulla, q.A_k_d3, s=16, color=FCOL[f], alpha=0.8, edgecolor="white", linewidth=0.3, label=FLAB[f])
        a2.scatter(np.maximum(q.delta_h_m, 5), q.w_d3, s=16, color=FCOL[f], alpha=0.8, edgecolor="white", linewidth=0.3)
    a1.plot([0, 110], [0, 110], color=GR, lw=0.8, ls=(0, (3, 3)))
    a1.text(78, 70, "equal", color=GR, fontsize=8, rotation=38)
    a1.set_xlim(0, 105); a1.set_ylim(0, 110)
    a1.set_xlabel("P.452 Bullington loss, actual profile (dB)"); a1.set_ylabel("ITM double knife edge $A_k$ at $d_3$ (dB)")
    a1.legend(loc="upper left", fontsize=8, handletextpad=0.2)
    a2.set_xscale("log"); a2.set_ylim(0, 1)
    a2.set_xlabel("ITM terrain irregularity Δh (m)"); a2.set_ylabel("ITM smooth-earth weight w at $d_3$")
    soft(a3)
    y, ticks, labs = 0, [], []
    for f in FREQS[::-1]:
        q = terms[terms.freq_mhz == f]
        itm = [(np.median(q.w_d3 * q.A_se_d3), "#C9D3EE"), (np.median((1 - q.w_d3) * q.A_k_d3), LB), (np.median(q.A_fo), DB)]
        p452 = [(np.median(q.Lbulla), GR), (np.median(np.maximum(q.Ldsph - q.Lbulls, 0)), LG)]
        for row, name in ((p452, "P.452"), (itm, "ITM")):
            x = 0
            for v, col in row:
                a3.add_patch(Rectangle((x, y - 0.34), v, 0.68, color=col, lw=0)); x += v + 0.6
            a3.text(x + 1, y, f"{x:.0f} dB", va="center", fontweight="semibold", fontsize=8.5)
            ticks.append(y); labs.append(f"{name} · {FLAB[f]}"); y += 1
        y += 0.6
    a3.set_yticks(ticks, labs); a3.set_xlim(0, 135); a3.set_ylim(-0.7, y - 0.3)
    a3.set_xlabel("Median diffraction loss and its terms (dB)")
    keys = [("#C9D3EE", "ITM smooth earth × w"), (LB, "ITM two knife edges × (1 − w)"), (DB, "ITM clutter term $A_{fo}$"),
            (GR, "P.452 Bullington"), (LG, "P.452 spherical-earth excess")]
    h = [mpl.patches.Patch(color=c, label=l) for c, l in keys]
    fig.legend(handles=h, loc="outside lower center", ncol=3, fontsize=8, handlelength=1, columnspacing=1.2)
    save(fig, "fig14_diffraction_terms_v2")


# ---------- fig15: ablation ----------
def fig15():
    cases = [("ITM as is", "ITM as published"), ("2 no clutter term", "Without the clutter term"),
             ("3 evaluated at the path", "A_d evaluated at the path"), ("1 single edge", "One knife edge, not two"),
             ("4 all three", "All three removed")]
    fig, ax = plt.subplots(figsize=(6.5, 2.9), layout="constrained"); soft(ax)
    for i, (c, lab) in enumerate(cases):
        g = [abl[(abl.freq_mhz == f) & (abl["case"] == c)].median_gap_db.iloc[0] for f in FREQS]
        ax.plot([min(g), max(g)], [i, i], color=LG, lw=3, zorder=1)
        for f, v in zip(FREQS, g):
            ax.scatter([v], [i], s=60, color=FCOL[f], edgecolor="white", zorder=3)
        if i == 0:
            for f, v in zip(FREQS, g):
                ax.text(v, i - 0.38, FLAB[f], ha="center", fontsize=8, color=FCOL[f], fontweight="semibold")
    ax.axvline(0, color=DB, lw=0.8)
    ax.set_yticks(range(len(cases)), [l for _, l in cases]); ax.set_ylim(len(cases) - 0.5, -0.8)
    ax.set_xlabel("Median ITM reference attenuation minus P.452 diffraction loss (dB)")
    save(fig, "fig15_diffraction_ablation_v2")


# ---------- fig18: archetype summary ----------
def fig18():
    A = pd.read_csv(FIG / "table_archetypes.csv")
    A = A[A.freq_mhz == 2700]
    paths = list(dict.fromkeys(A.path))
    fig, axs = plt.subplots(1, 3, figsize=(6.5, 2.9), sharey=True, layout="constrained")
    specs = [("Loss at 50 % of time (dB)", "{}_50", ORDER3), ("Loss at 1 % of time (dB)", "{}_1", ORDER3),
             ("Spread, 1 % to 99 % (dB)", "{}_spread_1_99", ["itm", "p2001"])]
    for ax, (xl, key, ms) in zip(axs, specs):
        soft(ax)
        for i, p in enumerate(paths):
            r = A[A.path == p].iloc[0]
            v = [r[key.format(m)] for m in ms]
            ax.plot([min(v), max(v)], [i, i], color=LG, lw=3, zorder=1)
            for m, x in zip(ms, v):
                ax.scatter([x], [i], s=40, marker=MK[m], color=MCOL[m], edgecolor="white", zorder=3 if m != "itm" else 4)
        ax.set_xlabel(xl)
    axs[0].set_yticks(range(len(paths)), paths); axs[0].invert_yaxis()
    axs[2].set_title("P.452 is defined only to 50 %", fontsize=8, color=GR, fontweight="normal")
    h = [mpl.lines.Line2D([], [], ls="", marker=MK[m], color=MCOL[m], ms=7, label=FULL[m]) for m in ORDER3]
    fig.legend(handles=h, loc="outside lower center", ncol=3, fontsize=8.5)
    save(fig, "fig18_archetype_summary_v2")


# ---------- fig19: knife edge ----------
def fig19():
    K = pd.read_csv(FIG / "table_knife_edge.csv")
    fig, ax = plt.subplots(figsize=(5.2, 2.8), layout="constrained"); soft(ax, "y")
    x = K.freq_mhz / 1000
    ax.plot(x, K.p452_mae_db, "-s", color=GR, lw=2, ms=6, mec="white")
    ax.plot(x, K.p2001_mae_db, marker="o", color=DB, lw=2, ms=6, mec="white", ls=(0, (4, 2)))
    ax.plot(x, K.itm_mae_db, "-o", color=LB, lw=2.8, ms=7, mec="white")
    ax.text(7.45, K.itm_mae_db.iloc[-1], "ITM", color=LB, fontweight="bold", va="center")
    ax.text(7.45, K.p2001_mae_db.iloc[-1] - 0.5, "P.452 and P.2001\n(nearly identical)", color=DB, va="center", fontsize=8.5)
    ax.set_xticks(x, [FLAB[f] for f in K.freq_mhz]); ax.set_xlim(2.3, 9.4); ax.set_ylim(0, 14)
    ax.set_ylabel("Mean |model − J(v)|, v ≥ 0 (dB)")
    save(fig, "fig19_knife_edge_error_v2")


# ---------- fig25: three regional maps ----------
def fig25():
    fig = plt.figure(figsize=(6.5, 6.6), layout="constrained")
    gs = fig.add_gridspec(3, 2, height_ratios=[1.05, 1, 0.06], width_ratios=[1.15, 1])
    axes = {"North America": fig.add_subplot(gs[0, :]), "Europe": fig.add_subplot(gs[1, 0]), "Japan": fig.add_subplot(gs[1, 1])}
    norm = LogNorm(30, 10000); cmap = mpl.colormaps["viridis"]
    for name, ax in axes.items():
        r = REGIONS[name]; basemap(ax, r["lon"], r["lat"], us=r["us"])
        d = REG[REG.region == name].sort_values("freq_mhz")
        for _, p in d.iterrows():
            ax.plot([p.tx_lon, p.rx_lon], [p.tx_lat, p.rx_lat], color=cmap(norm(p.freq_mhz)), lw=1.6, solid_capstyle="round", zorder=3)
        ax.scatter(np.r_[d.tx_lon, d.rx_lon], np.r_[d.tx_lat, d.rx_lat], s=5, color=DB, zorder=4, edgecolor="none")
        k = CNT.loc[name]
        ax.set_title(f"{name}\n{int(k.datasets)} datasets, {int(k.paths)} paths ({int(k.datasets_1_10_ghz)} at 1-10 GHz)", fontsize=9)
    cax = fig.add_subplot(gs[2, :])
    cb = fig.colorbar(mpl.cm.ScalarMappable(norm, cmap), cax=cax, orientation="horizontal")
    cb.set_ticks([30, 100, 300, 1000, 3000, 10000], labels=["30 MHz", "100 MHz", "300 MHz", "1 GHz", "3 GHz", "10 GHz"])
    cb.outline.set_visible(False); cax.tick_params(labelsize=8.5)
    save(fig, "fig25_dbsg3_map_v2")


# ---------- fig27: error by band ----------
def fig27():
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 3.3), sharey=True, layout="constrained")
    for ax, stat, xl in ((a1, "mean", "Mean error in the median (dB)"), (a2, "rms", "RMS error in the median (dB)")):
        soft(ax)
        ax.axhspan(2.5, 5.5, color=PANEL, zorder=0)
        for i, b in enumerate(BINS):
            v = []
            for m in ORDER3:
                e = C.err(m, "50", db.bin == b)
                if e.size >= 3:
                    v.append((m, e.mean() if stat == "mean" else np.sqrt(np.mean(e ** 2))))
            xs = [x for _, x in v]
            ax.plot([min(xs), max(xs)], [i, i], color=LG, lw=3, zorder=1)
            for m, x in v:
                ax.scatter([x], [i], s=48, marker=MK[m], color=MCOL[m], edgecolor="white", zorder=4 if m == "itm" else 3)
        if stat == "mean":
            ax.axvline(0, color=DB, lw=0.8); ax.set_xlim(-7, 9)
        else:
            ax.set_xlim(0, 17)
        ax.set_xlabel(xl)
    a1.set_yticks(range(6), BINS); a1.set_ylim(5.6, -0.6)
    a2.text(16.7, 2.62, "1 GHz to 10 GHz", fontsize=7.5, color=GR, va="top", ha="right")
    model_key(a2, 0.05, 0.97)
    save(fig, "fig27_dbsg3_error_by_bin_v2")


# ---------- fig30: terrain source and site correction ----------
def fig30():
    Dm = pd.read_csv(FIG / "table_dbsg3_by_dataset_dem.csv")
    Tc = pd.read_csv(FIG / "table_dbsg3_terrain_comparison.csv")
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.5, 2.9), gridspec_kw=dict(width_ratios=[1, 1.1]), layout="constrained")
    q = Dm[Dm.has_profile == 1].drop_duplicates("path")
    b0 = np.clip(np.r_[q.tx_dz_before_m, q.rx_dz_before_m], -300, 300)
    b1 = np.clip(np.r_[q.tx_dz_after_m, q.rx_dz_after_m], -300, 300)
    ed = np.arange(-150, 151, 10)
    soft(a1, "y")
    a1.hist(b0[np.isfinite(b0)], ed, color=LG, label="Listed coordinates")
    a1.hist(b1[np.isfinite(b1)], ed, color=LB, alpha=0.75, label="After site correction")
    a1.set_xlabel("30 m terrain minus surveyed ground (m)"); a1.set_ylabel("Terminals"); a1.legend(fontsize=8, loc="upper left")
    soft(a2)
    cases = [("rms_dem_listed", "30 m terrain, listed sites", "white", GR), ("rms_dem_corrected", "30 m terrain, corrected sites", PU, PU),
             ("rms_survey", "Surveyed profiles", LB, LB)]
    for i, r in Tc.iterrows():
        v = [r[c] for c, *_ in cases]
        a2.plot([min(v), max(v)], [i, i], color=LG, lw=3, zorder=1)
        for x, (_, _, fc, ec) in zip(v, cases):
            a2.scatter([x], [i], s=60, color=fc, edgecolor=ec, linewidth=1.8, zorder=3)
    for x, (_, lab, fc, ec) in zip([Tc.loc[0, c] for c, *_ in cases], cases):
        a2.text(x, -0.45, lab.replace(", ", ",\n"), ha="center", va="bottom", fontsize=7.5, color=ec)
    a2.set_yticks(range(len(Tc)), Tc.model); a2.set_ylim(len(Tc) - 0.5, -1.25); a2.set_xlim(0, 45)
    a2.set_xlabel(f"RMS error in the median (dB), same {int(Tc.n[0])} datasets")
    save(fig, "fig30_dbsg3_terrain_and_sites_v2")


if __name__ == "__main__":
    for fn in [fig03, fig14, fig15, fig18, fig19, fig25, fig27, fig30]:
        fn()
    print(db.region.value_counts())
