function T = demo_wrapper_small_set_rev1(options)
%DEMO_WRAPPER_SMALL_SET_REV1 ITM through the matlab_itu_p452 wrapper on 250 links.
%   T = DEMO_WRAPPER_SMALL_SET_REV1() times a typical ITM study on 250
%   transmitters (a 0.04-degree grid, 2.8 to 42 km) around one receiver in
%   Washington, DC, at 3 reliabilities, two ways:
%     old  itm_pathloss_rev1 (this repository), one call per case
%     new  pathloss_rev1(..., model="itm") from nicklasorte/matlab_itu_p452,
%          which reads each link's terrain profile once, keeps it in memory
%          for the session, and runs ITM (itm_p2p_rev1) on it, with the
%          same climate and N_0 lookups as itm_pathloss_rev1
%   and checks that every loss matches. Steps:
%     first_run      one run, terrain read
%     new_heights    TX heights 30 -> 45 m (profiles cached)
%     four_freqs     700, 2700, 3500, 7000 MHz (frequency vector)
%     confidence_90  confidence 90 % instead of 50 % (profiles cached)
%     study_cold     2 heights x 4 frequencies at confidence 50 and 90,
%                    starting with no cached profiles
%   Each timing is the best of 2 runs after a warm-up that loads the tiles
%   and maps, so both ways start from the same state.
%
%   Name-value options:
%     P452Dir  folder with matlab_itu_p452 (""; if empty, it must be on the
%              path, or in a matlab_itu_p452 folder next to this repository)
%
%   The wrapper runs against this repository's ITM: MATLAB_P452_ITM_DIR is
%   set to this folder for the call and restored after.
%
%   Run: addpath tests; T = demo_wrapper_small_set_rev1()
%
%   See also itm_pathloss_rev1, compare_models_rev1.

arguments
    options.P452Dir (1,1) string = ""
end
itm_root = fileparts(fileparts(mfilename('fullpath')));
addpath(itm_root);
p452_dir = options.P452Dir;
if strlength(p452_dir) == 0
    p452_dir = fullfile(fileparts(itm_root), "matlab_itu_p452");
end
if ~exist('pathloss_rev1', 'file')
    if ~isfile(fullfile(p452_dir, "pathloss_rev1.m"))
        error('itm:demo:NoP452', ...
            'matlab_itu_p452 with pathloss_rev1 not found in %s (set P452Dir).', p452_dir);
    end
    addpath(char(p452_dir));
end
old_env = getenv('MATLAB_P452_ITM_DIR');
restore = onCleanup(@() setenv('MATLAB_P452_ITM_DIR', old_env));
setenv('MATLAB_P452_ITM_DIR', itm_root);
p452_addpath_rev1();

rx = [38.8895, -77.0353, 10];
g = -0.3:0.04:0.3;
[dla, dlo] = meshgrid(g, g);
tx = [rx(1) + dla(:), rx(2) + dlo(:), repmat(30, numel(dla), 1)];
d_km = distance(rx(1), rx(2), tx(:, 1), tx(:, 2), wgs84Ellipsoid('km'));
tx = tx(d_km > 1, :);
tx = tx(1:250, :);
rel = [1; 10; 50];
f4 = [700 2700 3500 7000];
tx45 = tx;
tx45(:, 3) = 45;

itm_pathloss_rev1(tx, rx, 2700, rel);             % warm-up: tiles and maps

steps = ["first_run"; "new_heights"; "four_freqs"; "confidence_90"; "study_cold"];
n = numel(steps);
[t_old, t_new, max_diff] = deal(zeros(n, 1));

[t_old(1), L_old] = best(@() itm_pathloss_rev1(tx, rx, 2700, rel));
[t_new(1), L_new] = best(@() pathloss_rev1(tx, rx, 2700, rel, model="itm", cache=false));
max_diff(1) = max(abs(L_new - L_old), [], 'all');

pathloss_rev1(tx, rx, 2700, rel, model="itm");    % fills the session cache
[t_old(2), L_old] = best(@() itm_pathloss_rev1(tx45, rx, 2700, rel));
[t_new(2), L_new] = best(@() pathloss_rev1(tx45, rx, 2700, rel, model="itm"));
max_diff(2) = max(abs(L_new - L_old), [], 'all');

[t_old(3), L_old] = best(@() per_frequency(tx, rx, f4, rel, 50));
[t_new(3), L_new] = best(@() pathloss_rev1(tx, rx, f4, rel, model="itm"));
max_diff(3) = max(abs(L_new - L_old), [], 'all');

[t_old(4), L_old] = best(@() itm_pathloss_rev1(tx, rx, 2700, rel, confidence=90));
[t_new(4), L_new] = best(@() pathloss_rev1(tx, rx, 2700, rel, model="itm", ...
    model_options={'confidence', 90}));
max_diff(4) = max(abs(L_new - L_old), [], 'all');

% Positions nudged 1 mm per run so the profile cache starts empty; the
% tiles stay in memory, as they do for the old way
nudge = 0;
t_old(5) = best(@() study_old(tx, tx45, rx, f4, rel));
t_new(5) = best(@study_new);
max_diff(5) = NaN;                                % covered by the steps above

T = table(steps, t_old, t_new, t_old ./ t_new, max_diff, ...
    'VariableNames', ["step", "old_s", "new_s", "speedup", "max_diff_db"]);

    function study_new()
        nudge = nudge + 1;
        txn = tx;
        txn(:, 1) = txn(:, 1) + nudge * 1e-8;
        txn45 = txn;
        txn45(:, 3) = 45;
        for c = [50 90]
            pathloss_rev1(txn, rx, f4, rel, model="itm", model_options={'confidence', c});
            pathloss_rev1(txn45, rx, f4, rel, model="itm", model_options={'confidence', c});
        end
    end
end

function L = per_frequency(tx, rx, f, rel, conf)
L = zeros(size(tx, 1), numel(rel), numel(f));
for i = 1:numel(f)
    L(:, :, i) = itm_pathloss_rev1(tx, rx, f(i), rel, confidence=conf);
end
end

function study_old(tx, tx45, rx, f, rel)
for c = [50 90]
    per_frequency(tx, rx, f, rel, c);
    per_frequency(tx45, rx, f, rel, c);
end
end

function [t, out] = best(fn)
t = Inf;
out = [];
for r = 1:2
    t0 = tic;
    if nargout > 1
        out = fn();
    else
        fn();
    end
    t = min(t, toc(t0));
end
end
