function [T, E] = grid_separation_rev1(options)
%GRID_SEPARATION_REV1 Single-entry loss from a grid of transmitters to one receiver.
%   [T, E] = GRID_SEPARATION_REV1() puts a receiver at the Washington
%   Monument, Washington, DC, and a 100 km by 100 km grid of transmitters
%   around it at a 5 km step (440 points; the receiver's own point is
%   skipped). For each transmitter alone (single entry) it computes basic
%   transmission loss at 3 GHz and 1, 10, and 50 % of time with ITM v1.4,
%   P.452-18, and P.2001-6, each on its own 30 m terrain profile, through
%   pathloss_rev1 (nicklasorte/matlab_itu_p452), serially.
%
%   T has one row per transmitter: grid offsets dx_km (east) and dy_km
%   (north), distance, azimuth, position, free-space loss, and the three
%   models' loss at each time percentage (itm_50, p452_50, p2001_50, ...).
%
%   E is the exclusion summary: for each required loss L (Thresholds), model,
%   and time percentage, the number of grid points where the loss is below
%   L (a transmitter there would exceed the protection criterion), the area
%   they cover (points times StepKm^2), the farthest such point, and how
%   many of them lie on the grid's outer edge (more than zero means the
%   excluded area runs past the grid, so the area is a lower bound). The
%   required loss comes from a link budget: L = EIRP + receive gain -
%   interference threshold, all in dB; see the working paper for an
%   example.
%
%   Options (name-value):
%     Site         "dc" (default) or "la" (Los Angeles City Hall)
%     Rx           [lat lon height_m] to override the site
%     TxHeight     Transmitter antenna height, m (30)
%     Freq         MHz (3000)
%     P            Time percentages (1 10 50); P.452 is defined to 50 %
%     HalfWidthKm  Half the grid width, km (50)
%     StepKm       Grid step, km (5)
%     Thresholds   Required losses for E, dB (110:5:180)
%     OutDir       Folder for grid_<site>.csv and grid_<site>_exclusion.csv
%     P2001Dir, P452Dir  Model folders (default: siblings of matlab_itm)
%     Download     Download missing terrain tiles (true)
%     Tag          Suffix for the output file names (""), such as "_150km_2p5km"
%
%   Example:
%     [T, E] = grid_separation_rev1(Site="la");
%
%   See also pathloss_rev1, sensitivity_rev1.

arguments
    options.Site (1,1) string {mustBeMember(options.Site, ["dc", "la"])} = "dc"
    options.Rx (1,:) double = []
    options.TxHeight (1,1) double {mustBePositive} = 30
    options.Freq (1,1) double {mustBePositive} = 3000
    options.P double {mustBePositive} = [1 10 50]
    options.HalfWidthKm (1,1) double {mustBePositive} = 50
    options.StepKm (1,1) double {mustBePositive} = 5
    options.Thresholds double = 110:5:180
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Download (1,1) logical = true
    options.Tag (1,1) string = ""
end
sites = struct('dc', [38.8895, -77.0353, 10], 'la', [34.0537, -118.2428, 10]);
rx = sites.(options.Site);
if ~isempty(options.Rx), rx = options.Rx; end

itm_root = wp_setup(options.P2001Dir, options.P452Dir);
old_env = getenv('MATLAB_P452_ITM_DIR');
restore = onCleanup(@() setenv('MATLAB_P452_ITM_DIR', old_env)); %#ok<NASGU>
setenv('MATLAB_P452_ITM_DIR', itm_root);
p452_addpath_rev1();

% ---- the grid, placed on the WGS84 ellipsoid by geodesic distance and azimuth ----
v = -options.HalfWidthKm:options.StepKm:options.HalfWidthKm;
[dx, dy] = meshgrid(v, v);
keep = ~(dx == 0 & dy == 0);
dx = dx(keep); dy = dy(keep);
d = hypot(dx, dy);
az = mod(atan2d(dx, dy), 360);
[la, lo] = reckon(rx(1), rx(2), d, az, wgs84Ellipsoid('km'));
tx = [la, lo, repmat(options.TxHeight, numel(la), 1)];
n = numel(la);
fprintf('%s: %d transmitters, receiver at %.4f, %.4f\n', options.Site, n, rx(1), rx(2));

T = table(dx, dy, d, az, la, lo, 'VariableNames', {'dx_km', 'dy_km', 'd_km', 'az_deg', 'tx_lat', 'tx_lon'});
T.free_space_db = 32.45 + 20 * log10(options.Freq) + 20 * log10(T.d_km);
wopts = {'validity', "off", 'surface_source', "none", 'max_points', 5000, 'download', options.Download};
models = ["itm", "p452", "p2001"];
prof = struct([]);
for m = models
    P = options.P;
    if m == "p452", P = P(P <= 50); end
    po = {};
    if ~isempty(prof), po = {'profile', prof}; end
    t = tic;
    [L, info] = pathloss_rev1(tx, rx, options.Freq, P, 'model', m, wopts{:}, po{:});
    L = reshape(L, n, []);
    if isempty(prof) && ~isempty(info.profile), prof = info.profile; end
    for k = 1:numel(P)
        T.(sprintf('%s_%g', m, P(k))) = L(:, k);
    end
    fprintf('  %s done in %.0f s\n', m, toc(t));
end

% ---- exclusion summary: where a single transmitter would need more loss than it gets ----
rows = {};
for m = models
    for p = options.P
        col = sprintf('%s_%g', m, p);
        if ~ismember(col, T.Properties.VariableNames), continue, end
        for Lreq = options.Thresholds
            ex = T.(col) < Lreq;
            dmax = 0;
            if any(ex), dmax = max(T.d_km(ex)); end
            edge = nnz(ex & (abs(T.dx_km) >= options.HalfWidthKm - 1e-9 | abs(T.dy_km) >= options.HalfWidthKm - 1e-9));
            rows(end + 1, :) = {options.Site, m, p, Lreq, nnz(ex), nnz(ex) * options.StepKm ^ 2, dmax, edge}; %#ok<AGROW>
        end
    end
end
E = cell2table(rows, 'VariableNames', {'site', 'model', 'time_pct', 'required_loss_db', 'points', 'area_km2', 'max_distance_km', 'edge_points'});

if ~isfolder(options.OutDir), mkdir(options.OutDir); end
writetable(T, fullfile(options.OutDir, "grid_" + options.Site + options.Tag + ".csv"));
writetable(E, fullfile(options.OutDir, "grid_" + options.Site + options.Tag + "_exclusion.csv"));
end
