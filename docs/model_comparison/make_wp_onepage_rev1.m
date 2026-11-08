function make_wp_onepage_rev1(options)
%MAKE_WP_ONEPAGE_REV1 Full-page figure options for the working paper's four main findings.
%   MAKE_WP_ONEPAGE_REV1() draws five chart designs for each of the paper's
%   four main findings, one full page each (6.5 in by 8 in), for the
%   author to choose from:
%     op1a-e  The models agree in line of sight and split beyond the
%             horizon (60 real-terrain links, 50 % of time)
%     op2a-e  The diffraction gap grows with frequency and terrain, and
%             ITM's double knife edge is most of it (diffraction links)
%     op3a-e  Against measurements, all three are close to unbiased at the
%             median from 1 GHz to 10 GHz (ITU-R SG3 databank)
%     op4a-e  The tails: the ITU models predict too little loss at small
%             time percentages (databank and real-terrain links)
%   Two options per set of maps color each path by how many dB the models
%   are apart, or how many dB a model is off the measurement, on the plasma
%   colormap with a colorbar.
%   No model runs; the script reads wp_results_rev1.mat and the CSV tables
%   that make_wp_figures_rev1, diffraction_decomposition_rev1, and
%   compare_dbsg3_rev1 write.
%
%   Style: NTIA palette and Times New Roman (slide-design skill), with the
%   plasma colormap for sequential scales (heat tables, frequency). Gray for
%   context, NTIA light blue for ITM (the model the findings are about),
%   dark blue for P.2001, gray for P.452 (which tracks P.2001), purple only
%   for an alert. Every series is labeled directly. The takeaway title,
%   caption, and source line go in the document, not the image.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
end
d = options.Dir;
C = palette();
s = load(fullfile(d, 'wp_results_rev1.mat'), 'R');
R = s.R;
E7 = R.E7; F = R.freqs_mhz; P = R.p; i50 = find(P == 50);
cls = classify(E7.itm_mech);                       % F-by-K: 0 LOS, 1 diffraction, 3 troposcatter
cname = ["Line of sight", "Diffraction", "Troposcatter"]; ccode = [0 1 3];
Dt = readtable(fullfile(d, 'table_diffraction_terms.csv'), 'TextType', 'string');
Ab = readtable(fullfile(d, 'table_diffraction_ablation.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
Db = readtable(fullfile(d, 'table_dbsg3_by_dataset_survey.csv'), 'TextType', 'string');
Db = Db(Db.kept == 1, :);
In = readtable(fullfile(fileparts(d), 'data', 'dbsg3', 'dbsg3_tableiii_30mhz_10ghz.csv'), 'TextType', 'string');
[~, ia] = ismember(Db.id, In.id);                    % site coordinates (WGS84) for the maps
Db.tx_lat = In.tx_lat(ia); Db.tx_lon = In.tx_lon(ia); Db.rx_lat = In.rx_lat(ia); Db.rx_lon = In.rx_lon(ia);
fl = string(arrayfun(@(f) sprintf('%g GHz', f / 1000), F, 'UniformOutput', false));

%% ===== Finding 1: agreement in line of sight, split beyond the horizon =====
gap = squeeze(E7.p2001(:, :, i50) - E7.itm(:, :, i50));     % F-by-K, P.2001 minus ITM

% 1a: strip plot by mechanism and frequency
[fig, ax] = page(); hold(ax, 'on');
y = 0; yt = []; ytl = strings(0);
for c = 3:-1:1
    for f = numel(F):-1:1
        y = y + 1;
        g = gap(f, cls(f, :) == ccode(c));
        jit = 0.25 * (rand(RandStream('mrg32k3a', 'Seed', y), size(g)) - 0.5);
        col = C.gray; if c > 1, col = C.lb; end
        scatter(ax, g, y + jit, 22, col, 'filled', 'MarkerFaceAlpha', 0.6);
        plot(ax, median(g), y, 'd', 'MarkerSize', 11, 'MarkerFaceColor', C.db, 'MarkerEdgeColor', 'w');
        text(ax, median(g), y + 0.38, sprintf('%.0f dB', median(g)), 'HorizontalAlignment', 'center', ...
            'FontSize', 9, 'Color', C.db, 'FontName', C.font);
        yt(end + 1) = y; ytl(end + 1) = cname(c) + ", " + fl(f); %#ok<AGROW>
    end
    y = y + 0.8;
end
xline(ax, 0, '-', 'Color', C.db, 'LineWidth', 1);
set(ax, 'YTick', yt, 'YTickLabel', ytl); ylim(ax, [0.3 y]);
xlabel(ax, {'P.2001 minus ITM at 50 % of time (dB)', 'Negative: ITM predicts more loss'});
note(ax, 0.02, 0.97, 'Each dot is one link; the diamond is the median', C);
style(ax, C);
save_page(fig, d, 'op1a_strip_by_mechanism');

% 1b: dumbbell of median excess loss, ITM against P.2001 and P.452
[fig, ax] = page(); hold(ax, 'on');
y = 0; yt = []; ytl = strings(0);
for c = 3:-1:1
    for f = numel(F):-1:1
        y = y + 1;
        sel = cls(f, :) == ccode(c);
        a = median(squeeze(E7.itm(f, sel, i50)) - fspl(E7, f, sel, F));
        b = median(squeeze(E7.p2001(f, sel, i50)) - fspl(E7, f, sel, F));
        q = median(squeeze(E7.p452(f, sel, i50)) - fspl(E7, f, sel, F));
        plot(ax, [b a], [y y], '-', 'Color', C.lgray, 'LineWidth', 5);
        plot(ax, q, y, 's', 'MarkerSize', 8, 'MarkerFaceColor', C.gray, 'MarkerEdgeColor', 'w');
        plot(ax, b, y, 'o', 'MarkerSize', 10, 'MarkerFaceColor', C.db, 'MarkerEdgeColor', 'w');
        plot(ax, a, y, 'o', 'MarkerSize', 10, 'MarkerFaceColor', C.lb, 'MarkerEdgeColor', 'w');
        if abs(a - b) > 4
            text(ax, (a + b) / 2, y + 0.35, sprintf('%.0f dB apart', abs(a - b)), 'HorizontalAlignment', 'center', ...
                'FontSize', 9, 'Color', C.db, 'FontName', C.font);
        end
        yt(end + 1) = y; ytl(end + 1) = cname(c) + ", " + fl(f); %#ok<AGROW>
    end
    y = y + 0.8;
end
set(ax, 'YTick', yt, 'YTickLabel', ytl); ylim(ax, [0.3 y + 0.6]);
xlabel(ax, 'Median loss above free space at 50 % of time (dB)');
legend_text(ax, [C.lb; C.db; C.gray], ["ITM", "P.2001", "P.452"], ["o", "o", "s"], C);
style(ax, C);
save_page(fig, d, 'op1b_dumbbell_excess_loss');

% 1c: map of the 60 links, colored by how far apart the models are (plasma, dB)
[fig, ~, tl] = page(numel(F), 1);
cm = ramp(C);
for f = 1:numel(F)
    gx = geoaxes(tl); gx.Layout.Tile = f;
    try, geobasemap(gx, 'grayland'); catch, geobasemap(gx, 'none'); end
    hold(gx, 'on');
    v = abs(gap(f, :));
    for k = 1:numel(v)
        ci = 1 + round(min(v(k), 60) / 60 * (size(cm, 1) - 1));
        geoplot(gx, [E7.links.tx_lat(k) E7.links.rx_lat(k)], [E7.links.tx_lon(k) E7.links.rx_lon(k)], '-', ...
            'Color', cm(ci, :), 'LineWidth', 2.5);
    end
    geolimits(gx, [37.4 39.8], [-80.6 -75]);
    gx.FontName = C.font; gx.FontSize = 9;
    title(gx, fl(f), 'FontWeight', 'normal', 'Color', C.db);
    colormap(gx, cm); clim(gx, [0 60]);
end
cb = colorbar(gx); cb.Layout.Tile = 'east';
cb.Label.String = '|P.2001 minus ITM| at 50 % of time (dB off)'; cb.FontName = C.font; cb.FontSize = 10; cb.Color = C.db;
save_page(fig, d, 'op1c_map_colored_by_gap');

% 1d: annotated heat table of the median gap
[fig, ax] = page(); hold(ax, 'on');
M = NaN(3, numel(F)); N = M;
for c = 1:3
    for f = 1:numel(F)
        sel = cls(f, :) == ccode(c);
        M(c, f) = median(gap(f, sel)); N(c, f) = nnz(sel);
    end
end
imagesc(ax, -M); colormap(ax, ramp(C)); clim(ax, [0 50]);
for c = 1:3
    for f = 1:numel(F)
        tc = [1 1 1]; if -M(c, f) > 30, tc = C.db; end
        text(ax, f, c, sprintf('%.0f dB', abs(round(-M(c, f)))), 'HorizontalAlignment', 'center', 'FontSize', 26, ...
            'FontWeight', 'bold', 'Color', tc, 'FontName', C.font);
        text(ax, f, c + 0.3, sprintf('%d links', N(c, f)), 'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'Color', tc, 'FontName', C.font);
    end
end
set(ax, 'XTick', 1:numel(F), 'XTickLabel', fl, 'YTick', 1:3, 'YTickLabel', cname, 'YDir', 'reverse', ...
    'XAxisLocation', 'top', 'FontName', C.font, 'FontSize', 12, 'TickLength', [0 0]);
axis(ax, 'tight'); box(ax, 'off'); ax.XColor = C.db; ax.YColor = C.db;
xlabel(ax, 'How much more loss ITM predicts than P.2001 (median, dB)');
ax.Position = [0.22 0.25 0.72 0.6];
save_page(fig, d, 'op1d_heat_table');

% 1e: box plots by mechanism, one panel per frequency
[fig, ~, tl] = page(1, 3);
for f = 1:numel(F)
    ax = nexttile(tl); hold(ax, 'on');
    for c = 1:3
        g = gap(f, cls(f, :) == ccode(c));
        col = C.gray; if c > 1, col = C.lb; end
        boxchart(ax, c * ones(size(g)), g, 'BoxFaceColor', col, 'MarkerColor', col, 'WhiskerLineColor', C.db, ...
            'LineWidth', 1.2, 'BoxWidth', 0.6);
    end
    yline(ax, 0, '-', 'Color', C.db);
    set(ax, 'XTick', 1:3, 'XTickLabel', ["LOS", "Diffr.", "Tropo."]); ylim(ax, [-110 20]); xlim(ax, [0.4 3.6]);
    title(ax, fl(f), 'FontWeight', 'normal');
    if f == 1, ylabel(ax, 'P.2001 minus ITM at 50 % of time (dB)'); end
    style(ax, C);
end
save_page(fig, d, 'op1e_boxes_by_frequency');

%% ===== Finding 2: the diffraction gap and its causes =====
% 2a: gap against terrain irregularity with binned medians
[fig, ax] = page(); hold(ax, 'on');
seq = ramp(C); fc = seq(round(linspace(20, 175, numel(F))), :);
ed = [0 25 50 100 200 400 800 2000];
for f = 1:numel(F)
    sel = cls(f, :) > 0;
    x = E7.itm_dh(sel); g = gap(f, sel);
    scatter(ax, max(x, 5), g, 26, fc(f, :), 'filled', 'MarkerFaceAlpha', 0.45);
    b = discretize(x, ed); mb = accumarray(b(:), g(:), [numel(ed) - 1 1], @median, NaN);
    xb = sqrt(ed(1:end-1) .* ed(2:end)); xb(1) = 12;
    ok = isfinite(mb);
    plot(ax, xb(ok), mb(ok), '-', 'Color', fc(f, :), 'LineWidth', 3);
    k = find(ok, 1, 'last');
    text(ax, xb(k) * 1.15, mb(k) + 3 * (f - 2), fl(f), 'Color', fc(f, :), 'FontWeight', 'bold', 'FontSize', 11, 'FontName', C.font);
end
yline(ax, 0, '-', 'Color', C.db);
set(ax, 'XScale', 'log'); xlim(ax, [5 3000]);
xlabel(ax, 'Terrain irregularity \Deltah (m), log scale'); ylabel(ax, 'P.2001 minus ITM at 50 % of time (dB)');
note(ax, 0.03, 0.08, 'Rougher terrain and higher frequency: bigger gap', C);
style(ax, C);
save_page(fig, d, 'op2a_gap_vs_terrain');

% 2b: waterfall, how much of the median gap each ITM ingredient explains
cases = ["ITM as is", "1 single edge", "4 all three"];
[fig, ~, tl] = page(numel(F), 1);
for f = 1:numel(F)
    ax = nexttile(tl); hold(ax, 'on');
    g = arrayfun(@(c) Ab.median_gap_db(Ab.freq_mhz == F(f) & Ab.("case") == c), cases);
    seg = [0 g(1); g(2) g(1); g(3) g(2); min(0, g(3)) max(0, g(3))];   % [from to] for each bar
    val = [g(1), g(2) - g(1), g(3) - g(2), g(3)];
    cols = [C.lb; C.gray; C.gray; C.db];
    lab = ["Median gap, ITM as published", "Use one knife edge, not two", ...
        "Drop the clutter term; evaluate at the path", "What remains"];
    for j = 1:4
        lo = min(seg(j, :)); w = abs(diff(seg(j, :)));
        rectangle(ax, 'Position', [lo j - 0.3 w 0.6], 'FaceColor', cols(j, :), 'EdgeColor', 'none');
        text(ax, max(seg(j, :)) + 1, j, sprintf('%+.0f dB', val(j)), 'FontSize', 11, 'Color', C.db, ...
            'FontName', C.font, 'FontWeight', 'bold');
        if j < 4
            plot(ax, seg(j, 1 + (j > 1)) * [1 1] .* [1 1], [j + 0.3 j + 0.7], ':', 'Color', C.db);
        end
    end
    set(ax, 'YTick', 1:4, 'YTickLabel', lab, 'YDir', 'reverse'); xlim(ax, [-15 58]); ylim(ax, [0.5 4.5]);
    title(ax, fl(f), 'FontWeight', 'normal');
    xline(ax, 0, '-', 'Color', C.db);
    if f == numel(F), xlabel(ax, 'ITM minus P.452 diffraction loss, median over diffraction links (dB)'); end
    style(ax, C, "horizontal");
end
save_page(fig, d, 'op2b_waterfall');

% 2c: slope chart across frequency for each ablation case
[fig, ax] = page(); hold(ax, 'on');
cases5 = ["ITM as is", "2 no clutter term", "3 evaluated at the path", "1 single edge", "4 all three"];
lab5 = ["ITM as published", "Without the clutter term", "Evaluated at the path", "One knife edge, not two", "All three removed"];
yl = NaN(1, numel(cases5));
for j = 1:numel(cases5)
    g = arrayfun(@(f) Ab.median_gap_db(Ab.freq_mhz == f & Ab.("case") == cases5(j)), F);
    yl(j) = g(end); if j > 1 && any(abs(yl(1:j-1) - yl(j)) < 2.5), yl(j) = yl(j) - 3; end
    col = C.gray; lw = 2;
    if j == 1, col = C.lb; lw = 4; elseif j == 4, col = C.db; lw = 3; end
    plot(ax, F / 1000, g, '-o', 'Color', col, 'LineWidth', lw, 'MarkerFaceColor', col, 'MarkerSize', 7);
    text(ax, F(end) / 1000 + 0.15, yl(j), lab5(j), 'Color', col, 'FontSize', 11, 'FontName', C.font, 'FontWeight', 'bold');
end
yline(ax, 0, '-', 'Color', C.db);
xlim(ax, [2.4 10.5]); set(ax, 'XTick', F / 1000);
xlabel(ax, 'Frequency (GHz)'); ylabel(ax, 'ITM minus P.452 diffraction loss, median (dB)');
style(ax, C);
save_page(fig, d, 'op2c_slope_by_ingredient');

% 2d: heat table of the median gap by terrain class and frequency
[fig, ax] = page(); hold(ax, 'on');
ed2 = [0 50 150 300 3000]; rl = ["Under 50 m", "50 m to 150 m", "150 m to 300 m", "Over 300 m"];
M = NaN(4, numel(F)); N = M;
for f = 1:numel(F)
    sel = cls(f, :) > 0;
    b = discretize(E7.itm_dh(sel), ed2); g = gap(f, sel);
    for r = 1:4
        M(r, f) = median(g(b == r)); N(r, f) = nnz(b == r);
    end
end
imagesc(ax, -M); colormap(ax, ramp(C)); clim(ax, [0 60]);
for r = 1:4
    for f = 1:numel(F)
        if N(r, f) == 0, continue, end
        tc = [1 1 1]; if -M(r, f) > 35, tc = C.db; end
        text(ax, f, r, sprintf('%.0f dB', -M(r, f)), 'HorizontalAlignment', 'center', 'FontSize', 24, 'FontWeight', 'bold', 'Color', tc, 'FontName', C.font);
        text(ax, f, r + 0.3, sprintf('%d links', N(r, f)), 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', tc, 'FontName', C.font);
    end
end
set(ax, 'XTick', 1:numel(F), 'XTickLabel', fl, 'YTick', 1:4, 'YTickLabel', rl, 'YDir', 'reverse', 'XAxisLocation', 'top', ...
    'FontName', C.font, 'FontSize', 12, 'TickLength', [0 0]);
axis(ax, 'tight'); box(ax, 'off'); ax.XColor = C.db; ax.YColor = C.db;
ylabel(ax, 'Terrain irregularity \Deltah'); xlabel(ax, 'How much more loss ITM predicts than P.2001 (median, dB)');
ax.Position = [0.22 0.25 0.72 0.6];
save_page(fig, d, 'op2d_heat_terrain_frequency');

% 2e: what each model's diffraction loss is made of (median, stacked)
[fig, ax] = page(); hold(ax, 'on');
y = 0; yt = []; ytl = strings(0);
for f = numel(F):-1:1
    q = Dt(Dt.freq_mhz == F(f), :);
    parts = [median(q.w_d3 .* q.A_se_d3), median((1 - q.w_d3) .* q.A_k_d3), median(q.A_fo)];
    pp = [median(q.Lbulla), median(max(q.Ldsph - q.Lbulls, 0))];
    y = y + 1; xs = 0; cols = [C.lgray; C.lb; C.pu];
    for j = 1:3
        rectangle(ax, 'Position', [xs y - 0.3 parts(j) 0.6], 'FaceColor', cols(j, :), 'EdgeColor', 'w', 'LineWidth', 1.5);
        xs = xs + parts(j);
    end
    text(ax, xs + 1, y, sprintf('%.0f dB', xs), 'FontSize', 11, 'Color', C.db, 'FontName', C.font, 'FontWeight', 'bold');
    yt(end + 1) = y; ytl(end + 1) = "ITM, " + fl(f); %#ok<AGROW>
    y = y + 1; xs = 0; cols = [C.db; C.gray];
    for j = 1:2
        rectangle(ax, 'Position', [xs y - 0.3 pp(j) 0.6], 'FaceColor', cols(j, :), 'EdgeColor', 'w', 'LineWidth', 1.5);
        xs = xs + pp(j);
    end
    text(ax, xs + 1, y, sprintf('%.0f dB', xs), 'FontSize', 11, 'Color', C.db, 'FontName', C.font, 'FontWeight', 'bold');
    yt(end + 1) = y; ytl(end + 1) = "P.452, " + fl(f); %#ok<AGROW>
    y = y + 0.8;
end
set(ax, 'YTick', yt, 'YTickLabel', ytl); ylim(ax, [0.2 y + 1.5]); xlim(ax, [0 135]);
xlabel(ax, 'Median diffraction loss and its terms, diffraction links (dB)');
legend_text(ax, [C.lgray; C.lb; C.pu; C.db; C.gray], ["ITM smooth earth (weighted)", "ITM two knife edges (weighted)", ...
    "ITM clutter term", "P.452 one knife edge", "P.452 spherical-earth excess"], ["s", "s", "s", "s", "s"], C);
style(ax, C, "horizontal");
save_page(fig, d, 'op2e_stacked_terms');

%% ===== Finding 3: measurements, error in the median =====
mods = ["itm", "p452", "p2001"]; mlab = ["ITM", "P.452", "P.2001"]; mcol = [C.lb; C.gray; C.db];
hi = Db.freq_mhz >= 1000;
bins = ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-3 GHz", "3-6 GHz", "6-10 GHz"];
err = @(m, p, sel) Db.(m + "_" + p)(sel) - Db.("meas_" + p)(sel);

% 3a: CDF of the error, 1 GHz to 10 GHz
[fig, ax] = page(); hold(ax, 'on');
patch(ax, [-10 10 10 -10], [0 0 1 1], C.panel, 'EdgeColor', 'none');
for m = [2 3 1]
    e = sort(err(mods(m), "50", hi)); e = e(isfinite(e));
    stairs(ax, e, (1:numel(e)) / numel(e), 'Color', mcol(m, :), 'LineWidth', 3 + (m == 1));
    w = mean(abs(e) <= 10);
    text(ax, 14, 0.15 + 0.06 * (3 - m), sprintf('%s: %.0f %% within 10 dB', mlab(m), 100 * w), ...
        'Color', mcol(m, :), 'FontWeight', 'bold', 'FontSize', 11, 'FontName', C.font);
end
xline(ax, 0, '-', 'Color', C.db);
xlim(ax, [-40 50]);
xlabel(ax, 'Predicted minus measured median loss (dB); positive means too much loss');
ylabel(ax, sprintf('Share of the %d measured datasets, 1 GHz to 10 GHz', nnz(hi)));
note(ax, 0.03, 0.95, 'Shaded: within 10 dB of the measurement', C);
style(ax, C);
save_page(fig, d, 'op3a_error_cdf');

% 3b: box plots by frequency band, one panel per model
[fig, ~, tl] = page(3, 1);
for m = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    for b = 1:numel(bins)
        sel = Db.bin == bins(b);
        e = err(mods(m), "50", sel); e = e(isfinite(e));
        if numel(e) < 3, continue, end
        col = C.gray; if b >= 4, col = mcol(m, :); end
        boxchart(ax, b * ones(size(e)), e, 'BoxFaceColor', col, 'MarkerColor', col, 'WhiskerLineColor', C.db, 'BoxWidth', 0.6);
    end
    yline(ax, 0, '-', 'Color', C.db);
    set(ax, 'XTick', 1:numel(bins), 'XTickLabel', bins); xlim(ax, [0.4 numel(bins) + 0.6]); ylim(ax, [-40 50]);
    ylabel(ax, mlab(m) + " error (dB)");
    style(ax, C);
end
save_page(fig, d, 'op3b_boxes_by_band');

% 3c: range bars (10th to 90th percentile) with the median, by band and model
[fig, ax] = page(); hold(ax, 'on');
y = 0; yt = []; ytl = strings(0);
for b = numel(bins):-1:1
    for m = 3:-1:1
        e = err(mods(m), "50", Db.bin == bins(b)); e = e(isfinite(e));
        y = y + 1;
        if numel(e) < 3, continue, end
        q = prctile(e, [10 50 90]);
        plot(ax, q([1 3]), [y y], '-', 'Color', mcol(m, :), 'LineWidth', 6);
        plot(ax, q(2), y, 'o', 'MarkerSize', 9, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', mcol(m, :), 'LineWidth', 2);
        yt(end + 1) = y; ytl(end + 1) = mlab(m); %#ok<AGROW>
    end
    text(ax, -58, y - 1, bins(b), 'FontWeight', 'bold', 'FontSize', 11, 'Color', C.db, 'FontName', C.font);
    y = y + 0.8;
end
xline(ax, 0, '-', 'Color', C.db);
set(ax, 'YTick', yt, 'YTickLabel', ytl); xlim(ax, [-60 45]); ylim(ax, [0.3 y]);
xlabel(ax, 'Predicted minus measured median loss (dB): bar spans 80 % of datasets, circle is the median');
style(ax, C, "horizontal");
save_page(fig, d, 'op3c_range_bars');

% 3d: heat table of mean error by band and model
[fig, ax] = page(); hold(ax, 'on');
M = NaN(numel(bins), 3); N = M;
for b = 1:numel(bins)
    for m = 1:3
        e = err(mods(m), "50", Db.bin == bins(b)); e = e(isfinite(e));
        if numel(e) >= 3, M(b, m) = mean(e); N(b, m) = numel(e); end
    end
end
imagesc(ax, M, 'AlphaData', isfinite(M)); colormap(ax, diverging(C)); clim(ax, [-8 8]);
for b = 1:numel(bins)
    for m = 1:3
        if isnan(M(b, m))
            text(ax, m, b, 'not defined', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', C.gray, 'FontName', C.font);
            continue
        end
        tc = C.db; if abs(M(b, m)) > 5.5, tc = [1 1 1]; end
        text(ax, m, b, sprintf('%+.1f dB', M(b, m)), 'HorizontalAlignment', 'center', 'FontSize', 20, 'FontWeight', 'bold', 'Color', tc, 'FontName', C.font);
        text(ax, m, b + 0.3, sprintf('%d datasets', N(b, m)), 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', tc, 'FontName', C.font);
    end
end
set(ax, 'XTick', 1:3, 'XTickLabel', mlab, 'YTick', 1:numel(bins), 'YTickLabel', bins, 'YDir', 'reverse', 'XAxisLocation', 'top', ...
    'FontName', C.font, 'FontSize', 12, 'TickLength', [0 0]);
axis(ax, 'tight'); box(ax, 'off'); ax.XColor = C.db; ax.YColor = C.db;
xlabel(ax, {'Mean predicted minus measured median loss (dB)', 'Blue: too little loss; purple: too much'});
ax.Position = [0.2 0.12 0.74 0.76];
save_page(fig, d, 'op3d_heat_bias');

% 3e: where each model misses: databank paths colored by |error| (plasma, dB off)
[fig, ~, tl] = page(3, 1);
cm = ramp(C);
for m = 1:3
    gx = geoaxes(tl); gx.Layout.Tile = m;
    try, geobasemap(gx, 'grayland'); catch, geobasemap(gx, 'none'); end
    hold(gx, 'on');
    e = abs(Db.(mods(m) + "_50") - Db.meas_50);
    [~, o] = sort(e);
    for k = o(:)'
        if ~isfinite(e(k)), continue, end
        ci = 1 + round(min(e(k), 20) / 20 * (size(cm, 1) - 1));
        geoplot(gx, [Db.tx_lat(k) Db.rx_lat(k)], [Db.tx_lon(k) Db.rx_lon(k)], '-', 'Color', cm(ci, :), 'LineWidth', 2);
    end
    geolimits(gx, [20 62], [-125 145]);
    gx.FontName = C.font; gx.FontSize = 9;
    title(gx, mlab(m) + sprintf(' (median %.1f dB off)', median(e, 'omitnan')), 'FontWeight', 'normal', 'Color', C.db);
    colormap(gx, cm); clim(gx, [0 20]);
end
cb = colorbar(gx); cb.Layout.Tile = 'east';
cb.Label.String = '|Predicted minus measured median| (dB off), 30 MHz to 10 GHz'; cb.FontName = C.font; cb.FontSize = 10; cb.Color = C.db;
save_page(fig, d, 'op3e_map_colored_by_error');

%% ===== Finding 4: the tails =====
pc = ["01", "10", "50", "90", "99"]; pv = [1 10 50 90 99];

% 4a: mean error against time percentage, 1 GHz to 10 GHz
[fig, ax] = page(); hold(ax, 'on');
patch(ax, [0.8 120 120 0.8], [-3 -3 3 3], C.panel, 'EdgeColor', 'none');
for m = [2 3 1]
    v = arrayfun(@(j) mean(err(mods(m), pc(j), hi), 'omitnan'), 1:5);
    ok = isfinite(v);
    plot(ax, pv(ok), v(ok), '-o', 'Color', mcol(m, :), 'LineWidth', 3 + (m == 1), 'MarkerFaceColor', mcol(m, :), 'MarkerSize', 8);
    k = find(ok, 1, 'last');
    text(ax, pv(k) * 1.12, v(k) + 0.5 * (m - 2), mlab(m), 'Color', mcol(m, :), 'FontWeight', 'bold', 'FontSize', 12, 'FontName', C.font);
end
yline(ax, 0, '-', 'Color', C.db);
set(ax, 'XScale', 'log', 'XTick', [1 10 50 99]); xlim(ax, [0.8 160]); ylim(ax, [-14 6]);
xlabel(ax, 'Percentage of time the loss is not exceeded'); ylabel(ax, 'Mean predicted minus measured loss, 1 GHz to 10 GHz (dB)');
note(ax, 0.03, 0.08, 'Below zero at 1 %: the model predicts the signal is stronger than measured', C);
note(ax, 0.03, 0.95, 'Shaded: within 3 dB', C);
style(ax, C);
save_page(fig, d, 'op4a_bias_vs_time');

% 4b: heat tables, mean error by band and time percentage, one per model
[fig, ~, tl] = page(3, 1);
for m = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    M = NaN(numel(bins), 5);
    for b = 1:numel(bins)
        for j = 1:5
            e = err(mods(m), pc(j), Db.bin == bins(b)); e = e(isfinite(e));
            if numel(e) >= 3, M(b, j) = mean(e); end
        end
    end
    imagesc(ax, M, 'AlphaData', isfinite(M)); colormap(ax, diverging(C)); clim(ax, [-15 15]);
    for b = 1:numel(bins)
        for j = 1:5
            if isnan(M(b, j)), continue, end
            tc = C.db; if abs(M(b, j)) > 10, tc = [1 1 1]; end
            text(ax, j, b, sprintf('%+.0f', M(b, j)), 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold', 'Color', tc, 'FontName', C.font);
        end
    end
    set(ax, 'XTick', 1:5, 'XTickLabel', compose('%g %%', pv), 'YTick', 1:numel(bins), 'YTickLabel', bins, 'YDir', 'reverse', ...
        'FontName', C.font, 'FontSize', 10, 'TickLength', [0 0]);
    axis(ax, 'tight'); box(ax, 'off'); ax.XColor = C.db; ax.YColor = C.db;
    title(ax, mlab(m) + " (mean error, dB; blue too little loss, purple too much)", 'FontWeight', 'normal', 'Color', C.db);
end
save_page(fig, d, 'op4b_heat_bias_by_time');

% 4c: dumbbell, mean error at 50 % and at 1 %, by band and model
[fig, ax] = page(); hold(ax, 'on');
y = 0; yt = []; ytl = strings(0);
for b = numel(bins):-1:1
    for m = 3:-1:1
        e50 = mean(err(mods(m), "50", Db.bin == bins(b)), 'omitnan');
        e1 = mean(err(mods(m), "01", Db.bin == bins(b)), 'omitnan');
        y = y + 1;
        if ~isfinite(e50) || ~isfinite(e1), continue, end
        plot(ax, [e50 e1], [y y], '-', 'Color', C.lgray, 'LineWidth', 4);
        plot(ax, e50, y, 'o', 'MarkerSize', 9, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', mcol(m, :), 'LineWidth', 2);
        plot(ax, e1, y, 'o', 'MarkerSize', 9, 'MarkerFaceColor', mcol(m, :), 'MarkerEdgeColor', 'w');
        yt(end + 1) = y; ytl(end + 1) = mlab(m); %#ok<AGROW>
    end
    text(ax, -27, y - 1, bins(b), 'FontWeight', 'bold', 'FontSize', 11, 'Color', C.db, 'FontName', C.font);
    y = y + 0.8;
end
xline(ax, 0, '-', 'Color', C.db);
set(ax, 'YTick', yt, 'YTickLabel', ytl); xlim(ax, [-28 14]); ylim(ax, [0.3 y]);
xlabel(ax, 'Mean predicted minus measured loss (dB): open circle at 50 %, filled at 1 % of time');
style(ax, C, "horizontal");
save_page(fig, d, 'op4c_dumbbell_median_vs_1pct');

% 4d: how deep the 1 % enhancement is: measured against each model
[fig, ax] = page(); hold(ax, 'on');
depth = @(m) Db.(m + "_50")(hi) - Db.(m + "_01")(hi);
vals = {Db.meas_50(hi) - Db.meas_01(hi), depth("itm"), depth("p452"), depth("p2001")};
lab = ["Measured", "ITM", "P.452", "P.2001"]; cols = [0.1 0.1 0.1; C.lb; C.gray; C.db];
for j = 1:4
    v = vals{j}; v = v(isfinite(v));
    jit = 0.3 * (rand(RandStream('mrg32k3a', 'Seed', j), size(v)) - 0.5);
    mk = 'o'; if j == 1, mk = 'd'; end
    scatter(ax, j + jit, v, 22, cols(j, :), mk, 'filled', 'MarkerFaceAlpha', 0.5);
    plot(ax, j + [-0.3 0.3], median(v) * [1 1], '-', 'Color', C.db, 'LineWidth', 3);
    text(ax, j + 0.33, median(v), sprintf('%.0f dB', median(v)), 'FontSize', 11, 'FontWeight', 'bold', 'Color', C.db, 'FontName', C.font);
end
set(ax, 'XTick', 1:4, 'XTickLabel', lab); xlim(ax, [0.4 4.8]); ylim(ax, [0 max(cellfun(@(v) max(v(isfinite(v))), vals)) + 3]);
ylabel(ax, 'Loss at 50 % minus loss at 1 % of time, 1 GHz to 10 GHz (dB)');
note(ax, 0.03, 0.95, 'How much stronger the signal gets 1 % of the time; line is the median', C);
style(ax, C);
save_page(fig, d, 'op4d_enhancement_depth');

% 4e: real-terrain links, model difference against time percentage
[fig, ax] = page(); hold(ax, 'on');
for f = 1:numel(F)
    v = arrayfun(@(j) median(E7.p2001(f, :, j) - E7.itm(f, :, j)), 1:numel(P));
    plot(ax, P, v, '-', 'Color', fc(f, :), 'LineWidth', 3);
    text(ax, 0.0012, v(1) + 1.2 * (f - 2), fl(f), 'Color', fc(f, :), 'FontWeight', 'bold', 'FontSize', 11, 'FontName', C.font);
end
yline(ax, 0, '-', 'Color', C.db);
set(ax, 'XScale', 'log', 'XTick', [0.001 0.01 0.1 1 10 50]); xlim(ax, [0.001 100]);
xlabel(ax, 'Percentage of time the loss is not exceeded'); ylabel(ax, 'P.2001 minus ITM, median over 60 real-terrain links (dB)');
note(ax, 0.03, 0.08, 'At small percentages, ducting in P.2001 cuts its loss well below ITM''s', C);
style(ax, C);
save_page(fig, d, 'op4e_model_gap_vs_time');
end

%% ========================================================================
function C = palette()
C.db = [22 51 83] / 255;      % NTIA dark blue: text, P.2001
C.lb = [86 116 196] / 255;    % NTIA light blue: the highlight (ITM)
C.pu = [110 79 146] / 255;    % NTIA purple: alert or second highlight
C.gray = [138 141 145] / 255; % mid gray: context, P.452
C.lgray = [200 202 205] / 255;
C.panel = [232 233 234] / 255;
C.grid = [230 230 230] / 255;
C.font = 'Times New Roman';
end

function m = ramp(C) %#ok<INUSD>
% Sequential scale: plasma (Nick's preferred colormap; perceptually uniform
% and colorblind-safe), stopped short of its palest yellow so the top of the
% scale still shows on white
m = plasma(256);
m = m(1:230, :);
end

function m = diverging(C)
% Dark blue (too little loss) - light gray - purple (too much loss)
k = [C.db; [232 233 234] / 255; C.pu];
m = interp1([0 0.5 1], k, linspace(0, 1, 256));
end

function c = classify(codes)
c = NaN(size(codes));
c(codes == 0) = 0;
c(ismember(codes, [4 5 8 9])) = 1;
c(ismember(codes, [6 10])) = 3;
end

function v = fspl(E7, f, sel, F)
d = E7.links.length_km(sel)';
v = 32.45 + 20 * log10(F(f)) + 20 * log10(d);
end

function [fig, ax, tl] = page(r, c)
% One full page: 6.5 in by 8 in
fig = figure('Visible', 'off', 'Units', 'inches', 'Position', [0 0 6.5 8], 'Color', 'w');
if nargin == 0
    ax = axes(fig, 'Position', [0.24 0.1 0.72 0.86]); tl = [];
else
    tl = tiledlayout(fig, r, c, 'TileSpacing', 'compact', 'Padding', 'compact'); ax = [];
end
end

function style(ax, C, orient)
if nargin < 3, orient = "vertical"; end
box(ax, 'off');
ax.FontName = C.font; ax.FontSize = 11;
ax.XColor = C.db; ax.YColor = C.db; ax.TickLength = [0 0];
ax.GridColor = C.grid; ax.GridAlpha = 1;
if orient == "horizontal"
    ax.XGrid = 'on'; ax.YGrid = 'off';
else
    ax.YGrid = 'on'; ax.XGrid = 'off';
end
end

function note(ax, x, y, s, C)
text(ax, x, y, s, 'Units', 'normalized', 'FontSize', 10, 'Color', C.db, 'FontName', C.font, 'FontAngle', 'italic');
end

function legend_text(ax, cols, labels, ~, C)
% A small key at the top of the axes, two entries per row; each entry has
% its marker in the series color and its name in dark blue (not color alone)
for j = 1:numel(labels)
    x = 0.02 + 0.48 * mod(j - 1, 2); y = 0.985 - 0.04 * floor((j - 1) / 2);
    text(ax, x, y, char(9632), 'Units', 'normalized', 'Color', cols(j, :), 'FontSize', 14, ...
        'FontName', C.font, 'VerticalAlignment', 'middle');
    text(ax, x + 0.035, y, labels(j), 'Units', 'normalized', 'Color', C.db, 'FontSize', 10, ...
        'FontName', C.font, 'VerticalAlignment', 'middle');
end
end

function save_page(fig, d, name)
if exist('theme', 'file') || exist('theme', 'builtin'), theme(fig, 'light'); end
set(fig, 'Color', 'w');
exportgraphics(fig, fullfile(d, name + ".png"), 'Resolution', 220);
close(fig);
end
