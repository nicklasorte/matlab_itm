function S = sensitivity_rev1(options)
%SENSITIVITY_REV1 How much each model setting moves the ITM-ITU gap at 3 GHz.
%   S = SENSITIVITY_REV1() reruns the 60 real-terrain links of the working
%   paper (chart_data/real_terrain_links.csv) at 3 GHz and 50 % of time
%   through pathloss_rev1, serially, once per case:
%     itm  baseline     ground permittivity 25, conductivity 0.02 S/m,
%                       50 % confidence, radio climate and N0 from the maps
%     itm  ground       poor (4, 0.001 S/m) and average (15, 0.005 S/m)
%     itm  confidence   10 % and 90 %
%     itm  climate      each of the seven radio climates (1 to 7)
%     itm  N0           280 and 360 N-units
%     p452 baseline     bare-earth profile
%     p452 surface      Copernicus surface heights added to the profile
%     p2001 baseline
%     all  horizontal   horizontal instead of vertical polarization
%   and writes chart_data/sensitivity_links.csv: one row per link and case,
%   with the loss and the link's ITM mechanism class from the baseline.
%
%   Options: Freq (3000), P (50), OutDir, P2001Dir, P452Dir, Download.
%
%   See also grid_separation_rev1, pathloss_rev1.

arguments
    options.Freq (1,1) double {mustBePositive} = 3000
    options.P (1,1) double {mustBePositive} = 50
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Download (1,1) logical = true
end
here = fileparts(mfilename('fullpath'));
itm_root = wp_setup(options.P2001Dir, options.P452Dir);
old_env = getenv('MATLAB_P452_ITM_DIR');
restore = onCleanup(@() setenv('MATLAB_P452_ITM_DIR', old_env)); %#ok<NASGU>
setenv('MATLAB_P452_ITM_DIR', itm_root);
p452_addpath_rev1();

Lk = readtable(fullfile(here, 'chart_data', 'real_terrain_links.csv'));
tx = [Lk.tx_lat, Lk.tx_lon, Lk.tx_h_m];
rx = [Lk.rx_lat, Lk.rx_lon, Lk.rx_h_m];
n = height(Lk);
f = options.Freq; p = options.P;
base = {'validity', "off", 'max_points', 5000, 'download', options.Download};

% name, model, extra wrapper options, model options
C = {
    "baseline",            "itm",   {}, {}
    "ground poor",         "itm",   {}, {'epsilon', 4, 'sigma', 0.001}
    "ground average",      "itm",   {}, {'epsilon', 15, 'sigma', 0.005}
    "confidence 10 %",     "itm",   {}, {'confidence', 10}
    "confidence 90 %",     "itm",   {}, {'confidence', 90}
    "N0 280",              "itm",   {}, {'N_0', 280}
    "N0 360",              "itm",   {}, {'N_0', 360}
    "horizontal",          "itm",   {}, {'polarization', "horizontal"}
    "baseline",            "p452",  {'surface_source', "none"}, {}
    "surface heights",     "p452",  {'surface_source', "copernicus"}, {}
    "horizontal",          "p452",  {'surface_source', "none"}, {'polarization', "horizontal"}
    "baseline",            "p2001", {}, {}
    "horizontal",          "p2001", {}, {'Polarization', "horizontal"}
    };
for c = 1:7
    C(end + 1, :) = {sprintf("climate %d", c), "itm", {}, {'climate', c}}; %#ok<AGROW>
end

rows = {};
prof = struct([]);
for k = 1:size(C, 1)
    [name, model, wo, mo] = C{k, :};
    if ~any(strcmp(wo, 'surface_source')), wo = [wo, {'surface_source', "none"}]; end %#ok<AGROW>
    po = {};
    if ~isempty(prof) && strcmp(wo{find(strcmp(wo, 'surface_source')) + 1}, "none"), po = {'profile', prof}; end
    t = tic;
    try
        [L, info] = pathloss_rev1(tx, rx, f, p, 'model', model, 'model_options', mo, base{:}, wo{:}, po{:});
        if isempty(prof) && ~isempty(info.profile) && strcmp(wo{find(strcmp(wo, 'surface_source')) + 1}, "none")
            prof = info.profile;
        end
    catch err
        fprintf('  %s %s failed: %s\n', model, name, err.message);
        L = NaN(n, 1);
    end
    for j = 1:n
        rows(end + 1, :) = {Lk.link(j), model, name, L(j)}; %#ok<AGROW>
    end
    fprintf('  %-6s %-18s %.0f s\n', model, name, toc(t));
end
S = cell2table(rows, 'VariableNames', {'link', 'model', 'case', 'loss_db'});
S.freq_mhz = repmat(f, height(S), 1);
S.time_pct = repmat(p, height(S), 1);
writetable(S, fullfile(options.OutDir, 'sensitivity_links.csv'));
end
