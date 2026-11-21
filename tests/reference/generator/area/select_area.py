# Builds tests/reference/area_cases.csv: 2000 randomized cases (gen_area.py,
# seed 20261121), then up to four cases per rare branch from the wide fuzz
# (gen_area.py seeds 1-4, 50,000 each, "wide"), then the exact-limit cases.
import csv
H = "h_tx,h_rx,tx_siting,rx_siting,d_km,delta_h,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation"
rows = open("area_cases.csv").read().splitlines()[1:]
n_random = len(rows)
targets = {"hits": {6: "kHat_2 zero", 7: "kHat_1 zero", 9: "x <= 1 km in height function",
                    12: "InitializeArea MIN picks 20", 13: "delta_h below 1e-3",
                    14: "troposcatter q clamped at 0.1", 16: "A_sML <= A_0"},
           "warn": {0x200: "TX horizon < 0.1 smooth-earth", 0x400: "RX horizon < 0.1 smooth-earth"},
           "mode": {2: "diffraction"}}
picked = {}
for s in [1, 2, 3, 4]:
    cases = open(f"w{s}_cases.csv").read().splitlines()[1:]
    for r in csv.DictReader(open(f"w{s}_out.csv")):
        if r["rtn"] not in ("0", "1"):
            continue
        h, w, m = int(r["hits"]), int(r["warnings"]), int(r["mode"])
        keys = [("hits", b) for b in targets["hits"] if h >> b & 1] + \
               [("warn", b) for b in targets["warn"] if w & b] + [("mode", 2)] * (m == 2)
        for key in keys:
            L = picked.setdefault(key, [])
            if len(L) < 4:
                L.append(cases[int(r["case"])])
branch = []
for key in sorted(picked):
    for c in picked[key]:
        if c not in branch:
            branch.append(c)
    print(key, targets[key[0]][key[1]], len(picked[key]))
# exact limits: h_tx,h_rx,txs,rxs,d,dh,clim,N0,f,pol,eps,sig,md,t,l,s
b = [30, 10, 0, 0, 50, 90, 5, 301, 1000, 1, 15, 0.005, 3, 50, 50, 50]
def v(**kw):
    r = list(b)
    for k, x in kw.items():
        r[["h1","h2","ts","rs","d","dh","clim","N0","f","pol","eps","sig","md","t","l","s"].index(k)] = x
    return r
edge = [v(sig=1e3, f=20, pol=0, eps=80), v(sig=1e4, f=20, pol=0, eps=80, d=300),   # K < 1e-5
        v(eps=1, pol=0), v(eps=1, pol=1)]                                           # 1013, and none
for h in [0.5, 1, 4.999, 5, 5.001, 3000]:
    for site in [0, 1, 2]:
        edge.append(v(h1=h, ts=site)); edge.append(v(h2=h, rs=site))
for dh in [0, 1e-4, 0.000999, 1e-3, 0.001001, 1e4]:
    edge.append(v(dh=dh, ts=1, rs=2, h1=0.5, h2=0.5)); edge.append(v(dh=dh, ts=2, rs=1))
for d in [1e-3, 0.0999, 0.1, 1, 2000, 2000.0001, 3000]:
    edge.append(v(d=d))
for n in [250, 400]: edge.append(v(N0=n))
for f in [20, 40, 10000, 20000]: edge.append(v(f=f))
for c in range(1, 8): edge.append(v(clim=c))
for md in [0,1,2,3,10,11,12,13,20,21,22,23,30,31,32,33]: edge.append(v(md=md, t=10, l=90, s=70))
for p in [0.01, 99.99]:
    edge += [v(t=p), v(l=p), v(s=p), v(l=p, md=13)]
edge += [v(d=0), v(d=-1), v(dh=-1e-9), v(ts=3), v(ts=-1), v(rs=3), v(rs=-1),     # 1017-1020
         v(h1=0.49), v(h2=3000.1), v(N0=249), v(f=20001), v(clim=8), v(pol=2), v(eps=0.9), v(sig=0), v(md=4)]
edge = [",".join("%.17g" % x for x in r) for r in edge]
open("area_all_cases.csv", "w").write(H + "\n" + "\n".join(rows + branch + edge) + "\n")
print(n_random, "random,", len(branch), "branch,", len(edge), "edge")
