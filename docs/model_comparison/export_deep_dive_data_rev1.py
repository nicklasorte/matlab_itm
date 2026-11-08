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
  deep_archetype_time.csv   the five archetype paths: loss by model,
                            frequency, and all 30 time percentages, ITM's
                            10 % and 90 % confidence, and the dominant
                            P.452 and P.2001 mechanism (0 line of sight,
                            1 diffraction, 2 anomalous, 3 troposcatter,
                            4 sporadic-E)
  deep_smooth_earth_time.csv  smooth earth, land and sea: loss by model and
                            dominant mechanism at all 30 time percentages
  deep_itm_climate.csv      ITM on the double-horizon archetype at 2.7 GHz:
                            loss at 1, 10, 50, 90, and 99 % for radio
                            climates 1 to 7 (N0 320) and for N0 280 to 360
                            (climate 6)
  deep_knife_edge.csv       single raised point on a 20 km path: v, J(v), and
                            each model's loss above free space
  deep_freq_sweep.csv       three archetype paths, 100 MHz to 10 GHz: each
                            model's loss above free space at 50 % of time

Also rewrites, from the same .mat, the files export_wp_chart_data_rev1.m
writes (real_terrain_by_link.csv, real_terrain_gap_by_time.csv,
terrain_resolution_by_link.csv), so a rerun at one frequency needs no
second MATLAB pass. real_terrain_links.csv (the link table) is unchanged.

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
if F.size == 1:   # squeeze_me drops the frequency axis; put it back
    ex = lambda o, names, ax: [setattr(o, n, np.expand_dims(np.asarray(getattr(o, n)), ax)) for n in names]
    for case in ("land", "sea"):
        ex(getattr(R.E1, case), ["itm", "p452", "p2001", "itm_mech", "p452_mech", "p2001_mech"], 0)
    R.E1.fsl = np.atleast_2d(R.E1.fsl)
    ex(R.E8.radial, ["itm", "p452", "p2001"], 2)
    ex(R.E7, ["itm", "p452", "p2001", "itm_mech", "p452_mech", "p2001_mech"], 0)
    for a_ in np.atleast_1d(R.E5):
        ex(a_, ["itm", "p452", "p2001", "p2001_mech", "p452_mech", "itm_c10", "itm_c90"], 0)
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
rows = []
for a, name in zip(np.atleast_1d(R.E5), names):
    for fi, f in enumerate(F):
        for pi, p in enumerate(P):
            rows.append(dict(path=name, freq_mhz=f, time_pct=p, length_km=a.length_km, itm_mode_code=np.atleast_1d(a.itm_mech)[fi],
                             itm_db=a.itm[fi, pi], itm_c10_db=a.itm_c10[fi, pi], itm_c90_db=a.itm_c90[fi, pi],
                             p452_db=a.p452[fi, pi], p2001_db=a.p2001[fi, pi],
                             p452_mech=a.p452_mech[fi, pi], p2001_mech=a.p2001_mech[fi, pi]))
pd.DataFrame(rows).to_csv(OUT / "deep_archetype_time.csv", index=False)

rows = []
for case in ["land", "sea"]:
    c = getattr(R.E1, case)
    for fi, f in enumerate(F):
        for di, d in enumerate(R.E1.D_km):
            for pi, p in enumerate(P):
                rows.append(dict(surface=case, freq_mhz=f, d_km=d, time_pct=p, free_space_db=R.E1.fsl[fi, di],
                                 itm_db=c.itm[fi, di, pi], p452_db=c.p452[fi, di, pi], p2001_db=c.p2001[fi, di, pi],
                                 p452_mech=c.p452_mech[fi, di, pi], p2001_mech=c.p2001_mech[fi, di, pi]))
pd.DataFrame(rows).to_csv(OUT / "deep_smooth_earth_time.csv", index=False)

pc = [1, 10, 50, 90, 99]
rows = [dict(case="climate", climate=cl + 1, n0=320, **{f"itm_{p}_db": R.E9.climate[cl, k] for k, p in enumerate(pc)}) for cl in range(7)]
rows += [dict(case="n0", climate=6, n0=n, **{f"itm_{p}_db": R.E9.n0[j, k] for k, p in enumerate(pc)}) for j, n in enumerate(np.atleast_1d(R.E9.N0s))]
pd.DataFrame(rows).to_csv(OUT / "deep_itm_climate.csv", index=False)
rows = []
for fi, f in enumerate(F):
    for k in range(np.atleast_2d(R.E2.v).shape[1]):
        g = lambda x: np.atleast_2d(x)[fi, k]
        rows.append(dict(freq_mhz=f, h_m=np.atleast_1d(R.E2.H_m)[k], v=g(R.E2.v), J_db=g(R.E2.J),
                         itm_db=g(R.E2.itm), p452_db=g(R.E2.p452), p2001_db=g(R.E2.p2001)))
pd.DataFrame(rows).to_csv(OUT / "deep_knife_edge.csv", index=False)

rows = []
for a, name in enumerate(names[:3]):
    for j, f in enumerate(np.atleast_1d(R.E6.freqs)):
        rows.append(dict(path=name, freq_mhz=f, itm_db=R.E6.f_itm[a, j], p452_db=R.E6.f_p452[a, j], p2001_db=R.E6.f_p2001[a, j]))
pd.DataFrame(rows).to_csv(OUT / "deep_freq_sweep.csv", index=False)
links = pd.read_csv(OUT / "real_terrain_links.csv")
rows = []
for fi, f in enumerate(F):
    for k in range(E7.itm.shape[1]):
        code = E7.itm_mech[fi, k]
        c = "Diffraction" if code in (4, 5, 8, 9) else ("Troposcatter" if code in (6, 10) else "Line of sight")
        L = links.length_km.iloc[k]
        rows.append(dict(link=k + 1, freq_mhz=f, itm_mode_code=code, itm_class=c,
                         free_space_db=32.45 + 20 * np.log10(f) + 20 * np.log10(L),
                         itm_50_db=E7.itm[fi, k, i50], p452_50_db=E7.p452[fi, k, i50], p2001_50_db=E7.p2001[fi, k, i50]))
pd.DataFrame(rows).to_csv(OUT / "real_terrain_by_link.csv", index=False)
rows = []
for fi, f in enumerate(F):
    for pi, p in enumerate(P):
        rows.append(dict(freq_mhz=f, time_pct=p, p2001_minus_itm_median_db=np.median(E7.p2001[fi, :, pi] - E7.itm[fi, :, pi]),
                         p452_minus_itm_median_db=np.median(E7.p452[fi, :, pi] - E7.itm[fi, :, pi])))
pd.DataFrame(rows).to_csv(OUT / "real_terrain_gap_by_time.csv", index=False)
E3 = R.E3; rn = ["30 m", "90 m", "1 km smoothed"]
rows = [dict(link=int(l), resolution=rn[v], freq_mhz=F[0], itm_50_db=E3.itm[j, v], p452_50_db=E3.p452[j, v],
             p2001_50_db=E3.p2001[j, v], delta_h_m=E3.dh[j, v]) for j, l in enumerate(np.atleast_1d(E3.links)) for v in range(3)]
pd.DataFrame(rows).to_csv(OUT / "terrain_resolution_by_link.csv", index=False)
print("wrote deep-dive CSV files")
