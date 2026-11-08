"""Full-page charts for the ITM / P.2001 / P.452 working paper.

Five chart designs for each of the paper's four main findings, one page each,
drawn with matplotlib from CSV files only:

  chart_data/real_terrain_links.csv, real_terrain_by_link.csv,
  real_terrain_gap_by_time.csv, basemap_*.csv   (export_wp_chart_data_rev1.m)
  figures/table_diffraction_terms.csv, table_diffraction_ablation.csv
                                                (diffraction_decomposition_rev1.m)
  figures/table_dbsg3_by_dataset_survey.csv     (compare_dbsg3_rev1.m)
  data/dbsg3/dbsg3_tableiii_30mhz_10ghz.csv     (site coordinates)

Each page is a standalone figure: DRAFT//PRE-DECISIONAL at the top, the
takeaway as the headline, the chart, and a source line. Colors: NTIA light
blue for ITM, NTIA dark blue for P.2001, mid gray for P.452, NTIA purple for
alerts, and the plasma colormap for sequential scales ("dB off"). Font: Inter.

Run:  python3 make_wp_charts_rev1.py   (writes figures/chart_*.png)
"""

from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.colors import LinearSegmentedColormap, Normalize
from matplotlib.patches import Rectangle

HERE = Path(__file__).resolve().parent
CD, FIG, DATA = HERE / "chart_data", HERE / "figures", HERE / "data"

# ---------- style ----------
DB, LB, PU, GR = "#163353", "#5674C4", "#6E4F92", "#8A8D91"
LG, PANEL, GRID = "#C8CACD", "#EEF0F3", "#E6E6E6"
MCOL = {"itm": LB, "p452": GR, "p2001": DB}
MLAB = {"itm": "ITM", "p452": "P.452", "p2001": "P.2001"}
PLASMA = LinearSegmentedColormap.from_list("plasma_cut", mpl.colormaps["plasma"](np.linspace(0, 0.9, 256)))
DIVERGE = LinearSegmentedColormap.from_list("ntia_div", [DB, "#E8E9EA", PU])
FREQS = sorted(pd.read_csv(HERE / "chart_data" / "real_terrain_by_link.csv").freq_mhz.unique().tolist())
FLAB = {f: f"{f / 1000:g} GHz" for f in FREQS}
FCOL = {f: PLASMA(x) for f, x in zip(FREQS, np.linspace(0.08, 0.78, len(FREQS)) if len(FREQS) > 1 else [0.08])}
CLASSES = ["Line of sight", "Diffraction", "Troposcatter"]
BINS = ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-3 GHz", "3-6 GHz", "6-10 GHz"]
MARK = "DRAFT//PRE-DECISIONAL"
SRC_RT = "Source: NTIA analysis; ITM v1.4, P.452-18, and P.2001-6 on 30 m USGS 3DEP profiles, 60 mid-Atlantic links (2026)."
SRC_DB = "Source: NTIA analysis of ITU-R Study Group 3 databank Table III, on its surveyed profiles (2026)."

mpl.rcParams.update({
    "font.family": "Inter", "font.size": 10.5, "text.color": DB, "axes.labelcolor": DB,
    "axes.edgecolor": LG, "axes.linewidth": 0.8, "xtick.color": DB, "ytick.color": DB,
    "xtick.major.size": 0, "ytick.major.size": 0, "axes.grid": False, "grid.color": GRID,
    "grid.linewidth": 0.8, "axes.spines.top": False, "axes.spines.right": False,
    "axes.titleweight": "semibold", "axes.titlesize": 11, "axes.titlelocation": "left",
    "figure.facecolor": "white", "savefig.facecolor": "white", "legend.frameon": False,
})


def page(headline, sub, src, nrows=1, ncols=1, **kw):
    import textwrap
    fig = plt.figure(figsize=(8.5, 11))
    fig.text(0.07, 0.975, MARK, fontsize=8.5, fontweight="bold", color=DB, va="top")
    lines = textwrap.wrap(headline, 46)
    fig.text(0.07, 0.95, "\n".join(lines), fontsize=21, fontweight="bold", color=DB, va="top", linespacing=1.15)
    ys = 0.95 - 0.034 * len(lines) - 0.012
    fig.text(0.07, ys, sub, fontsize=11.5, color=GR, va="top", linespacing=1.3)
    top = min(kw.get("top", 0.83), ys - 0.018 * (sub.count("\n") + 1) - 0.045)
    fig.text(0.07, 0.022, src, fontsize=8, color=DB, va="bottom")
    gs = fig.add_gridspec(nrows, ncols, left=kw.get("left", 0.2), right=kw.get("right", 0.93),
                          top=top, bottom=kw.get("bottom", 0.08),
                          hspace=kw.get("hspace", 0.35), wspace=kw.get("wspace", 0.25),
                          width_ratios=kw.get("width_ratios"), height_ratios=kw.get("height_ratios"))
    return fig, gs


def finish(fig, name):
    fig.savefig(FIG / f"chart_{name}.png", dpi=220)
    plt.close(fig)
    print("wrote", name)


def soft(ax, grid="x"):
    ax.spines["left"].set_visible(grid != "x")
    if grid == "x":
        ax.xaxis.grid(True)
    else:
        ax.yaxis.grid(True)
    ax.set_axisbelow(True)


def cbar(fig, mappable, rect, label):
    cax = fig.add_axes(rect)
    cb = fig.colorbar(mappable, cax=cax, orientation="horizontal")
    cb.outline.set_visible(False)
    cb.set_label(label, color=DB, fontsize=9.5)
    cax.tick_params(labelsize=9, colors=DB)
    return cb


# ---------- data ----------
links = pd.read_csv(CD / "real_terrain_links.csv")
bylink = pd.read_csv(CD / "real_terrain_by_link.csv").merge(links[["link", "delta_h_m", "length_km"]], on="link")
bylink["gap"] = bylink.p2001_50_db - bylink.itm_50_db
gap_t = pd.read_csv(CD / "real_terrain_gap_by_time.csv")
coast = pd.read_csv(CD / "basemap_coastlines.csv")
states = pd.read_csv(CD / "basemap_us_states.csv")
terms = pd.read_csv(FIG / "table_diffraction_terms.csv")
abl = pd.read_csv(FIG / "table_diffraction_ablation.csv")
db = pd.read_csv(FIG / "table_dbsg3_by_dataset_survey.csv")
db = db[db.kept == 1].copy()
sites = pd.read_csv(DATA / "dbsg3" / "dbsg3_tableiii_30mhz_10ghz.csv")[["id", "tx_lat", "tx_lon", "rx_lat", "rx_lon"]]
db = db.merge(sites, on="id", how="left")
hi = db.freq_mhz >= 1000


def err(m, p, sel=None):
    d = db if sel is None else db[sel]
    return (d[f"{m}_{p}"] - d[f"meas_{p}"]).dropna()


def basemap(ax, lon_lim, lat_lim, us=True):
    ax.plot(coast.lon, coast.lat, color=LG, lw=0.6, zorder=1)
    if us:
        ax.plot(states.lon, states.lat, color=LG, lw=0.4, zorder=1)
    ax.set_xlim(lon_lim); ax.set_ylim(lat_lim)
    ax.set_aspect(1 / np.cos(np.deg2rad(np.mean(lat_lim))))
    ax.set_xticks([]); ax.set_yticks([])
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_facecolor("#F7F8FA")


# =================== Finding 1: agree in line of sight, split beyond ===================
H1 = "The models agree in line of sight and split by 30 dB or more beyond the horizon"


def f1a():
    fig, gs = page(H1, "P.2001 minus ITM on 60 real-terrain links at 50 % of time. Each dot is a link;\n"
                   "its color shows how many dB the two models are apart.", SRC_RT, left=0.26, bottom=0.15)
    ax = fig.add_subplot(gs[0]); soft(ax)
    norm = Normalize(0, 60)
    y, ticks, labels = 0, [], []
    rng = np.random.default_rng(7)
    for c in CLASSES[::-1]:
        for f in FREQS[::-1]:
            g = bylink[(bylink.itm_class == c) & (bylink.freq_mhz == f)].gap.values
            ax.scatter(g, y + rng.uniform(-0.28, 0.28, g.size), c=np.abs(g), cmap=PLASMA, norm=norm, s=34,
                       edgecolor="white", linewidth=0.4, zorder=3)
            m = np.median(g)
            ax.plot([m, m], [y - 0.38, y + 0.38], color=DB, lw=2.5, zorder=4)
            ax.text(m, y + 0.47, f"{m:.0f} dB", ha="center", fontsize=9, fontweight="semibold")
            ticks.append(y); labels.append(f"{c}  ·  {FLAB[f]}")
            y += 1
        y += 0.7
    ax.axvline(0, color=DB, lw=1)
    ax.set_yticks(ticks, labels); ax.set_xlim(-110, 15); ax.set_ylim(-0.7, y - 0.4)
    ax.set_xlabel("P.2001 minus ITM (dB)   ←  ITM predicts more loss")
    cbar(fig, mpl.cm.ScalarMappable(norm, PLASMA), [0.26, 0.065, 0.4, 0.012], "dB apart")
    finish(fig, "1a_strip")


def f1b():
    fig, gs = page(H1, "Median loss above free space at 50 % of time, by ITM's mechanism class.\n"
                   "The gray bar is the distance between ITM and P.2001; P.452 sits under P.2001.", SRC_RT, left=0.26)
    ax = fig.add_subplot(gs[0]); soft(ax)
    y, ticks, labels = 0, [], []
    for c in CLASSES[::-1]:
        for f in FREQS[::-1]:
            d = bylink[(bylink.itm_class == c) & (bylink.freq_mhz == f)]
            a, b, q = [np.median(d[k] - d.free_space_db) for k in ("itm_50_db", "p2001_50_db", "p452_50_db")]
            ax.plot([b, a], [y, y], color=LG, lw=7, solid_capstyle="round", zorder=2)
            ax.scatter([q], [y], s=70, marker="s", color=GR, zorder=3, edgecolor="white")
            ax.scatter([b], [y], s=120, color=DB, zorder=4, edgecolor="white")
            ax.scatter([a], [y], s=120, color=LB, zorder=5, edgecolor="white")
            if abs(a - b) > 4:
                ax.text(a + 3, y, f"+{a - b:.0f} dB", va="center", fontsize=9.5, fontweight="semibold", color=LB)
            ticks.append(y); labels.append(f"{c}  ·  {FLAB[f]}")
            y += 1
        y += 0.7
    ax.set_yticks(ticks, labels); ax.set_xlim(-5, 125)
    ax.set_xlabel("Median loss above free space (dB)")
    for k, (lab, col, mk) in enumerate([("ITM", LB, "o"), ("P.2001", DB, "o"), ("P.452", GR, "s")]):
        ax.scatter([0.62], [0.97 - 0.035 * k], s=90, color=col, marker=mk, edgecolor="white", transform=ax.transAxes, clip_on=False)
        ax.text(0.645, 0.97 - 0.035 * k, lab, va="center", fontsize=10.5, transform=ax.transAxes)
    finish(fig, "1b_dumbbell")


def f1c():
    fig, gs = page(H1, "The 60 links, colored by how many dB P.2001 and ITM are apart at 50 % of time.\n"
                   "The disagreement concentrates in the Appalachian ridges at the left.", SRC_RT,
                   nrows=3, left=0.07, right=0.93, hspace=0.12, bottom=0.13)
    norm = Normalize(0, 60)
    for i, f in enumerate(FREQS):
        ax = fig.add_subplot(gs[i]); basemap(ax, (-80.8, -74.9), (37.4, 39.9))
        d = bylink[bylink.freq_mhz == f].merge(links, on="link")
        for _, r in d.sort_values("gap", key=np.abs).iterrows():
            ax.plot([r.tx_lon, r.rx_lon], [r.tx_lat, r.rx_lat], color=PLASMA(norm(abs(r.gap))), lw=2.6,
                    solid_capstyle="round", zorder=3)
        ax.text(0.01, 0.95, FLAB[f], transform=ax.transAxes, fontsize=12, fontweight="bold", va="top")
    cbar(fig, mpl.cm.ScalarMappable(norm, PLASMA), [0.3, 0.07, 0.4, 0.012], "|P.2001 minus ITM| (dB apart)")
    finish(fig, "1c_map")


def f1d():
    fig, gs = page(H1, "How much more loss ITM predicts than P.2001: the median over the links\n"
                   "in each mechanism class, at 50 % of time.", SRC_RT, left=0.22, top=0.78, bottom=0.2)
    ax = fig.add_subplot(gs[0])
    M = np.array([[-bylink[(bylink.itm_class == c) & (bylink.freq_mhz == f)].gap.median() for f in FREQS] for c in CLASSES])
    N = np.array([[((bylink.itm_class == c) & (bylink.freq_mhz == f)).sum() for f in FREQS] for c in CLASSES])
    ax.imshow(M, cmap=PLASMA, vmin=0, vmax=55, aspect="auto")
    for i in range(3):
        for j in range(3):
            tc = "white" if M[i, j] < 33 else DB
            ax.text(j, i - 0.05, f"{abs(round(M[i, j])):.0f} dB", ha="center", va="center", fontsize=30, fontweight="bold", color=tc)
            ax.text(j, i + 0.3, f"{N[i, j]} links", ha="center", fontsize=10, color=tc)
    ax.set_xticks(range(3), [FLAB[f] for f in FREQS], fontsize=13); ax.xaxis.tick_top()
    ax.set_yticks(range(3), CLASSES, fontsize=13)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(length=0)
    finish(fig, "1d_heat")


def f1e():
    fig, gs = page(H1, "Distribution of P.2001 minus ITM over the links in each class, at 50 % of time.",
                   SRC_RT, ncols=3, left=0.1, wspace=0.12)
    for j, f in enumerate(FREQS):
        ax = fig.add_subplot(gs[j]); soft(ax, "y")
        for i, c in enumerate(CLASSES):
            g = bylink[(bylink.itm_class == c) & (bylink.freq_mhz == f)].gap.values
            col = GR if c == "Line of sight" else LB
            vp = ax.violinplot(g, [i], widths=0.8, showextrema=False)
            for b in vp["bodies"]:
                b.set_facecolor(col); b.set_alpha(0.35); b.set_edgecolor("none")
            ax.scatter(np.full(g.size, i) + np.random.default_rng(i).uniform(-0.12, 0.12, g.size), g, s=12, color=col, zorder=3)
            ax.plot([i - 0.3, i + 0.3], [np.median(g)] * 2, color=DB, lw=2.5)
        ax.axhline(0, color=DB, lw=1)
        ax.set_xticks(range(3), ["LOS", "Diffr.", "Tropo."]); ax.set_ylim(-110, 15)
        ax.set_title(FLAB[f])
        if j == 0:
            ax.set_ylabel("P.2001 minus ITM (dB)")
        else:
            ax.set_yticklabels([])
    finish(fig, "1e_violins")


# =================== Finding 2: the diffraction gap ===================
H2 = "Most of ITM's extra diffraction loss comes from counting two knife edges"


def f2a():
    fig, gs = page("The diffraction gap grows with terrain roughness and frequency",
                   "P.2001 minus ITM at 50 % of time on links beyond line of sight, against ITM's terrain\n"
                   "irregularity Δh. Lines are medians by Δh band.", SRC_RT, left=0.13)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    ed = np.array([0, 25, 50, 100, 200, 400, 800, 2000]); xb = np.sqrt(np.maximum(ed[:-1], 12) * ed[1:])
    for k, f in enumerate(FREQS):
        d = bylink[(bylink.freq_mhz == f) & (bylink.itm_class != "Line of sight")]
        ax.scatter(np.maximum(d.delta_h_m, 5), d.gap, s=30, color=FCOL[f], alpha=0.45, edgecolor="none")
        b = np.digitize(d.delta_h_m, ed) - 1
        mb = [d.gap[b == i].median() if (b == i).sum() else np.nan for i in range(len(xb))]
        ok = ~np.isnan(mb)
        ax.plot(xb[ok], np.array(mb)[ok], color=FCOL[f], lw=3.5)
        last = np.where(ok)[0][-1]
        ax.text(xb[last] * 1.12, mb[last] + 3 * (k - 1), FLAB[f], color=FCOL[f], fontweight="bold", va="center")
    ax.axhline(0, color=DB, lw=1); ax.set_xscale("log"); ax.set_xlim(5, 4000)
    ax.set_xlabel("Terrain irregularity Δh (m), log scale"); ax.set_ylabel("P.2001 minus ITM (dB)")
    finish(fig, "2a_gap_vs_terrain")


def f2b():
    fig, gs = page(H2, "Median ITM minus P.452 diffraction loss on the diffraction links, and how much of it\n"
                   "goes away when each ITM ingredient is removed.", SRC_RT, nrows=3, left=0.3, hspace=0.45)
    for i, f in enumerate(FREQS):
        ax = fig.add_subplot(gs[i]); soft(ax)
        g = {c: abl[(abl.freq_mhz == f) & (abl["case"] == c)].median_gap_db.iloc[0]
             for c in ["ITM as is", "1 single edge", "4 all three"]}
        segs = [(0, g["ITM as is"]), (g["1 single edge"], g["ITM as is"]), (g["4 all three"], g["1 single edge"]),
                (min(0, g["4 all three"]), max(0, g["4 all three"]))]
        vals = [g["ITM as is"], g["1 single edge"] - g["ITM as is"], g["4 all three"] - g["1 single edge"], g["4 all three"]]
        cols = [LB, LG, LG, DB]
        labs = ["Median gap, ITM as published", "Count one knife edge, not two", "Drop clutter term; evaluate at path", "What remains"]
        for j, ((a, b), v, col) in enumerate(zip(segs, vals, cols)):
            ax.add_patch(Rectangle((min(a, b), j - 0.32), abs(b - a), 0.64, color=col, lw=0))
            ax.text(max(a, b) + 1.2, j, f"{v:+.0f} dB", va="center", fontsize=10, fontweight="semibold")
        ax.set_yticks(range(4), labs); ax.invert_yaxis(); ax.set_xlim(-14, 58); ax.set_ylim(3.6, -0.6)
        ax.axvline(0, color=DB, lw=1); ax.set_title(FLAB[f])
    fig.axes[-1].set_xlabel("ITM minus P.452 diffraction loss (dB)")
    finish(fig, "2b_waterfall")


def f2c():
    fig, gs = page(H2, "Median ITM minus P.452 diffraction loss on the diffraction links, as ITM stands\n"
                   "and with one ingredient removed at a time.", SRC_RT, left=0.12, right=0.7)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    cases = [("ITM as is", "ITM as published", LB, 4.5), ("2 no clutter term", "Without the clutter term", GR, 2),
             ("3 evaluated at the path", "Evaluated at the path", GR, 2), ("1 single edge", "One knife edge, not two", DB, 3.5),
             ("4 all three", "All three removed", GR, 2)]
    used = []
    for c, lab, col, lw in cases:
        g = [abl[(abl.freq_mhz == f) & (abl["case"] == c)].median_gap_db.iloc[0] for f in FREQS]
        ax.plot([2.7, 4.9, 7.25], g, "-o", color=col, lw=lw, ms=8, mec="white")
        yl = g[-1]
        while any(abs(yl - u) < 2.6 for u in used):
            yl -= 2.6
        used.append(yl)
        ax.text(7.55, yl, lab, color=col, fontweight="bold", va="center", fontsize=10.5, clip_on=False)
    ax.axhline(0, color=DB, lw=1); ax.set_xticks([2.7, 4.9, 7.25], ["2.7", "4.9", "7.25"]); ax.set_xlim(2.4, 7.4)
    ax.set_xlabel("Frequency (GHz)"); ax.set_ylabel("ITM minus P.452 diffraction loss (dB)")
    finish(fig, "2c_slope")


def f2d():
    fig, gs = page("The gap is a rough-terrain effect: under 50 m of terrain irregularity it nearly vanishes",
                   "Median of how much more loss ITM predicts than P.2001, by terrain irregularity and\n"
                   "frequency, on links beyond line of sight, at 50 % of time.", SRC_RT, left=0.24, top=0.78, bottom=0.12)
    ax = fig.add_subplot(gs[0])
    ed = [0, 50, 150, 300, 3000]; rl = ["Under 50 m", "50-150 m", "150-300 m", "Over 300 m"]
    d = bylink[bylink.itm_class != "Line of sight"].copy()
    d["band"] = pd.cut(d.delta_h_m, ed, labels=rl)
    M = np.array([[-d[(d.band == r) & (d.freq_mhz == f)].gap.median() for f in FREQS] for r in rl])
    N = np.array([[((d.band == r) & (d.freq_mhz == f)).sum() for f in FREQS] for r in rl])
    ax.imshow(M, cmap=PLASMA, vmin=0, vmax=60, aspect="auto")
    for i in range(4):
        for j in range(3):
            tc = "white" if M[i, j] < 36 else DB
            ax.text(j, i - 0.05, f"{abs(round(M[i, j])):.0f} dB", ha="center", va="center", fontsize=26, fontweight="bold", color=tc)
            ax.text(j, i + 0.32, f"{N[i, j]} links", ha="center", fontsize=9.5, color=tc)
    ax.set_xticks(range(3), [FLAB[f] for f in FREQS], fontsize=13); ax.xaxis.tick_top()
    ax.set_yticks(range(4), rl, fontsize=13); ax.set_ylabel("Terrain irregularity Δh", fontsize=11)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(length=0)
    finish(fig, "2d_heat_terrain")


def f2e():
    fig, gs = page(H2, "What each model's diffraction loss is made of: the median of each term over the\n"
                   "diffraction links. ITM weights two knife edges heavily and adds a clutter term.", SRC_RT, left=0.2, bottom=0.18)
    ax = fig.add_subplot(gs[0]); soft(ax)
    y, ticks, labs = 0, [], []
    for f in FREQS[::-1]:
        q = terms[terms.freq_mhz == f]
        parts = [(np.median(q.w_d3 * q.A_se_d3), "#C9D3EE"), (np.median((1 - q.w_d3) * q.A_k_d3), LB), (np.median(q.A_fo), PU)]
        pp = [(np.median(q.Lbulla), DB), (np.median(np.maximum(q.Ldsph - q.Lbulls, 0)), GR)]
        for row, name in ((pp, "P.452"), (parts, "ITM")):
            x = 0
            for v, col in row:
                ax.add_patch(Rectangle((x, y - 0.33), v, 0.66, color=col, lw=0)); x += v
            ax.text(x + 1.5, y, f"{x:.0f} dB", va="center", fontweight="bold")
            ticks.append(y); labs.append(f"{name}  ·  {FLAB[f]}"); y += 1
        y += 0.8
    ax.set_yticks(ticks, labs); ax.set_xlim(0, 135); ax.set_ylim(-0.7, y)
    ax.set_xlabel("Median diffraction loss and its terms (dB)")
    keys = [("#C9D3EE", "ITM smooth earth, weighted"), (LB, "ITM two knife edges, weighted"), (PU, "ITM clutter term"),
            (DB, "P.452 one knife edge"), (GR, "P.452 spherical-earth excess")]
    for k, (col, lab) in enumerate(keys):
        xx, yy = 0.2 + 0.36 * (k % 2), 0.115 - 0.018 * (k // 2)
        fig.text(xx, yy, "■", color=col, fontsize=13, va="center"); fig.text(xx + 0.022, yy, lab, fontsize=9.5, va="center")
    finish(fig, "2e_stacked_terms")


# =================== Finding 3: measurements ===================
H3 = "Against 118 measured paths from 1 GHz to 10 GHz, all three models are close at the median"


def f3a():
    fig, gs = page(H3, "How far each model's median loss is from the measurement, ITU-R databank, 1 GHz to 10 GHz.\n"
                   "The shaded band is within 10 dB.", SRC_DB, left=0.12)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    ax.axvspan(0, 10, color=PANEL, zorder=0)
    for k, m in enumerate(["p452", "p2001", "itm"]):
        e = np.sort(np.abs(err(m, "50", hi)))
        ax.step(e, np.arange(1, e.size + 1) / e.size, where="post", color=MCOL[m], lw=3.5 if m == "itm" else 2.5)
        w = (e <= 10).mean()
        ax.text(31, 0.32 - 0.06 * k, f"{MLAB[m]}: {100 * w:.0f} % within 10 dB", color=MCOL[m], fontweight="bold", fontsize=11)
    ax.set_xlim(0, 45); ax.set_ylim(0, 1.01)
    ax.set_xlabel("dB off the measured median"); ax.set_ylabel("Share of the 118 measured datasets")
    ax.yaxis.set_major_formatter(mpl.ticker.PercentFormatter(1.0))
    finish(fig, "3a_cdf_dB_off")


def f3b():
    fig, gs = page("Below 1 GHz all three predict a little too little loss; ITM drifts high above 6 GHz",
                   "Predicted minus measured median loss by frequency band, ITU-R databank. Each dot is a dataset.",
                   SRC_DB, nrows=3, left=0.12, hspace=0.3)
    for i, m in enumerate(["itm", "p452", "p2001"]):
        ax = fig.add_subplot(gs[i]); soft(ax, "y")
        for j, b in enumerate(BINS):
            e = err(m, "50", db.bin == b).values
            if e.size < 3:
                ax.text(j, 0, "n/a", ha="center", color=GR, fontsize=9); continue
            col = MCOL[m] if j >= 3 else LG
            ax.scatter(j + np.random.default_rng(j).uniform(-0.25, 0.25, e.size), e, s=9, color=col, alpha=0.6, zorder=2)
            ax.plot([j - 0.32, j + 0.32], [np.median(e)] * 2, color=DB, lw=2.5, zorder=3)
        ax.axhline(0, color=DB, lw=1); ax.set_ylim(-40, 45)
        ax.set_xticks(range(6), BINS if i == 2 else [""] * 6); ax.set_ylabel(f"{MLAB[m]} (dB)")
    finish(fig, "3b_strips_by_band")


def f3c():
    fig, gs = page(H3, "Predicted minus measured median loss by band: the line spans 80 % of the datasets\n"
                   "and the marker is the median.", SRC_DB, left=0.2)
    ax = fig.add_subplot(gs[0]); soft(ax)
    y, ticks, labs = 0, [], []
    for b in BINS[::-1]:
        for m in ["p2001", "p452", "itm"]:
            e = err(m, "50", db.bin == b)
            if e.size >= 3:
                q = np.percentile(e, [10, 50, 90])
                ax.plot(q[[0, 2]], [y, y], color=LG, lw=2.5, solid_capstyle="round")
                ax.scatter(q[[0, 2]], [y, y], s=14, color=GR, zorder=2)
                ax.scatter([q[1]], [y], s=70, marker="s" if m == "p452" else "o", color=MCOL[m], edgecolor="white", zorder=3)
            ticks.append(y); labs.append(MLAB[m]); y += 1
        ax.text(-49, y - 2, b, fontweight="bold", fontsize=10.5, va="center")
        y += 0.9
    ax.axvline(0, color=DB, lw=1); ax.set_yticks(ticks, labs); ax.set_xlim(-50, 40); ax.set_ylim(-0.8, y)
    ax.set_xlabel("Predicted minus measured median loss (dB)")
    finish(fig, "3c_range_bars")


def f3d():
    fig, gs = page("ITM's only clear bias at the median is above 6 GHz, where it predicts 7 dB too much loss",
                   "Mean predicted minus measured median loss, ITU-R databank. Blue: too little loss;\n"
                   "purple: too much.", SRC_DB, left=0.22, top=0.8, bottom=0.1)
    ax = fig.add_subplot(gs[0])
    ms = ["itm", "p452", "p2001"]
    M = np.array([[err(m, "50", db.bin == b).mean() if err(m, "50", db.bin == b).size >= 3 else np.nan for m in ms] for b in BINS])
    N = np.array([[err(m, "50", db.bin == b).size for m in ms] for b in BINS])
    ax.imshow(np.ma.masked_invalid(M), cmap=DIVERGE, vmin=-8, vmax=8, aspect="auto")
    for i in range(6):
        for j in range(3):
            if np.isnan(M[i, j]):
                ax.text(j, i, "not defined\nbelow 100 MHz", ha="center", va="center", color=GR, fontsize=9); continue
            tc = "white" if abs(M[i, j]) > 5.5 else DB
            ax.text(j, i - 0.07, f"{M[i, j]:+.1f} dB", ha="center", va="center", fontsize=21, fontweight="bold", color=tc)
            ax.text(j, i + 0.3, f"{N[i, j]} datasets", ha="center", fontsize=8.5, color=tc)
    ax.set_xticks(range(3), [MLAB[m] for m in ms], fontsize=13); ax.xaxis.tick_top()
    ax.set_yticks(range(6), BINS, fontsize=12)
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(length=0)
    finish(fig, "3d_heat_bias")


def f3e():
    fig, gs = page("Where each model misses: the three measurement regions, colored by dB off",
                   "Each dot is the midpoint of a measured path in the ITU-R databank, 30 MHz to 10 GHz.\n"
                   "Large misses are drawn on top. One Australian path is not shown.", SRC_DB,
                   nrows=3, ncols=3, left=0.1, right=0.97, hspace=0.12, wspace=0.05, bottom=0.15,
                   width_ratios=[1.93, 0.87, 0.73])
    regions = [("North America", (-125, -54), (24, 53), True), ("Europe", (-11, 16), (42.5, 61.5), False),
               ("Japan", (128, 146.5), (26, 46.5), False)]
    norm = Normalize(0, 20)
    lat = (db.tx_lat + db.rx_lat) / 2; lon = (db.tx_lon + db.rx_lon) / 2
    for i, m in enumerate(["itm", "p452", "p2001"]):
        for j, (rn, lo, la, us) in enumerate(regions):
            ax = fig.add_subplot(gs[i, j]); basemap(ax, lo, la, us=us); ax.set_anchor("C")
            sel = (lon >= lo[0]) & (lon <= lo[1]) & (lat >= la[0]) & (lat <= la[1])
            d = db[sel].assign(e=(db[f"{m}_50"] - db.meas_50).abs(), x=lon[sel], y=lat[sel]).dropna(subset=["e"]).sort_values("e")
            ax.scatter(d.x, d.y, c=d.e, cmap=PLASMA, norm=norm, s=16, edgecolor="white", linewidth=0.3, zorder=3)
            ax.text(0.03, 0.03, f"median {d.e.median():.1f} dB", transform=ax.transAxes, fontsize=8.5, color=DB)
            if i == 0:
                ax.set_title(rn, fontsize=11.5)
            if j == 0:
                ax.text(-0.06, 0.5, MLAB[m], transform=ax.transAxes, rotation=90, ha="right", va="center",
                        fontsize=13, fontweight="bold", color=MCOL[m] if m != "p452" else DB)
    cbar(fig, mpl.cm.ScalarMappable(norm, PLASMA), [0.3, 0.09, 0.4, 0.012], "dB off the measured median")
    finish(fig, "3e_map_dB_off")


# =================== Finding 4: the tails ===================
H4 = "At 1 % of time the ITU models predict signals stronger than measured; ITM does not"
PC, PV = ["01", "10", "50", "90", "99"], [1, 10, 50, 90, 99]


def f4a():
    fig, gs = page(H4, "Mean predicted minus measured loss against time percentage, ITU-R databank,\n"
                   "1 GHz to 10 GHz. The shaded band is within 3 dB.", SRC_DB, left=0.12, right=0.84)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    ax.axhspan(-3, 3, color=PANEL, zorder=0)
    for k, m in enumerate(["p452", "p2001", "itm"]):
        v = [err(m, p, hi).mean() if err(m, p, hi).size else np.nan for p in PC]
        ok = ~np.isnan(v)
        ax.plot(np.array(PV)[ok], np.array(v)[ok], "-o", color=MCOL[m], lw=4 if m == "itm" else 2.8, ms=8, mec="white")
        last = np.where(ok)[0][-1]
        ax.text(PV[last] * 1.15, v[last] + 0.6 * (k - 1), MLAB[m], color=MCOL[m], fontweight="bold", va="center", fontsize=12)
    ax.axhline(0, color=DB, lw=1); ax.set_xscale("log"); ax.set_xticks([1, 10, 50, 99], ["1 %", "10 %", "50 %", "99 %"]); ax.set_xlim(0.8, 160)
    ax.set_ylim(-12, 5); ax.set_xlabel("Percentage of time the loss is not exceeded")
    ax.set_ylabel("Mean predicted minus measured (dB)")
    ax.annotate("Too strong a signal predicted\nfor the worst 1 % of the time", xy=(1, -8.6), xytext=(2.2, -10.8),
                fontsize=10, color=PU, arrowprops=dict(arrowstyle="->", color=PU))
    finish(fig, "4a_bias_vs_time")


def f4b():
    fig, gs = page(H4, "Mean predicted minus measured loss by band and time percentage, ITU-R databank.\n"
                   "Blue: too little loss (signal too strong); purple: too much.", SRC_DB, nrows=3, left=0.18, hspace=0.35)
    for i, m in enumerate(["itm", "p452", "p2001"]):
        ax = fig.add_subplot(gs[i])
        M = np.array([[err(m, p, db.bin == b).mean() if err(m, p, db.bin == b).size >= 3 else np.nan for p in PC] for b in BINS])
        ax.imshow(np.ma.masked_invalid(M), cmap=DIVERGE, vmin=-15, vmax=15, aspect="auto")
        for r in range(6):
            for c in range(5):
                if not np.isnan(M[r, c]):
                    ax.text(c, r, f"{M[r, c]:+.0f}", ha="center", va="center", fontsize=10.5, fontweight="bold",
                            color="white" if abs(M[r, c]) > 9 else DB)
        ax.set_xticks(range(5), [f"{p} %" for p in PV]); ax.set_yticks(range(6), BINS, fontsize=9)
        ax.set_title(MLAB[m]); ax.tick_params(length=0)
        for s in ax.spines.values():
            s.set_visible(False)
    finish(fig, "4b_heat_by_time")


def f4c():
    fig, gs = page(H4, "Mean predicted minus measured loss at 50 % (open) and at 1 % of time (filled),\n"
                   "by band, ITU-R databank.", SRC_DB, left=0.2)
    ax = fig.add_subplot(gs[0]); soft(ax)
    y, ticks, labs = 0, [], []
    for b in BINS[::-1]:
        for m in ["p2001", "p452", "itm"]:
            e50, e1 = err(m, "50", db.bin == b), err(m, "01", db.bin == b)
            if e50.size >= 3 and e1.size >= 3:
                a, c = e50.mean(), e1.mean()
                ax.plot([a, c], [y, y], color=LG, lw=4, zorder=1)
                ax.scatter([a], [y], s=80, color="white", edgecolor=MCOL[m], linewidth=2, zorder=3)
                ax.scatter([c], [y], s=80, color=MCOL[m], edgecolor="white", zorder=4)
            ticks.append(y); labs.append(MLAB[m]); y += 1
        ax.text(-27.5, y - 2, b, fontweight="bold", va="center")
        y += 0.9
    ax.axvline(0, color=DB, lw=1); ax.set_yticks(ticks, labs); ax.set_xlim(-28, 14); ax.set_ylim(-0.8, y)
    ax.set_xlabel("Mean predicted minus measured (dB)")
    finish(fig, "4c_dumbbell_50_vs_1")


def f4d():
    fig, gs = page("All three models predict a deeper 1 % signal enhancement than the measurements show",
                   "Loss at 50 % minus loss at 1 % of time: how much stronger the signal gets 1 % of the time,\n"
                   "ITU-R databank, 1 GHz to 10 GHz. The bar is the median.", SRC_DB, left=0.12)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    vals = [("Measured", (db.meas_50 - db.meas_01)[hi], "#222222")] + \
           [(MLAB[m], (db[f"{m}_50"] - db[f"{m}_01"])[hi], MCOL[m]) for m in ["itm", "p452", "p2001"]]
    for j, (lab, v, col) in enumerate(vals):
        v = v.dropna().values
        ax.scatter(j + np.random.default_rng(j).uniform(-0.25, 0.25, v.size), v, s=22, color=col, alpha=0.55, edgecolor="none")
        ax.plot([j - 0.32, j + 0.32], [np.median(v)] * 2, color=DB, lw=3)
        ax.text(j + 0.36, np.median(v), f"{np.median(v):.0f} dB", fontweight="bold", va="center")
    ax.set_xticks(range(4), [v[0] for v in vals]); ax.set_xlim(-0.5, 3.9); ax.set_ylim(0, None)
    ax.set_ylabel("Loss at 50 % minus loss at 1 % of time (dB)")
    finish(fig, "4d_enhancement_depth")


def f4e():
    fig, gs = page("On real terrain, the models disagree most at small time percentages",
                   "Median P.2001 minus ITM over the 60 real-terrain links, against time percentage.",
                   SRC_RT, left=0.13, right=0.86)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    for k, f in enumerate(FREQS):
        d = gap_t[gap_t.freq_mhz == f]
        d = d[d.time_pct <= 50]
        ax.plot(d.time_pct, d.p2001_minus_itm_median_db, color=FCOL[f], lw=3.5)
        ax.text(60, d.p2001_minus_itm_median_db.iloc[-1] + 0.8 * (1 - k), FLAB[f], color=FCOL[f], fontweight="bold", va="center")
    ax.axhline(0, color=DB, lw=1); ax.set_xscale("log"); ax.set_xlim(0.001, 50)
    ax.set_xticks([0.001, 0.01, 0.1, 1, 10, 50], ["0.001 %", "0.01 %", "0.1 %", "1 %", "10 %", "50 %"])
    ax.set_xlabel("Percentage of time the loss is not exceeded"); ax.set_ylabel("P.2001 minus ITM, median (dB)")
    ax.text(0.0013, -27.5, "Ducting in P.2001 cuts its loss far below ITM's at small percentages", fontsize=10, color=PU)
    finish(fig, "4e_gap_vs_time")


if __name__ == "__main__":
    for fn in [f1a, f1b, f1c, f1d, f1e, f2a, f2b, f2c, f2d, f2e, f3a, f3b, f3c, f3d, f3e, f4a, f4b, f4c, f4d, f4e]:
        fn()
