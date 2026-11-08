function export_wp_chart_data_rev1(options)
%EXPORT_WP_CHART_DATA_REV1 Write the data behind the working paper's full-page charts as CSV.
%   EXPORT_WP_CHART_DATA_REV1() reads wp_results_rev1.mat (written by
%   make_wp_figures_rev1) and writes, to docs/model_comparison/chart_data:
%     real_terrain_links.csv     one row per real-terrain link: region,
%                                coordinates, length, antenna heights, and
%                                ITM's terrain irregularity delta_h
%     real_terrain_by_link.csv   one row per link and study frequency: ITM
%                                mechanism class, free-space loss, and the
%                                three models' loss at 50 % of time
%     real_terrain_gap_by_time.csv  median P.2001 minus ITM and P.452 minus
%                                ITM over the links, by frequency and time
%                                percentage (all 30 percentages)
%     basemap_coastlines.csv     world coastlines (Mapping Toolbox
%                                coastlines.mat), NaN-separated, for maps
%     basemap_us_states.csv      U.S. state outlines (Mapping Toolbox
%                                usastatelo.shp), NaN-separated
%   The other chart data (diffraction terms and ablation, ITU-R databank
%   results) are already CSV tables in figures/; make_wp_charts_rev1.py
%   reads those directly. No model runs.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
end
s = load(fullfile(options.Dir, 'wp_results_rev1.mat'), 'R');
R = s.R; E7 = R.E7; F = R.freqs_mhz; P = R.p; i50 = find(P == 50);
if ~isfolder(options.OutDir), mkdir(options.OutDir); end

L = E7.links;
L.link = (1:height(L))';
L.delta_h_m = E7.itm_dh(:);
L = movevars(L, 'link', 'Before', 1);
writetable(L, fullfile(options.OutDir, 'real_terrain_links.csv'));

K = height(L);
rows = {};
for f = 1:numel(F)
    for k = 1:K
        code = E7.itm_mech(f, k);
        cls = "Line of sight";
        if ismember(code, [4 5 8 9]), cls = "Diffraction"; elseif ismember(code, [6 10]), cls = "Troposcatter"; end
        fsl = 32.45 + 20 * log10(F(f)) + 20 * log10(L.length_km(k));
        rows(end + 1, :) = {k, F(f), code, cls, fsl, E7.itm(f, k, i50), E7.p452(f, k, i50), E7.p2001(f, k, i50)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'link', 'freq_mhz', 'itm_mode_code', 'itm_class', 'free_space_db', ...
    'itm_50_db', 'p452_50_db', 'p2001_50_db'});
writetable(T, fullfile(options.OutDir, 'real_terrain_by_link.csv'));

rows = {};
for f = 1:numel(F)
    for j = 1:numel(P)
        g1 = median(E7.p2001(f, :, j) - E7.itm(f, :, j));
        g2 = median(E7.p452(f, :, j) - E7.itm(f, :, j));
        rows(end + 1, :) = {F(f), P(j), g1, g2}; %#ok<AGROW>
    end
end
G = cell2table(rows, 'VariableNames', {'freq_mhz', 'time_pct', 'p2001_minus_itm_median_db', 'p452_minus_itm_median_db'});
writetable(G, fullfile(options.OutDir, 'real_terrain_gap_by_time.csv'));

% Basemaps for the Python charts (no map download there)
c = load('coastlines', 'coastlat', 'coastlon');
writetable(table(c.coastlat, c.coastlon, 'VariableNames', {'lat', 'lon'}), fullfile(options.OutDir, 'basemap_coastlines.csv'));
st = shaperead('usastatelo', 'UseGeoCoords', true);
la = []; lo = [];
for k = 1:numel(st)
    la = [la; st(k).Lat(:); NaN]; lo = [lo; st(k).Lon(:); NaN]; %#ok<AGROW>
end
writetable(table(la, lo, 'VariableNames', {'lat', 'lon'}), fullfile(options.OutDir, 'basemap_us_states.csv'));
end
