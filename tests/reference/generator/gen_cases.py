"""Generate randomized ITM point-to-point reference cases.

Writes rand_pfls.csv (PFL-format profiles) and rand_cases.csv (inputs).
Profiles 0-4 are NTIA's real profiles from pfls.csv; the rest are synthetic.
"""
import sys
import numpy as np

rng = np.random.default_rng(20261107)

ntia_pfls = sys.argv[1] if len(sys.argv) > 1 else 'pfls.csv'   # NTIA's pfls.csv
ntia = [l.strip() for l in open(ntia_pfls) if len(l.strip()) > 2]
profiles = list(ntia)

def synth_profile():
    kind = rng.integers(0, 4)
    np_ = int(rng.choice([rng.integers(5, 60), rng.integers(60, 600), rng.integers(600, 2500)]))
    xi = float(rng.uniform(10.0, 250.0))
    x = np.arange(np_ + 1) * xi
    base = float(rng.uniform(0, 2500))
    if kind == 0:                                 # flat or sea
        z = np.full(np_ + 1, base if rng.random() < 0.5 else 0.0)
    else:
        dh = float(rng.choice([rng.uniform(1, 20), rng.uniform(20, 200), rng.uniform(200, 800)]))
        z = np.zeros(np_ + 1)
        for _ in range(6):                        # sum of random sinusoids
            lam = rng.uniform(500, 60e3)
            z += rng.uniform(0, 1) * np.sin(2 * np.pi * x / lam + rng.uniform(0, 2 * np.pi))
        z += 0.05 * np.cumsum(rng.standard_normal(np_ + 1))
        z = (z - z.min()) / max(np.ptp(z), 1e-9) * dh
        if kind == 3:                             # a single ridge
            c = rng.uniform(0.2, 0.8) * x[-1]
            z += rng.uniform(50, 600) * np.exp(-((x - c) / (0.03 * x[-1] + 1)) ** 2)
        z += base
    return ','.join([str(np_), repr(xi)] + ['%.3f' % v for v in z])

for _ in range(150):
    profiles.append(synth_profile())

mdvars = [0, 1, 2, 3, 10, 11, 12, 13, 20, 21, 22, 23, 30, 31, 32, 33]

def pct():
    return float(rng.choice([rng.uniform(0.01, 2), rng.uniform(2, 98), rng.uniform(98, 99.99), 50.0]))

lines = []
def add(p, t=None, s=None):
    h_tx = float(rng.choice([rng.uniform(0.5, 3), rng.uniform(3, 100), rng.uniform(100, 3000)]))
    h_rx = float(rng.choice([rng.uniform(0.5, 3), rng.uniform(3, 100), rng.uniform(100, 3000)]))
    f = float(np.exp(rng.uniform(np.log(20), np.log(20000))))
    row = [h_tx, h_rx, int(rng.integers(1, 8)), float(rng.uniform(250, 400)), f,
           int(rng.integers(0, 2)), float(rng.uniform(1, 80)), float(np.exp(rng.uniform(np.log(1e-4), np.log(5)))),
           int(rng.choice(mdvars)), pct() if t is None else t, pct(), pct() if s is None else s, p]
    lines.append(row)
    return row

for p in range(len(profiles)):                     # 3 random cases per profile
    for _ in range(3):
        add(p)

# Reliability sweeps: same inputs, many time percentages (CR mode: location = 50)
rel = [0.1, 1, 5, 10, 20, 50, 80, 90, 95, 99, 99.9]
sweep_start = len(lines)
for p in rng.choice(len(profiles), 25, replace=False):
    base = add(int(p))
    lines.pop()
    conf = float(rng.choice([10.0, 50.0, 90.0]))
    for r in rel:
        row = list(base)
        row[9], row[10], row[11] = r, 50.0, conf
        lines.append(row)

with open('rand_pfls.csv', 'w') as f:
    f.write('\n'.join(profiles) + '\n')
with open('rand_cases.csv', 'w') as f:
    f.write('h_tx,h_rx,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation,pfl\n')
    for r in lines:
        f.write(','.join(repr(v) if isinstance(v, float) else str(v) for v in r) + '\n')
print(len(profiles), 'profiles', len(lines), 'cases; sweep rows start at', sweep_start)
