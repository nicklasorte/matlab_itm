function [passed, results] = itm_selftest_rev1(options)
%ITM_SELFTEST_REV1 Verify the ITM port on this machine, including compiled apps.
%   passed = ITM_SELFTEST_REV1() runs every check and returns true when all
%   of them pass (skipped network checks don't count as failures).
%   [passed, results] = ITM_SELFTEST_REV1() also returns a table with one
%   row per check: name, status ("PASS", "FAIL", or "SKIP"), detail, and
%   seconds.
%
%   MATLAB Compiler doesn't support matlab.unittest, so this function uses
%   plain comparisons and runs the same verifications as the test suite
%   in tests/: NTIA's published results, 740 cases from the NTIA C++ ITM
%   v1.4, the ITU climate and refractivity lookups against the WInnForum
%   reference model, input errors, and (with network) live terrain.
%
%   Name-value options:
%     network   Run the checks that download terrain tiles (true)
%     progress  Function handle called as progress(row) after each check,
%               where row is a one-row table; the app uses it to update
%               its log while the checks run
%
%   Example:
%     [ok, T] = itm_selftest_rev1(); disp(T)
%
%   See also itm_app_rev1, build_itm_app_rev1.

arguments
    options.network (1,1) logical = true
    options.progress = []
end

ref = reference_dir();
checks = { ...
    "ITU maps load",                          @() check_maps(); ...
    "NTIA published example and table",       @() check_ntia_example(ref); ...
    "NTIA p2p.csv cases",                     @() check_ntia_csv(ref); ...
    "740 cases vs NTIA C++ ITM v1.4",         @() check_cpp(ref); ...
    "Reliability vector equals scalar calls", @() check_vector(ref); ...
    "Climate and N0 vs WInnForum (309 points)", @() check_itu(ref); ...
    "Input errors raise ITM identifiers",     @() check_errors(); ...
    "Terrain: 3DEP profile (network)",        @() check_3dep(); ...
    "Terrain: Copernicus and ocean (network)", @() check_copernicus(); ...
    "End-to-end path loss (network)",         @() check_end_to_end()};
is_network = endsWith([checks{:, 1}]', "(network)");

n = size(checks, 1);
name = [checks{:, 1}]';
status = strings(n, 1);
detail = strings(n, 1);
seconds = zeros(n, 1);
net = [];                          % probed once per run, at the first network check
for k = 1:n
    if is_network(k) && options.network && isempty(net)
        net = network_ok();
    end
    t0 = tic;
    if is_network(k) && ~options.network
        status(k) = "SKIP";
        detail(k) = "network checks turned off";
    elseif is_network(k) && ~net
        status(k) = "SKIP";
        detail(k) = "USGS tile server unreachable";
    else
        try
            detail(k) = checks{k, 2}();
            status(k) = "PASS";
        catch err
            status(k) = "FAIL";
            detail(k) = string(err.message);
        end
    end
    seconds(k) = toc(t0);
    if ~isempty(options.progress)
        options.progress(table(name(k), status(k), detail(k), seconds(k), ...
            'VariableNames', {'name', 'status', 'detail', 'seconds'}));
    end
end
results = table(name, status, detail, seconds);
passed = ~any(status == "FAIL");
end

%% ------------------------------------------------------------------------
function d = check_maps()
c = itm_radio_climate_rev1(38.9, -77.0);
n = itm_surface_refractivity_rev1(38.9, -77.0);
must(c == 6, "Climate at Washington, DC is %d; expected 6.", c);
must(n > 300 && n < 350, "N0 at Washington, DC is %.2f; expected 300-350.", n);
d = sprintf("climate %d, N0 %.2f at Washington, DC", c, n);
end

function d = check_ntia_example(ref)
pfl = read_ntia_pfl(fullfile(ref, 'ntia_example_pfl.txt'));
args = {'climate', 5, 'N_0', 301, 'polarization', 1, 'epsilon', 15, 'sigma', 0.005, 'mdvar', 1};
L = itm_p2p_rev1(15, 3, pfl, 3500, [10; 65; 90], 'confidence', [10 60 90], args{:});
published = [110.9 117.2 129.1; 110.9 117.4 129.2; 110.9 117.5 129.3];
must(isequal(round(L, 1), published), "Table differs from NTIA o_p2pcr_tbl.txt.");
[L50, iv] = itm_p2p_rev1(15, 3, pfl, 3500, 50, args{:});
got = [round(L50, 1), round(iv.d_km, 3), round(iv.N_s, 1), round(iv.delta_h_m, 1), iv.mode];
must(isequal(got, [114.5, 3.635, 251.5, 3.2, 1]), "Intermediate values differ from NTIA o_p2pcr.txt.");
d = "3x3 table and intermediate values match NTIA";
end

function d = check_ntia_csv(ref)
T = readtable(fullfile(ref, 'ntia_p2p.csv'));
P = read_profiles(fullfile(ref, 'ntia_pfls.csv'));
err = zeros(height(T), 1);
for k = 1:height(T)
    r = T(k, :);
    A = itm_p2p_rev1(r.h_tx__meter, r.h_rx__meter, P{k}, r.f__mhz, r.time, 'confidence', r.situation, ...
        'location', r.location, 'climate', r.climate, 'N_0', r.N_0, 'polarization', r.pol, ...
        'epsilon', r.epsilon, 'sigma', r.sigma, 'mdvar', r.mdvar);
    err(k) = abs(A - r.A__db);
end
must(all(err <= 0.005), "Max difference %.4f dB exceeds the 0.005 dB rounding of p2p.csv.", max(err));
d = sprintf("%d cases, max difference %.4f dB (2-decimal reference)", height(T), max(err));
end

function d = check_cpp(ref)
[C, E, P] = load_cpp(ref);
n = size(C, 1);
A = zeros(n, 1); W = zeros(n, 1); M = zeros(n, 1);
for k = 1:n
    [A(k), info] = run_case(C(k, :), P);
    W(k) = double(info.warnings);
    M(k) = info.mode;
end
dA = max(abs(A - E(:, 4)));
must(dA <= 1e-9, "Max loss difference %.3g dB exceeds 1e-9 dB.", dA);
must(isequal(M, E(:, 16)), "%d propagation modes differ.", nnz(M ~= E(:, 16)));
must(isequal(W, E(:, 3)), "%d warning flags differ.", nnz(W ~= E(:, 3)));
d = sprintf("max difference %.2g dB; modes and warnings identical", dA);
end

function d = check_vector(ref)
[C, E, P] = load_cpp(ref);
[~, ~, idx] = unique(C(:, [1:9 11 12 13]), 'rows', 'stable');
groups = find(accumarray(idx, 1) >= 5);
worst = 0;
for g = groups'
    rows = find(idx == g);
    c = C(rows(1), :);
    Lv = itm_p2p_rev1(c(1), c(2), P{c(13) + 1}, c(5), C(rows, 10), 'confidence', c(12), ...
        'location', c(11), 'climate', c(3), 'N_0', c(4), 'polarization', c(6), ...
        'epsilon', c(7), 'sigma', c(8), 'mdvar', c(9));
    worst = max([worst; abs(Lv - E(rows, 4))]);
end
must(numel(groups) >= 20 && worst <= 1e-9, "Vector calls differ from C++ by %.3g dB.", worst);
d = sprintf("%d reliability sweeps, max difference %.2g dB", numel(groups), worst);
end

function d = check_itu(ref)
T = readtable(fullfile(ref, 'itu_lookup_expected.csv'));
c = itm_radio_climate_rev1(T.lat, T.lon);
n = itm_surface_refractivity_rev1(T.lat, T.lon);
must(isequal(c, T.climate), "%d climate codes differ.", nnz(c ~= T.climate));
dn = max(abs(n - T.N_0));
must(dn <= 1e-8, "N0 differs by %.3g N-units.", dn);
d = sprintf("%d points; climate identical, N0 within %.1g", height(T), dn);
end

function d = check_errors()
pfl = [100; 100; zeros(101, 1)];
cases = { ...
    @() itm_p2p_rev1(30, 10, pfl, 2700, 0), 'itm:InvalidReliability'; ...
    @() itm_p2p_rev1(30, 10, pfl, 2700, 50, 'confidence', 100), 'itm:InvalidConfidence'; ...
    @() itm_p2p_rev1(30, 10, pfl, 19, 50), 'itm:InvalidFrequency'; ...
    @() itm_p2p_rev1(0.4, 10, pfl, 2700, 50), 'itm:InvalidTxHeight'; ...
    @() itm_p2p_rev1(30, 10, pfl, 2700, 50, 'mdvar', 4), 'itm:InvalidMdvar'; ...
    @() itm_p2p_rev1(30, 10, pfl(1:end - 1), 2700, 50), 'itm:InvalidProfile'};
for k = 1:size(cases, 1)
    id = "";
    try
        cases{k, 1}();
    catch err
        id = string(err.identifier);
    end
    must(id == cases{k, 2}, "Expected %s, got ""%s"".", cases{k, 2}, id);
end
d = sprintf("%d invalid inputs rejected with the right identifier", size(cases, 1));
end

function d = check_3dep()
[pfl, info] = itm_terrain_profile_rev1(38.8895, -77.0353, 39.0458, -76.6413);
dist = distance(38.8895, -77.0353, 39.0458, -76.6413, wgs84Ellipsoid('meter'));
must(abs(pfl(1) * pfl(2) - dist) <= 1e-6 * dist, "Profile length doesn't match the geodesic.");
must(all(info.source_code == 1), "Not every point came from 3DEP.");
z = pfl(3:end);
must(all(z > -10 & z < 200), "Elevations outside -10 to 200 m.");
d = sprintf("%d points at %.1f m, all 3DEP, %.0f to %.0f m", numel(z), pfl(2), min(z), max(z));
end

function d = check_copernicus()
[z, info] = itm_terrain_elevation_rev1([51.50; 36.50], [-0.12; -30.50]);
must(isequal(info.source_code, uint8([2; 0])), "London should be GLO-30 and the Atlantic none.");
must(z(1) > -5 && z(1) < 60 && z(2) == 0, "Elevations out of range: %g, %g.", z(1), z(2));
d = sprintf("London %.1f m (GLO-30), mid-Atlantic 0 m", z(1));
end

function d = check_end_to_end()
tx = [38.8895, -77.0353, 30];
rx = [39.0458, -76.6413, 10];
rel = [1 10 50 90 99];
[L, info] = itm_pathloss_rev1(tx, rx, 2700, rel);
must(all(diff(L) >= 0), "Loss decreases with reliability.");
must(L(3) > info.A_fs_db - 10 && L(3) < 250, "Median loss %.1f dB is implausible.", L(3));
L2 = itm_p2p_rev1(30, 10, info.pfl, 2700, rel, 'climate', info.climate, 'N_0', info.N_0);
must(max(abs(L - L2)) < 1e-12, "Wrapper differs from the core.");
d = sprintf("loss at 1/50/99%% = %.2f / %.2f / %.2f dB, climate %d", L(1), L(3), L(5), info.climate);
end

%% ------------------------------------------------------------------------
function must(cond, fmt, varargin)
if ~cond
    error('itm:selftest:Failed', fmt, varargin{:});
end
end

function [C, E, P] = load_cpp(ref)
persistent cache
if isempty(cache) || ~strcmp(cache.ref, ref)
    cache.ref = ref;
    cache.C = readmatrix(fullfile(ref, 'rand_cases.csv'));
    cache.E = readmatrix(fullfile(ref, 'rand_expected.csv'));
    cache.P = read_profiles(fullfile(ref, 'rand_pfls.csv'));
end
C = cache.C; E = cache.E; P = cache.P;
end

function [A, info] = run_case(c, P)
[A, info] = itm_p2p_rev1(c(1), c(2), P{c(13) + 1}, c(5), c(10), 'confidence', c(12), ...
    'location', c(11), 'climate', c(3), 'N_0', c(4), 'polarization', c(6), 'epsilon', c(7), ...
    'sigma', c(8), 'mdvar', c(9));
end

function P = read_profiles(file)
lines = readlines(file);
lines = lines(strlength(strtrim(lines)) > 2);
P = cell(numel(lines), 1);
for k = 1:numel(lines)
    P{k} = str2double(split(lines(k), ','));
end
end

function pfl = read_ntia_pfl(file)
v = str2double(split(strjoin(readlines(file), ','), ','));
pfl = v(~isnan(v));
end

function ref = reference_dir()
% tests/reference in the source tree or inside a compiled app
ref = fullfile(fileparts(mfilename('fullpath')), 'tests', 'reference');
if isfile(fullfile(ref, 'rand_cases.csv'))
    return
end
if isdeployed
    hits = dir(fullfile(ctfroot, '**', 'rand_cases.csv'));
    if ~isempty(hits)
        ref = hits(1).folder;
        return
    end
end
error('itm:selftest:NoReference', ...
    'Reference files not found at %s. Compiled apps must package tests/reference.', ref);
end

function ok = network_ok()
try
    r = matlab.net.http.RequestMessage('HEAD');
    resp = send(r, matlab.net.URI( ...
        'https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1/TIFF/current/n39w077/USGS_1_n39w077.tif'));
    ok = resp.StatusCode == matlab.net.http.StatusCode.OK;
catch
    ok = false;
end
end
