function d = itm_cache_dir()
%ITM_CACHE_DIR Root folder for cached ITU maps and terrain tiles.
%   Order: the MATLAB_ITM_CACHE environment variable, then
%   %LOCALAPPDATA%\matlab_itm on Windows, then ~/.matlab_itm. A user-level
%   folder keeps the cache writable from a compiled app and survives
%   MATLAB and Runtime upgrades (prefdir is release-specific and tempdir is
%   purged by the OS).

d = getenv('MATLAB_ITM_CACHE');
if ~isempty(d)
    return
end
if ispc && ~isempty(getenv('LOCALAPPDATA'))
    d = fullfile(getenv('LOCALAPPDATA'), 'matlab_itm');
elseif ~isempty(getenv('HOME'))
    d = fullfile(getenv('HOME'), '.matlab_itm');
else
    error('itm:cache:NoHome', 'Cannot find a home folder for the cache. Set MATLAB_ITM_CACHE.');
end
end
