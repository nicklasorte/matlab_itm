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
b = join(b, links(:, {'link', 'delta_h_m', 'length_km'}));
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
    f = fullfile(CD, "grid_" + site + "_exclusion.csv");
    if ~isfile(f), continue, end
    E = readtable(f, 'TextType', 'string'); E = E(E.time_pct == 50, :);
    G = readtable(fullfile(CD, "grid_" + site + ".csv"));
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

% ---- smooth-earth distance to threshold ----
th = readtable(fullfile(FIG, 'table_distance_to_threshold.csv'));
N("thr_maxdiff_land") = max(abs([th.land_itm_km - th.land_p2001_km; th.land_itm_km - th.land_p452_km]));

fid = fopen(fullfile(FIG, 'numbers_3ghz.json'), 'w');
fprintf(fid, '%s', jsonencode(N, 'PrettyPrint', true));
fclose(fid);
fprintf('wrote %d numbers to numbers_3ghz.json\n', N.Count);
end

function c = classof(code)
c = repmat("Line of sight", size(code));
c(ismember(code, [4 5 8 9])) = "Diffraction";
c(ismember(code, [6 10])) = "Troposcatter";
end
