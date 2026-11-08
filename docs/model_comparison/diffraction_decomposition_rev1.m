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
        it = itm_terms(pfl, F(f), [L.tx_h_m(k) L.rx_h_m(k)], r.itm.N_0, r.itm.info);
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
function t = itm_terms(pfl, f, h_m, N_0, info)
% ITM v1.4 diffraction terms, same equations as private/itm_p2p_core.m
% (initialize_point_to_point L190-203, longley_rice L366-466,
% diffraction_loss L469-484). Polarization vertical, epsilon 25, sigma 0.02.
np = fix(pfl(1));
p10 = fix(0.1 * np);
h_acc = cumsum(pfl((p10:np - p10) + 3));
h_sys = h_acc(end) / (np - 2 * p10 + 1);
N_s = N_0 * exp(-h_sys / 9460.0);
gamma_e = 157e-9 * (1.0 - 0.04665 * exp(N_s / 179.3));
ep_r = complex(25, 18000 * 0.02 / f);
Z_g = sqrt(ep_r - 1.0) / ep_r;
a_e = 1 / gamma_e;
d_m = info.d_km * 1e3;
d_hzn = info.d_hzn_m;
h_e = info.h_e_m;
dh = info.delta_h_m;
theta_hzn = info.theta_hzn_rad;
d_sML = sum(sqrt(2.0 * h_e * a_e));
d_ML = sum(d_hzn);
theta_los = -max(sum(theta_hzn), -d_ML / a_e);
t.d_ML = d_ML; t.d_sML = d_sML;
t.d_3 = max(d_sML, d_ML + 5.0 * (a_e^2 / f)^(1 / 3));
d_4 = t.d_3 + 10.0 * (a_e^2 / f)^(1 / 3);
t.theta_nlos_mrad = 1e3 * (t.d_3 / a_e - theta_los);

opts = {'two', true};
[A3, c3] = dl(t.d_3, opts{:});
A4 = dl(d_4, opts{:});
t.A_k3 = c3.A_k; t.A_se3 = c3.A_se; t.w3 = c3.w; t.A_fo = c3.A_fo; t.A_d3 = A3;
t.v1 = c3.v1; t.v2 = c3.v2;
t.A_ref = line_or_los(A3, A4);
check = t.A_ref - info.A_ref_db;
if abs(check) > 1e-9
    error('wp:diffraction:check', 'Recomputed ITM A_ref differs from ITM by %g dB.', check);
end
% Ablations
[a3, ~] = dl(t.d_3, 'two', false); a4 = dl(d_4, 'two', false);
t.A_ref_single = line_or_los(a3, a4);
[a3, ~] = dl(t.d_3, 'two', true, 'clutter', false); a4 = dl(d_4, 'two', true, 'clutter', false);
t.A_ref_noclutter = line_or_los(a3, a4);
if d_m > d_ML
    t.A_d_at_d = dl(d_m, 'two', true);
    t.A_all = dl(d_m, 'two', false, 'clutter', false);
else
    t.A_d_at_d = NaN; t.A_all = NaN;
end

    function [A, c] = dl(d, varargin)
        o = struct('two', true, 'clutter', true);
        for i = 1:2:numel(varargin), o.(varargin{i}) = varargin{i + 1}; end
        theta_nlos = d / a_e - theta_los;
        d_nlos = d - d_ML;
        c.v1 = 0.0795775 * (f / 47.7) * theta_nlos^2 * d_hzn(1) * d_nlos / (d_nlos + d_hzn(1));
        c.v2 = 0.0795775 * (f / 47.7) * theta_nlos^2 * d_hzn(2) * d_nlos / (d_nlos + d_hzn(2));
        if o.two
            c.A_k = fres(c.v1) + fres(c.v2);
        else
            c.A_k = fres(max(c.v1, c.v2));
        end
        c.A_se = se(d);
        dh_s = dh * (1.0 - 0.8 * exp(-d_sML / 50e3));
        sh = 0.78 * dh_s * exp(-0.5 * dh_s^0.25);
        c.A_fo = min(15.0, 5 * log10(1.0 + 1e-5 * h_m(1) * h_m(2) * f * sh));
        if ~o.clutter, c.A_fo = 0; end
        dh_d = dh * (1.0 - 0.8 * exp(-d / 50e3));
        q = h_m(1) * h_m(2);
        qk = h_e(1) * h_e(2) - q;
        q = q + 10.0;
        q = (sqrt(1.0 + qk / q) + (-theta_los * a_e + d_ML) / d) * min(dh_d * f / 47.7, 6283.2);
        c.w = 25.1 / (25.1 + sqrt(q));
        A = c.w * c.A_se + (1.0 - c.w) * c.A_k + c.A_fo;
    end

    function A_se = se(d)
        a_0 = 6370e3;
        theta_nlos = d / a_e - theta_los;
        a_m = [(d - d_ML) / (d / a_e - theta_los), 0.5 * d_hzn(1)^2 / h_e(1), 0.5 * d_hzn(2)^2 / h_e(2)];
        dk = [(a_m(1) * theta_nlos) / 1000.0, d_hzn(1) / 1000.0, d_hzn(2) / 1000.0];
        C_0 = ((4.0 / 3.0) * a_0 ./ a_m).^(1 / 3);
        K = 0.017778 * C_0 * f^(-1 / 3) / abs(Z_g);
        B_0 = 1.607 - K;
        x = zeros(1, 3);
        x(2) = B_0(2) * C_0(2)^2 * f^(1 / 3) * dk(2);
        x(3) = B_0(3) * C_0(3)^2 * f^(1 / 3) * dk(3);
        x(1) = B_0(1) * C_0(1)^2 * f^(1 / 3) * dk(1) + x(2) + x(3);
        A_se = 0.05751 * x(1) - 10.0 * log10(x(1)) - hf(x(2), K(2)) - hf(x(3), K(3)) - 20;
    end

    function A = line_or_los(A3, A4)
        % longley_rice L391-466 with the diffraction loss from A3, A4
        M_d = (A4 - A3) / (d_4 - t.d_3);
        A_d0 = A3 - M_d * t.d_3;
        if d_m < d_sML
            A = los_region(M_d, A_d0);
        else
            A = trans_horizon(M_d, A_d0);
        end
        A = max(A, 0);
    end

    function A = trans_horizon(M_d, A_d0)
        d_5 = d_ML + 200e3; d_6 = d_ML + 400e3;
        [A_6, h0] = tropo(d_6, -1); A_5 = tropo(d_5, h0);
        if A_5 < 1000
            M_s = (A_6 - A_5) / 200e3;
            d_x = max(max(d_sML, d_ML + 1.088 * (a_e^2 / f)^(1 / 3) * log(f)), (A_5 - A_d0 - M_s * d_5) / (M_d - M_s));
            A_s0 = (M_d - M_s) * d_x + A_d0;
        else
            M_s = M_d; A_s0 = A_d0; d_x = 10e6;
        end
        if d_m > d_x
            A = M_s * d_m + A_s0;
        else
            A = M_d * d_m + A_d0;
        end
    end

    function A = los_region(M_d, A_d0)
        A_sML = d_sML * M_d + A_d0;
        d_0 = 0.04 * f * h_e(1) * h_e(2);
        if A_d0 >= 0
            d_0 = min(d_0, 0.5 * d_ML); d_1 = d_0 + 0.25 * (d_ML - d_0);
        else
            d_1 = max(-A_d0 / M_d, 0.25 * d_ML);
        end
        A_1 = los_loss(d_1, M_d, A_d0);
        flag = false; k1 = 0; k2 = 0;
        if d_0 < d_1
            A_0 = los_loss(d_0, M_d, A_d0);
            q = log(d_sML / d_0);
            k2 = max(0, ((d_sML - d_0) * (A_1 - A_0) - (d_1 - d_0) * (A_sML - A_0)) / ((d_sML - d_0) * log(d_1 / d_0) - (d_1 - d_0) * q));
            flag = A_d0 > 0 || k2 > 0;
            if flag
                k1 = (A_sML - A_0 - k2 * q) / (d_sML - d_0);
                if k1 < 0
                    k1 = 0; k2 = max(A_sML - A_0, 0) / q;
                    if k2 == 0, k1 = M_d; end
                end
            end
        end
        if ~flag
            k1 = max(A_sML - A_1, 0) / (d_sML - d_1); k2 = 0;
            if k1 == 0, k1 = M_d; end
        end
        A_o = A_sML - k1 * d_sML - k2 * log(d_sML);
        A = A_o + k1 * d_m + k2 * log(d_m);
    end

    function A_los = los_loss(d, M_d, A_d0)
        dh_d = dh * (1.0 - 0.8 * exp(-d / 50e3));
        sh = 0.78 * dh_d * exp(-0.5 * dh_d^0.25);
        wn = f / 47.7;
        sin_psi = (h_e(1) + h_e(2)) / sqrt(d^2 + (h_e(1) + h_e(2))^2);
        R_e = (sin_psi - Z_g) / (sin_psi + Z_g) * exp(-min(10.0, wn * sh * sin_psi));
        q = real(R_e)^2 + imag(R_e)^2;
        if q < 0.25 || q < sin_psi, R_e = R_e * sqrt(sin_psi / q); end
        dphi = wn * 2.0 * h_e(1) * h_e(2) / d;
        if dphi > pi / 2, dphi = pi - (pi / 2)^2 / dphi; end
        rr = complex(cos(dphi), -sin(dphi)) + R_e;
        A_t = -10 * log10(real(rr)^2 + imag(rr)^2);
        A_d = M_d * d + A_d0;
        w = 1 / (1 + f * dh / max(10e3, d_sML));
        A_los = w * A_t + (1 - w) * A_d;
    end

    function [A, h0] = tropo(d, h0)
        wn = f / 47.7;
        ad = d_hzn(1) - d_hzn(2); rr = h_e(2) / h_e(1);
        if ad < 0, ad = -ad; rr = 1 / rr; end
        theta = theta_hzn(1) + theta_hzn(2) + d / a_e;
        r1 = 2 * wn * theta * h_e(1); r2 = 2 * wn * theta * h_e(2);
        if h0 > 15
            H_0 = h0;
        else
            if r1 < 0.2 && r2 < 0.2, A = 1001; return, end
            s = (d - ad) / (d + ad);
            q = min(max(0.1, rr / s), 10.0); s = max(0.1, s);
            h_0 = (d - ad) * (d + ad) * theta * 0.25 / d;
            eta = (h_0 / 1.7556e3) * (1 + (0.031 - N_s * 2.32e-3 + N_s^2 * 5.67e-6) * exp(-(min(1.7, h_0 / 8e3))^6));
            H_00 = (h0f(r1, eta) + h0f(r2, eta)) / 2;
            H_0 = max(H_00 + min(H_00, 6 * (0.6 - log10(max(eta, 1))) * log10(s) * log10(q)), 0);
            if eta < 1
                H_0 = eta * H_0 + (1 - eta) * 10 * log10(((1 + sqrt(2) / r1) * (1 + sqrt(2) / r2))^2 * (r1 + r2) / (r1 + r2 + 2 * sqrt(2)));
            end
            if H_0 > 15 && h0 >= 0, H_0 = h0; end
        end
        h0 = H_0;
        th = d / a_e - theta_los;
        A = ff(th * d) + 10 * log10(wn * 47.7 * th^4) - 0.1 * (N_s - 301) * exp(-th * d / 40e3) + H_0;
    end
end

function A = fres(v2)
if v2 < 5.76
    A = 6.02 + 9.11 * sqrt(v2) - 1.27 * v2;
else
    A = 12.953 + 10 * log10(v2);
end
end

function r = hf(x, K)
if x < 200
    w = -log(K);
    if K < 1e-5 || x * w^3 > 5495
        r = -117;
        if x > 1, r = 17.372 * log(x) + r; end
    else
        r = 2.5e-5 * x^2 / K - 8.686 * w - 15;
    end
else
    r = 0.05751 * x - 4.343 * log(x);
    if x < 2000
        w = 0.0134 * x * exp(-0.005 * x);
        r = (1 - w) * r + w * (17.372 * log(x) - 117);
    end
end
end

function F0 = ff(td)
a = [133.4, 104.6, 71.8]; b = [0.332e-3, 0.212e-3, 0.157e-3]; c = [-10, -2.5, 5];
if td <= 10e3, i = 1; elseif td <= 70e3, i = 2; else, i = 3; end
F0 = a(i) + b(i) * td + c(i) * log10(td);
end

function h = h0f(r, eta)
eta = min(max(eta, 1), 5);
i = fix(eta);
q = eta - i;
h = h0c(i, r);
if q ~= 0, h = (1 - q) * h + q * h0c(i + 1, r); end
end

function h = h0c(j, r)
a = [25.0, 80.0, 177.0, 395.0, 705.0];
b = [24.0, 45.0, 68.0, 80.0, 105.0];
h = 10 * log10(1 + a(j) * (1 / r)^4 + b(j) * (1 / r)^2);
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
