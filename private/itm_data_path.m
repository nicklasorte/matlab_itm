function p = itm_data_path(name)
%ITM_DATA_PATH Full path to a bundled data file in the repo's data folder.
%   Works from the source tree and from a MATLAB Compiler app, where the
%   data folder is packaged with the code (see build_itm_app_rev1).

here = fileparts(fileparts(mfilename('fullpath')));    % repo root (private/..)
p = fullfile(here, 'data', name);
if isfile(p)
    return
end
if isdeployed
    hits = dir(fullfile(ctfroot, '**', name));
    if ~isempty(hits)
        p = fullfile(hits(1).folder, hits(1).name);
        return
    end
end
error('itm:DataFileMissing', ...
    'Data file %s not found. Expected it at %s. Compiled apps must package the data folder.', name, p);
end
