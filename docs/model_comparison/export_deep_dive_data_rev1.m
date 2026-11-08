function export_deep_dive_data_rev1(options)
%EXPORT_DEEP_DIVE_DATA_REV1 Write the model results behind the paper's figures as CSV.
%   EXPORT_DEEP_DIVE_DATA_REV1() reads figures/wp_results_rev1.mat (written
%   by make_wp_figures_rev1; no model runs) and writes, to chart_data/:
%     real_terrain_by_link.csv     the 60 links: ITM mode and class, free
%                                  space, and each model's loss at 50 %
%     real_terrain_gap_by_time.csv median P.2001 minus ITM and P.452 minus
%                                  ITM by frequency and time percentage
%     terrain_resolution_by_link.csv  the diffraction links on 30 m, 90 m,
%                                  and 1 km smoothed profiles
%     deep_smooth_earth.csv        smooth earth, land and sea, at 50 %
%     deep_smooth_earth_time.csv   smooth earth at all 30 percentages, with
%                                  the dominant P.452 and P.2001 mechanism
%                                  (0 line of sight, 1 diffraction,
%                                  2 anomalous, 3 troposcatter, 4 sporadic-E)
%     deep_radials.csv             four real-terrain radials, 1 % and 50 %
%     deep_time_by_link.csv        the 60 links at all 30 percentages
%     deep_archetype_profiles.csv  terrain profiles of the five archetypes
%     deep_archetype_time.csv      the archetypes at all 30 percentages
%     deep_itm_climate.csv         ITM on the double-horizon archetype by
%                                  radio climate and by N0
%     deep_knife_edge.csv          single raised point: v, J(v), each model
%     deep_freq_sweep.csv          three archetypes, 100 MHz to 10 GHz
%   real_terrain_links.csv (the link table) is written by
%   export_wp_chart_data_rev1 and does not change.
%
%   Options: Dir (folder of wp_results_rev1.mat), OutDir.

arguments
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
end
s = load(fullfile(options.Dir, 'wp_results_rev1.mat'), 'R');
R = s.R; F = R.freqs_mhz(:)'; P = R.p(:)'; i50 = find(P == 50);
out = options.OutDir; if ~isfolder(out), mkdir(out); end
M = ["itm", "p452", "p2001"];
cls = @(c) string(ifelse(ismember(c, [4 5 8 9]), "Diffraction", ifelse(ismember(c, [6 10]), "Troposcatter", "Line of sight")));

% ---- real-terrain links at 50 % ----
links = readtable(fullfile(out, 'real_terrain_links.csv'));
E7 = R.E7; K = size(E7.itm, 2);
rows = {};
for fi = 1:numel(F)
    for k = 1:K
        code = E7.itm_mech(fi, k);
        rows(end + 1, :) = {k, F(fi), code, cls(code), 32.45 + 20 * log10(F(fi)) + 20 * log10(links.length_km(k)), ...
            E7.itm(fi, k, i50), E7.p452(fi, k, i50), E7.p2001(fi, k, i50)}; %#ok<AGROW>
    end
end
wt(rows, {'link', 'freq_mhz', 'itm_mode_code', 'itm_class', 'free_space_db', 'itm_50_db', 'p452_50_db', 'p2001_50_db'}, out, 'real_terrain_by_link.csv');

rows = {};
for fi = 1:numel(F)
    for j = 1:numel(P)
        rows(end + 1, :) = {F(fi), P(j), median(E7.p2001(fi, :, j) - E7.itm(fi, :, j)), median(E7.p452(fi, :, j) - E7.itm(fi, :, j))}; %#ok<AGROW>
    end
end
wt(rows, {'freq_mhz', 'time_pct', 'p2001_minus_itm_median_db', 'p452_minus_itm_median_db'}, out, 'real_terrain_gap_by_time.csv');

rows = {};
for fi = 1:numel(F)
    for k = 1:K
        for j = 1:numel(P)
            rows(end + 1, :) = {k, F(fi), P(j), E7.itm_mech(fi, k), E7.itm(fi, k, j), E7.p452(fi, k, j), E7.p2001(fi, k, j)}; %#ok<AGROW>
        end
    end
end
wt(rows, {'link', 'freq_mhz', 'time_pct', 'itm_mode_code', 'itm_db', 'p452_db', 'p2001_db'}, out, 'deep_time_by_link.csv');

% ---- terrain resolution ----
E3 = R.E3; rn = ["30 m", "90 m", "1 km smoothed"]; rows = {};
for j = 1:numel(E3.links)
    for v = 1:3
        rows(end + 1, :) = {E3.links(j), rn(v), F(1), E3.itm(j, v), E3.p452(j, v), E3.p2001(j, v), E3.dh(j, v)}; %#ok<AGROW>
    end
end
wt(rows, {'link', 'resolution', 'freq_mhz', 'itm_50_db', 'p452_50_db', 'p2001_50_db', 'delta_h_m'}, out, 'terrain_resolution_by_link.csv');

% ---- smooth earth ----
rows = {}; rows2 = {};
for surf = ["land", "sea"]
    c = R.E1.(surf);
    for fi = 1:numel(F)
        for di = 1:numel(R.E1.D_km)
            rows(end + 1, :) = {surf, F(fi), R.E1.D_km(di), R.E1.fsl(fi, di), c.itm_mech(fi, di), ...
                c.itm(fi, di, i50), c.p452(fi, di, i50), c.p2001(fi, di, i50)}; %#ok<AGROW>
            for j = 1:numel(P)
                rows2(end + 1, :) = {surf, F(fi), R.E1.D_km(di), P(j), R.E1.fsl(fi, di), c.itm(fi, di, j), c.p452(fi, di, j), ...
                    c.p2001(fi, di, j), c.p452_mech(fi, di, j), c.p2001_mech(fi, di, j)}; %#ok<AGROW>
            end
        end
    end
end
wt(rows, {'surface', 'freq_mhz', 'd_km', 'free_space_db', 'itm_mode_code', 'itm_50_db', 'p452_50_db', 'p2001_50_db'}, out, 'deep_smooth_earth.csv');
wt(rows2, {'surface', 'freq_mhz', 'd_km', 'time_pct', 'free_space_db', 'itm_db', 'p452_db', 'p2001_db', 'p452_mech', 'p2001_mech'}, out, 'deep_smooth_earth_time.csv');

% ---- radials ----
r = R.E8.radial; rows = {};
for a = 1:numel(r.az)
    for k = 1:numel(r.D_km)
        for fi = 1:numel(F)
            rows(end + 1, :) = {r.az(a), r.D_km(k), F(fi), r.itm(a, k, fi, 1), r.p452(a, k, fi, 1), r.p2001(a, k, fi, 1), ...
                r.itm(a, k, fi, 2), r.p452(a, k, fi, 2), r.p2001(a, k, fi, 2)}; %#ok<AGROW>
        end
    end
end
wt(rows, {'azimuth_deg', 'd_km', 'freq_mhz', 'itm_1_db', 'p452_1_db', 'p2001_1_db', 'itm_50_db', 'p452_50_db', 'p2001_50_db'}, out, 'deep_radials.csv');

% ---- archetypes ----
names = ["Line of sight", "Single-horizon diffraction", "Double-horizon diffraction", "Troposcatter", "Over-sea coastal"];
rows = {}; rows2 = {};
for i = 1:numel(R.E5)
    a = R.E5(i);
    for j = 1:numel(a.prof.d_km)
        rows(end + 1, :) = {names(i), a.link, a.htx, a.hrx, a.prof.d_km(j), a.prof.h_m(j)}; %#ok<AGROW>
    end
    for fi = 1:numel(F)
        for j = 1:numel(P)
            rows2(end + 1, :) = {names(i), F(fi), P(j), a.length_km, a.itm_mech(fi), a.itm(fi, j), a.itm_c10(fi, j), a.itm_c90(fi, j), ...
                a.p452(fi, j), a.p2001(fi, j), a.p452_mech(fi, j), a.p2001_mech(fi, j)}; %#ok<AGROW>
        end
    end
end
wt(rows, {'path', 'link', 'htx_m', 'hrx_m', 'd_km', 'h_m'}, out, 'deep_archetype_profiles.csv');
wt(rows2, {'path', 'freq_mhz', 'time_pct', 'length_km', 'itm_mode_code', 'itm_db', 'itm_c10_db', 'itm_c90_db', 'p452_db', 'p2001_db', ...
    'p452_mech', 'p2001_mech'}, out, 'deep_archetype_time.csv');

% ---- ITM climate and N0 ----
pc = [1 10 50 90 99]; rows = {};
for c = 1:7, rows(end + 1, :) = [{"climate", c, 320}, num2cell(R.E9.climate(c, :))]; end %#ok<AGROW>
for j = 1:numel(R.E9.N0s), rows(end + 1, :) = [{"n0", 6, R.E9.N0s(j)}, num2cell(R.E9.n0(j, :))]; end %#ok<AGROW>
wt(rows, [{'case', 'climate', 'n0'}, compose('itm_%d_db', pc)], out, 'deep_itm_climate.csv');

% ---- knife edge and frequency sweep ----
E2 = R.E2; rows = {};
for fi = 1:numel(F)
    for k = 1:numel(E2.H_m)
        rows(end + 1, :) = {F(fi), E2.H_m(k), E2.v(fi, k), E2.J(fi, k), E2.itm(fi, k), E2.p452(fi, k), E2.p2001(fi, k)}; %#ok<AGROW>
    end
end
wt(rows, {'freq_mhz', 'h_m', 'v', 'J_db', 'itm_db', 'p452_db', 'p2001_db'}, out, 'deep_knife_edge.csv');
E6 = R.E6; rows = {};
for a = 1:3
    for j = 1:numel(E6.freqs)
        rows(end + 1, :) = {names(a), E6.freqs(j), E6.f_itm(a, j), E6.f_p452(a, j), E6.f_p2001(a, j)}; %#ok<AGROW>
    end
end
wt(rows, {'path', 'freq_mhz', 'itm_db', 'p452_db', 'p2001_db'}, out, 'deep_freq_sweep.csv');
fprintf('wrote deep-dive CSV files to %s\n', out);
end

function wt(rows, names, out, file)
writetable(cell2table(rows, 'VariableNames', names), fullfile(out, file));
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
