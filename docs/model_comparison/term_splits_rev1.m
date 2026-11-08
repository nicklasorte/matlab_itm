function term_splits_rev1(options)
%TERM_SPLITS_REV1 ITM's and P.2001's diffraction and ducting terms side by side, and P.2001's Monte Carlo combination.
%   TERM_SPLITS_REV1() runs plan items 9, 10, 11, 16, and 25 of the working
%   paper (ALGORITHM_COMPARISON_PLAN.md) at options.Freq (3000 MHz):
%
%   Item 9, smooth-earth diffraction. Flat profiles 500 m above sea level in
%   central Kansas (38.5 N, 100.0 W, due east), 40 km to 300 km, 30 m and
%   10 m antennas, both polarizations. ITM's smooth-earth term A_se at the
%   path's distance (wp_itm_terms, ITM's three-radius method with the
%   horizons ITM finds) against P.2001's spherical-earth loss L_dsph
%   (Attachment A.2, A.3), and each model's full diffraction loss.
%     chart_data/term_smooth_earth.csv
%
%   Items 10 and 11, diffraction terms on real links. The 60 eastern and 60
%   western links, with the settings of wp_run3 (radio climate and N_0 from
%   ITU maps at the midpoint, vertical polarization). For every link ITM
%   classes as diffraction: ITM's terms at the path's distance, w A_se,
%   (1 - w) A_k, and A_fo (and at d_3, where ITM evaluates them), and
%   P.2001's at 50 % of time: the knife-edge loss J(nu) of the Bullington
%   point (L_dbka), its empirical addition L_dba - L_dbka (eq. A.23), and
%   the spherical-earth excess max(L_dsph - L_dbs, 0) (eq. A.1).
%     chart_data/term_diffraction_links.csv
%
%   Item 16, ducting terms. P.2001's anomalous-propagation loss
%   L_ba = A_ac + A_ad + A_at (Attachment D, eq. D.25) on the smooth path at
%   20 km to 700 km, at 0.1 %, 1 %, and 10 % of time, and on the 120 links
%   at 1 %; with ITM's loss for comparison.
%     chart_data/term_ducting_smooth.csv, chart_data/term_ducting_links.csv
%
%   Item 25, Monte Carlo combination. On five paths (smooth earth 50 km,
%   120 km, and 300 km in Kansas; the rough western link of the algorithm
%   comparison; and the over-sea path from Atlantic City, NJ, to Ocean City,
%   MD), P.2001's sub-model distributions L_bm12(p), L_bm3(p), and L_bm4(p)
%   are computed on a dense grid of time percentages and combined two
%   ways: the single-percentage blend of sec. 5.2 (eq. 59), as itu_p2001
%   returns it, and the Monte Carlo method of sec. 5.3 (eq. 60), with
%   options.Draws (200,000) independent uniform time percentages for each
%   sub-model, inverse-CDF sampling on the logit scale, and a power sum.
%     chart_data/term_monte_carlo.csv
%
%   Options: Freq (3000), Draws (200000), Seed (2001), OutDir, P2001Dir,
%   P452Dir, Items ([9 10 16 25]; 10 also writes item 11's data).

arguments
    options.Freq (1,1) double = 3000
    options.Draws (1,1) double = 200000
    options.Seed (1,1) double = 2001
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Items (1,:) double = [9 10 16 25]
end
here = fileparts(mfilename('fullpath'));
wp_setup(options.P2001Dir, options.P452Dir);
f = options.Freq; ghz = f / 1000; h0 = 500; htx = 30; hrx = 10;
E = wgs84Ellipsoid('km'); tx0 = [38.5, -100.0];
pols = ["vertical", "horizontal"];

% ---- item 9: smooth-earth diffraction ----
if ismember(9, options.Items)
    rows = {};
    for d = 40:10:300
        [pfl, dk, hm, rxp] = flat(d, h0, tx0, E);
        for ip = 1:2
            pc = 2 - ip;                                     % ITM: 1 vertical, 0 horizontal
            [~, info] = itm_p2p_rev1(htx, hrx, pfl, f, 50, climate=5, N_0=301, polarization=pc, validity="off");
            t = wp_itm_terms(pfl, f, [htx hrx], 301, info, pc);
            o = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), ghz, 50, tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, ...
                'Polarization', pols(ip), 'Validity', "off");
            rows(end + 1, :) = {d, pols(ip), t.A_se_at_d, t.w_at_d, t.A_d_at_d, info.A_ref_db, o.Ldsph, o.Ld, o.Ldba, ...
                o.Ldbs}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'d_km', 'polarization', 'itm_a_se_db', 'itm_w', 'itm_a_d_at_path_db', ...
        'itm_a_ref_db', 'p2001_ldsph_db', 'p2001_ld_db', 'p2001_ldba_db', 'p2001_ldbs_db'}), ...
        fullfile(options.OutDir, 'term_smooth_earth.csv'));
end

% ---- items 10, 11, and 16 (links): terms on the 120 links ----
links = {};
if any(ismember([10 16], options.Items))
    s = load(fullfile(here, 'figures', 'wp_results_rev1.mat'), 'R');
    links = {"East", s.R.E7.links; "West", readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string')};
end
if ismember(10, options.Items) || ismember(16, options.Items)
    rd = {}; rdu = {};
    for g = 1:size(links, 1)
        L = links{g, 2};
        for k = 1:height(L)
            prof = wp_terrain_profile([L.tx_lat(k) L.tx_lon(k)], [L.rx_lat(k) L.rx_lon(k)]);
            ht = L.tx_h_m(k); hr = L.rx_h_m(k);
            pfl = [numel(prof.d_km) - 1; prof.d_km(end) * 1e3 / (numel(prof.d_km) - 1); prof.h_m(:)];
            c = itm_radio_climate_rev1(prof.mid(1), prof.mid(2));
            if c == 7, c = min(itm_radio_climate_rev1(prof.tx(1), prof.tx(2)), itm_radio_climate_rev1(prof.rx(1), prof.rx(2))); end
            n0 = itm_surface_refractivity_rev1(prof.mid(1), prof.mid(2));
            [Li, info] = itm_p2p_rev1(ht, hr, pfl, f, [1 50], climate=c, N_0=n0, validity="off");
            o = p2001_profile_rev1(prof.d_km(:), prof.h_m(:), prof.zone(:), ghz, [1; 50], prof.tx(1), prof.tx(2), ...
                prof.rx(1), prof.rx(2), ht, hr, 'Validity', "off");
            if ismember(info.mode_code, [4 5 8 9]) && ismember(10, options.Items)
                t = wp_itm_terms(pfl, f, [ht hr], n0, info, 1);
                q = o(2);
                rd(end + 1, :) = {links{g, 1}, k, prof.d_km(end), info.delta_h_m, info.A_ref_db, ...
                    t.w_at_d * t.A_se_at_d, (1 - t.w_at_d) * t.A_k_at_d, t.A_fo, t.A_d_at_d, ...
                    t.w3 * t.A_se3, (1 - t.w3) * t.A_k3, t.A_d3, ...
                    q.Ldbka, q.Ldba - q.Ldbka, max(q.Ldsph - q.Ldbs, 0), q.Ld, q.Lb - q.Lbfs}; %#ok<AGROW>
            end
            if ismember(16, options.Items)
                q = o(1);
                rdu(end + 1, :) = {links{g, 1}, k, prof.d_km(end), Li(1) - info.A_fs_db, q.Lb - q.Lbfs, q.Lbm1 - q.Lbfs, ...
                    q.Lbm2 - q.Lbfs, q.Aac, q.Aad, q.Aat, q.Lba}; %#ok<AGROW>
            end
        end
        fprintf('links %s done\n', links{g, 1});
    end
    if ismember(10, options.Items)
        writetable(cell2table(rd, 'VariableNames', {'side', 'link', 'd_km', 'itm_delta_h_m', 'itm_a_ref_db', ...
            'itm_wse_path_db', 'itm_wk_path_db', 'itm_afo_db', 'itm_ad_path_db', 'itm_wse_d3_db', 'itm_wk_d3_db', 'itm_ad_d3_db', ...
            'p2001_knife_db', 'p2001_empirical_db', 'p2001_sph_excess_db', 'p2001_ld_db', 'p2001_excess_db'}), ...
            fullfile(options.OutDir, 'term_diffraction_links.csv'));
    end
    if ismember(16, options.Items)
        writetable(cell2table(rdu, 'VariableNames', {'side', 'link', 'd_km', 'itm_excess_1_db', 'p2001_excess_1_db', ...
            'p2001_lbm1_excess_1_db', 'p2001_lbm2_excess_1_db', 'aac_db', 'aad_db', 'aat_db', 'lba_db'}), ...
            fullfile(options.OutDir, 'term_ducting_links.csv'));
    end
end

% ---- item 16 (smooth): ducting terms against distance ----
if ismember(16, options.Items)
    rows = {}; P = [0.1 1 10];
    for d = unique([20:10:100, 125:25:700])
        [pfl, dk, hm, rxp] = flat(d, h0, tx0, E);
        Li = itm_p2p_rev1(htx, hrx, pfl, f, P, climate=5, N_0=301, polarization=0, validity="off");
        o = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), ghz, P(:), tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, ...
            'Polarization', "horizontal", 'Validity', "off");
        for j = 1:numel(P)
            q = o(j);
            rows(end + 1, :) = {d, P(j), q.Lbfs, Li(j) - q.Lbfs, q.Lb - q.Lbfs, q.Lbm1 - q.Lbfs, q.Lbm2 - q.Lbfs, ...
                q.Lbm3 - q.Lbfs, q.Aac, q.Aad, q.Aat}; %#ok<AGROW>
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'d_km', 'time_pct', 'fs_db', 'itm_excess_db', 'p2001_excess_db', ...
        'lbm1_excess_db', 'lbm2_excess_db', 'lbm3_excess_db', 'aac_db', 'aad_db', 'aat_db'}), ...
        fullfile(options.OutDir, 'term_ducting_smooth.csv'));
end

% ---- item 25: Monte Carlo combination ----
if ismember(25, options.Items)
    rs = RandStream('mrg32k3a', 'Seed', options.Seed);
    pg = p2001_time_grid_rev1(0.001);
    paths = {};
    for d = [50 120 300]
        [~, dk, hm, rxp] = flat(d, h0, tx0, E);
        paths(end + 1, :) = {sprintf('Smooth earth, %d km', d), dk, hm, 4 * ones(size(dk)), tx0, rxp, htx, hrx}; %#ok<AGROW>
    end
    A = readtable(fullfile(options.OutDir, 'alg_itm_anatomy.csv'), 'TextType', 'string');
    W = readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string');
    ok = bitand(uint32(W.itm_warnings), uint32(384)) == 0;
    W = W(ok & W.itm_class == "Diffraction" & W.length_km > 40 & W.length_km < 100, :);
    [~, iw] = max(W.itm_50 - W.p2001_50);
    pr = wp_terrain_profile([W.tx_lat(iw) W.tx_lon(iw)], [W.rx_lat(iw) W.rx_lon(iw)]);
    paths(end + 1, :) = {char(A.path(find(startsWith(A.path, "rough"), 1))), pr.d_km(:), pr.h_m(:), pr.zone(:), pr.tx, pr.rx, ...
        W.tx_h_m(iw), W.rx_h_m(iw)};
    ps = wp_terrain_profile([39.36 -74.42], [38.34 -75.08]);
    paths(end + 1, :) = {'Over sea, Atlantic City to Ocean City', ps.d_km(:), ps.h_m(:), ps.zone(:), ps.tx, ps.rx, 30, 10};
    rows = {};
    x = log10(pg ./ (100 - pg));
    for k = 1:size(paths, 1)
        [nm, dk, hm, z, tx, rx, ht, hr] = paths{k, :};
        o = p2001_profile_rev1(dk, hm, z, ghz, pg(:), tx(1), tx(2), rx(1), rx(2), ht, hr, 'Validity', "off", 'OutputForm', "fields");
        Lm = min(o.Lbm1, o.Lbm2);
        L12 = Lm - 10 * log10(10.^(-0.1 * (o.Lbm1 - Lm)) + 10.^(-0.1 * (o.Lbm2 - Lm)));      % eq. 58
        n = options.Draws;
        u = 100 * rand(rs, n, 3);
        u = min(max(u, pg(1)), pg(end));                    % sampled within the grid's range
        xu = log10(u ./ (100 - u));
        a = interp1(x, L12, xu(:, 1)); b = interp1(x, o.Lbm3, xu(:, 2)); c = interp1(x, o.Lbm4, xu(:, 3));
        m = min([a b c], [], 2);
        Lmc = m - 10 * log10(10.^(-0.1 * (a - m)) + 10.^(-0.1 * (b - m)) + 10.^(-0.1 * (c - m)));   % eq. 60
        for j = 1:numel(pg)
            rows(end + 1, :) = {string(nm), dk(end), pg(j), o.Lb(j), prctile(Lmc, pg(j)), L12(j), o.Lbm3(j), o.Lbm4(j), o.Lbfs}; %#ok<AGROW>
        end
        fprintf('Monte Carlo: %s done\n', nm);
    end
    writetable(cell2table(rows, 'VariableNames', {'path', 'd_km', 'time_pct', 'blend_db', 'monte_carlo_db', 'lbm12_db', ...
        'lbm3_db', 'lbm4_db', 'fs_db'}), fullfile(options.OutDir, 'term_monte_carlo.csv'));
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
