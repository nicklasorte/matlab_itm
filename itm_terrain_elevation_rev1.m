function [z_m, info] = itm_terrain_elevation_rev1(lat_deg, lon_deg, options)
%ITM_TERRAIN_ELEVATION_REV1 Terrain elevation from cached DEM tiles.
%   z_m = ITM_TERRAIN_ELEVATION_REV1(lat_deg, lon_deg) returns the terrain
%   elevation (m above the vertical datum) at each point, by bilinear
%   interpolation of 1 x 1 degree GeoTIFF tiles. Tiles are downloaded once
%   to a local cache folder (or reused from the itu_p2001 cache) and kept
%   in memory up to a size cap.
%
%   Sources (public, no account or key):
%     "usgs3dep"     USGS 3DEP 1 arc-second (~30 m) bare-earth DEM, NAVD88.
%                    Covers the U.S., Puerto Rico, the U.S. Virgin Islands,
%                    Guam, and parts of Canada and Mexico near the border.
%     "usgs3dep13"   USGS 3DEP 1/3 arc-second (~10 m) bare earth. CONUS,
%                    Hawaii, territories. ~370 MB per tile; use with
%                    spacing_m=10 in itm_terrain_profile_rev1.
%     "copernicus"   Copernicus GLO-30 (~30 m) DEM, EGM2008, global. It is a
%                    surface model: it includes buildings and tree canopy.
%     "copernicus90" Copernicus GLO-90 (~90 m), global; fills tiles not
%                    released in GLO-30.
%     "auto"         (default) 3DEP 1 arc-second first, then GLO-30, then
%                    GLO-90 for any point the previous source has no data for.
%   Points with no data in any source are set to 0 m when they are water:
%   inside a tile (no-data cells along coasts) or over sea on the ITU-R
%   P.617 map. A land point that no chosen source covers is an error
%   (itm:terrain:NoCoverage), so a forced single source can't silently
%   read land outside its coverage as sea level.
%
%   Name-value options:
%     source       "auto" (default), "usgs3dep", "usgs3dep13", "copernicus",
%                  or "copernicus90"
%     terrain_dir  Tile cache folder. Default: env MATLAB_ITM_TERRAIN_DIR,
%                  else <cache>/terrain (see itm_setup_rev1)
%     download     Download missing tiles (true). Set false on offline
%                  servers after itm_setup_rev1.
%     cache_gb     Memory for decoded tiles, GB. Default: env
%                  MATLAB_ITM_TILE_CACHE_GB, else 2 (about 38 one-arc-second
%                  tiles). Oldest-used tiles are dropped first.
%
%   info returns per-point source codes (0 none/water, 1 3DEP 1",
%   2 GLO-30, 3 GLO-90, 4 3DEP 1/3") and the tile files used.
%
%   Tile handling adapted from p2001_dem_tile_rev1 and
%   p2001_terrain_profile_rev1 in nicklasorte/itu_p2001.
%
%   See also itm_terrain_profile_rev1, itm_setup_rev1.

arguments
    lat_deg double {mustBeReal, mustBeFinite, mustBeInRange(lat_deg, -90, 90)}
    lon_deg double {mustBeReal, mustBeFinite}
    options.source (1,1) string {mustBeMember(options.source, ["auto", "usgs3dep", "usgs3dep13", "copernicus", "copernicus90"])} = "auto"
    options.terrain_dir (1,1) string = itm_default_terrain_dir()
    options.download (1,1) logical = true
    options.cache_gb (1,1) double {mustBePositive} = default_cache_gb()
end

if ~isequal(size(lat_deg), size(lon_deg))
    error('itm:terrain:SizeMismatch', 'lat_deg and lon_deg must be the same size.');
end
sz = size(lat_deg);
lat = lat_deg(:);
lon = mod(lon_deg(:) + 180, 360) - 180;

z = nan(numel(lat), 1);
src = zeros(numel(lat), 1, 'uint8');
in_tile = false(numel(lat), 1);
files = strings(0, 1);

code_names = ["usgs3dep", "copernicus", "copernicus90", "usgs3dep13"];
if options.source == "auto"
    order = ["usgs3dep", "copernicus", "copernicus90"];
else
    order = options.source;
end

for s = 1:numel(order)
    todo = isnan(z);
    if ~any(todo)
        break
    end
    [z_s, has_tile, used] = sample_source(char(order(s)), lat(todo), lon(todo), options);
    idx = find(todo);
    in_tile(idx(has_tile)) = true;
    got = ~isnan(z_s);
    z(idx(got)) = z_s(got);
    src(idx(got)) = find(code_names == order(s));
    files = [files; used]; %#ok<AGROW> few tiles per call
end

% No data in any source. Water if inside a tile (coastal no-data cells) or
% sea on the ITU-R P.617 map (0.5 degree, code 0, read as 7 here);
% otherwise land outside the chosen sources' coverage.
no_data = isnan(z);
if any(no_data & ~in_tile)
    open = find(no_data & ~in_tile);
    land = itm_radio_climate_rev1(lat(open), lon(open)) ~= 7;
    if any(land)
        k = open(find(land, 1));
        error('itm:terrain:NoCoverage', ...
            ['%d land points have no %s tile (first at %.4f, %.4f). ' ...
            'Use source "auto" or "copernicus" outside the U.S.'], ...
            nnz(land), strjoin(order, '/'), lat(k), lon(k));
    end
end
z(no_data) = 0;
z_m = reshape(z, sz);
info = struct('source_code', reshape(src, sz), ...
    'source_names', {{'none (0 m, water)', 'USGS 3DEP 1 arc-second', 'Copernicus GLO-30', ...
    'Copernicus GLO-90', 'USGS 3DEP 1/3 arc-second'}}, ...
    'tiles', unique(files(files ~= "")));
end

function gb = default_cache_gb()
gb = str2double(getenv('MATLAB_ITM_TILE_CACHE_GB'));
if ~(isfinite(gb) && gb > 0)
    gb = 2;
end
end

function [z, has_tile, used] = sample_source(source, lat, lon, options)
z = nan(size(lat));
has_tile = false(size(lat));
tlat = min(floor(lat), 89);
tlon = min(floor(lon), 179);
[keys, ~, which_tile] = unique([tlat, tlon], 'rows');
used = strings(size(keys, 1), 1);
sidecar_dir = fullfile(options.terrain_dir, source);
for k = 1:size(keys, 1)
    file = itm_get_tile(source, keys(k, 1), keys(k, 2), char(options.terrain_dir), options.download);
    used(k) = file;
    if file == ""
        continue
    end
    [F, R] = tile_cache(file, sidecar_dir, options.cache_gb);
    pick = which_tile == k;
    has_tile(pick) = true;
    % Clamp into the raster limits: Copernicus tiles stop one posting
    % short of their east and south edges; the sliver is under a pixel.
    la = min(max(lat(pick), R.LatitudeLimits(1)), R.LatitudeLimits(2));
    lo = min(max(lon(pick), R.LongitudeLimits(1)), R.LongitudeLimits(2));
    % Same result as geointerp(Z, R, la, lo, "linear"), bit for bit, but
    % the interpolant is built once per tile instead of on every call.
    [x, y] = geographicToIntrinsic(R, la, lo);
    z(pick) = F(y, x);
end
end

function [F, R] = tile_cache(file, sidecar_dir, cache_gb)
% Least-recently-used in-memory cache of tile interpolants, capped by size.
% Decoding a GeoTIFF (LZW) takes about 170 ms; the decoded grid is also
% kept on disk in this tool's cache (<tile>.zcache and <tile>.rcache.mat),
% even for tiles shared from the itu_p2001 cache, and a new MATLAB or app
% process reads it in about 10 ms.
persistent names interps refs stamps bytes
if isempty(names)
    names = strings(0, 1); interps = {}; refs = {}; stamps = zeros(0, 1); bytes = zeros(0, 1);
end
hit = find(names == file, 1);
if ~isempty(hit)
    stamps(hit) = now_counter();
    F = interps{hit};
    R = refs{hit};
    return
end
[~, base, ext] = fileparts(file);
[Z, R] = read_tile(file, fullfile(sidecar_dir, base + ext));
% 'nearest' extrapolation matches geointerp in the half-pixel border of a
% cells raster; points are clamped to the raster limits before lookup.
F = griddedInterpolant(Z, 'linear', 'nearest');
names(end + 1, 1) = file;
interps{end + 1, 1} = F;
refs{end + 1, 1} = R;
stamps(end + 1, 1) = now_counter();
bytes(end + 1, 1) = 4 * numel(Z);
while sum(bytes) > cache_gb * 1e9 && numel(names) > 1     % keep the newest
    [~, old] = min(stamps);
    names(old) = []; interps(old) = []; refs(old) = []; stamps(old) = []; bytes(old) = [];
end
end

function [Z, R] = read_tile(file, sidecar_base)
zfile = string(sidecar_base) + ".zcache";
rfile = string(sidecar_base) + ".rcache.mat";
if isfile(zfile) && isfile(rfile)
    try
        s = load(rfile, 'R', 'sz');
        fid = fopen(zfile, 'r');
        Z = [];
        if fid >= 0
            Z = fread(fid, [s.sz(1) s.sz(2)], '*single');
            fclose(fid);
        end
        if isequal(size(Z), s.sz)
            R = s.R;
            return
        end
    catch
        % unreadable or partial sidecar: decode the GeoTIFF again
    end
end
[Z, R] = readgeoraster(file, 'OutputType', 'single');
info = georasterinfo(file);
if ~isempty(info.MissingDataIndicator)
    Z = standardizeMissing(Z, single(info.MissingDataIndicator));
end
Z(Z < -1000) = NaN;            % guard against unflagged fill values
write_sidecars(Z, R, zfile, rfile);
end

function write_sidecars(Z, R, zfile, rfile)
% Best effort: a read-only cache folder just means decoding every time.
folder = fileparts(zfile);
if ~isfolder(folder)
    mkdir(folder);
end
% The grid file is written first and the small .mat last, and each is
% renamed into place atomically, so readers never see a partial pair.
try
    if ~isfile(zfile)
        [~, token] = fileparts(tempname);
        tmp = zfile + "." + token + ".part";
        fid = fopen(tmp, 'w');
        if fid < 0
            return
        end
        fwrite(fid, Z, 'single');
        fclose(fid);
        itm_publish_file(tmp, zfile);
    end
    itm_atomic_save(rfile, struct('R', R, 'sz', size(Z)));
catch
end
end

function c = now_counter()
persistent n
if isempty(n), n = 0; end
n = n + 1;
c = n;
end
