function C = grid_clutter_rev1(options)
%GRID_CLUTTER_REV1 The DC and Los Angeles grids with ITU-R P.2108 clutter loss added.
%   C = GRID_CLUTTER_REV1() reads the single-entry grids that
%   grid_separation_rev1 wrote (300 km by 300 km at a 2.5 km step, Tag
%   "_150km_2p5km"; the 100 km grid if that file is missing), adds ITU-R
%   P.2108-1 Section 3.2 statistical clutter loss at the receiver end to
%   each model's loss at 50 % of time, and recomputes the exclusion area
%   at each required loss.
%
%   Section 3.2 is the terrestrial clutter model for a terminal in urban or
%   suburban clutter (0.5 GHz to 67 GHz, paths of 0.25 km and longer): its
%   loss depends only on frequency, distance, and the percentage of
%   locations, and is the same for every propagation model. It is applied
%   at the receiver (10 m) only; the 30 m transmitter is taken to be above
%   the clutter. Cases:
%     none      no clutter loss (the grids as computed)
%     rx_p10    receiver end, loss not exceeded at 10 % of locations
%     rx_p50    receiver end, 50 % of locations (median)
%     rx_p90    receiver end, 90 % of locations
%
%   Uses p2108_terrestrial_rev1 from nicklasorte/itu_p2108 (options.P2108Dir,
%   default: a folder itu_p2108 next to matlab_itm).
%
%   Writes chart_data/grid_clutter.csv: site, model, clutter case, required
%   loss, excluded points, area (km^2), farthest excluded point, and excluded
%   points on the grid edge (more than zero: the area runs past the grid).
%
%   Options: Freq (3000 MHz), Thresholds (110:5:200), DataDir, P2108Dir.

arguments
    options.Freq (1,1) double = 3000
    options.Thresholds double = 110:5:200
    options.DataDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2108Dir (1,1) string = ""
end
here = fileparts(mfilename('fullpath'));
d = options.P2108Dir;
if strlength(d) == 0, d = fullfile(fileparts(fileparts(fileparts(here))), 'itu_p2108'); end
addpath(fullfile(d, 'src'));
if ~exist('p2108_terrestrial_rev1', 'file')
    error('wp:p2108', 'p2108_terrestrial_rev1 not found. Pass the itu_p2108 folder as P2108Dir.');
end
cases = struct('name', {"none", "rx_p10", "rx_p50", "rx_p90"}, 'p', {NaN, 10, 50, 90});
models = ["itm", "p452", "p2001"];
rows = {};
for site = ["dc", "la"]
    tag = "_150km_2p5km";
    if ~isfile(fullfile(options.DataDir, "grid_" + site + tag + ".csv")), tag = ""; end
    G = readtable(fullfile(options.DataDir, "grid_" + site + tag + ".csv"));
    hw = max(abs(G.dx_km)); st = min(diff(unique(G.dx_km)));
    rim = abs(G.dx_km) >= hw - 1e-9 | abs(G.dy_km) >= hw - 1e-9;
    for c = cases
        if isnan(c.p)
            Lc = zeros(height(G), 1);
        else
            Lc = p2108_terrestrial_rev1(options.Freq / 1000, max(G.d_km, 0.25), c.p);
        end
        for m = models
            L = G.(m + "_50") + Lc;
            for Lreq = options.Thresholds
                ex = L < Lreq;
                dmax = 0; if any(ex), dmax = max(G.d_km(ex)); end
                rows(end + 1, :) = {site, m, c.name, Lreq, nnz(ex), nnz(ex) * st ^ 2, dmax, nnz(ex & rim), median(Lc)}; %#ok<AGROW>
            end
        end
    end
end
C = cell2table(rows, 'VariableNames', {'site', 'model', 'clutter', 'required_loss_db', 'points', 'area_km2', ...
    'max_distance_km', 'edge_points', 'median_clutter_loss_db'});
writetable(C, fullfile(options.DataDir, 'grid_clutter.csv'));
end
