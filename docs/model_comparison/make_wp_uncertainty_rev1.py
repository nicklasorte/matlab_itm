"""Uncertainty in the working paper's headline numbers (3 GHz).

Bootstrap 95 % confidence intervals (10,000 resamples, fixed seed) for:
  - the median ITM minus P.2001 gap by ITM mechanism class, and the share of
    links more than 20 dB apart (resampling links)
  - the median gap in the two groups split at ITM's smooth-earth weight
    w = 0.12, and the split point itself (the w that best separates the
    gaps, found again in each resample)
  - each model's mean error against the measurements, resampling measured
    paths (not datasets), because datasets on one path share its errors
plus Hartigan's dip test for bimodality of the diffraction-link gap, and
the number of links that would narrow each class interval to +/-3 dB.

Reads CSV only. Writes chart_data/uncertainty_summary.csv,
chart_data/uncertainty_measurements.csv, figures/s26_uncertainty_gap.png,
figures/s27_uncertainty_measured.png, and adds keys to
figures/numbers_3ghz.json.

Run:  python3 make_wp_uncertainty_rev1.py
"""

import json

import diptest
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import make_wp_figures_3ghz as S
from make_wp_charts_rev1 import DB, LB, GR, LG, CD, FIG

B = 10_000
rng = np.random.default_rng(20261108)


def boot_median(v):
    v = np.asarray(v)
    idx = rng.integers(0, v.size, (B, v.size))
    m = np.median(v[idx], axis=1)
    return np.median(v), *np.percentile(m, [2.5, 97.5])


def best_split(w, g, grid=np.linspace(0.04, 0.4, 73)):
    """w that maximizes the between-group difference in median gap, weighted by balance."""
    best, val = np.nan, -np.inf
    for t in grid:
        lo, hi = g[w < t], g[w >= t]
        if lo.size < 3 or hi.size < 3:
            continue
        s = (np.median(lo) - np.median(hi)) * np.sqrt(lo.size * hi.size) / w.size
        if s > val:
            best, val = t, s
    return best


rows = []
b = S.b
for c in S.CLS:
    v = b[b.itm_class == c].apart.values
    m, lo, hi = boot_median(v)
    half = (hi - lo) / 2
    n3 = int(np.ceil(v.size * (half / 3) ** 2)) if half > 3 else v.size
    sh = (v[rng.integers(0, v.size, (B, v.size))] > 20).mean(axis=1)
    rows.append(dict(quantity=f"{c} links", n=v.size, median_db=m, ci_low_db=lo, ci_high_db=hi, links_for_pm3db=n3,
                     share_over_20db=(v > 20).mean(), share_low=np.percentile(sh, 2.5), share_high=np.percentile(sh, 97.5)))

t = S.terms
w = t.w_d3.values
g = (t.itm_excess_50 - t.p2001_excess_50).values
for lab, sel in (("w under 0.12", w < 0.12), ("w 0.12 or more", w >= 0.12)):
    m, lo, hi = boot_median(g[sel])
    rows.append(dict(quantity=lab, n=int(sel.sum()), median_db=m, ci_low_db=lo, ci_high_db=hi, links_for_pm3db=np.nan))

splits = []
for _ in range(2000):
    i = rng.integers(0, w.size, w.size)
    splits.append(best_split(w[i], g[i]))
splits = np.array(splits)
sp = best_split(w, g)
dip, pdip = diptest.diptest(g)
U = pd.DataFrame(rows)
U.to_csv(CD / "uncertainty_summary.csv", index=False)

# ---- measurements: cluster bootstrap over paths ----
d = S.db
groups = {"All": d.freq_mhz > 0, "30 MHz-1 GHz": d.freq_mhz < 1000, "1-10 GHz": d.freq_mhz >= 1000}
mrows = []
for gname, gsel in groups.items():
    q = d[gsel]
    paths = q.path.unique()
    for m in ["itm", "p452", "p2001"]:
        e = (q[f"{m}_50"] - q.meas_50)
        ok = e.notna()
        if ok.sum() < 5:
            continue
        qq = q[ok].assign(e=e[ok])
        per = qq.groupby("path").e.agg(["sum", "size"])
        pv = per.index.values
        sums, sizes = per["sum"].values, per["size"].values
        bs = []
        for _ in range(B):
            i = rng.integers(0, pv.size, pv.size)
            bs.append(sums[i].sum() / sizes[i].sum())
        lo, hi = np.percentile(bs, [2.5, 97.5])
        mrows.append(dict(group=gname, model=m, datasets=int(ok.sum()), paths=int(pv.size), mean_error_db=qq.e.mean(), ci_low_db=lo, ci_high_db=hi))
M = pd.DataFrame(mrows)
M.to_csv(CD / "uncertainty_measurements.csv", index=False)

# ---- figures ----
fig, ax = S.new(2.9); S.clean(ax, "x")
for i, r in U.iterrows():
    col = S.CC.get(r.quantity.replace(" links", ""), DB if "under" in r.quantity else LB)
    ax.plot([r.ci_low_db, r.ci_high_db], [i, i], color=col, lw=6, alpha=0.35, solid_capstyle="round")
    ax.scatter([r.median_db], [i], s=60, color=col, edgecolor="white", zorder=3)
    ax.text(r.ci_high_db + 1.5, i, f"{r.median_db:.0f} dB ({r.ci_low_db:.0f} to {r.ci_high_db:.0f})", va="center", fontsize=8.5)
ax.axvline(0, color=DB, lw=0.8)
ax.set_yticks(range(len(U)), [f"{q} ({n})" for q, n in zip(U.quantity, U.n)]); ax.set_ylim(len(U) - 0.4, -0.6)
ax.set_xlim(-10, 80); ax.set_xlabel("Median ITM minus P.2001 at 3 GHz with its 95 % bootstrap interval (dB)")
S.save(fig, "s26_uncertainty_gap")

fig, ax = S.new(3.0); S.clean(ax, "x")
y, ticks, labs = 0, [], []
for gname in groups:
    for m in ["itm", "p452", "p2001"]:
        r = M[(M.group == gname) & (M.model == m)]
        if r.empty:
            continue
        r = r.iloc[0]
        ax.plot([r.ci_low_db, r.ci_high_db], [y, y], color=S.MC[m], lw=6, alpha=0.35, solid_capstyle="round")
        ax.scatter([r.mean_error_db], [y], s=55, color=S.MC[m], edgecolor="white", zorder=3)
        ticks.append(y); labs.append(f"{S.ML[m]}, {gname}"); y += 1
    y += 0.6
ax.axvline(0, color=DB, lw=0.8)
ax.set_yticks(ticks, labs); ax.set_ylim(y - 0.4, -0.6); ax.set_xlim(-6, 4)
ax.set_xlabel("Mean predicted minus measured loss at 50 % with its 95 % interval, resampling paths (dB)")
S.save(fig, "s27_uncertainty_measured")

N = json.load(open(FIG / "numbers_3ghz.json"))
for _, r in U.iterrows():
    k = r.quantity.replace(" ", "_")
    N[f"u_{k}_lo"], N[f"u_{k}_hi"], N[f"u_{k}_n3"] = round(r.ci_low_db, 1), round(r.ci_high_db, 1), (None if pd.isna(r.links_for_pm3db) else int(r.links_for_pm3db))
    if not pd.isna(r.get("share_over_20db", np.nan)):
        N[f"u_{k}_share"] = [round(100 * r.share_over_20db), round(100 * r.share_low), round(100 * r.share_high)]
N.update(u_split=round(float(sp), 3), u_split_lo=round(float(np.nanpercentile(splits, 2.5)), 3), u_split_hi=round(float(np.nanpercentile(splits, 97.5)), 3),
         u_dip=round(float(dip), 3), u_dip_p=round(float(pdip), 4), u_B=B)
for _, r in M.iterrows():
    N[f"um_{r.group}_{r.model}"] = [round(r.mean_error_db, 1), round(r.ci_low_db, 1), round(r.ci_high_db, 1), int(r.paths)]
json.dump(N, open(FIG / "numbers_3ghz.json", "w"), indent=1)
print(U.round(1).to_string()); print(M.round(1).to_string()); print("split", sp, np.nanpercentile(splits, [2.5, 97.5]), "dip", dip, pdip)
