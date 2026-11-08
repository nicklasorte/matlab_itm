function N = paper_numbers_3ghz_rev1(options)
%PAPER_NUMBERS_3GHZ_REV1 Every number quoted in the 3 GHz working paper, plus the summary tables the figures plot.
%   N = PAPER_NUMBERS_3GHZ_REV1() reads the result CSV files (chart_data/,
%   figures/table_*.csv) and writes:
%     figures/numbers_3ghz.json        the numbers the text quotes (the
%                                      build script reads them by key)
%     chart_data/meas_error_by_band.csv     median error at 50 % by band
%     chart_data/meas_error_by_time.csv     mean error by time percentage
%     chart_data/meas_error_by_dh.csv       median error at 50 % by delta h
%     chart_data/meas_enhancement_by_distance.csv  median loss at 50 %
%                                      minus loss at 1 %, by path length
%     chart_data/sensitivity_summary.csv    per case: median change from
%                                      the baseline and median gap to
%                                      P.2001, by ITM mechanism class
%     chart_data/grid_summary.csv      per site and model: exclusion area
%                                      and farthest point at each
%                                      required loss, 50 % of time
%     chart_data/its_phase2_link_errors.csv, its_phase2_error_by_freq.csv,
%       its_phase2_error_by_distance.csv, its_phase2_pairs.csv  ITS Phase 2
%       measurements (when compare_its_phase2_rev1 has run)
%     chart_data/terrain_east_west.csv  the eastern and western link gaps
%       (when western_terrain_rev1 has run)
%   Run it after export_deep_dive_data_rev1, uncertainty_rev1,
%   sensitivity_rev1, and grid_separation_rev1. No model runs.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.DataDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
end
FIG = options.Dir; CD = options.DataDir;
rd = @(f) readtable(fullfile(CD, f), 'TextType', 'string', 'VariableNamingRule', 'preserve');
N = containers.Map();
r1 = @(x) round(x, 1);
CLS = ["Line of sight", "Diffraction", "Troposcatter"];

links = rd('real_terrain_links.csv');
b = rd('real_terrain_by_link.csv');
b = join(b, links(:, {'link', 'region', 'delta_h_m', 'length_km'}));
b.apart = b.itm_50_db - b.p2001_50_db;
F0 = b.freq_mhz(1);
for c = CLS
    q = b(b.itm_class == c, :);
    N("n_" + c) = height(q);
    N("gap_" + c) = r1(median(q.apart));
    N("gap452_" + c) = r1(median(q.itm_50_db - q.p452_50_db));
end
N("los_maxabs") = r1(max(abs(b.apart(b.itm_class == "Line of sight"))));
mm = 0;
for c = CLS
    q = b(b.itm_class == c, :);
    mm = max(mm, abs(median(q.p2001_50_db - q.p452_50_db)));
end
N("p2001_p452_maxmed") = round(mm, 2);

se = rd('deep_smooth_earth.csv'); se = se(se.surface == "land", :);
N("se_maxabs") = r1(max(abs(se.itm_50_db - se.p2001_50_db)));
fs = rd('deep_freq_sweep.csv');
for pth = unique(fs.path)'
    q = fs(fs.path == pth, :); g = q.itm_db - q.p2001_db;
    for f = [100 1000 3162 10000]
        N(sprintf('sweep_%s_%d', pth, f)) = r1(g(q.freq_mhz == f));
    end
    N("sweep_" + pth + "_maxabs") = r1(max(abs(g)));
end

% ---- terrain resolution ----
T = rd('terrain_resolution_by_link.csv'); T.a = T.itm_50_db - T.p2001_50_db;
w30 = T(T.resolution == "30 m", :); w90 = T(T.resolution == "90 m", :); w1k = T(T.resolution == "1 km smoothed", :);
ch = w1k.a - w30.a;
for m = ["itm", "p2001"]
    N("res90_" + m) = round(median(w90.(m + "_50_db") - w30.(m + "_50_db")), 2);
    N("res1k_" + m) = r1(median(w1k.(m + "_50_db") - w30.(m + "_50_db")));
end
N("res_n") = height(w30); N("res_med30") = r1(median(w30.a)); N("res_med1k") = r1(median(w1k.a));
N("res_moved10") = nnz(abs(ch) > 10); N("res_medabs") = r1(median(abs(ch))); N("res_max") = r1(max(abs(ch)));

% ---- diffraction terms and ablation ----
t = readtable(fullfile(FIG, 'table_diffraction_terms.csv'), 'TextType', 'string'); t = t(t.freq_mhz == F0, :);
w = t.w_d3; gd = t.itm_excess_50 - t.p2001_excess_50;
N("nd") = height(t);
N("term_se") = r1(median(w .* t.A_se_d3)); N("term_k") = r1(median((1 - w) .* t.A_k_d3)); N("term_fo") = r1(median(t.A_fo));
N("term_bull") = r1(median(t.Lbulla));
N("term_p452_excess") = r1(median(max(t.Ldsph - t.Lbulls, 0)));
rat = t.itm_excess_50 ./ t.p452_excess_50;
N("ratio") = round(median(rat), 2); N("ratio_lt1") = nnz(rat < 1);
N("w_lt") = r1(median(gd(w < 0.12))); N("w_lt_n") = nnz(w < 0.12);
N("w_ge") = r1(median(gd(w >= 0.12))); N("w_ge_n") = nnz(w >= 0.12);
ab = readtable(fullfile(FIG, 'table_diffraction_ablation.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
ab = ab(ab.freq_mhz == F0, :);
for k = 1:height(ab), N("ab_" + ab.("case")(k)) = r1(ab.median_gap_db(k)); end
dbl = t(t.link == 59, :);
if ~isempty(dbl)
    N("dbl_w") = round(dbl.w_d3, 3); N("dbl_Ase") = r1(dbl.A_se_d3); N("dbl_Ak") = r1(dbl.A_k_d3); N("dbl_Afo") = r1(dbl.A_fo);
    N("dbl_itm_excess") = r1(dbl.itm_excess_50); N("dbl_p452_excess") = r1(dbl.p452_excess_50); N("dbl_p2001_excess") = r1(dbl.p2001_excess_50);
    N("dbl_dh") = r1(dbl.delta_h_m);
end

% ---- radials and the window ----
rad = rd('deep_radials.csv'); rad.g = rad.itm_50_db - rad.p2001_50_db;
for az = unique(rad.azimuth_deg)'
    q = rad(rad.azimuth_deg == az, :);
    N(sprintf('rad%d_max60', az)) = round(max(q.g(q.d_km <= 60)));
    N(sprintf('rad%d_med80', az)) = r1(median(q.g(q.d_km > 80)));
    N(sprintf('rad%d_maxabs80', az)) = r1(max(abs(q.g(q.d_km > 80))));
end
D = readtable(fullfile(FIG, 'table_dbsg3_by_dataset_survey.csv'), 'TextType', 'string');
D = D(D.kept == 1, :); D.apart = D.itm_50 - D.p2001_50;
N("meas_n") = height(D);
N("meas150_n") = nnz(D.d_km > 150); N("meas150_med") = r1(median(D.apart(D.d_km > 150), 'omitnan'));
win = b.delta_h_m > 150 & b.length_km < 150;
N("win_n") = nnz(win); N("win_gt20") = nnz(b.apart(win) > 20); N("win_med") = r1(median(b.apart(win))); N("win_out") = r1(median(b.apart(~win)));
dw = D.itm_delta_h_m > 150 & D.d_km < 150;
N("mwin_n") = nnz(dw); N("mwin_los") = nnz(dw & D.itm_mode_code == 0);
sets = {"", true(height(D), 1); "hi_", D.freq_mhz >= 1000; "lo_", D.freq_mhz < 1000};
for s = 1:3
    q = D(dw & sets{s, 2}, :); bg = q.apart > 10;
    N("mwin_" + sets{s, 1} + "big_n") = nnz(bg); N("mwin_" + sets{s, 1} + "big_paths") = numel(unique(q.path(bg)));
    N("mwin_" + sets{s, 1} + "big_itm") = r1(mean(q.itm_50(bg) - q.meas_50(bg)));
    N("mwin_" + sets{s, 1} + "big_p2001") = r1(mean(q.p2001_50(bg) - q.meas_50(bg)));
end

% ---- time distribution and ducting ----
TT = rd('deep_time_by_link.csv'); TT = TT(TT.freq_mhz == F0, :);
TT.c = classof(TT.itm_mode_code); TT.a = TT.itm_db - TT.p2001_db;
for c = CLS
    for p = [0.001 1 50 99]
        N(sprintf('time_%s_%g', c, p)) = round(median(TT.a(TT.c == c & TT.time_pct == p)));
    end
    q50 = TT(TT.c == c & TT.time_pct == 50, :); q1 = TT(TT.c == c & TT.time_pct == 1, :);
    N("dep_itm_" + c) = r1(median(q50.itm_db - q1.itm_db)); N("dep_p2001_" + c) = r1(median(q50.p2001_db - q1.p2001_db));
end
A = rd('deep_archetype_time.csv'); A = A(A.freq_mhz == F0, :);
sea = A(A.path == "Over-sea coastal", :);
N("sea_len") = round(sea.length_km(1)); N("sea_fs") = r1(32.45 + 20 * log10(F0) + 20 * log10(sea.length_km(1)));
for p = [0.01 1 50]
    for m = ["itm", "p452", "p2001"]
        N(sprintf('sea_%s_%g', m, p)) = r1(sea.(m + "_db")(sea.time_pct == p));
    end
end
N("sea_below_fs") = max(sea.time_pct(sea.p2001_db < N("sea_fs")));
for pth = unique(A.path)'
    q = A(A.path == pth, :);
    N("arch_" + pth + "_itm_drop") = r1(q.itm_db(q.time_pct == 50) - q.itm_db(q.time_pct == 0.01));
    N("arch_" + pth + "_p2001_drop") = r1(q.p2001_db(q.time_pct == 50) - q.p2001_db(q.time_pct == 0.01));
end
cl = rd('deep_itm_climate.csv');
N("clim_min") = r1(min(cl.itm_1_db(cl.("case") == "climate"))); N("clim_max") = r1(max(cl.itm_1_db(cl.("case") == "climate")));
N("n0_range") = r1(range(cl.itm_1_db(cl.("case") == "n0")));
st = rd('deep_smooth_earth_time.csv'); st = st(st.freq_mhz == F0, :);
for surf = ["land", "sea"]
    q = st(st.surface == surf & st.p2001_mech == 2, :);
    [dd, ~, id] = unique(q.d_km);
    N("duct_" + surf) = containers.Map(cellstr(string(dd)), num2cell(accumarray(id, q.time_pct, [], @max)));
end

% ---- measurements: summary tables for the figures ----
bins = ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-3 GHz", "3-6 GHz", "6-10 GHz"];
rows = {};
for bn = bins
    for m = ["itm", "p452", "p2001"]
        e = D.(m + "_50")(D.bin == bn) - D.meas_50(D.bin == bn); e = e(isfinite(e));
        rows(end + 1, :) = {bn, m, numel(e), median(e), mean(e)}; %#ok<AGROW>
    end
end
writetable(cell2table(rows, 'VariableNames', {'band', 'model', 'n', 'median_error_db', 'mean_error_db'}), fullfile(CD, 'meas_error_by_band.csv'));
rows = {};
for p = ["01", "10", "50", "90", "99"]
    for m = ["itm", "p452", "p2001"]
        e = D.(m + "_" + p) - D.("meas_" + p); e = e(isfinite(e));
        rows(end + 1, :) = {str2double(p), m, numel(e), mean(e)}; %#ok<AGROW>
    end
end
writetable(cell2table(rows, 'VariableNames', {'time_pct', 'model', 'n', 'mean_error_db'}), fullfile(CD, 'meas_error_by_time.csv'));
ed = [0 25 50 100 200 400 3000]; rows = {};
for i = 1:numel(ed) - 1
    s = D.itm_delta_h_m >= ed(i) & D.itm_delta_h_m < ed(i + 1);
    for m = ["itm", "p452", "p2001"]
        e = D.(m + "_50")(s) - D.meas_50(s); e = e(isfinite(e));
        rows(end + 1, :) = {ed(i), ed(i + 1), sqrt(max(ed(i), 10) * ed(i + 1)), m, numel(e), median(e)}; %#ok<AGROW>
    end
end
writetable(cell2table(rows, 'VariableNames', {'dh_low_m', 'dh_high_m', 'dh_mid_m', 'model', 'n', 'median_error_db'}), fullfile(CD, 'meas_error_by_dh.csv'));
ed = [0 60 120 200 300 450 900]; rows = {};
for i = 1:numel(ed) - 1
    s = D.d_km >= ed(i) & D.d_km < ed(i + 1);
    for k = ["meas", "itm", "p452", "p2001"]
        v = D.(k + "_50")(s) - D.(k + "_01")(s); v = v(isfinite(v));
        rows(end + 1, :) = {ed(i), ed(i + 1), sqrt(max(ed(i), 20) * ed(i + 1)), k, numel(v), median(v)}; %#ok<AGROW>
    end
end
writetable(cell2table(rows, 'VariableNames', {'d_low_km', 'd_high_km', 'd_mid_km', 'series', 'n', 'median_db'}), fullfile(CD, 'meas_enhancement_by_distance.csv'));
for k = ["meas", "itm", "p452", "p2001"]
    N("enh_" + k) = r1(median(D.(k + "_50") - D.(k + "_01"), 'omitnan'));
end

% ---- uncertainty ----
U = rd('uncertainty_summary.csv');
for i = 1:height(U)
    key = "u_" + replace(U.quantity(i), " ", "_");
    N(key) = [r1(U.median_db(i)), r1(U.ci_low_db(i)), r1(U.ci_high_db(i))];
    if isfinite(U.share_over_20db(i))
        N(key + "_share") = round(100 * [U.share_over_20db(i), U.share_low(i), U.share_high(i)]);
    end
end
Sp = rd('uncertainty_split.csv');
N("u_split") = [Sp.split_w, Sp.split_low, Sp.split_high]; N("u_bc") = round(Sp.bimodality_coefficient, 2);
N("u_bic") = [r1(Sp.bic_one), r1(Sp.bic_two)]; N("u_mix") = [r1(Sp.mixture_mean_low_db), r1(Sp.mixture_mean_high_db)];
UM = rd('uncertainty_measurements.csv');
for i = 1:height(UM)
    N("um_" + UM.group(i) + "_" + UM.model(i)) = [r1(UM.mean_error_db(i)), r1(UM.ci_low_db(i)), r1(UM.ci_high_db(i)), UM.paths(i)];
end

% ---- sensitivity ----
S = rd('sensitivity_links.csv');
S = join(S, b(:, {'link', 'itm_class'}));
base = struct('itm', S(S.model == "itm" & S.("case") == "baseline", :), 'p452', S(S.model == "p452" & S.("case") == "baseline", :), ...
    'p2001', S(S.model == "p2001" & S.("case") == "baseline", :));
rows = {};
for m = ["itm", "p452", "p2001"]
    cases = unique(S.("case")(S.model == m), 'stable');
    for c = cases'
        q = S(S.model == m & S.("case") == c, :);
        [~, ia, ib] = intersect(q.link, base.(m).link); q = q(ia, :); bb = base.(m)(ib, :);
        [~, ja, jb] = intersect(q.link, base.p2001.link); q2 = q(ja, :); pp = base.p2001(jb, :);
        for cc = ["All", CLS]
            s1 = cc == "All" | q.itm_class == cc; s2 = cc == "All" | q2.itm_class == cc;
            rows(end + 1, :) = {m, c, cc, nnz(s1), median(q.loss_db(s1) - bb.loss_db(s1)), max(abs(q.loss_db(s1) - bb.loss_db(s1))), ...
                median(q2.loss_db(s2) - pp.loss_db(s2))}; %#ok<AGROW>
        end
    end
end
SS = cell2table(rows, 'VariableNames', {'model', 'case', 'itm_class', 'links', 'median_change_db', 'max_abs_change_db', 'median_gap_to_p2001_db'});
writetable(SS, fullfile(CD, 'sensitivity_summary.csv'));
for i = 1:height(SS)
    N(sprintf('sens_%s_%s_%s', SS.model(i), SS.("case")(i), SS.itm_class(i))) = [r1(SS.median_change_db(i)), r1(SS.median_gap_to_p2001_db(i)), r1(SS.max_abs_change_db(i))];
end
sb = SS(SS.model == "itm" & SS.("case") == "baseline" & SS.itm_class == "Diffraction", :);
N("sens_base_gap_dif") = r1(sb.median_gap_to_p2001_db);
q = SS(SS.model == "itm" & SS.itm_class == "Diffraction" & SS.("case") ~= "baseline", :);
[~, i] = max(abs(q.median_gap_to_p2001_db - sb.median_gap_to_p2001_db));
N("sens_most_case") = q.("case")(i); N("sens_most_gap") = r1(q.median_gap_to_p2001_db(i));
N("sens_gap_range") = [r1(min(q.median_gap_to_p2001_db)), r1(max(q.median_gap_to_p2001_db))];

% ---- grid ----
rows = {};
for site = ["dc", "la"]
    tag = "_150km_2p5km";                          % the main grid: 300 km by 300 km at 2.5 km
    if ~isfile(fullfile(CD, "grid_" + site + tag + "_exclusion.csv")), tag = ""; end
    f = fullfile(CD, "grid_" + site + tag + "_exclusion.csv");
    if ~isfile(f), continue, end
    E = readtable(f, 'TextType', 'string'); E = E(E.time_pct == 50, :);
    G = readtable(fullfile(CD, "grid_" + site + tag + ".csv"));
    N("grid_" + site + "_tag") = tag;
    ga = G.itm_50 - G.p2001_50;
    N("grid_" + site + "_gap_median") = r1(median(ga)); N("grid_" + site + "_gap_p90") = r1(prctile(ga, 90));
    N("grid_" + site + "_gap_max") = r1(max(ga)); N("grid_" + site + "_n") = height(G);
    N("grid_" + site + "_share_gt20") = round(100 * mean(ga > 20));
    N("grid_" + site + "_p452_p2001_maxabs") = round(max(abs(G.p452_50 - G.p2001_50)), 2);
    for L = [140 150 160]
        for m = ["itm", "p452", "p2001"]
            e = E(E.model == m & E.required_loss_db == L, :);
            N(sprintf('grid_%s_%s_%d_area', site, m, L)) = e.area_km2; N(sprintf('grid_%s_%s_%d_dmax', site, m, L)) = r1(e.max_distance_km);
            rows(end + 1, :) = {site, m, L, e.area_km2, e.max_distance_km}; %#ok<AGROW>
        end
    end
end
writetable(cell2table(rows, 'VariableNames', {'site', 'model', 'required_loss_db', 'area_km2', 'max_distance_km'}), fullfile(CD, 'grid_summary.csv'));
fc = fullfile(CD, 'grid_convergence.csv');
if isfile(fc)
    Cv = readtable(fc, 'TextType', 'string');
    for i = 1:height(Cv)
        if ~ismember(Cv.required_loss_db(i), [150 160 170 180]), continue, end
        N(sprintf('conv_%s_%s_%d_%g_%g', Cv.site(i), Cv.model(i), Cv.required_loss_db(i), Cv.half_width_km(i), Cv.step_km(i))) = ...
            [Cv.area_km2(i), Cv.edge_points(i), r1(Cv.max_distance_km(i))];
    end
    % largest change in area between the 2.5 km and 1 km steps on the 100 km grid, 150 to 170 dB
    q = Cv(Cv.half_width_km == 50 & ismember(Cv.required_loss_db, [150 160 170]), :);
    a1 = q(q.step_km == 1, :); a25 = q(q.step_km == 2.5, :); a5 = q(q.step_km == 5, :);
    N("conv_step25_maxpct") = round(100 * max(abs(a25.area_km2 ./ a1.area_km2 - 1)));
    N("conv_step5_maxpct") = round(100 * max(abs(a5.area_km2 ./ a1.area_km2 - 1)));
end

% ---- ITU-R VHF/UHF point-to-area measurements (compare_dbsg3_area_rev1) ----
fa = fullfile(FIG, 'table_dbsg3_area.csv');
if isfile(fa)
    Ar = readtable(fa, 'TextType', 'string');
    labs = ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-2 GHz", "2-3 GHz", "All"];
    rows = {};
    for bn = labs
        s = Ar.bin == bn | bn == "All";
        for m = ["itm", "p452", "p2001"]
            e = Ar.(m + "_50")(s) - Ar.meas_50(s); e = e(isfinite(e));
            if isempty(e), continue, end
            rows(end + 1, :) = {bn, m, numel(e), mean(e), rms(e), median(e)}; %#ok<AGROW>
            N(sprintf('area_%s_%s', bn, m)) = [r1(mean(e)), r1(rms(e)), numel(e)];
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'band', 'model', 'n', 'mean_error_db', 'rms_error_db', 'median_error_db'}), ...
        fullfile(CD, 'meas_area_error_by_band.csv'));
    N("area_n") = height(Ar); N("area_experiments") = numel(unique(Ar.file));
    N("area_d_range") = [r1(min(Ar.d_km)), r1(max(Ar.d_km))];
    N("area_f_range") = [min(Ar.freq_mhz), max(Ar.freq_mhz)];
end

% ---- ITS Phase 2 irregular-terrain measurements (compare_its_phase2_rev1) ----
fi = fullfile(CD, 'its_phase2_results.csv');
if isfile(fi)
    N = its_numbers(N, readtable(fi, 'TextType', 'string'), rd('its_phase2_paths.csv'), CD, r1);
end

% ---- ITS Phase 1 and low-antenna spot measurements (compare_its_spot_rev1) ----
fs2 = fullfile(CD, 'its_spot_results.csv');
if isfile(fs2)
    N = spot_numbers(N, readtable(fs2, 'TextType', 'string'), CD, r1);
end

% ---- P.2108 clutter on the grids (grid_clutter_rev1) ----
fg = fullfile(CD, 'grid_clutter.csv');
if isfile(fg)
    Gc = readtable(fg, 'TextType', 'string');
    for i = 1:height(Gc)
        if ~ismember(Gc.required_loss_db(i), [150 160 170 180 190 200]) || Gc.clutter(i) == "none", continue, end
        N(sprintf('gclut_%s_%s_%s_%d', Gc.site(i), Gc.model(i), Gc.clutter(i), Gc.required_loss_db(i))) = ...
            [Gc.area_km2(i), r1(Gc.max_distance_km(i))];
    end
    N("gclut_loss") = r1(unique(Gc.median_clutter_loss_db(Gc.clutter == "rx_p50")));
    N("gclut_loss_p10") = r1(unique(Gc.median_clutter_loss_db(Gc.clutter == "rx_p10")));
    N("gclut_loss_p90") = r1(unique(Gc.median_clutter_loss_db(Gc.clutter == "rx_p90")));
end

% ---- algorithm comparison (algorithm_comparison_rev1) ----
if isfile(fullfile(CD, 'alg_smooth_sweep.csv'))
    N = alg_numbers(N, CD, r1);
end

% ---- synthetic diffraction families (diffraction_families_rev1) ----
if isfile(fullfile(CD, 'fam_two_obstacles.csv'))
    N = fam_numbers(N, CD, r1);
end

% ---- term splits and Monte Carlo combination (term_splits_rev1) ----
if isfile(fullfile(CD, 'term_smooth_earth.csv'))
    N = term_numbers(N, CD, r1);
end

% ---- western terrain sample (western_terrain_rev1) ----
fw = fullfile(CD, 'western_links.csv');
if isfile(fw)
    N = west_numbers(N, rd('western_links.csv'), b, FIG, CD, r1, CLS);
end

% ---- smooth-earth distance to threshold ----
th = readtable(fullfile(FIG, 'table_distance_to_threshold.csv'));
N("thr_maxdiff_land") = max(abs([th.land_itm_km - th.land_p2001_km; th.land_itm_km - th.land_p452_km]));

fid = fopen(fullfile(FIG, 'numbers_3ghz.json'), 'w');
fprintf(fid, '%s', jsonencode(N, 'PrettyPrint', true));
fclose(fid);
fprintf('wrote %d numbers to numbers_3ghz.json\n', N.Count);
end

function N = its_numbers(N, T, Pt, CD, r1)
% ITS Phase 2: link-level errors (median over each link's receiver heights),
% summaries by frequency and distance, censored results, and open versus
% concealed pairs. Error = model minus measured basic transmission loss.
M = ["itm", "p452", "p2001"];
T.group = "van" + string(T.rcvr) + "-hi";             % Virginia: receiver van and height
T.group(T.rcvr > 0 & T.hrx_m <= 2) = "van" + string(T.rcvr(T.rcvr > 0 & T.hrx_m <= 2)) + "-lo";
T.group(T.rcvr == 0) = "h3-13";                     % Colorado: heights 3 m to 13 m (15 m)
use = ~(T.rcvr == 0 & T.hrx_m < 3);                % Colorado: heights of 3 m and up
U = T(use & ~T.censored, :);
for m = M, U.("e_" + m) = U.(m + "_50") - U.meas_lb_db; end
[g, K] = findgroups(U(:, {'set', 'path', 'siting', 'freq_mhz', 'group'}));
K.d_km = splitapply(@(x) x(1), U.d_km, g);
K.delta_h_m = splitapply(@(x) x(1), U.delta_h_m, g);
K.itm_region = splitapply(@(x) x(1), U.itm_region, g);
K.n_heights = splitapply(@numel, U.d_km, g);
K.meas_excess_db = splitapply(@median, U.meas_excess_db, g);
K.meas_lb_db = splitapply(@median, U.meas_lb_db, g);
for m = M
    K.(m + "_50") = splitapply(@(x) median(x, 'omitnan'), U.(m + "_50"), g);
    K.("err_" + m) = splitapply(@(x) median(x, 'omitnan'), U.("e_" + m), g);
end
K.near3 = ismember(K.freq_mhz, [1846 2180 4595 4820]);
writetable(K, fullfile(CD, 'its_phase2_link_errors.csv'));

all3 = all(isfinite(K{:, "err_" + M}), 2);
C = K(all3, :);
N("its_paths") = nnz(Pt.kept); N("its_paths_out") = nnz(~Pt.kept);
N("its_rows") = height(T); N("its_links") = height(C);
N("its_d_range") = [r1(min(C.d_km)), r1(max(C.d_km))];
rows = {};
for s = ["All", "R1", "R2", "R3", "VA"]
    for f = unique(C.freq_mhz)'
        q = C((s == "All" | C.set == s) & C.freq_mhz == f, :);
        if isempty(q), continue, end
        for m = M
            e = q.("err_" + m);
            rows(end + 1, :) = {s, f, m, numel(e), mean(e), median(e), rms(e)}; %#ok<AGROW>
        end
    end
end
writetable(cell2table(rows, 'VariableNames', {'set', 'freq_mhz', 'model', 'n', 'mean_error_db', 'median_error_db', 'rms_error_db'}), ...
    fullfile(CD, 'its_phase2_error_by_freq.csv'));
Q = C(C.near3, :);
N("its3_n") = height(Q); N("its3_paths") = numel(unique(Q.set + Q.path + Q.siting));
for m = M
    e = Q.("err_" + m);
    N("its3_" + m) = [r1(mean(e)), r1(median(e)), r1(rms(e))];
    for s = ["R1", "R2", "R3", "VA"]
        e = Q.("err_" + m)(Q.set == s);
        N("its3_" + s + "_" + m) = [r1(mean(e)), r1(median(e)), numel(e)];
    end
end
% Censoring-aware medians: every receiver height near 3 GHz, censored results
% included. A censored result's measured loss is a lower bound, so its error
% (model minus measured) is an upper bound; the Kaplan-Meier estimate of the
% median handles that. NaN when more than half the results are censored
% below the median (the median is then only a bound).
Rw = T(use & ismember(T.freq_mhz, [1846 2180 4595 4820]), :);
[gw, ~] = findgroups(Rw(:, {'set', 'path', 'siting', 'freq_mhz', 'group'}));
cnt = accumarray(gw, 1);
Rw.w = 1 ./ cnt(gw);                               % each link counts once, whatever its number of heights
Rw.colorado_open = Rw.set ~= "VA" & Rw.siting == "O";
Rw.virginia_open = Rw.set == "VA" & Rw.siting == "O" & endsWith(Rw.group, "-hi");
Q.colorado_open = Q.set ~= "VA" & Q.siting == "O";
Q.virginia_open = Q.set == "VA" & Q.siting == "O" & endsWith(Q.group, "-hi");
ed = [0 5 15 50 150]; rows = {};
for grp = ["colorado_open", "virginia_open"]
    for i = 1:numel(ed) - 1
        s = Q.(grp) & Q.d_km >= ed(i) & Q.d_km < ed(i + 1);
        sr = Rw.(grp) & Rw.d_km >= ed(i) & Rw.d_km < ed(i + 1);
        cs = sum(Rw.w(sr) .* Rw.censored(sr)) / sum(Rw.w(sr));
        for m = M
            e = Q.("err_" + m)(s);
            km = km_median(Rw.(m + "_50")(sr) - Rw.meas_lb_db(sr), Rw.censored(sr), Rw.w(sr));
            rows(end + 1, :) = {grp, ed(i), ed(i + 1), m, numel(unique(gw(sr))), median(e), km, cs}; %#ok<AGROW>
            N(sprintf('its3_%s_d%d_%s', grp, ed(i), m)) = [r1(km), r1(median(e)), numel(unique(gw(sr)))];
        end
        N(sprintf('its3_%s_d%d_cens', grp, ed(i))) = round(100 * cs);
    end
    sr = Rw.(grp);
    N("its3_" + grp + "_links") = numel(unique(gw(sr)));
    for m = M
        N("its3_" + grp + "_" + m) = r1(km_median(Rw.(m + "_50")(sr) - Rw.meas_lb_db(sr), Rw.censored(sr), Rw.w(sr)));
    end
end
writetable(cell2table(rows, 'VariableNames', {'group', 'd_low_km', 'd_high_km', 'model', 'links', ...
    'median_error_uncensored_db', 'km_median_error_db', 'censored_share'}), fullfile(CD, 'its_phase2_error_by_distance.csv'));
% by set, censoring-aware
for st = ["R1", "R2", "R3", "VA"]
    sr = Rw.set == st;
    N("its3_" + st + "_cens") = round(100 * sum(Rw.w(sr) .* Rw.censored(sr)) / sum(Rw.w(sr)));
    for m = M
        N("its3_" + st + "_" + m + "_km") = r1(km_median(Rw.(m + "_50")(sr) - Rw.meas_lb_db(sr), Rw.censored(sr), Rw.w(sr)));
    end
end
% Colorado mountains (R2) beyond 15 km: the divergence window in measured data
sr = Rw.set == "R2" & Rw.d_km >= 15;
N("its3_r2far_links") = numel(unique(gw(sr))); N("its3_r2far_cens") = round(100 * sum(Rw.w(sr) .* Rw.censored(sr)) / sum(Rw.w(sr)));
N("its3_r2far_dh") = round(median(Rw.delta_h_m(sr)));
for m = M
    e = Rw.(m + "_50")(sr) - Rw.meas_lb_db(sr); c = logical(Rw.censored(sr));
    N("its3_r2far_" + m) = [r1(median(e(~c))), r1(km_median(e, c, Rw.w(sr)))];
    N("its3_r2far_below_" + m) = round(100 * mean(e(c) < 0));   % censored: model below the bound
end
% the divergence window: rough terrain at 15 to 150 km
w = Q.d_km >= 15 & Q.delta_h_m > 150;
N("its3_win_n") = nnz(w);
wr = Rw.d_km >= 15 & Rw.delta_h_m > 150;
N("its3_win_cens") = round(100 * sum(Rw.w(wr) .* Rw.censored(wr)) / sum(Rw.w(wr)));
for m = M
    N("its3_win_" + m) = [r1(median(Q.("err_" + m)(w))), r1(mean(Q.("err_" + m)(w))), ...
        r1(km_median(Rw.(m + "_50")(wr) - Rw.meas_lb_db(wr), Rw.censored(wr), Rw.w(wr)))];
    N("its3_nowin_" + m) = [r1(median(Q.("err_" + m)(~w))), r1(mean(Q.("err_" + m)(~w)))];
end
% which model is closer, link by link, in the window
N("its3_win_itm_closer") = nnz(abs(Q.err_itm(w)) < abs(Q.err_p2001(w)));
% censored results near 3 GHz: share where the model predicts less loss than the lower bound
Z = T(use & T.censored & ismember(T.freq_mhz, [1846 2180 4595 4820]), :);
N("its3_cens_n") = height(Z); N("its3_cens_links") = numel(unique(Z.set + Z.path + Z.siting + Z.freq_mhz));
for m = M
    N("its3_cens_below_" + m) = round(100 * mean(Z.(m + "_50") < Z.meas_lb_db));
end
% open versus concealed pairs: same path, frequency, and receiver configuration
O = K(K.siting == "O", :); Cn = K(K.siting == "C", :);
[~, io, ic] = intersect(O(:, {'set', 'path', 'freq_mhz', 'group'}), Cn(:, {'set', 'path', 'freq_mhz', 'group'}));
Pp = O(io, {'set', 'path', 'freq_mhz', 'group', 'd_km'});
Pp.meas_c_minus_o_db = Cn.meas_lb_db(ic) - O.meas_lb_db(io);
for m = M, Pp.(m + "_c_minus_o_db") = Cn.(m + "_50")(ic) - O.(m + "_50")(io); end
Pp.band = repmat("3-10 GHz", height(Pp), 1);
Pp.band(Pp.freq_mhz < 3000) = "1-3 GHz"; Pp.band(Pp.freq_mhz < 1000) = "0.3-1 GHz"; Pp.band(Pp.freq_mhz < 300) = "Below 0.3 GHz";
writetable(Pp, fullfile(CD, 'its_phase2_pairs.csv'));
N("its_pairs_n") = height(Pp); N("its_pairs_paths") = numel(unique(Pp.set + Pp.path));
bands = {"lo", Pp.freq_mhz < 1000; "mid", Pp.freq_mhz >= 1000 & Pp.freq_mhz < 3000; "hi", Pp.freq_mhz >= 3000};
for i = 1:3
    q = Pp(bands{i, 2}, :);
    N("its_pairs_" + bands{i, 1}) = [r1(median(q.meas_c_minus_o_db)), r1(median(q.itm_c_minus_o_db)), ...
        r1(median(q.p2001_c_minus_o_db)), height(q)];
end
q = Pp(ismember(Pp.freq_mhz, [1846 2180 4595 4820]), :);
N("its_pairs_3") = [r1(median(q.meas_c_minus_o_db)), r1(prctile(q.meas_c_minus_o_db, 25)), r1(prctile(q.meas_c_minus_o_db, 75)), ...
    r1(median(q.itm_c_minus_o_db)), r1(median(q.p2001_c_minus_o_db)), height(q)];
end

function N = spot_numbers(N, T, CD, r1)
% Per measurement set: censoring-aware median error (each path counts once)
M = ["itm", "p452", "p2001"];
labels = struct('PL', "Colorado plains", 'MT', "Colorado mountains", 'OH', "Ohio hills", ...
    'WY', "Laramie Mountains, Wyoming", 'ID', "Snake River Plateau, Idaho", 'WA', "Columbia Plateau, Washington");
[g, ~] = findgroups(T(:, {'set', 'path', 'terrain', 'freq_mhz'}));
cnt = accumarray(g, 1); T.w = 1 ./ cnt(g);
T.band = repmat("UHF", height(T), 1); T.band(T.freq_mhz < 75) = "50 MHz"; T.band(T.freq_mhz >= 75 & T.freq_mhz < 150) = "100 MHz";
T.band(T.freq_mhz >= 200 & T.freq_mhz < 300) = "230 MHz"; T.band(T.freq_mhz >= 300) = "416 MHz";
rows = {};
for st = unique(T.set, 'stable')'
    for tr = unique(T.terrain(T.set == st), 'stable')'
        for bn = unique(T.band(T.set == st), 'stable')'
            s = T.set == st & T.terrain == tr & T.band == bn;
            cs = sum(T.w(s) .* T.censored(s)) / sum(T.w(s));
            for m = M
                e = T.(m + "_50")(s) - T.meas_lb_db(s);
                km = km_median(e, T.censored(s), T.w(s));
                rows(end + 1, :) = {st, labels.(st), tr, bn, m, numel(unique(T.path(s))), km, cs, median(T.delta_h_m(s))}; %#ok<AGROW>
                N(sprintf('spot_%s_%s_%s_%s', st, tr, replace(bn, " ", ""), m)) = [r1(km), numel(unique(T.path(s)))];
            end
        end
    end
end
S = cell2table(rows, 'VariableNames', {'set', 'label', 'terrain', 'band', 'model', 'paths', 'km_median_error_db', ...
    'censored_share', 'median_delta_h_m'});
writetable(S, fullfile(CD, 'its_spot_summary.csv'));
N("spot_paths") = numel(unique(T.set + T.path)); N("spot_rows") = height(T);
for grp = ["phase1", "lowant"]
    if grp == "phase1", s = ismember(T.set, ["PL", "MT", "OH"]); else, s = ~ismember(T.set, ["PL", "MT", "OH"]) & T.terrain == "dem"; end
    N("spot_" + grp + "_paths") = numel(unique(T.set(s) + T.path(s)));
    for m = M
        N("spot_" + grp + "_" + m) = r1(km_median(T.(m + "_50")(s) - T.meas_lb_db(s), T.censored(s), T.w(s)));
    end
    N("spot_" + grp + "_cens") = round(100 * sum(T.w(s) .* T.censored(s)) / sum(T.w(s)));
end
% the gap between the models on the measured paths, and the site shift
q = T(T.terrain ~= "dem_high", :);
N("spot_gap_med") = r1(median(q.itm_50 - q.p2001_50, 'omitnan'));
a = T(T.terrain == "dem", :); b = T(T.terrain == "dem_high", :);
N("spot_shift_itm") = r1(median(b.itm_50 - a.itm_50, 'omitnan'));
end

function N = alg_numbers(N, CD, r1)
% Numbers for the ITM and P.2001 algorithm comparison
S = readtable(fullfile(CD, 'alg_smooth_sweep.csv'));
for p = [50 1]
    q = S(S.time_pct == p, :);
    g = q.itm_lb_db - q.p2001_lb_db;
    N(sprintf('alg_s%d_maxabs', p)) = r1(max(abs(g)));
    N(sprintf('alg_s%d_gap120', p)) = r1(g(q.d_km == 120));
    k = find(q.p2001_mech == 3, 1); if ~isempty(k), N(sprintf('alg_s%d_tropo_from', p)) = round(q.d_km(k)); end
    k = find(q.p2001_mech == 2, 1); if ~isempty(k), N(sprintf('alg_s%d_anom_from', p)) = round(q.d_km(k)); end
    k = find(q.itm_mode == 3, 1); if ~isempty(k), N(sprintf('alg_s%d_itm_tropo_from', p)) = round(q.d_km(k)); end
    w = q.d_km >= 50 & q.d_km <= 400;
    N(sprintf('alg_s%d_gap_50_400', p)) = [r1(min(g(w))), r1(max(g(w)))];
end
q = S(S.time_pct == 50, :);
N("alg_d_sml") = r1(q.itm_d_sml_km(1)); N("alg_d_x") = r1(max(q.itm_d_x_km));
q1 = S(S.time_pct == 1 & S.d_km == 120, :); q5 = S(S.time_pct == 50 & S.d_km == 120, :);
N("alg_120_itm") = [r1(q5.itm_lb_db), r1(q1.itm_lb_db)]; N("alg_120_p2001") = [r1(q5.p2001_lb_db), r1(q1.p2001_lb_db)];
N("alg_120_lbm") = [r1(q1.p2001_lbm1_db), r1(q1.p2001_lbm2_db), r1(q1.p2001_lbm3_db)];
L = readtable(fullfile(CD, 'alg_los_sweep.csv'));
N("alg_los_tworay") = [r1(min(L.tworay_excess_db(L.d_km >= 2))), r1(max(L.tworay_excess_db(L.d_km >= 2)))];
s = L.d_km <= 20;
N("alg_los_itm_max") = r1(max(abs(L.itm_excess_db(s)))); N("alg_los_p2001_max") = r1(max(abs(L.p2001_excess_db(s))));
k = find(L.p2001_excess_db > 1, 1); N("alg_los_p2001_from") = r1(L.d_km(k));
k = find(L.itm_excess_db > 1, 1); N("alg_los_itm_from") = r1(L.d_km(k));
A = readtable(fullfile(CD, 'alg_itm_anatomy.csv'), 'TextType', 'string');
nm = unique(A.path, 'stable');
for i = 1:numel(nm)
    a = A(A.path == nm(i), :); key = sprintf('alg_an%d_', i);
    g = @(kd, col) a.(col)(a.kind == kd);
    N(key + "name") = nm(i);
    N(key + "d") = r1(g("itm_at_path", 'd_km'));
    N(key + "itm") = r1(g("itm_at_path", 'value_db')); N(key + "p2001") = r1(g("p2001_at_path", 'value_db'));
    N(key + "d3") = [r1(g("d_3", 'd_km')), r1(g("d_3", 'value_db'))]; N(key + "d4") = [r1(g("d_4", 'd_km')), r1(g("d_4", 'value_db'))];
    N(key + "d5") = [r1(g("d_5", 'd_km')), r1(g("d_5", 'value_db'))]; N(key + "d6") = [r1(g("d_6", 'd_km')), r1(g("d_6", 'value_db'))];
    N(key + "dml") = r1(g("d_ML", 'd_km')); N(key + "dsml") = r1(g("d_sML", 'd_km')); N(key + "dx") = r1(g("d_x", 'd_km'));
end
T = readtable(fullfile(CD, 'alg_time_sweep.csv'), 'TextType', 'string');
nm = unique(T.path, 'stable');
for i = 1:numel(nm)
    t = T(T.path == nm(i), :); key = sprintf('alg_t%d_', i);
    v = @(col, p) t.(col)(t.time_pct == p);
    N(key + "itm_spread") = r1(v('itm_lb_db', 99) - v('itm_lb_db', 1));
    N(key + "p2001_spread") = r1(v('p2001_lb_db', 99) - v('p2001_lb_db', 1));
    k = find(t.p2001_mech ~= 2, 1);
    if t.p2001_mech(1) == 2 && ~isempty(k), N(key + "anom_until") = t.time_pct(k - 1); end
end
C = readtable(fullfile(CD, 'alg_constants.csv'), 'TextType', 'string', 'Delimiter', ',');
cv = C{:, end};
N("alg_ns") = r1(cv(1)); N("alg_ae_itm") = round(cv(2)); N("alg_dn50") = r1(cv(3));
N("alg_ae_p2001_50") = round(cv(4)); N("alg_ae_p2001_1") = round(cv(5));
M = readtable(fullfile(CD, 'alg_mechanism_links.csv'), 'TextType', 'string');
for p = [50 1]
    m = M(M.time_pct == p, :);
    tro = ismember(m.itm_mode_code, [6 10]);
    N(sprintf('alg_m%d_itm_tropo', p)) = nnz(tro);
    N(sprintf('alg_m%d_itm_tropo_p2001_diff', p)) = nnz(tro & m.p2001_mech == 1);
    N(sprintf('alg_m%d_p2001_anom', p)) = nnz(m.p2001_mech == 2);
    N(sprintf('alg_m%d_agree', p)) = nnz((m.itm_mode_code == 0 & m.p2001_mech == 0) | ...
        (ismember(m.itm_mode_code, [4 5 8 9]) & m.p2001_mech == 1) | (tro & m.p2001_mech == 3));
    N(sprintf('alg_m%d_n', p)) = height(m);
end
end

function N = fam_numbers(N, CD, r1)
% Plan items 20, 21, and 24
T = readtable(fullfile(CD, 'fam_two_obstacles.csv'));
T.itm = T.itm_db - T.fs_db; T.p = T.p2001_db - T.fs_db;
for h = [100 200 280]
    q = T(T.h1_m == h & T.h2_m == h, :);
    N(sprintf('fam2_eq%d', h)) = [r1(q.itm), r1(q.p), r1(q.epstein_peterson_db), r1(q.deygout_db)];
    q = T(T.h1_m == h & T.h2_m == 0, :);
    N(sprintf('fam2_one%d', h)) = [r1(q.itm), r1(q.p), r1(q.epstein_peterson_db), r1(q.deygout_db)];
end
ref = 0.5 * (T.epstein_peterson_db + T.deygout_db);
N("fam2_n") = height(T);
N("fam2_itm_vs_ref") = [r1(median(T.itm - ref)), r1(prctile(T.itm - ref, 25)), r1(prctile(T.itm - ref, 75))];
N("fam2_p_vs_ref") = [r1(median(T.p - ref)), r1(prctile(T.p - ref, 25)), r1(prctile(T.p - ref, 75))];
N("fam2_p_within10") = round(100 * mean(abs(T.p - ref) <= 10));
N("fam2_itm_within10") = round(100 * mean(abs(T.itm - ref) <= 10));
N("fam2_gap_max") = r1(max(T.itm - T.p));
N("fam2_itm_dh_max") = r1(max(T.itm_delta_h_m));
N("fam2_itm_mode_los") = nnz(T.itm_mode == 1);
G = readtable(fullfile(CD, 'fam_roughness_grid.csv'));
g = @(dh, d) G.median_gap_db(G.target_delta_h_m == dh & G.d_km == d);
for dh = [10 50 100 200 500 1000]
    N(sprintf('fam21_dh%d', dh)) = [r1(min(G.median_gap_db(G.target_delta_h_m == dh))), r1(max(G.median_gap_db(G.target_delta_h_m == dh)))];
end
N("fam21_150_le200") = r1(max(G.median_gap_db(G.d_km == 150 & G.target_delta_h_m <= 200)));
N("fam21_10km_10") = r1(g(10, 10)); N("fam21_50km_100") = r1(g(100, 50)); N("fam21_50km_500") = r1(g(500, 50));
N("fam21_ratio10") = r1(median(G.median_itm_delta_h_m(G.d_km == 10) ./ G.target_delta_h_m(G.d_km == 10)));
N("fam21_ratio150") = r1(median(G.median_itm_delta_h_m(G.d_km == 150) ./ G.target_delta_h_m(G.d_km == 150)));
R = readtable(fullfile(CD, 'fam_roughness_runs.csv'));
N("fam21_runs") = height(R); N("fam21_flagged") = round(100 * mean(R.itm_horizon_flag));
P = readtable(fullfile(CD, 'fam_evaluation_point.csv'), 'TextType', 'string');
u = P(P.used == 1, :);
g0 = u.itm_excess_db - u.p2001_excess_db; g1 = u.itm_excess_db - u.p2001_line_at_path_db;
N("fam24_n") = height(u); N("fam24_total") = height(P);
N("fam24_gap") = [r1(median(g0)), r1(median(g1))];
N("fam24_wider") = nnz(g1 > g0);
N("fam24_closed_half") = nnz(g1 < 0.5 * g0);
end

function N = term_numbers(N, CD, r1)
% Plan items 9, 10, 11, 16, and 25
S = readtable(fullfile(CD, 'term_smooth_earth.csv'), 'TextType', 'string');
S.dse = S.itm_a_se_db - S.p2001_ldsph_db;
for pol = ["vertical", "horizontal"]
    q = S(S.polarization == pol, :);
    N("term_se_" + pol) = [r1(min(q.dse)), r1(max(q.dse))];
end
q = S(S.polarization == "vertical", :);
N("term_se_v150") = [r1(q.itm_a_se_db(q.d_km == 150)), r1(q.p2001_ldsph_db(q.d_km == 150))];
D = readtable(fullfile(CD, 'term_diffraction_links.csv'), 'TextType', 'string');
c = struct('edges', D.itm_wk_path_db - D.p2001_knife_db, 'smooth', D.itm_wse_path_db - D.p2001_sph_excess_db, ...
    'addon', D.itm_afo_db - D.p2001_empirical_db, 'extension', D.itm_a_ref_db - D.itm_ad_path_db, ...
    'other', D.p2001_ld_db - D.p2001_excess_db, 'total', D.itm_a_ref_db - D.p2001_excess_db);
rows = {};
for k = string(fieldnames(c))'
    v = c.(k);
    N("term_gap_" + k) = [r1(mean(v)), r1(median(v))];
    rows(end + 1, :) = {k, mean(v), median(v)}; %#ok<AGROW>
end
writetable(cell2table(rows, 'VariableNames', {'component', 'mean_db', 'median_db'}), fullfile(CD, 'term_gap_components.csv'));
N("term_n") = height(D); N("term_n_east") = nnz(D.side == "East"); N("term_n_west") = nnz(D.side == "West");
N("term_itm_med") = [r1(median(D.itm_wse_path_db)), r1(median(D.itm_wk_path_db)), r1(median(D.itm_afo_db)), ...
    r1(median(D.itm_ad_path_db)), r1(median(D.itm_ad_d3_db)), r1(median(D.itm_a_ref_db))];
N("term_p2001_med") = [r1(median(D.p2001_knife_db)), r1(median(D.p2001_empirical_db)), r1(median(D.p2001_sph_excess_db)), ...
    r1(median(D.p2001_excess_db))];
N("term_afo") = [r1(min(D.itm_afo_db)), r1(median(D.itm_afo_db)), r1(max(D.itm_afo_db))];
N("term_afo_cap") = nnz(D.itm_afo_db >= 15 - 1e-9);
N("term_emp") = [r1(min(D.p2001_empirical_db)), r1(median(D.p2001_empirical_db)), r1(max(D.p2001_empirical_db))];
N("term_emp_r") = round(100 * corr(D.d_km, D.p2001_empirical_db)) / 100;
T = readtable(fullfile(CD, 'term_ducting_smooth.csv'));
t = T(T.time_pct == 1, :);
N("term_duct_aac") = [r1(min(t.aac_db)), r1(max(t.aac_db))];
for d = [50 125 275 500]
    q = t(t.d_km == d, :);
    N(sprintf('term_duct_%d', d)) = [r1(q.aad_db), r1(q.aat_db), r1(q.lbm2_excess_db), r1(q.itm_excess_db), r1(q.lbm1_excess_db)];
end
U = readtable(fullfile(CD, 'term_ducting_links.csv'), 'TextType', 'string');
N("term_duct_links_lbm2_lt_lbm1") = nnz(U.p2001_lbm2_excess_1_db < U.p2001_lbm1_excess_1_db);
N("term_duct_links_n") = height(U);
M = readtable(fullfile(CD, 'term_monte_carlo.csv'), 'TextType', 'string');
M.diff = M.monte_carlo_db - M.blend_db;
nm = unique(M.path, 'stable'); rows = {};
for i = 1:numel(nm)
    q = M(M.path == nm(i), :);
    [~, j] = max(abs(q.diff));
    key = sprintf('term_mc%d_', i);
    N(key + "name") = nm(i);
    N(key + "max") = [r1(q.diff(j)), q.time_pct(j)];
    N(key + "p50") = r1(q.diff(q.time_pct == 50)); N(key + "p1") = r1(q.diff(q.time_pct == 1));
    q2 = q(q.time_pct >= 0.01 & q.time_pct <= 99, :);
    [~, j2] = max(abs(q2.diff));
    N(key + "max_core") = [r1(q2.diff(j2)), q2.time_pct(j2)];
end
end

function m = km_median(e, cens, w)
% Kaplan-Meier median of errors e (model minus measured) when some are
% upper bounds (cens true), with weights w. With x = -e, the bounds are
% right-censored.
if nargin < 3, w = ones(size(e)); end
cens = logical(cens); ok = isfinite(e); e = e(ok); cens = cens(ok); w = w(ok);
m = NaN;
if isempty(e), return, end
[f, x] = ecdf(-e, 'Censoring', cens, 'Frequency', w);
k = find(f >= 0.5, 1);
if ~isempty(k), m = -x(k); end
end

function N = west_numbers(N, W, b, FIG, CD, r1, CLS)
% Western links against the eastern 60: the ITM minus P.2001 gap by class,
% by region, and in the divergence window.
W.apart = W.itm_50 - W.p2001_50; W.apart452 = W.itm_50 - W.p452_50;
N("west_n") = height(W);
N("west_regions") = unique(W.region, 'stable')';
for c = CLS
    q = W(W.itm_class == c, :);
    N("west_n_" + c) = height(q);
    if height(q), N("west_gap_" + c) = r1(median(q.apart)); end
end
for rg = unique(W.region, 'stable')'
    q = W(W.region == rg, :); k = replace(rg, " ", "_");
    N("west_" + k + "_dh") = round(median(q.delta_h_m));
    N("west_" + k + "_gap") = r1(median(q.apart));
    N("west_" + k + "_gt20") = nnz(q.apart > 20);
end
N("west_dh_med") = round(median(W.delta_h_m)); N("east_dh_med") = round(median(b.delta_h_m));
N("west_gap_med") = r1(median(W.apart)); N("east_gap_med") = r1(median(b.apart));
N("west_gt20") = nnz(W.apart > 20); N("east_gt20") = nnz(b.apart > 20);
N("west_gap_max") = r1(max(W.apart));
N("west_p2001_p452_maxabs") = r1(max(abs(W.p2001_50 - W.p452_50)));
hz = bitand(uint32(W.itm_warnings), uint32(128)) > 0 | bitand(uint32(W.itm_warnings), uint32(256)) > 0;
N("west_hzn_flag") = nnz(hz);
if any(~hz), N("west_gap_noflag") = r1(median(W.apart(~hz))); end
win = W.delta_h_m > 150 & W.length_km < 150;
N("west_win_n") = nnz(win); N("west_win_med") = r1(median(W.apart(win)));
if any(~win), N("west_out_med") = r1(median(W.apart(~win))); end
% time distribution: does the gap close at 1 %?
for p = [1 10]
    N(sprintf('west_gap_%d', p)) = r1(median(W.(sprintf('itm_%d', p)) - W.(sprintf('p2001_%d', p))));
end
% ITM's smooth-earth weight on the western diffraction links
ft = fullfile(FIG, 'table_diffraction_terms_west.csv');
if isfile(ft)
    t = readtable(ft, 'TextType', 'string'); gd = t.itm_excess_50 - t.p2001_excess_50;
    N("west_nd") = height(t);
    N("west_w_lt") = r1(median(gd(t.w_d3 < 0.12))); N("west_w_lt_n") = nnz(t.w_d3 < 0.12);
    if any(t.w_d3 >= 0.12), N("west_w_ge") = r1(median(gd(t.w_d3 >= 0.12))); end
    N("west_w_ge_n") = nnz(t.w_d3 >= 0.12);
    N("west_term_k") = r1(median((1 - t.w_d3) .* t.A_k_d3)); N("west_term_fo") = r1(median(t.A_fo));
    N("west_term_bull") = r1(median(t.Lbulla));
end
% one table for the east-west figure
E = table(repmat("East", height(b), 1), b.link, b.delta_h_m, b.length_km, b.itm_class, b.apart, b.itm_50_db - b.p452_50_db, ...
    'VariableNames', {'side', 'link', 'delta_h_m', 'length_km', 'itm_class', 'itm_minus_p2001_db', 'itm_minus_p452_db'});
Wt = table(repmat("West", height(W), 1), (1:height(W))', W.delta_h_m, W.length_km, W.itm_class, W.apart, W.apart452, ...
    'VariableNames', E.Properties.VariableNames);
Wt.region = W.region; E.region = b.region;
writetable([E; Wt], fullfile(CD, 'terrain_east_west.csv'));
end

function c = classof(code)
c = repmat("Line of sight", size(code));
c(ismember(code, [4 5 8 9])) = "Diffraction";
c(ismember(code, [6 10])) = "Troposcatter";
end
