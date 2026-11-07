classdef test_limits_rev1 < matlab.unittest.TestCase
    %TEST_LIMITS_REV1 Inputs at and beyond the limits of ITM: the model must fail loudly.
    %   Short and long paths, frequency and height limits, extreme
    %   reliabilities, a batch with one bad link, and paths near the poles.
    %   By default (validity="error"), a path outside 1 to 2000 km raises
    %   itm:validity:Distance and other NTIA warning flags raise the MATLAB
    %   warning itm:validity:Caution. NTIA's hard limits always raise
    %   itm:Invalid* errors.
    %
    %   The pole tests with terrain are tagged "Network".
    %
    %   Run: runtests('tests/test_limits_rev1.m')

    methods (TestClassSetup)
        function add_path(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end
    end

    methods (Test)
        function short_and_long_paths_raise_errors(tc)
            for d_km = [0.5 0.999 2000.5 2500]
                tc.verifyError(@() itm_p2p_rev1(30, 10, flat_profile(d_km), 2700, 50), ...
                    'itm:validity:Distance', sprintf('%g km', d_km));
            end
        end

        function distance_error_names_the_length(tc)
            try
                itm_p2p_rev1(30, 10, flat_profile(0.5), 2700, 50);
                tc.verifyFail('No error for a 0.5 km path.');
            catch err
                tc.verifySubstring(err.message, '0.5 km');
                tc.verifySubstring(err.message, 'validity="warn"');
            end
        end

        function edges_of_the_range_compute(tc)
            % 1 km and 2000 km are inside the range. Above 1000 km NTIA
            % flags the distance as near its limit, so 2000 km warns.
            L1 = itm_p2p_rev1(30, 10, flat_profile(1), 2700, 50);
            L2 = tc.verifyWarning(@() itm_p2p_rev1(30, 10, flat_profile(2000), 2700, 50), 'itm:validity:Caution');
            tc.verifyTrue(isfinite(L1) && isfinite(L2) && L2 > L1);
        end

        function warn_mode_computes_and_off_matches_ntia(tc)
            pfl = flat_profile(0.5);
            Lw = tc.verifyWarning(@() itm_p2p_rev1(30, 10, pfl, 2700, 50, validity="warn"), 'itm:validity:Distance');
            Lo = tc.verifyWarningFree(@() itm_p2p_rev1(30, 10, pfl, 2700, 50, validity="off"));
            tc.verifyEqual(Lw, Lo);
            [~, info] = itm_p2p_rev1(30, 10, pfl, 2700, 50, validity="off");
            tc.verifyTrue(bitand(info.warnings, uint32(64)) > 0, 'NTIA flag 0x0040 (path < 1 km) missing.');
        end

        function ordinary_path_is_warning_free(tc)
            tc.verifyWarningFree(@() itm_p2p_rev1(30, 10, flat_profile(50), 2700, [1 10 50 90 99]));
        end

        function frequency_limits(tc)
            pfl = flat_profile(50);
            for f = [20 30 15000 20000]          % inside 20-20000 MHz, outside 40-10000 MHz
                L = tc.verifyWarning(@() itm_p2p_rev1(30, 10, pfl, f, 50), 'itm:validity:Caution', sprintf('%g MHz', f));
                tc.verifyTrue(isfinite(L));
            end
            for f = [19.99 20000.01 0 -100]
                tc.verifyError(@() itm_p2p_rev1(30, 10, pfl, f, 50, validity="off"), 'itm:InvalidFrequency', ...
                    sprintf('%g MHz', f));
            end
        end

        function height_limits(tc)
            pfl = flat_profile(50);
            for h = [0.5 0.9 1001 3000]          % inside 0.5-3000 m, outside 1-1000 m
                tc.verifyWarning(@() itm_p2p_rev1(h, 10, pfl, 2700, 50), 'itm:validity:Caution', sprintf('TX %g m', h));
                tc.verifyWarning(@() itm_p2p_rev1(30, h, pfl, 2700, 50), 'itm:validity:Caution', sprintf('RX %g m', h));
            end
            tc.verifyError(@() itm_p2p_rev1(0.49, 10, pfl, 2700, 50), 'itm:InvalidTxHeight');
            tc.verifyError(@() itm_p2p_rev1(30, 3000.1, pfl, 2700, 50), 'itm:InvalidRxHeight');
        end

        function reliability_limits(tc)
            pfl = flat_profile(50);
            tc.verifyWarning(@() itm_p2p_rev1(30, 10, pfl, 2700, [0.01 50]), 'itm:validity:Caution');
            tc.verifyWarning(@() itm_p2p_rev1(30, 10, pfl, 2700, 99.99), 'itm:validity:Caution');
            for r = [0 100 -1 101]
                tc.verifyError(@() itm_p2p_rev1(30, 10, pfl, 2700, r), 'itm:InvalidReliability', sprintf('%g %%', r));
            end
        end

        function batch_error_names_the_bad_link(tc)
            pfls = {flat_profile(10); flat_profile(0.5); flat_profile(20); flat_profile(3000)};
            tx = [39.0 -77.0 30];
            rx = [39.1 -77.0 10; 39.0045 -77.0 10; 39.18 -77.0 10; 60 -77 10];
            try
                itm_pathloss_rev1(tx, rx, 2700, 50, pfl=pfls);
                tc.verifyFail('No error for links outside 1-2000 km.');
            catch err
                tc.verifyEqual(err.identifier, 'itm:validity:Distance');
                tc.verifySubstring(err.message, '2 of 4 links');
                tc.verifySubstring(err.message, 'link 2, 4');
            end
            L = tc.verifyWarning(@() itm_pathloss_rev1(tx, rx, 2700, 50, pfl=pfls, validity="warn"), ...
                'itm:validity:Distance');
            tc.verifySize(L, [4 1]);
            tc.verifyTrue(all(isfinite(L)));
        end

        function batch_input_error_names_the_link(tc)
            pfls = {flat_profile(10); flat_profile(20)};
            rx = [39.1 -77.0 10; 39.18 -77.0 0.4];
            try
                itm_pathloss_rev1([39 -77 30], rx, 2700, 50, pfl=pfls);
                tc.verifyFail('No error for a 0.4 m receiver.');
            catch err
                tc.verifyEqual(err.identifier, 'itm:InvalidRxHeight');
                tc.verifySubstring(err.message, 'Link 2');
            end
        end

        function north_pole_geometry(tc)
            % 11 km path across the North Pole: the midpoint is at the pole,
            % where the climate and refractivity maps must still give values
            [L, info] = itm_pathloss_rev1([89.95 0 30], [89.95 180 10], 2700, [10 50 90], ...
                pfl=flat_profile(11.1));
            tc.verifyTrue(all(isfinite(L)) && all(diff(L) > 0));
            tc.verifyGreaterThan(info.midpoint_deg(1), 89.99);
            tc.verifyTrue(ismember(info.climate, 1:7));
            tc.verifyTrue(info.N_0 >= 250 && info.N_0 <= 400);
        end

        function south_pole_geometry(tc)
            [L, info] = itm_pathloss_rev1([-89.95 0 30], [-89.95 90 10], 2700, 50, pfl=flat_profile(7.9));
            tc.verifyTrue(isfinite(L));
            tc.verifyLessThan(info.midpoint_deg(1), -89.95);
            tc.verifyTrue(ismember(info.climate, 1:7));
        end
    end

    methods (Test, TestTags = {'Network'})
        function terrain_across_north_pole(tc)
            % Arctic Ocean: no land tiles, so the profile is sea level
            [pfl, info] = itm_terrain_profile_rev1(89.95, 0, 89.95, 180);
            tc.verifyLessThan(pfl(1) * pfl(2), 12e3);
            tc.verifyTrue(all(isfinite(pfl)));
            tc.verifyTrue(all(info.source_code == 0 | info.elevation_m > -10));
        end

        function terrain_near_south_pole(tc)
            % Antarctic plateau, about 2800 m: land must come from a tile,
            % never silently from sea level
            [pfl, info] = itm_terrain_profile_rev1(-89.5, 0, -89.5, 2);
            z = pfl(3:end);
            tc.verifyTrue(all(info.source_code > 0), 'Land points without a terrain source.');
            tc.verifyTrue(all(z > 2000 & z < 3500), sprintf('Heights %.0f to %.0f m.', min(z), max(z)));
        end
    end
end

function pfl = flat_profile(d_km)
% Flat PFL of length d_km with at most 1000 intervals
np = min(1000, max(10, round(d_km * 10)));
pfl = [np; d_km * 1e3 / np; zeros(np + 1, 1)];
end
