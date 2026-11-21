"""Compare a regenerated C++ reference CSV with the stored one.

Usage: python3 compare_expected.py NEW.csv STORED.csv

Integer columns (case, rtn, warnings, mode, hits) must match exactly.
Floating-point columns must agree to 1e-9 relative (1e-9 absolute below
1), the tolerance the MATLAB tests use; NaN matches NaN. Exits 1 on any
difference and prints the first few.
"""
import csv
import math
import sys

INT_COLS = {"case", "rtn", "warnings", "mode", "hits"}


def close(a, b):
    x, y = float(a), float(b)
    if math.isnan(x) or math.isnan(y):
        return math.isnan(x) and math.isnan(y)
    if math.isinf(x) or math.isinf(y):
        return x == y
    return abs(x - y) <= 1e-9 * max(1.0, abs(y))


def main(new_file, stored_file):
    new = list(csv.reader(open(new_file)))
    old = list(csv.reader(open(stored_file)))
    bad = []
    if new[0] != old[0]:
        bad.append(f"header differs: {new[0]} vs {old[0]}")
    if len(new) != len(old):
        bad.append(f"row count differs: {len(new) - 1} vs {len(old) - 1}")
    header = old[0]
    worst = 0.0
    for i, (rn, ro) in enumerate(zip(new[1:], old[1:]), start=1):
        if len(rn) != len(ro):
            bad.append(f"row {i}: {len(rn)} vs {len(ro)} fields")
            continue
        for name, a, b in zip(header, rn, ro):
            if name in INT_COLS:
                ok = a == b
            else:
                ok = close(a, b)
                if ok and not (math.isnan(float(b)) or math.isinf(float(b))):
                    worst = max(worst, abs(float(a) - float(b)) / max(1.0, abs(float(b))))
            if not ok:
                bad.append(f"row {i} ({name}): {a} vs stored {b}")
    name = stored_file.split("/")[-1]
    if bad:
        print(f"FAIL {name}: {len(bad)} differences")
        for line in bad[:10]:
            print("  " + line)
        return 1
    print(f"ok   {name}: {len(old) - 1} rows, largest relative difference {worst:.2g}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
