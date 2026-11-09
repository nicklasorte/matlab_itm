function d = itm_windows_cache_dir()
%ITM_WINDOWS_CACHE_DIR Default cache root on Windows: C:\propagation_cache\matlab_itm.
%   matlab_itm, itu_p2001, and matlab_itu_p452 share one Windows folder,
%   C:\propagation_cache, each in its own subfolder. One place to change
%   the name; see itm_cache_dir.
d = fullfile('C:\propagation_cache', 'matlab_itm');
end
