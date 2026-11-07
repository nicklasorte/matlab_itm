function d = itm_default_terrain_dir()
%ITM_DEFAULT_TERRAIN_DIR Folder for cached terrain tiles.
%   The MATLAB_ITM_TERRAIN_DIR environment variable if set, otherwise
%   <cache>/terrain (see itm_cache_dir).

d = getenv('MATLAB_ITM_TERRAIN_DIR');
if isempty(d)
    d = fullfile(itm_cache_dir(), 'terrain');
end
end
