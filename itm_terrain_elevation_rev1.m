function [z_m, info] = itm_terrain_elevation_rev1(lat_deg, lon_deg, options)
%ITM_TERRAIN_ELEVATION_REV1 Terrain elevation from cached 1 arc-second DEM tiles.
%   z_m = ITM_TERRAIN_ELEVATION_REV1(lat_deg, lon_deg) returns the terrain
%   elevation (m above the vertical datum) at each point, by bilinear
%   interpolation of 1 x 1 degree GeoTIFF tiles. Tiles are downloaded once
%   to a local cache folder and reused; up to max_tiles stay in memory.
%
%   Sources (public, no account or key):
%     "usgs3dep"    USGS 3DEP 1 arc-second (~30 m) bare-earth DEM, NAVD88.
%                   Covers the U.S., Puerto Rico, the U.S. Virgin Islands,
%                   Guam, and parts of Canada and Mexico near the border.
%     "copernicus"  Copernicus GLO-30 (~30 m) DEM, EGM2008, global. It is a
%                   surface model: it includes buildings and tree canopy.
%     "copernicus90" Copernicus GLO-90 (~90 m), global; fills tiles not
%                   released in GLO-30.
%     "auto"        (default) 3DEP first, then GLO-30, then GLO-90 for any
%                   point the previous source has no data for.
%   Points with no data in any source (open ocean) are set to 0 m.
%
%   Name-value options:
%     source       "auto" (default), "usgs3dep", "copernicus", or "copernicus90"
%     terrain_dir  Tile cache folder. Default: env MATLAB_ITM_TERRAIN_DIR,
%                  else %LOCALAPPDATA%\matlab_itm\terrain (Windows) or
%                  ~/.matlab_itm/terrain
%     download     Download missing tiles (true). Set false on offline
%                  servers after itm_setup_rev1.
%     max_tiles    Tiles kept in memory, about 52 MB each (8)
%
%   info returns per-point source codes (0 none/ocean, 1 3DEP, 2 GLO-30,
%   3 GLO-90) and the tile files used.
%
%   See also itm_terrain_profile_rev1, itm_setup_rev1.

arguments
    lat_deg double {mustBeReal, mustBeFinite, mustBeInRange(lat_deg, -90, 90)}
    lon_deg double {mustBeReal, mustBeFinite}
    options.source (1,1) string {mustBeMember(options.source, ["auto", "usgs3dep", "copernicus", "copernicus90"])} = "auto"
    options.terrain_dir (1,1) string = itm_default_terrain_dir()
    options.download (1,1) logical = true
    options.max_tiles (1,1) double {mustBeInteger, mustBePositive} = 8
end

if ~isequal(size(lat_deg), size(lon_deg))
    error('itm:terrain:SizeMismatch', 'lat_deg and lon_deg must be the same size.');
end
sz = size(lat_deg);
lat = lat_deg(:);
lon = mod(lon_deg(:) + 180, 360) - 180;

z = nan(numel(lat), 1);
src = zeros(numel(lat), 1, 'uint8');
files = strings(0, 1);

all_sources = ["usgs3dep", "copernicus", "copernicus90"];
if options.source == "auto"
    order = all_sources;
else
    order = options.source;
end

for s = 1:numel(order)
    todo = isnan(z);
    if ~any(todo)
        break
    end
    [z(todo), used] = sample_source(char(order(s)), lat(todo), lon(todo), options);
    src(todo & ~isnan(z)) = find(all_sources == order(s));
    files = [files; used]; %#ok<AGROW> few tiles per call
end

z(isnan(z)) = 0;               % no source has data: open water
z_m = reshape(z, sz);
info = struct('source_code', reshape(src, sz), ...
    'source_names', {{'none (0 m)', 'USGS 3DEP 1 arc-second', 'Copernicus GLO-30', 'Copernicus GLO-90'}}, ...
    'tiles', unique(files(files ~= "")));
end

function [z, used] = sample_source(source, lat, lon, options)
z = nan(size(lat));
tlat = min(floor(lat), 89);
tlon = min(floor(lon), 179);
[keys, ~, which_tile] = unique([tlat, tlon], 'rows');
used = strings(size(keys, 1), 1);
for k = 1:size(keys, 1)
    file = itm_get_tile(source, keys(k, 1), keys(k, 2), char(options.terrain_dir), options.download);
    used(k) = file;
    if file == ""
        continue
    end
    [Z, R] = tile_cache(file, options.max_tiles);
    pick = which_tile == k;
    % Clamp into the raster limits: Copernicus tiles stop one posting
    % short of their east edge, and the sliver is under one pixel wide.
    la = min(max(lat(pick), R.LatitudeLimits(1)), R.LatitudeLimits(2));
    lo = min(max(lon(pick), R.LongitudeLimits(1)), R.LongitudeLimits(2));
    z(pick) = geointerp(Z, R, la, lo, 'linear');
end
end

function [Z, R] = tile_cache(file, max_tiles)
% Least-recently-used in-memory cache of decoded tiles
persistent names rasters refs stamps
if isempty(names)
    names = strings(0, 1); rasters = {}; refs = {}; stamps = zeros(0, 1);
end
hit = find(names == file, 1);
if ~isempty(hit)
    stamps(hit) = now_counter();
    Z = rasters{hit};
    R = refs{hit};
    return
end
[Z, R] = readgeoraster(file, 'OutputType', 'single');
info = georasterinfo(file);
if ~isempty(info.MissingDataIndicator)
    Z = standardizeMissing(Z, single(info.MissingDataIndicator));
end
Z(Z < -1000) = NaN;            % guard against unflagged fill values
if numel(names) >= max_tiles
    [~, old] = min(stamps);
    names(old) = []; rasters(old) = []; refs(old) = []; stamps(old) = [];
end
names(end + 1, 1) = file;
rasters{end + 1, 1} = Z;
refs{end + 1, 1} = R;
stamps(end + 1, 1) = now_counter();
end

function c = now_counter()
persistent n
if isempty(n), n = 0; end
n = n + 1;
c = n;
end
