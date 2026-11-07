function R = compare_models_rev1(options)
%COMPARE_MODELS_REV1 Random-link comparison of matlab_itm with SEADLib ITM, TIREM, and MATLAB Longley-Rice.
%   R = COMPARE_MODELS_REV1() draws random links, runs every available
%   model on each one, and compares path loss from 0.1 % to 99.9 %, the
%   elevation angles at the transmitter and receiver, the propagation
%   mechanism, and the time per link. It prints a summary and returns a
%   struct with every per-link result.
%
%   Models (each runs only if it's available on this computer; the
%   summary says which were skipped and why):
%     matlab_itm       itm_pathloss_rev1, this repository (terrain: USGS
%                      3DEP 1", downloaded and cached)
%     seadlib_itm      SEADLib.dll ITMAcs.ITMP2P.ITMp2pAryRels, called as in
%                      ITMP2P_mechanism_rev4_embed_height (Windows, .NET,
%                      terrain from C:\USGS)
%     itm_on_seadlib_profile
%                      itm_p2p_rev1 on the SEADLib terrain profile, so a
%                      difference from seadlib_itm is the model (v1.4 vs
%                      1.2.2), not the terrain
%     seadlib_tirem    SEADLib USGS profile + tirempl, as in
%                      TIREM5_mechanism_angles_rev4 (needs the TIREM library)
%     rfprop_tirem     propagationModel("tirem") + pathloss (needs the TIREM
%                      library; MATLAB terrain)
%     matlab_lr        propagationModel("longley-rice") + pathloss, one call
%                      per time percentage (MATLAB terrain)
%     itm_on_matlab_terrain
%                      itm_p2p_rev1 on a profile from MATLAB's terrain
%                      (elevation with Map="gmted2010", 90 m steps), so a
%                      difference from matlab_lr is the model or sampling,
%                      and a difference from matlab_itm is the terrain
%
%   All models use the same inputs: epsilon 25, sigma 0.02 S/m, vertical
%   polarization unless Tpol says otherwise, confidence 50 %, and the radio
%   climate and N_0 from itm_radio_climate_rev1 and
%   itm_surface_refractivity_rev1 with the SEADLib rule (lower terminal
%   climate, N_0 at the midpoint). TIREM has no time variability, so it
%   gives one loss per link, compared with the others at 50 %.
%
%   Elevation angles (degrees, positive up):
%     matlab_itm, itm_on_seadlib_profile: toward the radio horizon, or
%       toward the other antenna on a line-of-sight path, on ITM's
%       effective earth (see itm_pathloss_rev1)
%     matlab_lr, rfprop_tirem: the elevation part of AngleOfDeparture
%       (TX) and AngleOfArrival (RX) from pathloss. On this MATLAB release
%       they describe the straight line between the antennas, ignoring
%       terrain, so they differ from ITM's on obstructed paths.
%     seadlib_tirem: from the tirempl info struct, if it has angle fields
%     seadlib_itm: SEADLib returns no angles (NaN)
%
%   Mechanisms are compared in common classes: LOS, diffraction,
%   troposcatter (ITM codes 0, 5 and 9, 6 and 10; TIREM mode text containing
%   "LOS", "DIF", or "TRO"). MATLAB Longley-Rice returns no mechanism.
%
%   Name-value options:
%     NumLinks     number of random links (20)
%     Seed         random seed (1)
%     FreqMHz      frequency (2700)
%     Region       [lat_min lat_max lon_min lon_max] for transmitters
%                  ([36 41 -82 -75], the mid-Atlantic). Keep it inside your
%                  C:\USGS tile coverage when running SEADLib.
%     LengthKm     [min max] path length, log-uniform ([5 150])
%     TxHeightM    [min max] TX height above ground ([10 100])
%     RxHeightM    [min max] RX height above ground ([2 30])
%     Tpol         0 horizontal, 1 vertical (1)
%     Reliability  time percentages (0.1 to 99.9, 45 values, dense at the tails)
%     SeadlibDir   folder with SEADLib.dll and the USGS tiles ("C:\USGS")
%     TiremDir     folder with the TIREM library ("C:\USGS\TIREM5")
%     Models       subset of models to run (all)
%     Prefetch     run every model on every link once, untimed, before
%                  the timed pass, so downloads and first-use costs aren't
%                  in the per-link times (true). The untimed pass's times
%                  are reported as cold_ms.
%     ExcelFile    Excel workbook for every result ("compare_models_results.xlsx"
%                  in the current folder; "" to skip). Sheets: Summary_Time,
%                  Summary_Loss, Summary_Angles, Summary_Mechanism, Links,
%                  Angles, Mechanism, Time_ms, Errors, and one Loss_<model>
%                  sheet per model (links by time percentage).
%     SaveFile     .mat file for R ("", don't save)
%
%   Example (Windows, with SEADLib and TIREM):
%     R = compare_models_rev1(NumLinks=100, SaveFile="compare_100.mat");
%     R.summary_loss, R.summary_time, R.summary_angles, R.summary_mechanism
%
%   See also itm_pathloss_rev1, itm_p2p_mechanism_rev1.

arguments
    options.NumLinks (1,1) double {mustBeInteger, mustBePositive} = 20
    options.Seed (1,1) double = 1
    options.FreqMHz (1,1) double {mustBePositive} = 2700
    options.Region (1,4) double = [36 41 -82 -75]
    options.LengthKm (1,2) double {mustBePositive} = [5 150]
    options.TxHeightM (1,2) double {mustBePositive} = [10 100]
    options.RxHeightM (1,2) double {mustBePositive} = [2 30]
    options.Tpol (1,1) double {mustBeMember(options.Tpol, [0 1])} = 1
    options.Reliability (1,:) double = [0.1:0.1:0.9, 1:9, 10:10:90, 91:99, 99.1:0.1:99.9]
    options.SeadlibDir (1,1) string = "C:\USGS"
    options.TiremDir (1,1) string = "C:\USGS\TIREM5"
    options.Models (1,:) string = ["matlab_itm", "seadlib_itm", "itm_on_seadlib_profile", ...
        "seadlib_tirem", "rfprop_tirem", "matlab_lr", "itm_on_matlab_terrain"]
    options.Prefetch (1,1) logical = true
    options.ExcelFile (1,1) string = "compare_models_results.xlsx"
    options.SaveFile (1,1) string = ""
end

addpath(fileparts(fileparts(mfilename('fullpath'))));
rel = options.Reliability(:).';
n_rel = numel(rel);
conf = 50;
f_mhz = options.FreqMHz;
pol_name = ["horizontal", "vertical"];
pol_name = pol_name(options.Tpol + 1);

%% Random links
rs = RandStream('mrg32k3a', 'Seed', options.Seed);
n = options.NumLinks;
g = options.Region;
tx_ll = [g(1) + diff(g(1:2)) * rand(rs, n, 1), g(3) + diff(g(3:4)) * rand(rs, n, 1)];
len_km = exp(log(options.LengthKm(1)) + diff(log(options.LengthKm)) * rand(rs, n, 1));
az = 360 * rand(rs, n, 1);
[rx_lat, rx_lon] = reckon(tx_ll(:, 1), tx_ll(:, 2), len_km * 1e3, az, wgs84Ellipsoid('meter'));
tx = [tx_ll, options.TxHeightM(1) + diff(options.TxHeightM) * rand(rs, n, 1)];
rx = [rx_lat, rx_lon, options.RxHeightM(1) + diff(options.RxHeightM) * rand(rs, n, 1)];
links = table((1:n)', tx(:, 1), tx(:, 2), tx(:, 3), rx(:, 1), rx(:, 2), rx(:, 3), len_km, ...
    'VariableNames', {'link', 'tx_lat', 'tx_lon', 'tx_h_m', 'rx_lat', 'rx_lon', 'rx_h_m', 'length_km'});

% Climate and N_0 with the SEADLib rule, shared by every ITM-family model
climate = min(itm_radio_climate_rev1(tx(:, 1), tx(:, 2)), itm_radio_climate_rev1(rx(:, 1), rx(:, 2)));
n0 = zeros(n, 1);
for k = 1:n % midpoint on the sphere, as find_refrac_itu452_par_GUI (track2, 3 points)
    [mlat, mlon] = track2(tx(k, 1), tx(k, 2), rx(k, 1), rx(k, 2), [], 'degrees', 3);
    n0(k) = itm_surface_refractivity_rev1(mlat(2), mlon(2));
end
links.climate = climate;
links.N_0 = n0;
climate_names = ["equatorial", "continental-subtropical", "maritime-subtropical", "desert", ...
    "continental-temperate", "maritime-over-land", "maritime-over-sea"];

%% Which models can run here
avail = struct();
why = struct();
for m = options.Models
    avail.(m) = true;
    why.(m) = "";
end
has_net = ispc && isfile(fullfile(options.SeadlibDir, "SEADLib.dll"));
if ~has_net
    for m = ["seadlib_itm", "itm_on_seadlib_profile", "seadlib_tirem"]
        if isfield(avail, m)
            avail.(m) = false;
            why.(m) = "needs Windows and " + fullfile(options.SeadlibDir, "SEADLib.dll");
        end
    end
else
    NET.addAssembly(char(fullfile(options.SeadlibDir, "SEADLib.dll")));
end
has_tirem = false;
if any(isfield(avail, ["seadlib_tirem", "rfprop_tirem"]))
    try
        tiremSetup(char(options.TiremDir));
        has_tirem = true;
    catch err
        for m = ["seadlib_tirem", "rfprop_tirem"]
            if isfield(avail, m)
                avail.(m) = false;
                why.(m) = "TIREM library not set up (" + string(err.message) + ")";
            end
        end
    end
end
for m = ["matlab_lr", "itm_on_matlab_terrain"]
    if isfield(avail, m) && ~exist('propagationModel', 'file')
        avail.(m) = false;
        why.(m) = "needs Antenna Toolbox or Communications Toolbox";
    end
end
models = options.Models(arrayfun(@(m) avail.(m), options.Models));

%% Storage: loss (n x n_rel), angles (n x 2), mechanism class, seconds per link
blank = struct('loss_db', NaN(n, n_rel), 'elev_deg', NaN(n, 2), 'mech', strings(n, 1), ...
    'mech_raw', strings(n, 1), 'seconds', NaN(n, 1), 'error', strings(n, 1));
out = struct();
for m = models
    out.(m) = blank;
end
seadlib_prof = cell(n, 1);
prof_seconds = zeros(n, 1);     % SEADLib terrain profile time, charged to both models that use it
prof_first = strings(n, 1);
m_now = "";
example_info = struct();        % first info struct per model, to show its fields

%% Untimed pass: tile downloads, maps, first-use compilation
cold = struct();
for m = models
    cold.(m) = NaN(n, 1);
end
if options.Prefetch
    warm_links = 1:n;
else
    warm_links = 1;
end
fprintf('Untimed pass over %d links ...\n', numel(warm_links));
for k = warm_links
    for m = models
        try
            t0 = tic;
            run_model(m, k);
            cold.(m)(k) = toc(t0);
        catch
        end
    end
end
for m = models
    out.(m) = blank;
end
seadlib_prof(:) = {[]};         % read the profiles again inside the timing
prof_seconds(:) = 0;
prof_first(:) = "";

%% Timed runs
for k = 1:n
    fprintf('Link %d of %d (%.1f km)\n', k, n, len_km(k));
    for m = models
        try
            m_now = m;
            t0 = tic;
            [L, el, mech_raw] = run_model(m, k);
            out.(m).seconds(k) = toc(t0);
            if any(m == ["itm_on_seadlib_profile", "seadlib_tirem"]) && ~isnan(out.(m).seconds(k))
                % The profile is read once per link; charge its time to both
                out.(m).seconds(k) = out.(m).seconds(k) - prof_charged(m, k) + prof_seconds(k);
            end
            out.(m).loss_db(k, :) = expand_loss(L, n_rel);
            out.(m).elev_deg(k, :) = el;
            out.(m).mech_raw(k) = string(mech_raw);
            out.(m).mech(k) = mech_class(mech_raw);
        catch err
            out.(m).error(k) = string(err.identifier) + ": " + string(err.message);
        end
    end
end

%% Summaries
R = struct('links', links, 'reliability', rel, 'models', models, 'skipped', why, 'results', out, ...
    'example_info', example_info);
R.summary_time = summarize_time(out, models, cold);
R.summary_loss = summarize_loss(out, models, rel);
R.summary_angles = summarize_angles(out, models);
R.summary_mechanism = summarize_mechanism(out, models);
skipped = setdiff(options.Models, models);
fprintf('\n%d links, %.0f to %.0f km, %g MHz, %d time percentages (%.1f to %.1f %%)\n', n, ...
    min(len_km), max(len_km), f_mhz, n_rel, min(rel), max(rel));
for m = skipped
    fprintf('Skipped %s: %s\n', m, why.(m));
end
for m = string(fieldnames(example_info))'
    fprintf('%s info fields: %s\n', m, strjoin(string(fieldnames(example_info.(m))), ', '));
end
fprintf('\nTime per link (ms)\n'); disp(R.summary_time)
fprintf('Path loss difference from matlab_itm (dB): model minus matlab_itm, all links\n'); disp(R.summary_loss)
fprintf('Elevation angles (degrees): mean |difference| from matlab_itm\n'); disp(R.summary_angles)
fprintf('Propagation mechanism: share of links in the same class as matlab_itm\n'); disp(R.summary_mechanism)
for m = models
    nerr = nnz(strlength(out.(m).error) > 0);
    if nerr > 0
        fprintf('%s failed on %d links; first: %s\n', m, nerr, out.(m).error(find(strlength(out.(m).error) > 0, 1)));
    end
end
if strlength(options.ExcelFile) > 0
    write_excel(options.ExcelFile, R);
    fprintf('Wrote %s\n', options.ExcelFile);
end
if strlength(options.SaveFile) > 0
    save(options.SaveFile, 'R');
    fprintf('Saved %s\n', options.SaveFile);
end

%% ------------------------------------------------------------------------
    function [L, el, mech_raw] = run_model(m, k)
        el = [NaN NaN];
        mech_raw = "";
        switch m
            case "matlab_itm"
                [L, ~, el, code] = itm_pathloss_rev1(tx(k, :), rx(k, :), f_mhz, rel, confidence=conf, ...
                    polarization=options.Tpol, climate=climate(k), N_0=n0(k), validity="warn");
                mech_raw = string(code);

            case "seadlib_itm"
                itmp = ITMAcs.ITMP2P;
                [Lnet, pm] = itmp.ITMp2pAryRels(tx(k, 3), rx(k, 3), n0(k), 0.02, 25.0, f_mhz, ...
                    int32(climate(k)), options.Tpol, conf / 100, rel / 100, tx(k, 1), tx(k, 2), ...
                    rx(k, 1), rx(k, 2), int32(1), char(options.SeadlibDir + "\"));
                L = double(Lnet);
                mech_raw = string(double(pm));

            case "itm_on_seadlib_profile"
                z = seadlib_profile(k);
                d_m = deg2km(distance(tx(k, 1), tx(k, 2), rx(k, 1), rx(k, 2))) * 1e3;
                pfl = [numel(z) - 1; d_m / (numel(z) - 1); z(:)];
                [L, info] = itm_p2p_rev1(tx(k, 3), rx(k, 3), pfl, f_mhz, rel, confidence=conf, ...
                    climate=climate(k), N_0=n0(k), polarization=options.Tpol, validity="warn");
                el = info.elevation_deg;
                mech_raw = string(info.mode_code);

            case "seadlib_tirem"
                z = seadlib_profile(k);
                d_m = deg2km(distance(tx(k, 1), tx(k, 2), rx(k, 1), rx(k, 2))) * 1e3;
                r = linspace(0, d_m, numel(z));
                [L, info] = tirempl(r, z, f_mhz * 1e6, 'TransmitterAntennaHeight', tx(k, 3), ...
                    'ReceiverAntennaHeight', rx(k, 3), 'AntennaPolarization', pol_name, ...
                    'GroundConductivity', 0.02, 'GroundPermittivity', 25, 'AtmosphericRefractivity', n0(k));
                [el, mech_raw] = tirem_info(info);
                keep_info(m, info);

            case "rfprop_tirem"
                [txs, rxs] = sites(k);
                pm = propagationModel("tirem", 'AntennaPolarization', pol_name, ...
                    'GroundConductivity', 0.02, 'GroundPermittivity', 25, 'AtmosphericRefractivity', n0(k));
                [L, info] = pathloss(pm, rxs, txs);
                el = mw_angles(info);
                [~, mech_raw] = tirem_info(info);
                keep_info(m, info);

            case "itm_on_matlab_terrain"
                [L, info] = itm_p2p_rev1(tx(k, 3), rx(k, 3), matlab_terrain_profile(k), f_mhz, rel, ...
                    confidence=conf, climate=climate(k), N_0=n0(k), polarization=options.Tpol, validity="warn");
                el = info.elevation_deg;
                mech_raw = string(info.mode_code);

            case "matlab_lr"
                [txs, rxs] = sites(k);
                L = NaN(1, n_rel);
                for j = 1:n_rel % TimeVariabilityTolerance takes one value per model object
                    pm = propagationModel('longley-rice', 'AntennaPolarization', pol_name, ...
                        'GroundConductivity', 0.02, 'GroundPermittivity', 25, ...
                        'AtmosphericRefractivity', n0(k), 'ClimateZone', climate_names(climate(k)), ...
                        'TimeVariabilityTolerance', min(max(round(rel(j) / 100, 6), 0.001), 0.999), ...
                        'SituationVariabilityTolerance', round(conf / 100, 6));
                    if j == 1
                        [L(j), info] = pathloss(pm, rxs, txs);
                        el = mw_angles(info);
                        keep_info(m, info);
                    else
                        L(j) = pathloss(pm, rxs, txs);
                    end
                end
        end
    end

    function pfl = matlab_terrain_profile(k)
        % MATLAB's terrain (GMTED2010) at 90 m steps along the WGS84 geodesic
        e = wgs84Ellipsoid('meter');
        d_m = distance(tx(k, 1), tx(k, 2), rx(k, 1), rx(k, 2), e);
        npt = max(ceil(d_m / 90) + 1, 11);
        [la, lo] = track2(tx(k, 1), tx(k, 2), rx(k, 1), rx(k, 2), e, 'degrees', npt);
        z = elevation(rxsite('Latitude', la, 'Longitude', lo), 'Map', 'gmted2010');
        pfl = [npt - 1; d_m / (npt - 1); z(:)];
    end

    function z = seadlib_profile(k)
        % Same call as TIREM5_mechanism_angles_rev4; cached so both models
        % that use it see one profile and the timing isn't charged twice
        if isempty(seadlib_prof{k})
            tp = tic;
            usgs = TerrainPcs.USGS;
            usgs.TerrainDataPath = char(options.SeadlibDir);
            seadlib_prof{k} = double(usgs.GetPathElevation(TerrainPcs.Geolocation(tx(k, 1), tx(k, 2)), ...
                TerrainPcs.Geolocation(rx(k, 1), rx(k, 2)), 90, true));
            prof_seconds(k) = toc(tp);
            prof_first(k) = m_now;
        end
        z = seadlib_prof{k};
    end

    function t = prof_charged(m, k)
        % Profile time already inside this model's toc (it paid for the read)
        t = 0;
        if prof_first(k) == m
            t = prof_seconds(k);
        end
    end

    function keep_info(m, info)
        if ~isfield(example_info, m) && isstruct(info)
            example_info.(m) = info;
        end
    end

    function [txs, rxs] = sites(k)
        txs = txsite('Latitude', tx(k, 1), 'Longitude', tx(k, 2), 'AntennaHeight', tx(k, 3), ...
            'TransmitterFrequency', f_mhz * 1e6);
        rxs = rxsite('Latitude', rx(k, 1), 'Longitude', rx(k, 2), 'AntennaHeight', rx(k, 3));
    end
end

%% ------------------------------------------------------------------------
function L = expand_loss(L, n_rel)
L = double(L(:)).';
if isscalar(L)
    L = repmat(L, 1, n_rel);       % TIREM: one loss for every percentage
end
end

function el = mw_angles(info)
% Elevation from pathloss info: AngleOfDeparture/AngleOfArrival are
% [azimuth; elevation] in degrees
el = [NaN NaN];
if isstruct(info) && isfield(info, 'AngleOfDeparture') && numel(info.AngleOfDeparture) >= 2
    el(1) = info.AngleOfDeparture(2);
end
if isstruct(info) && isfield(info, 'AngleOfArrival') && numel(info.AngleOfArrival) >= 2
    el(2) = info.AngleOfArrival(2);
end
end

function [el, mech] = tirem_info(info)
% The TIREM info struct differs by release; take whatever angle and mode
% fields it has, by name
el = mw_angles(info);
mech = "";
if ~isstruct(info)
    mech = string(info);
    return
end
f = string(fieldnames(info));
pick = @(pat) f(find(~cellfun(@isempty, regexpi(cellstr(f), pat, 'once')), 1));
mf = pick('mode');
if ~isempty(mf)
    mech = string(info.(mf));
end
tf = pick('^(tx|transmit).*(elev|angle)');
rf = pick('^(rx|receiv).*(elev|angle)');
if ~isempty(tf) && isnumeric(info.(tf)), el(1) = double(info.(tf)(1)); end
if ~isempty(rf) && isnumeric(info.(rf)), el(2) = double(info.(rf)(1)); end
end

function c = mech_class(raw)
% Common class: LOS, Diffraction, Troposcatter, or the raw text
raw = upper(strtrim(string(raw)));
c = "";
if strlength(raw) == 0
    return
end
code = str2double(raw);
if ~isnan(code)
    if code == 0, c = "LOS";
    elseif any(code == [4 5 8 9]), c = "Diffraction";
    elseif any(code == [6 10]), c = "Troposcatter";
    else, c = "Code " + raw;
    end
elseif contains(raw, "LOS") || contains(raw, "LINE")
    c = "LOS";
elseif contains(raw, "DIF")
    c = "Diffraction";
elseif contains(raw, "TRO") || contains(raw, "SCAT")
    c = "Troposcatter";
else
    c = raw;
end
end

function T = summarize_time(out, models, cold)
ms = zeros(numel(models), 5);
for i = 1:numel(models)
    s = 1e3 * out.(models(i)).seconds;
    ms(i, :) = [median(s, 'omitnan'), prctile(s, 90), max(s), median(1e3 * cold.(models(i)), 'omitnan'), nnz(~isnan(s))];
end
T = array2table(ms, 'VariableNames', {'median_ms', 'p90_ms', 'max_ms', 'cold_median_ms', 'links_ok'}, ...
    'RowNames', cellstr(models));
end

function T = summarize_loss(out, models, rel)
base = out.matlab_itm.loss_db;
pick = [0.1 1 10 50 90 99 99.9];
[~, cols] = min(abs(rel(:) - pick), [], 1);
rows = setdiff(models, "matlab_itm", 'stable');
v = NaN(numel(rows), numel(pick) + 2);
for i = 1:numel(rows)
    d = out.(rows(i)).loss_db - base;
    v(i, 1:numel(pick)) = median(d(:, cols), 1, 'omitnan');
    v(i, end - 1) = mean(abs(d), 'all', 'omitnan');
    v(i, end) = max(abs(d), [], 'all', 'omitnan');
end
names = [compose("median_at_%g", rel(cols)), "mean_abs", "max_abs"];
T = array2table(v, 'VariableNames', cellstr(matlab.lang.makeValidName(names)), 'RowNames', cellstr(rows));
end

function T = summarize_angles(out, models)
base = out.matlab_itm.elev_deg;
rows = setdiff(models, "matlab_itm", 'stable');
v = NaN(numel(rows), 4);
for i = 1:numel(rows)
    e = out.(rows(i)).elev_deg;
    d = abs(e - base);
    v(i, :) = [mean(d(:, 1), 'omitnan'), mean(d(:, 2), 'omitnan'), nnz(~isnan(e(:, 1))), nnz(~isnan(e(:, 2)))];
end
T = array2table(v, 'VariableNames', {'tx_mean_abs_diff_deg', 'rx_mean_abs_diff_deg', 'tx_links', 'rx_links'}, ...
    'RowNames', cellstr(rows));
end

function T = summarize_mechanism(out, models)
base = out.matlab_itm.mech;
rows = models;
v = NaN(numel(rows), 5);
for i = 1:numel(rows)
    c = out.(rows(i)).mech;
    have = strlength(c) > 0 & strlength(base) > 0;
    v(i, :) = [mean(c(have) == base(have)), nnz(c == "LOS"), nnz(c == "Diffraction"), ...
        nnz(c == "Troposcatter"), nnz(have)];
end
T = array2table(v, 'VariableNames', {'same_class_as_matlab_itm', 'LOS', 'Diffraction', 'Troposcatter', 'links'}, ...
    'RowNames', cellstr(rows));
end

function write_excel(file, R)
% Every result in one workbook; an existing file is replaced
if isfile(file)
    delete(file);
end
models = R.models;
out = R.results;
writetable(R.summary_time, file, 'Sheet', 'Summary_Time', 'WriteRowNames', true);
writetable(R.summary_loss, file, 'Sheet', 'Summary_Loss', 'WriteRowNames', true);
writetable(R.summary_angles, file, 'Sheet', 'Summary_Angles', 'WriteRowNames', true);
writetable(R.summary_mechanism, file, 'Sheet', 'Summary_Mechanism', 'WriteRowNames', true);
writetable(R.links, file, 'Sheet', 'Links');
A = R.links(:, {'link', 'length_km'});
M = A; Tm = A; E = A;
for m = models
    A.(m + "_tx_elev_deg") = out.(m).elev_deg(:, 1);
    A.(m + "_rx_elev_deg") = out.(m).elev_deg(:, 2);
    M.(m + "_class") = out.(m).mech;
    M.(m + "_raw") = out.(m).mech_raw;
    Tm.(m + "_ms") = 1e3 * out.(m).seconds;
    E.(m) = out.(m).error;
end
writetable(A, file, 'Sheet', 'Angles');
writetable(M, file, 'Sheet', 'Mechanism');
writetable(Tm, file, 'Sheet', 'Time_ms');
writetable(E, file, 'Sheet', 'Errors');
names = matlab.lang.makeValidName("p_" + compose("%g", R.reliability));
for m = models
    T = [R.links(:, {'link', 'length_km'}), array2table(out.(m).loss_db, 'VariableNames', cellstr(names))];
    writetable(T, file, 'Sheet', char(strip(extractBefore("Loss_" + m + blanks(31), 32))));   % Excel caps names at 31
end
end
