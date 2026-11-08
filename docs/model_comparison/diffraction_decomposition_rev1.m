function D = diffraction_decomposition_rev1(options)
%DIFFRACTION_DECOMPOSITION_REV1 Why ITM's diffraction loss on rough terrain exceeds P.452 and P.2001.
%   D = DIFFRACTION_DECOMPOSITION_REV1() takes the 60 real-terrain links of
%   make_wp_figures_rev1 (wp_results_rev1.mat), rebuilds their profiles,
%   and splits each model's diffraction loss into its terms:
%
%   ITM v1.4 (private/itm_p2p_core.m, diffraction_loss and longley_rice):
%     A_k    double knife edge: F(v1) + F(v2), one edge at each horizon,
%            each seeing the full bending angle theta = d/a_e - theta_los
%     A_se   smooth-earth (Vogler three-radius) diffraction
%     w      weight 25.1/(25.1 + sqrt(q)); q grows with delta_h(d)*f
%     A_fo   clutter term, min(15, 5 log10(1 + 1e-5 h1 h2 f sigma_h))
%     A_d = w A_se + (1 - w) A_k + A_fo, evaluated at d_3 and d_4 (beyond
%     the horizons) and extended to the path as the straight line
%     A_ref = M_d d + A_d0 (diffraction region), or blended toward the
%     line-of-sight fit when d < d_sML.
%   P.452-18 (delta-Bullington, Sec. 4.2.3), which P.2001-6 shares:
%     Lbulla  Bullington on the actual profile (one equivalent edge)
%     Lbulls  Bullington on a smooth profile at the effective heights
%     Ldsph   spherical-earth loss; Ld = Lbulla + max(Ldsph - Lbulls, 0)
%
%   The script recomputes ITM's terms with the same equations and checks
%   that they reproduce ITM's A_ref to 1e-9 dB, so the split is exact.
%   It then removes one ITM ingredient at a time to see how much of the
%   gap each one explains:
%     1 single edge: A_k = F(max(v1, v2)) instead of F(v1) + F(v2)
%     2 no clutter term: A_fo = 0
%     3 evaluated at the path: A_d(d) instead of the d_3-d_4 line
%     4 all three together
%
%   Writes table_diffraction_terms.csv, table_diffraction_ablation.csv,
%   fig14_diffraction_terms.png, and fig15_diffraction_ablation.png to
%   options.OutDir.
%
%   Other links: options.Links (a table with tx_lat, tx_lon, rx_lat, rx_lon,
%   tx_h_m, rx_h_m, and region, such as western_terrain_rev1 writes) and
%   options.Freqs (MHz) run the same split on those links instead, and
%   options.Tag is added to every output file name ("_west").

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.Results (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures', 'wp_results_rev1.mat')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Links table = table()
    options.Freqs double = []
    options.Tag (1,1) string = ""
end

wp_setup(options.P2001Dir, options.P452Dir);
out = options.OutDir;
if isempty(options.Links)
    s = load(options.Results, 'R');
    L = s.R.E7.links;
    F = s.R.freqs_mhz;
else
    L = options.Links;
    F = 3000;
end
if ~isempty(options.Freqs), F = options.Freqs; end
tag = options.Tag;
n = height(L);

rows = {};
for k = 1:n
    prof = wp_terrain_profile([L.tx_lat(k) L.tx_lon(k)], [L.rx_lat(k) L.rx_lon(k)]);
    pfl = [numel(prof.d_km) - 1; prof.d_km(end) * 1e3 / (numel(prof.d_km) - 1); prof.h_m(:)];
    for f = 1:numel(F)
        r = wp_run3(prof, F(f), L.tx_h_m(k), L.rx_h_m(k), 50);
        cls = r.itm.mech;
        if ~ismember(cls, [4 5 8 9])               % diffraction links only
            continue
        end
        it = wp_itm_terms(pfl, F(f), [L.tx_h_m(k) L.rx_h_m(k)], r.itm.N_0, r.itm.info);
        pb = p452_terms(prof, r.p452.info, F(f));
        A_fs = r.itm.info.A_fs_db;
        rows(end + 1, :) = {k, L.region(k), F(f), prof.d_km(end), cls, r.itm.info.mode, ...
            r.itm.info.delta_h_m, it.d_ML / 1e3, it.d_sML / 1e3, it.d_3 / 1e3, it.theta_nlos_mrad, ...
            it.v1, it.v2, it.A_k3, it.A_se3, it.w3, it.A_fo, it.A_d3, it.A_ref, it.A_d_at_d, ...
            it.A_ref_single, it.A_ref_noclutter, it.A_all, ...
            r.itm.Lb - A_fs, pb.Lbulla, pb.Lbulls, pb.Ldsph, pb.Ld50, r.p452.Lb - pb.Lbfsg, ...
            r.p2001.Lb - A_fs, pb.nu}; %#ok<AGROW>
    end
    fprintf('link %2d of %d\n', k, n);
end
D = cell2table(rows, 'VariableNames', {'link', 'region', 'freq_mhz', 'd_km', 'itm_mode_code', 'itm_region', ...
    'delta_h_m', 'd_ML_km', 'd_sML_km', 'd_3_km', 'theta_nlos_mrad', 'v1_sq', 'v2_sq', ...
    'A_k_d3', 'A_se_d3', 'w_d3', 'A_fo', 'A_d_d3', 'A_ref', 'A_d_at_path', ...
    'A_ref_single_edge', 'A_ref_no_clutter', 'A_ref_all_three', ...
    'itm_excess_50', 'Lbulla', 'Lbulls', 'Ldsph', 'Ld50_p452', 'p452_excess_50', 'p2001_excess_50', 'bullington_nu'});
writetable(D, fullfile(out, 'table_diffraction_terms' + tag + '.csv'));

% Ablation summary: median gap (ITM excess minus P.452 Ld50) after each change
abl = {'ITM as is', D.A_ref; '1 single edge', D.A_ref_single_edge; '2 no clutter term', D.A_ref_no_clutter; ...
    '3 evaluated at the path', D.A_d_at_path; '4 all three', D.A_ref_all_three};
rows = {};
for f = 1:numel(F)
    sel = D.freq_mhz == F(f);
    for a = 1:size(abl, 1)
        g = abl{a, 2}(sel) - D.Ld50_p452(sel);
        g = g(isfinite(g));
        rows(end + 1, :) = {F(f), abl{a, 1}, numel(g), median(g), mean(g), prctile(g, 10), prctile(g, 90)}; %#ok<AGROW>
    end
end
A = cell2table(rows, 'VariableNames', {'freq_mhz', 'case', 'n_links', 'median_gap_db', 'mean_gap_db', 'p10_gap_db', 'p90_gap_db'});
writetable(A, fullfile(out, 'table_diffraction_ablation' + tag + '.csv'));

% Fig. 14: the terms, link by link (first study frequency) and by frequency
fig = figure('Visible', 'off', 'Position', [0 0 1200 420]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact');
ax = nexttile(tl); hold(ax, 'on');
mk = 'osd';
for f = 1:numel(F)
    sel = D.freq_mhz == F(f);
    scatter(ax, D.Lbulla(sel), D.A_k_d3(sel), 30, mk(f), 'filled', 'DisplayName', sprintf('%g MHz', F(f)));
end
lim = [0 max([D.A_k_d3; D.Lbulla]) + 5];
plot(ax, lim, lim, 'k:', 'HandleVisibility', 'off');
xlabel(ax, 'P.452 Bullington, actual profile (dB)'); ylabel(ax, 'ITM double knife edge A_k at d_3 (dB)');
title(ax, 'Knife-edge terms'); legend(ax, 'Location', 'northwest'); grid(ax, 'on'); axis(ax, 'square');
ax = nexttile(tl); hold(ax, 'on');
for f = 1:numel(F)
    sel = D.freq_mhz == F(f);
    scatter(ax, D.delta_h_m(sel), D.w_d3(sel), 30, mk(f), 'filled', 'DisplayName', sprintf('%g MHz', F(f)));
end
set(ax, 'XScale', 'log'); ylim(ax, [0 1]);
xlabel(ax, 'ITM terrain irregularity \Deltah (m)'); ylabel(ax, 'Smooth-earth weight w at d_3');
title(ax, 'Weight on smooth earth'); grid(ax, 'on');
ax = nexttile(tl);
M = zeros(numel(F), 4); Mp = zeros(numel(F), 2);
for f = 1:numel(F)
    sel = D.freq_mhz == F(f);
    M(f, :) = [median(D.w_d3(sel) .* D.A_se_d3(sel)), median((1 - D.w_d3(sel)) .* D.A_k_d3(sel)), ...
        median(D.A_fo(sel)), median(D.A_ref(sel) - D.A_d_d3(sel))];
    Mp(f, :) = [median(D.Lbulla(sel)), median(max(D.Ldsph(sel) - D.Lbulls(sel), 0))];
end
x = 1:numel(F);
b1 = bar(ax, x - 0.2, M, 0.35, 'stacked');
hold(ax, 'on');
b2 = bar(ax, x + 0.2, Mp, 0.35, 'stacked');
set(b1(1), 'FaceColor', [0.60 0.75 0.88]); set(b1(2), 'FaceColor', [0 0.447 0.698]);
set(b1(3), 'FaceColor', [0.35 0.35 0.35]); set(b1(4), 'FaceColor', [0.85 0.85 0.85]);
set(b2(1), 'FaceColor', [0.835 0.369 0]); set(b2(2), 'FaceColor', [0.95 0.75 0.55]);
set(ax, 'XTick', x, 'XTickLabel', compose('%g MHz', F));
ylabel(ax, 'Median term (dB)');
legend(ax, [b1 b2], {'ITM w A_{se}', 'ITM (1-w) A_k', 'ITM A_{fo}', 'ITM line fit to path', ...
    'P.452 Bullington', 'P.452 spherical excess'}, 'Location', 'northoutside', 'NumColumns', 2, 'FontSize', 7);
title(ax, 'Median terms: ITM (left), P.452 (right)'); grid(ax, 'on');
wp_save_fig(fig, out, 'fig14_diffraction_terms' + tag);

% Fig. 15: ablation
fig = figure('Visible', 'off', 'Position', [0 0 900 380]);
ax = axes(fig); hold(ax, 'on');
cases = string(abl(:, 1));
G = reshape(A.median_gap_db, numel(cases), numel(F))';
bar(ax, G');
set(ax, 'XTick', 1:numel(cases), 'XTickLabel', cases);
ylabel(ax, 'Median of ITM minus P.452 Ld (dB)');
legend(ax, compose('%g MHz', F), 'Location', 'northeast');
title(ax, 'How much of the diffraction gap each ITM ingredient explains'); grid(ax, 'on');
wp_save_fig(fig, out, 'fig15_diffraction_ablation' + tag);
end

%% ------------------------------------------------------------------------
function t = p452_terms(prof, info, f_mhz)
% P.452-18 delta-Bullington terms (matlab_itu_p452 p452_p2p_rev1.m
% L474-508), median effective radius, no clutter (g = h).
d = prof.d_km(:); h = prof.h_m(:);
f = f_mhz / 1000;
ae = info.ae;
t.Lbulla = bull(d, h, info.hts, info.hrs, ae, f);
t.Lbulls = bull(d, zeros(size(h)), info.hts - info.hstd, info.hrs - info.hsrd, ae, f);
t.Ldsph = info.Ldsph;
t.Ld50 = info.Ld50;
t.Lbfsg = info.Lbfsg;
[~, t.nu] = bull(d, h, info.hts, info.hrs, ae, f);
end

function [Lbull, nu] = bull(d, h, hts, hrs, ap, f)
Ce = 1 / ap;
lambda = 0.2998 / f;
dtot = d(end) - d(1);
di = d(2:end-1); hi = h(2:end-1);
Stim = max((hi + 500 * Ce * di .* (dtot - di) - hts) ./ di);
Str = (hrs - hts) / dtot;
if Stim < Str
    nu = max((hi + 500 * Ce * di .* (dtot - di) - (hts * (dtot - di) + hrs * di) / dtot) .* ...
        sqrt(0.002 * dtot ./ (lambda * di .* (dtot - di))));
else
    Srim = max((hi + 500 * Ce * di .* (dtot - di) - hrs) ./ (dtot - di));
    dbp = (hrs - hts + Srim * dtot) / (Stim + Srim);
    nu = (hts + Stim * dbp - (hts * (dtot - dbp) + hrs * dbp) / dtot) * sqrt(0.002 * dtot / (lambda * dbp * (dtot - dbp)));
end
Luc = 0;
if nu > -0.78
    Luc = 6.9 + 20 * log10(sqrt((nu - 0.1).^2 + 1) + nu - 0.1);
end
Lbull = Luc + (1 - exp(-Luc / 6.0)) * (10 + 0.02 * dtot);
end
