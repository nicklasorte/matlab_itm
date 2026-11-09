function d = itm_legacy_cache_dir()
%ITM_LEGACY_CACHE_DIR Earlier Windows cache root, %LOCALAPPDATA%\matlab_itm.
%   Used as the fallback when C:\matlab_itm isn't writable, and searched for
%   tiles downloaded before the default moved. Empty off Windows or when
%   LOCALAPPDATA isn't set.
d = '';
if ispc && ~isempty(getenv('LOCALAPPDATA'))
    d = fullfile(getenv('LOCALAPPDATA'), 'matlab_itm');
end
end
