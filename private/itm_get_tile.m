function file = itm_get_tile(source, tile_lat, tile_lon, terrain_dir, download)
%ITM_GET_TILE Local path to a 1 x 1 degree terrain tile, downloading it once.
%   file = ITM_GET_TILE(source, tile_lat, tile_lon, terrain_dir, download)
%   returns the cached GeoTIFF for the tile whose south-west corner is
%   (tile_lat, tile_lon), or "" when the provider has no tile there (for
%   example open ocean). A missing tile is remembered with a zero-byte
%   <name>.404 marker so later runs skip the request.
%
%   Downloads go to a uniquely named temporary file in the same folder and
%   are renamed into place with an atomic move (first writer wins), so
%   several processes or compiled servers can share one terrain folder.
%
%   Sources (both public, no account or key):
%     usgs3dep    USGS 3DEP 1 arc-second DEM (bare earth, U.S. and territories)
%     copernicus  Copernicus GLO-30 DEM (global, 1 arc-second, surface model)

[name, url] = tile_name_url(source, tile_lat, tile_lon);
folder = fullfile(terrain_dir, source);
file = string(fullfile(folder, name));
marker = file + ".404";
if isfile(file)
    return
end
if isfile(marker)
    file = "";
    return
end
if ~download
    error('itm:terrain:TileMissing', ...
        ['Terrain tile %s is not in %s and download is off. ' ...
        'Run itm_download_tiles_rev1 for this area or allow downloads. Source URL: %s'], ...
        name, folder, url);
end
if ~isfolder(folder)
    [ok, msg] = mkdir(folder);
    if ~ok && ~isfolder(folder)
        error('itm:terrain:CacheNotWritable', 'Cannot create terrain folder %s: %s', folder, msg);
    end
end

tmp = file + "." + string(java_free_token()) + ".part";
opts = weboptions('Timeout', 300);
max_tries = 3;
for attempt = 1:max_tries
    try
        websave(tmp, url, opts);
        break
    catch ME
        delete_quietly(tmp);
        if strcmp(ME.identifier, 'MATLAB:webservices:HTTP404StatusCodeError') || ...
                (strcmp(ME.identifier, 'MATLAB:webservices:HTTP403StatusCodeError') && strcmp(source, 'copernicus'))
            % No tile here (Copernicus S3 answers 403 for absent keys)
            fclose(fopen(marker, 'w'));
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
publish_atomically(tmp, file);
end

function [name, url] = tile_name_url(source, tile_lat, tile_lon)
switch source
    case 'usgs3dep'
        % USGS names tiles by their north-west corner, for example
        % n39w077 covers 38-39 N, 77-76 W.
        north = tile_lat + 1;
        ns = 'n'; if north < 0, ns = 's'; end
        ew = 'w'; if tile_lon >= 0, ew = 'e'; end
        tag = sprintf('%s%02d%s%03d', ns, abs(north), ew, abs(tile_lon));
        name = sprintf('USGS_1_%s.tif', tag);
        url = sprintf('https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1/TIFF/current/%s/%s', tag, name);
    case 'copernicus'
        % Copernicus names tiles by their south-west corner
        ns = 'N'; if tile_lat < 0, ns = 'S'; end
        ew = 'E'; if tile_lon < 0, ew = 'W'; end
        stem = sprintf('Copernicus_DSM_COG_10_%s%02d_00_%s%03d_00_DEM', ns, abs(tile_lat), ew, abs(tile_lon));
        name = [stem '.tif'];
        url = sprintf('https://copernicus-dem-30m.s3.amazonaws.com/%s/%s', stem, name);
    otherwise
        error('itm:terrain:UnknownSource', 'Unknown terrain source "%s".', source);
end
end

function publish_atomically(tmp, file)
if isfile(file)                       % another process finished first
    delete_quietly(tmp);
    return
end
if usejava('jvm')
    try
        src = java.nio.file.Paths.get(char(tmp), javaArray('java.lang.String', 0));
        dst = java.nio.file.Paths.get(char(file), javaArray('java.lang.String', 0));
        opt = javaArray('java.nio.file.CopyOption', 1);
        opt(1) = java.nio.file.StandardCopyOption.ATOMIC_MOVE;
        java.nio.file.Files.move(src, dst, opt);
    catch
        % FileAlreadyExistsException: first writer won; keep theirs
        delete_quietly(tmp);
    end
else
    % No JVM (-nojvm): movefile is not atomic, but the file was complete
    % and validated before the move.
    if ~isfile(file)
        movefile(tmp, file);
    else
        delete_quietly(tmp);
    end
end
end

function t = java_free_token()
% Unique suffix that does not depend on the global rng state, so servers
% started with the same seed still get distinct temporary names.
[~, t] = fileparts(tempname);
end

function delete_quietly(f)
if isfile(f)
    delete(f);
end
end
