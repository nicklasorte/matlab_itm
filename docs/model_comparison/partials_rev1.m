function partials_rev1(options)
%PARTIALS_REV1 Finishes plan items 1, 4, 13, and 28 of the working paper.
%   PARTIALS_REV1() completes the parts of plan items 1, 4, 13, and 28
%   (ALGORITHM_COMPARISON_PLAN.md) that revision 4 had left for later, at
%   options.Freq (3000 MHz). Item 15 needs no new run: it uses the smooth-
%   earth continuity run of implementation_checks_rev1 (check_continuity.csv).
%
%   Item 1, horizons. On the paper's 60 eastern and 60 western links, each
%   terminal's horizon distance and elevation angle from ITM (on its own
%   effective earth) and from P.2001 (on a_e50, sec. 3.7), with ITM's mode
%   and P.2001's line-of-sight flag.
%     chart_data/part_horizons.csv
%
%   Item 4, earth curvature. Smooth 120 km paths (30 m and 10 m antennas)
%   due north from 10 U.S. sites, at an approximate site elevation: ITM's
%   effective earth radius (N_0 from the ITU map at the midpoint, as in the
%   paper) and P.2001's median radius a_e50 and its time-dependent radius a_p
%   at 0.01 % to 50 % of time.
%     chart_data/part_earth_radius.csv
%
%   Item 13, line-of-sight fading. Smooth earth in central Kansas (500 m),
%   1 km to 40 km, 30 m and 10 m antennas, 0.01 % to 99.99 % of time: ITM's
%   loss minus its 50 % value, and P.2001's fade term A_1 and loss minus its
%   50 % value.
%     chart_data/part_los_fade.csv
%
%   Item 28, input sensitivity per equation. On the 120 links at 50 % of
%   time, one input changed at a time:
%     ITM:    N_0 +20 and -20; dry ground (4, 0.001 S/m) instead of 25,
%             0.02 S/m; effective earth radius +5 % and -5 %; profile spacing
%             doubled; transmitter or receiver antenna 1 m higher.
%     P.2001: effective earth radius (a_e50 and a_p) +5 % and -5 %; profile
%             spacing doubled; transmitter or receiver antenna 1 m higher.
%   ("P.2001 has no ground or N_0 input: it reads them from its zone and
%   maps.) The radius changes use temporary copies of the two models with a
%   one-line override (environment variable WP_AE_OVERRIDE_KM), as in
%   implementation_checks_rev1. Each run keeps the terms: for ITM, A_ref
%   and, on links ITM classes as diffraction (mode codes 4, 5, 8, 9) when
%   wp_itm_terms can rebuild A_ref exactly, the knife-edge term
%   A_k, smooth-earth term A_se, weight w, clutter term A_fo, and A_d at d_3;
%   for P.2001, L_bm1, L_d, L_dba, L_dsph, L_dbs, L_bm2, and L_bm3.
%     chart_data/part_sensitivity_terms.csv
%
%   Options: Freq (3000), OutDir, P2001Dir, P452Dir, Items ([1 4 13 28]).

arguments
    options.Freq (1,1) double = 3000
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Items (1,:) double = [1 4 13 28]
end
here = fileparts(mfilename('fullpath'));
itm_root = wp_setup(options.P2001Dir, options.P452Dir);
f = options.Freq; ghz = f / 1000; E = wgs84Ellipsoid('km');

% ---- items 1 and 28: the 120 links ----
if any(ismember([1 28], options.Items))
    s = load(fullfile(here, 'figures', 'wp_results_rev1.mat'), 'R');
    sets = {"East", s.R.E7.links; "West", readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string')};
    if ismember(28, options.Items)
        sw = make_swap_copies(itm_root, which('p2001_profile_rev1'));
        addpath(sw);
        cleanup = onCleanup(@() rmpath(sw)); %#ok<NASGU>
    end
    rh = {}; rt = {};
    for g = 1:2
        L = sets{g, 2};
        for k = 1:height(L)
            prof = wp_terrain_profile([L.tx_lat(k) L.tx_lon(k)], [L.rx_lat(k) L.rx_lon(k)]);
            ht = L.tx_h_m(k); hr = L.rx_h_m(k);
            [b, info, o, n0] = run_link(prof, ht, hr, f, ghz, @itm_p2p_rev1, @p2001_profile_rev1, {});
            if ismember(1, options.Items)
                rh(end + 1, :) = {sets{g, 1}, k, prof.d_km(end), info.mode_code, info.d_hzn_m(1) / 1e3, ...
                    info.d_hzn_m(2) / 1e3, 1e3 * info.theta_hzn_rad(1), 1e3 * info.theta_hzn_rad(2), o.Dlt, o.Dlr, ...
                    o.Thetat, o.Thetar, o.FlagLos50}; %#ok<AGROW>
            end
            if ismember(28, options.Items)
                id = {sets{g, 1}, k, prof.d_km(end), info.mode_code};
                rt = [rt; itm_row(id, "baseline", b.itm, info, prof, ht, hr, f, n0)]; %#ok<AGROW>
                rt = [rt; p2001_row(id, "baseline", o)]; %#ok<AGROW>
                % ITM cases
                cases = {"N_0 +20", {'N_0', n0 + 20}, prof, ht, hr, n0 + 20
                         "N_0 -20", {'N_0', n0 - 20}, prof, ht, hr, n0 - 20
                         "dry ground", {'epsilon', 4, 'sigma', 0.001}, prof, ht, hr, NaN
                         "spacing doubled", {}, coarse(prof), ht, hr, n0
                         "tx antenna +1 m", {}, prof, ht + 1, hr, n0
                         "rx antenna +1 m", {}, prof, ht, hr + 1, n0};
                for q = 1:size(cases, 1)
                    [bq, iq] = run_link(cases{q, 3}, cases{q, 4}, cases{q, 5}, f, ghz, @itm_p2p_rev1, [], cases{q, 2});
                    rt = [rt; itm_row(id, cases{q, 1}, bq.itm, iq, cases{q, 3}, cases{q, 4}, cases{q, 5}, f, cases{q, 6})]; %#ok<AGROW>
                end
                for sc = [1.05 0.95]
                    nm = sprintf("radius %+d %%", round(100 * (sc - 1)));
                    setenv('WP_AE_OVERRIDE_KM', sprintf('%.6f', sc * info.lines.a_e_m / 1e3));
                    [bq, iq] = run_link(prof, ht, hr, f, ghz, @itm_p2p_ae_rev1, [], {});
                    rt = [rt; itm_row(id, nm, bq.itm, iq, prof, ht, hr, f, NaN)]; %#ok<AGROW>
                    setenv('WP_AE_OVERRIDE_KM', sprintf('%.6f', sc * o.Reff50));
                    [~, ~, oq] = run_link(prof, ht, hr, f, ghz, [], @p2001_profile_ae_rev1, {});
                    rt = [rt; p2001_row(id, nm, oq)]; %#ok<AGROW>
                    setenv('WP_AE_OVERRIDE_KM', '');
                end
                pc = {"spacing doubled", coarse(prof), ht, hr; "tx antenna +1 m", prof, ht + 1, hr; ...
                      "rx antenna +1 m", prof, ht, hr + 1};
                for q = 1:size(pc, 1)
                    [~, ~, oq] = run_link(pc{q, 2}, pc{q, 3}, pc{q, 4}, f, ghz, [], @p2001_profile_rev1, {});
                    rt = [rt; p2001_row(id, pc{q, 1}, oq)]; %#ok<AGROW>
                end
            end
        end
        fprintf('links %s done\n', sets{g, 1});
    end
    if ismember(1, options.Items)
        writetable(cell2table(rh, 'VariableNames', {'side', 'link', 'd_km', 'itm_mode_code', 'itm_d_hzn_tx_km', ...
            'itm_d_hzn_rx_km', 'itm_theta_tx_mrad', 'itm_theta_rx_mrad', 'p2001_d_lt_km', 'p2001_d_lr_km', ...
            'p2001_theta_t_mrad', 'p2001_theta_r_mrad', 'p2001_los50'}), fullfile(options.OutDir, 'part_horizons.csv'));
    end
    if ismember(28, options.Items)
        writetable(cell2table(rt, 'VariableNames', {'side', 'link', 'd_km', 'itm_mode_code', 'model', 'case', 'loss_db', ...
            'itm_a_ref_db', 'itm_mode', 'itm_a_k3_db', 'itm_a_se3_db', 'itm_w3', 'itm_a_fo_db', 'itm_a_d3_db', ...
            'p2001_lbm1_db', 'p2001_ld_db', 'p2001_ldba_db', 'p2001_ldsph_db', 'p2001_ldbs_db', 'p2001_lbm2_db', ...
            'p2001_lbm3_db'}), fullfile(options.OutDir, 'part_sensitivity_terms.csv'));
    end
end

% ---- item 4: earth curvature at 10 sites ----
if ismember(4, options.Items)
    S = {"Seattle", 47.61, -122.33, 50; "San Diego", 32.72, -117.16, 50; "Phoenix", 33.45, -112.07, 340;
         "Denver", 39.74, -104.99, 1600; "Central Kansas", 38.50, -100.00, 600; "Dallas", 32.78, -96.80, 150;
         "Chicago", 41.88, -87.63, 180; "Miami", 25.76, -80.19, 5; "Washington", 38.91, -77.04, 50;
         "Boston", 42.36, -71.06, 20};
    P = [0.01 0.1 1 10 50];
    rows = {};
    for i = 1:size(S, 1)
        tx = [S{i, 2}, S{i, 3}]; d = 120;
        n = round(d / 0.1); dk = linspace(0, d, n + 1)'; hm = S{i, 4} * ones(n + 1, 1);
        [la, lo] = reckon(tx(1), tx(2), d, 0, E); [ml, mo] = reckon(tx(1), tx(2), d / 2, 0, E);
        n0 = itm_surface_refractivity_rev1(ml, mo); c = itm_radio_climate_rev1(ml, mo);
        [~, info] = itm_p2p_rev1(30, 10, [n; 1000 * d / n; hm], f, 50, climate=c, N_0=n0, validity="off");
        o = p2001_profile_rev1(dk, hm, 4 * ones(n + 1, 1), ghz, P(:), tx(1), tx(2), la, lo, 30, 10, 'Validity', "off");
        for j = 1:numel(P)
            rows(end + 1, :) = {S{i, 1}, S{i, 2}, S{i, 3}, S{i, 4}, n0, info.N_s, info.lines.a_e_m / 1e3, P(j), ...
                o(j).Reff50, o(j).Reffp}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'site', 'lat', 'lon', 'elev_m', 'itm_n0', 'itm_ns', 'itm_ae_km', ...
        'time_pct', 'p2001_ae50_km', 'p2001_ap_km'}), fullfile(options.OutDir, 'part_earth_radius.csv'));
end

% ---- item 13: line-of-sight fading ----
if ismember(13, options.Items)
    tx0 = [38.5, -100.0]; P = [0.01 0.1 1 10 50 90 99 99.9 99.99];
    rows = {};
    for d = [1 2 5 10 20 30 40]
        n = max(10, round(d / 0.03)); dk = linspace(0, d, n + 1)'; hm = 500 * ones(n + 1, 1);
        [la, lo] = reckon(tx0(1), tx0(2), d, 90, E);
        [Li, info] = itm_p2p_rev1(30, 10, [n; 1000 * d / n; hm], f, P, climate=5, N_0=301, validity="off");
        o = p2001_profile_rev1(dk, hm, 4 * ones(n + 1, 1), ghz, P(:), tx0(1), tx0(2), la, lo, 30, 10, 'Validity', "off");
        i50 = find(P == 50);
        for j = 1:numel(P)
            rows(end + 1, :) = {d, P(j), Li(j), Li(j) - Li(i50), o(j).Lb, o(j).Lb - o(i50).Lb, o(j).A1, o(j).Lbfs, ...
                info.mode, o(j).FlagLos50}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'d_km', 'time_pct', 'itm_db', 'itm_rel_db', 'p2001_db', 'p2001_rel_db', ...
        'p2001_a1_db', 'fs_db', 'itm_mode', 'p2001_los50'}), fullfile(options.OutDir, 'part_los_fade.csv'));
end
end

%% ------------------------------------------------------------------------
function [b, info, o, n0, c] = run_link(prof, ht, hr, f, ghz, itmfun, p2fun, itmopts)
b = struct('itm', NaN, 'p2001', NaN); info = []; o = [];
mid = prof.mid;
c = itm_radio_climate_rev1(mid(1), mid(2));
if c == 7, c = min(itm_radio_climate_rev1(prof.tx(1), prof.tx(2)), itm_radio_climate_rev1(prof.rx(1), prof.rx(2))); end
n0 = itm_surface_refractivity_rev1(mid(1), mid(2));
if ~isempty(itmfun)
    pfl = [numel(prof.d_km) - 1; prof.d_km(end) * 1e3 / (numel(prof.d_km) - 1); prof.h_m(:)];
    args = {'climate', c, 'validity', "off"};
    if ~any(strcmp(itmopts(1:2:end), 'N_0')), args = [args, {'N_0', n0}]; end
    args = [args, itmopts];
    [b.itm, info] = itmfun(ht, hr, pfl, f, 50, args{:});
end
if ~isempty(p2fun)
    o = p2fun(prof.d_km(:), prof.h_m(:), prof.zone(:), ghz, 50, prof.tx(1), prof.tx(2), prof.rx(1), prof.rx(2), ht, hr, ...
        'Validity', "off");
    b.p2001 = o.Lb;
end
end

function r = itm_row(id, name, L, info, prof, ht, hr, f, n0)
t = struct('A_k3', NaN, 'A_se3', NaN, 'w3', NaN, 'A_fo', NaN, 'A_d3', NaN);
if isfinite(n0) && ismember(info.mode_code, [4 5 8 9])
    pfl = [numel(prof.d_km) - 1; prof.d_km(end) * 1e3 / (numel(prof.d_km) - 1); prof.h_m(:)];
    try
        t = wp_itm_terms(pfl, f, [ht hr], n0, info);
    catch
    end
end
r = [id, {"ITM", name, L, info.A_ref_db, info.mode, t.A_k3, t.A_se3, t.w3, t.A_fo, t.A_d3, NaN, NaN, NaN, NaN, NaN, NaN, NaN}];
end

function r = p2001_row(id, name, o)
r = [id, {"P.2001", name, o.Lb, NaN, NaN, NaN, NaN, NaN, NaN, NaN, o.Lbm1, o.Ld, o.Ldba, o.Ldsph, o.Ldbs, o.Lbm2, o.Lbm3}];
end

function p = coarse(prof)
% Same path at twice the profile spacing (heights interpolated)
n = numel(prof.d_km) - 1; m = max(10, floor(n / 2));
p = prof;
p.d_km = linspace(0, prof.d_km(end), m + 1)';
p.h_m = interp1(prof.d_km(:), prof.h_m(:), p.d_km);
p.zone = interp1(prof.d_km(:), prof.zone(:), p.d_km, 'nearest');
end

function d = make_swap_copies(itm_root, p2001_file)
% Temporary copies of the two models with a radius override (see implementation_checks_rev1).
d = fullfile(tempdir, 'wp_partials_ae');
if isfolder(d), rmdir(d, 's'); end
mkdir(d);
mkdir(fullfile(d, 'itm')); copyfile(fullfile(itm_root, 'private'), fullfile(d, 'itm', 'private'));
txt = fileread(fullfile(itm_root, 'itm_p2p_rev1.m'));
write(fullfile(d, 'itm', 'itm_p2p_ae_rev1.m'), strrep(txt, 'function [A_db, info] = itm_p2p_rev1(', ...
    'function [A_db, info] = itm_p2p_ae_rev1('));
core = fullfile(d, 'itm', 'private', 'itm_p2p_core.m');
txt = fileread(core);
key = sprintf('[Z_g, gamma_e, N_s] = initialize_point_to_point(f_mhz, h_sys_m, N_0, ...\n    polarization, epsilon, sigma);');
assert(contains(txt, key), 'wp:partials:itm', 'ITM core changed; update the override insertion point.');
write(core, strrep(txt, key, [key newline 'ov_ = str2double(getenv(''WP_AE_OVERRIDE_KM'')); if isfinite(ov_) && ov_ > 0, gamma_e = 1 / (1e3 * ov_); end']));
src = fileparts(p2001_file);
mkdir(fullfile(d, 'p2001')); copyfile(fullfile(src, 'private'), fullfile(d, 'p2001', 'private'));
txt = fileread(p2001_file);
txt = strrep(txt, 'function out = p2001_profile_rev1(', 'function out = p2001_profile_ae_rev1(');
key = 'Reffp(Cp <= 1e-6) = 1e6;';
assert(contains(txt, key), 'wp:partials:p2001', 'P.2001 code changed; update the override insertion point.');
write(fullfile(d, 'p2001', 'p2001_profile_ae_rev1.m'), strrep(txt, key, [key newline ...
    'ov_ = str2double(getenv(''WP_AE_OVERRIDE_KM'')); if isfinite(ov_) && ov_ > 0, Reff50 = ov_; Cp(:) = 1 / ov_; Reffp(:) = ov_; end']));
d = strjoin({fullfile(d, 'itm'), fullfile(d, 'p2001')}, pathsep);
end

function write(file, txt)
fid = fopen(file, 'w'); fwrite(fid, txt); fclose(fid);
end
