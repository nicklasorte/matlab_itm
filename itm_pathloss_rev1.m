function [loss_db, info, elev_deg] = itm_pathloss_rev1(tx, rx, f_mhz, reliability, options)
%ITM_PATHLOSS_REV1 ITM point-to-point path loss between locations.
%   loss_db = ITM_PATHLOSS_REV1(tx, rx, f_mhz, reliability) returns the ITM
%   v1.4 basic transmission loss (dB) from tx to rx for each reliability
%   percentage.
%
%     tx, rx       [lat_deg, lon_deg, height_m]: WGS84 position and antenna
%                  height above ground. Either may have N rows (N links);
%                  a single row is paired with every row of the other.
%     f_mhz        Frequency (MHz)
%     reliability  Time percentage(s), 0 < reliability < 100, any size
%
%   Output size: for one link, the size of reliability (or of
%   reliability .* confidence). For N links, N-by-K, where row n holds
%   link n and K = numel(reliability .* confidence).
%
%   Everything else is automatic:
%     - Terrain profile along the WGS84 geodesic at 30 m spacing, from
%       USGS 3DEP 1 arc-second tiles, with Copernicus GLO-30 (then GLO-90)
%       outside 3DEP coverage. Tiles download once to a local cache. All links are
%       sampled in one pass over the tiles.
%     - Radio climate from ITU-R P.617 (TropoClim) at the path midpoint;
%       if the midpoint is over sea, the lower of the two terminal climates.
%     - Sea-level refractivity N_0 from ITU-R P.452 (N050) at the midpoint.
%     - Ground and statistics defaults: epsilon 25, sigma 0.02 S/m,
%       vertical polarization, confidence 50 percent, mdvar 13 (broadcast,
%       no location variability).
%   These match the WInnForum CBRS reference model and NTIA practice.
%
%   Name-value options (all optional):
%     confidence    Confidence percentage(s) (50). A row of confidences
%                   with a column of reliabilities returns a table.
%     polarization  "vertical" (default), "horizontal", 1, or 0
%     epsilon       Ground relative permittivity (25)
%     sigma         Ground conductivity, S/m (0.02)
%     mdvar         Mode of variability (13); see itm_p2p_rev1
%     climate       Override the radio climate code(s) (1-7), scalar or N
%     N_0           Override the sea-level refractivity (N-units), scalar or N
%     pfl           Supply terrain profile(s) instead of reading tiles: a
%                   PFL vector, or an N-by-1 cell array of them
%     spacing_m     Profile point spacing (30)
%     max_points    Profile point cap (Inf; WInnForum uses 1501)
%     terrain_source "auto" (default), "usgs3dep" (1"), "usgs3dep13" (1/3",
%                   pair with spacing_m=10), "copernicus" (GLO-30), or
%                   "copernicus90" (GLO-90)
%     terrain_dir   Tile cache folder; see itm_terrain_elevation_rev1
%     download      Download missing tiles (true)
%     validity      "error" (default), "warn", or "off". With "error", a
%                   path shorter than 1 km or longer than 2000 km raises
%                   itm:validity:Distance, naming the links; other NTIA
%                   warning flags raise one MATLAB warning,
%                   itm:validity:Caution, per call. See itm_p2p_rev1.
%
%   Errors are loud by design: a land point with no terrain tile raises
%   itm:terrain:NoCoverage, and NTIA's hard input limits raise itm:Invalid*.
%
%   info (struct array, one per link) contains the ITM intermediate
%   values, the climate and N_0 used, the terrain profile, and the terrain
%   sources.
%
%   [loss_db, ~, elev_deg] = ITM_PATHLOSS_REV1(...) returns the elevation
%   angles, N-by-2 [TX, RX] in degrees (positive up): toward the other
%   antenna on a line-of-sight path, or toward the terrain horizon
%   otherwise, on ITM's effective earth (refraction included). They are
%   also in info.elevation_deg. The azimuth from TX to RX is in
%   info.profile.azimuth_deg.
%
%   Example:
%     tx = [38.8895, -77.0353, 30];             % lat, lon, height (m)
%     rx = [39.0458, -76.6413, 10];
%     L = itm_pathloss_rev1(tx, rx, 2700, [1 10 50 90 99])
%
%     % 3 transmitters to one receiver, 3-by-5 output
%     txs = [38.90 -77.03 30; 38.95 -76.90 25; 39.20 -76.70 40];
%     L = itm_pathloss_rev1(txs, rx, 2700, [1 10 50 90 99])
%
%   See also itm_p2p_rev1, itm_terrain_profile_rev1,
%   itm_radio_climate_rev1, itm_surface_refractivity_rev1.

arguments
    tx (:,3) double {mustBeReal, mustBeFinite, mustBeNonempty}
    rx (:,3) double {mustBeReal, mustBeFinite, mustBeNonempty}
    f_mhz (1,1) double {mustBeReal, mustBeFinite}
    reliability double {mustBeReal, mustBeFinite, mustBeNonempty}
    options.confidence double {mustBeReal, mustBeFinite, mustBeNonempty} = 50
    options.polarization = "vertical"
    options.epsilon (1,1) double {mustBeReal, mustBeFinite} = 25
    options.sigma (1,1) double {mustBeReal, mustBeFinite} = 0.02
    options.mdvar (1,1) double {mustBeReal, mustBeFinite} = 13
    options.climate double {mustBeReal} = []
    options.N_0 double {mustBeReal} = []
    options.pfl = []
    options.spacing_m (1,1) double {mustBeReal, mustBePositive, mustBeFinite} = 30
    options.max_points (1,1) double {mustBeReal} = Inf
    options.terrain_source (1,1) string {mustBeMember(options.terrain_source, ["auto", "usgs3dep", "usgs3dep13", "copernicus", "copernicus90"])} = "auto"
    options.terrain_dir (1,1) string = itm_default_terrain_dir()
    options.download (1,1) logical = true
    options.validity (1,1) string {mustBeMember(options.validity, ["error", "warn", "off"])} = "error"
end

% Pair transmitters and receivers
n = max(size(tx, 1), size(rx, 1));
if size(tx, 1) ~= n && size(tx, 1) ~= 1 || size(rx, 1) ~= n && size(rx, 1) ~= 1
    error('itm:SizeMismatch', 'tx and rx must have the same number of rows, or one row.');
end
tx = repmat(tx, n / size(tx, 1), 1);
rx = repmat(rx, n / size(rx, 1), 1);
if any(abs([tx(:, 1); rx(:, 1)]) > 90)
    error('itm:InvalidLatitude', 'Latitude must be within [-90, 90] degrees.');
end
pol = parse_polarization(options.polarization);
% Validate the percentages and convert them to normal deviates once, before
% any terrain download; every link reuses them.
z = itm_percentiles(reliability, options.confidence, 50);

% Terrain profiles and path geometry. The profile call samples every link
% in one pass over the tiles and returns each geodesic's length and
% midpoint from the same reckon call, so they aren't solved again here.
if isempty(options.pfl)
    [pfls, pinfo] = itm_terrain_profile_rev1(tx(:, 1), tx(:, 2), rx(:, 1), rx(:, 2), ...
        spacing_m=options.spacing_m, max_points=options.max_points, ...
        source=options.terrain_source, terrain_dir=options.terrain_dir, download=options.download);
    if n == 1
        pfls = {pfls};
    end
    mid = vertcat(pinfo.midpoint_deg);
    lat_mid = mid(:, 1);
    lon_mid = mid(:, 2);
else
    pfls = options.pfl;
    if ~iscell(pfls)
        pfls = {pfls};
    end
    if numel(pfls) ~= n
        error('itm:SizeMismatch', 'pfl must be one profile or a cell array of %d profiles.', n);
    end
    ellipsoid = itm_wgs84();
    [d_m, az] = itm_geodesic_inverse(tx(:, 1), tx(:, 2), rx(:, 1), rx(:, 2));
    lat_mid = zeros(n, 1);
    lon_mid = zeros(n, 1);
    for k = 1:n            % per path, so a link's midpoint doesn't depend on the batch
        [lat_mid(k), lon_mid(k)] = reckon(tx(k, 1), tx(k, 2), d_m(k) / 2, az(k), ellipsoid);
    end
    pinfo = struct('distance_m', num2cell(d_m), 'source_code', [], 'tiles', strings(0, 1));
end

% Radio climate (ITU-R P.617) and refractivity (ITU-R P.452), vectorized
if isempty(options.climate)
    climate = itm_radio_climate_rev1(lat_mid, lon_mid);
    sea = climate == 7;
    if any(sea)
        ends = min(itm_radio_climate_rev1(tx(sea, 1), tx(sea, 2)), ...
            itm_radio_climate_rev1(rx(sea, 1), rx(sea, 2)));
        climate(sea) = ends;
    end
    climate_source = "ITU-R P.617 (path midpoint)";
else
    climate = expand(options.climate, n, 'climate');
    climate_source = "user";
end
if isempty(options.N_0)
    N_0 = itm_surface_refractivity_rev1(lat_mid, lon_mid);
    N_0_source = "ITU-R P.452 N050 (path midpoint)";
else
    N_0 = expand(options.N_0, n, 'N_0');
    N_0_source = "user";
end

% ITM core per link; each call is vectorized over reliability and confidence
out_size = z.size;
k_out = prod(out_size);
loss = zeros(n, k_out);
iinfo = cell(n, 1);
wbits = zeros(n, 1, 'uint32');
elev_deg = zeros(n, 2);
d_km = zeros(n, 1);
% itm_p2p_core skips the per-call arguments block (inputs validated above)
want_info = nargout > 1;
for k = 1:n
    try
        [Lk, iinfo{k}, wbits(k), elev_deg(k, :)] = itm_p2p_core(tx(k, 3), rx(k, 3), pfls{k}, f_mhz, reliability, ...
            options.confidence, 50, climate(k), N_0(k), pol, options.epsilon, options.sigma, ...
            options.mdvar, want_info, z);
    catch err
        if n == 1
            rethrow(err);
        end
        error(err.identifier, "Link %d: %s", k, err.message);   % name the failing link
    end
    loss(k, :) = Lk(:).';
    d_km(k) = pfls{k}(1) * pfls{k}(2) / 1000;
end
itm_validity(wbits, d_km, options.validity);
if n == 1
    loss_db = reshape(loss, out_size);
else
    loss_db = loss;
end

if nargout > 1
    info = vertcat(iinfo{:});
    for k = 1:n
        info(k).climate = climate(k);
        info(k).climate_source = climate_source;
        info(k).N_0 = N_0(k);
        info(k).N_0_source = N_0_source;
        info(k).midpoint_deg = [lat_mid(k), lon_mid(k)];
        info(k).pfl = pfls{k};
        info(k).profile = pinfo(k);
    end
end
end

function v = expand(v, n, name)
v = v(:);
if isscalar(v)
    v = repmat(v, n, 1);
elseif numel(v) ~= n
    error('itm:SizeMismatch', '%s must be a scalar or have one value per link (%d).', name, n);
end
end

function pol = parse_polarization(p)
if isnumeric(p) && isscalar(p) && (p == 0 || p == 1)
    pol = double(p);
elseif (isstring(p) || ischar(p)) && any(strcmpi(p, ["vertical", "v"]))
    pol = 1;
elseif (isstring(p) || ischar(p)) && any(strcmpi(p, ["horizontal", "h"]))
    pol = 0;
else
    error('itm:InvalidPolarization', 'polarization must be "vertical", "horizontal", 1, or 0.');
end
end
