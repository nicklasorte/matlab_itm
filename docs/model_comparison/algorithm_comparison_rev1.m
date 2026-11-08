function algorithm_comparison_rev1(options)
%ALGORITHM_COMPARISON_REV1 ITM and P.2001 mechanism by mechanism: the data behind the algorithm comparison.
%   ALGORITHM_COMPARISON_REV1() runs ITM v1.4 (itm_p2p_rev1, nicklasorte/
%   matlab_itm) and Rec. ITU-R P.2001-6 (p2001_profile_rev1, nicklasorte/
%   itu_p2001) on the same profiles and writes each model's internal terms,
%   so the working paper can show how each one builds its answer. All
%   cases are at options.Freq (3000 MHz), transmitting antenna 30 m and
%   receiving antenna 10 m above ground, horizontal polarization, unless
%   noted. ITM: radio climate 5 (continental temperate), N_0 = 301 N-units,
%   ground permittivity 25 and conductivity 0.02 S/m, validity "off".
%   P.2001: its own maps at the path's location, inland (zone 4).
%
%   Smooth earth: a flat profile 500 m above sea level, starting at
%   38.5 N, 100.0 W (central Kansas) and running due east, so P.2001's maps
%   describe a continental interior.
%
%   Writes to chart_data/:
%     alg_smooth_sweep.csv    smooth earth, 3 km to 700 km, 50 % and 1 % of
%                             time: ITM loss, reference attenuation, mode,
%                             and region boundaries (d_sML, d_x); P.2001
%                             loss, free-space loss, and sub-models Lbm1
%                             (line of sight and diffraction), Lbm2
%                             (anomalous: ducting and layer reflection),
%                             Lbm3 (troposcatter), Lbm4 (sporadic-E), the
%                             diffraction term Ld, and the dominant mechanism
%     alg_los_sweep.csv       smooth earth, 1 km to 40 km at 50 %: ITM and
%                             P.2001 excess loss and a two-ray reference
%                             (direct plus ground-reflected ray over flat
%                             earth, Fresnel reflection coefficient for the
%                             same ground and polarization)
%     alg_itm_anatomy.csv     for two paths (smooth earth 120 km; a rough
%                             western link), ITM's construction lines
%                             (diffraction, scatter, line-of-sight fit)
%                             evaluated over distance, with its anchor
%                             points, and both models' value at the path
%     alg_time_sweep.csv      the same two paths, 0.01 % to 99 % of time:
%                             ITM loss and P.2001 loss and sub-models
%     alg_constants.csv       effective earth radius and other refraction
%                             inputs each model uses on the smooth path
%     alg_mechanism_links.csv the 60 eastern and 60 western links at 1 % and
%                             50 %: ITM's mode and P.2001's dominant
%                             mechanism
%
%   Options: Freq (3000), OutDir, P2001Dir, P452Dir, Links (true: also the
%   120 links, which needs their terrain tiles).

arguments
    options.Freq (1,1) double = 3000
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Links (1,1) logical = true
end
here = fileparts(mfilename('fullpath'));
wp_setup(options.P2001Dir, options.P452Dir);
f = options.Freq; ghz = f / 1000;
htx = 30; hrx = 10; h0 = 500;
E = wgs84Ellipsoid('km');
tx0 = [38.5, -100.0];
itmo = {'climate', 5, 'N_0', 301, 'polarization', 0, 'epsilon', 25, 'sigma', 0.02, 'validity', "off"};
p2o = {'Polarization', "horizontal", 'Validity', "off"};
if ~isfolder(options.OutDir), mkdir(options.OutDir); end

% ---- 1. smooth-earth sweep, 3 km to 700 km ----
D = unique([logspace(log10(3), log10(700), 90), 120]);
P = [1 50];
rows = {};
for d = D
    [pfl, dk, hm, rxp] = flat(d, h0, tx0, E);
    [L, info] = itm_p2p_rev1(htx, hrx, pfl, f, P, itmo{:});
    o = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), ghz, P(:), tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, p2o{:});
    for k = 1:numel(P)
        q = o(k);
        rows(end + 1, :) = {d, P(k), L(k), info.A_fs_db, info.A_ref_db, info.mode, info.lines.d_sML_m / 1e3, ...
            info.lines.d_x_m / 1e3, q.Lb, q.Lbfs, q.Lbm1, q.Lbm2, q.Lbm3, q.Lbm4, q.Ld, mech(q)}; %#ok<AGROW>
    end
end
S = cell2table(rows, 'VariableNames', {'d_km', 'time_pct', 'itm_lb_db', 'itm_fs_db', 'itm_aref_db', 'itm_mode', ...
    'itm_d_sml_km', 'itm_d_x_km', 'p2001_lb_db', 'p2001_fs_db', 'p2001_lbm1_db', 'p2001_lbm2_db', 'p2001_lbm3_db', ...
    'p2001_lbm4_db', 'p2001_ld_db', 'p2001_mech'});
writetable(S, fullfile(options.OutDir, 'alg_smooth_sweep.csv'));

% ---- 2. line of sight, 1 km to 40 km ----
rows = {};
eps_r = 25; sig = 0.02; lam = 299.792458 / f;
epc = eps_r - 1i * 60 * lam * sig;
for d = linspace(1, 40, 157)
    [pfl, dk, hm, rxp] = flat(d, h0, tx0, E);
    [L, info] = itm_p2p_rev1(htx, hrx, pfl, f, 50, itmo{:});
    o = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), ghz, 50, tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, p2o{:});
    % two-ray over flat earth, horizontal polarization
    dm = d * 1e3;
    r1 = hypot(dm, htx - hrx); r2 = hypot(dm, htx + hrx);
    sp = (htx + hrx) / r2;
    R = (sp - sqrt(epc - (1 - sp^2))) / (sp + sqrt(epc - (1 - sp^2)));
    e = 1 / r1 * exp(-1i * 2 * pi * r1 / lam) + R / r2 * exp(-1i * 2 * pi * r2 / lam);
    tworay = -20 * log10(abs(e) * r1);
    rows(end + 1, :) = {d, L - info.A_fs_db, o.Lb - o.Lbfs, tworay, info.mode, o.FlagLos50}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'d_km', 'itm_excess_db', 'p2001_excess_db', 'tworay_excess_db', 'itm_mode', 'p2001_los50'});
writetable(T, fullfile(options.OutDir, 'alg_los_sweep.csv'));

% ---- 3. ITM anatomy and 4. time sweep on two paths ----
paths = struct('name', {"smooth earth, 120 km", "rough western link"}, 'pfl', {[], []}, 'prof', {[], []});
[paths(1).pfl, dk, hm, rxp] = flat(120, h0, tx0, E);
paths(1).prof = struct('d_km', dk, 'h_m', hm, 'tx', tx0, 'rx', rxp);
W = readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string');
% a diffraction link of 40 km to 100 km that ITM doesn't flag for a horizon
% angle over 200 mrad (warning bits 0x0080 and 0x0100), with the largest gap
ok = bitand(uint32(W.itm_warnings), uint32(384)) == 0;
W = W(ok & W.itm_class == "Diffraction" & W.length_km > 40 & W.length_km < 100, :);
[~, iw] = max(W.itm_50 - W.p2001_50);
pr = wp_terrain_profile([W.tx_lat(iw) W.tx_lon(iw)], [W.rx_lat(iw) W.rx_lon(iw)]);
paths(2).pfl = [numel(pr.d_km) - 1; 1000 * pr.d_km(end) / (numel(pr.d_km) - 1); pr.h_m(:)];
paths(2).prof = struct('d_km', pr.d_km(:), 'h_m', pr.h_m(:), 'tx', [W.tx_lat(iw) W.tx_lon(iw)], 'rx', [W.rx_lat(iw) W.rx_lon(iw)]);
paths(2).name = "rough western link (" + W.region(iw) + ", " + sprintf('%.0f km', pr.d_km(end)) + ")";
hts = [htx, W.tx_h_m(iw)]; hrs = [hrx, W.rx_h_m(iw)];
an = {}; tm = {};
Pt = [0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 20 30 40 50 60 70 80 90 95 98 99];
for k = 1:2
    pf = paths(k).pfl; pp = paths(k).prof;
    [L, info] = itm_p2p_rev1(hts(k), hrs(k), pf, f, Pt, itmo{:});
    o = p2001_profile_rev1(pp.d_km, pp.h_m, 4 * ones(size(pp.d_km)), ghz, Pt(:), pp.tx(1), pp.tx(2), pp.rx(1), pp.rx(2), ...
        hts(k), hrs(k), p2o{:});
    for j = 1:numel(Pt)
        tm(end + 1, :) = {paths(k).name, Pt(j), L(j), info.A_fs_db, o(j).Lb, o(j).Lbfs, o(j).Lbm1, o(j).Lbm2, o(j).Lbm3, ...
            o(j).Lbm4, mech(o(j))}; %#ok<AGROW>
    end
    ln = info.lines; dpath = info.d_km;
    i50 = find(Pt == 50);
    dd = linspace(max(1, 0.3 * ln.d_ML_m / 1e3), max(ln.d_6_m, ln.d_4_m) / 1e3 * 1.05, 300);
    for x = dd
        xm = x * 1e3;
        dif = ln.M_d * xm + ln.A_d0_db;
        sca = NaN; if isfinite(ln.M_s), sca = ln.M_s * xm + ln.A_s0_db; end
        los = NaN; if isfinite(ln.A_o_db), los = ln.A_o_db + ln.kHat_1 * xm + ln.kHat_2 * log(xm); end
        an(end + 1, :) = {paths(k).name, "curve", x, dif, sca, los, NaN}; %#ok<AGROW>
    end
    pts = {"d_3", ln.d_3_m, ln.A_3_db; "d_4", ln.d_4_m, ln.A_4_db; "d_5", ln.d_5_m, ln.A_5_db; "d_6", ln.d_6_m, ln.A_6_db; ...
        "d_0", ln.d_0_m, ln.A_0_db; "d_1", ln.d_1_m, ln.A_1_db; "d_sML", ln.d_sML_m, ln.A_sML_db; ...
        "d_ML", ln.d_ML_m, NaN; "d_x", ln.d_x_m, NaN};
    for r = 1:size(pts, 1)
        an(end + 1, :) = {paths(k).name, pts{r, 1}, pts{r, 2} / 1e3, NaN, NaN, NaN, pts{r, 3}}; %#ok<AGROW>
    end
    an(end + 1, :) = {paths(k).name, "itm_at_path", dpath, NaN, NaN, NaN, info.A_ref_db}; %#ok<AGROW>
    an(end + 1, :) = {paths(k).name, "p2001_at_path", dpath, NaN, NaN, NaN, o(i50).Lb - o(i50).Lbfs}; %#ok<AGROW>
    an(end + 1, :) = {paths(k).name, "p2001_ld_at_path", dpath, NaN, NaN, NaN, o(i50).Ld}; %#ok<AGROW>
end
writetable(cell2table(an, 'VariableNames', {'path', 'kind', 'd_km', 'diffraction_line_db', 'scatter_line_db', ...
    'los_fit_db', 'value_db'}), fullfile(options.OutDir, 'alg_itm_anatomy.csv'));
writetable(cell2table(tm, 'VariableNames', {'path', 'time_pct', 'itm_lb_db', 'itm_fs_db', 'p2001_lb_db', 'p2001_fs_db', ...
    'p2001_lbm1_db', 'p2001_lbm2_db', 'p2001_lbm3_db', 'p2001_lbm4_db', 'p2001_mech'}), fullfile(options.OutDir, 'alg_time_sweep.csv'));

% ---- 5. refraction inputs on the 120 km smooth path ----
[pfl, dk, hm, rxp] = flat(120, h0, tx0, E);
[~, info] = itm_p2p_rev1(htx, hrx, pfl, f, 50, itmo{:});
o = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), ghz, [1; 50], tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, p2o{:});
C = table(["ITM"; "ITM"; "P.2001"; "P.2001"; "P.2001"], ...
    ["surface refractivity N_s (N-units)"; "effective earth radius (km)"; "refractivity gradient, lowest 1 km, median (N-units/km)"; ...
     "effective earth radius at 50 % (km)"; "effective earth radius at 1 % (km)"], ...
    [info.N_s; info.lines.a_e_m / 1e3; o(2).Nd1km50; o(2).Reff50; o(1).Reffp], 'VariableNames', {'model', 'quantity', 'value'});
writetable(C, fullfile(options.OutDir, 'alg_constants.csv'));

% ---- 6. mechanism on the 120 links ----
if options.Links
    s = load(fullfile(here, 'figures', 'wp_results_rev1.mat'), 'R');   % the eastern links (make_wp_figures_rev1)
    Le = s.R.E7.links;
    Lw = readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string');
    sets = {"East", Le; "West", Lw};
    rows = {}; pj = [1 50];
    for g = 1:2
        L = sets{g, 2};
        for k = 1:height(L)
            prof = wp_terrain_profile([L.tx_lat(k) L.tx_lon(k)], [L.rx_lat(k) L.rx_lon(k)]);
            r = wp_run3(prof, f, L.tx_h_m(k), L.rx_h_m(k), [1 50]);
            for j = 1:2
                rows(end + 1, :) = {sets{g, 1}, k, string(L.region(k)), pj(j), r.itm.Lb(j), r.p2001.Lb(j), r.itm.mech, ...
                    r.p2001.mech(j)}; %#ok<AGROW>
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'side', 'link', 'region', 'time_pct', 'itm_lb_db', 'p2001_lb_db', ...
        'itm_mode_code', 'p2001_mech'}), fullfile(options.OutDir, 'alg_mechanism_links.csv'));
end
end

%% ------------------------------------------------------------------------
function [pfl, dk, hm, rxp] = flat(d, h0, tx, E)
n = max(10, round(d / 0.03));
dk = linspace(0, d, n + 1)'; hm = h0 * ones(n + 1, 1);
pfl = [n; 1000 * d / n; hm];
[la, lo] = reckon(tx(1), tx(2), d, 90, E);
rxp = [la, lo];
end

function c = mech(q)
% P.2001 dominant mechanism, as p2001_rev1: lowest-loss sub-model
[~, i] = min([q.Lbm1, q.Lbm2, q.Lbm3, q.Lbm4]);
c = i;
if i == 1 && q.FlagLos50 == 1, c = 0; end
end
