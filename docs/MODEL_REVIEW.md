DRAFT//PRE-DECISIONAL

# Model review: matlab_itm against NTIA ITM v1.4

This review checks that the MATLAB port of the Irregular Terrain Model
(ITM) computes what the NTIA C++ reference computes, and that the inputs and
wrappers around the core don't change the answer. It covers rung 1 of the
review plan: the model itself, not its fitness for a particular study.

- **Reference:** [NTIA/itm](https://github.com/NTIA/itm) commit `183ad95`
  (2024-09-24, still the head of the repository on 2026-11-10). The `v1.4`
  tag (`668e4ab`) differs from it only by a const-correctness refactor, and
  the two builds give byte-identical output on the 740 randomized cases.
- **Port reviewed:** `main` at `d2dd90d`, then the `model-review` branch with
  the fixes listed here.
- **Review date:** November 10, 2026.

## Summary

The port reproduces the C++ arithmetic function for function, and after the
fixes in this review it agrees with the C++ on every case tried: 120,000
fuzzed cases (loss within 1.2 × 10⁻¹³ relative; the mode label differs only
at two exact ties), the 855 C++ reference cases in the test suite, and every
C++ error return.

The review found one serious defect, now fixed. When ITM's smooth-earth
diffraction term leaves its domain, the C++ gets NaN and quietly sets the
reference attenuation to 0. The MATLAB port got a complex number instead and
either stopped with an error or returned a loss that was wrong by a median of
231 dB. This happens on real inputs: vertical polarization over sea or fresh
water below about 530 MHz, on about 1.4 % of the sea paths sampled. Because
the port now matches the C++ on those paths, it inherits an upstream
weakness: the loss there is free space plus variability, which is optimistic
by a median of about 20 dB. The port now flags these results.

## Findings

Ranked by severity. "Fixed" means fixed on the `model-review` branch, with a
test.

| # | Severity | Finding | Status |
| --- | --- | --- | --- |
| 1 | High | Out-of-domain smooth-earth term: the port errored or returned a wrong loss where the C++ returns a finite one | Fixed (`9fb7261`) |
| 2 | Medium | Upstream C++ behavior on those paths: the reference attenuation is silently set to 0 | Flagged (`0200c5a`); report to NTIA recommended |
| 3 | Low | ITM accepts physically impossible terrain and returns thousands of dB with warnings only | Open; recommendation below |
| 4 | Low | C++ reference values depend on the compiler (fused multiply-add) by up to 0.013 dB | Documented; reference values stay x86 |
| 5 | Low | Propagation-mode label can differ at an exact d = d_sML tie (2 of 120,000 cases); the loss is identical | No action |
| 6 | Info | Ground constants, polarization, `mdvar`, and confidence defaults come from the WInnForum CBRS reference, not NTIA guidance | Documented in the README |
| 7 | Info | `terrain_source="auto"` can mix 3DEP (NAVD88, bare earth) and Copernicus (EGM2008, surface model) on one profile near the U.S. border | Documented in the README |
| 8 | Info | Windows cache paths (`C:\propagation_cache`) are untested; no Windows machine was available | Open |
| 9 | Info | No continuous integration; tests run by hand on one Mac | Recommendation below |

### 1. Out-of-domain smooth-earth term (high, fixed)

**What happens.** In Vogler's smooth-earth diffraction, `B_0 = 1.607 - K`.
When K exceeds 1.607 (small ground impedance |Z_g|, which vertical
polarization over very conductive ground gives at low frequency, or a short
terminal horizon), `B_0` and the normalized distance go negative. The C++
then evaluates `log10` of a negative number and gets NaN. The NaN flows
through the diffraction line into the reference attenuation, and the final
`MAX(A_ref, 0.0)` macro (`NaN > 0` is false) turns it into 0. MATLAB's
`log10` and fractional powers of a negative number return complex values
instead, so the port either stopped in `complex()` or carried a complex
value to a different finite answer.

**Impact on `main` (`d2dd90d`).** Against the C++ on 120,000 fuzzed cases:
535 cases raised `MATLAB:complex:realPartInputNonNumericOrNonReal`, and 1,348
returned a loss that differed by a median of 231 dB (maximum 8,890 dB). All
1,883 were cases where the C++ sets the reference attenuation from NaN to 0.
On a realistic sample of 40,000 paths with standard ground constants, the
condition occurred only with vertical polarization over sea water (57 of
4,023 paths, 20 MHz to 532 MHz) and fresh water (3 of 4,039, 30 MHz to
77 MHz). It never occurred over land grounds or with horizontal
polarization.

**Fix.** The core now uses `c_sqrt`, `c_log10`, and `c_pow`, which return NaN
for a negative argument as C does, and `c_max` and `c_min`, which are the C
ternary macros (they keep a NaN in the second argument, where MATLAB's `max`
drops it), on every line where a NaN can reach. The fuzz comparison runs in
the same time as before.

**Tests.** `matches_cpp_branch_cases` includes five such cases, and the
deployable self-test runs them in the compiled app.

### 2. Upstream behavior on those paths (medium, flagged)

With the fix, the port returns the C++ answer: free-space loss plus
variability, with no diffraction or two-ray term. On the 60 realistic paths
above, the same path with horizontal polarization, where the term stays
defined, has a median of 19.7 dB more loss (2.1 dB to 200 dB). Over sea the
two polarizations normally differ by a few dB, so the vertical-polarization
result is optimistic by tens of dB.

The port keeps the C++ value, as a faithful port should, and now says so:
`info.A_ref_undefined` is true, `info.warning_messages` names the condition,
and unless `validity="off"` the call raises `itm:validity:Caution`.
`info.warnings` stays equal to the C++ bitmask; the new flag (0x10000) sits
above every NTIA bit.

**Recommendation.** Report the behavior to NTIA/ITS as an issue on
[NTIA/itm](https://github.com/NTIA/itm), with one of the branch cases as a
reproducer. For studies with vertically polarized maritime links below
about 550 MHz (marine VHF at 156 MHz is in range), check
`info.A_ref_undefined` and treat flagged links separately.

### 3. Physically impossible terrain (low, open)

ITM does no checks on terrain heights. The troposcatter asymmetry clamp
(`TroposcatterLoss.cpp` line 88) is reachable only when one terminal's
horizon is more than about 900 km away, which takes terrain higher than
11 km. On such profiles the C++ and the port both return losses of up to
32,000 dB (median about 750 dB in the fuzz cases), with only warning flags. A related case: the C++ reads past
the end of the array when `pfl(1)` doesn't match the number of heights; the
port already rejects that profile (`itm:InvalidProfile`).

**Recommendation.** Consider adding terrain heights outside -500 m to 9,000 m
to the `itm:validity:Caution` conditions. It wouldn't change any result.

### 4. Compiler dependence of the C++ reference (low, documented)

Built with g++ on Apple silicon (aarch64), the C++ fuses multiply-adds and
differs from the x86 build in the last bits. ITM has discontinuities (mode
boundaries, `fix` and `floor` on distances), so in rare cases the difference
grows: up to 0.013 dB, and a different mode in three cases, over 120,000
cases. The
port agrees with the x86 build on all of those. The reference values in
`tests/reference` come from x86 builds; regenerate them on x86, or with
`-ffp-contract=off`.

### 5. Mode label at an exact tie (low, no action)

In two of 120,000 cases, the path length equals the smooth-earth horizon
distance to the last bit, and the port and the C++ round to different sides,
so one reports line of sight and the other diffraction. The loss agrees to
10⁻¹⁴ dB because the two formulas meet at that distance.

### 6 to 9. Documentation and process

- **Defaults (6).** `epsilon` 25, `sigma` 0.02 S/m, vertical polarization,
  `mdvar` 13, and confidence 50 % match `wf_itm.py` in the WInnForum CBRS
  reference model exactly, as the README says. The NTIA C++ takes all of
  them as required inputs, with no defaults. The WInnForum model runs ITM 1.2.2, so its
  inputs, not its outputs, are what this port matches.
- **Terrain sources (7).** See [Inputs around the core](#inputs-around-the-core).
- **Windows (8).** The `C:\propagation_cache` root, its `%LOCALAPPDATA%`
  fallback, and the reads from earlier folders have no test on Windows.
- **Continuous integration (9).** See [Recommendations](#recommendations).

## What was checked

### Line-by-line comparison

Every C++ function maps to one MATLAB function with the same arithmetic in
the same order: `ITM_P2P_TLS_Ex`, `ValidateInputs`, `InitializePointToPoint`,
`QuickPfl`, `FindHorizons`, `ComputeDeltaH`, `LinearLeastSquaresFit`,
`LongleyRice`, `DiffractionLoss`, `KnifeEdgeDiffraction`, `FresnelIntegral`,
`SmoothEarthDiffraction`, `HeightFunction`, `LineOfSightLoss`,
`TroposcatterLoss`, `FFunction`, `H0Function` and `H0Curve`,
`TerrainRoughness`, `SigmaHFunction`, `FreeSpaceLoss`, `Variability`,
`Curve`, and `InverseComplementaryCumulativeDistributionFunction`. The
constants and warning bits match. Three restructurings were checked for
exact equivalence:

- `find_horizons` is vectorized. `cumsum` keeps the C++'s sequential
  addition of the point spacing, and `max` returns the first maximum, which
  matches the strict `>` in the C++ loop.
- In `compute_delta_h`, one subtraction replaces the inner `while` loop and
  gives the same index and remainder; the `float` cast is kept.
- `linear_least_squares_fit` uses `cumsum` in the C++ summation order.

The port adds behavior without changing the arithmetic: it rejects
malformed profiles, requires integer `climate` and `mdvar`, raises
`itm:NonFiniteLoss` for a non-finite result, returns the ITM 1.2.2 mode
code, elevation angles, and the line diagnostics, vectorizes over
reliability and confidence, and exposes location variability.

**Independent check.** A separate agent, which didn't see these notes,
repeated the comparison blind for five function pairs: `Variability`,
`TroposcatterLoss` with `H0Function` and `FFunction`,
`SmoothEarthDiffraction` with `HeightFunction`, `QuickPfl` with
`FindHorizons`, and `ComputeDeltaH` with `LinearLeastSquaresFit`. It found
all five equivalent, with no logic, index, truncation, or NaN-handling
difference. It also tested the `compute_delta_h` rewrite against the C++
loop in C over 448 million steps (np up to 3,000, spacing 0.1 m to
5,000 m) with no mismatch. The risk it couldn't rule out from reading,
last-bit differences between MATLAB's math library and glibc near a branch
threshold, is what the fuzz comparison measures.

### Branch coverage

`gcov` on the C++ build showed which source branches the 740 randomized
cases reach. Because the MATLAB branches mirror the C++ ones, the same list
applies to the port. Eleven branches were never taken. An instrumented C++
build that records each of them was fuzzed with 120,000 cases (flat,
random-walk, pitted, towered, bowl, dome, ramp, sine, and extreme profiles,
30 m to 3,000 km, across the full input ranges):

| C++ branch | Result |
| --- | --- |
| `ComputeDeltaH`: fewer than two points (delta_h = 0) | Reached |
| `QuickPfl`: line-of-sight horizon rescale | Reached |
| `LongleyRice`: paths over 1000 km and 2000 km | Reached |
| `LongleyRice`: zero line-of-sight slopes `kHat_1`, `kHat_2` | Reached |
| `HeightFunction`: K < 1e-5, and x <= 1 km in that branch | Reached |
| `TroposcatterLoss`: asymmetry s < 0.1 | Reached only with terrain above 11 km (finding 3) |
| `ComputeDeltaH`: inner loop ends on the profile length | Unreachable: the interval ends at least min(7.5 m, 0.1 spacing) before the receiver |
| `LinearLeastSquaresFit`: `i_end <= i_start` fallback | Unreachable: every caller passes a start strictly before the end |
| Error 1016, effective earth radius | Unreachable: N_s of 150 to 400 N-units gives 7,140 km to 11,260 km, inside the check |

Error returns 1000, 1001, 1013 (`epsilon` = 1 with horizontal polarization),
1021, and 1022 (terrain below sea level with N_0 near 400) were all reached.
The 41 cases kept, with expected values from the unmodified v1.4 build, are
in `tests/reference/branch_*`; finding 1 surfaced the first time the port
ran them.

On the MATLAB side, `test_itm_p2p_rev1` executes 549 of 566 statements
(97.0 %) in `itm_p2p_core.m` and every statement in `itm_percentiles.m`
(MATLAB statement coverage; decision coverage needs MATLAB Test). The 17
statements left are the two unreachable branches above, dead `itm_error`
cases for percentage errors that `itm_percentiles` raises itself, the
`itm:NonFiniteLoss` guard, and three profile checks, which now have tests.

### Fuzz comparison

The 120,000 fuzzed cases were run through the port and compared with the
x86 C++ build: loss, mode, warning flags, and all 11 intermediate values.

| Code | Match | C++ error raised as the matching MATLAB error | Mismatch | MATLAB error |
| --- | --- | --- | --- | --- |
| `main` (`d2dd90d`) | 116,588 | 1,529 | 1,348 | 535 |
| `model-review` | 118,469 | 1,529 | 2 (finding 5) | 0 |

The largest relative loss difference on `model-review` is 1.2 × 10⁻¹³.

### Edge of the domain

74 cases at the exact limits, in `tests/reference/edge_*`: terminal heights
of 0.5 m, 1 m, 1000 m, and 3000 m and just outside 0.5 m and 3000 m;
frequencies of 20, 40, 10000, and 20000 MHz and just outside 20 and
20000 MHz; N_0 of 250 and 400 and just outside; time, location, and situation
of 0.01 % and 99.99 %; all 7 climates and all 16 `mdvar` values; `epsilon`
= 1; `sigma` of 1e-12 and 1e4 S/m; a 10 m path, a 1 km path, a 2100 km sea
path, two equal peaks that tie for the horizon, np = 1, and an obstacle one
point from the receiver. All match the C++, including the warning flags and
which inputs are errors.

One behavior to know when reading results: ITM classifies a path as line of
sight when it is shorter than the smooth-earth horizon distance computed
from the effective heights. On very rough terrain, a path blocked by hills
can still be "line of sight" to ITM; warning bits 0x0080 and 0x0100 (horizon
angle over 200 mrad) mark these.

### Inputs around the core

- **ITU maps.** `data/TropoClim.txt` (ITU-R P.617-3) and `data/N050.TXT`
  (ITU-R P.452-16) are byte-identical to the files in the ITU downloads
  (SHA-256 checked on 2026-11-10).
- **Map lookups.** The radio-climate lookup (nearest 0.5° grid point, sea
  read as 7) and the N_0 lookup (bilinear on the 1.5° grid) are the
  WInnForum `tropoclim.py` and `refractivity.py` formulas. They also clamp
  at 90° S and wrap at 180°, where the Python indexes out of range. The
  path rules, the climate and N_0 at the geodesic midpoint and the lower
  terminal climate when the midpoint is over sea, are those of `wf_itm.py`.
- **Terrain interpolation.** On 36,000 random points in 18 cached tiles,
  the fast interpolation matches an independent `geointerp` call to 0 m on
  3DEP and GLO-90 and within 3 × 10⁻⁵ m on GLO-30.
- **Tile seams.** Walking across six seams between adjacent cached 3DEP
  tiles at about 1 m steps, the step at the seam is no larger than the steps
  on either side (at most 0.09 m, against medians of up to 0.20 m).
- **Coastlines.** None of the 141 cached 3DEP tiles has a no-data cell;
  3DEP stores open water as 0 m, so coastal paths read sea level without the
  fallback. The fallback (a no-data point takes the next source, then 0 m)
  matters mainly outside 3DEP coverage.
- **Datums and surface models.** In `auto` mode, a profile near the U.S.
  border can mix 3DEP (NAVD88, bare earth) with Copernicus (EGM2008, a
  surface model that includes buildings and trees). The datums differ by
  about 1 m or less; the surface model can add tens of meters in cities and
  forests. The README states both.
- **Profile spacing.** Points are equally spaced along the WGS84 geodesic at
  no more than `spacing_m` (30 m), one geodesic call per path so that a
  link's profile doesn't depend on its batch.

### Wrappers and deployment

The full suite ran on MATLAB R2025b on Apple silicon, each test file in its
own MATLAB process, with a two-worker pool for the parallel tests:

| Test file | Passed | Covers |
| --- | --- | --- |
| `test_itm_p2p_rev1` | 14 of 14 | The core against NTIA and C++ references |
| `test_itm_geo_rev1` | 21 of 21 | Maps, terrain, wrapper vs core, N links vs one, the command-line tool vs `itm_pathloss_rev1`, two workers downloading into one folder |
| `test_limits_rev1` | 14 of 14 | Validity errors and warnings, polar paths |
| `test_mechanism_rev1` | 5 of 5 | The SEADLib drop-in |
| `test_robustness_rev1` | 7 of 7 | `parfor` vs serial, shared caches, antimeridian, tile edges, batch independence |
| `test_app_rev1` | 3 of 3 | The deployable self-test and app |
| `test_deploy_rev1` | 1 of 1 | Compiles the app and runs `--selftest` |

Two additions came from this review. A new test checks that the
command-line tool, given text arguments as a compiled app passes them,
returns exactly what `itm_pathloss_rev1` returns. The deployable self-test
now also runs the 41 branch cases, so the compiled app is checked on the
out-of-domain paths of finding 1; the compiled app passed.

Not covered: the Windows cache paths (finding 8), and the compiled app on
Windows and Linux.

## Recommendations

1. Merge the `model-review` branch (merged with this review).
2. Report finding 2 to NTIA/ITS with a reproducer from
   `tests/reference/branch_cases.csv`.
3. For maritime links with vertical polarization below about 550 MHz, check
   `info.A_ref_undefined` in study outputs.
4. Add implausible terrain heights to `itm:validity:Caution` (finding 3).
5. Set up continuous integration in two parts. A GitHub Actions job without
   MATLAB can rebuild the NTIA C++ on x86 and regenerate
   `tests/reference/*_expected.csv`, failing if any value moves by more than
   10⁻⁹. A second job runs the MATLAB suite: on GitHub-hosted runners with
   `matlab-actions/setup-matlab`, which for a private repository needs a
   MATLAB batch licensing token, or on a self-hosted runner on the Mac that
   already holds the license. Run the `Compile` and network tests nightly
   rather than on every push.
6. Run the suite once on Windows to cover the `C:\propagation_cache` paths.

## Reproducing this review

- Branch cases: `tests/reference/generator/README.md`, section "Branch
  cases" (instrumentation patch, fuzz generators, selection script).
- Edge cases: `tests/reference/generator/gen_edge.py`.
- Fuzz comparison: regenerate the fuzz inputs with `gen_fuzz.py` (seeds 1 to
  4, 25,000 cases each) and `gen_t10.py` (seed 7, 20,000 cases), build
  `ref_driver` on x86, and compare with `itm_p2p_rev1(..., validity="off")`.
