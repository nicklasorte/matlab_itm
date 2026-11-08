function T = compare_dbsg3_rev1(options)
%COMPARE_DBSG3_REV1 ITM, P.452, and P.2001 against the ITU-R SG3 databank, 30 MHz to 10 GHz.
%   T = COMPARE_DBSG3_REV1() runs the three models on every usable dataset
%   from 30 MHz to 10 GHz in ITU-R Study Group 3 databank Table III
%   (clear-air trans-horizon basic transmission loss, "long term" data,
%   free download at https://www.itu.int/oth/R0A04/en) and compares them
%   with the measured basic transmission loss not exceeded for 1, 10, 50,
%   90, and 99 % of the time.
%
%   Input: data/dbsg3/dbsg3_tableiii_30mhz_10ghz.csv, built from the
%   databank's ltpath, ltdata, and path-profile files. A dataset is usable
%   when it has both site coordinates, both antenna heights, a measured
%   median, and loss given relative to free space. Measured basic
%   transmission loss is free-space loss at the listed distance plus the
%   listed attenuation. Coordinates in Japan were converted from the Tokyo
%   datum to WGS84 (Japanese Geospatial Information Authority approximate
%   formula) when the CSV was built.
%
%   Site correction. Old site coordinates can sit a few hundred meters
%   off a hilltop site, which puts a ridge next to the antenna on a 30 m
%   terrain model. Where the databank has a surveyed profile, each
%   terminal moves to the 30 m terrain point within options.SearchRadius
%   (500 m) whose elevation best matches the surveyed ground elevation at
%   that end (cost: |elevation difference| in metres + 0.01 per metre of shift).
%
%   Quality screen. A dataset is left out of the comparison when:
%     coords     the listed distance and the coordinates disagree by > 3 %
%     profile    the surveyed profile length and listed distance disagree by > 5 %
%     elevation  after correction, terrain and survey elevations still
%                differ by more than options.ElevTol (20 m) at either end
%     obstructed the terrain puts a horizon within 500 m of a terminal at
%                more than 30 mrad (a sign of a misplaced site)
%   The models still run on left-out datasets; the tables keep them.
%
%   Every model gets the same profile: USGS 3DEP 1" in the U.S. and
%   Copernicus GLO-30 elsewhere, at 30 m spacing (coarser on paths longer
%   than 150 km so that a profile has at most 5,000 points). P.452 runs for
%   100 MHz and above, and for 1, 10, and 50 % only.
%
%   Writes to options.OutDir: table_dbsg3_by_dataset.csv,
%   table_dbsg3_summary.csv, table_dbsg3_quality.csv, and figures
%   fig25 to fig31 (see the code comments for each).
%
%   Name-value options: OutDir, P2001Dir, P452Dir, SearchRadius (500 m),
%   ElevTol (20 m), MaxRows (Inf, for quick tests).

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.SearchRadius (1,1) double = 500
    options.ElevTol (1,1) double = 20
    options.MaxRows (1,1) double = Inf
end

wp_setup(options.P2001Dir, options.P452Dir);
here = fileparts(mfilename('fullpath'));
out = options.OutDir;
if ~isfolder(out), mkdir(out); end
csv = fullfile(here, 'data', 'dbsg3', 'dbsg3_tableiii_30mhz_10ghz.csv');
io = detectImportOptions(csv, 'Delimiter', ',');
io = setvartype(io, {'id', 'path', 'pol', 'years', 'record', 'tx_name', 'tx_country', 'rx_name', 'rx_country', 'datum_shift'}, 'string');
S = readtable(csv, io);
S = S(1:min(height(S), options.MaxRows), :);
n = height(S);
P = [1 10 50 90 99];
A = [S.a1, S.a10, S.a50, S.a90, S.a99];
fsl = 32.45 + 20 * log10(S.freq_mhz) + 20 * log10(S.d_km);
meas = fsl + A;

% ---- site correction, once per path ----
[up, ~, iu] = unique(S.path, 'stable');
site = struct('tx', [], 'rx', [], 'shift_m', [NaN NaN], 'dz_before', [NaN NaN], 'dz_after', [NaN NaN]);
site = repmat(site, numel(up), 1);
for u = 1:numel(up)
    k = find(iu == u, 1);
    tx = [S.tx_lat(k) S.tx_lon(k)]; rx = [S.rx_lat(k) S.rx_lon(k)];
    site(u).tx = tx; site(u).rx = rx;
    if S.has_profile(k) == 1
        [site(u).tx, site(u).shift_m(1), site(u).dz_before(1), site(u).dz_after(1)] = ...
            relocate(tx, S.tx_ground_survey_m(k), options.SearchRadius);
        [site(u).rx, site(u).shift_m(2), site(u).dz_before(2), site(u).dz_after(2)] = ...
            relocate(rx, S.rx_ground_survey_m(k), options.SearchRadius);
    end
    site(u).tx0 = tx; site(u).rx0 = rx;
end

% ---- models ----
itm = NaN(n, 5); p452 = NaN(n, 5); p2001 = NaN(n, 5);
itm0 = NaN(n, 5); p452_0 = NaN(n, 5); p2001_0 = NaN(n, 5);    % uncorrected sites
dh = NaN(n, 1); code = NaN(n, 1); obstructed = false(n, 1); gc = NaN(n, 1);
profs = cell(numel(up), 2);
for k = 1:n
    u = iu(k);
    if isempty(profs{u, 1})
        d = S.d_km(k);
        sp = max(30, d * 1000 / 5000);
        profs{u, 1} = wp_terrain_profile(site(u).tx, site(u).rx, sp);
        moved = any(site(u).shift_m > 0);
        if moved
            profs{u, 2} = wp_terrain_profile(site(u).tx0, site(u).rx0, sp);
        else
            profs{u, 2} = profs{u, 1};
        end
    end
    prof = profs{u, 1};
    gc(k) = prof.d_km(end);
    r = wp_run3(prof, S.freq_mhz(k), S.htx_m(k), S.hrx_m(k), P);
    itm(k, :) = r.itm.Lb; p452(k, :) = r.p452.Lb; p2001(k, :) = r.p2001.Lb;
    dh(k) = r.itm.info.delta_h_m; code(k) = r.itm.mech;
    obstructed(k) = any(r.itm.info.d_hzn_m < 500 & r.itm.info.theta_hzn_rad > 0.03);
    if any(site(u).shift_m > 0)
        r0 = wp_run3(profs{u, 2}, S.freq_mhz(k), S.htx_m(k), S.hrx_m(k), P);
        itm0(k, :) = r0.itm.Lb; p452_0(k, :) = r0.p452.Lb; p2001_0(k, :) = r0.p2001.Lb;
    else
        itm0(k, :) = itm(k, :); p452_0(k, :) = p452(k, :); p2001_0(k, :) = p2001(k, :);
    end
    fprintf('%4d/%d %-9s %7.1f MHz %6.1f km meas50 %6.1f ITM %6.1f P452 %6.1f P2001 %6.1f\n', k, n, S.id(k), ...
        S.freq_mhz(k), S.d_km(k), meas(k, 3), itm(k, 3), p452(k, 3), p2001(k, 3));
end

% ---- quality screen ----
bad_coords = abs(gc - S.d_km) ./ S.d_km > 0.03;
bad_profile = S.has_profile == 1 & abs(S.profile_len_km - S.d_km) ./ S.d_km > 0.05;
dz_after = reshape([site(iu).dz_after], 2, [])';
bad_elev = any(abs(dz_after) > options.ElevTol, 2);
keep = ~bad_coords & ~bad_profile & ~bad_elev & ~obstructed;
Q = table(["coords"; "profile"; "elevation"; "obstructed"; "kept"; "total"], ...
    [nnz(bad_coords); nnz(bad_profile); nnz(bad_elev); nnz(obstructed); nnz(keep); n], ...
    'VariableNames', {'reason', 'datasets'});
writetable(Q, fullfile(out, 'table_dbsg3_quality.csv'));

% ---- frequency bins ----
edges = [30 100 300 1000 3000 6000 10001];
bins = ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-3 GHz", "3-6 GHz", "6-10 GHz"];
bi = discretize(S.freq_mhz, edges);
shift = reshape([site(iu).shift_m], 2, [])';
dzb = reshape([site(iu).dz_before], 2, [])';

T = table(S.id, S.path, S.freq_mhz, bins(bi)', S.d_km, S.htx_m, S.hrx_m, S.tx_country, S.rx_country, ...
    S.tx_name, S.rx_name, S.has_profile, shift(:, 1), shift(:, 2), dzb(:, 1), dzb(:, 2), dz_after(:, 1), dz_after(:, 2), ...
    bad_coords, bad_profile, bad_elev, obstructed, keep, dh, code, ...
    'VariableNames', {'id', 'path', 'freq_mhz', 'bin', 'd_km', 'htx_m', 'hrx_m', 'tx_country', 'rx_country', ...
    'tx_name', 'rx_name', 'has_profile', 'tx_shift_m', 'rx_shift_m', 'tx_dz_before_m', 'rx_dz_before_m', ...
    'tx_dz_after_m', 'rx_dz_after_m', 'bad_coords', 'bad_profile', 'bad_elevation', 'obstructed', 'kept', ...
    'itm_delta_h_m', 'itm_mode_code'});
for j = 1:5
    tag = sprintf('%02d', P(j));
    T.("meas_" + tag) = meas(:, j); T.("itm_" + tag) = itm(:, j);
    T.("p452_" + tag) = p452(:, j); T.("p2001_" + tag) = p2001(:, j);
end
T.itm_50_uncorrected = itm0(:, 3); T.p452_50_uncorrected = p452_0(:, 3); T.p2001_50_uncorrected = p2001_0(:, 3);
writetable(T, fullfile(out, 'table_dbsg3_by_dataset.csv'));

% ---- summary ----
mods = {itm, p452, p2001}; mn = ["ITM v1.4", "P.452-18", "P.2001-6"];
rows = {};
scopes = ["All", bins, "1-10 GHz", "30 MHz-1 GHz"];
for sc = scopes
    switch sc
        case "All", sel = keep;
        case "1-10 GHz", sel = keep & S.freq_mhz >= 1000;
        case "30 MHz-1 GHz", sel = keep & S.freq_mhz < 1000;
        otherwise, sel = keep & bins(bi)' == sc;
    end
    for m = 1:3
        for j = 1:5
            e = mods{m}(sel, j) - meas(sel, j);
            e = e(isfinite(e));
            if isempty(e), continue, end
            rows(end + 1, :) = {sc, mn(m), P(j), numel(e), mean(e), sqrt(mean(e.^2)), median(e), ...
                prctile(e, 10), prctile(e, 90), std(e)}; %#ok<AGROW>
        end
    end
end
Sm = cell2table(rows, 'VariableNames', {'group', 'model', 'percent', 'n', 'mean_error_db', 'rms_error_db', ...
    'median_error_db', 'p10_error_db', 'p90_error_db', 'std_error_db'});
% site-correction effect on the median, kept datasets whose sites moved
moved = keep & any(shift > 0, 2);
m0 = {itm0, p452_0, p2001_0};
for m = 1:3
    e1 = mods{m}(moved, 3) - meas(moved, 3); e0 = m0{m}(moved, 3) - meas(moved, 3);
    ok = isfinite(e1) & isfinite(e0);
    Sm = [Sm; {"moved sites, corrected", mn(m), 50, nnz(ok), mean(e1(ok)), sqrt(mean(e1(ok).^2)), median(e1(ok)), NaN, NaN, std(e1(ok))}; ...
        {"moved sites, uncorrected", mn(m), 50, nnz(ok), mean(e0(ok)), sqrt(mean(e0(ok).^2)), median(e0(ok)), NaN, NaN, std(e0(ok))}]; %#ok<AGROW>
end
writetable(Sm, fullfile(out, 'table_dbsg3_summary.csv'));

mc = [0 0.447 0.698; 0.835 0.369 0; 0 0.620 0.451];
bc = [0.55 0.55 0.55; 0.50 0.30 0.65; 0.80 0.47 0.65; 0.835 0.369 0; 0 0.620 0.451; 0 0.447 0.698];

% Fig. 25: map of the datasets
fig = figure('Visible', 'off', 'Position', [0 0 1400 700]);
gx = geoaxes(fig);
try, geobasemap(gx, 'grayland'); catch, geobasemap(gx, 'none'); end
hold(gx, 'on');
for b = 1:numel(bins)
    first = true;
    for k = find(keep & bi == b)'
        u = iu(k); la = [site(u).tx(1) site(u).rx(1)]; lo = [site(u).tx(2) site(u).rx(2)];
        if first
            geoplot(gx, la, lo, '-', 'Color', bc(b, :), 'LineWidth', 1.8, 'DisplayName', bins(b)); first = false;
        else
            geoplot(gx, la, lo, '-', 'Color', bc(b, :), 'LineWidth', 1.8, 'HandleVisibility', 'off');
        end
    end
end
legend(gx, 'Location', 'southoutside', 'NumColumns', 6);
title(gx, sprintf('ITU-R SG3 databank Table III: %d datasets used, 30 MHz to 10 GHz', nnz(keep)));
wp_save_fig(fig, out, 'fig25_dbsg3_map');

% Fig. 26: median error against frequency
fig = figure('Visible', 'off', 'Position', [0 0 1250 430]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
for m = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    e = mods{m}(:, 3) - meas(:, 3);
    ok = keep & isfinite(e);
    scatter(ax, S.freq_mhz(ok), e(ok), 14, mc(m, :), 'filled', 'MarkerFaceAlpha', 0.35, 'DisplayName', 'Dataset');
    q = NaN(numel(bins), 3);
    for b = 1:numel(bins)
        sb = ok & bi == b;
        if nnz(sb) >= 3, q(b, :) = prctile(e(sb), [25 50 75]); end
    end
    cb = sqrt(edges(1:end-1) .* min(edges(2:end), 10000));
    errorbar(ax, cb, q(:, 2), q(:, 2) - q(:, 1), q(:, 3) - q(:, 2), 'k-s', 'LineWidth', 2, 'MarkerFaceColor', 'k', ...
        'DisplayName', 'Median and quartiles by bin');
    yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    set(ax, 'XScale', 'log', 'XTick', [30 100 300 1000 3000 10000], 'XTickLabel', {'30 MHz', '100 MHz', '300 MHz', '1 GHz', '3 GHz', '10 GHz'});
    xlim(ax, [25 12000]); ylim(ax, [-50 60]);
    title(ax, mn(m)); xlabel(ax, 'Frequency');
    if m == 1, ylabel(ax, 'Predicted minus measured median (dB)'); legend(ax, 'Location', 'northwest'); end
    if m == 2, subtitle(ax, 'P.452 starts at 100 MHz', 'FontSize', 8); end
    grid(ax, 'on');
end
wp_save_fig(fig, out, 'fig26_dbsg3_error_vs_frequency');

% Fig. 27: mean and RMS error by bin at 50 %
fig = figure('Visible', 'off', 'Position', [0 0 1200 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
stat = ["mean_error_db", "rms_error_db"]; ttl = ["Mean error at 50 %", "RMS error at 50 %"];
for s = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    V = NaN(numel(bins), 3);
    for b = 1:numel(bins)
        for m = 1:3
            r = Sm(Sm.group == bins(b) & Sm.model == mn(m) & Sm.percent == 50, :);
            if ~isempty(r), V(b, m) = r.(stat(s)); end
        end
    end
    h = bar(ax, categorical(bins, bins), V);
    for m = 1:3, h(m).FaceColor = mc(m, :); end
    ylabel(ax, 'dB'); title(ax, ttl(s)); grid(ax, 'on');
    if s == 1, legend(ax, mn, 'Location', 'northwest'); end
end
wp_save_fig(fig, out, 'fig27_dbsg3_error_by_bin');

% Fig. 28: mean error by bin and time percentage
fig = figure('Visible', 'off', 'Position', [0 0 1250 420]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
for m = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    for b = 1:numel(bins)
        y = NaN(1, 5);
        for j = 1:5
            r = Sm(Sm.group == bins(b) & Sm.model == mn(m) & Sm.percent == P(j), :);
            if ~isempty(r) && r.n >= 3, y(j) = r.mean_error_db; end
        end
        plot(ax, 1:5, y, '-o', 'Color', bc(b, :), 'LineWidth', 1.6, 'MarkerFaceColor', bc(b, :), 'DisplayName', bins(b));
    end
    yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    set(ax, 'XTick', 1:5, 'XTickLabel', compose('%g %%', P)); xlim(ax, [0.7 5.3]);
    title(ax, mn(m)); xlabel(ax, 'Time percentage');
    if m == 1, ylabel(ax, 'Mean predicted minus measured (dB)'); legend(ax, 'Location', 'southwest', 'FontSize', 7); end
    grid(ax, 'on');
end
wp_save_fig(fig, out, 'fig28_dbsg3_error_by_percentage');

% Fig. 29: median error against terrain irregularity
fig = figure('Visible', 'off', 'Position', [0 0 1250 420]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
for m = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    e = mods{m}(:, 3) - meas(:, 3);
    hi = keep & S.freq_mhz >= 1000 & isfinite(e); lo = keep & S.freq_mhz < 1000 & isfinite(e);
    scatter(ax, max(dh(lo), 2), e(lo), 12, [0.6 0.6 0.6], 'filled', 'MarkerFaceAlpha', 0.4, 'DisplayName', '30 MHz-1 GHz');
    scatter(ax, max(dh(hi), 2), e(hi), 22, mc(m, :), 'filled', 'DisplayName', '1-10 GHz');
    yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    set(ax, 'XScale', 'log'); ylim(ax, [-50 60]);
    title(ax, mn(m)); xlabel(ax, 'ITM terrain irregularity \Deltah (m)');
    if m == 1, ylabel(ax, 'Predicted minus measured median (dB)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
wp_save_fig(fig, out, 'fig29_dbsg3_error_vs_delta_h');

% Fig. 30: site correction
fig = figure('Visible', 'off', 'Position', [0 0 1200 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
ax = nexttile(tl); hold(ax, 'on');
pr = S.has_profile == 1;
[~, ia] = unique(iu(pr)); idx = find(pr); idx = idx(ia);
b0 = dzb(idx, :); b1 = dz_after(idx, :);
ed = -300:10:300;
histogram(ax, max(min(b0(:), 300), -300), ed, 'FaceColor', [0.7 0.7 0.7], 'DisplayName', 'Listed coordinates');
histogram(ax, max(min(b1(:), 300), -300), ed, 'FaceColor', mc(1, :), 'FaceAlpha', 0.7, 'DisplayName', 'After correction');
xlabel(ax, '30 m terrain minus surveyed ground elevation at a terminal (m)'); ylabel(ax, 'Terminals');
title(ax, 'Terminal elevation, terrain model against survey'); legend(ax); grid(ax, 'on');
ax = nexttile(tl); hold(ax, 'on');
V = NaN(3, 2);
for m = 1:3
    V(m, 1) = Sm.rms_error_db(Sm.group == "moved sites, uncorrected" & Sm.model == mn(m));
    V(m, 2) = Sm.rms_error_db(Sm.group == "moved sites, corrected" & Sm.model == mn(m));
end
h = bar(ax, categorical(mn, mn), V);
h(1).FaceColor = [0.7 0.7 0.7]; h(2).FaceColor = mc(1, :);
ylabel(ax, 'RMS error in the median (dB)'); legend(ax, {'Listed coordinates', 'Corrected sites'}, 'Location', 'northwest');
title(ax, sprintf('Effect on the %d kept datasets whose sites moved', nnz(moved))); grid(ax, 'on');
wp_save_fig(fig, out, 'fig30_dbsg3_site_correction');

% Fig. 31: distributions on six kept datasets from 1 GHz to 10 GHz
cand = ["LT0588", "LT1438", "LT2212", "LT2633", "LT2365", "LT2352", "LT2237", "LT1703", "LT1606", "LT2064"];
pick = [];
for c = cand
    k = find(S.path == c & keep & S.freq_mhz >= 1000, 1);
    if ~isempty(k), pick(end + 1) = k; end %#ok<AGROW>
    if numel(pick) == 6, break, end
end
fig = figure('Visible', 'off', 'Position', [0 0 1200 700]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
for kk = 1:numel(pick)
    k = pick(kk);
    ax = nexttile(tl); hold(ax, 'on');
    ok = isfinite(meas(k, :));
    plot(ax, P(ok), meas(k, ok), 'k-o', 'LineWidth', 2, 'MarkerFaceColor', 'k', 'DisplayName', 'Measured');
    plot(ax, P, itm(k, :), '-', 'Color', mc(1, :), 'LineWidth', 1.8, 'DisplayName', 'ITM v1.4');
    plot(ax, P, p452(k, :), '--', 'Color', mc(2, :), 'LineWidth', 1.8, 'DisplayName', 'P.452-18');
    plot(ax, P, p2001(k, :), '-.', 'Color', mc(3, :), 'LineWidth', 1.8, 'DisplayName', 'P.2001-6');
    set(ax, 'XScale', 'log', 'XTick', [1 10 50 99]);
    title(ax, sprintf('%s: %.0f MHz, %.0f km', S.path(k), S.freq_mhz(k), S.d_km(k)), 'FontSize', 9);
    subtitle(ax, S.tx_name(k) + " to " + S.rx_name(k), 'FontSize', 8);
    xlabel(ax, 'Time percentage (%)');
    if mod(kk, 3) == 1, ylabel(ax, 'Basic transmission loss (dB)'); end
    if kk == 1, legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
wp_save_fig(fig, out, 'fig31_dbsg3_distributions');
end

%% ------------------------------------------------------------------------
function [p, shift_m, dz0, dz1] = relocate(p0, z_survey, R)
% Move a terminal to the 30 m terrain point within R metres whose elevation
% best matches the surveyed ground elevation; ties go to the nearer point.
z0 = itm_terrain_elevation_rev1(p0(1), p0(2));
dz0 = z0 - z_survey;
step = 30;
[dx, dy] = meshgrid(-R:step:R);
in = hypot(dx, dy) <= R;
dx = dx(in); dy = dy(in);
lat = p0(1) + dy / 111320;
lon = p0(2) + dx ./ (111320 * cosd(p0(1)));
z = itm_terrain_elevation_rev1(lat, lon);
z(isnan(z)) = 0;
cost = abs(z - z_survey) + 0.01 * hypot(dx, dy);
[~, i] = min(cost);
p = [lat(i) lon(i)];
shift_m = hypot(dx(i), dy(i));
dz1 = z(i) - z_survey;
end
