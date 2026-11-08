function make_wp_summary_figures_rev1(options)
%MAKE_WP_SUMMARY_FIGURES_REV1 Figures that replace tables in the working paper.
%   MAKE_WP_SUMMARY_FIGURES_REV1() reads the CSV tables that
%   make_wp_figures_rev1 writes and draws them as figures, so the paper can
%   show them instead of tables:
%     fig17_median_gap_vs_time.png   median P.2001 and P.452 minus ITM over
%                                    the real-terrain links, against time %
%     fig18_archetype_summary.png    archetype paths: loss at 50 % and 1 %,
%                                    and the 1 % to 99 % spread
%     fig19_knife_edge_error.png     mean absolute difference from P.526 J(v)
%   Run it after make_wp_figures_rev1. No model runs; takes seconds.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
end
d = options.Dir;
blue = [0 0.447 0.698]; ver = [0.835 0.369 0]; grn = [0 0.620 0.451];

% Fig. 17
T = readtable(fullfile(d, 'table_real_terrain_by_percentage.csv'));
F = unique(T.freq_mhz)';
fig = figure('Visible', 'off', 'Position', [0 0 1200 380]);
tl = tiledlayout(fig, 1, numel(F), 'TileSpacing', 'compact');
for f = 1:numel(F)
    s = T(T.freq_mhz == F(f), :);
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, s.time_pct, s.p2001_minus_itm_med_db, '-o', 'Color', grn, 'LineWidth', 1.8, 'MarkerFaceColor', grn, 'DisplayName', 'P.2001 minus ITM');
    plot(ax, s.time_pct, s.p452_minus_itm_med_db, '--s', 'Color', ver, 'LineWidth', 1.8, 'DisplayName', 'P.452 minus ITM');
    yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    set(ax, 'XScale', 'log');
    title(ax, sprintf('%g MHz, all real-terrain links', F(f)));
    xlabel(ax, 'Time percentage (%)');
    if f == 1, ylabel(ax, 'Median difference from ITM (dB)'); legend(ax, 'Location', 'southeast'); end
    grid(ax, 'on');
end
wp_save_fig(fig, d, 'fig17_median_gap_vs_time');

% Fig. 18
A = readtable(fullfile(d, 'table_archetypes.csv'), 'TextType', 'string');
paths = unique(A.path, 'stable')';
fig = figure('Visible', 'off', 'Position', [0 0 1200 420]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
sel = A.freq_mhz == 2700;
a = A(sel, :);
[~, ix] = ismember(paths, a.path);
a = a(ix, :);
titles = ["Loss at 50 % of time", "Loss at 1 % of time", "Spread, 1 % to 99 % of time"];
data = {[a.itm_50 a.p452_50 a.p2001_50], [a.itm_1 a.p452_1 a.p2001_1], [a.itm_spread_1_99 NaN(height(a), 1) a.p2001_spread_1_99]};
for t = 1:3
    ax = nexttile(tl);
    b = barh(ax, data{t});
    b(1).FaceColor = blue; b(2).FaceColor = ver; b(3).FaceColor = grn;
    set(ax, 'YTick', 1:numel(paths), 'YTickLabel', paths, 'YDir', 'reverse');
    if t > 1, set(ax, 'YTickLabel', []); end
    xlabel(ax, 'dB'); title(ax, titles(t)); grid(ax, 'on');
    if t == 1
        legend(ax, {'ITM v1.4', 'P.452-18', 'P.2001-6'}, 'Location', 'southoutside', 'NumColumns', 3);
    end
    if t == 3, subtitle(ax, 'P.452 is defined only to 50 %', 'FontSize', 8); end
end
title(tl, 'Archetype paths at 2.7 GHz');
wp_save_fig(fig, d, 'fig18_archetype_summary');

% Fig. 19
K = readtable(fullfile(d, 'table_knife_edge.csv'));
fig = figure('Visible', 'off', 'Position', [0 0 700 340]);
ax = axes(fig);
b = bar(ax, categorical(compose('%g MHz', K.freq_mhz)), [K.itm_mae_db K.p452_mae_db K.p2001_mae_db]);
b(1).FaceColor = blue; b(2).FaceColor = ver; b(3).FaceColor = grn;
ylabel(ax, 'Mean |model - J(v)|, v >= 0 (dB)');
legend(ax, {'ITM v1.4', 'P.452-18', 'P.2001-6'}, 'Location', 'northoutside', 'NumColumns', 3);
title(ax, 'Single knife edge: difference from ITU-R P.526 J(v)'); grid(ax, 'on');
wp_save_fig(fig, d, 'fig19_knife_edge_error');
end
