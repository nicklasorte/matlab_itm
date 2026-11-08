function R = make_wp_figures_rev1(options)
%MAKE_WP_FIGURES_REV1 Figures and numbers for the ITM, P.2001, and P.452 comparison working paper.
%   R = MAKE_WP_FIGURES_REV1() runs the calculations behind every figure
%   and table of the working paper "ITM, ITU-R P.2001, and ITU-R P.452:
%   how the models differ by propagation mechanism", writes the figures
%   (PNG) and the result tables (CSV) to options.OutDir, and returns every
%   result in a struct (also saved as wp_results_rev1.mat).
%
%   Every model gets the same terrain profile in each calculation, so the
%   differences are the models, not the terrain:
%     ITM v1.4     itm_p2p_rev1 (this repository)
%     P.452-18     p452_p2p_rev1 (nicklasorte/matlab_itu_p452), 0.001-50 %
%     P.2001-6     p2001_rev1 with Profile= (nicklasorte/itu_p2001)
%   ITM's radio climate and N_0 come from itm_radio_climate_rev1 and
%   itm_surface_refractivity_rev1 at the path midpoint (WInnForum rule);
%   P.452 and P.2001 read their own ITU maps at the path midpoint.
%   Antenna heights are above ground; polarization is vertical; ITM uses
%   epsilon 25, sigma 0.02 S/m, mdvar 13, confidence 50 %.
%
%   Calculations (figure numbers follow the paper):
%     E1  Smooth earth, flat land and flat sea, 1 to 200 km (Fig. 1, 4, 8)
%     E2  Single knife edge against ITU-R P.526 J(v) (Fig. 2)
%     E3  Terrain resolution: 30 m, 90 m, and 1 km smoothed profiles (Fig. 3)
%     E5  Full distribution on five archetype paths (Fig. 5, 6)
%     E6  Frequency and receiver-height sweeps (Fig. 7)
%     E7  Real-terrain sample, three regions (Fig. 9, 10)
%     E8  Distance to a loss threshold along real-terrain radials (Fig. 11)
%     E9  ITM climate and refractivity sensitivity (table)
%   The paper's three study frequencies are 2700, 4900, and 7250 MHz.
%
%   Name-value options:
%     OutDir             output folder (figures/ next to this file)
%     P2001Dir, P452Dir  itu_p2001 and matlab_itu_p452 folders ("": on the
%                        path, or next to the matlab_itm folder)
%     Freqs              study frequencies, MHz ([2700 4900 7250])
%     NumLinksPerRegion  real-terrain links per region (20)
%     Seed               random seed (7)
%
%   Run time on R2025b, Apple silicon, tiles cached: about 5 minutes. The
%   first run downloads about 40 terrain tiles.

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'figures')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Freqs (1,:) double = [2700 4900 7250]
    options.NumLinksPerRegion (1,1) double {mustBeInteger, mustBePositive} = 20
    options.Seed (1,1) double = 7
end

here = fileparts(mfilename('fullpath'));
itm_root = fileparts(fileparts(here));
addpath(itm_root);
add_model_path(options.P2001Dir, itm_root, "itu_p2001", "p2001_rev1");
add_model_path(options.P452Dir, itm_root, "matlab_itu_p452", "p452_p2p_rev1");
if ~isfolder(options.OutDir)
    mkdir(options.OutDir);
end
out = options.OutDir;
F = options.Freqs;
P = [0.001 0.002 0.005 0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 20 30 40 50 60 70 80 90 95 98 99 99.5 99.8 99.9 99.95 99.98 99.99];
i50 = find(P == 50);
R = struct('freqs_mhz', F, 'p', P, 'commits', commits(itm_root));
warning('off', 'itm:validity:Caution');
warning('off', 'p2001:profile:spacing');
t_all = tic;

%% E1: smooth earth, land and sea ------------------------------------------
fprintf('E1 smooth earth ...\n');
D = [1:10, 12:2:50, 55:5:200];
cases = struct('name', {"land", "sea"}, 'tx', {[39.0 -77.0], [37.0 -72.0]}, 'zone', {4, 1});
for c = 1:2
    for f = 1:numel(F)
        for k = 1:numel(D)
            prof = flat_profile(D(k), cases(c).tx, cases(c).zone);
            r = run3(prof, F(f), 30, 10, P);
            E1.(cases(c).name).itm(f, k, :) = r.itm.Lb;
            E1.(cases(c).name).p452(f, k, :) = r.p452.Lb;
            E1.(cases(c).name).p2001(f, k, :) = r.p2001.Lb;
            E1.(cases(c).name).itm_mech(f, k) = r.itm.mech(1);
            E1.(cases(c).name).p452_mech(f, k, :) = r.p452.mech;
            E1.(cases(c).name).p2001_mech(f, k, :) = r.p2001.mech;
        end
    end
end
E1.D_km = D;
E1.fsl = 32.45 + 20 * log10(F(:)) + 20 * log10(D);
R.E1 = E1;

fig = figure('Visible', 'off', 'Position', [0 0 1200 380]);
tl = tiledlayout(fig, 1, numel(F), 'TileSpacing', 'compact');
for f = 1:numel(F)
    ax = nexttile(tl); hold(ax, 'on');
    plot_models(ax, D, squeeze(E1.land.itm(f, :, i50)) - E1.fsl(f, :), ...
        squeeze(E1.land.p452(f, :, i50)) - E1.fsl(f, :), squeeze(E1.land.p2001(f, :, i50)) - E1.fsl(f, :));
    mark_itm_regimes(ax, D, E1.land.itm_mech(f, :), squeeze(E1.land.itm(f, :, i50)) - E1.fsl(f, :));
    title(ax, sprintf('%g MHz, flat land, 50 %%', F(f))); xlabel(ax, 'Distance (km)');
    if f == 1, ylabel(ax, 'Basic transmission loss minus free space (dB)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
save_fig(fig, out, 'fig01_smooth_earth_land_50pct');

%% E2: single knife edge vs. P.526 -----------------------------------------
fprintf('E2 knife edge ...\n');
% Tall antennas (100 m) keep the smooth-earth term small, so the
% excess loss is mostly the knife edge
H = [0 25 50 75 100 125 150 175 200 250 300 400 500 600];
L_km = 20; h_ant = 100; ae = 6371e3 * 4 / 3;
for f = 1:numel(F)
    lam = 299.792458 / F(f);                   % m
    for k = 1:numel(H)
        prof = flat_profile(L_km, [39.0 -77.0], 4);
        mid = round(numel(prof.d_km) / 2);
        prof.h_m(mid) = H(k);                 % one raised point: a knife edge
        d1 = prof.d_km(mid) * 1e3; d2 = L_km * 1e3 - d1;
        clear_h = H(k) + d1 * d2 / (2 * ae) - h_ant;      % above the ray, 4/3 earth
        v = clear_h * sqrt(2 / lam * (1 / d1 + 1 / d2));
        r = run3(prof, F(f), h_ant, h_ant, 50);
        fsl = 32.45 + 20 * log10(F(f)) + 20 * log10(L_km);
        E2.v(f, k) = v;
        E2.J(f, k) = knife_edge_J(v);
        E2.itm(f, k) = r.itm.Lb - fsl;
        E2.p452(f, k) = r.p452.Lb - fsl;
        E2.p2001(f, k) = r.p2001.Lb - fsl;
    end
end
E2.H_m = H;
R.E2 = E2;
fig = figure('Visible', 'off', 'Position', [0 0 1200 380]);
tl = tiledlayout(fig, 1, numel(F), 'TileSpacing', 'compact');
for f = 1:numel(F)
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, E2.v(f, :), E2.J(f, :), 'k--', 'LineWidth', 1.5, 'DisplayName', 'P.526 knife edge J(v)');
    plot_models(ax, E2.v(f, :), E2.itm(f, :), E2.p452(f, :), E2.p2001(f, :));
    title(ax, sprintf('%g MHz, 20 km path, 100 m antennas', F(f))); xlabel(ax, 'Fresnel-Kirchhoff parameter v');
    if f == 1, ylabel(ax, 'Excess loss over free space (dB)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
save_fig(fig, out, 'fig02_knife_edge');

%% E7: real-terrain sample (also feeds E3, E5, E6) --------------------------
fprintf('E7 real-terrain sample ...\n');
regions = struct('name', {"coastal plain", "piedmont", "appalachian"}, ...
    'box', {[38.0 39.5 -76.3 -75.2], [38.3 39.6 -77.9 -76.9], [37.6 39.4 -80.4 -78.6]});
rs = RandStream('mrg32k3a', 'Seed', options.Seed);
links = table();
profs = {};
for g = 1:numel(regions)
    b = regions(g).box;
    for j = 1:options.NumLinksPerRegion
        tx = [b(1) + diff(b(1:2)) * rand(rs), b(3) + diff(b(3:4)) * rand(rs)];
        len = exp(log(10) + (log(150) - log(10)) * rand(rs));
        az = 360 * rand(rs);
        [la2, lo2] = reckon(tx(1), tx(2), len * 1e3, az, wgs84Ellipsoid('meter'));
        htx = 10 + 90 * rand(rs); hrx = 2 + 28 * rand(rs);
        prof = terrain_profile(tx, [la2 lo2]);
        profs{end + 1, 1} = prof; %#ok<AGROW> 60 links
        links = [links; table(g, regions(g).name, tx(1), tx(2), la2, lo2, len, htx, hrx, ...
            'VariableNames', {'region_id', 'region', 'tx_lat', 'tx_lon', 'rx_lat', 'rx_lon', 'length_km', 'tx_h_m', 'rx_h_m'})]; %#ok<AGROW>
    end
end
n = height(links);
E7.links = links;
for f = 1:numel(F)
    for k = 1:n
        r = run3(profs{k}, F(f), links.tx_h_m(k), links.rx_h_m(k), P);
        E7.itm(f, k, :) = r.itm.Lb; E7.p452(f, k, :) = r.p452.Lb; E7.p2001(f, k, :) = r.p2001.Lb;
        E7.itm_mech(f, k) = r.itm.mech(1);
        E7.p452_mech(f, k) = r.p452.mech(i50); E7.p2001_mech(f, k) = r.p2001.mech(i50);
        E7.itm_dh(k) = r.itm.delta_h_m; E7.itm_flags(f, k) = r.itm.flags;
        E7.itm_elev(k, :) = r.itm.elev; E7.p452_elev(k, :) = r.p452.elev; E7.p2001_elev(k, :) = r.p2001.elev;
    end
end
R.E7 = E7;
classes = ["LOS", "Diffraction", "Troposcatter"];
cc = [0 1 3];                                   % their codes
fig = figure('Visible', 'off', 'Position', [0 0 1200 760]);
tl = tiledlayout(fig, 2, numel(F), 'TileSpacing', 'compact');
for row = 1:2
    for f = 1:numel(F)
        ax = nexttile(tl); hold(ax, 'on');
        if row == 1, other = E7.p2001; nm = 'P.2001'; else, other = E7.p452; nm = 'P.452'; end
        d = other(f, :, i50) - E7.itm(f, :, i50);
        cls = common_class(E7.itm_mech(f, :));
        for c = 1:3
            sel = cls == cc(c);
            if any(sel)
                x = sort(d(sel)); y = (1:numel(x)) / numel(x);
                stairs(ax, x, y, 'LineWidth', 1.5, 'DisplayName', sprintf('%s (%d)', classes(c), nnz(sel)));
            end
        end
        xline(ax, 0, 'k:', 'HandleVisibility', 'off');
        title(ax, sprintf('%s minus ITM, %g MHz, 50 %%', nm, F(f))); xlabel(ax, 'Difference (dB)');
        if f == 1, ylabel(ax, 'Fraction of links'); end
        legend(ax, 'Location', 'southeast'); grid(ax, 'on');
    end
end
save_fig(fig, out, 'fig09_real_terrain_cdf_by_mechanism');

% Fig. 10: the diffraction gap against ITM's terrain irregularity
fig = figure('Visible', 'off', 'Position', [0 0 1200 380]);
tl = tiledlayout(fig, 1, numel(F), 'TileSpacing', 'compact');
for f = 1:numel(F)
    ax = nexttile(tl); hold(ax, 'on');
    cls = common_class(E7.itm_mech(f, :));
    d = E7.p2001(f, :, i50) - E7.itm(f, :, i50);
    mk = 'osd';
    for c = 1:3
        sel = cls == cc(c);
        scatter(ax, E7.itm_dh(sel), d(sel), 30, mk(c), 'filled', 'DisplayName', classes(c));
    end
    set(ax, 'XScale', 'log'); yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    title(ax, sprintf('%g MHz, 50 %%', F(f))); xlabel(ax, 'ITM terrain irregularity \Deltah (m)');
    if f == 1, ylabel(ax, 'P.2001 minus ITM (dB)'); legend(ax, 'Location', 'southwest'); end
    grid(ax, 'on');
end
save_fig(fig, out, 'fig10_gap_vs_delta_h');

%% E3: terrain resolution ----------------------------------------------------
fprintf('E3 terrain resolution ...\n');
f3 = 1;                                         % 2700 MHz
dif = find(common_class(E7.itm_mech(f3, :)) == 1);
res_names = ["30 m", "90 m", "1 km smoothed"];
for j = 1:numel(dif)
    k = dif(j);
    base = profs{k};
    variants = {base, decimate_profile(base, 3), smooth_profile(base, 33)};
    for v = 1:3
        r = run3(variants{v}, F(f3), links.tx_h_m(k), links.rx_h_m(k), 50);
        E3.itm(j, v) = r.itm.Lb; E3.p452(j, v) = r.p452.Lb; E3.p2001(j, v) = r.p2001.Lb;
        E3.dh(j, v) = r.itm.delta_h_m;
    end
end
E3.links = dif;
E3.res_names = res_names;
R.E3 = E3;
fig = figure('Visible', 'off', 'Position', [0 0 1000 380]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');
ax = nexttile(tl); hold(ax, 'on');
chg = @(M) M(:, 2:3) - M(:, 1);
b = [median(chg(E3.itm), 1); median(chg(E3.p452), 1); median(chg(E3.p2001), 1)];
bar(ax, categorical(["ITM", "P.452", "P.2001"]), b);
legend(ax, res_names(2:3), 'Location', 'northeast'); ylabel(ax, 'Median change from the 30 m result (dB)');
title(ax, sprintf('%d diffraction links, %g MHz, 50 %%', numel(dif), F(f3))); grid(ax, 'on');
ax = nexttile(tl); hold(ax, 'on');
gap = E3.p2001 - E3.itm;
boxchart(ax, categorical(repelem(res_names, numel(dif))', res_names), gap(:));
ylabel(ax, 'P.2001 minus ITM (dB)'); title(ax, 'Gap by terrain resolution'); grid(ax, 'on');
save_fig(fig, out, 'fig03_terrain_resolution');

%% E4: mechanism maps (from E1) --------------------------------------------
fprintf('E4 mechanism maps ...\n');
fig = figure('Visible', 'off', 'Position', [0 0 1200 760]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
cmap = [0.35 0.35 0.35; 0 0.447 0.698; 0.835 0.369 0; 0 0.620 0.451; 0.8 0.475 0.655];
names = ["LOS", "Diffraction", "Anomalous", "Troposcatter", "Sporadic-E"];
for c = 1:2
    for mdl = ["p2001", "p452"]
        ax = nexttile(tl);
        M = squeeze(E1.(cases(c).name).(mdl + "_mech")(1, :, :))';
        if mdl == "p452", M(P > 50, :) = NaN; end
        imagesc(ax, 1:numel(D), 1:numel(P), M, 'AlphaData', ~isnan(M), [0 4]); colormap(ax, cmap);
        set(ax, 'YDir', 'normal', 'YTick', 1:3:numel(P), 'YTickLabel', string(P(1:3:end)), ...
            'XTick', 1:6:numel(D), 'XTickLabel', string(D(1:6:end)));
        hold(ax, 'on');
        itm_m = common_class(E1.(cases(c).name).itm_mech(1, :));
        plot(ax, 1:numel(D), repmat(numel(P) + 0.5, 1, numel(D)), 'k-', 'HandleVisibility', 'off');
        scatter(ax, 1:numel(D), repmat(numel(P) + 0.9, 1, numel(D)), 18, cmap(itm_m + 1, :), 's', 'filled', 'Clipping', 'off');
        title(ax, sprintf('%s, flat %s, %g MHz (top strip: ITM regime)', model_label(mdl), cases(c).name, F(1)));
        xlabel(ax, 'Distance (km)'); ylabel(ax, 'Time percentage');
        cb = colorbar(ax, 'Ticks', 0:4, 'TickLabels', names); cb.Limits = [0 4]; %#ok<NASGU>
    end
end
save_fig(fig, out, 'fig04_mechanism_maps');

%% E5: full distribution on archetype paths --------------------------------
fprintf('E5 archetypes ...\n');
arch = pick_archetypes(E7, f3, i50);
arch_names = ["Line of sight", "Single-horizon diffraction", "Double-horizon diffraction", "Troposcatter"];
arch_links = [arch.los, arch.single, arch.double, arch.tropo];
A = struct();
for a = 1:numel(arch_links)
    k = arch_links(a);
    A(a).name = arch_names(a); A(a).link = k; A(a).prof = profs{k};
    A(a).htx = links.tx_h_m(k); A(a).hrx = links.rx_h_m(k);
    A(a).tx = [links.tx_lat(k) links.tx_lon(k)]; A(a).rx = [links.rx_lat(k) links.rx_lon(k)];
end
% Fifth archetype: an over-sea coastal path, Atlantic City NJ to Ocean City MD
A(5).name = "Over-sea coastal"; A(5).link = NaN; A(5).htx = 30; A(5).hrx = 10;
A(5).tx = [39.36 -74.42]; A(5).rx = [38.34 -75.08]; A(5).prof = terrain_profile(A(5).tx, A(5).rx);
for a = 1:numel(A)
    for f = 1:numel(F)
        r = run3(A(a).prof, F(f), A(a).htx, A(a).hrx, P);
        A(a).itm(f, :) = r.itm.Lb; A(a).p452(f, :) = r.p452.Lb; A(a).p2001(f, :) = r.p2001.Lb;
        A(a).p2001_mech(f, :) = r.p2001.mech; A(a).p452_mech(f, :) = r.p452.mech; A(a).itm_mech(f) = r.itm.mech(1);
        rc = run3(A(a).prof, F(f), A(a).htx, A(a).hrx, P, [10 90]);
        A(a).itm_c10(f, :) = rc.itm.Lb_conf(1, :); A(a).itm_c90(f, :) = rc.itm.Lb_conf(2, :);
    end
    A(a).length_km = A(a).prof.d_km(end);
end
R.E5 = A;
fig = figure('Visible', 'off', 'Position', [0 0 1300 760]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
z = norminv(P / 100);
for a = 1:numel(A)
    ax = nexttile(tl); hold(ax, 'on');
    fill(ax, [z fliplr(z)], [A(a).itm_c10(1, :) fliplr(A(a).itm_c90(1, :))], [0 0.447 0.698], ...
        'FaceAlpha', 0.12, 'EdgeColor', 'none', 'DisplayName', 'ITM, 10-90 % confidence');
    plot_models(ax, z, A(a).itm(1, :), A(a).p452(1, :), A(a).p2001(1, :));
    tk = [0.001 0.01 0.1 1 10 50 90 99 99.9 99.99];
    set(ax, 'XTick', norminv(tk / 100), 'XTickLabel', string(tk));
    title(ax, sprintf('%s, %.0f km, %g MHz', A(a).name, A(a).length_km, F(1)));
    xlabel(ax, 'Time percentage (normal scale)');
    if a == 1, ylabel(ax, 'Basic transmission loss (dB)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
ax = nexttile(tl); hold(ax, 'on');          % spread about the median
for a = 1:numel(A)
    plot(ax, z, A(a).p2001(1, :) - A(a).p2001(1, i50), '-', 'Color', model_color("p2001"), 'HandleVisibility', 'off');
    plot(ax, z, A(a).itm(1, :) - A(a).itm(1, i50), '-', 'Color', model_color("itm"), 'HandleVisibility', 'off');
    plot(ax, z, A(a).p452(1, :) - A(a).p452(1, i50), '-', 'Color', model_color("p452"), 'HandleVisibility', 'off');
end
set(ax, 'XTick', norminv([0.001 0.1 1 10 50 90 99 99.99] / 100), 'XTickLabel', string([0.001 0.1 1 10 50 90 99 99.99]));
title(ax, 'Loss minus its 50 % value, all five paths'); xlabel(ax, 'Time percentage (normal scale)');
ylabel(ax, 'dB'); grid(ax, 'on');
save_fig(fig, out, 'fig05_full_distribution_archetypes');

% Fig. 6: which P.2001 sub-model dominates along the distribution
fig = figure('Visible', 'off', 'Position', [0 0 1300 300]);
tl = tiledlayout(fig, 1, numel(A), 'TileSpacing', 'compact');
for a = 1:numel(A)
    ax = nexttile(tl);
    imagesc(ax, 1:numel(P), 1:numel(F), A(a).p2001_mech, [0 4]); colormap(ax, cmap);
    set(ax, 'YTick', 1:numel(F), 'YTickLabel', string(F), 'XTick', 1:4:numel(P), 'XTickLabel', string(P(1:4:end)));
    title(ax, A(a).name); xlabel(ax, 'Time percentage');
    if a == 1, ylabel(ax, 'MHz'); end
end
cb = colorbar(ax, 'Ticks', 0:4, 'TickLabels', names); cb.Layout.Tile = 'east';
save_fig(fig, out, 'fig06_p2001_dominant_mechanism_by_percentage');

%% E6: frequency and height sweeps ------------------------------------------
fprintf('E6 sweeps ...\n');
FS = round(logspace(log10(100), log10(10000), 21));
HS = [2 3 5 7 10 15 20 30 50 75 100];
for a = 1:3                      % LOS, single-horizon, double-horizon archetypes
    for j = 1:numel(FS)
        r = run3(A(a).prof, FS(j), A(a).htx, A(a).hrx, 50);
        fsl = 32.45 + 20 * log10(FS(j)) + 20 * log10(A(a).length_km);
        E6.f_itm(a, j) = r.itm.Lb - fsl; E6.f_p452(a, j) = r.p452.Lb - fsl; E6.f_p2001(a, j) = r.p2001.Lb - fsl;
    end
    for j = 1:numel(HS)
        r = run3(A(a).prof, F(1), A(a).htx, HS(j), 50);
        E6.h_itm(a, j) = r.itm.Lb; E6.h_p452(a, j) = r.p452.Lb; E6.h_p2001(a, j) = r.p2001.Lb;
    end
end
E6.freqs = FS; E6.heights = HS;
R.E6 = E6;
fig = figure('Visible', 'off', 'Position', [0 0 1200 700]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact');
for a = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    plot_models(ax, FS, E6.f_itm(a, :), E6.f_p452(a, :), E6.f_p2001(a, :));
    xline(ax, F, ':', 'HandleVisibility', 'off'); set(ax, 'XScale', 'log');
    title(ax, sprintf('%s, 50 %%', A(a).name)); xlabel(ax, 'Frequency (MHz)');
    if a == 1, ylabel(ax, 'Loss minus free space (dB)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
for a = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    plot_models(ax, HS, E6.h_itm(a, :), E6.h_p452(a, :), E6.h_p2001(a, :));
    set(ax, 'XScale', 'log'); title(ax, sprintf('%s, %g MHz, 50 %%', A(a).name, F(1)));
    xlabel(ax, 'Receiver height above ground (m)');
    if a == 1, ylabel(ax, 'Basic transmission loss (dB)'); end
    grid(ax, 'on');
end
save_fig(fig, out, 'fig07_frequency_height_sweeps');

%% E8: distance to a loss threshold -----------------------------------------
fprintf('E8 separation distance ...\n');
% Smooth earth (from E1): first distance where the 50 % loss reaches a threshold
thr = [150 160 170 180];
for c = 1:2
    for f = 1:numel(F)
        for t = 1:numel(thr)
            for mdl = ["itm", "p452", "p2001"]
                L = squeeze(E1.(cases(c).name).(mdl)(f, :, i50));
                k = find(L >= thr(t), 1);
                E8.smooth.(cases(c).name).(mdl)(f, t) = NaN;
                if ~isempty(k), E8.smooth.(cases(c).name).(mdl)(f, t) = D(k); end
            end
        end
    end
end
% Real terrain: four radials from a Piedmont site, prefix of one long profile
site = [38.90 -77.45]; az4 = [0 90 180 270]; Dr = 2:2:150;
for j = 1:numel(az4)
    [la2, lo2] = reckon(site(1), site(2), 150e3, az4(j), wgs84Ellipsoid('meter'));
    full = terrain_profile(site, [la2 lo2]);
    for k = 1:numel(Dr)
        sub = prefix_profile(full, Dr(k));
        for f = 1:numel(F)
            r = run3(sub, F(f), 30, 10, [1 50]);
            E8.radial.itm(j, k, f, :) = r.itm.Lb; E8.radial.p452(j, k, f, :) = r.p452.Lb;
            E8.radial.p2001(j, k, f, :) = r.p2001.Lb;
        end
    end
end
E8.thr = thr; E8.radial.D_km = Dr; E8.radial.az = az4; E8.radial.site = site;
R.E8 = E8;
fig = figure('Visible', 'off', 'Position', [0 0 1200 700]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
for j = 1:numel(az4)
    ax = nexttile(tl); hold(ax, 'on');
    plot_models(ax, Dr, squeeze(E8.radial.itm(j, :, 1, 2)), squeeze(E8.radial.p452(j, :, 1, 2)), ...
        squeeze(E8.radial.p2001(j, :, 1, 2)));
    plot(ax, Dr, 32.45 + 20 * log10(F(1)) + 20 * log10(Dr), 'k:', 'DisplayName', 'Free space');
    title(ax, sprintf('Radial %d deg from %.2f N, %.2f W, %g MHz, 50 %%', az4(j), site(1), -site(2), F(1)));
    xlabel(ax, 'Distance (km)');
    if j == 1, ylabel(ax, 'Basic transmission loss (dB)'); legend(ax, 'Location', 'southeast'); end
    grid(ax, 'on');
end
save_fig(fig, out, 'fig11_radial_loss_vs_distance');
fig = figure('Visible', 'off', 'Position', [0 0 1200 380]);
tl = tiledlayout(fig, 1, numel(F), 'TileSpacing', 'compact');
for f = 1:numel(F)
    ax = nexttile(tl); hold(ax, 'on');
    for mdl = ["itm", "p452", "p2001"]
        plot(ax, thr, E8.smooth.land.(mdl)(f, :), '-o', 'Color', model_color(mdl), 'LineWidth', 1.5, ...
            'DisplayName', model_label(mdl));
    end
    title(ax, sprintf('%g MHz, flat land, 50 %%', F(f))); xlabel(ax, 'Loss threshold (dB)');
    if f == 1, ylabel(ax, 'Distance to reach the threshold (km)'); legend(ax, 'Location', 'northwest'); end
    grid(ax, 'on');
end
save_fig(fig, out, 'fig08_distance_to_threshold_smooth_earth');

%% E9: ITM climate and refractivity sensitivity ------------------------------
fprintf('E9 sensitivity ...\n');
a = 3; pf = A(a).prof; pfl = itm_pfl(pf);
for cl = 1:7
    E9.climate(cl, :) = itm_p2p_rev1(A(a).htx, A(a).hrx, pfl, F(1), [1 10 50 90 99], climate=cl, N_0=320, validity="off");
end
N0s = [280 300 320 340 360];
for j = 1:numel(N0s)
    E9.n0(j, :) = itm_p2p_rev1(A(a).htx, A(a).hrx, pfl, F(1), [1 10 50 90 99], climate=6, N_0=N0s(j), validity="off");
    E9.p452_n0(j, :) = p452_p2p_rev1(pf.d_km, pf.h_m, [], zone452(pf.zone), A(a).htx, A(a).hrx, F(1) / 1000, ...
        [1 10 50], tx_deg=pf.tx, rx_deg=pf.rx, N0=N0s(j), validity="off");
end
E9.N0s = N0s;
R.E9 = E9;

%% Tables --------------------------------------------------------------------
R.tables = make_tables(R, F, P, i50, classes, out);
R.seconds = toc(t_all);
save(fullfile(out, 'wp_results_rev1.mat'), 'R');
fprintf('Done in %.0f s. Figures and tables in %s\n', R.seconds, out);
end

%% ========================================================================
function r = run3(prof, f_mhz, htx, hrx, p, conf)
% The three models on one profile. prof: d_km, h_m, zone (1 sea, 4 land),
% tx, rx ([lat lon]), mid ([lat lon]).
if nargin < 6, conf = 50; end
pfl = itm_pfl(prof);
c = itm_radio_climate_rev1(prof.mid(1), prof.mid(2));
if c == 7
    c = min(itm_radio_climate_rev1(prof.tx(1), prof.tx(2)), itm_radio_climate_rev1(prof.rx(1), prof.rx(2)));
end
n0 = itm_surface_refractivity_rev1(prof.mid(1), prof.mid(2));
if isscalar(conf)
    [L, info] = itm_p2p_rev1(htx, hrx, pfl, f_mhz, p, climate=c, N_0=n0, validity="off");
    r.itm.Lb = L(:)';
    r.itm.mech = repmat(info.mode_code, size(p));
    r.itm.elev = info.elevation_deg;
    r.itm.delta_h_m = info.delta_h_m;
    fl = uint32(0);
    for w = unique(info.warnings(:))'
        fl = bitor(fl, w);                % union of the flags over all percentages
    end
    r.itm.flags = fl;
    r.itm.climate = c; r.itm.N_0 = n0;
else
    T = itm_p2p_rev1(htx, hrx, pfl, f_mhz, p(:), confidence=conf, climate=c, N_0=n0, validity="off");
    r.itm.Lb_conf = T';
end
if ~isscalar(conf)
    return
end
% P.452-18: 0.001 to 50 % only
ok = p >= 0.001 & p <= 50;
r.p452.Lb = NaN(size(p)); r.p452.mech = NaN(size(p));
[Lb, info] = p452_p2p_rev1(prof.d_km, prof.h_m, [], zone452(prof.zone), htx, hrx, f_mhz / 1000, p(ok), ...
    tx_deg=prof.tx, rx_deg=prof.rx, validity="off");
r.p452.Lb(ok) = Lb(:)';
Ld = info.Lb0p(:) + info.Ldp(:);
[~, k] = min([Ld, info.Lbs(:) + zeros(size(Ld)), info.Lba(:) + zeros(size(Ld))], [], 2);
code = [1; 3; 2];                         % diffraction path, troposcatter, anomalous
m = code(k);
m(k == 1 & info.pathtype == 1) = 0;       % line of sight
r.p452.mech(ok) = m';
r.p452.elev = rad2deg([info.theta_t, info.theta_r] / 1000);
% P.2001-6
pr = struct('d_km', prof.d_km(:), 'h_m', prof.h_m(:), 'zone', prof.zone(:));
[lb, ~, el, mech] = p2001_rev1([prof.tx htx], [prof.rx hrx], f_mhz, p(:), Profile=pr, Validity="off", InfoDetail="brief");
r.p2001.Lb = lb(:)'; r.p2001.mech = mech(:)'; r.p2001.elev = el;
end

function pfl = itm_pfl(prof)
np = numel(prof.d_km) - 1;
pfl = [np; prof.d_km(end) * 1e3 / np; prof.h_m(:)];
end

function z = zone452(zone)
% P.2001 zones (1 sea, 3 coastal land, 4 inland) to P.452 (3 sea, 1 coastal, 2 inland)
z = 2 * ones(size(zone));
z(zone == 1) = 3;
z(zone == 3) = 1;
end

function prof = flat_profile(len_km, tx, zone)
np = max(10, round(len_km * 10));          % 100 m spacing; flat, so resolution is irrelevant
prof.d_km = linspace(0, len_km, np + 1)';
prof.h_m = zeros(np + 1, 1);
prof.zone = zone * ones(np + 1, 1);
prof.tx = tx;
prof.rx = [tx(1) + len_km / 111.2, tx(2)];
prof.mid = (prof.tx + prof.rx) / 2;
end

function prof = terrain_profile(tx, rx)
[pfl, info] = itm_terrain_profile_rev1(tx(1), tx(2), rx(1), rx(2));
np = pfl(1);
prof.d_km = (0:np)' * pfl(2) / 1e3;
prof.h_m = pfl(3:end);
prof.zone = p2001_zone_lookup_rev1(info.lat_deg, info.lon_deg);
prof.zone(info.source_code == 0) = 1;      % no elevation data: open water
prof.tx = tx; prof.rx = rx; prof.mid = info.midpoint_deg;
end

function q = prefix_profile(prof, len_km)
k = find(prof.d_km <= len_km + 1e-9, 1, 'last');
q = prof;
q.d_km = prof.d_km(1:k); q.h_m = prof.h_m(1:k); q.zone = prof.zone(1:k);
% end point and midpoint along the same radial
frac = prof.d_km(k) / prof.d_km(end);
q.rx = prof.tx + frac * (prof.rx - prof.tx);
q.mid = (q.tx + q.rx) / 2;
end

function q = decimate_profile(prof, m)
% Coarser spacing (m times the original) over the same path length,
% heights interpolated linearly: a stand-in for a coarser DEM
dtot = prof.d_km(end);
step = m * (prof.d_km(2) - prof.d_km(1));
n = max(10, round(dtot / step));
q = prof;
q.d_km = linspace(0, dtot, n + 1)';
q.h_m = interp1(prof.d_km, prof.h_m, q.d_km, 'linear');
q.zone = interp1(prof.d_km, prof.zone, q.d_km, 'nearest');
end

function q = smooth_profile(prof, w)
q = prof;
q.h_m = movmean(prof.h_m, w, 'Endpoints', 'shrink');
end

function J = knife_edge_J(v)
% ITU-R P.526-15 eq. (31), valid for v > -0.78; 0 below
J = 6.9 + 20 * log10(sqrt((v - 0.1).^2 + 1) + v - 0.1);
J(v <= -0.78) = 0;
end

function c = common_class(itm_codes)
% ITM 1.2.2 codes to the P.2001 mechanism codes: 0 LOS, 1 diffraction,
% 3 troposcatter (ITM has no anomalous or sporadic-E regime)
c = NaN(size(itm_codes));
c(itm_codes == 0) = 0;
c(ismember(itm_codes, [4 5 8 9])) = 1;
c(ismember(itm_codes, [6 10])) = 3;
end

function arch = pick_archetypes(E7, f, i50)
% One link of each ITM class at the first study frequency
codes = E7.itm_mech(f, :);
len = E7.links.length_km';
L50 = E7.itm(f, :, i50);
pick = @(sel, fallback) first_or(find(sel, 1), fallback);
[~, shortest] = min(len);
arch.los = pick(codes == 0, shortest);
arch.single = pick(codes == 5, pick(ismember(codes, [5 9]), shortest));
d9 = find(ismember(codes, [8 9]));
if isempty(d9), d9 = find(ismember(codes, [4 5 8 9])); end
[~, j] = max(L50(d9));                        % the deepest double-horizon diffraction link
arch.double = d9(j);
[~, longest] = max(len);
arch.tropo = pick(ismember(codes, [6 10]), longest);
end

function k = first_or(k, fallback)
if isempty(k), k = fallback; end
end

function plot_models(ax, x, itm, p452, p2001)
plot(ax, x, itm, '-', 'Color', model_color("itm"), 'LineWidth', 1.8, 'DisplayName', 'ITM v1.4');
plot(ax, x, p452, '--', 'Color', model_color("p452"), 'LineWidth', 1.8, 'DisplayName', 'P.452-18');
plot(ax, x, p2001, '-.', 'Color', model_color("p2001"), 'LineWidth', 1.8, 'DisplayName', 'P.2001-6');
end

function mark_itm_regimes(ax, D, codes, y)
% Markers where ITM changes regime (LOS, diffraction, troposcatter)
cls = common_class(codes);
k = find(diff(cls) ~= 0) + 1;
plot(ax, D(k), y(k), 'kv', 'MarkerFaceColor', 'k', 'MarkerSize', 6, 'DisplayName', 'ITM regime change');
end

function c = model_color(m)
switch m
    case "itm", c = [0 0.447 0.698];       % blue
    case "p452", c = [0.835 0.369 0];      % vermillion
    otherwise, c = [0 0.620 0.451];        % bluish green
end
end

function s = model_label(m)
switch m
    case "itm", s = "ITM v1.4";
    case "p452", s = "P.452-18";
    otherwise, s = "P.2001-6";
end
end

function save_fig(fig, out, name)
% Light theme and white background whatever the desktop theme, for print
if exist('theme', 'file') || exist('theme', 'builtin')
    theme(fig, 'light');
end
set(fig, 'Color', 'w');
exportgraphics(fig, fullfile(out, name + ".png"), 'Resolution', 200);
close(fig);
end

function add_model_path(dir_opt, itm_root, folder, fn)
d = dir_opt;
if strlength(d) == 0
    d = fullfile(fileparts(itm_root), folder);
end
if isfolder(d)
    addpath(char(d));
end
if ~exist(fn, 'file')
    error('wp:path', '%s not found. Pass the %s folder (option %sDir).', fn, folder, extractBefore(folder + "_", "_"));
end
end

function C = commits(itm_root)
% Commit of each repository, for the paper's reproducibility note
C = struct();
repos = struct('name', {"matlab_itm", "itu_p2001", "matlab_itu_p452"}, ...
    'fn', {"itm_p2p_rev1", "p2001_rev1", "p452_p2p_rev1"});
for k = 1:numel(repos)
    d = fileparts(which(repos(k).fn));
    if ispc
        [s, o] = system(sprintf('git -C "%s" rev-parse HEAD', d));
    else                                       % time limit: git can hang on a locked repository
        [s, o] = system(sprintf('perl -e "alarm 10; exec @ARGV" git -C "%s" rev-parse HEAD', d));
    end
    C.(repos(k).name) = "unknown";
    if s == 0, C.(repos(k).name) = strtrim(string(o)); end
end
C.matlab = string(version);
end

function T = make_tables(R, F, P, i50, classes, out)
T = struct();
cc = [0 1 3];                                 % mechanism codes of the classes
% Real-terrain medians by ITM class
rows = {};
for f = 1:numel(F)
    cls = common_class(R.E7.itm_mech(f, :));
    for c = 1:3
        sel = cls == cc(c);
        d1 = R.E7.p2001(f, sel, i50) - R.E7.itm(f, sel, i50);
        d2 = R.E7.p452(f, sel, i50) - R.E7.itm(f, sel, i50);
        d3 = R.E7.p2001(f, sel, i50) - R.E7.p452(f, sel, i50);
        rows(end + 1, :) = {F(f), classes(c), nnz(sel), median(d1), median(d2), median(d3), ...
            max(abs(d1)), mean(R.E7.itm_dh(sel))}; %#ok<AGROW>
    end
end
T.real_by_class = cell2table(rows, 'VariableNames', {'freq_mhz', 'itm_class', 'links', ...
    'p2001_minus_itm_med_db', 'p452_minus_itm_med_db', 'p2001_minus_p452_med_db', 'p2001_minus_itm_maxabs_db', 'itm_delta_h_mean_m'});
writetable(T.real_by_class, fullfile(out, 'table_real_terrain_by_class.csv'));
% Low and high tails, real terrain, all links
rows = {};
for f = 1:numel(F)
    for pp = [0.01 0.1 1 10 50 90 99 99.9]
        j = find(P == pp);
        rows(end + 1, :) = {F(f), pp, median(R.E7.p2001(f, :, j) - R.E7.itm(f, :, j)), ...
            median(R.E7.p452(f, :, j) - R.E7.itm(f, :, j), 'omitnan')}; %#ok<AGROW>
    end
end
T.real_by_percentage = cell2table(rows, 'VariableNames', {'freq_mhz', 'time_pct', 'p2001_minus_itm_med_db', 'p452_minus_itm_med_db'});
writetable(T.real_by_percentage, fullfile(out, 'table_real_terrain_by_percentage.csv'));
% Knife edge: mean absolute error against J(v) for v >= 0
rows = {};
for f = 1:numel(F)
    s = R.E2.v(f, :) >= 0;
    rows(end + 1, :) = {F(f), mean(abs(R.E2.itm(f, s) - R.E2.J(f, s))), mean(abs(R.E2.p452(f, s) - R.E2.J(f, s))), ...
        mean(abs(R.E2.p2001(f, s) - R.E2.J(f, s)))}; %#ok<AGROW>
end
T.knife_edge = cell2table(rows, 'VariableNames', {'freq_mhz', 'itm_mae_db', 'p452_mae_db', 'p2001_mae_db'});
writetable(T.knife_edge, fullfile(out, 'table_knife_edge.csv'));
% Terrain resolution
chg = @(M) median(M(:, 2:3) - M(:, 1), 1);
T.resolution = table(["ITM"; "P.452"; "P.2001"], [chg(R.E3.itm); chg(R.E3.p452); chg(R.E3.p2001)], ...
    'VariableNames', {'model', 'median_change_db_90m_and_smoothed'});
writetable(T.resolution, fullfile(out, 'table_terrain_resolution.csv'));
% Archetypes at 50 %, 1 %, and the 1-99 % spread
rows = {};
for a = 1:numel(R.E5)
    for f = 1:numel(F)
        A = R.E5(a);
        j1 = find(P == 1); j99 = find(P == 99);
        rows(end + 1, :) = {A.name, A.length_km, F(f), A.itm(f, i50), A.p452(f, i50), A.p2001(f, i50), ...
            A.itm(f, j1), A.p452(f, j1), A.p2001(f, j1), A.itm(f, j99) - A.itm(f, j1), A.p2001(f, j99) - A.p2001(f, j1)}; %#ok<AGROW>
    end
end
T.archetypes = cell2table(rows, 'VariableNames', {'path', 'length_km', 'freq_mhz', 'itm_50', 'p452_50', 'p2001_50', ...
    'itm_1', 'p452_1', 'p2001_1', 'itm_spread_1_99', 'p2001_spread_1_99'});
writetable(T.archetypes, fullfile(out, 'table_archetypes.csv'));
% Smooth-earth distance to threshold
rows = {};
for f = 1:numel(F)
    for t = 1:numel(R.E8.thr)
        rows(end + 1, :) = {F(f), R.E8.thr(t), R.E8.smooth.land.itm(f, t), R.E8.smooth.land.p452(f, t), ...
            R.E8.smooth.land.p2001(f, t), R.E8.smooth.sea.itm(f, t), R.E8.smooth.sea.p452(f, t), R.E8.smooth.sea.p2001(f, t)}; %#ok<AGROW>
    end
end
T.threshold = cell2table(rows, 'VariableNames', {'freq_mhz', 'threshold_db', 'land_itm_km', 'land_p452_km', ...
    'land_p2001_km', 'sea_itm_km', 'sea_p452_km', 'sea_p2001_km'});
writetable(T.threshold, fullfile(out, 'table_distance_to_threshold.csv'));
% Real-terrain radials: the last distance where the 50 % loss is still
% below each threshold (beyond it, the loss stays above the threshold)
rows = {};
Dr = R.E8.radial.D_km;
mdl = ["itm", "p452", "p2001"];
for f = 1:numel(F)
    for t = 1:numel(R.E8.thr)
        for j = 1:numel(R.E8.radial.az)
            v = zeros(1, 3);
            for m = 1:3
                L = squeeze(R.E8.radial.(mdl(m))(j, :, f, 2));
                k = find(L < R.E8.thr(t), 1, 'last');
                if isempty(k), v(m) = 0; else, v(m) = Dr(k); end
            end
            rows(end + 1, :) = {F(f), R.E8.thr(t), R.E8.radial.az(j), v(1), v(2), v(3)}; %#ok<AGROW>
        end
    end
end
T.radial = cell2table(rows, 'VariableNames', {'freq_mhz', 'threshold_db', 'azimuth_deg', 'itm_km', 'p452_km', 'p2001_km'});
writetable(T.radial, fullfile(out, 'table_radial_distance_to_threshold.csv'));
% ITM horizon-angle flags (0x0080, 0x0100) on real terrain
fl = R.E7.itm_flags(1, :);
T.horizon_flags = table(nnz(bitand(fl, uint32(128)) | bitand(fl, uint32(256))), numel(fl), ...
    'VariableNames', {'links_with_horizon_angle_over_200_mrad', 'links'});
writetable(T.horizon_flags, fullfile(out, 'table_itm_horizon_flags.csv'));
% Elevation angles: mean absolute difference from ITM
T.elevation = table(["P.452"; "P.2001"], [mean(abs(R.E7.p452_elev - R.E7.itm_elev), 1); mean(abs(R.E7.p2001_elev - R.E7.itm_elev), 1)], ...
    'VariableNames', {'model', 'mean_abs_diff_deg_tx_rx'});
writetable(T.elevation, fullfile(out, 'table_elevation.csv'));
end
