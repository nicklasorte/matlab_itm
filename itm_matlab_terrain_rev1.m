function map = itm_matlab_terrain_rev1(tile_lat, tile_lon, options)
%ITM_MATLAB_TERRAIN_REV1 Register USGS 1-arc-second terrain with MATLAB's terrain models.
%   map = ITM_MATLAB_TERRAIN_REV1(tile_lat, tile_lon) makes sure the
%   1-degree tiles with southwest corners (tile_lat, tile_lon) are part of
%   the MATLAB custom terrain "itm_usgs1", and returns that name for the
%   Map argument of pathloss, coverage, elevation, and siteviewer.
%   map = ITM_MATLAB_TERRAIN_REV1(region=[lat_min lat_max lon_min lon_max])
%   does the same for every tile that touches a region; run it once for a
%   study area.
%
%   The tiles are written as DTED level 2 with itm_dted_tiles_rev1 (USGS
%   3DEP 1", Copernicus GLO-30 where 3DEP has no data), the same terrain
%   as itm_pathloss_rev1, and registered with addCustomTerrain.
%
%   Registration is slow (about 30 s per tile, R2025b, Apple silicon) but
%   happens once: MATLAB keeps custom terrain across sessions, and this
%   function records the registered tiles in <dted folder>/itm_usgs1_tiles.mat.
%   When new tiles are needed, the terrain is registered again with all
%   tiles, so register the whole study area up front.
%
%   Name-value options:
%     region   [lat_min lat_max lon_min lon_max] instead of tile lists
%     folder   DTED folder (<cache>/dted)
%     force    register again even if nothing is new (false)
%
%   See also itm_matlab_lr_rev1, itm_dted_tiles_rev1, addCustomTerrain.

arguments
    tile_lat double {mustBeInteger} = zeros(0, 1)
    tile_lon double {mustBeInteger} = zeros(0, 1)
    options.region double = []
    options.folder (1,1) string = fullfile(fileparts(itm_default_terrain_dir()), "dted")
    options.force (1,1) logical = false
end

map = "itm_usgs1";
if ~isempty(options.region)
    g = options.region;
    [LA, LO] = ndgrid(floor(g(1)):ceil(g(2)) - 1, floor(g(3)):ceil(g(4)) - 1);
    tile_lat = LA(:);
    tile_lon = LO(:);
end
tiles = unique([tile_lat(:), tile_lon(:)], 'rows');
if any(tiles(:, 1) < -50 | tiles(:, 1) > 49)
    error('itm:matlabterrain:Latitude', ['USGS 1" terrain for MATLAB covers latitudes -50 to 50 ' ...
        'degrees (DTED level 2 has 1" spacing only there). Use Map="gmted2010" elsewhere.']);
end

record = fullfile(options.folder, "itm_usgs1_tiles.mat");
registered = zeros(0, 2);
if isfile(record)
    s = load(record, 'registered');
    registered = s.registered;
end
if ~options.force && all(ismember(tiles, registered, 'rows'))
    return
end

all_tiles = unique([registered; tiles], 'rows');
n_new = nnz(~ismember(all_tiles, registered, 'rows'));
fprintf(['Registering %d tiles (%d new) as MATLAB custom terrain "%s"; about 30 s per tile, ' ...
    'once.\n'], size(all_tiles, 1), n_new, map);
files = itm_dted_tiles_rev1(all_tiles(:, 1), all_tiles(:, 2), folder=options.folder);
try
    removeCustomTerrain(map);
catch
    % not registered yet
end
addCustomTerrain(map, files, 'FillMissing', true, 'Attribution', 'USGS 3DEP 1 arc-second');
registered = all_tiles; %#ok<NASGU> saved below
save(record, 'registered');
end
