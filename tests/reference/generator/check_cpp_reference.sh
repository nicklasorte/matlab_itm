#!/usr/bin/env bash
# Rebuild the NTIA C++ ITM and check every stored reference file against it.
#
# Usage: tests/reference/generator/check_cpp_reference.sh NTIA_DIR [WORK_DIR]
#   NTIA_DIR  a clone of https://github.com/NTIA/itm at the commit to test
#   WORK_DIR  scratch folder (default: a new temporary folder)
#
# Checks, in order:
#   1. The case generators reproduce the stored inputs, byte for byte or to
#      1e-14 relative (compare_inputs.py; numpy's SIMD exp and log differ in
#      the last bit between processors):
#      rand_* (gen_cases.py), edge_* (gen_edge.py), and the 2,000 randomized
#      rows at the top of area_cases.csv (area/gen_area.py). The branch cases
#      and the other area rows come from fuzzing and aren't regenerated.
#   2. The C++ outputs for every stored input match the stored
#      *_expected.csv files (compare_expected.py, 1e-9 relative).
# Build on x86-64: on aarch64, g++ fuses multiply-adds and the last bits move
# (docs/MODEL_REVIEW.md, finding 4). Exits nonzero on the first failure.
set -euo pipefail

NTIA=$(cd "$1" && pwd)
WORK=${2:-$(mktemp -d)}
GEN=$(cd "$(dirname "$0")" && pwd)
REF=$(cd "$GEN/.." && pwd)
mkdir -p "$WORK"
echo "NTIA commit: $(git -C "$NTIA" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "Machine: $(uname -m), $(g++ --version | head -1)"

# Build: copy the NTIA sources, fix the Windows include paths and the DLL
# export, and compile both drivers.
rm -rf "$WORK/build" && mkdir -p "$WORK/build"
cp -r "$NTIA/src" "$NTIA/include" "$WORK/build/"
cd "$WORK/build"
sed -i 's#\.\.\\include\\#../include/#g' src/*.cpp
sed -i 's/#define DLLEXPORT extern "C" __declspec(dllexport)/#define DLLEXPORT extern "C"/' include/itm.h
cp "$GEN/ref_driver.cpp" "$GEN/area/area_driver.cpp" .
g++ -O2 -o ref_driver ref_driver.cpp src/*.cpp -Iinclude
g++ -O2 -o area_driver area_driver.cpp src/*.cpp -Iinclude

# 1. Inputs
cd "$WORK"
python3 "$GEN/gen_cases.py" "$NTIA/pfls.csv" > /dev/null
python3 "$GEN/gen_edge.py" > /dev/null
python3 "$GEN/area/gen_area.py" 20261121 2000 area_gen
fail=0
for f in rand_cases.csv rand_pfls.csv edge_cases.csv edge_pfls.csv; do
    python3 "$GEN/compare_inputs.py" "$f" "$REF/$f" || fail=1
done
python3 "$GEN/compare_inputs.py" area_gen_cases.csv "$REF/area_cases.csv" 2000 || fail=1

# 2. Outputs
for s in rand branch edge; do
    "$WORK/build/ref_driver" "$REF/${s}_cases.csv" "$REF/${s}_pfls.csv" > "${s}_expected.csv"
    python3 "$GEN/compare_expected.py" "${s}_expected.csv" "$REF/${s}_expected.csv" || fail=1
done
"$WORK/build/area_driver" "$REF/area_cases.csv" > area_expected.csv
python3 "$GEN/compare_expected.py" area_expected.csv "$REF/area_expected.csv" || fail=1

if [ "$fail" -ne 0 ]; then echo "C++ reference check FAILED"; exit 1; fi
echo "C++ reference check passed"
