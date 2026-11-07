classdef test_mechanism_rev1 < matlab.unittest.TestCase
    %TEST_MECHANISM_REV1 The SEADLib drop-in (itm_p2p_mechanism_rev1) and the ITM 1.2.2 mode codes.
    %   Tag "Network": downloads terrain tiles on the first run.
    %
    %   Run: runtests('tests/test_mechanism_rev1.m')

    properties (Constant)
        bs = [38.90 -77.03 30; 38.95 -76.90 25; 39.20 -76.70 40]
        rx = [39.0458 -76.6413 10]
        rel = [1 10 50 90 99]
    end

    methods (TestClassSetup)
        function add_path(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end
    end

    methods (Test)
        function mode_codes_follow_itm_122(tc)
            % Flat 10 km, tall masts: line of sight (0). Flat 80 km, short
            % masts: beyond both horizons, so double horizon (9 or 10).
            [~, info] = itm_p2p_rev1(100, 100, [100; 100; zeros(101, 1)], 2700, 50);
            tc.verifyEqual(info.mode_code, 0);
            [~, info] = itm_p2p_rev1(10, 10, [800; 100; zeros(801, 1)], 2700, 50);
            tc.verifyTrue(ismember(info.mode_code, [9 10]), sprintf('mode_code %d', info.mode_code));
            tc.verifyEqual(info.mode_code == 10, info.mode == 3, 'Troposcatter codes disagree.');
        end

        function single_horizon_code(tc)
            % A ridge near the receiver hides it from a tall transmitter on
            % a plain: one horizon is the other antenna's, so 4 + mode
            z = zeros(301, 1);
            z(280) = 120;
            [~, info] = itm_p2p_rev1(200, 5, [300; 100; z], 2700, 50, validity="off");
            tc.verifyTrue(ismember(info.mode_code, [0 5 6 9 10]));
        end
    end

    methods (Test, TestTags = {'Network'})
        function matches_itm_pathloss_with_endpoint_climate(tc)
            [L, mode, elev, msg] = itm_p2p_mechanism_rev1(tc.bs, tc.rx, tc.rel, 50, 3550, 1);
            [L2, info, elev2, mode2] = itm_pathloss_rev1(tc.bs, tc.rx, 3550, tc.rel, climate_rule="endpoints");
            tc.verifySize(L, [3 5]);
            tc.verifyEqual(L, L2);
            tc.verifyEqual(mode, mode2);
            tc.verifyEqual(elev, elev2);
            tc.verifyEqual(msg, strings(3, 1));
            tc.verifyTrue(all(ismember(mode, [0 5 6 9 10])));
            c_tx = itm_radio_climate_rev1(tc.bs(:, 1), tc.bs(:, 2));
            c_rx = itm_radio_climate_rev1(tc.rx(1), tc.rx(2));
            tc.verifyEqual([info.climate]', min(c_tx, c_rx));
        end

        function one_link_returns_a_row(tc)
            L = itm_p2p_mechanism_rev1(tc.bs(1, :), tc.rx, tc.rel', 50, 3550, 0);
            tc.verifySize(L, [1 5]);
        end

        function failures_are_loud_or_nan(tc)
            bs = [tc.bs; tc.rx(1) + 0.004, tc.rx(2), 30];      % 0.45 km link
            tc.verifyError(@() itm_p2p_mechanism_rev1(bs, tc.rx, tc.rel, 50, 3550, 1), 'itm:validity:Distance');
            [L, mode, ~, msg] = tc.verifyWarning(@() itm_p2p_mechanism_rev1(bs, tc.rx, tc.rel, 50, 3550, 1, ...
                OnError="nan"), 'itm:mechanism:Failed');
            tc.verifyTrue(all(isnan(L(4, :))) && isnan(mode(4)));
            tc.verifySubstring(msg(4), 'itm:validity:Distance');
            tc.verifyTrue(all(isfinite(L(1:3, :)), 'all'));
            tc.verifyEqual(msg(1:3), strings(3, 1));
        end
    end
end
