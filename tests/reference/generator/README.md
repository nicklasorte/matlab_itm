# Reference case generator

The expected values in `tests/reference/rand_expected.csv` come from the
NTIA/ITS C++ ITM v1.4 ([NTIA/itm](https://github.com/NTIA/itm), commit
`183ad95`), compiled on Linux.

## Regenerate

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
