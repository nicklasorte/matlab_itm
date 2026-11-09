function file = itm_get_tile(source, tile_lat, tile_lon, terrain_dir, download)
%ITM_GET_TILE Local path to a 1 x 1 degree terrain tile, downloading it once.
%   file = ITM_GET_TILE(source, tile_lat, tile_lon, terrain_dir, download)
%   returns the cached GeoTIFF for the tile whose south-west corner is
%   (tile_lat, tile_lon), or "" when the provider has no tile there (open
%   ocean, or outside the source's coverage).
%
%   Sources (public HTTPS buckets, no account or key):
%     usgs3dep      USGS 3DEP 1 arc-second (~30 m), bare earth, NAVD88. U.S.
%                   and territories. ~45 MB per tile.
%     usgs3dep13    USGS 3DEP 1/3 arc-second (~10 m), bare earth, NAVD88.
%                   CONUS, Hawaii, territories. ~370 MB per tile.
%     copernicus    Copernicus GLO-30 (1 arc-second), surface model, global
%     copernicus90  Copernicus GLO-90 (3 arc-second), global, fills tiles
%                   not released in GLO-30
%
%   Lookup order for a tile:
%     1. terrain_dir/<source>/<file> (this tool's cache)
%     2. The itu_p2001 cache (ITU_P2001_CACHE, else ~/.itu_p2001 or
%        %LOCALAPPDATA%\itu_p2001), dem/<usgs1|usgs13|cop30|cop90>/<file>.
%        Both tools use the providers' file names, so a tile downloaded by
%        either is reused by the other and not stored twice. Set
%        MATLAB_ITM_SHARE_P2001_CACHE=0 to skip this.
%     3. Windows: the earlier default cache, %LOCALAPPDATA%\matlab_itm\terrain
%        (before the default moved to C:\matlab_itm), read in place.
%     4. A <file>.404 marker here or a <file>.missing marker there: no tile.
%     5. For Copernicus, the bucket's tileList.txt (cached once): absent
%        means ocean, without a request, so a network or proxy error is
%        never mistaken for open water.
%     6. Download with websave to a temporary file, validated as a raster,
%        then renamed into place atomically (first writer wins), so several
%        processes can share one cache folder.
%
%   MATLAB_ITM_OFFLINE=1 turns downloads off whatever download says, so a
%   compiled app on a machine without internet reports a missing tile
%   (itm:terrain:TileMissing) instead of a network error.
%
%   Adapted from p2001_dem_tile_rev1 in nicklasorte/itu_p2001.

% Resolved paths are remembered for the session, so repeated calls for a
% tile skip the path building and file-system checks (about 0.1 ms each,
% several per tile). Only settled answers (a file, or no tile) are kept.
persistent memo
if isempty(memo)
    memo = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = sprintf('%s|%d|%d|%s|%s|%s', source, tile_lat, tile_lon, terrain_dir, ...
    getenv('ITU_P2001_CACHE'), getenv('MATLAB_ITM_SHARE_P2001_CACHE'));
if isKey(memo, key)
    file = memo(key);
    return
end
download = download && getenv('MATLAB_ITM_OFFLINE') ~= "1";
file = resolve(source, tile_lat, tile_lon, terrain_dir, download);
memo(key) = file;
end

function file = resolve(source, tile_lat, tile_lon, terrain_dir, download)
[name, url, p2001_sub] = tile_name_url(source, tile_lat, tile_lon);
folder = fullfile(terrain_dir, source);
file = string(fullfile(folder, name));
if isfile(file)
    return
end
shared = shared_p2001_path(p2001_sub, name);
if shared ~= "" && isfile(shared)
    file = shared;
    return
end
legacy = legacy_path(source, name, terrain_dir);
if legacy ~= ""
    file = legacy;
    return
end
if isfile(file + ".404") || (shared ~= "" && isfile(shared + ".missing"))
    file = "";
    return
end
if startsWith(source, 'copernicus') && ~in_tile_list(source, name, terrain_dir, download)
    file = "";
    return
end
if ~download
    error('itm:terrain:TileMissing', ...
        ['Terrain tile %s is not in %s and download is off%s. ' ...
        'Run itm_setup_rev1 for this area on a connected machine and copy the cache, ' ...
        'or allow downloads. Source URL: %s'], ...
        name, folder, offline_reason(), url);
end
ensure_folder(folder);

tmp = file + "." + unique_token() + ".part";
max_tries = 3;
for attempt = 1:max_tries
    try
        websave(tmp, url, weboptions('Timeout', 300));
        break
    catch ME
        delete_quietly(tmp);
        if strcmp(ME.identifier, 'MATLAB:webservices:HTTP404StatusCodeError')
            fclose(fopen(file + ".404", 'w'));      % no tile here
            file = "";
            return
        end
        if attempt == max_tries
            error('itm:terrain:DownloadFailed', 'Downloading %s failed after %d tries: %s', ...
                url, max_tries, ME.message);
        end
    end
end

% Confirm the download is a readable raster before publishing it
try
    georasterinfo(tmp);
catch ME
    delete_quietly(tmp);
    error('itm:terrain:BadTile', 'Downloaded tile %s is not a readable GeoTIFF: %s', url, ME.message);
end
itm_publish_file(tmp, file);
end

function [name, url, p2001_sub] = tile_name_url(source, tile_lat, tile_lon)
switch source
    case {'usgs3dep', 'usgs3dep13'}
        % USGS names tiles by their north-west corner: n39w077 covers
        % 38-39 N, 77-76 W.
        if strcmp(source, 'usgs3dep13')
            res = '13'; p2001_sub = 'usgs13';
        else
            res = '1'; p2001_sub = 'usgs1';
        end
        north = tile_lat + 1;
        ns = 'n'; if north < 0, ns = 's'; end
        ew = 'w'; if tile_lon >= 0, ew = 'e'; end
        tag = sprintf('%s%02d%s%03d', ns, abs(north), ew, abs(tile_lon));
        name = sprintf('USGS_%s_%s.tif', res, tag);
        url = sprintf('https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/%s/TIFF/current/%s/%s', ...
            res, tag, name);
    case {'copernicus', 'copernicus90'}
        % Copernicus names tiles by their south-west corner
        ns = 'N'; if tile_lat < 0, ns = 'S'; end
        ew = 'E'; if tile_lon < 0, ew = 'W'; end
        [res, bucket, p2001_sub] = copernicus_bucket(source);
        stem = sprintf('Copernicus_DSM_COG_%s_%s%02d_00_%s%03d_00_DEM', res, ns, abs(tile_lat), ew, abs(tile_lon));
        name = [stem '.tif'];
        url = sprintf('https://%s.s3.amazonaws.com/%s/%s', bucket, stem, name);
    otherwise
        error('itm:terrain:UnknownSource', 'Unknown terrain source "%s".', source);
end
end

function [res, bucket, p2001_sub] = copernicus_bucket(source)
if strcmp(source, 'copernicus90')
    res = '30'; bucket = 'copernicus-dem-90m'; p2001_sub = 'cop90';
else
    res = '10'; bucket = 'copernicus-dem-30m'; p2001_sub = 'cop30';
end
end

function s = offline_reason()
% Explains why download is off when the environment variable set it
s = '';
if getenv('MATLAB_ITM_OFFLINE') == "1"
    s = ' (MATLAB_ITM_OFFLINE is 1)';
end
end

function p = legacy_path(source, name, terrain_dir)
% Tile in the earlier Windows default cache (%LOCALAPPDATA%\matlab_itm\terrain),
% read in place so moving the default doesn't download it again; "" if none
p = "";
root = itm_legacy_cache_dir();
if isempty(root), return, end
cand = string(fullfile(root, 'terrain', source, name));
if ~strcmpi(fullfile(root, 'terrain'), terrain_dir) && isfile(cand)
    p = cand;
end
end

function p = shared_p2001_path(sub, name)
% Tile path in the itu_p2001 cache, or "" when sharing is off
p = "";
if getenv('MATLAB_ITM_SHARE_P2001_CACHE') == "0"
    return
end
root = getenv('ITU_P2001_CACHE');
if isempty(root)
    if ispc
        base = getenv('LOCALAPPDATA'); leaf = 'itu_p2001';
    else
        base = getenv('HOME'); leaf = '.itu_p2001';
    end
    if isempty(base)
        return
    end
    root = fullfile(base, leaf);
end
p = string(fullfile(root, 'dem', sub, name));
end

function tf = in_tile_list(source, name, terrain_dir, download)
% True when the Copernicus bucket lists this tile
persistent lists
if isempty(lists)
    lists = struct();
end
if ~isfield(lists, source)
    folder = fullfile(terrain_dir, source);
    list_file = string(fullfile(folder, 'tileList.txt'));
    [~, ~, sub] = copernicus_bucket(source);
    shared = shared_p2001_path(sub, 'tileList.txt');
    if ~isfile(list_file) && shared ~= "" && isfile(shared)
        list_file = shared;
    end
    if ~isfile(list_file)
        if ~download
            error('itm:terrain:TileMissing', ...
                '%s is not cached and download is off%s. Run itm_setup_rev1 first.', list_file, offline_reason());
        end
        ensure_folder(folder);
        [~, bucket] = copernicus_bucket(source);
        tmp = list_file + "." + unique_token() + ".part";
        websave(tmp, sprintf('https://%s.s3.amazonaws.com/tileList.txt', bucket), weboptions('Timeout', 120));
        itm_publish_file(tmp, list_file);
    end
    lists.(source) = strip(readlines(list_file, 'EmptyLineRule', 'skip'));
end
[~, stem] = fileparts(name);
tf = any(lists.(source) == string(stem));
end

function ensure_folder(folder)
if ~isfolder(folder)
    [ok, msg] = mkdir(folder);
    if ~ok && ~isfolder(folder)
        error('itm:terrain:CacheNotWritable', 'Cannot create terrain folder %s: %s', folder, msg);
    end
end
end

function t = unique_token()
% Independent of the global rng, so servers started with the same seed
% still get distinct temporary names
[~, t] = fileparts(tempname);
t = string(t);
end

function delete_quietly(f)
if isfile(f)
    delete(f);
end
end
