function d = itm_legacy_cache_dir()
%ITM_LEGACY_CACHE_DIR Fallback cache root on Windows, %LOCALAPPDATA%\matlab_itm.
%   Used when C:\propagation_cache\matlab_itm isn't writable. Empty off
%   Windows or when LOCALAPPDATA isn't set. See itm_old_cache_dirs for the
%   folders searched for tiles downloaded under earlier defaults.
d = '';
if ispc && ~isempty(getenv('LOCALAPPDATA'))
    d = fullfile(getenv('LOCALAPPDATA'), 'matlab_itm');
end
end
