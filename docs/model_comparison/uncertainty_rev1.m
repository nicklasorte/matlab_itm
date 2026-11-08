function U = uncertainty_rev1(options)
%UNCERTAINTY_REV1 Bootstrap confidence intervals for the paper's headline numbers.
%   U = UNCERTAINTY_REV1() reads the 3 GHz results (chart_data/ and
%   figures/table_*.csv) and writes, with 10,000 bootstrap resamples and a
%   fixed seed:
%     chart_data/uncertainty_summary.csv
%       the median ITM minus P.2001 gap by ITM mechanism class and in the
%       two groups split at ITM's smooth-earth weight w = 0.12, each with a
%       95 % interval (resampling links), and the share of links more than
%       20 dB apart with its interval
%     chart_data/uncertainty_split.csv
%       the w that best separates the diffraction-link gaps, with its
%       interval, and two bimodality checks on those gaps: Sarle's
%       bimodality coefficient (above 5/9 suggests two groups) and the BIC
%       of one- against two-component Gaussian mixtures
%     chart_data/uncertainty_measurements.csv
%       each model's mean error against the databank measurements at 50 %
%       by group, with a 95 % interval from resampling measured paths
%       (datasets on one path share its errors)
%
%   Options: B (10000), Seed (20261108), Dir (figures), DataDir (chart_data).

arguments
    options.B (1,1) double {mustBeInteger, mustBePositive} = 10000
    options.Seed (1,1) double = 20261108
    options.Dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.DataDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
end
rng(options.Seed, 'twister');
B = options.B; cd_ = options.DataDir;
bl = readtable(fullfile(cd_, 'real_terrain_by_link.csv'), 'TextType', 'string');
gap = bl.itm_50_db - bl.p2001_50_db;
T = readtable(fullfile(options.Dir, 'table_diffraction_terms.csv'), 'TextType', 'string');
f0 = bl.freq_mhz(1);
T = T(T.freq_mhz == f0, :);
w = T.w_d3; g = T.itm_excess_50 - T.p2001_excess_50;

rows = {};
for c = ["Line of sight", "Diffraction", "Troposcatter"]
    v = gap(bl.itm_class == c);
    [m, lo, hi] = bmed(v, B);
    sh = mean(v(randi(numel(v), numel(v), B)) > 20, 1);
    rows(end + 1, :) = {c + " links", numel(v), m, lo, hi, mean(v > 20), prctile(sh, 2.5), prctile(sh, 97.5)}; %#ok<AGROW>
end
for s = [true false]
    sel = (w < 0.12) == s;
    [m, lo, hi] = bmed(g(sel), B);
    lab = "w 0.12 or more"; if s, lab = "w under 0.12"; end
    rows(end + 1, :) = {lab, nnz(sel), m, lo, hi, NaN, NaN, NaN}; %#ok<AGROW>
end
U = cell2table(rows, 'VariableNames', {'quantity', 'n', 'median_db', 'ci_low_db', 'ci_high_db', 'share_over_20db', 'share_low', 'share_high'});
writetable(U, fullfile(cd_, 'uncertainty_summary.csv'));

% ---- the split point and bimodality ----
sp = best_split(w, g);
bs = NaN(2000, 1);
for k = 1:2000
    i = randi(numel(w), numel(w), 1);
    bs(k) = best_split(w(i), g(i));
end
n = numel(g);
bc = (skewness(g, 0) ^ 2 + 1) / (kurtosis(g, 0) - 3 + 3 * (n - 1) ^ 2 / ((n - 2) * (n - 3)));
opts = statset('MaxIter', 500);
g1 = fitgmdist(g, 1, 'Options', opts);
g2 = fitgmdist(g, 2, 'Options', opts, 'Replicates', 20);
mu = sort(g2.mu);
S = table(sp, prctile(bs, 2.5), prctile(bs, 97.5), bc, g1.BIC, g2.BIC, mu(1), mu(2), n, ...
    'VariableNames', {'split_w', 'split_low', 'split_high', 'bimodality_coefficient', 'bic_one', 'bic_two', 'mixture_mean_low_db', ...
    'mixture_mean_high_db', 'links'});
writetable(S, fullfile(cd_, 'uncertainty_split.csv'));

% ---- measurements, resampling paths ----
D = readtable(fullfile(options.Dir, 'table_dbsg3_by_dataset_survey.csv'), 'TextType', 'string');
D = D(D.kept == 1, :);
groups = {"All", true(height(D), 1); "30 MHz-1 GHz", D.freq_mhz < 1000; "1-10 GHz", D.freq_mhz >= 1000};
rows = {};
for gi = 1:size(groups, 1)
    q = D(groups{gi, 2}, :);
    for m = ["itm", "p452", "p2001"]
        e = q.(m + "_50") - q.meas_50;
        ok = isfinite(e);
        if nnz(ok) < 5, continue, end
        [~, ~, id] = unique(q.path(ok));
        su = accumarray(id, e(ok)); sz = accumarray(id, 1); np = numel(su);
        bm = NaN(B, 1);
        for k = 1:B
            i = randi(np, np, 1);
            bm(k) = sum(su(i)) / sum(sz(i));
        end
        rows(end + 1, :) = {groups{gi, 1}, m, nnz(ok), np, mean(e(ok)), prctile(bm, 2.5), prctile(bm, 97.5)}; %#ok<AGROW>
    end
end
M = cell2table(rows, 'VariableNames', {'group', 'model', 'datasets', 'paths', 'mean_error_db', 'ci_low_db', 'ci_high_db'});
writetable(M, fullfile(cd_, 'uncertainty_measurements.csv'));
disp(U); disp(S); disp(M);
end

function [m, lo, hi] = bmed(v, B)
m = median(v);
bm = median(v(randi(numel(v), numel(v), B)), 1);
lo = prctile(bm, 2.5); hi = prctile(bm, 97.5);
end

function best = best_split(w, g)
% The w that maximizes the difference in median gap between the groups, weighted by balance
best = NaN; val = -Inf;
for t = linspace(0.04, 0.4, 73)
    lo = g(w < t); hi = g(w >= t);
    if numel(lo) < 3 || numel(hi) < 3, continue, end
    s = (median(lo) - median(hi)) * sqrt(numel(lo) * numel(hi)) / numel(w);
    if s > val, best = t; val = s; end
end
end
