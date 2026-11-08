function [loss_db, info] = itm_matlab_lr_rev1(tx, rx, f_mhz, reliability, options)
%ITM_MATLAB_LR_REV1 MATLAB's propagationModel("longley-rice") on this repository's terrain.
%   loss_db = ITM_MATLAB_LR_REV1(tx, rx, f_mhz, reliability) runs MathWorks'
%   Longley-Rice (Antenna Toolbox or Communications Toolbox) with the same
%   inputs and defaults as itm_pathloss_rev1, and on the same terrain:
%   USGS 3DEP 1 arc-second, with Copernicus GLO-30 where 3DEP has no data,
%   instead of MATLAB's built-in GMTED2010 (about 250 m).
%
%     tx, rx       [lat_deg, lon_deg, height_m]; N rows, or one row paired
%                  with every row of the other
%     f_mhz        frequency (MHz)
%     reliability  time percentages, 0 < reliability < 100 (percent)
%
%   loss_db is N-by-numel(reliability) (for one link, the size of
%   reliability). Use it to check this port against MathWorks' model, or
%   to run MathWorks' model on 1" terrain.
%
%   Engines (option engine):
%     "profile" (default) MathWorks' Longley-Rice core, the builtin that
%             propagationModel("longley-rice") calls
%             (builtin('_longleyricepl'), from rfprop.LongleyRice), on
%             the same terrain profile itm_pathloss_rev1 uses: identical
%             terrain and sampling, about 0.03 ms per call. The builtin
%             is undocumented and could change in a later release; if it
%             fails, use engine="pathloss".
%     "pathloss" the documented pathloss function with Map set to the
%             registered USGS 1" DTED terrain (terrain="usgs1") or to
%             MATLAB's GMTED2010 (terrain="gmted2010"). MATLAB samples
%             the terrain itself.
%
%   How the terrain gets in for engine="pathloss": MATLAB terrain models read custom terrain
%   only as DTED, through addCustomTerrain. The 1-degree tiles the paths
%   cross are written as DTED level 2 and registered as the custom terrain
%   "itm_usgs1" by itm_matlab_terrain_rev1. Registering takes about 30 s
%   per tile, once: MATLAB keeps it across sessions. For a study area, run
%   itm_matlab_terrain_rev1(region=[lat_min lat_max lon_min lon_max])
%   first. DTED stores whole meters, so heights are rounded to 1 m.
%
%   Defaults, as in itm_pathloss_rev1: confidence 50 %, vertical
%   polarization, epsilon 25, sigma 0.02 S/m, the ITU-R P.617 climate and
%   P.452 N_0 for the path. MATLAB's own defaults differ (horizontal, 15,
%   0.005 S/m), so they're always set here.
%
%   info (struct array, one per link): elevation_deg [TX, RX] in
%   degrees, MATLAB's convention: the straight line between the antennas
%   on the WGS84 ellipsoid, not the terrain horizon (from pathloss's
%   AngleOfDeparture and AngleOfArrival, or computed the same way with
%   geodetic2aer for engine="profile"), distance_m, climate, N_0,
%   terrain, engine.
%
%   Name-value options:
%     engine        "profile" (default) or "pathloss"; see above
%     terrain       "usgs1" (default) or "gmted2010" (MATLAB's terrain;
%                   engine="pathloss" only)
%     confidence    confidence percentage (50)
%     polarization  "vertical" (default) or "horizontal"
%     epsilon, sigma         ground constants (25, 0.02)
%     climate, N_0           overrides, scalar or one per link
%     climate_rule  "midpoint" (default) or "endpoints"; see itm_pathloss_rev1
%     dted_folder   where the DTED tiles go (<cache>/dted)
%
%   Example:
%     L = itm_matlab_lr_rev1([38.98 -76.49 30], [38.90 -77.04 10], 2700, [1 50 99])
%     L2 = itm_pathloss_rev1([38.98 -76.49 30], [38.90 -77.04 10], 2700, [1 50 99])
%
%   See also itm_pathloss_rev1, itm_dted_tiles_rev1, propagationModel.

arguments
    tx (:,3) double {mustBeReal, mustBeFinite, mustBeNonempty}
    rx (:,3) double {mustBeReal, mustBeFinite, mustBeNonempty}
    f_mhz (1,1) double {mustBePositive}
    reliability double {mustBeReal, mustBeFinite, mustBeNonempty, mustBeGreaterThan(reliability, 0), mustBeLessThan(reliability, 100)}
    options.engine (1,1) string {mustBeMember(options.engine, ["profile", "pathloss"])} = "profile"
    options.terrain (1,1) string {mustBeMember(options.terrain, ["usgs1", "gmted2010"])} = "usgs1"
    options.confidence (1,1) double {mustBeGreaterThan(options.confidence, 0), mustBeLessThan(options.confidence, 100)} = 50
    options.polarization (1,1) string {mustBeMember(options.polarization, ["vertical", "horizontal"])} = "vertical"
    options.epsilon (1,1) double {mustBePositive} = 25
    options.sigma (1,1) double {mustBePositive} = 0.02
    options.climate double = []
    options.N_0 double = []
    options.climate_rule (1,1) string {mustBeMember(options.climate_rule, ["midpoint", "endpoints"])} = "midpoint"
    options.dted_folder (1,1) string = fullfile(fileparts(itm_default_terrain_dir()), "dted")
end

if ~exist('propagationModel', 'file')
    error('itm:matlablr:NoToolbox', 'propagationModel needs Antenna Toolbox or Communications Toolbox.');
end
n = max(size(tx, 1), size(rx, 1));
if size(tx, 1) ~= n && size(tx, 1) ~= 1 || size(rx, 1) ~= n && size(rx, 1) ~= 1
    error('itm:SizeMismatch', 'tx and rx must have the same number of rows, or one row.');
end
tx = repmat(tx, n / size(tx, 1), 1);
rx = repmat(rx, n / size(rx, 1), 1);
rel = reliability(:).';

% Geometry, climate, and N_0 exactly as itm_pathloss_rev1 chooses them
if options.engine == "profile"
    if options.terrain ~= "usgs1"
        error('itm:matlablr:Engine', 'engine="profile" uses this repository''s terrain; use engine="pathloss" for terrain="%s".', options.terrain);
    end
    [pfls, pinfo] = itm_terrain_profile_rev1(tx(:, 1), tx(:, 2), rx(:, 1), rx(:, 2));
    if n == 1
        pfls = {pfls};
    end
    mid = vertcat(pinfo.midpoint_deg);
    lat_mid = mid(:, 1);
    lon_mid = mid(:, 2);
    d_m = [pinfo.distance_m]';
else
    e = itm_wgs84();
    [d_m, az] = itm_geodesic_inverse(tx(:, 1), tx(:, 2), rx(:, 1), rx(:, 2));
    lat_mid = zeros(n, 1);
    lon_mid = zeros(n, 1);
    for k = 1:n % per path, as in itm_pathloss_rev1
        [lat_mid(k), lon_mid(k)] = reckon(tx(k, 1), tx(k, 2), d_m(k) / 2, az(k), e);
    end
end
if isempty(options.climate)
    c_ends = min(itm_radio_climate_rev1(tx(:, 1), tx(:, 2)), itm_radio_climate_rev1(rx(:, 1), rx(:, 2)));
    if options.climate_rule == "endpoints"
        climate = c_ends;
    else
        climate = itm_radio_climate_rev1(lat_mid, lon_mid);
        climate(climate == 7) = c_ends(climate == 7);
    end
else
    climate = options.climate(:) + zeros(n, 1);
end
if isempty(options.N_0)
    N_0 = itm_surface_refractivity_rev1(lat_mid, lon_mid);
else
    N_0 = options.N_0(:) + zeros(n, 1);
end

zones = ["equatorial", "continental-subtropical", "maritime-subtropical", "desert", ...
    "continental-temperate", "maritime-over-land", "maritime-over-sea"];
loss_db = NaN(n, numel(rel));
el = NaN(n, 2);
tol = min(max(round(rel / 100, 6), 0.001), 0.999);    % MATLAB accepts 0.001 to 0.999
conf = round(options.confidence / 100, 6);

if options.engine == "profile"
    w = wgs84Ellipsoid('meter');
    for k = 1:n % one link at a time; the builtin takes one time percentage per call
        p = pfls{k}(:).';
        for j = 1:numel(rel)
            [loss_db(k, j), err] = builtin('_longleyricepl', p, char(zones(climate(k))), ...
                char(options.polarization), options.epsilon, options.sigma, N_0(k), tx(k, 3), rx(k, 3), ...
                f_mhz, conf, tol(j));
            if err ~= 0 && j == 1
                warning('itm:matlablr:ErrorCode', 'MathWorks Longley-Rice returned error code %d on link %d.', err, k);
            end
        end
        % MATLAB's angle convention: the straight line between the antennas
        h_tx = p(3) + tx(k, 3);
        h_rx = p(end) + rx(k, 3);
        [~, el(k, 1)] = geodetic2aer(rx(k, 1), rx(k, 2), h_rx, tx(k, 1), tx(k, 2), h_tx, w);
        [~, el(k, 2)] = geodetic2aer(tx(k, 1), tx(k, 2), h_tx, rx(k, 1), rx(k, 2), h_rx, w);
    end
else
    map = options.terrain;
    if map == "usgs1"
        map = register_tiles(tx, rx, n, options.dted_folder);
    end
    for k = 1:n % pathloss pairs every rx with every tx, so one link at a time
        txs = txsite('Latitude', tx(k, 1), 'Longitude', tx(k, 2), 'AntennaHeight', tx(k, 3), ...
            'TransmitterFrequency', f_mhz * 1e6);
        rxs = rxsite('Latitude', rx(k, 1), 'Longitude', rx(k, 2), 'AntennaHeight', rx(k, 3));
        pm = propagationModel('longley-rice', 'AntennaPolarization', options.polarization, ...
            'GroundConductivity', options.sigma, 'GroundPermittivity', options.epsilon, ...
            'AtmosphericRefractivity', N_0(k), 'ClimateZone', zones(climate(k)), ...
            'SituationVariabilityTolerance', conf);
        for j = 1:numel(rel) % TimeVariabilityTolerance is one value per model
            pm.TimeVariabilityTolerance = tol(j);
            if j == 1
                [loss_db(k, j), pinfo] = pathloss(pm, rxs, txs, 'Map', map);
                el(k, :) = [pinfo.AngleOfDeparture(2), pinfo.AngleOfArrival(2)];
            else
                loss_db(k, j) = pathloss(pm, rxs, txs, 'Map', map);
            end
        end
    end
end
if n == 1
    loss_db = reshape(loss_db, size(reliability));
end
if nargout > 1
    info = struct('elevation_deg', num2cell(el, 2), 'distance_m', num2cell(d_m), ...
        'climate', num2cell(climate), 'N_0', num2cell(N_0), 'terrain', options.terrain, ...
        'engine', options.engine);
end
end

function map = register_tiles(tx, rx, n, folder)
% The 1-degree tiles these paths cross, registered as "itm_usgs1"
tiles = zeros(0, 2);
for k = 1:n % every tile a path crosses
    [la, lo] = track2(tx(k, 1), tx(k, 2), rx(k, 1), rx(k, 2), [], 'degrees', 200);
    tiles = [tiles; floor([la, lo])]; %#ok<AGROW> n links
end
tiles = unique(tiles, 'rows');
map = itm_matlab_terrain_rev1(tiles(:, 1), tiles(:, 2), folder=folder);
end
