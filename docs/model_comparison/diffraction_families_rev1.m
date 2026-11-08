function diffraction_families_rev1(options)
%DIFFRACTION_FAMILIES_REV1 Synthetic tests that isolate ITM's and P.2001's diffraction geometry.
%   DIFFRACTION_FAMILIES_REV1() runs three experiments from the working
%   paper's plan (ALGORITHM_COMPARISON_PLAN.md, items 20, 21, and 24) with
%   ITM v1.4 (itm_p2p_rev1) and Rec. ITU-R P.2001-6 (p2001_profile_rev1) on
%   the same profiles, at options.Freq (3000 MHz) and 50 % of time, with a
%   30 m transmitting and a 10 m receiving antenna, horizontal polarization.
%   ITM: climate 5, N_0 = 301, ground 25 and 0.02 S/m, validity "off".
%   P.2001: inland (zone 4), maps at the path's location, validity "off".
%   Paths start at 38.5 N, 100.0 W and run due east (central Kansas).
%
%   Item 20, two obstacles: a 30 km path over flat ground 500 m above sea
%   level with two triangular ridges (base 300 m wide) centred at 10 km and
%   20 km, each 0 m to 300 m high in 20 m steps. Shows where ITM's knife edge
%   at each horizon and P.2001's single Bullington edge agree. Two classical
%   multiple-knife-edge references are computed on the same geometry, with
%   the knife-edge loss J(nu) of Rec. ITU-R P.526 (eq. 31), heights on an
%   effective earth of radius options.AeKm (8,500 km): Epstein-Peterson
%   (each edge against the line joining its neighbours) and Deygout (the
%   main edge against the terminals, then each side's edge against the main
%   edge and its terminal).
%     chart_data/fam_two_obstacles.csv
%
%   Item 21, synthetic rough terrain: profiles of filtered Gaussian noise
%   (correlation length options.CorrKm, 2 km) on a 500 m base, scaled so
%   that the interdecile range of heights about a straight-line fit equals
%   a target Δh of 10 m to 1,000 m, at path lengths of 10 km to 150 km,
%   options.Draws (20) draws each. ITM's own Δh is recorded too (it leaves
%   out the ends and corrects for distance, so it differs from the target).
%     chart_data/fam_roughness_runs.csv     one row per profile
%     chart_data/fam_roughness_grid.csv     median, 25th, and 75th
%                                           percentile of ITM minus P.2001
%                                           per (target Δh, length)
%
%   Item 24, evaluation point: ITM computes diffraction at d_3 and d_4,
%   beyond the path, and extends a line back to the path's distance
%   (info.lines). The same construction is applied to P.2001: flat terrain
%   is inserted midway between ITM's two horizon points, at the profile's
%   height there, to lengthen the path to d_3 and to d_4 without moving
%   either terminal's horizon; P.2001's loss above free space at those two
%   lengths gives a line, read at the true distance. Run on the 60 eastern
%   and 60 western links wherever ITM's path is beyond line of sight at
%   its actual horizons and d_3 is longer than the path.
%     chart_data/fam_evaluation_point.csv
%
%   Options: Freq (3000), Draws (20), CorrKm (2), Seed (2108), OutDir,
%   P2001Dir, P452Dir, Items ([20 21 24]).

arguments
    options.Freq (1,1) double = 3000
    options.Draws (1,1) double {mustBeInteger, mustBePositive} = 20
    options.CorrKm (1,1) double = 2
    options.Seed (1,1) double = 2108
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Items (1,:) double = [20 21 24]
    options.AeKm (1,1) double = 8500
end
here = fileparts(mfilename('fullpath'));
wp_setup(options.P2001Dir, options.P452Dir);
f = options.Freq; ghz = f / 1000; htx = 30; hrx = 10; h0 = 500; dx = 0.03;
E = wgs84Ellipsoid('km'); tx0 = [38.5, -100.0];
itmo = {'climate', 5, 'N_0', 301, 'polarization', 0, 'epsilon', 25, 'sigma', 0.02, 'validity', "off"};
p2o = {'Polarization', "horizontal", 'Validity', "off"};
if ~isfolder(options.OutDir), mkdir(options.OutDir); end
run2 = @(dk, hm, ht, hr, tx, rx) both(dk, hm, ht, hr, tx, rx, f, ghz, itmo, p2o);

% ---- item 20: two obstacles ----
if ismember(20, options.Items)
    d = 30; dk = (0:dx:d)'; [la, lo] = reckon(tx0(1), tx0(2), d, 90, E); rx0 = [la, lo];
    H = 0:20:300; rows = {};
    for h1 = H
        for h2 = H
            hm = h0 + ridge(dk, 10, h1) + ridge(dk, 20, h2);
            r = run2(dk, hm, htx, hrx, tx0, rx0);
            [ep, dg] = two_edges([0, h0 + htx], [10, h0 + h1], [20, h0 + h2], [d, h0 + hrx], f, options.AeKm);
            rows(end + 1, :) = {h1, h2, r.itm, r.p2001, r.fs, r.itm_mode, r.dh, r.dl_km, r.ld, r.ldba, r.ldsph, r.ldbs, ep, dg}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'h1_m', 'h2_m', 'itm_db', 'p2001_db', 'fs_db', 'itm_mode', ...
        'itm_delta_h_m', 'itm_d_l_km', 'p2001_ld_db', 'p2001_ldba_db', 'p2001_ldsph_db', 'p2001_ldbs_db', ...
        'epstein_peterson_db', 'deygout_db'}), ...
        fullfile(options.OutDir, 'fam_two_obstacles.csv'));
end

% ---- item 21: synthetic rough terrain ----
if ismember(21, options.Items)
    rs = RandStream('mrg32k3a', 'Seed', options.Seed);
    D = [10 15 20 30 50 75 100 150]; DH = [10 20 50 100 200 500 1000];
    rows = {};
    for d = D
        dk = (0:dx:d)'; n = numel(dk);
        [la, lo] = reckon(tx0(1), tx0(2), d, 90, E); rx0 = [la, lo];
        sig = options.CorrKm / dx;                          % filter width in samples
        k = (-ceil(3 * sig):ceil(3 * sig))'; g = exp(-0.5 * (k / sig).^2); g = g / sum(g);
        for dh = DH
            for j = 1:options.Draws
                z = conv(randn(rs, n + 2 * numel(k), 1), g, 'same');
                z = z(numel(k) + (1:n));
                p = polyfit(dk, z, 1); res = z - polyval(p, dk);
                q = prctile(res, [90 10]);
                hm = h0 + 0.5 * dh + res * dh / (q(1) - q(2));   % interdecile range = dh, kept above 500 m
                r = run2(dk, hm, htx, hrx, tx0, rx0);
                rows(end + 1, :) = {d, dh, j, r.itm, r.p2001, r.fs, r.itm_mode, r.dh, r.dl_km, r.w, r.warn}; %#ok<AGROW>
            end
        end
        fprintf('roughness: %g km done\n', d);
    end
    T = cell2table(rows, 'VariableNames', {'d_km', 'target_delta_h_m', 'draw', 'itm_db', 'p2001_db', 'fs_db', 'itm_mode', ...
        'itm_delta_h_m', 'itm_d_l_km', 'itm_horizon_flag', 'itm_warnings'});
    writetable(T, fullfile(options.OutDir, 'fam_roughness_runs.csv'));
    gap = T.itm_db - T.p2001_db;
    [gi, G] = findgroups(T(:, {'target_delta_h_m', 'd_km'}));
    G.median_gap_db = splitapply(@median, gap, gi);
    G.p25_gap_db = splitapply(@(x) prctile(x, 25), gap, gi);
    G.p75_gap_db = splitapply(@(x) prctile(x, 75), gap, gi);
    G.median_itm_delta_h_m = splitapply(@median, T.itm_delta_h_m, gi);
    G.share_itm_flagged = splitapply(@mean, T.itm_horizon_flag, gi);
    writetable(G, fullfile(options.OutDir, 'fam_roughness_grid.csv'));
end

% ---- item 24: evaluation point ----
if ismember(24, options.Items)
    s = load(fullfile(here, 'figures', 'wp_results_rev1.mat'), 'R');
    Le = s.R.E7.links; Lw = readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string');
    sets = {"East", Le; "West", Lw}; rows = {};
    for gk = 1:2
        L = sets{gk, 2};
        for k = 1:height(L)
            prof = wp_terrain_profile([L.tx_lat(k) L.tx_lon(k)], [L.rx_lat(k) L.rx_lon(k)]);
            dk = prof.d_km(:); hm = prof.h_m(:); d = dk(end);
            ht = L.tx_h_m(k); hr = L.rx_h_m(k);
            tx = [L.tx_lat(k) L.tx_lon(k)]; rx = [L.rx_lat(k) L.rx_lon(k)];
            r0 = run2(dk, hm, ht, hr, tx, rx);
            ln = r0.lines;
            d3 = ln.d_3_m / 1e3; d4 = ln.d_4_m / 1e3; dl1 = r0.dhzn_km(1); dl2 = r0.dhzn_km(2);
            use = (r0.dl_km < d) && (d3 > d);
            ext = NaN(1, 2);
            if use
                xs = 0.5 * (dl1 + (d - dl2));                  % midway between the horizon points
                for m = 1:2
                    dd = [d3 d4]; ins = dd(m) - d;
                    [dk2, hm2] = insert_flat(dk, hm, xs, ins, mean(diff(dk)));
                    [la, lo] = reckon(tx(1), tx(2), dk2(end), azimuth(tx(1), tx(2), rx(1), rx(2), E), E);
                    r = run2(dk2, hm2, ht, hr, tx, [la lo]);
                    ext(m) = r.p2001 - r.fs;
                end
            end
            p_line = NaN;
            if use, p_line = ext(1) + (ext(2) - ext(1)) / (d4 - d3) * (d - d3); end
            rows(end + 1, :) = {sets{gk, 1}, k, d, d3, d4, r0.dl_km, use, r0.itm - r0.fs, r0.p2001 - r0.fs, ext(1), ext(2), ...
                p_line, ln.A_3_db, ln.A_4_db, r0.itm_mode, r0.warn}; %#ok<AGROW>
        end
        fprintf('evaluation point: %s done\n', sets{gk, 1});
    end
    writetable(cell2table(rows, 'VariableNames', {'side', 'link', 'd_km', 'd3_km', 'd4_km', 'itm_d_l_km', 'used', ...
        'itm_excess_db', 'p2001_excess_db', 'p2001_excess_at_d3_db', 'p2001_excess_at_d4_db', 'p2001_line_at_path_db', ...
        'itm_a3_db', 'itm_a4_db', 'itm_mode', 'itm_warnings'}), fullfile(options.OutDir, 'fam_evaluation_point.csv'));
end
end

%% ------------------------------------------------------------------------
function r = both(dk, hm, ht, hr, tx, rx, f, ghz, itmo, p2o)
n = numel(dk) - 1;
pfl = [n; 1000 * dk(end) / n; hm(:)];
[L, info] = itm_p2p_rev1(ht, hr, pfl, f, 50, itmo{:});
o = p2001_profile_rev1(dk(:), hm(:), 4 * ones(n + 1, 1), ghz, 50, tx(1), tx(2), rx(1), rx(2), ht, hr, p2o{:});
r.itm = L; r.p2001 = o.Lb; r.fs = info.A_fs_db; r.itm_mode = info.mode; r.dh = info.delta_h_m;
r.dhzn_km = info.d_hzn_m / 1e3; r.dl_km = sum(info.d_hzn_m) / 1e3; r.lines = info.lines;
r.ld = o.Ld; r.ldba = o.Ldba; r.ldsph = o.Ldsph; r.ldbs = o.Ldbs;
r.warn = double(max(info.warnings(:)));
r.w = double(bitand(uint32(r.warn), uint32(384)) > 0);
end

function [ep, dg] = two_edges(T, E1, E2, R, f, ae)
% Knife-edge loss above free space for two edges between terminals T and R.
% Points are [distance km, height m]; heights are raised by the earth bulge
% d(D - d)/(2 ae) relative to the chord, so straight lines can be used.
lam = 299.792458 / f;                          % m
D = R(1);
b = @(p) [p(1), p(2) + 1000 * p(1) * (D - p(1)) / (2 * ae)];
T = b(T); E1 = b(E1); E2 = b(E2); R = b(R);
nu = @(A, P, B) nuf(A, P, B, lam);
ep = J(nu(T, E1, E2)) + J(nu(E1, E2, R));
n1 = nu(T, E1, R); n2 = nu(T, E2, R);
if n1 >= n2
    dg = J(n1) + J(nu(E1, E2, R));
else
    dg = J(n2) + J(nu(T, E1, E2));
end
end

function v = nuf(A, P, B, lam)
% Fresnel-Kirchhoff parameter of point P against the line A-B (km, m)
d1 = 1000 * (P(1) - A(1)); d2 = 1000 * (B(1) - P(1));
h = P(2) - (A(2) + (B(2) - A(2)) * d1 / (d1 + d2));
v = h * sqrt(2 / lam * (1 / d1 + 1 / d2));
end

function L = J(v)
% Rec. ITU-R P.526, eq. (31); zero for v <= -0.78
L = 0;
if v > -0.78, L = 6.9 + 20 * log10(sqrt((v - 0.1)^2 + 1) + v - 0.1); end
end

function z = ridge(dk, c, h)
z = max(0, h * (1 - abs(dk - c) / 0.15));     % triangle, 300 m base
end

function [dk2, hm2] = insert_flat(dk, hm, xs, ins, step)
% Insert ins km of flat terrain at distance xs, at the profile's height there
i = find(dk <= xs, 1, 'last');
m = max(1, round(ins / step));
st = ins / m;
hm2 = [hm(1:i); repmat(hm(i), m, 1); hm(i + 1:end)];
dk2 = [dk(1:i); dk(i) + st * (1:m)'; dk(i + 1:end) + ins];
% re-space evenly (both models need equal spacing)
n = numel(dk2) - 1;
x = linspace(0, dk2(end), n + 1)';
hm2 = interp1(dk2, hm2, x, 'linear');
dk2 = x;
end
