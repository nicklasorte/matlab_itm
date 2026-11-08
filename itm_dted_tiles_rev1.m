function files = itm_dted_tiles_rev1(tile_lat, tile_lon, options)
%ITM_DTED_TILES_REV1 Write USGS 3DEP 1-arc-second terrain as DTED level 2 tiles.
%   files = ITM_DTED_TILES_REV1(tile_lat, tile_lon) writes one DTED level 2
%   file (1 arc-second, 3601 x 3601 postings) for each 1-degree tile whose
%   southwest corner is (tile_lat(k), tile_lon(k)), and returns the file
%   names. The heights come from itm_terrain_elevation_rev1: USGS 3DEP 1",
%   with Copernicus GLO-30 where 3DEP has no data (source "auto").
%
%   MATLAB's terrain models (propagationModel "longley-rice" and "tirem",
%   siteviewer) read custom terrain only from DTED, through
%   addCustomTerrain. These files let them use the same 1" terrain as
%   itm_pathloss_rev1:
%
%     files = itm_dted_tiles_rev1(38, -77);
%     addCustomTerrain("usgs1", files);
%     pl = pathloss(propagationModel("longley-rice"), rx, tx, Map="usgs1");
%
%   Postings sit on whole arc-seconds, the DTED grid, so heights are the
%   bilinear interpolation of the USGS grid at those points, rounded to
%   whole meters as DTED requires. Water with no data is 0 m.
%
%   DTED level 2 has 1" longitude spacing only below 50 degrees latitude;
%   tiles farther north raise an error.
%
%   Name-value options:
%     folder    output folder (<cache>/dted, see itm_default_terrain_dir)
%     source    terrain source for itm_terrain_elevation_rev1 ("auto")
%     overwrite rewrite tiles that already exist (false)
%
%   Files follow the DTED naming: <folder>/w077/n38.dt2.
%
%   See also itm_terrain_elevation_rev1, addCustomTerrain.

arguments
    tile_lat double {mustBeInteger, mustBeInRange(tile_lat, -50, 49)}
    tile_lon double {mustBeInteger, mustBeInRange(tile_lon, -180, 179)}
    options.folder (1,1) string = fullfile(fileparts(itm_default_terrain_dir()), "dted")
    options.source (1,1) string = "auto"
    options.overwrite (1,1) logical = false
end

tile_lat = tile_lat(:);
tile_lon = tile_lon(:);
if numel(tile_lat) ~= numel(tile_lon)
    error('itm:dted:SizeMismatch', 'tile_lat and tile_lon must have the same number of elements.');
end
n_post = 3601;
files = strings(numel(tile_lat), 1);
for k = 1:numel(tile_lat) % one tile at a time: 13 million postings each
    la0 = tile_lat(k);
    lo0 = tile_lon(k);
    sub = fullfile(options.folder, sprintf('%s%03d', ew(lo0), abs(lo0)));
    files(k) = fullfile(sub, sprintf('%s%02d.dt2', ns(la0), abs(la0)));
    if isfile(files(k)) && ~options.overwrite
        continue
    end
    if ~isfolder(sub)
        mkdir(sub);
    end
    % Postings: column j is longitude lo0 + (j-1)/3600, south to north
    [LAT, LON] = ndgrid(la0 + (0:n_post - 1)' / 3600, lo0 + (0:n_post - 1) / 3600);
    z = itm_terrain_elevation_rev1(LAT(:), LON(:), source=options.source);
    z = reshape(round(z), n_post, n_post);
    z(isnan(z)) = 0;
    write_dted2(files(k), la0, lo0, z);
end
end

%% ------------------------------------------------------------------------
function write_dted2(file, la0, lo0, z)
% DTED level 2 per MIL-PRF-89020B: UHL (80), DSI (648), ACC (2700), then
% one record per longitude line (south to north, signed-magnitude int16,
% big-endian, with sentinel, counts, and checksum).
n = size(z, 1);
lat_s = sprintf('%03d0000%s', abs(la0), ns(la0));          % DDDMMSSH
lon_s = sprintf('%03d0000%s', abs(lo0), ew(lo0));
uhl = ['UHL1', lon_s, lat_s, '0010', '0010', 'NA  ', 'U  ', blanks(12), ...
    sprintf('%04d', n), sprintf('%04d', n), '0', blanks(24)];

corner = @(la, lo) [sprintf('%02d0000%s', abs(la), ns(la)), sprintf('%03d0000%s', abs(lo), ew(lo))];
dsi = ['DSI', 'U', blanks(2), blanks(27), blanks(26), 'DTED2', blanks(15), blanks(8), '01', 'A', ...
    '0000', '0000', '0000', 'USGS    ', blanks(16), 'PRF89020B', '00', '0005', 'MSL', 'WGS84', ...
    blanks(10), '0000', blanks(22), sprintf('%02d0000.0%s', abs(la0), ns(la0)), ...
    sprintf('%03d0000.0%s', abs(lo0), ew(lo0)), corner(la0, lo0), corner(la0 + 1, lo0), ...
    corner(la0 + 1, lo0 + 1), corner(la0, lo0 + 1), '0000000.0', '0010', '0010', ...
    sprintf('%04d', n), sprintf('%04d', n), '00', blanks(101), blanks(100), blanks(156)];
acc = ['ACC', 'NA  ', 'NA  ', 'NA  ', 'NA  ', blanks(4), ' ', blanks(31), '00', blanks(2700 - 57)];
assert(numel(uhl) == 80 && numel(dsi) == 648 && numel(acc) == 2700, 'DTED header lengths are wrong.');

% Signed magnitude: bit 15 is the sign, bits 0-14 the absolute value
mag = uint16(min(abs(z), 32767));
v = bitor(mag, uint16(z < 0) * uint16(32768));
hi = uint8(bitshift(v, -8));
lo = uint8(bitand(v, uint16(255)));
data = zeros(2 * n, n, 'uint8');
data(1:2:end, :) = hi;
data(2:2:end, :) = lo;

rec = zeros(8 + 2 * n + 4, n, 'uint8');
col = uint32(0:n - 1);
rec(1, :) = 170;                                            % sentinel 0xAA
rec(2, :) = uint8(bitshift(col, -16));                      % data block count (3 bytes)
rec(3, :) = uint8(bitand(bitshift(col, -8), 255));
rec(4, :) = uint8(bitand(col, 255));
rec(5, :) = uint8(bitshift(col, -8));                       % longitude count (2 bytes)
rec(6, :) = uint8(bitand(col, 255));
rec(7:8, :) = 0;                                            % latitude count
rec(9:8 + 2 * n, :) = data;
chk = uint32(sum(double(rec(1:8 + 2 * n, :)), 1));          % sum of the record's bytes
rec(end - 3, :) = uint8(bitshift(chk, -24));
rec(end - 2, :) = uint8(bitand(bitshift(chk, -16), 255));
rec(end - 1, :) = uint8(bitand(bitshift(chk, -8), 255));
rec(end, :) = uint8(bitand(chk, 255));

tmp = file + ".part";
fid = fopen(tmp, 'w');
if fid < 0
    error('itm:dted:Write', 'Cannot write %s.', tmp);
end
fwrite(fid, [uint8(uhl), uint8(dsi), uint8(acc)], 'uint8');
fwrite(fid, rec(:), 'uint8');
fclose(fid);
movefile(tmp, file, 'f');
end

function c = ns(la)
c = 'N';
if la < 0, c = 'S'; end
end

function c = ew(lo)
c = 'E';
if lo < 0, c = 'W'; end
end
