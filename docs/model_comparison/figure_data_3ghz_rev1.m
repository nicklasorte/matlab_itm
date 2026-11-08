function figure_data_3ghz_rev1(options)
%FIGURE_DATA_3GHZ_REV1 Compute the data each figure of the 3 GHz paper plots.
%   FIGURE_DATA_3GHZ_REV1() reads the result CSV files (chart_data/ and
%   figures/table_*.csv) and writes one table per figure to
%   chart_data/figures/fig_sNN_*.csv, with every derived quantity the
%   figure shows already computed: gaps between models, losses above free
%   space, medians, smoothed curves, group labels, horizons. The Python
%   script make_wp_figures_3ghz.py then only plots columns from these files.
%   Run it after export_deep_dive_data_rev1 and paper_numbers_3ghz_rev1.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.DataDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
end
FIG = options.Dir; CD = options.DataDir; OUT = fullfile(CD, 'figures');
if ~isfolder(OUT), mkdir(OUT); end
rd = @(f) readtable(fullfile(CD, f), 'TextType', 'string', 'VariableNamingRule', 'preserve');
wt = @(T, f) writetable(T, fullfile(OUT, f));
CLS = ["Line of sight", "Diffraction", "Troposcatter"];

links = rd('real_terrain_links.csv');
b = rd('real_terrain_by_link.csv');
b = join(b, links(:, {'link', 'delta_h_m', 'length_km'}));
F0 = b.freq_mhz(1);
b.itm_minus_p2001_db = b.itm_50_db - b.p2001_50_db;

% s01 smooth earth: loss above free space on land
se = rd('deep_smooth_earth.csv'); se = se(se.surface == "land" & se.freq_mhz == F0, :);
wt(table(se.d_km, se.itm_50_db - se.free_space_db, se.p452_50_db - se.free_space_db, se.p2001_50_db - se.free_space_db, ...
    'VariableNames', {'d_km', 'itm_above_fs_db', 'p452_above_fs_db', 'p2001_above_fs_db'}), 'fig_s01_smooth_earth.csv');

% s02 knife edge
k = rd('deep_knife_edge.csv'); k = k(k.freq_mhz == F0 & k.v >= -1, :);
wt(k(:, {'v', 'J_db', 'itm_db', 'p452_db', 'p2001_db'}), 'fig_s02_knife_edge.csv');

% s03 knife-edge functions: J(v) from the Fresnel integrals, the ITU and ITM approximations
v = linspace(0, 8, 401)';
J = arrayfun(@J_exact, v);
itu = 6.9 + 20 * log10(sqrt((v - 0.1) .^ 2 + 1) + v - 0.1);
itm = 6.02 + 9.11 * v - 1.27 * v .^ 2;
hi = v .^ 2 >= 5.76; itm(hi) = 12.953 + 10 * log10(v(hi) .^ 2);
wt(table(v, J, itu, itm, 2 * itm, 'VariableNames', {'v', 'J_db', 'itu_db', 'itm_one_edge_db', 'itm_two_edges_db'}), 'fig_s03_knife_edge_function.csv');

% s04, s05, s11, s14 the links
b.over_20db = b.itm_minus_p2001_db > 20;
wt(b(:, {'link', 'itm_class', 'delta_h_m', 'length_km', 'itm_minus_p2001_db', 'over_20db'}), 'fig_links_gap.csv');
rows = {};
for c = CLS
    q = b.itm_minus_p2001_db(b.itm_class == c);
    rows(end + 1, :) = {c, numel(q), median(q)}; %#ok<AGROW>
end
wt(cell2table(rows, 'VariableNames', {'itm_class', 'links', 'median_db'}), 'fig_s04_class_medians.csv');

% s06 frequency sweep
fs = rd('deep_freq_sweep.csv');
wt(table(fs.path, fs.freq_mhz, fs.itm_db - fs.p2001_db, 'VariableNames', {'path', 'freq_mhz', 'itm_minus_p2001_db'}), 'fig_s06_frequency_sweep.csv');

% s07 terrain resolution
T = rd('terrain_resolution_by_link.csv'); T.gap = T.itm_50_db - T.p2001_50_db;
G = unstack(T(:, {'link', 'resolution', 'gap'}), 'gap', 'resolution', 'VariableNamingRule', 'preserve');
G.moved_over_10db = abs(G.("1 km smoothed") - G.("30 m")) > 10;
wt(G, 'fig_s07_terrain_resolution.csv');

% s08, s12, s16 diffraction terms
t = readtable(fullfile(FIG, 'table_diffraction_terms.csv'), 'TextType', 'string'); t = t(t.freq_mhz == F0, :);
w = t.w_d3;
wt(table(["ITM"; "ITM"; "ITM"; "P.452"; "P.452"], ["smooth earth × w"; "two knife edges × (1 − w)"; "clutter"; "one knife edge"; "spherical-earth excess"], ...
    [median(w .* t.A_se_d3); median((1 - w) .* t.A_k_d3); median(t.A_fo); median(t.Lbulla); median(max(t.Ldsph - t.Lbulls, 0))], ...
    'VariableNames', {'model', 'term', 'median_db'}), 'fig_s08_diffraction_terms.csv');
gd = t.itm_excess_50 - t.p2001_excess_50;
grp = repmat("w 0.12 or more", height(t), 1); grp(w < 0.12) = "w under 0.12";
gm = zeros(height(t), 1); gm(w < 0.12) = median(gd(w < 0.12)); gm(w >= 0.12) = median(gd(w >= 0.12));
wt(table(t.link, w, gd, grp, gm, t.itm_excess_50, t.p452_excess_50, 'VariableNames', ...
    {'link', 'w_d3', 'itm_minus_p2001_db', 'group', 'group_median_db', 'itm_excess_db', 'p452_excess_db'}), 'fig_diffraction_links.csv');

% s10 radials: ITM minus P.2001, median over 5 points (10 km)
rad = rd('deep_radials.csv'); rad = rad(rad.freq_mhz == F0, :);
rad.gap = rad.itm_50_db - rad.p2001_50_db; rad.gap_smoothed = rad.gap;
for az = unique(rad.azimuth_deg)'
    s = rad.azimuth_deg == az;
    rad.gap_smoothed(s) = movmedian(rad.gap(s), 5, 'Endpoints', 'shrink');
end
se2 = rd('deep_smooth_earth.csv'); se2 = se2(se2.surface == "land" & se2.freq_mhz == F0 & se2.d_km <= 150, :);
R = [rad(:, {'azimuth_deg', 'd_km', 'gap', 'gap_smoothed'}); ...
    table(-ones(height(se2), 1), se2.d_km, se2.itm_50_db - se2.p2001_50_db, se2.itm_50_db - se2.p2001_50_db, ...
    'VariableNames', {'azimuth_deg', 'd_km', 'gap', 'gap_smoothed'})];
wt(R, 'fig_s10_radials.csv');   % azimuth -1 is smooth earth

% s11, s14 measured paths
D = readtable(fullfile(FIG, 'table_dbsg3_by_dataset_survey.csv'), 'TextType', 'string'); D = D(D.kept == 1, :);
wt(table(D.id, D.freq_mhz, D.d_km, D.itm_delta_h_m, D.itm_50 - D.p2001_50, 'VariableNames', ...
    {'id', 'freq_mhz', 'd_km', 'delta_h_m', 'itm_minus_p2001_db'}), 'fig_measured_paths.csv');

% fig25 measured paths by region (midpoint inside each region's box)
X = readtable(fullfile(fileparts(CD), 'data', 'dbsg3', 'dbsg3_tableiii_30mhz_10ghz.csv'), 'TextType', 'string');
X = X(ismember(X.id, D.id), {'id', 'path', 'freq_mhz', 'tx_lat', 'tx_lon', 'rx_lat', 'rx_lon'});
mla = (X.tx_lat + X.rx_lat) / 2; mlo = (X.tx_lon + X.rx_lon) / 2;
X.region = repmat("Other", height(X), 1);
X.region(mlo >= -125 & mlo <= -54 & mla >= 24 & mla <= 53) = "North America";
X.region(mlo >= -11 & mlo <= 16 & mla >= 42.5 & mla <= 61.5) = "Europe";
X.region(mlo >= 128 & mlo <= 146.5 & mla >= 26 & mla <= 46.5) = "Japan";
wt(X, 'fig25_measured_regions.csv');
rows = {};
for rg = ["North America", "Europe", "Japan", "Other"]
    q = X(X.region == rg, :);
    rows(end + 1, :) = {rg, height(q), numel(unique(q.path)), nnz(q.freq_mhz >= 1000)}; %#ok<AGROW>
end
wt(cell2table(rows, 'VariableNames', {'region', 'datasets', 'paths', 'datasets_1_10_ghz'}), 'fig25_region_counts.csv');

% s13 anatomy of the double-horizon link: profile with earth bulge, horizons, Bullington point
pr = rd('deep_archetype_profiles.csv'); pr = pr(pr.path == "Double-horizon diffraction", :);
d = pr.d_km; h = pr.h_m; Dk = d(end); a = 8500;
z = h + d .* (Dk - d) / (2 * a) * 1000;
ztx = z(1) + pr.htx_m(1); zrx = z(end) + pr.hrx_m(1);
st = (z(2:end-1) - ztx) ./ d(2:end-1); [s1, i1] = max(st); i1 = i1 + 1;
sr = (z(2:end-1) - zrx) ./ (Dk - d(2:end-1)); [s2r, i2] = max(sr); i2 = i2 + 1; s2 = -s2r;
xb = (zrx - s2 * Dk - ztx) / (s1 - s2); zb = ztx + s1 * xb;
wt(table(d, z, 'VariableNames', {'d_km', 'height_with_bulge_m'}), 'fig_s13_profile.csv');
tt = t(t.link == pr.link(1), :);
geo = table(["tx"; "rx"; "tx_horizon"; "rx_horizon"; "bullington"], [0; Dk; d(i1); d(i2); xb], [ztx; zrx; z(i1); z(i2); zb], ...
    'VariableNames', {'point', 'd_km', 'z_m'});
wt(geo, 'fig_s13_geometry.csv');
wt(table(["ITM"; "ITM"; "ITM"; "P.452"; "P.2001"], ["smooth earth × w"; "two knife edges × (1 − w)"; "clutter"; "one knife edge (Bullington)"; "Bullington and spherical earth"], ...
    [tt.w_d3 * tt.A_se_d3; (1 - tt.w_d3) * tt.A_k_d3; tt.A_fo; tt.Lbulla; tt.p2001_excess_50], ...
    [tt.itm_excess_50; tt.itm_excess_50; tt.itm_excess_50; tt.p452_excess_50; tt.p2001_excess_50], ...
    'VariableNames', {'model', 'term', 'value_db', 'model_total_db'}), 'fig_s13_terms.csv');

% s15, s19 time distribution by class
TT = rd('deep_time_by_link.csv'); TT = TT(TT.freq_mhz == F0, :);
TT.c = classof(TT.itm_mode_code); TT.gap = TT.itm_db - TT.p2001_db;
rows = {}; rows2 = {};
for c = CLS
    for p = unique(TT.time_pct)'
        rows(end + 1, :) = {c, p, median(TT.gap(TT.c == c & TT.time_pct == p))}; %#ok<AGROW>
    end
    q50 = TT(TT.c == c & TT.time_pct == 50, :); q1 = TT(TT.c == c & TT.time_pct == 1, :);
    rows2(end + 1, :) = {c, median(q50.itm_db - q1.itm_db), median(q50.p2001_db - q1.p2001_db)}; %#ok<AGROW>
end
wt(cell2table(rows, 'VariableNames', {'itm_class', 'time_pct', 'median_itm_minus_p2001_db'}), 'fig_s15_time_by_class.csv');
wt(cell2table(rows2, 'VariableNames', {'itm_class', 'itm_50_minus_1_db', 'p2001_50_minus_1_db'}), 'fig_s19_enhancement_real.csv');

% s17, s21 archetypes over time
A = rd('deep_archetype_time.csv'); A = A(A.freq_mhz == F0, :);
A.free_space_db = 32.45 + 20 * log10(F0) + 20 * log10(A.length_km);
for m = ["itm", "p452", "p2001"]
    A.(m + "_minus_50_db") = NaN(height(A), 1);
    for pth = unique(A.path)'
        s = A.path == pth;
        A.(m + "_minus_50_db")(s) = A.(m + "_db")(s) - A.(m + "_db")(s & A.time_pct == 50);
    end
end
wt(A, 'fig_archetypes_time.csv');

% s18 ducting takeover
st = rd('deep_smooth_earth_time.csv'); st = st(st.freq_mhz == F0, :);
rows = {};
for surf = ["land", "sea"]
    for dd = unique(st.d_km)'
        q = st(st.surface == surf & st.d_km == dd & st.p2001_mech == 2, :);
        mx = NaN; if ~isempty(q), mx = max(q.time_pct); end
        rows(end + 1, :) = {surf, dd, mx}; %#ok<AGROW>
    end
end
wt(cell2table(rows, 'VariableNames', {'surface', 'd_km', 'max_ducting_time_pct'}), 'fig_s18_ducting_takeover.csv');
% s29, s30, s32 grids: the main 300 km grid, with the exclusion at 160 dB, and the basemap in km from the receiver
E = wgs84Ellipsoid('km');
sites = struct('dc', [38.8895, -77.0353], 'la', [34.0537, -118.2428]);
cst = readtable(fullfile(CD, 'basemap_coastlines.csv')); ust = readtable(fullfile(CD, 'basemap_us_states.csv'));
for site = ["dc", "la"]
    f = fullfile(CD, "grid_" + site + "_150km_2p5km.csv");
    if ~isfile(f), continue, end
    Gd = readtable(f);
    Gd.itm_minus_p2001_db = Gd.itm_50 - Gd.p2001_50;
    Gd.itm_excluded_160 = Gd.itm_50 < 160; Gd.p2001_excluded_160 = Gd.p2001_50 < 160;
    wt(Gd(:, {'dx_km', 'dy_km', 'd_km', 'itm_50', 'p2001_50', 'itm_minus_p2001_db', 'itm_excluded_160', 'p2001_excluded_160'}), "fig_grid_" + site + ".csv");
    rx = sites.(site); rows = {};
    for src = {cst, ust}
        B = src{1}; la = B.lat; lo = B.lon;
        near = abs(la - rx(1)) < 2.5 & abs(lo - rx(2)) < 3.5 | isnan(la);
        la = la(near); lo = lo(near);
        [dd, az] = distance(rx(1), rx(2), la, lo, E);
        x = dd .* sind(az); y = dd .* cosd(az);
        x(isnan(la)) = NaN; y(isnan(la)) = NaN;
        rows{end + 1} = table([x; NaN], [y; NaN], 'VariableNames', {'dx_km', 'dy_km'}); %#ok<AGROW>
    end
    wt(vertcat(rows{:}), "fig_grid_" + site + "_basemap.csv");
end
fprintf('wrote figure data to %s\n', OUT);
end

function J = J_exact(v)
C = integral(@(t) cos(pi * t .^ 2 / 2), 0, v); S = integral(@(t) sin(pi * t .^ 2 / 2), 0, v);
J = -20 * log10(sqrt((1 - C - S) ^ 2 + (C - S) ^ 2) / 2);
end

function c = classof(code)
c = repmat("Line of sight", size(code));
c(ismember(code, [4 5 8 9])) = "Diffraction";
c(ismember(code, [6 10])) = "Troposcatter";
end
