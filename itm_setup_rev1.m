function summary = itm_setup_rev1(options)
%ITM_SETUP_REV1 Cache the ITU maps and terrain tiles ahead of time.
%   summary = ITM_SETUP_REV1() loads the ITU-R climate and refractivity
%   maps (from this repository, or downloaded from the ITU) and reports
%   the cache folder.
%   summary = ITM_SETUP_REV1(region=[lat_min lat_max lon_min lon_max])
%   also caches every terrain tile that covers the region, so analyses run
%   afterward with download=false, or with MATLAB_ITM_OFFLINE=1 on a
%   machine without internet (copy the cache folder there and set
%   MATLAB_ITM_CACHE). Downloads are atomic, so several machines can fill
%   one shared folder at once.
%   MATLAB_ITM_OFFLINE=1 also blocks this function's downloads, so leave
%   it unset on the connected machine that fills the cache.
%
%   With source "auto" (default), each tile is taken from USGS 3DEP; where
%   3DEP has no tile or has gaps (borders, coasts), the Copernicus GLO-30
%   tile is cached too, and GLO-90 where GLO-30 has none. A 3DEP 1
%   arc-second tile is about 45 MB.
%
%   Name-value options:
%     cache_dir  Cache root for this MATLAB session (sets MATLAB_ITM_CACHE).
%                Default: ~/.matlab_itm (Windows: C:\matlab_itm, or
%                %LOCALAPPDATA%\matlab_itm if C:\matlab_itm isn't writable)
%     region     [lat_min lat_max lon_min lon_max] in degrees; default none
%     source     "auto" (default), "usgs3dep", "usgs3dep13" (~370 MB per tile),
%                "copernicus", or "copernicus90"
%
%   summary is a table with one row per tile and the file cached from
%   each source ("" where the provider has no tile).
%
%   Example: Mid-Atlantic, about 36 tiles
%     itm_setup_rev1(region=[36 42 -80 -74])
%
%   Adapted from p2001_setup_rev1 in nicklasorte/itu_p2001.

arguments
    options.cache_dir (1,1) string = ""
    options.region double {mustBeReal, mustBeFinite} = []
    options.source (1,1) string {mustBeMember(options.source, ["auto", "usgs3dep", "usgs3dep13", "copernicus", "copernicus90"])} = "auto"
end

if strlength(options.cache_dir) > 0
    setenv('MATLAB_ITM_CACHE', options.cache_dir);
end
itm_maps();
terrain_dir = itm_default_terrain_dir();
fprintf('ITU maps ready. Terrain cache: %s\n', terrain_dir);

r = options.region;
if isempty(r)
    summary = table('Size', [0 6], 'VariableTypes', ["double", "double", "string", "string", "string", "string"], ...
        'VariableNames', ["south_lat", "west_lon", "usgs3dep_file", "copernicus_file", "copernicus90_file", "usgs3dep13_file"]);
    return
end
if numel(r) ~= 4 || r(1) >= r(2) || r(3) >= r(4) || r(1) < -90 || r(2) > 90
    error('itm:setup:Region', 'region must be [lat_min lat_max lon_min lon_max] with min < max.');
end
lats = floor(r(1)):min(ceil(r(2)) - 1, 89);
lons = unique(mod((floor(r(3)):ceil(r(4)) - 1) + 180, 360) - 180);
[LA, LO] = ndgrid(lats, lons);
n = numel(LA);
files = strings(n, 4);
names = ["usgs3dep", "copernicus", "copernicus90", "usgs3dep13"];
for k = 1:n
    get = @(s) itm_get_tile(char(names(s)), LA(k), LO(k), char(terrain_dir), true);
    if options.source ~= "auto"
        s = find(names == options.source);
        files(k, s) = get(s);
    else
        files(k, 1) = get(1);
        if tile_has_gaps(files(k, 1))           % no 3DEP tile, or partial
            files(k, 2) = get(2);
            if files(k, 2) == ""                % not released in GLO-30
                files(k, 3) = get(3);
            end
        end
    end
    fprintf('Tile %d of %d (%d, %d): %s\n', k, n, LA(k), LO(k), ...
        strjoin(names(files(k, :) ~= ""), ' + '));
end
summary = table(LA(:), LO(:), files(:, 1), files(:, 2), files(:, 3), files(:, 4), 'VariableNames', ...
    ["south_lat", "west_lon", "usgs3dep_file", "copernicus_file", "copernicus90_file", "usgs3dep13_file"]);
end

function tf = tile_has_gaps(file)
if file == ""
    tf = true;
    return
end
Z = readgeoraster(file, 'OutputType', 'single');
info = georasterinfo(file);
if ~isempty(info.MissingDataIndicator)
    Z = standardizeMissing(Z, single(info.MissingDataIndicator));
end
tf = any(isnan(Z(:)) | Z(:) < -1000);
end
