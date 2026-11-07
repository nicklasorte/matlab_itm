function d = itm_default_terrain_dir()
%ITM_DEFAULT_TERRAIN_DIR Writable folder for cached terrain tiles.
%   Order: the MATLAB_ITM_TERRAIN_DIR environment variable, then
%   %LOCALAPPDATA%\matlab_itm\terrain on Windows, then
%   $HOME/.matlab_itm/terrain. A user-level folder (not the app folder)
%   keeps the cache writable when the code runs from a compiled app.

d = getenv('MATLAB_ITM_TERRAIN_DIR');
if ~isempty(d)
    return
end
if ispc && ~isempty(getenv('LOCALAPPDATA'))
    d = fullfile(getenv('LOCALAPPDATA'), 'matlab_itm', 'terrain');
elseif ~isempty(getenv('HOME'))
    d = fullfile(getenv('HOME'), '.matlab_itm', 'terrain');
else
    d = fullfile(tempdir, 'matlab_itm', 'terrain');
end
end
