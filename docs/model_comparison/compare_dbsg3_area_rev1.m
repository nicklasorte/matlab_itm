function T = compare_dbsg3_area_rev1(options)
%COMPARE_DBSG3_AREA_REV1 ITM, P.452, and P.2001 against the ITU-R VHF/UHF point-to-area measurements.
%   T = COMPARE_DBSG3_AREA_REV1() reads the ITU-R Study Group 3 databank of
%   VHF/UHF measurements relating to terrestrial broadcasting (Rec. ITU-R
%   P.311 Tables VI-1 and VI-2; data/dbsg3/itu_r_sg3_dbsg3_vhfuhf_rssdata.zip,
%   from https://www.itu.int/oth/R0A0400005B/en), keeps the spatial
%   measurements (Table VI-2, bands 1 to 7, 30 MHz to 3 GHz) that have site
%   coordinates, a surveyed terrain profile, and a receiving antenna at
%   least MinRxHeight above ground, and runs the three models on each
%   surveyed profile at 50 % of time through pathloss_rev1, serially.
%
%   Each record is a location median: the field strength exceeded at 50 %
%   of the locations measured, quoted for 1 kW e.r.p. (column 40 of the
%   .SPL files). Basic transmission loss is
%       Lb = 141.45 - E + 20 log10(f_MHz)
%   (Rec. ITU-R P.525 for 1 kW e.i.r.p., plus 2.15 dB for e.r.p.).
%
%   A record's profile is found by matching the terminal coordinates in the
%   profile file header (within 0.002 degrees), because profile file names
%   repeat across experiments. Profiles whose first point is the receiver
%   are reversed. Records whose profile length differs from the coordinate
%   distance by more than 5 % are left out.
%
%   Writes data/dbsg3/dbsg3_area_30mhz_3ghz.csv (every parsed record) and
%   figures/table_dbsg3_area.csv (the kept records with measured and
%   predicted loss), and prints the mean and RMS error by band.
%
%   Options: MinRxHeight (10 m), MinFreq (30), MaxFreq (3000), MaxRows,
%   OutDir, P2001Dir, P452Dir.

arguments
    options.MinRxHeight (1,1) double = 10
    options.MinFreq (1,1) double = 30
    options.MaxFreq (1,1) double = 3000
    options.MaxRows (1,1) double = Inf
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
end
here = fileparts(mfilename('fullpath'));
itm_root = wp_setup(options.P2001Dir, options.P452Dir);
old_env = getenv('MATLAB_P452_ITM_DIR');
restore = onCleanup(@() setenv('MATLAB_P452_ITM_DIR', old_env)); %#ok<NASGU>
setenv('MATLAB_P452_ITM_DIR', itm_root);
p452_addpath_rev1();

tmp = fullfile(tempdir, 'dbsg3_vhfuhf');
if ~isfolder(tmp), unzip(fullfile(here, 'data', 'dbsg3', 'itu_r_sg3_dbsg3_vhfuhf_rssdata.zip'), tmp); end

% ---- parse the spatial records ----
files = [dir(fullfile(tmp, 'disk1', 'band*', '*.SPL')); dir(fullfile(tmp, 'disk2', 'band6', '*.SPL')); dir(fullfile(tmp, 'disk2', 'band7', '*.SPL'))];
C = {};
for k = 1:numel(files)
    txt = splitlines(string(fileread(fullfile(files(k).folder, files(k).name))));
    for i = 1:numel(txt)
        c = strtrim(split(txt(i), "|"));
        if numel(c) < 41, continue, end
        C(end + 1, :) = {string(files(k).name), c(1), c(2), c(5), num(c(6)), lon180(num(c(7))), num(c(8)), num(c(9)), c(10), num(c(12)), ...
            c(15), num(c(16)), lon180(num(c(17))), num(c(18)), num(c(19)), num(c(22)), c(28), num(c(29)), num(c(39)), num(c(40)), num(c(41)), ...
            c(min(43, numel(c)))}; %#ok<AGROW>
    end
end
A = cell2table(C, 'VariableNames', {'file', 'id', 'tx_name', 'tx_country', 'tx_lat', 'tx_lon', 'tx_ground_m', 'htx_m', 'pol', 'freq_mhz', ...
    'rx_country', 'rx_lat', 'rx_lon', 'rx_ground_m', 'hrx_m', 'rx_env', 'profile_ref', 'd_listed_km', 'fs10_dbuvm', 'fs50_dbuvm', 'fs90_dbuvm', 'source'});
A.meas_50 = 141.45 - A.fs50_dbuvm + 20 * log10(A.freq_mhz);
writetable(A, fullfile(here, 'data', 'dbsg3', 'dbsg3_area_30mhz_3ghz.csv'));

% ---- profiles, indexed by the terminal coordinates in their headers ----
pf = [dir(fullfile(tmp, 'disk3', '*', '*.PFL')); dir(fullfile(tmp, 'disk4', '*', '*.PFL')); dir(fullfile(tmp, 'disk5', '*', '*.PFL'))];
H = NaN(numel(pf), 5); P = cell(numel(pf), 1);
for k = 1:numel(pf)
    [H(k, :), P{k}] = read_pfl(fullfile(pf(k).folder, pf(k).name));
end
ok = all(isfinite(H(:, 1:4)), 2); H = H(ok, :); P = P(ok);

S = A(isfinite(A.tx_lat) & isfinite(A.rx_lat) & isfinite(A.meas_50) & A.hrx_m >= options.MinRxHeight & ...
    A.freq_mhz >= options.MinFreq & A.freq_mhz <= options.MaxFreq, :);
E = wgs84Ellipsoid('km');
S.d_km = distance(S.tx_lat, S.tx_lon, S.rx_lat, S.rx_lon, E);
S.profile_row = zeros(height(S), 1); S.profile_swapped = false(height(S), 1);
for i = 1:height(S)
    m = find(abs(H(:, 1) - S.tx_lat(i)) < 0.002 & abs(H(:, 2) - S.tx_lon(i)) < 0.002 & ...
        abs(H(:, 3) - S.rx_lat(i)) < 0.002 & abs(H(:, 4) - S.rx_lon(i)) < 0.002, 1);
    if isempty(m)   % header written receiver first
        m = find(abs(H(:, 3) - S.tx_lat(i)) < 0.002 & abs(H(:, 4) - S.tx_lon(i)) < 0.002 & ...
            abs(H(:, 1) - S.rx_lat(i)) < 0.002 & abs(H(:, 2) - S.rx_lon(i)) < 0.002, 1);
        S.profile_swapped(i) = ~isempty(m);
    end
    if ~isempty(m), S.profile_row(i) = m; end
end
S = S(S.profile_row > 0, :);
plen = cellfun(@(v) v(end, 1), P(S.profile_row));
S.profile_len_km = plen;
S = S(abs(plen - S.d_km) <= 0.05 * S.d_km & S.d_km >= 1, :);
S = S(1:min(height(S), options.MaxRows), :);
n = height(S);
fprintf('%d spatial records with coordinates, profile, and receiving antenna >= %g m\n', n, options.MinRxHeight);

% ---- build the wrapper profiles (transmitter first) and run the models ----
blank = struct('d_km', [], 'h_m', [], 'g_m', [], 'zone', [], 'spacing_m', [], 'midpoint_deg', [], 'distance_km', []);
prof = repmat(blank, n, 1);
for i = 1:n
    v = P{S.profile_row(i)};
    % The file starts at its own TX unless its header says the receiver; reverse when that is our receiver
    if xor(H(S.profile_row(i), 5) == 1, S.profile_swapped(i))
        v = [v(end, 1) - flipud(v(:, 1)), flipud(v(:, 2))];
    end
    dt = v(end, 1); sp = max(0.03, dt / 5000); np = max(10, round(dt / sp));
    d = linspace(0, dt, np + 1)'; h = interp1(v(:, 1), v(:, 2), d, 'linear');
    [arclen, az] = distance(S.tx_lat(i), S.tx_lon(i), S.rx_lat(i), S.rx_lon(i), E);
    [la, lo] = reckon(S.tx_lat(i), S.tx_lon(i), d / dt * arclen, az, E);
    z = p2001_zone_lookup_rev1(la, lo);
    zone = 2 * ones(size(d)); zone(z == 1) = 3; zone(z == 3) = 1;
    [mla, mlo] = reckon(S.tx_lat(i), S.tx_lon(i), arclen / 2, az, E);
    prof(i) = struct('d_km', d, 'h_m', h, 'g_m', h, 'zone', zone, 'spacing_m', 1000 * dt / np, 'midpoint_deg', [mla mlo], 'distance_km', dt);
end
TX = [S.tx_lat, S.tx_lon, S.htx_m]; RX = [S.rx_lat, S.rx_lon, S.hrx_m];
wopts = {'validity', "off", 'surface_source', "none", 'max_points', 5000, 'download', false};
for m = ["itm", "p452", "p2001"]
    L = NaN(n, 1);
    for i = 1:n
        if m == "p452" && S.freq_mhz(i) < 100, continue, end
        try
            L(i) = pathloss_rev1(TX(i, :), RX(i, :), S.freq_mhz(i), 50, 'model', m, 'profile', prof(i), wopts{:});
        catch
        end
    end
    S.(m + "_50") = L;
    fprintf('  %s done\n', m);
end
S.bin = strings(n, 1);
ed = [30 100 300 1000 2000 3000.1]; lab = ["30-100 MHz", "100-300 MHz", "0.3-1 GHz", "1-2 GHz", "2-3 GHz"];
for b = 1:numel(lab), S.bin(S.freq_mhz >= ed(b) & S.freq_mhz < ed(b + 1)) = lab(b); end
T = removevars(S, {'profile_row', 'profile_swapped'});
writetable(T, fullfile(options.OutDir, 'table_dbsg3_area.csv'));
for b = lab
    s = T.bin == b;
    fprintf('%-12s n=%4d', b, nnz(s));
    for m = ["itm", "p452", "p2001"]
        e = T.(m + "_50")(s) - T.meas_50(s); e = e(isfinite(e));
        fprintf('  %s %5.1f/%5.1f', m, mean(e), rms(e));
    end
    fprintf('\n');
end
end

function x = num(s)
x = str2double(s);
end

function x = lon180(x)
x(x > 180) = x(x > 180) - 360;
end

function [h, v] = read_pfl(fn)
% Header: TX and RX latitude and longitude (east, 0 to 360), first point (1 = receiver)
txt = splitlines(string(fileread(fn)));
h = NaN(1, 5); v = zeros(0, 2);
for i = 1:numel(txt)
    t = txt(i);
    if startsWith(t, "TX CNTRY") || startsWith(t, "RX CNTRY")
        x = sscanf(char(extractAfter(t, 11)), '%f %f');
        if numel(x) == 2
            j = 1 + 2 * startsWith(t, "RX");
            h(j:j + 1) = [x(1), lon180(x(2))];
        end
    elseif contains(t, "First Point")
        h(5) = double(endsWith(strtrim(t), "R"));
    else
        if ~isempty(regexp(t, '^\s*\d*\.?\d+\s+-?\d*\.?\d+', 'once'))
            x = sscanf(char(t), '%f %f');
            v(end + 1, :) = x(1:2)'; %#ok<AGROW>
        end
    end
end
[~, ia] = unique(v(:, 1), 'stable'); v = v(ia, :);
if size(v, 1) < 2, h(:) = NaN; end
end
