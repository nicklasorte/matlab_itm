"""Extract path data from OT/TRER 16 (Longley, Reasoner, Fuller, 1971).

Reads the text of the report (pdftotext -layout), parses Table 1 (terminal
coordinates) and Table 2 (frequency, distance, antenna heights, observed
basic transmission loss at 1, 10, 50, 90, and 99 percent of time), and
keeps a path only if the great-circle distance between its terminals
agrees with the tabulated distance within 3 percent. That check rejects
rows that the scan's OCR garbled.

    pdftotext -layout sources/OT-TRER-16.pdf trer16.txt
    python3 parse_trer16.py trer16.txt trer16_paths.csv
"""
import csv, math, re, sys

OCR = [("'l", "9"), ("&", "6"), ("<t", "4"), ("ft", "4"), ("lt", "4"), ("~", "4"), ("'+", "4")]

def norm(s):
    for a, b in OCR:
        s = s.replace(a, b)
    s = re.sub(r"(?<=\d)[Oo](?=\d|\s)", "0", s)
    s = re.sub(r"(?<=\s)[Oo](?=\d)", "0", s)
    s = re.sub(r"(?<=\s)[D](?=\d)", "0", s)
    s = re.sub(r"(?<=\d)[D](?=\d|\s)", "0", s)
    s = re.sub(r"(?<=\s)[J](?=\d)", "3", s)
    s = re.sub(r"(?<=\s)l(?=\d)", "1", s)
    s = re.sub(r"(?<=\d)l(?=\d|\s)", "1", s)
    s = re.sub(r"(?<=\s)[g](?=\s|\d|\.)", "9", s)
    s = re.sub(r"(?<=\d)[g](?=\s|\d)", "9", s)
    return s

COORD = re.compile(r"(\d{1,2})\s*(\d{2})\s*(\d{2})\s*([NS])\s+(\d{1,3})\s+(\d{1,2})\s+(\d{1,2})\s*([WwHE])")

def dms(d, m, s):
    return int(d) + int(m) / 60 + int(s) / 3600

def table1(lines):
    out = {}
    for ln in lines:
        m = re.match(r"^\s*(\d{1,4})\s+\S", ln)
        if not m:
            continue
        s = norm(ln)
        c = COORD.findall(s)
        if len(c) < 2:
            continue
        pid = int(re.match(r"^\s*(\d{1,4})", s).group(1))
        (a, b, cc, ns1, d, e, f, ew1), (g, h, i, ns2, j, k, l, ew2) = c[0], c[1]
        lat1 = dms(a, b, cc) * (1 if ns1 == "N" else -1)
        lon1 = -dms(d, e, f) if ew1 in "WwH" else dms(d, e, f)
        lat2 = dms(g, h, i) * (1 if ns2 == "N" else -1)
        lon2 = -dms(j, k, l) if ew2 in "WwH" else dms(j, k, l)
        names = re.split(r"\s{2,}", ln.strip())
        out[pid] = dict(tx_name=names[1] if len(names) > 1 else "", tx_lat=lat1, tx_lon=lon1,
                        rx_lat=lat2, rx_lon=lon2, line=ln.strip())
    return out

NUM = re.compile(r"-?\d+\.\d+|-?\d+")

def table2(lines):
    out = {}
    for ln in lines:
        m = re.match(r"^\s*(\d{1,4})\s*[•·.,*]", ln)
        if not m:
            continue
        s = norm(ln[m.end():])
        s = re.sub(r"(\d)\.\s+(\d)", r"\1.\2", s)
        s = re.sub(r"(\d)\s+\.(\d)", r"\1.\2", s)
        s = s.replace(",", ".")
        v = [float(x) for x in NUM.findall(s)]
        # F D DH NS HTG HRG H HLT DLT HLR DLR THETA LB1 LB10 LB50 LB90 LB99 TN101 ESSA70
        if len(v) != 19:
            continue
        out[int(m.group(1))] = dict(f_mhz=v[0], d_km=v[1], dh_m=v[2], ns=v[3], htg_m=v[4], hrg_m=v[5],
                                    horizons=v[6], theta_mrad=v[11], lb01=v[12], lb10=v[13], lb50=v[14],
                                    lb90=v[15], lb99=v[16], tn101_lbcr=v[17], essa70_lbcr=v[18])
    return out

def gc_km(a, b, c, d):
    p1, p2, dl = map(math.radians, (a, c, d - b))
    return 6371.0 * math.acos(min(1, math.sin(p1) * math.sin(p2) + math.cos(p1) * math.cos(p2) * math.cos(dl)))

def main(txt, out_csv):
    lines = open(txt, encoding="utf8", errors="replace").read().splitlines()
    i1 = next(i for i, l in enumerate(lines) if "PROPAGATION PATH LOCATIONS AND PERIODS" in l and "TABLE" in l)
    i2 = next(i for i, l in enumerate(lines) if "PATH PA" in l and "BASIC TRANSMISSION LOSS" in l and i > i1)
    t1, t2 = table1(lines[i1:i2]), table2(lines[i2:])
    rows, rejected = [], 0
    for pid, p in sorted(t2.items()):
        if pid not in t1:
            continue
        c = t1[pid]
        d = gc_km(c["tx_lat"], c["tx_lon"], c["rx_lat"], c["rx_lon"])
        ok = abs(d - p["d_km"]) <= 0.03 * p["d_km"]
        if not ok:
            rejected += 1
            continue
        us = 24 <= c["tx_lat"] <= 50 and -125 <= c["tx_lon"] <= -66 and 24 <= c["rx_lat"] <= 50 and -125 <= c["rx_lon"] <= -66
        rows.append(dict(path=pid, **{k: c[k] for k in ("tx_lat", "tx_lon", "rx_lat", "rx_lon")},
                         d_gc_km=round(d, 2), conus=us, **p))
    with open(out_csv, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"Table 1 rows {len(t1)}, Table 2 rows {len(t2)}, matched and distance-checked {len(rows)}, rejected {rejected}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
