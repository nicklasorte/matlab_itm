"""Ten chart forms for the paper's key graph.

The key graph: how far ITM and P.2001 are apart on the 60 real-terrain
links at 50 % of time, by ITM's propagation mechanism (line of sight,
diffraction, troposcatter) and frequency (2.7, 4.9, and 7.25 GHz). The
models agree within 1 dB in line of sight and are 30 dB to 48 dB apart
beyond the horizon.

Each design is a full page: marking, headline, subtitle, chart, source.
Reads chart_data/ only (via make_wp_charts_rev1); writes figures/key_NN_*.png.

Run:  python3 make_wp_key_graph_rev1.py
"""

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import FancyBboxPatch, Rectangle
from scipy.stats import gaussian_kde

import make_wp_charts_rev1 as C
from make_wp_charts_rev1 import DB, LB, PU, GR, LG, PANEL, FREQS, FLAB, CLASSES, SRC_RT, MARK, page, soft, FIG

b = C.bylink.copy()
b["apart"] = -b.gap                      # dB of extra loss ITM predicts over P.2001
CC = {"Line of sight": "#9AA0A6", "Diffraction": LB, "Troposcatter": PU}
SHORT = {"Line of sight": "Line of sight", "Diffraction": "Diffraction", "Troposcatter": "Troposcatter"}
H = "The models agree in line of sight and split by 30 dB or more beyond the horizon"
XL = "How much more loss ITM predicts than P.2001 (dB)"


def fmt(x):
    return f"{0 if abs(x) < 0.5 else x:.0f}"


def sel(c, f):
    return b[(b.itm_class == c) & (b.freq_mhz == f)]


def med(c, f):
    return sel(c, f).apart.median()


def save(fig, name):
    fig.savefig(FIG / f"key_{name}.png", dpi=220)
    plt.close(fig)
    print("wrote", name)


def class_key(fig, x, y, dx=0.2):
    for k, c in enumerate(CLASSES):
        fig.text(x + dx * k, y, "●", color=CC[c], fontsize=13, va="center")
        fig.text(x + dx * k + 0.02, y, c, fontsize=10, va="center", color=DB)


def swarm(v, width=0.38, size=0.9):
    """Beeswarm offsets: place each value at the smallest free offset."""
    order = np.argsort(v); pos = np.zeros(v.size); placed = []
    for i in order:
        for off in sorted(np.r_[0, np.arange(1, 40), -np.arange(1, 40)] * 0.045, key=abs):
            if all((abs(v[i] - v[j]) > size or abs(off - pos[j]) > 0.044) for j in placed):
                pos[i] = off; break
        placed.append(i)
    return np.clip(pos, -width, width)


# 1 ---------- ridgeline ----------
def k01():
    fig, gs = page(H, "Distribution over the links of how much more loss ITM predicts than P.2001,\n"
                   "at 50 % of time. Each ridge is one mechanism at one frequency.", SRC_RT, left=0.27, bottom=0.11)
    ax = fig.add_subplot(gs[0]); ax.set_yticks([]); ax.spines["left"].set_visible(False)
    xs = np.linspace(-15, 110, 600); y = 0; ticks = []
    for c in CLASSES[::-1]:
        for f in FREQS[::-1]:
            v = sel(c, f).apart.values
            k = gaussian_kde(v, bw_method=0.35 if c != "Line of sight" else 0.6)(xs)
            k = k / k.max() * 1.25
            ax.fill_between(xs, y, y + k, color=CC[c], alpha=0.85, lw=0, zorder=10 - y)
            ax.plot(xs, y + k, color="white", lw=1.4, zorder=10 - y)
            ax.plot([np.median(v)] * 2, [y, y + np.interp(np.median(v), xs, k)], color="white", lw=1.6, zorder=10 - y)
            ax.text(-17, y + 0.18, f"{c} · {FLAB[f]}", ha="right", fontsize=10, color=DB)
            ax.text(np.median(v) + 1.5, y + 0.15, f"{fmt(np.median(v))} dB", fontsize=9, color="white" if c != "Line of sight" else DB,
                    fontweight="bold", zorder=20)
            y += 0.62
        y += 0.5
    ax.set_xlim(-15, 110); ax.set_ylim(-0.1, y + 0.9); ax.xaxis.grid(True, color="#EDEDED"); ax.set_axisbelow(True)
    ax.set_xlabel(XL)
    save(fig, "01_ridgeline")


# 2 ---------- beeswarm ----------
def k02():
    fig, gs = page(H, "Each dot is one link at 50 % of time. Columns are ITM's mechanism classes;\n"
                   "the number is the median.", SRC_RT, ncols=3, left=0.1, wspace=0.08, bottom=0.12)
    for j, f in enumerate(FREQS):
        ax = fig.add_subplot(gs[j]); soft(ax, "y")
        for i, c in enumerate(CLASSES):
            v = sel(c, f).apart.values
            ax.scatter(i + swarm(v, size=2.6), v, s=30, color=CC[c], edgecolor="white", linewidth=0.5, zorder=3)
            m = np.median(v)
            ax.plot([i - 0.36, i + 0.36], [m, m], color=DB, lw=2, zorder=4)
            ax.text(i, 108, f"{fmt(m)}", ha="center", fontsize=15, fontweight="bold", color=CC[c] if c != "Line of sight" else GR)
        ax.set_xticks(range(3), ["Line of\nsight", "Diffrac-\ntion", "Tropo-\nscatter"], fontsize=9)
        ax.set_ylim(-12, 116); ax.set_title(FLAB[f], fontsize=12)
        if j: ax.set_yticklabels([])
        else: ax.set_ylabel(XL)
    save(fig, "02_beeswarm")


# 3 ---------- raincloud ----------
def k03():
    fig, gs = page(H, "Raincloud: the density (cloud), the middle half and median (box), and every link (rain),\n"
                   "at 50 % of time.", SRC_RT, left=0.27, bottom=0.11)
    ax = fig.add_subplot(gs[0]); soft(ax)
    xs = np.linspace(-15, 110, 500); y = 0; ticks, labs = [], []
    rng = np.random.default_rng(3)
    for c in CLASSES[::-1]:
        for f in FREQS[::-1]:
            v = sel(c, f).apart.values
            k = gaussian_kde(v, bw_method=0.4 if c != "Line of sight" else 0.6)(xs); k = k / k.max() * 0.55
            ax.fill_between(xs, y + 0.08, y + 0.08 + k, color=CC[c], alpha=0.55, lw=0)
            q1, m, q3 = np.percentile(v, [25, 50, 75])
            ax.add_patch(FancyBboxPatch((q1, y - 0.06), max(q3 - q1, 0.4), 0.12, boxstyle="round,pad=0,rounding_size=0.05",
                                        color=CC[c], lw=0, zorder=3))
            ax.plot([m, m], [y - 0.1, y + 0.1], color="white", lw=2, zorder=4)
            ax.scatter(v, y - 0.25 + rng.uniform(-0.07, 0.07, v.size), s=10, color=CC[c], alpha=0.8, edgecolor="none")
            ticks.append(y); labs.append(f"{c} · {FLAB[f]}"); y += 0.95
        y += 0.45
    ax.set_yticks(ticks, labs); ax.set_xlim(-15, 110); ax.set_ylim(-0.6, y - 0.3)
    ax.set_xlabel(XL)
    save(fig, "03_raincloud")


# 4 ---------- hero numbers with mini strips ----------
def k04():
    fig, gs = page(H, "Median of how much more loss ITM predicts than P.2001, at 50 % of time.\n"
                   "The strip under each number shows every link.", SRC_RT, nrows=3, ncols=3, left=0.2, right=0.95,
                   hspace=0.35, wspace=0.12, bottom=0.1)
    for i, c in enumerate(CLASSES):
        for j, f in enumerate(FREQS):
            ax = fig.add_subplot(gs[i, j]); ax.set_xlim(-15, 110); ax.set_ylim(0, 1); ax.axis("off")
            ax.add_patch(FancyBboxPatch((-13, 0.02), 121, 0.96, boxstyle="round,pad=0,rounding_size=6",
                                        color=PANEL if c == "Line of sight" else ("#E9EDF8" if c == "Diffraction" else "#EFEAF4"),
                                        lw=0, mutation_aspect=1 / 60))
            m = med(c, f)
            ax.text(48, 0.6, f"{fmt(m)}", ha="center", va="center", fontsize=44, fontweight="bold", color=CC[c] if c != "Line of sight" else GR)
            ax.text(48, 0.36, "dB", ha="center", va="center", fontsize=11, color=GR)
            v = sel(c, f).apart.values
            ax.plot([-5, 100], [0.18, 0.18], color="white", lw=6, solid_capstyle="round")
            ax.scatter(np.clip(v, -5, 100), np.full(v.size, 0.18), s=14, color=CC[c], alpha=0.75, edgecolor="none", zorder=3)
            if i == 0:
                ax.set_title(FLAB[f], fontsize=13, loc="center")
            if j == 0:
                ax.text(-20, 0.5, c.replace(" of ", " of\n"), ha="right", va="center", fontsize=13, fontweight="semibold", color=DB)
    fig.text(0.2, 0.075, "Strip scale: 0 dB at the left to 100 dB at the right.", fontsize=9, color=GR)
    save(fig, "04_hero_numbers")


# 5 ---------- paired scatter ----------
def k05():
    fig, gs = page(H, "Each dot is a link at 50 % of time: P.2001's loss against ITM's, both above free space.\n"
                   "On the diagonal the models agree; above it ITM predicts more loss.", SRC_RT, nrows=3, left=0.2, right=0.8,
                   hspace=0.28, bottom=0.11)
    for i, f in enumerate(FREQS):
        ax = fig.add_subplot(gs[i]); ax.set_aspect("equal")
        d = b[b.freq_mhz == f]
        x, y = d.p2001_50_db - d.free_space_db, d.itm_50_db - d.free_space_db
        ax.fill_between([0, 160], [0, 160], [30, 190], color="#F3F0F7", lw=0, zorder=0)
        ax.plot([0, 160], [0, 160], color=GR, lw=1, zorder=1)
        ax.plot([0, 160], [30, 190], color=PU, lw=0.8, ls=(0, (3, 3)), zorder=1)
        ax.text(10, 46, "+30 dB", color=PU, fontsize=8.5, rotation=45)
        for c in CLASSES:
            s = d.itm_class == c
            ax.scatter(x[s], y[s], s=26, color=CC[c], edgecolor="white", linewidth=0.5, zorder=3)
        ax.set_xlim(-2, 100); ax.set_ylim(-2, 160); ax.set_title(FLAB[f], fontsize=12)
        ax.set_xticks([0, 50, 100]); ax.set_yticks([0, 50, 100, 150])
        ax.set_ylabel("ITM (dB)")
        if i == 2: ax.set_xlabel("P.2001 loss above free space (dB)")
    class_key(fig, 0.2, 0.06)
    save(fig, "05_paired_scatter")


# 6 ---------- slope chart ----------
def k06():
    fig, gs = page(H, "Each line is a link at 50 % of time, from P.2001's loss (left) to ITM's (right), above free space.\n"
                   "Flat lines agree; steep lines are where the models split.", SRC_RT, ncols=3, left=0.09, right=0.95,
                   wspace=0.18, bottom=0.12)
    for j, f in enumerate(FREQS):
        ax = fig.add_subplot(gs[j]); soft(ax, "y")
        d = b[b.freq_mhz == f]
        for c in CLASSES:
            for _, r in d[d.itm_class == c].iterrows():
                ax.plot([0, 1], [r.p2001_50_db - r.free_space_db, r.itm_50_db - r.free_space_db], color=CC[c], lw=1.1,
                        alpha=0.75 if c != "Line of sight" else 0.9, solid_capstyle="round")
        ax.set_xticks([0, 1], ["P.2001", "ITM"], fontsize=11, fontweight="semibold"); ax.set_xlim(-0.08, 1.08)
        ax.set_ylim(-3, 165); ax.set_title(FLAB[f], fontsize=12)
        ax.spines["bottom"].set_visible(False)
        if j: ax.set_yticklabels([])
        else: ax.set_ylabel("Loss above free space (dB)")
    class_key(fig, 0.12, 0.075)
    save(fig, "06_slope")


# 7 ---------- ECDF ----------
def k07():
    fig, gs = page(H, "Share of links where ITM predicts at least a given amount more loss than P.2001,\n"
                   "at 50 % of time, all three frequencies.", SRC_RT, left=0.13, right=0.8)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    for c in CLASSES:
        v = np.sort(b[b.itm_class == c].apart.values)
        share = 1 - np.arange(v.size) / v.size
        ax.step(np.r_[-10, v], np.r_[1, share], where="post", color=CC[c], lw=3.5)
        k = (v >= 30).mean()
        ax.text(112, share[-1] if c == "Line of sight" else np.interp(95, v, share) + 0.02, c, color=CC[c], fontweight="bold", fontsize=11)
        ax.scatter([30], [k], s=60, color=CC[c], edgecolor="white", zorder=4)
        ax.text(31.5, k + 0.025, f"{100 * k:.0f} %", color=CC[c], fontweight="bold", fontsize=10)
    ax.axvline(30, color=DB, lw=0.8, ls=(0, (3, 3)))
    ax.text(30.8, 1.03, "30 dB", fontsize=9, color=DB)
    ax.set_xlim(-10, 110); ax.set_ylim(0, 1.06)
    ax.yaxis.set_major_formatter(mpl.ticker.PercentFormatter(1.0))
    ax.set_xlabel(XL); ax.set_ylabel("Share of links at or above")
    save(fig, "07_exceedance")


# 8 ---------- waffle ----------
def k08():
    bins = [(-100, 5, "Under 5 dB"), (5, 30, "5 to 30 dB"), (30, 60, "30 to 60 dB"), (60, 200, "Over 60 dB")]
    shades = ["#D9DCE0", "#A9B8E3", LB, DB]
    fig, gs = page(H, "Every link at every frequency is one square (60 links × 3 frequencies), at 50 % of time,\n"
                   "shaded by how much more loss ITM predicts than P.2001.", SRC_RT, nrows=3, left=0.27, right=0.93,
                   hspace=0.3, bottom=0.14)
    for i, c in enumerate(CLASSES):
        ax = fig.add_subplot(gs[i]); ax.axis("off"); ax.set_aspect("equal")
        v = np.sort(b[b.itm_class == c].apart.values)
        cols = 18
        for k, x in enumerate(v):
            sh = shades[next(n for n, (lo, hi, _) in enumerate(bins) if lo <= x < hi)]
            ax.add_patch(FancyBboxPatch((k % cols, -(k // cols)), 0.84, 0.84, boxstyle="round,pad=0,rounding_size=0.15", color=sh, lw=0))
        ax.set_xlim(-0.2, cols); ax.set_ylim(-4.2, 1)
        ax.text(-0.8, 0.4, c, ha="right", va="center", fontsize=13, fontweight="semibold", color=DB)
        ax.text(-0.8, -0.5, f"{v.size} link-frequencies", ha="right", va="center", fontsize=9.5, color=GR)
        ax.text(-0.8, -1.4, f"median {np.median(v):.0f} dB", ha="right", va="center", fontsize=9.5, color=GR)
    for k, ((_, _, lab), sh) in enumerate(zip(bins, shades)):
        fig.text(0.27 + 0.16 * k, 0.09, "■", color=sh, fontsize=16, va="center")
        fig.text(0.295 + 0.16 * k, 0.09, lab, fontsize=10, va="center")
    save(fig, "08_waffle")


# 9 ---------- gap against path length ----------
def k09():
    fig, gs = page("Path length does not decide the split; the propagation mechanism does",
                   "How much more loss ITM predicts than P.2001 against path length, at 50 % of time,\n"
                   "all three frequencies. Color is ITM's mechanism class.", SRC_RT, left=0.13)
    ax = fig.add_subplot(gs[0]); soft(ax, "y")
    for c in CLASSES:
        d = b[b.itm_class == c]
        ax.scatter(d.length_km, d.apart, s=34, color=CC[c], alpha=0.8, edgecolor="white", linewidth=0.5, label=c)
    ax.axhline(0, color=DB, lw=0.8)
    los = b[b.itm_class == "Line of sight"].length_km.max()
    ax.axvspan(0, los, color=PANEL, zorder=0)
    ax.text(2, 104, "Range of the\nline-of-sight links", fontsize=9.5, color=GR, va="top")
    ax.set_xlim(0, b.length_km.max() * 1.05); ax.set_ylim(-12, 108)
    ax.set_xlabel("Path length (km)"); ax.set_ylabel(XL)
    ax.legend(loc="upper right", fontsize=10, markerscale=1.3)
    save(fig, "09_vs_length")


# 10 ---------- dark interval chart ----------
def k10():
    bg, fg, mut = "#0F1B2D", "#E8ECF4", "#8C97AB"
    cc = {"Line of sight": "#B8BEC8", "Diffraction": "#8FA8F0", "Troposcatter": "#B99AE0"}
    fig = plt.figure(figsize=(8.5, 11), facecolor=bg)
    fig.text(0.07, 0.975, MARK, fontsize=8.5, fontweight="bold", color=fg, va="top")
    fig.text(0.07, 0.95, "The models agree in line of sight and\nsplit by 30 dB or more beyond the horizon", fontsize=21,
             fontweight="bold", color=fg, va="top", linespacing=1.15)
    fig.text(0.07, 0.865, "How much more loss ITM predicts than P.2001, at 50 % of time. The bright band holds\n"
             "the middle half of the links, the faint band 80 %; the dot is the median.", fontsize=11.5, color=mut, va="top")
    fig.text(0.07, 0.022, SRC_RT, fontsize=8, color=mut)
    ax = fig.add_axes([0.27, 0.1, 0.66, 0.68], facecolor=bg)
    for s in ax.spines.values(): s.set_visible(False)
    ax.tick_params(colors=fg, length=0); ax.xaxis.grid(True, color="#22324A"); ax.set_axisbelow(True)
    y, ticks, labs = 0, [], []
    for c in CLASSES[::-1]:
        for f in FREQS[::-1]:
            v = sel(c, f).apart.values
            p10, p25, m, p75, p90 = np.percentile(v, [10, 25, 50, 75, 90])
            ax.plot([p10, p90], [y, y], color=cc[c], lw=10, alpha=0.25, solid_capstyle="round")
            ax.plot([p25, p75], [y, y], color=cc[c], lw=10, alpha=0.7, solid_capstyle="round")
            ax.scatter([m], [y], s=110, color=fg, edgecolor=cc[c], linewidth=2.5, zorder=3)
            ax.text(max(p90, m) + 4, y, f"{fmt(m)} dB", va="center", color=fg, fontsize=10.5, fontweight="bold")
            ticks.append(y); labs.append(f"{c} · {FLAB[f]}"); y += 1
        y += 0.8
    ax.set_yticks(ticks, labs, color=fg); ax.set_xlim(-10, 100); ax.set_ylim(-0.8, y - 0.4)
    ax.set_xlabel(XL, color=fg)
    fig.savefig(FIG / "key_10_dark_intervals.png", dpi=220, facecolor=bg); plt.close(fig); print("wrote 10_dark_intervals")


if __name__ == "__main__":
    for fn in [k01, k02, k03, k04, k05, k06, k07, k08, k09, k10]:
        fn()
