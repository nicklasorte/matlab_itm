"""Write the CSV files behind the deep-dive figures (where the models diverge).

Reads figures/wp_results_rev1.mat (written by make_wp_figures_rev1.m; no
model runs) and writes, to chart_data/:
  deep_smooth_earth.csv     smooth earth, land and sea: loss by model,
                            frequency, distance, at 50 % of time, with ITM's
                            mode code at each distance
  deep_radials.csv          four real-terrain radials from 38.90 N, 77.45 W
                            (30 m and 10 m antennas): loss by model,
                            frequency, distance, at 1 % and 50 % of time
  deep_time_by_link.csv     the 60 real-terrain links: loss by model,
                            frequency, and all 30 time percentages, with
                            ITM's mode code
  deep_archetype_profiles.csv  terrain profiles of the five archetype paths

Run:  python3 export_deep_dive_data_rev1.py
"""

from pathlib import Path

import numpy as np
import pandas as pd
import scipy.io as sio

HERE = Path(__file__).resolve().parent
OUT = HERE / "chart_data"
R = sio.loadmat(HERE / "figures" / "wp_results_rev1.mat", variable_names=["R"], squeeze_me=True, struct_as_record=False)["R"]
F, P = np.atleast_1d(R.freqs_mhz), np.atleast_1d(R.p)
i50 = int(np.where(P == 50)[0][0])
MOD = ["itm", "p452", "p2001"]

rows = []
for case in ["land", "sea"]:
    c = getattr(R.E1, case)
    for fi, f in enumerate(F):
        for di, d in enumerate(R.E1.D_km):
            rows.append(dict(surface=case, freq_mhz=f, d_km=d, free_space_db=R.E1.fsl[fi, di],
                             itm_mode_code=c.itm_mech[fi, di],
                             **{f"{m}_50_db": getattr(c, m)[fi, di, i50] for m in MOD}))
pd.DataFrame(rows).to_csv(OUT / "deep_smooth_earth.csv", index=False)

r = R.E8.radial
rows = []
for j, az in enumerate(np.atleast_1d(r.az)):
    for k, d in enumerate(r.D_km):
        for fi, f in enumerate(F):
            row = dict(azimuth_deg=az, d_km=d, freq_mhz=f)
            for pi, p in enumerate([1, 50]):
                for m in MOD:
                    row[f"{m}_{p}_db"] = getattr(r, m)[j, k, fi, pi]
            rows.append(row)
pd.DataFrame(rows).to_csv(OUT / "deep_radials.csv", index=False)

E7 = R.E7
rows = []
for fi, f in enumerate(F):
    for k in range(E7.itm.shape[1]):
        for pi, p in enumerate(P):
            rows.append(dict(link=k + 1, freq_mhz=f, time_pct=p, itm_mode_code=E7.itm_mech[fi, k],
                             **{f"{m}_db": getattr(E7, m)[fi, k, pi] for m in MOD}))
pd.DataFrame(rows).to_csv(OUT / "deep_time_by_link.csv", index=False)

names = ["Line of sight", "Single-horizon diffraction", "Double-horizon diffraction", "Troposcatter", "Over-sea coastal"]
rows = []
for a, name in zip(np.atleast_1d(R.E5), names):
    pr = a.prof
    for d, h in zip(pr.d_km, pr.h_m):
        rows.append(dict(path=name, link=a.link, htx_m=a.htx, hrx_m=a.hrx, d_km=d, h_m=h))
pd.DataFrame(rows).to_csv(OUT / "deep_archetype_profiles.csv", index=False)
print("wrote deep-dive CSV files")
