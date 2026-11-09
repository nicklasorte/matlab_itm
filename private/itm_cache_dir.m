function d = itm_cache_dir()
%ITM_CACHE_DIR Root folder for cached ITU maps and terrain tiles.
%   Order:
%     1. The MATLAB_ITM_CACHE environment variable.
%     2. Windows: C:\matlab_itm, created on first use. If it can't be
%        created or written (a locked-down PC), %LOCALAPPDATA%\matlab_itm,
%        with a one-time warning.
%     3. Other platforms: ~/.matlab_itm.
%   A fixed folder outside MATLAB keeps the cache writable from a compiled
%   app and survives MATLAB and Runtime upgrades (prefdir is
%   release-specific and tempdir is purged by the OS). Tiles already in the
%   earlier Windows default, %LOCALAPPDATA%\matlab_itm, are still read in
%   place (see itm_get_tile), so they aren't downloaded again.

persistent resolved
d = getenv('MATLAB_ITM_CACHE');
if ~isempty(d)
    return
end
if ispc
    if ~isempty(resolved)
        d = resolved;
        return
    end
    d = itm_windows_cache_dir();
    if ~writable(d)
        fallback = itm_legacy_cache_dir();
        if isempty(fallback)
            error('itm:cache:NotWritable', ...
                'Cannot create or write %s, and LOCALAPPDATA is not set. Set MATLAB_ITM_CACHE.', d);
        end
        warning('itm:cache:Fallback', ...
            'Cannot create or write %s; caching in %s instead. Set MATLAB_ITM_CACHE to choose a folder.', ...
            d, fallback);
        d = fallback;
    end
    resolved = d;
elseif ~isempty(getenv('HOME'))
    d = fullfile(getenv('HOME'), '.matlab_itm');
else
    error('itm:cache:NoHome', 'Cannot find a home folder for the cache. Set MATLAB_ITM_CACHE.');
end
end

function ok = writable(d)
% True when folder d exists (creating it if needed) and a file can be written in it.
ok = false;
if ~isfolder(d)
    [made, ~] = mkdir(d);
    if ~made, return, end
end
probe = fullfile(d, sprintf('.write_test_%d', feature('getpid')));
fid = fopen(probe, 'w');
if fid < 0, return, end
fclose(fid);
delete(probe);
ok = true;
end
