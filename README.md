# matlab_itm

A MATLAB port of the NTIA/ITS Irregular Terrain Model (ITM, Longley-Rice)
version 1.4, point-to-point mode, with automatic terrain, radio climate, and
refractivity. It runs in MATLAB R2025b and in apps compiled with MATLAB
Compiler for the free MATLAB Runtime.

The core is a line-by-line port of the C++ reference implementation at
[NTIA/itm](https://github.com/NTIA/itm) (commit `183ad95`). It matches that
code to within 4 × 10⁻¹³ dB on 740 test cases, with identical propagation
modes, warning flags, and intermediate values.

## Quick start

```matlab
addpath('matlab_itm')

tx = [38.8895, -77.0353, 30];        % [lat (deg), lon (deg), height above ground (m)]
rx = [39.0458, -76.6413, 10];
reliability = [1 10 50 90 99];       % time percentages

loss_db = itm_pathloss_rev1(tx, rx, 2700, reliability)
% loss_db = 178.61  181.90  184.56  186.89  188.79
```

That's all you need to pass. The function finds the terrain profile, the
radio climate, and the surface refractivity for the path, and evaluates
every reliability from one geometry pass.

Many transmitters to one receiver, in one call:

```matlab
txs = [38.90 -77.03 30; 38.95 -76.90 25; 39.20 -76.70 40];
L = itm_pathloss_rev1(txs, rx, 2700, reliability);    % 3-by-5
```

A reliability-by-confidence table:

```matlab
T = itm_pathloss_rev1(tx, rx, 2700, [10; 50; 90], confidence=[10 50 90]);   % 3-by-3
```

## Functions

| Function | Purpose |
| --- | --- |
| `itm_pathloss_rev1(tx, rx, f_mhz, reliability)` | Path loss between locations, with everything automatic. Accepts N links. |
| `itm_p2p_rev1(h_tx_m, h_rx_m, pfl, f_mhz, reliability)` | ITM core for a terrain profile you supply. Equivalent to NTIA `ITM_P2P_CR` (and `ITM_P2P_TLS` with the `location` option). |
| `itm_terrain_profile_rev1(lat1, lon1, lat2, lon2)` | ITM PFL profile(s) along the WGS84 geodesic. |
| `itm_terrain_elevation_rev1(lat, lon)` | Terrain elevation at points, from cached DEM tiles. |
| `itm_radio_climate_rev1(lat, lon)` | ITU-R P.617 radio climate code (1–7). |
| `itm_surface_refractivity_rev1(lat, lon)` | ITU-R P.452 sea-level refractivity N₀. |
| `itm_setup_rev1(region=[lat_min lat_max lon_min lon_max])` | Cache the ITU maps and the terrain tiles for an area (offline servers, shared caches). |
| `itm_app_rev1()` | Self-test app: a **Run self-test** button, a PASSED/FAILED status box, and a table of checks. `itm_app_rev1("--selftest")` runs headless. |
| `itm_selftest_rev1()` | The self-test the app runs. Deployable (no `matlab.unittest`). |
| `itm_cli_rev1(...)` | Command-line path-loss tool for a compiled app. |
| `build_itm_app_rev1()` | Compiles the app (or the CLI) with MATLAB Compiler, with every data file it needs. |

Every function documents its inputs and name-value options; run
`help itm_pathloss_rev1`.

## How a call flows

```mermaid
flowchart LR
    A["tx, rx<br/>[lat lon h]"] --> B["WGS84 geodesic<br/>distance, track2, reckon"]
    B --> C["Profile points<br/>every 30 m"]
    B --> D["Path midpoint"]
    C --> E{"Tile in local cache?"}
    E -- no --> F["Download once<br/>3DEP, then GLO-30, then GLO-90"]
    F --> G["~/.matlab_itm/terrain"]
    M["ITU maps<br/>data/ or cache or itu.int"] --> I
    M --> J
    E -- yes --> G
    G --> H["readgeoraster + geointerp<br/>bilinear elevation"]
    D --> I["ITU-R P.617 TropoClim<br/>radio climate"]
    D --> J["ITU-R P.452 N050<br/>refractivity N0"]
    H --> K["ITM v1.4 core<br/>itm_p2p_rev1"]
    I --> K
    J --> K
    K --> L["Loss for every<br/>reliability"]
```

## Terrain data

The terrain source has to work in a compiled app, without a MATLAB license
or an account. All sources here are public, keyless, and served as plain
GeoTIFF files over HTTPS, so the app needs only `websave` and
`readgeoraster`, which MATLAB Compiler supports.

| Source | Coverage | Resolution | Surface | Vertical datum | Tile size |
| --- | --- | --- | --- | --- | --- |
| [USGS 3DEP 1 arc-second](https://www.usgs.gov/3d-elevation-program) (default) | U.S. (CONUS, Alaska, Hawaii), Puerto Rico, U.S. Virgin Islands, Guam, border areas of Canada and Mexico | ~30 m | Bare earth | NAVD88 | ~45 MB per 1° × 1° |
| [Copernicus GLO-30](https://registry.opendata.aws/copernicus-dem/) (fallback) | Global | ~30 m | Surface model (includes buildings and canopy) | EGM2008 | ~35 MB per 1° × 1° |
| [Copernicus GLO-90](https://registry.opendata.aws/copernicus-dem/) (second fallback) | Global, including tiles not released in GLO-30 | ~90 m | Surface model | EGM2008 | ~5 MB per 1° × 1° |
| USGS 3DEP 1/3 arc-second (`terrain_source="usgs3dep13"`, opt-in) | CONUS, Hawaii, territories | ~10 m | Bare earth | NAVD88 | ~370 MB per 1° × 1° |

With `terrain_source="auto"` (the default), each point comes from 3DEP.
Points where 3DEP has no tile or no data (outside the U.S., past a border,
offshore) are filled from GLO-30, then GLO-90. Points with no data in any
source are set to 0 m when they're water: no-data cells inside a tile
(coasts), or sea on the ITU-R P.617 map. A land point that no chosen source
covers raises `itm:terrain:NoCoverage`, so forcing `terrain_source="usgs3dep"`
outside the U.S. fails loudly instead of reading land as sea level.
`info.profile.source_code` records the source of every point.

For 10 m terrain, pass `terrain_source="usgs3dep13", spacing_m=10`. Its
tiles are large, so it's never part of `"auto"`.

Tiles download the first time a path needs them and are reused afterward:

- **Cache folder.** `<cache>/terrain`, where `<cache>` is the
  `MATLAB_ITM_CACHE` environment variable, else `%LOCALAPPDATA%\matlab_itm`
  on Windows, else `~/.matlab_itm`. `MATLAB_ITM_TERRAIN_DIR` or the
  `terrain_dir` option overrides the terrain folder alone.
- **Shared with itu_p2001.** Both tools use the providers' file names, so
  a tile already in the itu_p2001 cache (`ITU_P2001_CACHE`, else
  `~/.itu_p2001/dem/...`) is read in place, not downloaded again. Set
  `MATLAB_ITM_SHARE_P2001_CACHE=0` to turn this off.
- **Decoded tiles on disk.** Decoding a GeoTIFF takes about 170 ms. The
  decoded grid is saved beside it (`.zcache`, about 52 MB per tile), so a new
  MATLAB or app process loads a tile in about 10 ms.
- **Memory.** Decoded tiles stay in memory up to 2 GB (about 38 one-arc-second
  tiles); set `MATLAB_ITM_TILE_CACHE_GB` to change it. The least recently
  used tile is dropped first.
- **Offline servers.** Run `itm_setup_rev1(region=[...])` on a connected
  machine, copy the cache folder, set `MATLAB_ITM_CACHE` to it, and call
  with `download=false`. A missing tile then raises
  `itm:terrain:TileMissing` rather than failing silently.
- **Shared folders.** Downloads go to a temporary file and are renamed into
  place atomically (first writer wins), so several compiled servers can
  share one cache. The test suite checks this with two parallel workers.
- **Ocean tiles.** Copernicus publishes a `tileList.txt` of every tile; it's
  cached once, and a tile absent from it counts as ocean without a request.
  So a network or proxy error is never mistaken for open water. A 3DEP tile
  that returns HTTP 404 is remembered with a zero-byte `.404` marker.

Rough download sizes: a 100 km radius around one site is about 9 tiles
(400 MB); all of CONUS 3DEP is about 1,000 tiles (45 GB).

## Climate and refractivity

Yes, both are automatic: every call looks them up from the path's latitude
and longitude.

![How climate and refractivity are chosen](docs/climate_refractivity_us.png)

Both come from ITU-R data files (see [data/SOURCES.md](data/SOURCES.md)),
loaded in this order:

1. `MATLAB_ITM_MAPS_DIR`, if set: `itm_maps.mat` or the two ITU text files.
1. `data/TropoClim.txt` and `data/N050.TXT` in this repository.
1. The same files packaged in a compiled app.
1. `<cache>/itu_maps/itm_maps.mat`.
1. A download of the ITU supplement ZIPs, parsed and cached. Set
   `MATLAB_ITM_OFFLINE=1` to forbid it.

ITU forbids reproducing or distributing its digital maps without written
permission. Keep this repository and apps built from it inside your
organization.

- **Radio climate:** ITU-R P.617-3 radio-climatic zone map (`TropoClim.txt`,
  0.5° grid), nearest grid point, at the path midpoint. If the midpoint is
  over sea (code 7), the lower of the two terminal climates is used.
- **Refractivity:** ITU-R P.452 sea-level surface refractivity (`N050.TXT`,
  1.5° grid), bilinear interpolation, at the path midpoint. ITM converts N₀
  to the surface value Nₛ with the profile's mean terrain height.

These rules and the parameter defaults below follow the WInnForum CBRS SAS
reference model (`tropoclim.py`, `refractivity.py`, `wf_itm.py`). The
lookups reproduce that code exactly on 309 global test points.

Note: the ITU-R P.617 map puts Washington, DC, and most of the eastern
U.S. south of about 40.5° N in climate 6 (maritime temperate over land),
not 5 (continental temperate).

![World climate zones and refractivity](docs/climate_refractivity_world.png)

To redraw both figures from the data files: `python3 docs/make_maps.py`.

## Defaults

| Parameter | Default | Option |
| --- | --- | --- |
| Confidence | 50 % | `confidence` |
| Polarization | Vertical | `polarization` |
| Relative permittivity | 25 | `epsilon` |
| Conductivity | 0.02 S/m | `sigma` |
| Mode of variability | 13 (broadcast, no location variability) | `mdvar` |
| Profile spacing | 30 m (native DEM resolution) | `spacing_m` |
| Profile point cap | None (WInnForum uses 1501) | `max_points` |

Reliability and confidence are percentages (0 to 100, exclusive), as in the
NTIA code. The WInnForum Python wrapper uses fractions (0 to 1).

## Vectorization

- **Reliability and confidence.** The link geometry (horizons, effective
  heights, terrain irregularity, reference attenuation) is computed once.
  Only the variability step runs per percentage, as array math with
  implicit expansion. 1,000 reliabilities cost about the same as one.
- **Terrain.** Horizon search, least-squares fits, and elevation sampling
  are vectorized. Elevations for all links in a call are sampled in one pass
  over the tiles.
- **Lookups.** Climate and refractivity accept arrays of points.
- **Floating point.** Where the C++ accumulates by repeated addition and then
  truncates to an integer index, the MATLAB uses `cumsum`, which adds in the
  same order. A `k*xi` form rounds differently and changed 22 of 740 results
  by up to 0.44 dB in testing.
- **One remaining loop.** The terrain-irregularity resampling keeps a loop of
  at most 245 steps: each step's rounding depends on the previous position,
  so it can't be expressed as an array operation without changing results.
- **Geodesics.** One `distance` call and one `reckon` call cover every point
  of every link (the same points as `track2`, to 2 × 10⁻¹² degrees). The
  WGS84 ellipsoid object is built once.
- **Interpolation.** One `griddedInterpolant` per tile, queried in intrinsic
  coordinates: the same values as `geointerp` to single-precision rounding
  (rarely 1 ulp, about 10⁻⁵ m, apart) and about 25 times faster.
- **Per-link overhead.** `itm_pathloss_rev1` validates its inputs once, then
  calls the private core for each link without re-running the `arguments`
  block (about 0.4 ms per call).

Measured on R2025b, Apple silicon, before these optimizations
(`tests/benchmark_itm_rev1.m`): a cold first call took 1.2 s (0.4 s parsing
the ITU text files, 0.6 s decoding three tiles), one warm link took 33 ms,
and 50 links × 1,000 reliabilities took 79 ms.

## Time per link

Measured on R2025b, Apple silicon (MacBook Air), one 38 km link
(Washington to Baltimore, 1,278 profile points at 30 m, 2700 MHz), tiles
already downloaded. Run `tests/profile_one_link_rev1.m` to reproduce.

| Stage | Warm (tiles in memory) | Cold (new process) |
| --- | --- | --- |
| Geodesic: `distance` + `reckon` for the profile points | 3.2 ms | |
| Terrain: elevation at the profile points (3 tiles) | 2.4 ms | 70 ms (decoded tiles read from disk) |
| Climate and N₀ lookups | 0.8 ms | 11 ms (ITU maps loaded) |
| ITM core (`itm_p2p_rev1`) | 2.3 ms | |
| **Full call (`itm_pathloss_rev1`)** | **8.8 to 12 ms** | 120 to 450 ms (includes MATLAB compiling the functions on first use) |

The warm full call took 33 ms before the optimizations in this repository.
About 60% of it is now terrain: the WGS84 geodesic (`distance`, `reckon`)
is the largest single piece. The ITM core is about 25%, and the number of
reliabilities barely matters: 1,000 reliabilities cost about the same as
one (12.6 ms versus 12.2 ms per link in the same run).

### Compared with ITU-R P.2001 (itu_p2001)

Same link, frequency, and time percentage, each model with its own terrain
handler (`tests/compare_p2001_rev1.m`, same session, back to back, idle
machine). `itu_p2001` has since adopted this repository's decoded-tile
cache and direct intrinsic coordinates (itu_p2001 commit `0a4b762`):

| Model | Cold (new process) | Warm, 1 percentage | Warm, 1,000 percentages | Core model only |
| --- | --- | --- | --- | --- |
| ITM v1.4 (`matlab_itm`) | 122 ms | 12.5 ms | 11.3 ms | 1.9 ms |
| ITU-R P.2001-6, before the port | 832 ms | 14.6 ms | 26.6 ms | 8.0 ms |
| ITU-R P.2001-6, after the port | 259 ms | 13.4 ms | 25.6 ms | 6.8 ms |

- **Terrain dominates both.** The two terrain handlers cost about the same
  per link, so a single percentage costs nearly the same in either model.
- **The models differ in the core.** P.2001 combines many more mechanisms
  per time percentage (ducting, sporadic-E, troposcatter, rain and gas
  fades), so its core costs several times ITM's and grows with the number
  of percentages; ITM's barely does.
- **The port changed no result.** P.2001 losses before and after are
  identical on five test links at seven percentages, and its ITU-R
  validation set still matches to 7 × 10⁻¹³ dB.

### Fidelity to the original release

The optimized code returns the same losses as the first release of this
port (`656996a`): on the same five links (3DEP, 110 km multi-tile, the
coastal sea-rule path, Mount Washington, and the Alps on Copernicus) at
seven reliabilities from 0.1 to 99.9 %, the largest difference is
9 × 10⁻⁹ dB, from interpolation rounding and 10⁻¹² degree geodesic
differences. The 740 NTIA C++ cases still match to 4 × 10⁻¹³ dB.

## Compile for MATLAB Runtime

```matlab
build_itm_app_rev1()                       % self-test app: build/app/itm_app
build_itm_app_rev1(installer=true)         % plus an installer that fetches the Runtime
build_itm_app_rev1(entry="cli")            % command-line path-loss tool
```

The app opens a window with a **Run self-test** button. It runs the same
checks as the test suite and shows PASSED or FAILED, with a row per check.
To verify an installation from a script, run it headless; the exit code is
0 on success and 1 on failure:

```text
itm_app --selftest              # all checks, including terrain downloads
itm_app --selftest --offline    # skip the checks that need the network
```

The build packages everything the code opens by name at run time, which
dependency analysis can't find: `data/` (ITU maps), `private/`, and
`tests/reference/` (for the self-test). Required products: MATLAB and
Mapping Toolbox. To compile these functions into your own app, add the
`itm_*_rev1.m` files and those three folders.

### Things to know before deploying

- **The test suite can't be compiled.** MATLAB Compiler doesn't support
  `matlab.unittest`, so the app runs `itm_selftest_rev1`, which repeats the
  same verifications with plain comparisons.
- **Same release, same platform.** The target needs the MATLAB Runtime for
  the release used to build (R2025b). Build on Windows for Windows targets.
  The installer option downloads the right Runtime.
- **Writable cache.** The app writes terrain tiles to
  `%LOCALAPPDATA%\matlab_itm` (Windows) or `~/.matlab_itm`. On a locked-down
  machine, set `MATLAB_ITM_CACHE` to a writable folder.
- **Network.** The app needs HTTPS access to `prd-tnm.s3.amazonaws.com`
  (USGS) and `copernicus-dem-30m.s3.amazonaws.com` /
  `copernicus-dem-90m.s3.amazonaws.com`. The ITU maps are inside the app.
  Behind a proxy, check that MATLAB Runtime's web access works with
  `itm_app --selftest`.
- **Offline machines.** Run `itm_setup_rev1(region=[...])` on a connected
  machine, copy the cache folder over, and set `MATLAB_ITM_CACHE` to it and
  `MATLAB_ITM_OFFLINE=1`.
- **First run is slower.** Each tile downloads once (about 3 s per 45 MB
  tile) and decodes once; later runs read the decoded cache.
- **ITU terms.** The app contains ITU digital maps, which ITU forbids
  redistributing without permission. Keep it inside your organization.

## Tests

```matlab
runtests('tests')                                         % all

% Skip the tests that download tiles
import matlab.unittest.selectors.HasTag
suite = testsuite('tests');
run(suite.selectIf(~HasTag('Network')))
```

The concurrent-download test needs a parallel pool (`parpool(2)`); without
one, it's reported as incomplete rather than failed.

| Test file | What it checks |
| --- | --- |
| `test_itm_p2p_rev1.m` | NTIA's published example and reliability-by-confidence table; NTIA `p2p.csv` cases; 740 randomized cases against the NTIA C++ (loss to 10⁻⁹ dB; modes, warnings, and intermediate values); vector vs scalar calls; output shapes; monotonic loss vs reliability; free-space check; every error identifier; warning flags. |
| `test_itm_geo_rev1.m` | Climate and refractivity vs WInnForum; maps folder override; setup; vectorized lookups; wrapper vs core; N-link vs single-link calls; offline errors; 3DEP profile; Copernicus fallback, GLO-90, and ocean; uncovered-land error; reuse of the itu_p2001 cache; batched profiles; end-to-end loss; two workers downloading into one folder. |
| `test_app_rev1.m` | The deployable self-test, its progress callback, and the app's button and status box. |

`tests/benchmark_itm_rev1.m` times the workloads a compiled app runs.

The randomized cases come from the NTIA C++ itself. To regenerate them,
see [tests/reference/generator/README.md](tests/reference/generator/README.md).

## Errors and warnings

Errors use identifiers such as `itm:InvalidReliability` and quote the NTIA
error code (for example 1007). ITM warnings don't stop the run:
`info.warnings` holds the NTIA bitmask for every output element, and
`info.warning_messages` lists them in words.

## Relationship to itu_p2001

The ITU maps loader (download, parse, atomic cache), the setup function,
and the terrain handler (tile names and URLs, Copernicus tile lists, the
GLO-90 and USGS 1/3 arc-second sources, the memory cap in GB, and the
uncovered-land error) follow
[nicklasorte/itu_p2001](https://github.com/nicklasorte/itu_p2001)
(`p2001_maps_rev1`, `p2001_setup_rev1`, `p2001_dem_tile_rev1`,
`p2001_terrain_profile_rev1`, `p2001_atomic_save_rev1`). Each tool keeps its
own cache folder (`~/.matlab_itm`, `~/.itu_p2001`), and `matlab_itm` reads
tiles already in the `itu_p2001` cache instead of downloading them again.

## Data credits

- Rec. ITU-R P.617 and P.452 and their digital maps: © ITU.
- USGS 3D Elevation Program: public domain.
- Copernicus DEM: © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH
  2014-2018, provided under COPERNICUS by the European Union and ESA; all
  rights reserved. Free to use worldwide except in Armenia and Azerbaijan.

## References

- NTIA/ITS, [ITM C++ source, v1.4](https://github.com/NTIA/itm)
- G.A. Hufford, A.G. Longley, W.A. Kissick, [A Guide to the Use of the ITS Irregular Terrain Model in the Area Prediction Mode](https://its.ntia.gov/publications/download/82-100_ocr.pdf), NTIA Report 82-100, 1982
- [Recommendation ITU-R P.617](https://www.itu.int/rec/R-REC-P.617), Propagation prediction techniques and data required for the design of trans-horizon radio-relay systems
- [Recommendation ITU-R P.452](https://www.itu.int/rec/R-REC-P.452), Prediction procedure for the evaluation of interference between stations on the surface of the Earth
- Wireless Innovation Forum, [Spectrum Access System reference models](https://github.com/Wireless-Innovation-Forum/Spectrum-Access-System)
