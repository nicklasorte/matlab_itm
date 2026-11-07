function report = itm_download_tiles_rev1(lat_lim, lon_lim, options)
%ITM_DOWNLOAD_TILES_REV1 Pre-download terrain tiles for an area.
%   report = ITM_DOWNLOAD_TILES_REV1(lat_lim, lon_lim) caches every
%   1 x 1 degree tile that touches the box lat_lim = [south north],
%   lon_lim = [west east] (degrees). Run it once on a connected machine,
%   then run analyses with download=false, or point several servers at the
%   same terrain_dir. Downloads are atomic, so parallel runs are safe.
%
%   With source "auto" (default) it caches the USGS 3DEP tile and, where
%   3DEP has no tile or has gaps (borders, coasts), the Copernicus tile.
%   A 3DEP 1 arc-second tile is about 45 MB; CONUS is about 1,000 tiles.
%
%   Name-value options:
%     source       "auto" (default), "usgs3dep", or "copernicus"
%     terrain_dir  Cache folder (see itm_terrain_elevation_rev1)
%
%   report is a table with one row per tile and the file found for each
%   source ("" where the provider has no tile).
%
%   Example: tiles for a 100 km radius around Washington, DC
%     itm_download_tiles_rev1([37.9 39.8], [-78.2 -75.9])

arguments
    lat_lim (1,2) double {mustBeReal, mustBeFinite, mustBeInRange(lat_lim, -90, 90)}
    lon_lim (1,2) double {mustBeReal, mustBeFinite}
    options.source (1,1) string {mustBeMember(options.source, ["auto", "usgs3dep", "copernicus"])} = "auto"
    options.terrain_dir (1,1) string = itm_default_terrain_dir()
end

lat_lim = sort(lat_lim);
lon_lim = sort(lon_lim);
lats = floor(lat_lim(1)):min(ceil(lat_lim(2)) - 1, 89);
lons = floor(lon_lim(1)):ceil(lon_lim(2)) - 1;
lons = unique(mod(lons + 180, 360) - 180);
[LA, LO] = ndgrid(lats, lons);
n = numel(LA);
usgs = strings(n, 1);
cop = strings(n, 1);
dir_ = char(options.terrain_dir);
for k = 1:n
    if options.source ~= "copernicus"
        usgs(k) = itm_get_tile('usgs3dep', LA(k), LO(k), dir_, true);
    end
    need_cop = options.source == "copernicus" || ...
        (options.source == "auto" && (usgs(k) == "" || tile_has_gaps(usgs(k))));
    if need_cop
        cop(k) = itm_get_tile('copernicus', LA(k), LO(k), dir_, true);
    end
    fprintf('Tile %d of %d (%d, %d): 3DEP %s, Copernicus %s\n', k, n, LA(k), LO(k), ...
        status(usgs(k), options.source ~= "copernicus"), status(cop(k), need_cop));
end
report = table(LA(:), LO(:), usgs, cop, 'VariableNames', ...
    {'south_lat', 'west_lon', 'usgs3dep_file', 'copernicus_file'});
end

function tf = tile_has_gaps(file)
Z = readgeoraster(file, 'OutputType', 'single');
info = georasterinfo(file);
if ~isempty(info.MissingDataIndicator)
    Z = standardizeMissing(Z, single(info.MissingDataIndicator));
end
tf = any(isnan(Z(:)) | Z(:) < -1000);
end

function s = status(f, tried)
if ~tried
    s = "skipped";
elseif f == ""
    s = "no tile";
else
    s = "cached";
end
end
