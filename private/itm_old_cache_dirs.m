function d = itm_old_cache_dirs()
%ITM_OLD_CACHE_DIRS Earlier Windows cache roots, searched for tiles read in place.
%   C:\matlab_itm and %LOCALAPPDATA%\matlab_itm, the defaults before
%   C:\propagation_cache\matlab_itm. Empty cell off Windows.
d = {};
if ispc
    d = {'C:\matlab_itm'};
    if ~isempty(itm_legacy_cache_dir())
        d{end + 1} = itm_legacy_cache_dir();
    end
end
end
