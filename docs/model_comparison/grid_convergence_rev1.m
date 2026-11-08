function C = grid_convergence_rev1(options)
%GRID_CONVERGENCE_REV1 Is the transmitter grid fine enough and big enough?
%   C = GRID_CONVERGENCE_REV1() runs grid_separation_rev1 for Washington,
%   DC, and Los Angeles twice:
%     wide  300 km by 300 km at a 2.5 km step (Tag "_150km_2p5km")
%     fine  100 km by 100 km at a 1 km step  (Tag "_50km_1km")
%   and, from those runs, recomputes the single-entry exclusion area at
%   each required loss for every combination of grid half-width (50, 100,
%   and 150 km) and step (1, 2.5, and 5 km; the coarser grids are subsets of
%   the finer ones). It writes chart_data/grid_convergence.csv with, for each
%   site, model, required loss, half-width, and step: the area, the number
%   of excluded points on the grid's outer edge (more than zero means the
%   excluded area runs past the grid), and the farthest excluded point.
%
%   An area has converged in step when the 2.5 km and 1 km values agree,
%   and in extent when no excluded point lies on the edge.
%
%   Options: Sites (["dc" "la"]), Run (true; false reuses the CSV files),
%   Thresholds (110:5:200), Models, OutDir, P2001Dir, P452Dir.

arguments
    options.Sites (1,:) string = ["dc", "la"]
    options.Run (1,1) logical = true
    options.Thresholds double = 110:5:200
    options.Models (1,:) string = ["itm", "p452", "p2001"]
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
end
d = {'P2001Dir', options.P2001Dir, 'P452Dir', options.P452Dir, 'OutDir', options.OutDir, 'Thresholds', options.Thresholds, 'P', 50};
runs = struct('tag', {"_150km_2p5km", "_50km_1km"}, 'hw', {150, 50}, 'step', {2.5, 1});
rows = {};
for site = options.Sites
    G = cell(1, 2);
    for r = 1:2
        f = fullfile(options.OutDir, "grid_" + site + runs(r).tag + ".csv");
        if options.Run || ~isfile(f)
            t = tic;
            grid_separation_rev1('Site', site, 'HalfWidthKm', runs(r).hw, 'StepKm', runs(r).step, 'Tag', runs(r).tag, d{:});
            fprintf('%s%s done in %.0f s\n', site, runs(r).tag, toc(t));
        end
        G{r} = readtable(f);
    end
    % (half-width, step, source run)
    cfg = [50 1 2; 50 2.5 1; 50 5 1; 100 2.5 1; 100 5 1; 150 2.5 1; 150 5 1];
    for c = 1:size(cfg, 1)
        hw = cfg(c, 1); st = cfg(c, 2); T = G{cfg(c, 3)};
        on = abs(T.dx_km) <= hw + 1e-9 & abs(T.dy_km) <= hw + 1e-9 & ...
            abs(mod(T.dx_km / st + 1e-9, 1)) < 1e-6 & abs(mod(T.dy_km / st + 1e-9, 1)) < 1e-6;
        T = T(on, :);
        rim = abs(T.dx_km) >= hw - 1e-9 | abs(T.dy_km) >= hw - 1e-9;
        for m = options.Models
            L = T.(m + "_50");
            for Lreq = options.Thresholds
                ex = L < Lreq;
                dmax = 0; if any(ex), dmax = max(T.d_km(ex)); end
                rows(end + 1, :) = {site, m, Lreq, hw, st, height(T), nnz(ex), nnz(ex) * st ^ 2, nnz(ex & rim), dmax}; %#ok<AGROW>
            end
        end
    end
end
C = cell2table(rows, 'VariableNames', {'site', 'model', 'required_loss_db', 'half_width_km', 'step_km', 'grid_points', ...
    'excluded_points', 'area_km2', 'edge_points', 'max_distance_km'});
writetable(C, fullfile(options.OutDir, 'grid_convergence.csv'));
end
