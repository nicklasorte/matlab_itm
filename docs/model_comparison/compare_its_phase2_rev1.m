function T = compare_its_phase2_rev1(options)
%COMPARE_ITS_PHASE2_REV1 ITM, P.452, and P.2001 against the ITS Phase 2 irregular-terrain measurements.
%   T = COMPARE_ITS_PHASE2_REV1() reads the ITS "Phase 2" spot measurements
%   (data/its/its_phase2.zip, from https://its.ntia.gov/data/legacy-radio-propagation-data/;
%   see data/its/README.md), and runs the three models on every measured
%   path that has a surveyed terrain profile:
%     R1  Colorado plains (Gunbarrel Hill receiver)        230-9190 MHz
%     R2  Colorado mountains (Fritz Peak receiver)          230-9190 MHz
%     R3  North Table Mountain, Golden (air to ground)      230-9190 MHz
%     VA  Virginia piedmont                                   76-8395 MHz
%   R4 (a receiver inside a woods) has no profiles and is left out.
%
%   Measured basic transmission loss is free-space loss at the listed path
%   distance plus the measured attenuation relative to free space,
%       Lb = 32.45 + 20 log10(f_MHz) + 20 log10(d_km) + A.
%   Each path was measured in one or more runs; the measured value is the
%   median over the runs. A value of 500 or more in the data means the signal
%   was below the system's sensitivity, so the attenuation was greater than
%   the value minus 500. A result with any such run is marked censored: its
%   measured loss is only a lower bound, and it is left out of the error
%   statistics (paper_numbers_3ghz_rev1 counts how often each model predicts
%   less loss than the bound).
%
%   Antennas (horizontal polarization throughout):
%     Colorado  transmitter 6.6 m (230-751 MHz) or 7.3 m (910-9190 MHz);
%               receiver at each height from 1 m to 13 m (15 m at R3)
%     Virginia  heights per frequency from vapars.txt: receiver van 1 or 2
%               at its "Hi" height, or "Lo" (2 m)
%
%   Terrain: the surveyed profile, transmitter first, resampled linearly to
%   30 m spacing (the profiles were read from 1:24,000 and 1:62,500 maps, so
%   points are sparse), inland everywhere (P.452 zone 2, P.2001 zone 4).
%   Paths whose profile length differs from the listed distance by more than
%   5 % (and 0.05 km) are left out. The models run through pathloss_rev1
%   (nicklasorte/matlab_itu_p452) at 50 % of time, one path and frequency
%   per call, all of that path's receiver heights together; P.452 for
%   100 MHz and above. ITM's terrain irregularity delta h and propagation
%   mode at 50 % come from itm_p2p_rev1 on the same profile.
%
%   Writes to options.OutDir (chart_data/):
%     its_phase2_results.csv  one row per path, siting, frequency, and
%                             receiver configuration: distance, heights,
%                             runs, measured attenuation and loss, censored
%                             flag, free-space loss, and each model's loss
%     its_phase2_paths.csv    one row per path and siting: profile used,
%                             lengths, ITM delta h and ITM region (1 line of sight,
%                             2 diffraction, 3 troposcatter) at 50 % and
%                             the frequency nearest 3 GHz, and whether
%                             the path was kept
%
%   Options: OutDir, P2001Dir, P452Dir, Sets (["r1" "r2" "r3" "va"]),
%   MaxPaths (Inf, for a quick test).

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Sets (1,:) string = ["r1", "r2", "r3", "va"]
    options.MaxPaths (1,1) double = Inf
end
here = fileparts(mfilename('fullpath'));
itm_root = wp_setup(options.P2001Dir, options.P452Dir);
old_env = getenv('MATLAB_P452_ITM_DIR');
restore = onCleanup(@() setenv('MATLAB_P452_ITM_DIR', old_env)); %#ok<NASGU>
setenv('MATLAB_P452_ITM_DIR', itm_root);
p452_addpath_rev1();

tmp = fullfile(tempdir, 'its_phase2');
if ~isfolder(fullfile(tmp, 'phase_2')), unzip(fullfile(here, 'data', 'its', 'its_phase2.zip'), tmp); end
root = fullfile(tmp, 'phase_2');
E = wgs84Ellipsoid('km');
models = ["itm", "p452", "p2001"];
mopts = struct('itm', {{'polarization', "horizontal"}}, 'p452', {{'polarization', "horizontal"}}, ...
    'p2001', {{'Polarization', "horizontal"}});
wopts = {'validity', "off", 'surface_source', "none", 'max_points', 5000, 'download', false};

rows = {}; prow = {};
for s = options.Sets
    va = s == "va";
    pars = readmatrix(fullfile(root, s + "pars.txt"), 'NumHeaderLines', 1, 'FileType', 'text');
    F = pars(:, 1)';
    [P, D] = read_set(root, s, va);
    keys = unique(D(:, {'path', 'siting'}), 'rows', 'stable');
    nk = min(height(keys), options.MaxPaths);
    fprintf('%s: %d paths with data\n', upper(s), height(keys));
    for k = 1:nk
        pth = keys.path(k); site = keys.siting(k);
        if va
            ip = find(P.path == pth, 1);
        else
            ip = find(P.path == pth & P.site == site, 1);
            if isempty(ip), ip = find(P.path == pth, 1); end
        end
        if isempty(ip), continue, end
        tx = [P.xlat(ip), P.xlon(ip)]; rx = [P.rlat(ip), P.rlon(ip)]; dlist = P.dist(ip);
        fn = profile_name(root, s, pth, site, va);
        kept = false; plen = NaN; dh = NaN; imode = ""; why = "";
        if strlength(fn) == 0
            why = "no profile";
        else
            [hdr, v] = read_pfl(fn);
            if any(isnan(hdr(1:4))) || size(v, 1) < 2
                why = "unreadable profile";
            else
                if hdr(5) == 1, v = [v(end, 1) - flipud(v(:, 1)), flipud(v(:, 2))]; end   % transmitter first
                plen = v(end, 1);
                if abs(plen - dlist) > max(0.05 * dlist, 0.05)
                    why = "profile length";
                else
                    kept = true;
                end
            end
        end
        if kept
            prof = make_profile(v, tx, rx, E);
            [dh, imode] = itm_info(prof, F, tx, rx, va, pars);
        end
        [~, pf] = fileparts(fn);
        prow(end + 1, :) = {upper(s), pth, site, string(pf), dlist, plen, dh, imode, kept, why}; %#ok<AGROW>
        if ~kept, continue, end

        % Measurement configurations for this path and siting
        R = D(D.path == pth & D.siting == site, :);
        if va
            cfg = unique(R(:, {'rcvr', 'rht'}), 'rows');
        else
            cfg = unique(R(:, {'rht'}), 'rows'); cfg.rcvr = zeros(height(cfg), 1);
        end
        nc = height(cfg);
        for j = 1:numel(F)
            if va
                htx = pars(j, 2);
                hrx = zeros(nc, 1);
                for c = 1:nc
                    if cfg.rht(c) == "Lo", hrx(c) = pars(j, 5); else, hrx(c) = pars(j, 2 + cfg.rcvr(c)); end
                end
            else
                htx = pars(j, 2); hrx = double(cfg.rht);
            end
            if j > 1 && F(j) == F(j - 1), continue, end      % R4-style repeated column
            meas = NaN(nc, 1); cens = false(nc, 1); nrun = zeros(nc, 1);
            for c = 1:nc
                if va
                    sel = R.rcvr == cfg.rcvr(c) & R.rht == cfg.rht(c);
                else
                    sel = R.rht == cfg.rht(c);
                end
                a = R.A(sel, j);
                a = a(a < 999);
                if isempty(a), continue, end
                b = a >= 500;
                a(b) = a(b) - 500;
                meas(c) = median(a); cens(c) = any(b); nrun(c) = numel(a);
            end
            ok = isfinite(meas);
            if ~any(ok), continue, end
            fs = 32.45 + 20 * log10(F(j)) + 20 * log10(dlist);
            L = NaN(nc, numel(models));
            TXr = repmat([tx htx], nnz(ok), 1); RXr = [repmat(rx, nnz(ok), 1), hrx(ok)];
            pr = repmat(prof, nnz(ok), 1);
            for mi = 1:numel(models)
                m = models(mi);
                if m == "p452" && F(j) < 100, continue, end
                try
                    L(ok, mi) = pathloss_rev1(TXr, RXr, F(j), 50, 'model', m, 'model_options', mopts.(m), 'profile', pr, wopts{:});
                catch
                end
            end
            for c = find(ok)'
                rows(end + 1, :) = {upper(s), pth, site, dlist, plen, F(j), htx, hrx(c), cfg.rcvr(c), string(cfg.rht(c)), ...
                    nrun(c), meas(c), cens(c), fs + meas(c), fs, L(c, 1), L(c, 2), L(c, 3), dh, imode}; %#ok<AGROW>
            end
        end
        if mod(k, 20) == 0, fprintf('  %s %d of %d\n', upper(s), k, nk); end
    end
end
T = cell2table(rows, 'VariableNames', {'set', 'path', 'siting', 'd_km', 'profile_km', 'freq_mhz', 'htx_m', 'hrx_m', ...
    'rcvr', 'rht', 'runs', 'meas_excess_db', 'censored', 'meas_lb_db', 'fs_db', 'itm_50', 'p452_50', 'p2001_50', ...
    'delta_h_m', 'itm_region'});
Pt = cell2table(prow, 'VariableNames', {'set', 'path', 'siting', 'profile', 'd_km', 'profile_km', 'delta_h_m', ...
    'itm_region', 'kept', 'reason'});
if ~isfolder(options.OutDir), mkdir(options.OutDir); end
writetable(T, fullfile(options.OutDir, 'its_phase2_results.csv'));
writetable(Pt, fullfile(options.OutDir, 'its_phase2_paths.csv'));
fprintf('%d results on %d kept paths (%d left out)\n', height(T), nnz(Pt.kept), nnz(~Pt.kept));
end

%% ------------------------------------------------------------------------
function [P, D] = read_set(root, s, va)
fid = fopen(fullfile(root, s + "path.txt")); c = onCleanup(@() fclose(fid));
if va
    x = textscan(fid, '%s %f %f %f %f %f', 'HeaderLines', 1);
    P = table(string(x{1}), strings(numel(x{1}), 1), x{2}, x{3}, x{4}, x{5}, x{6}, ...
        'VariableNames', {'path', 'site', 'xlat', 'xlon', 'rlat', 'rlon', 'dist'});
else
    x = textscan(fid, '%s %s %f %f %f %f %f', 'HeaderLines', 1);
    P = table(string(x{1}), string(x{2}), x{3}, x{4}, x{5}, x{6}, x{7}, ...
        'VariableNames', {'path', 'site', 'xlat', 'xlon', 'rlat', 'rlon', 'dist'});
end
fid2 = fopen(fullfile(root, s + "data.txt")); c2 = onCleanup(@() fclose(fid2));
if va
    x = textscan(fid2, ['%s %f %s %f %s' repmat(' %f', 1, 7)], 'HeaderLines', 2);
    D = table(string(x{1}), x{2}, string(x{3}), x{4}, string(x{5}), [x{6:12}], ...
        'VariableNames', {'path', 'run', 'siting', 'rcvr', 'rht', 'A'});
else
    x = textscan(fid2, ['%s %f %s %f' repmat(' %f', 1, 7)], 'HeaderLines', 2);
    D = table(string(x{1}), x{2}, string(x{3}), x{4}, [x{5:11}], ...
        'VariableNames', {'path', 'run', 'siting', 'rht', 'A'});
end
end

function fn = profile_name(root, s, pth, site, va)
% Path "R1-005-T3" -> 005r1t3.pfl (o3, c3, or a3 for an open/concealed pair);
% Virginia "T1-0_5-R1" -> 0'5t1r1.pfl
p = split(pth, "-");
nom = replace(p(2), "_", "'");
d = fullfile(root, s + "_pfl");
if va
    cand = lower(nom + p(1) + p(3));
else
    num = extractAfter(p(3), 1);
    switch site
        case "C", cand = lower(nom + p(1) + "c" + num);
        case "A", cand = lower(nom + p(1) + "a" + num);
        otherwise, cand = [lower(nom + p(1) + "o" + num), lower(nom + p(1) + "t" + num)];
    end
end
fn = "";
for c = cand
    f = fullfile(d, c + ".pfl");
    if isfile(f), fn = string(f); return, end
end
end

function prof = make_profile(v, tx, rx, E)
dt = v(end, 1); np = max(10, round(dt / 0.03));
d = linspace(0, dt, np + 1)'; h = interp1(v(:, 1), v(:, 2), d, 'linear');
[arclen, az] = distance(tx(1), tx(2), rx(1), rx(2), E);
[mla, mlo] = reckon(tx(1), tx(2), arclen / 2, az, E);
prof = struct('d_km', d, 'h_m', h, 'g_m', h, 'zone', 2 * ones(size(d)), 'spacing_m', 1000 * dt / np, ...
    'midpoint_deg', [mla mlo], 'distance_km', dt);
end

function [dh, imode] = itm_info(prof, F, tx, rx, va, pars)
% ITM delta h and propagation mode at 50 %, at the frequency nearest 3 GHz
[~, j] = min(abs(F - 3000));
htx = pars(j, 2);
if va, hrx = pars(j, 3); else, hrx = 10; end
pfl = [numel(prof.d_km) - 1; prof.spacing_m; prof.h_m(:)];
c = itm_radio_climate_rev1(prof.midpoint_deg(1), prof.midpoint_deg(2));
if c == 7, c = min(itm_radio_climate_rev1(tx(1), tx(2)), itm_radio_climate_rev1(rx(1), rx(2))); end
n0 = itm_surface_refractivity_rev1(prof.midpoint_deg(1), prof.midpoint_deg(2));
[~, info] = itm_p2p_rev1(htx, hrx, pfl, F(j), 50, climate=c, N_0=n0, polarization=0, validity="off");
dh = info.delta_h_m;
imode = string(info.mode);
end

function x = lon180(x)
x(x > 180) = x(x > 180) - 360;
end

function [h, v] = read_pfl(fn)
% Header: TX and RX latitude and longitude (east, 0 to 360), first point (1 = receiver)
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
