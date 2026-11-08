function remaining_terms_rev1(options)
%REMAINING_TERMS_REV1 Gases, rain, sporadic-E, polarization, and ground for ITM and P.2001.
%   REMAINING_TERMS_REV1() runs plan items 18 and 19 of the working paper
%   (ALGORITHM_COMPARISON_PLAN.md) on smooth earth in central Kansas
%   (38.5 N, 100.0 W, due east), 30 m and 10 m antennas.
%
%   Item 18, gases, rain, and sporadic-E. P.2001's explicit terms against
%   frequency, 0.1 GHz to 50 GHz, at 50 km, 150 km, and 300 km and at 50 %,
%   1 %, and 0.01 % of time, 500 m above sea level, vertical polarization:
%     gaseous absorption on the surface path A_gsur (Attachment F.2, in
%     sub-models 1 and 2) and on the troposcatter path A_gs (F.3, in
%     sub-model 3);
%     A_1, the combined clear-air fading and precipitation term of
%     sub-model 1 (Attachments B and C), and A_2, the precipitation term of
%     sub-model 3 (C);
%     the sporadic-E effect: the combined loss without sub-model 4
%     (eq. 59 with L_bm12 and L_bm3 only) minus the combined loss.
%   ITM has none of these terms explicitly; its loss is kept from 0.1 GHz
%   to 20 GHz (its stated range) for context.
%     chart_data/rem_terms_frequency.csv
%
%   Item 19, polarization and ground. Loss with vertical minus horizontal
%   polarization, 1 km to 150 km, at 0.1, 0.3, 1, and 3 GHz and 50 % of
%   time. ITM with three grounds: P.2001's land constants (relative
%   permittivity 22, conductivity 0.003 S/m), dry ground (4, 0.001 S/m),
%   and sea water (80, 5 S/m). P.2001 sets its ground constants itself from
%   the radio-climatic zone (Table 2): an inland path (zone 4) and a sea
%   path (zone 1). Land paths 500 m above sea level; sea paths at 0 m.
%     chart_data/rem_polarization.csv
%
%   Options: OutDir, P2001Dir, P452Dir, Items ([18 19]).

arguments
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Items (1,:) double = [18 19]
end
wp_setup(options.P2001Dir, options.P452Dir);
E = wgs84Ellipsoid('km'); tx0 = [38.5, -100.0]; htx = 30; hrx = 10;

% ---- item 18 ----
if ismember(18, options.Items)
    F = [0.1 0.2 0.3 0.5 1 2 3 5 7 10 15 20 25 30 40 50]; P = [50 1 0.01];
    rows = {};
    for d = [50 150 300]
        [pfl, dk, hm, rxp] = flat(d, 500, tx0, E);
        for f = F
            o = p2001_profile_rev1(dk, hm, 4 * ones(size(dk)), f, P(:), tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, ...
                'Validity', "off");
            Li = NaN(size(P));
            if f <= 20
                Li = itm_p2p_rev1(htx, hrx, pfl, 1000 * f, P, climate=5, N_0=301, validity="off");
            end
            for j = 1:numel(P)
                q = o(j);
                lbm12 = -10 * log10(10.^(-0.1 * q.Lbm1) + 10.^(-0.1 * q.Lbm2));
                lb_no4 = -5 * log10(10.^(-0.2 * lbm12) + 10.^(-0.2 * q.Lbm3));
                rows(end + 1, :) = {d, f, P(j), q.Lbfs, q.Lb, q.Lbm1, q.Lbm2, q.Lbm3, q.Lbm4, q.Agsur, q.Ags, ...
                    q.A1, q.A2, lb_no4 - q.Lb, Li(j)}; %#ok<AGROW>
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'d_km', 'freq_ghz', 'time_pct', 'fs_db', 'p2001_db', 'lbm1_db', ...
        'lbm2_db', 'lbm3_db', 'lbm4_db', 'agsur_db', 'ags_db', 'a1_db', 'a2_db', 'sporadic_e_effect_db', 'itm_db'}), ...
        fullfile(options.OutDir, 'rem_terms_frequency.csv'));
end

% ---- item 19 ----
if ismember(19, options.Items)
    grounds = {"P.2001 land", 22, 0.003, 500; "dry ground", 4, 0.001, 500; "sea water", 80, 5, 0};
    rows = {};
    for f = [0.1 0.3 1 3]
        for d = 1:1:150
            for g = 1:size(grounds, 1)
                [pfl, ~, ~, ~] = flat(d, grounds{g, 4}, tx0, E);
                Lv = itm_p2p_rev1(htx, hrx, pfl, 1000 * f, 50, climate=5, N_0=301, polarization=1, ...
                    epsilon=grounds{g, 2}, sigma=grounds{g, 3}, validity="off");
                Lh = itm_p2p_rev1(htx, hrx, pfl, 1000 * f, 50, climate=5, N_0=301, polarization=0, ...
                    epsilon=grounds{g, 2}, sigma=grounds{g, 3}, validity="off");
                rows(end + 1, :) = {"ITM", grounds{g, 1}, f, d, Lv, Lh}; %#ok<AGROW>
            end
            for zn = [4 1]
                h0 = 500 * (zn == 4);
                [~, dk, hm, rxp] = flat(d, h0, tx0, E);
                ov = p2001_profile_rev1(dk, hm, zn * ones(size(dk)), f, 50, tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, ...
                    'Polarization', "vertical", 'Validity', "off");
                oh = p2001_profile_rev1(dk, hm, zn * ones(size(dk)), f, 50, tx0(1), tx0(2), rxp(1), rxp(2), htx, hrx, ...
                    'Polarization', "horizontal", 'Validity', "off");
                nm = "P.2001 land"; if zn == 1, nm = "sea water"; end
                rows(end + 1, :) = {"P.2001", nm, f, d, ov.Lb, oh.Lb}; %#ok<AGROW>
            end
        end
    end
    writetable(cell2table(rows, 'VariableNames', {'model', 'ground', 'freq_ghz', 'd_km', 'vertical_db', 'horizontal_db'}), ...
        fullfile(options.OutDir, 'rem_polarization.csv'));
end
end

%% ------------------------------------------------------------------------
function [pfl, dk, hm, rxp] = flat(d, h0, tx, E)
n = max(10, round(d / 0.1));
dk = linspace(0, d, n + 1)'; hm = h0 * ones(n + 1, 1);
pfl = [n; 1000 * d / n; hm];
[la, lo] = reckon(tx(1), tx(2), d, 90, E);
rxp = [la, lo];
end
