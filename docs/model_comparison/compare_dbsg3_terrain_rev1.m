function C = compare_dbsg3_terrain_rev1(options)
%COMPARE_DBSG3_TERRAIN_REV1 Surveyed profiles against 30 m terrain on the databank paths.
%   C = COMPARE_DBSG3_TERRAIN_REV1() reads the two runs of
%   compare_dbsg3_rev1 (Terrain="survey" and Terrain="dem") and shows what
%   the terrain source and the site correction do:
%     fig30_dbsg3_terrain_and_sites.png
%       left   30 m terrain minus surveyed ground elevation at each
%              terminal, at the listed coordinates and after the site
%              correction
%       right  RMS error in the median on the datasets both runs kept:
%              30 m terrain at the listed coordinates, 30 m terrain with
%              corrected sites, and the surveyed profiles
%   and returns the numbers behind the right panel (also written as
%   table_dbsg3_terrain_comparison.csv). No model runs.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
end
d = options.Dir;
Sv = readtable(fullfile(d, 'table_dbsg3_by_dataset_survey.csv'), 'TextType', 'string');
Dm = readtable(fullfile(d, 'table_dbsg3_by_dataset_dem.csv'), 'TextType', 'string');
[~, is, id] = intersect(Sv.id, Dm.id, 'stable');
Sv = Sv(is, :); Dm = Dm(id, :);
both = Sv.kept == 1 & isfinite(Dm.itm_50) & isfinite(Dm.itm_50_uncorrected) & ...
    ~Dm.bad_coords & ~Dm.bad_profile;
mn = ["ITM v1.4", "P.452-18", "P.2001-6"]; col = ["itm", "p452", "p2001"];
rows = {};
for m = 1:3
    e0 = Dm.(col(m) + "_50_uncorrected")(both) - Dm.meas_50(both);
    e1 = Dm.(col(m) + "_50")(both) - Dm.meas_50(both);
    e2 = Sv.(col(m) + "_50")(both) - Sv.meas_50(both);
    ok = isfinite(e0) & isfinite(e1) & isfinite(e2);
    rows(end + 1, :) = {mn(m), nnz(ok), rms(e0(ok)), rms(e1(ok)), rms(e2(ok)), mean(e0(ok)), mean(e1(ok)), mean(e2(ok))}; %#ok<AGROW>
end
C = cell2table(rows, 'VariableNames', {'model', 'n', 'rms_dem_listed', 'rms_dem_corrected', 'rms_survey', ...
    'mean_dem_listed', 'mean_dem_corrected', 'mean_survey'});
writetable(C, fullfile(d, 'table_dbsg3_terrain_comparison.csv'));

mc = [0 0.447 0.698];
fig = figure('Visible', 'off', 'Position', [0 0 1200 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
ax = nexttile(tl); hold(ax, 'on');
[~, iu] = unique(Dm.path(Dm.has_profile == 1));
q = Dm(Dm.has_profile == 1, :); q = q(iu, :);
b0 = [q.tx_dz_before_m; q.rx_dz_before_m]; b1 = [q.tx_dz_after_m; q.rx_dz_after_m];
ed = -300:10:300;
histogram(ax, max(min(b0, 300), -300), ed, 'FaceColor', [0.7 0.7 0.7], 'DisplayName', 'Listed coordinates');
histogram(ax, max(min(b1, 300), -300), ed, 'FaceColor', mc, 'FaceAlpha', 0.7, 'DisplayName', 'After site correction');
xlabel(ax, '30 m terrain minus surveyed ground elevation (m)'); ylabel(ax, 'Terminals');
title(ax, 'Terminal elevation: terrain model against survey'); legend(ax, 'Location', 'northwest'); grid(ax, 'on');
ax = nexttile(tl);
h = bar(ax, categorical(mn, mn), [C.rms_dem_listed C.rms_dem_corrected C.rms_survey]);
h(1).FaceColor = [0.7 0.7 0.7]; h(2).FaceColor = mc; h(3).FaceColor = [0 0.620 0.451];
ylabel(ax, 'RMS error in the median (dB)');
legend(ax, {'30 m terrain, listed sites', '30 m terrain, corrected sites', 'Surveyed profiles'}, 'Location', 'northoutside', 'NumColumns', 3);
title(ax, sprintf('Same %d datasets, 1 GHz to 10 GHz', C.n(1))); grid(ax, 'on');
wp_save_fig(fig, d, 'fig30_dbsg3_terrain_and_sites');
end
