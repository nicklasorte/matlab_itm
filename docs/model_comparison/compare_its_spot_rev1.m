function T = compare_its_spot_rev1(options)
%COMPARE_ITS_SPOT_REV1 ITM, P.452, and P.2001 against the ITS Phase 1 and low-antenna spot measurements.
%   T = COMPARE_ITS_SPOT_REV1() reads two more ITS legacy spot-measurement
%   sets (https://its.ntia.gov/data/legacy-radio-propagation-data/; see
%   data/its/README.md) and runs the three models at 50 % of time:
%
%   Phase 1 (data/its/its_phase1.zip), 1963-64, VHF, surveyed profiles:
%     PL  Colorado plains      MT  Colorado mountains     OH  Ohio hills
%     50 MHz (receiver 0.55 m or 0.6 m, and 1.7 m; vertical) and 100 MHz
%     (receiver 3, 6, and 9 m; vertical and horizontal); transmitter 3.15 m
%     to 4.2 m. Only the principal receiving sites (P) are used; the
%     alternate sites (V, H) have no coordinates. 20 MHz (below the models'
%     range) and the second transmitter KLIR (no profile) are left out.
%   Low antenna (data/its/its_low_antenna.zip), 1968, UHF, arid western
%   terrain, no profiles:
%     WY  Laramie Mountains    ID  Snake River Plateau    WA  Columbia Plateau
%     230 MHz and 416 MHz, vertical; transmitter 0.75 m or 3 m; receiver
%     0.75 m to 3 m. Terrain is 30 m USGS 3DEP along the geodesic between
%     the listed coordinates (wp_terrain_profile). The sites were "generally
%     on the highest ground within 100 m of an originally chosen point", so a
%     second run (terrain "dem_high") moves each terminal to the highest 30 m
%     terrain point within 100 m of its listed position.
%
%   Data are attenuation relative to free space at the listed distance;
%   measured basic transmission loss is free space plus that value. 999 is
%   no measurement. In Phase 1, a value of 500 or more means the signal was
%   below sensitivity (a lower bound, flagged as censored). Low-antenna data
%   don't distinguish missing from below-sensitivity values (all 999).
%
%   Profiles: surveyed profiles transmitter first, resampled to 30 m;
%   inland everywhere (P.452 zone 2, P.2001 zone 4). Paths whose surveyed
%   profile length differs from the listed distance by more than 5 % (and
%   0.05 km) are left out.
%
%   Writes chart_data/its_spot_results.csv: one row per set, path,
%   frequency, polarization, and antenna heights, with terrain source,
%   measured attenuation and loss, censored flag, free-space loss, each
%   model's loss, and ITM's delta h and region (1 line of sight,
%   2 diffraction, 3 troposcatter).
%
%   Options: OutDir, P2001Dir, P452Dir, Sets (["pl" "mt" "oh" "wy" "id"
%   "wa"]), MaxPaths (Inf), Download (true, terrain tiles for the
%   low-antenna paths).

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Sets (1,:) string = ["pl", "mt", "oh", "wy", "id", "wa"]
    options.MaxPaths (1,1) double = Inf
    options.Download (1,1) logical = true %#ok<INUSA> used through itm_terrain_profile_rev1 defaults
end
here = fileparts(mfilename('fullpath'));
itm_root = wp_setup(options.P2001Dir, options.P452Dir);
old_env = getenv('MATLAB_P452_ITM_DIR');
restore = onCleanup(@() setenv('MATLAB_P452_ITM_DIR', old_env)); %#ok<NASGU>
setenv('MATLAB_P452_ITM_DIR', itm_root);
p452_addpath_rev1();
tmp = fullfile(tempdir, 'its_spot');
if ~isfolder(fullfile(tmp, 'phase_1')), unzip(fullfile(here, 'data', 'its', 'its_phase1.zip'), tmp); end
if ~isfolder(fullfile(tmp, 'low_ant')), unzip(fullfile(here, 'data', 'its', 'its_low_antenna.zip'), tmp); end
E = wgs84Ellipsoid('km');
models = ["itm", "p452", "p2001"];
wopts = {'validity', "off", 'surface_source', "none", 'max_points', 5000, 'download', false};

rows = {};
for s = options.Sets
    phase1 = ismember(s, ["pl", "mt", "oh"]);
    if phase1, root = fullfile(tmp, 'phase_1'); else, root = fullfile(tmp, 'low_ant'); end
    [C, P, D] = read_set(root, s, phase1);
    np = min(height(P), options.MaxPaths);
    fprintf('%s: %d paths\n', upper(s), height(P));
    for k = 1:np
        pth = P.path(k); tx = [P.xlat(k), P.xlon(k)]; rx = [P.rlat(k), P.rlon(k)]; dl = P.dist(k);
        R = D(D.path == pth, :);
        if isempty(R), continue, end
        if phase1
            v = survey_profile(root, s, pth);
            if isempty(v) || abs(v(end, 1) - dl) > max(0.05 * dl, 0.05), continue, end
            variants = {"survey", tx, rx, v};
        else
            v1 = dem_profile(tx, rx);
            [tx2, rx2] = highest_nearby(tx, rx, E);
            v2 = dem_profile(tx2, rx2);
            variants = {"dem", tx, rx, v1; "dem_high", tx2, rx2, v2};
        end
        for vi = 1:size(variants, 1)
            [src, t1, r1, v] = variants{vi, :};
            prof = make_profile(v, t1, r1, E);
            [dh, reg] = itm_info(prof, t1, r1);
            for j = 1:height(C)
                f = C.freq(j);
                if f < 30 || startsWith(C.name(j), "KLIR"), continue, end   % 20 MHz; second transmitter (no profile)
                if phase1
                    hrx = C.rht(j) * ones(height(R), 1); a = R.A(:, j);
                else
                    hrx = R.rht; a = R.A(:, j);
                end
                htx = C.xht(j);
                ok = a < 999;
                if ~any(ok), continue, end
                cens = phase1 & a >= 500;
                a(cens) = a(cens) - 500;
                fs = 32.45 + 20 * log10(f) + 20 * log10(dl);
                pol = "vertical"; if C.pol(j) == "H", pol = "horizontal"; end
                mo = struct('itm', {{'polarization', pol}}, 'p452', {{'polarization', pol}}, 'p2001', {{'Polarization', pol}});
                n = nnz(ok);
                L = NaN(n, 3);
                for mi = 1:3
                    m = models(mi);
                    if m == "p452" && f < 100, continue, end
                    try
                        L(:, mi) = pathloss_rev1(repmat([t1 htx], n, 1), [repmat(r1, n, 1), hrx(ok)], f, 50, 'model', m, ...
                            'model_options', mo.(m), 'profile', repmat(prof, n, 1), wopts{:});
                    catch
                    end
                end
                ii = find(ok);
                for q = 1:n
                    rows(end + 1, :) = {upper(s), pth, src, dl, prof.distance_km, f, C.pol(j), htx, hrx(ii(q)), ...
                        a(ii(q)), cens(ii(q)), fs + a(ii(q)), fs, L(q, 1), L(q, 2), L(q, 3), dh, reg}; %#ok<AGROW>
                end
            end
        end
        if mod(k, 25) == 0, fprintf('  %s %d of %d\n', upper(s), k, np); end
    end
end
T = cell2table(rows, 'VariableNames', {'set', 'path', 'terrain', 'd_km', 'profile_km', 'freq_mhz', 'pol', 'htx_m', 'hrx_m', ...
    'meas_excess_db', 'censored', 'meas_lb_db', 'fs_db', 'itm_50', 'p452_50', 'p2001_50', 'delta_h_m', 'itm_region'});
if ~isfolder(options.OutDir), mkdir(options.OutDir); end
writetable(T, fullfile(options.OutDir, 'its_spot_results.csv'));
fprintf('%d results\n', height(T));
end

%% ------------------------------------------------------------------------
function [C, P, D] = read_set(root, s, phase1)
% Column definitions (pars), paths, and data. C: one row per data column.
txt = splitlines(strtrim(string(fileread(fullfile(root, s + "pars.txt")))));
hdr = split(strtrim(txt(1)));
C = table();
for i = 2:numel(txt)
    c = split(strtrim(txt(i)));
    if numel(c) < numel(hdr), continue, end
    r = table(c(1), str2double(c(2)), c(3), 'VariableNames', {'name', 'freq', 'pol'});
    if phase1
        r.rht = str2double(c(4)); r.xht = str2double(c(5));
    else
        r.rht = NaN; r.xht = str2double(c(4));
    end
    C = [C; r]; %#ok<AGROW>
end
fid = fopen(fullfile(root, s + "path.txt")); cl = onCleanup(@() fclose(fid));
x = textscan(fid, '%s %f %f %f %f %f', 'HeaderLines', 1);
P = table(string(x{1}), x{2}, x{3}, x{4}, x{5}, x{6}, 'VariableNames', {'path', 'xlat', 'xlon', 'rlat', 'rlon', 'dist'});
lines = splitlines(string(fileread(fullfile(root, s + "data.txt"))));
nc = height(C);
D = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'double'}, 'VariableNames', {'path', 'rht', 'A'});
pathc = strings(0, 1); rht = zeros(0, 1); A = zeros(0, nc);
for i = 1:numel(lines)
    c = split(strtrim(lines(i)));
    if numel(c) < 2 || startsWith(c(1), "Path") || startsWith(c(1), "-"), continue, end
    if phase1
        if s == "oh", c(2) = []; end                     % Ohio: transmitter column
        vals = str2double(c(2:end))';
        r = NaN;
    else
        r = str2double(c(2)); vals = str2double(c(3:end))';
    end
    if numel(vals) ~= nc, continue, end
    pathc(end + 1, 1) = c(1); rht(end + 1, 1) = r; A(end + 1, :) = vals; %#ok<AGROW>
end
D = table(pathc, rht, A, 'VariableNames', {'path', 'rht', 'A'});
end

function v = survey_profile(root, s, pth)
% "MT-05-P13" -> 005mtp13.pfl; Ohio "T0-10-P1" -> 010t0p1.pfl
p = split(pth, "-");
nom = sprintf('%03d', str2double(replace(p(2), "_", ".")));
if contains(p(2), "_"), nom = replace(p(2), "_", "'"); end
fn = fullfile(root, s + "_pfl", lower(nom + p(1) + p(3)) + ".pfl");
v = [];
if ~isfile(fn), return, end
[h, v] = read_pfl(fn);
if size(v, 1) < 2, v = []; return, end
if h(5) == 1, v = [v(end, 1) - flipud(v(:, 1)), flipud(v(:, 2))]; end
end

function v = dem_profile(tx, rx)
prof = wp_terrain_profile(tx, rx);
v = [prof.d_km, prof.h_m];
end

function [tx2, rx2] = highest_nearby(tx, rx, E)
% Each terminal moved to the highest 30 m terrain point within 100 m
tx2 = top(tx, E); rx2 = top(rx, E);
end

function q = top(p, E)
[dn, de] = meshgrid(-0.1:0.03:0.1, -0.1:0.03:0.1);
in = hypot(dn, de) <= 0.1 + 1e-9;
az = atan2d(de(in), dn(in)); r = hypot(dn(in), de(in));
[la, lo] = reckon(p(1), p(2), r, az, E);
z = itm_terrain_elevation_rev1(la, lo);
[~, i] = max(z);
q = [la(i), lo(i)];
end

function prof = make_profile(v, tx, rx, E)
dt = v(end, 1); np = max(10, round(dt / 0.03));
d = linspace(0, dt, np + 1)'; h = interp1(v(:, 1), v(:, 2), d, 'linear');
[arclen, az] = distance(tx(1), tx(2), rx(1), rx(2), E);
[mla, mlo] = reckon(tx(1), tx(2), arclen / 2, az, E);
prof = struct('d_km', d, 'h_m', h, 'g_m', h, 'zone', 2 * ones(size(d)), 'spacing_m', 1000 * dt / np, ...
    'midpoint_deg', [mla mlo], 'distance_km', dt);
end

function [dh, reg] = itm_info(prof, tx, rx)
% ITM delta h and region at 50 %, 100 MHz, 3 m antennas (geometry only)
pfl = [numel(prof.d_km) - 1; prof.spacing_m; prof.h_m(:)];
c = itm_radio_climate_rev1(prof.midpoint_deg(1), prof.midpoint_deg(2));
if c == 7, c = min(itm_radio_climate_rev1(tx(1), tx(2)), itm_radio_climate_rev1(rx(1), rx(2))); end
n0 = itm_surface_refractivity_rev1(prof.midpoint_deg(1), prof.midpoint_deg(2));
[~, info] = itm_p2p_rev1(3, 3, pfl, 100, 50, climate=c, N_0=n0, validity="off");
dh = info.delta_h_m; reg = info.mode;
end

function x = lon180(x)
x(x > 180) = x(x > 180) - 360;
end

function [h, v] = read_pfl(fn)
txt = splitlines(string(fileread(fn)));
h = NaN(1, 5); v = zeros(0, 2);
for i = 1:numel(txt)
    t = txt(i);
    if startsWith(t, "TX CNTRY") || startsWith(t, "RX CNTRY")
        x = sscanf(char(extractAfter(t, 11)), '%f %f');
        if numel(x) == 2
            j = 1 + 2 * startsWith(t, "RX");
            h(j:j + 1) = [x(1), lon180(x(2))];
        end
    elseif contains(t, "First Point")
        h(5) = double(endsWith(strtrim(t), "R"));
    elseif ~isempty(regexp(t, '^\s*\d*\.?\d+\s+-?\d*\.?\d+', 'once'))
        x = sscanf(char(t), '%f %f');
        v(end + 1, :) = x(1:2)'; %#ok<AGROW>
    end
end
[~, ia] = unique(v(:, 1), 'stable'); v = v(ia, :);
end
