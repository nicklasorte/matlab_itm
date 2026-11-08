function itm_root = wp_setup(p2001_dir, p452_dir)
%WP_SETUP Put ITM, P.2001, and P.452 on the path for the working-paper scripts.
%   itm_root = WP_SETUP(p2001_dir, p452_dir) adds the matlab_itm root and
%   the itu_p2001 and matlab_itu_p452 folders. An empty folder name means
%   "already on the path, or next to the matlab_itm folder".
here = fileparts(fileparts(mfilename('fullpath')));      % docs/model_comparison
itm_root = fileparts(fileparts(here));
addpath(itm_root);
add_one(p2001_dir, itm_root, "itu_p2001", "p2001_rev1");
add_one(p452_dir, itm_root, "matlab_itu_p452", "p452_p2p_rev1");
warning('off', 'itm:validity:Caution');
warning('off', 'p2001:profile:spacing');
end

function add_one(d, itm_root, folder, fn)
if strlength(d) == 0
    d = fullfile(fileparts(itm_root), folder);
end
if isfolder(d)
    addpath(char(d));
end
if ~exist(fn, 'file')
    error('wp:path', '%s not found. Pass the %s folder.', fn, folder);
end
end
