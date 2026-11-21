# Reference case generator

The expected values in `tests/reference/rand_expected.csv` come from the
NTIA/ITS C++ ITM v1.4 ([NTIA/itm](https://github.com/NTIA/itm), commit
`183ad95`), compiled on Linux.

## Continuous check

`check_cpp_reference.sh NTIA_DIR` rebuilds the NTIA C++ from a clone of
NTIA/itm and checks every stored file in `tests/reference`: the generators
must reproduce the stored inputs (`rand_*`, `edge_*`, and the
2,000 randomized area rows) byte for byte or to 1e-14 relative, because numpy's SIMD `exp` and `log` can move the last bit on another processor; the C++ outputs for every stored input
must match the `*_expected.csv` files to 1e-9 relative (`compare_expected.py`). It needs Python with numpy 2.5.3 (the version that wrote `rand_*`).
The GitHub Actions workflow `.github/workflows/cpp-reference.yml` runs it on
x86-64 against the v1.4 tag and the reviewed head (`183ad95`) whenever
`tests/reference` changes, and every Monday against NTIA's latest code as
well (that job is informational and can't fail the run). It needs no MATLAB
license.

## Regenerate

Build on x86-64, or add `-ffp-contract=off`. On aarch64, g++ fuses
multiply-adds by default, which changes the last bits and, in rare cases,
a result by up to 0.013 dB (see `docs/MODEL_REVIEW.md`, finding 4).

1. Clone the NTIA code and make it build outside Windows:

   ```bash
   git clone https://github.com/NTIA/itm ntia_itm
   cd ntia_itm
   sed -i 's#\.\.\\include\\#../include/#g' src/*.cpp
   sed -i 's/#define DLLEXPORT extern "C" __declspec(dllexport)/#define DLLEXPORT extern "C"/' include/itm.h
   ```

1. Build the driver:

   ```bash
   cp path/to/ref_driver.cpp .
   g++ -O2 -o ref_driver ref_driver.cpp src/*.cpp -Iinclude
   ```

1. Generate cases and expected values:

   ```bash
   python3 gen_cases.py pfls.csv   # writes rand_cases.csv and rand_pfls.csv
   ./ref_driver rand_cases.csv rand_pfls.csv > rand_expected.csv
   ```

   Run it from the NTIA clone, which contains `pfls.csv`.

## Files

| File | Contents |
| --- | --- |
| `rand_cases.csv` | Inputs: `h_tx, h_rx, climate, N_0, f, pol, eps, sigma, mdvar, time, location, situation, pfl` (0-based profile index) |
| `rand_pfls.csv` | Profiles in PFL format, one per line. Lines 1–5 are NTIA's `pfls.csv`. |
| `rand_expected.csv` | C++ outputs: return code, warnings, loss, and intermediate values |

The case mix: 155 profiles (5 real, 150 synthetic: flat, sea, rolling, and
ridged, 5 to 2,500 intervals at 10 to 250 m), 3 random parameter sets per
profile across the full valid input range and all 16 `mdvar` values, and 25
reliability sweeps of 11 values each. All three propagation modes appear
(493 line of sight, 84 diffraction, 163 troposcatter).

## Branch cases

`tests/reference/branch_cases.csv`, `branch_pfls.csv`, and
`branch_expected.csv` hold 41 cases that reach the C++ branches the
randomized cases miss. To find them, the C++ was instrumented so that each
target branch sets a bit in a global mask (`branch/instrument.patch`), and
the fuzz driver prints that mask per case (`branch/fuzz_driver.patch`). The
fuzz inputs come from `branch/gen_fuzz.py` (seeds 1 to 4, 25,000 cases
each: flat, random-walk, pitted, towered, bowl, dome, ramp, sine, and
extreme profiles, 30 m to 3,000 km) and `branch/gen_t10.py` (seed 7,
20,000 cases with a high transmitter and one obstacle near the receiver).
`branch/extra.py` adds np = 1 profiles and one case for each C++ error
return the inputs can trigger. `branch/select.py` keeps up to four cases per
target with distinct `mdvar` and mode, smallest profiles first.

The expected values come from the unmodified v1.4 build
(`./ref_driver branch_cases.csv branch_pfls.csv > branch_expected.csv`).
The instrumented build gives the same outputs.

| Bit | C++ branch | Cases |
| --- | --- | --- |
| 0 | `ComputeDeltaH`: fewer than two points between the start and end (delta_h = 0) | 4 + 3 with np = 1 |
| 3 | `QuickPfl`: line-of-sight horizon distances rescaled | 4 |
| 4, 5 | `LongleyRice`: path over 1000 km and over 2000 km (warnings) | 4, 4 |
| 6, 7 | `LongleyRice`: line-of-sight slope `kHat_2` or `kHat_1` is zero | 4, 4 |
| 8, 9 | `HeightFunction`: K < 1e-5, and x <= 1 km inside that branch | 4, 4 |
| 10 | `TroposcatterLoss`: asymmetry s < 0.1 (needs terrain above 11 km) | 1 |
| — | Error returns 1000, 1001, 1013 (`epsilon` = 1, horizontal), 1021, 1022 | 5 |

Three targets aren't reachable from point-to-point mode, so they have no
cases:

- `ComputeDeltaH`, inner loop ending on the profile length: the end of
  the interval sits at least min(7.5 m, 0.1 spacing) before the receiver.
- `LinearLeastSquaresFit`, the `i_end <= i_start` fallback: every caller
  passes a start strictly before the end.
- Error 1016 (effective earth radius): N_s from 150 to 400 N-units gives
  7,140 km to 11,260 km, which is inside the 4,000 km to 13,333 km check.

## Edge cases

`tests/reference/edge_cases.csv`, `edge_pfls.csv`, and `edge_expected.csv`
hold 74 cases at the exact input limits, written by `gen_edge.py`: terminal
heights of 0.5 m, 1 m, 1000 m, and 3000 m and just outside 0.5 m and 3000 m;
frequencies of 20, 40, 10000, and 20000 MHz and just outside 20 and 20000
MHz; N_0 of 250 and 400 and just outside; time, location, and situation of
0.01 % and 99.99 %; all 7 climates and all 16 `mdvar` values; `epsilon` = 1
with each polarization; `sigma` of 1e-12 S/m and 1e4 S/m; and six special
profiles (a 10 m path, a 1 km path, a 2100 km sea path, two equal peaks
that tie for the horizon, np = 1, and an obstacle one point from the
receiver), each at three height and frequency settings.

```bash
python3 gen_edge.py
./ref_driver edge_cases.csv edge_pfls.csv > edge_expected.csv
```

## Area mode

`tests/reference/area_cases.csv` and `area_expected.csv` hold 2,143 cases for
`itm_area_rev1`, computed by `area/area_driver.cpp` (NTIA
`ITM_AREA_TLS_Ex`, v1.4). Rows 1 to 2000 are randomized
(`area/gen_area.py 20261121 2000 area`). The next 31 reach rare branches;
`area/select_area.py` takes up to four for each from 200,000 wider cases
(`gen_area.py` seeds 1 to 4, 50,000 each, `wide`), run through an
instrumented build (`area/instrument_area.patch`, which also carries the
point-to-point bits): the `InitializeArea` exponent limit of 20 and Δh below
1e-3, the zero line-of-sight slopes, the height-function x <= 1 km branch,
the troposcatter q clamp at 0.1, the horizon-distance warnings 0x0200 and
0x0400, and diffraction mode. The last 112 are at the input limits, from
`select_area.py`: K < 1e-5 (sigma of 1e3 and 1e4 S/m at 20 MHz, horizontal),
heights of 0.5 m to 3000 m with each siting (including either side of the
5 m siting threshold), Δh around 1e-3 m and up to 10 km, distances of 1 m
to 3000 km, every climate and `mdvar`, tail percentages, and one case for
each C++ error return (1000 to 1002, 1008 to 1014, 1017 to 1020).

Area-mode branches that can't be reached: N_s below 250 or out of range and
the effective-radius error (N_s = N_0, which is checked), horizon distance
over 3 times the smooth-earth distance (area mode never exceeds it), the
troposcatter asymmetry clamp (area-mode horizons stay under about 260 km),
and the troposcatter q clamp at 10 (the frame puts the shorter effective
height over the taller, so q <= 1 before the clamp).

```bash
g++ -O2 -o area_driver area/area_driver.cpp src/*.cpp -Iinclude
python3 area/gen_area.py 20261121 2000 area
python3 area/select_area.py        # needs the wide fuzz outputs; see the script
./area_driver area_all_cases.csv > area_expected.csv
```
