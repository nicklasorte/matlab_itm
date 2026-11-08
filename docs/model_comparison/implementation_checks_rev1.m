function implementation_checks_rev1(options)
%IMPLEMENTATION_CHECKS_REV1 Inputs, swaps, reciprocity, and continuity for ITM and P.2001.
%   IMPLEMENTATION_CHECKS_REV1() runs plan items 2, 3, 22, 26, and 27 of the
%   working paper (ALGORITHM_COMPARISON_PLAN.md) at options.Freq (3000 MHz)
%   and 50 % of time. Real links are the paper's 60 eastern and 60 western
%   links, run as wp_run3 runs them (radio climate and N_0 from ITU maps at
%   the midpoint for ITM; P.2001 with its own maps; vertical polarization).
%
%   Items 2 and 3, inputs. For each link: ITM's terrain irregularity Δh and
%   effective antenna heights h_e (itm_p2p_rev1 info), and P.2001's
%   roughness h_m and effective heights for diffraction, h_tep and h_rep,
%   and for ducting, h_tea and h_rea (sec. 3.8), with both losses.
%     chart_data/check_inputs.csv
%
%   Item 22, earth-radius swap. Each model is run again with the other's
%   median effective earth radius: ITM with P.2001's a_e50, and P.2001 with
%   ITM's a_e (a_e50 and a_p both set, so at 50 % of time). The released
%   functions are not changed: the script copies itm_p2p_rev1 with its
%   private folder, and p2001_profile_rev1 with its private folder, into a
%   temporary folder, and inserts one line in each copy that replaces the
%   computed radius when the environment variable WP_AE_OVERRIDE_KM is set.
%     chart_data/check_radius_swap.csv
%
%   Item 26, reciprocity. Each link run again with the terminals swapped
%   (profile reversed, heights and coordinates exchanged).
%     chart_data/check_reciprocity.csv
%
%   Item 27, continuity. Loss against distance at 100 m steps: smooth earth
%   (500 m above sea level, central Kansas, due east) from 1 km to 300 km,
%   and the paper's eastward real-terrain radial from 38.90 N, 77.45 W to
%   150 km (prefixes of one profile), 30 m and 10 m antennas, with ITM's
%   mode and region boundaries and P.2001's dominant mechanism and
%   line-of-sight flag at each step.
%     chart_data/check_continuity.csv
%
%   Options: Freq (3000), OutDir, P2001Dir, P452Dir, Items ([2 22 26 27];
%   2 also covers item 3).

arguments
    options.Freq (1,1) double = 3000
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Items (1,:) double = [2 22 26 27]
end
here = fileparts(mfilename('fullpath'));
itm_root = wp_setup(options.P2001Dir, options.P452Dir);
f = options.Freq; ghz = f / 1000; E = wgs84Ellipsoid('km');

% ---- the 120 links ----
if any(ismember([2 22 26], options.Items))
    s = load(fullfile(here, 'figures', 'wp_results_rev1.mat'), 'R');
    sets = {"East", s.R.E7.links; "West", readtable(fullfile(options.OutDir, 'western_links.csv'), 'TextType', 'string')};
    if ismember(22, options.Items)
        swapdir = make_swap_copies(itm_root, which('p2001_profile_rev1'));
        addpath(swapdir);
        cleanup = onCleanup(@() rmpath(swapdir)); %#ok<NASGU>
    end
    ri = {}; rs = {}; rr = {};
    for g = 1:2
        L = sets{g, 2};
        for k = 1:height(L)
            prof = wp_terrain_profile([L.tx_lat(k) L.tx_lon(k)], [L.rx_lat(k) L.rx_lon(k)]);
            ht = L.tx_h_m(k); hr = L.rx_h_m(k);
            [b, info, o] = run_link(prof, ht, hr, f, ghz, @itm_p2p_rev1, @p2001_profile_rev1);
            if ismember(2, options.Items)
                ri(end + 1, :) = {sets{g, 1}, k, prof.d_km(end), b.itm, b.p2001, b.fs, info.mode_code, info.delta_h_m, ...
                    info.h_e_m(1), info.h_e_m(2), ht, hr, o.Hm, o.Htep, o.Hrep, o.Htea, o.Hrea, o.Lb, o.FlagLos50}; %#ok<AGROW>
            end
            if ismember(22, options.Items)
                ae_itm = info.lines.a_e_m / 1e3; ae_p = o.Reff50;
                setenv('WP_AE_OVERRIDE_KM', sprintf('%.6f', ae_p));
                bi = run_link(prof, ht, hr, f, ghz, @itm_p2p_ae_rev1, []);
                setenv('WP_AE_OVERRIDE_KM', sprintf('%.6f', ae_itm));
                bp = run_link(prof, ht, hr, f, ghz, [], @p2001_profile_ae_rev1);
                setenv('WP_AE_OVERRIDE_KM', '');
                rs(end + 1, :) = {sets{g, 1}, k, prof.d_km(end), info.mode_code, ae_itm, ae_p, b.itm, b.p2001, ...
                    bi.itm, bp.p2001, b.fs}; %#ok<AGROW>
            end
            if ismember(26, options.Items)
                pr = prof;
                pr.d_km = prof.d_km(end) - flipud(prof.d_km(:)); pr.h_m = flipud(prof.h_m(:)); pr.zone = flipud(prof.zone(:));
                pr.tx = prof.rx; pr.rx = prof.tx;
                br = run_link(pr, hr, ht, f, ghz, @itm_p2p_rev1, @p2001_profile_rev1);
                rr(end + 1, :) = {sets{g, 1}, k, prof.d_km(end), info.mode_code, b.itm, br.itm, b.p2001, br.p2001}; %#ok<AGROW>
            end
        end
        fprintf('links %s done\n', sets{g, 1});
    end
    if ismember(2, options.Items)
        writetable(cell2table(ri, 'VariableNames', {'side', 'link', 'd_km', 'itm_db', 'p2001_db', 'fs_db', 'itm_mode_code', ...
            'itm_delta_h_m', 'itm_he_tx_m', 'itm_he_rx_m', 'h_tx_m', 'h_rx_m', 'p2001_hm_m', 'p2001_htep_m', 'p2001_hrep_m', ...
            'p2001_htea_m', 'p2001_hrea_m', 'p2001_lb_db', 'p2001_los50'}), fullfile(options.OutDir, 'check_inputs.csv'));
    end
    if ismember(22, options.Items)
        writetable(cell2table(rs, 'VariableNames', {'side', 'link', 'd_km', 'itm_mode_code', 'itm_ae_km', 'p2001_ae50_km', ...
            'itm_db', 'p2001_db', 'itm_at_p2001_ae_db', 'p2001_at_itm_ae_db', 'fs_db'}), fullfile(options.OutDir, 'check_radius_swap.csv'));
    end
    if ismember(26, options.Items)
        writetable(cell2table(rr, 'VariableNames', {'side', 'link', 'd_km', 'itm_mode_code', 'itm_db', 'itm_reversed_db', ...
            'p2001_db', 'p2001_reversed_db'}), fullfile(options.OutDir, 'check_reciprocity.csv'));
    end
end

% ---- item 27: continuity ----
if ismember(27, options.Items)
    rows = {};
    tx0 = [38.5, -100.0]; htx = 30; hrx = 10; h0 = 500;
    for d = 1:0.1:300
        n = max(10, round(d / 0.03)); dk = linspace(0, d, n + 1)'; hm = h0 * ones(n + 1, 1);
        [la, lo] = reckon(tx0(1), tx0(2), d, 90, E);
        rows(end + 1, :) = cont_row("smooth earth", dk, hm, 4 * ones(n + 1, 1), tx0, [la lo], htx, hrx, f, ghz); %#ok<AGROW>
    end
    site = [38.90 -77.45];
    [la, lo] = reckon(site(1), site(2), 150, 90, E);
    P = wp_terrain_profile(site, [la lo]);
    step = mean(diff(P.d_km));
    for d = 1:0.1:150
        m = round(d / step) + 1;
        dk = P.d_km(1:m); hm = P.h_m(1:m); z = P.zone(1:m);
        [la2, lo2] = reckon(site(1), site(2), dk(end), 90, E);
        rows(end + 1, :) = cont_row("Piedmont radial, east", dk(:), hm(:), z(:), site, [la2 lo2], htx, hrx, f, ghz); %#ok<AGROW>
    end
    writetable(cell2table(rows, 'VariableNames', {'path', 'd_km', 'itm_db', 'p2001_db', 'fs_db', 'itm_mode', 'itm_d_sml_km', ...
        'itm_d_x_km', 'itm_d_l_km', 'p2001_mech', 'p2001_los50'}), fullfile(options.OutDir, 'check_continuity.csv'));
end
end

%% ------------------------------------------------------------------------
function [b, info, o] = run_link(prof, ht, hr, f, ghz, itmfun, p2fun)
b = struct('itm', NaN, 'p2001', NaN, 'fs', NaN); info = []; o = [];
pfl = [numel(prof.d_km) - 1; prof.d_km(end) * 1e3 / (numel(prof.d_km) - 1); prof.h_m(:)];
if ~isempty(itmfun)
    mid = prof.mid;
    c = itm_radio_climate_rev1(mid(1), mid(2));
    if c == 7, c = min(itm_radio_climate_rev1(prof.tx(1), prof.tx(2)), itm_radio_climate_rev1(prof.rx(1), prof.rx(2))); end
    n0 = itm_surface_refractivity_rev1(mid(1), mid(2));
    [b.itm, info] = itmfun(ht, hr, pfl, f, 50, climate=c, N_0=n0, validity="off");
    b.fs = info.A_fs_db;
end
if ~isempty(p2fun)
    o = p2fun(prof.d_km(:), prof.h_m(:), prof.zone(:), ghz, 50, prof.tx(1), prof.tx(2), prof.rx(1), prof.rx(2), ht, hr, ...
        'Validity', "off");
    b.p2001 = o.Lb;
end
end

function r = cont_row(name, dk, hm, z, tx, rx, ht, hr, f, ghz)
n = numel(dk) - 1;
pfl = [n; 1000 * dk(end) / n; hm(:)];
[L, info] = itm_p2p_rev1(ht, hr, pfl, f, 50, climate=5, N_0=301, validity="off");
o = p2001_profile_rev1(dk(:), hm(:), z(:), ghz, 50, tx(1), tx(2), rx(1), rx(2), ht, hr, 'Validity', "off");
[~, i] = min([o.Lbm1, o.Lbm2, o.Lbm3, o.Lbm4]);
mech = i; if i == 1 && o.FlagLos50 == 1, mech = 0; end
r = {name, dk(end), L, o.Lb, info.A_fs_db, info.mode, info.lines.d_sML_m / 1e3, info.lines.d_x_m / 1e3, ...
    sum(info.d_hzn_m) / 1e3, mech, o.FlagLos50};
end

function d = make_swap_copies(itm_root, p2001_file)
% Temporary copies of the two models with a radius override; see the help.
d = fullfile(tempdir, 'wp_radius_swap');
if isfolder(d), rmdir(d, 's'); end
mkdir(d);
% ITM: itm_p2p_rev1 -> itm_p2p_ae_rev1, with the same private folder
mkdir(fullfile(d, 'itm')); copyfile(fullfile(itm_root, 'private'), fullfile(d, 'itm', 'private'));
txt = fileread(fullfile(itm_root, 'itm_p2p_rev1.m'));
txt = strrep(txt, 'function [A_db, info] = itm_p2p_rev1(', 'function [A_db, info] = itm_p2p_ae_rev1(');
write(fullfile(d, 'itm', 'itm_p2p_ae_rev1.m'), txt);
core = fullfile(d, 'itm', 'private', 'itm_p2p_core.m');
txt = fileread(core);
key = sprintf('[Z_g, gamma_e, N_s] = initialize_point_to_point(f_mhz, h_sys_m, N_0, ...\n    polarization, epsilon, sigma);');
assert(contains(txt, key), 'wp:swap:itm', 'ITM core changed; update the override insertion point.');
txt = strrep(txt, key, [key newline 'ov_ = str2double(getenv(''WP_AE_OVERRIDE_KM'')); if isfinite(ov_) && ov_ > 0, gamma_e = 1 / (1e3 * ov_); end']);
write(core, txt);
% P.2001: p2001_profile_rev1 -> p2001_profile_ae_rev1, with the same private folder
src = fileparts(p2001_file);
mkdir(fullfile(d, 'p2001')); copyfile(fullfile(src, 'private'), fullfile(d, 'p2001', 'private'));
txt = fileread(p2001_file);
txt = strrep(txt, 'function out = p2001_profile_rev1(', 'function out = p2001_profile_ae_rev1(');
key = 'Reffp(Cp <= 1e-6) = 1e6;';
assert(contains(txt, key), 'wp:swap:p2001', 'P.2001 code changed; update the override insertion point.');
txt = strrep(txt, key, [key newline 'ov_ = str2double(getenv(''WP_AE_OVERRIDE_KM'')); if isfinite(ov_) && ov_ > 0, Reff50 = ov_; Cp(:) = 1 / ov_; Reffp(:) = ov_; end']);
write(fullfile(d, 'p2001', 'p2001_profile_ae_rev1.m'), txt);
d = {fullfile(d, 'itm'), fullfile(d, 'p2001')};
d = strjoin(d, pathsep);
end

function write(file, txt)
fid = fopen(file, 'w'); fwrite(fid, txt); fclose(fid);
end
