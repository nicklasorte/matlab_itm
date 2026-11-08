function T = compare_trer16_rev1(options)
%COMPARE_TRER16_REV1 ITM, P.452, and P.2001 against measured U.S. paths from OT/TRER 16.
%   T = COMPARE_TRER16_REV1() runs the three models on the 41 U.S. paths
%   from 1 GHz to 10 GHz in data/trer16_us_paths.csv and compares them
%   with the measured long-term distributions of basic transmission loss.
%
%   Source of the measurements: A. G. Longley, R. K. Reasoner, and V. L.
%   Fuller, "Measured and Predicted Long-Term Distributions of Tropospheric
%   Transmission Loss," OT/TRER 16, Office of Telecommunications, July 1971
%   (data/sources/OT-TRER-16.pdf), Tables 1 and 2. The CSV was read from the
%   page images and checked: the great-circle distance between the listed
%   coordinates matches the listed path length within 0.2 % on 34 paths.
%   The seven Southern California over-sea paths (1903-1909) list
%   coordinates only to the arcminute (within 1.7 %), list no antenna
%   heights (10 m is assumed; column heights_assumed), and give only the
%   median; the summary reports them separately.
%
%   Every model gets the same profile: USGS 3DEP 1" terrain at 30 m along
%   the geodesic between the listed sites (wp_terrain_profile). Antenna
%   heights are the listed heights above ground (HTG, HRG). The measured
%   values are basic transmission loss not exceeded for 1, 10, 50, 90, and
%   99 % of the time (hourly medians), the same sense as the models' time
%   percentage. P.452 runs for 1, 10, and 50 % only.
%
%   Writes, to options.OutDir:
%     table_trer16_by_path.csv      measured and predicted, every path and %
%     table_trer16_summary.csv      mean and RMS error by model, frequency
%                                   group, and percentage
%     fig12_trer16_median_error.png predicted minus measured median, by path
%     fig13_trer16_distributions.png measured and predicted distributions on
%                                   six paths from 2.3 GHz to 4.1 GHz
%     fig16_trer16_path_map.png     map of the paths
%     fig20_trer16_error_vs_delta_h.png median error against ITM's Delta h
%
%   Name-value options:
%     OutDir             output folder (figures/ next to this file)
%     P2001Dir, P452Dir  model folders ("" = on the path or next to matlab_itm)

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
end

wp_setup(options.P2001Dir, options.P452Dir);
here = fileparts(mfilename('fullpath'));
out = options.OutDir;
if ~isfolder(out), mkdir(out); end

csv = fullfile(here, 'data', 'trer16_us_paths.csv');
io = detectImportOptions(csv, 'Delimiter', ',');
io = setvartype(io, {'path', 'tx_name', 'tx_lat', 'tx_lon', 'rx_name', 'rx_lat', 'rx_lon', 'years', 'region'}, 'string');
S = readtable(csv, io);
n = height(S);
P = [1 10 50 90 99];
meas_cols = ["lb01_db", "lb10_db", "lb50_db", "lb90_db", "lb99_db"];

meas = NaN(n, 5); itm = NaN(n, 5); p452 = NaN(n, 5); p2001 = NaN(n, 5);
itm_code = NaN(n, 1); itm_dh = NaN(n, 1); itm_clim = NaN(n, 1); sea_frac = NaN(n, 1); fsl = NaN(n, 1);
for k = 1:n
    tx = [dms(S.tx_lat(k)), dms(S.tx_lon(k))];
    rx = [dms(S.rx_lat(k)), dms(S.rx_lon(k))];
    prof = wp_terrain_profile(tx, rx);
    r = wp_run3(prof, S.freq_mhz(k), S.htg_m(k), S.hrg_m(k), P);
    for j = 1:5
        meas(k, j) = S.(meas_cols(j))(k);
    end
    itm(k, :) = r.itm.Lb; p452(k, :) = r.p452.Lb; p2001(k, :) = r.p2001.Lb;
    itm_code(k) = r.itm.mech; itm_dh(k) = r.itm.info.delta_h_m; itm_clim(k) = r.itm.climate;
    sea_frac(k) = mean(prof.zone == 1);
    fsl(k) = 32.45 + 20 * log10(S.freq_mhz(k)) + 20 * log10(prof.d_km(end));
    fprintf('%6s %7.1f MHz %6.1f km  meas50 %6.1f  ITM %6.1f  P.452 %6.1f  P.2001 %6.1f\n', ...
        S.path(k), S.freq_mhz(k), S.d_km(k), meas(k, 3), itm(k, 3), p452(k, 3), p2001(k, 3));
end

grp = strings(n, 1);
grp(S.freq_mhz < 2000) = "1.0-1.7 GHz";
grp(S.freq_mhz >= 2000 & S.freq_mhz < 3000) = "2.3-2.8 GHz";
grp(S.freq_mhz >= 3000 & S.freq_mhz < 5000) = "3.4-4.1 GHz";
grp(S.freq_mhz >= 9000) = "9.1-9.4 GHz";

% Per-path table
T = table(S.path, S.freq_mhz, S.d_km, S.htg_m, S.hrg_m, S.heights_assumed, S.n_horizons, S.region, grp, itm_code, itm_dh, itm_clim, sea_frac, fsl, ...
    'VariableNames', {'path', 'freq_mhz', 'd_km', 'htg_m', 'hrg_m', 'heights_assumed', 'n_horizons', 'region', 'group', ...
    'itm_mode_code', 'itm_delta_h_m', 'itm_climate', 'sea_fraction', 'free_space_db'});
for j = 1:5
    tag = sprintf('%02d', P(j));
    T.("meas_" + tag) = meas(:, j);
    T.("itm_" + tag) = itm(:, j);
    T.("p452_" + tag) = p452(:, j);
    T.("p2001_" + tag) = p2001(:, j);
end
T.tn101_50 = S.tn101_lbcr_db;
T.essa70_50 = S.essa70_lbcr_db;
writetable(T, fullfile(out, 'table_trer16_by_path.csv'));

% Summary: error = predicted minus measured
models = {itm, p452, p2001, [NaN(n, 2), S.tn101_lbcr_db, NaN(n, 2)], [NaN(n, 2), S.essa70_lbcr_db, NaN(n, 2)]};
names = ["ITM v1.4", "P.452-18", "P.2001-6", "TN 101 (1967)", "ESSA 70 (1970)"];
listed = S.heights_assumed == 0;
groups = ["All, listed heights", unique(grp(listed))', "California over sea, heights assumed"];
rows = {};
for g = groups
    if g == "All, listed heights"
        sel = listed;
    elseif g == "California over sea, heights assumed"
        sel = ~listed;
    else
        sel = listed & grp == g;
    end
    for m = 1:numel(models)
        for j = 1:5
            e = models{m}(sel, j) - meas(sel, j);
            e = e(isfinite(e));
            if isempty(e), continue, end
            rows(end + 1, :) = {g, names(m), P(j), numel(e), mean(e), sqrt(mean(e.^2)), median(e)}; %#ok<AGROW>
        end
    end
end
Sm = cell2table(rows, 'VariableNames', {'group', 'model', 'percent', 'n_paths', 'mean_error_db', 'rms_error_db', 'median_error_db'});
writetable(Sm, fullfile(out, 'table_trer16_summary.csv'));

% Fig. 12: median error by path
[~, ord] = sortrows([S.heights_assumed, S.freq_mhz, S.d_km]);   % assumed-height paths last
fig = figure('Visible', 'off', 'Position', [0 0 1300 460]);
ax = axes(fig); hold(ax, 'on');
x = 1:n;
plot(ax, x, itm(ord, 3) - meas(ord, 3), 'o', 'MarkerFaceColor', [0 0.447 0.698], 'Color', [0 0.447 0.698], 'DisplayName', 'ITM v1.4');
plot(ax, x, p452(ord, 3) - meas(ord, 3), 's', 'Color', [0.835 0.369 0], 'LineWidth', 1.2, 'DisplayName', 'P.452-18');
plot(ax, x, p2001(ord, 3) - meas(ord, 3), 'd', 'Color', [0 0.620 0.451], 'LineWidth', 1.2, 'DisplayName', 'P.2001-6');
yline(ax, 0, 'k:', 'HandleVisibility', 'off');
lab = S.path(ord) + " (" + string(round(S.freq_mhz(ord))) + ")";
set(ax, 'XTick', x, 'XTickLabel', lab, 'XTickLabelRotation', 60, 'FontSize', 8);
xlim(ax, [0.5 n + 0.5]);
ylabel(ax, 'Predicted minus measured median (dB)');
xlabel(ax, 'OT/TRER 16 path number (frequency, MHz), sorted by frequency and distance');
title(ax, sprintf('Median basic transmission loss, %d measured U.S. paths from 1 GHz to 10 GHz', n));
xline(ax, nnz(listed) + 0.5, 'k--', 'Heights assumed', 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
legend(ax, 'Location', 'northwest'); grid(ax, 'on');
wp_save_fig(fig, out, 'fig12_trer16_median_error');

% Fig. 13: distributions on six paths from 2.3 GHz to 4.1 GHz
key = ["590", "591", "1609", "1712", "904", "1124A"];
fig = figure('Visible', 'off', 'Position', [0 0 1200 700]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
for kk = 1:numel(key)
    k = find(S.path == key(kk));
    ax = nexttile(tl); hold(ax, 'on');
    ok = isfinite(meas(k, :));
    plot(ax, P(ok), meas(k, ok), 'k-o', 'LineWidth', 2, 'MarkerFaceColor', 'k', 'DisplayName', 'Measured');
    plot(ax, P, itm(k, :), '-', 'Color', [0 0.447 0.698], 'LineWidth', 1.8, 'DisplayName', 'ITM v1.4');
    plot(ax, P, p452(k, :), '--', 'Color', [0.835 0.369 0], 'LineWidth', 1.8, 'DisplayName', 'P.452-18');
    plot(ax, P, p2001(k, :), '-.', 'Color', [0 0.620 0.451], 'LineWidth', 1.8, 'DisplayName', 'P.2001-6');
    set(ax, 'XScale', 'log', 'XTick', [1 10 50 99]);
    title(ax, sprintf('Path %s: %.0f MHz, %.0f km', key(kk), S.freq_mhz(k), S.d_km(k)), 'FontSize', 9);
    subtitle(ax, S.tx_name(k) + " to " + S.rx_name(k), 'FontSize', 8);
    xlabel(ax, 'Time percentage (%)');
    if mod(kk, 3) == 1, ylabel(ax, 'Basic transmission loss (dB)'); end
    if kk == 1, legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
wp_save_fig(fig, out, 'fig13_trer16_distributions');

% Fig. 20: median error against terrain irregularity
fig = figure('Visible', 'off', 'Position', [0 0 1200 400]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
mods = {itm, p452, p2001}; mn = ["ITM v1.4", "P.452-18", "P.2001-6"];
mc = [0 0.447 0.698; 0.835 0.369 0; 0 0.620 0.451];
for m = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    e = mods{m}(:, 3) - meas(:, 3);
    trans = itm_code > 0;
    scatter(ax, max(itm_dh(listed & trans), 5), e(listed & trans), 36, mc(m, :), 'filled', 'DisplayName', 'Beyond line of sight');
    scatter(ax, max(itm_dh(listed & ~trans), 5), e(listed & ~trans), 36, mc(m, :), 'DisplayName', 'Line of sight');
    for k = find(S.path == "321" | S.path == "1712")'
        text(ax, max(itm_dh(k), 5), e(k), "  " + S.path(k), 'FontSize', 8);
    end
    yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    set(ax, 'XScale', 'log'); ylim(ax, [-30 40]);
    title(ax, mn(m)); xlabel(ax, 'ITM terrain irregularity \Deltah (m)');
    if m == 1, ylabel(ax, 'Predicted minus measured median (dB)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
wp_save_fig(fig, out, 'fig20_trer16_error_vs_delta_h');

% Fig. 16: where the measured paths are
fig = figure('Visible', 'off', 'Position', [0 0 1100 560]);
gx = geoaxes(fig);
try
    geobasemap(gx, 'grayland');
catch
    geobasemap(gx, 'none');
end
hold(gx, 'on');
gnames = unique(grp)';
cols = [0.5 0.5 0.5; 0.835 0.369 0; 0 0.620 0.451; 0 0.447 0.698];
for g = 1:numel(gnames)
    first = true;
    for k = find(grp == gnames(g))'
        la = [dms(S.tx_lat(k)) dms(S.rx_lat(k))]; lo = [dms(S.tx_lon(k)) dms(S.rx_lon(k))];
        if first
            geoplot(gx, la, lo, '-', 'Color', cols(g, :), 'LineWidth', 2, 'DisplayName', gnames(g));
            first = false;
        else
            geoplot(gx, la, lo, '-', 'Color', cols(g, :), 'LineWidth', 2, 'HandleVisibility', 'off');
        end
    end
end
geolimits(gx, [24 50], [-125 -66]);
legend(gx, 'Location', 'southoutside', 'NumColumns', 4);
title(gx, 'Measured U.S. paths from 1 GHz to 10 GHz in OT/TRER 16, by frequency group');
wp_save_fig(fig, out, 'fig16_trer16_path_map');
end

function d = dms(s)
% "38 45 50 N" to decimal degrees
p = split(strtrim(s));
v = str2double(p(1:end - 1));
v(end + 1:3) = 0;
d = v(1) + v(2) / 60 + v(3) / 3600;
if any(p(end) == ["S", "W"]), d = -d; end
end
