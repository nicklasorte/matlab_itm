function maps = itm_maps(maps_folder)
%ITM_MAPS Load the ITU-R climate and refractivity maps, downloading them on first use.
%   maps = ITM_MAPS() returns a struct with fields TropoClim (360 x 720,
%   ITU-R P.617-3 radio-climatic zones) and N050 (121 x 241, ITU-R P.452
%   sea-level surface refractivity).
%   maps = ITM_MAPS(maps_folder) reads itm_maps.mat, or the ITU text files
%   TropoClim.txt and N050.TXT, from maps_folder instead.
%
%   ITU forbids reproducing or redistributing its digital maps without
%   written permission: keep this repository, and apps built from it,
%   inside your organization. Search order:
%     1. Maps already loaded in this MATLAB session.
%     2. itm_maps.mat, or the two ITU .txt files, in maps_folder (if given)
%        or in the folder named by MATLAB_ITM_MAPS_DIR.
%     3. data/itm_maps.mat (or data/TropoClim.txt and data/N050.TXT) in
%        this repository.
%     4. The same files bundled with a compiled app (build_itm_app_rev1).
%     5. itm_maps.mat in the cache folder (<cache>/itu_maps).
%     6. The ITU ZIP files, downloaded with websave, unzipped, parsed, and
%        cached as itm_maps.mat with an atomic write.
%   Set MATLAB_ITM_OFFLINE=1 to forbid step 6.
%
%   Sources (free downloads from the ITU):
%     https://www.itu.int/rec/R-REC-P.617   (P.617-3 supplement, TropoClim.txt)
%     https://www.itu.int/rec/R-REC-P.452   (P.452-16 supplement, N050.TXT)
%
%   Adapted from p2001_maps_rev1 in nicklasorte/itu_p2001.

arguments
    maps_folder (1,1) string = ""
end

persistent cached cached_key
if strlength(maps_folder) == 0
    maps_folder = string(getenv('MATLAB_ITM_MAPS_DIR'));
end
if ~isempty(cached) && isequal(cached_key, maps_folder)
    maps = cached;
    return
end

mat_name = "itm_maps.mat";
raw = [];

% 2. explicit folder
if strlength(maps_folder) > 0
    if isfile(fullfile(maps_folder, mat_name))
        raw = load(fullfile(maps_folder, mat_name));
    elseif all(isfile(fullfile(maps_folder, ["TropoClim.txt", "N050.TXT"])))
        raw = parse_txt(maps_folder);
    else
        error('itm:maps:NotInFolder', ...
            'Neither %s nor TropoClim.txt and N050.TXT are in %s.', mat_name, maps_folder);
    end
end

% 3. data folder of this repository: itm_maps.mat loads in a few ms;
% parsing the text files takes about 0.4 s
repo_data = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data');
if isempty(raw)
    raw = load_folder(repo_data, mat_name);
end

% 4. bundled with a compiled app (data folder may be relocated in the CTF)
if isempty(raw) && isdeployed
    hits = [dir(fullfile(ctfroot, '**', char(mat_name))); dir(fullfile(ctfroot, '**', 'N050.TXT'))];
    if ~isempty(hits)
        raw = load_folder(hits(1).folder, mat_name);
    end
end

% 5.-6. cache, else download
if isempty(raw)
    folder = fullfile(itm_cache_dir(), 'itu_maps');
    cache_mat = fullfile(folder, mat_name);
    if isfile(cache_mat)
        raw = load(cache_mat);
    else
        if ~all(isfile(fullfile(folder, ["TropoClim.txt", "N050.TXT"])))
            download_maps(folder);
        end
        raw = parse_txt(folder);
        itm_atomic_save(cache_mat, raw);
    end
end

check_size(raw, 'TropoClim', [360 720]);
check_size(raw, 'N050', [121 241]);
maps = struct('TropoClim', raw.TropoClim, 'N050', raw.N050);
cached = maps;
cached_key = maps_folder;
end

function raw = load_folder(folder, mat_name)
% itm_maps.mat if present, else the ITU text files, else []
raw = [];
if isfile(fullfile(folder, mat_name))
    raw = load(fullfile(folder, mat_name));
elseif all(isfile(fullfile(folder, ["TropoClim.txt", "N050.TXT"])))
    raw = parse_txt(folder);
end
end

function raw = parse_txt(folder)
raw = struct();
raw.TropoClim = readmatrix(fullfile(folder, 'TropoClim.txt'), 'FileType', 'text');
raw.N050 = readmatrix(fullfile(folder, 'N050.TXT'), 'FileType', 'text');
raw.source = "ITU-R P.617-3 TropoClim.txt; ITU-R P.452-16 N050.TXT";
end

function check_size(raw, name, sz)
if ~isfield(raw, name) || ~isequal(size(raw.(name)), sz)
    error('itm:maps:Corrupt', 'Map %s is missing or not %d x %d.', name, sz);
end
end

function download_maps(folder)
if getenv('MATLAB_ITM_OFFLINE') == "1"
    error('itm:maps:NotCached', ...
        ['The ITU maps are not cached in %s and MATLAB_ITM_OFFLINE is 1. Run itm_setup_rev1 ' ...
        'on a connected machine and copy the cache, or set MATLAB_ITM_MAPS_DIR.'], folder);
end
if ~isfolder(folder)
    mkdir(folder);
end
% file in ZIP, ZIP URLs to try in order
items = { ...
    'TropoClim.txt', {'https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.617-3-201309-S!!ZIP-E.zip'}; ...
    'N050.TXT', {'https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.452-16-201507-S!!ZIP-E.zip', ...
                 'https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.452-18-202310-I!!ZIP-E.zip'}};
for k = 1:size(items, 1)
    target = fullfile(folder, items{k, 1});
    if isfile(target)
        continue
    end
    urls = items{k, 2};
    ok = false;
    for u = 1:numel(urls)
        zip_file = [tempname(folder) '.zip'];
        try
            websave(zip_file, urls{u}, weboptions('Timeout', 120));
            files = unzip(zip_file, tempname(folder));
            hit = files(endsWith(files, filesep + string(items{k, 1}), 'IgnoreCase', true));
            if ~isempty(hit)
                movefile(hit{1}, target);   % private cache; the .mat write is atomic
                ok = true;
            end
        catch
            % try the next URL
        end
        if isfile(zip_file)
            delete(zip_file);
        end
        if ok
            break
        end
    end
    if ~ok
        error('itm:maps:DownloadFailed', ...
            ['Cannot download %s from the ITU. Download the Recommendation supplement ZIP ' ...
            'yourself, extract %s into a folder, and set MATLAB_ITM_MAPS_DIR to it. Tried: %s'], ...
            items{k, 1}, items{k, 1}, strjoin(urls, ', '));
    end
end
end
