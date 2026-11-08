function timedist_rev1(options)
%TIMEDIST_REV1 Troposcatter by climate, and time distributions against measurements.
%   TIMEDIST_REV1() runs plan items 14, 17, and 29 of the working paper
%   (ALGORITHM_COMPARISON_PLAN.md).
%
%   Item 14, troposcatter by climate. Smooth earth 500 m above sea level in
%   central Kansas (38.5 N, 100.0 W, due east), 70 km to 700 km in 10 km
%   steps, 30 m and 10 m antennas, horizontal polarization, at
%   options.Freq (3000 MHz) and 1, 10, 50, 90, and 99 % of time.
%     ITM: total loss for each of its 7 radio climates, with N_0 = 301 for
%     all of them so that only the climate's variability curves change,
%     and ITM's mode at the median.
%     P.2001: troposcatter basic transmission loss L_bs (Attachment E, eqs.
%     E.16 and E.17) for each of the climate zones 1 to 6 and the sea-path
%     zone of Table E.1. The released function reads the zone from the
%     TropoClim map at the common volume. To force a zone without changing
%     the released code, the script copies p2001_profile_rev1 with its
%     private folder into a temporary folder and inserts one line in the
%     copy of tl_troposcatter that replaces the zone when the environment
%     variable WP_CLIMZONE_OVERRIDE is set. P.2001's combined loss with the
%     zone from the map is kept for context.
%     chart_data/td_tropo_climate.csv
%
%   Items 17 and 29, time distributions against measurements. Post-processes
%   figures/table_dbsg3_by_dataset_survey.csv (compare_dbsg3_rev1, surveyed
%   profiles): for each dataset kept by the quality screen that has measured
%   and predicted loss at all of 1, 10, 50, 90, and 99 % of time, the shape
%   of each distribution relative to its own median, S(p) = L(p) - L(50),
%   for the measurement, ITM, P.2001, and P.452 (1 % and 10 % only). The
%   shape error S_model(p) - S_meas(p) removes each model's median bias, so
%   it tests only the time-variability equations.
%     chart_data/td_measured_shape.csv    one row per dataset and percentage
%     chart_data/td_measured_summary.csv  medians by group and percentage
%     chart_data/td_measured_examples.csv six datasets from 1.7 GHz to
%                                         4.5 GHz spread over path length
%
%   Options: Freq (3000), OutDir, P2001Dir, P452Dir, Items ([14 29]).

arguments
    options.Freq (1,1) double = 3000
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Items (1,:) double = [14 29]
end
here = fileparts(mfilename('fullpath'));
wp_setup(options.P2001Dir, options.P452Dir);
P = [1 10 50 90 99];

% ---- item 14: troposcatter by climate ----
if ismember(14, options.Items)
    f = options.Freq; ghz = f / 1000; h0 = 500; htx = 30; hrx = 10;
    E = wgs84Ellipsoid('km'); tx0 = [38.5, -100.0];
    czdir = make_zone_copy(which('p2001_profile_rev1'));
    addpath(czdir);
    cleanup = onCleanup(@() cleanup_zone(czdir)); %#ok<NASGU>
    rows = {};
    for d = 70:10:700
        [pfl, dk, hm, rxp] = flat(d, h0, tx0, E);
        o0 = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), ghz, P(:), tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, ...
            'Polarization', "horizontal", 'Validity', "off");
        fs = o0(1).Lbfs;
        for j = 1:numel(P)
            rows(end + 1, :) = {"P.2001 combined", o0(1).Ztropo, d, P(j), o0(j).Lb, fs, NaN}; %#ok<AGROW>
        end
        for c = 1:7
            [Li, info] = itm_p2p_rev1(htx, hrx, pfl, f, P, climate=c, N_0=301, polarization=0, validity="off");
            for j = 1:numel(P)
                rows(end + 1, :) = {"ITM", c, d, P(j), Li(j), fs, info.mode}; %#ok<AGROW>
            end
        end
        for z = 0:6
            setenv('WP_CLIMZONE_OVERRIDE', sprintf('%d', z));
            o = p2001_profile_cz_rev1(dk, hm, 4 * ones(size(dk)), ghz, P(:), tx0(1), tx0(2), rxp(1), rxp(2), ...
                htx, hrx, 'Polarization', "horizontal", 'Validity', "off");
            assert(all([o.Ztropo] == z), 'wp:td:zone', 'Zone override did not take effect.');
            for j = 1:numel(P)
                rows(end + 1, :) = {"P.2001 troposcatter", z, d, P(j), o(j).Lbs, fs, NaN}; %#ok<AGROW>
            end
        end
        setenv('WP_CLIMZONE_OVERRIDE', '');
    end
    writetable(cell2table(rows, 'VariableNames', {'model', 'climate', 'd_km', 'time_pct', 'loss_db', 'fs_db', ...
        'itm_mode'}), fullfile(options.OutDir, 'td_tropo_climate.csv'));
end

% ---- items 17 and 29: measured time distributions ----
if ismember(29, options.Items)
    T = readtable(fullfile(here, 'figures', 'table_dbsg3_by_dataset_survey.csv'), 'TextType', 'string');
    tag = ["01" "10" "50" "90" "99"];
    M = T{:, "meas_" + tag}; I = T{:, "itm_" + tag}; Q = T{:, "p2001_" + tag}; F = T{:, "p452_" + tag};
    use = T.kept == 1 & all(isfinite([M I Q]), 2);
    T = T(use, :); M = M(use, :); I = I(use, :); Q = Q(use, :); F = F(use, :);
    sM = M - M(:, 3); sI = I - I(:, 3); sQ = Q - Q(:, 3); sF = F - F(:, 3);
    ghzband = T.freq_mhz >= 1000;
    mode = repmat("other", height(T), 1);
    mode(T.itm_mode_code == 10) = "scatter"; mode(ismember(T.itm_mode_code, [5 9])) = "diffraction";
    mode(T.itm_mode_code == 0) = "line of sight";
    rows = {};
    for k = 1:height(T)
        for j = 1:numel(P)
            rows(end + 1, :) = {T.id(k), T.freq_mhz(k), T.d_km(k), T.bin(k), mode(k), P(j), M(k, j), I(k, j), ...
                Q(k, j), F(k, j), sM(k, j), sI(k, j), sQ(k, j), sF(k, j)}; %#ok<AGROW>
        end
    end
    S = cell2table(rows, 'VariableNames', {'id', 'freq_mhz', 'd_km', 'bin', 'itm_mode', 'time_pct', 'meas_db', ...
        'itm_db', 'p2001_db', 'p452_db', 'meas_shape_db', 'itm_shape_db', 'p2001_shape_db', 'p452_shape_db'});
    writetable(S, fullfile(options.OutDir, 'td_measured_shape.csv'));

    groups = {"All", true(height(T), 1); "1 GHz and above", ghzband; "Below 1 GHz", ~ghzband; ...
        "Scatter", mode == "scatter"; "Diffraction", mode == "diffraction"; "Line of sight", mode == "line of sight"};
    rs = {};
    for g = 1:size(groups, 1)
        m = groups{g, 2};
        for j = 1:numel(P)
            eI = sI(m, j) - sM(m, j); eQ = sQ(m, j) - sM(m, j); eF = sF(m, j) - sM(m, j); eF = eF(isfinite(eF));
            rs(end + 1, :) = {groups{g, 1}, P(j), nnz(m), median(sM(m, j)), median(sI(m, j)), median(sQ(m, j)), ...
                median(eI), median(eQ), median(abs(eI)), median(abs(eQ)), numel(eF), med(eF), med(abs(eF)), ...
                mean(abs(eQ) < abs(eI))}; %#ok<AGROW>
        end
        % spread from 1 % to 99 % of time
        wM = M(m, 5) - M(m, 1); wI = I(m, 5) - I(m, 1); wQ = Q(m, 5) - Q(m, 1);
        rs(end + 1, :) = {groups{g, 1}, NaN, nnz(m), median(wM), median(wI), median(wQ), median(wI - wM), ...
            median(wQ - wM), median(abs(wI - wM)), median(abs(wQ - wM)), 0, NaN, NaN, ...
            mean(abs(wQ - wM) < abs(wI - wM))}; %#ok<AGROW>
    end
    writetable(cell2table(rs, 'VariableNames', {'group', 'time_pct', 'n', 'meas_shape_db', 'itm_shape_db', ...
        'p2001_shape_db', 'itm_shape_err_db', 'p2001_shape_err_db', 'itm_abs_err_db', 'p2001_abs_err_db', ...
        'p452_n', 'p452_shape_err_db', 'p452_abs_err_db', 'frac_p2001_closer'}), ...
        fullfile(options.OutDir, 'td_measured_summary.csv'));
    % NaN time_pct rows are the 1 % to 99 % spread.

    % six examples, 1.7 GHz to 4.5 GHz, spread over path length (one per distinct path)
    c = find(T.freq_mhz >= 1700 & T.freq_mhz <= 4500);
    [~, iu] = unique(T.path(c), 'stable'); c = c(iu);
    [~, o] = sort(T.d_km(c)); c = c(o);
    pick = c(unique(round(linspace(1, numel(c), 6))));
    X = S(ismember(S.id, T.id(pick)), :);
    writetable(X, fullfile(options.OutDir, 'td_measured_examples.csv'));
end
end

%% ------------------------------------------------------------------------
function y = med(x)
if isempty(x), y = NaN; else, y = median(x); end
end

function [pfl, dk, hm, rxp] = flat(d, h0, tx, E)
n = max(10, round(d / 0.1));
dk = linspace(0, d, n + 1)'; hm = h0 * ones(n + 1, 1);
pfl = [n; 1000 * d / n; hm];
[la, lo] = reckon(tx(1), tx(2), d, 90, E);
rxp = [la, lo];
end

function d = make_zone_copy(p2001_file)
% Temporary copy of P.2001 with a climate-zone override; see the help.
d = fullfile(tempdir, 'wp_climzone');
if isfolder(d), rmdir(d, 's'); end
mkdir(d);
src = fileparts(p2001_file);
copyfile(fullfile(src, 'private'), fullfile(d, 'private'));
txt = fileread(p2001_file);
key = 'function out = p2001_profile_rev1(';
assert(contains(txt, key), 'wp:td:p2001', 'P.2001 entry changed; update the copy.');
write(fullfile(d, 'p2001_profile_cz_rev1.m'), strrep(txt, key, 'function out = p2001_profile_cz_rev1('));
tl = fullfile(d, 'private', 'tl_troposcatter.m');
txt = fileread(tl);
key = 'clear TropoClim';
assert(contains(txt, key), 'wp:td:tropo', 'tl_troposcatter changed; update the override insertion point.');
txt = strrep(txt, key, [key newline 'ov_ = str2double(getenv(''WP_CLIMZONE_OVERRIDE'')); if isfinite(ov_), climzone = ov_; end']);
write(tl, txt);
end

function cleanup_zone(d)
setenv('WP_CLIMZONE_OVERRIDE', '');
rmpath(d);
end

function write(file, txt)
fid = fopen(file, 'w'); fwrite(fid, txt); fclose(fid);
end
