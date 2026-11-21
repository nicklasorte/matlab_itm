# Randomized ITM area-mode cases (tests/reference/area_*). Deterministic.
# Usage: python3 gen_area.py SEED N OUT_PREFIX [wide]
# "wide" also draws delta_h up to 16 km, extreme height pairs, and epsilon = 1,
# to reach rare branches (see generator/README.md).
import sys, random, math
seed, N, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
wide = len(sys.argv) > 4 and sys.argv[4] == "wide"
R = random.Random(seed)
H = "h_tx,h_rx,tx_siting,rx_siting,d_km,delta_h,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation"
def pct():
    r = R.random()
    if r < 0.1: return R.choice([0.01, 0.1, 99.9, 99.99])
    if r < 0.2: return 50.0
    return R.uniform(0.5, 99.5)
rows = []
for k in range(N):
    h1 = 10 ** R.uniform(-0.35, 3.52); h2 = 10 ** R.uniform(-0.35, 3.52)
    if R.random() < 0.15: h1 = R.choice([0.5, 1, 2, 3, 4.9, 5, 10])
    s1 = R.choice([0, 1, 2]); s2 = R.choice([0, 1, 2])
    d = 10 ** R.uniform(-1.5, 3.6)
    dh = R.choice([0.0, 10 ** R.uniform(-3, 3.3), 10 ** R.uniform(-3, 3.3), 30, 90, 200, 500, 700])
    clim = R.randint(1, 7); N0 = R.uniform(250, 400); pol = R.randint(0, 1)
    eps = 10 ** R.uniform(0, 2); sig = 10 ** R.uniform(-5, 2)
    f = 10 ** R.uniform(math.log10(20), math.log10(20000))
    md = R.choice([0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23, 30, 31, 32, 33])
    t, l, s = pct(), pct(), pct()
    if wide:
        r = R.random()
        if r < 0.3: dh = 10 ** R.uniform(3, 4.2)
        elif r < 0.45: dh = R.choice([0.0, 1e-4, 1e-3, 0.002])
        elif r < 0.6: h1, h2 = R.choice([(3000, 0.5), (0.5, 3000), (2500, 0.6), (0.6, 2500)])
        elif r < 0.65: eps, pol = 1.0, 0
    e = R.random()                      # about 3 % invalid, one field each
    if e < 0.005: d = R.choice([0.0, -1.0])
    elif e < 0.010: dh = -R.uniform(0.001, 10)
    elif e < 0.015: s1 = R.choice([-1, 3])
    elif e < 0.020: s2 = R.choice([-1, 3])
    elif e < 0.025: N0 = R.choice([249.0, 401.0])
    elif e < 0.030: f = R.choice([19.0, 20001.0])
    rows.append([h1, h2, s1, s2, d, dh, clim, N0, f, pol, eps, sig, md, t, l, s])
with open(out + "_cases.csv", "w") as fc:
    fc.write(H + "\n" + "\n".join(",".join("%.17g" % v for v in r) for r in rows) + "\n")
