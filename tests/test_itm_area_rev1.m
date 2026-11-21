classdef test_itm_area_rev1 < matlab.unittest.TestCase
    %TEST_ITM_AREA_REV1 Tests for itm_area_rev1, ITM v1.4 area mode.
    %   1. 2,143 cases against the NTIA C++ ITM_AREA_TLS_Ex
    %      (tests/reference/area_*): 2,000 randomized cases, 31 cases for
    %      rare branches, and 112 cases at the input limits, including every
    %      error return. Loss to 1e-9 dB; mode, warnings, and intermediate
    %      values; C++ errors raise the matching MATLAB error.
    %   2. Vector distances, siting checks, defaults, and validity handling.
    %   Run with: runtests('tests/test_itm_area_rev1.m')

    properties
        ref_dir
    end

    methods (TestClassSetup)
        function setup(tc)
            here = fileparts(mfilename('fullpath'));
            tc.ref_dir = fullfile(here, 'reference');
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(here)));
        end
    end

    methods (Test)
        function matches_cpp_reference(tc)
            C = readmatrix(fullfile(tc.ref_dir, 'area_cases.csv'));
            E = readmatrix(fullfile(tc.ref_dir, 'area_expected.csv'));
            tc.assertEqual(size(C, 1), size(E, 1));
            ids = containers.Map([1000 1001 1002 1008 1009 1010 1011 1012 1013 1014 1017 1018 1019 1020], ...
                {'itm:InvalidTxHeight', 'itm:InvalidRxHeight', 'itm:InvalidClimate', 'itm:InvalidRefractivity', ...
                'itm:InvalidFrequency', 'itm:InvalidPolarization', 'itm:InvalidEpsilon', 'itm:InvalidSigma', ...
                'itm:GroundImpedance', 'itm:InvalidMdvar', 'itm:InvalidDistance', 'itm:InvalidDeltaH', ...
                'itm:InvalidTxSiting', 'itm:InvalidRxSiting'});
            for k = 1:size(C, 1)
                msg = sprintf('area case %d', k - 1);
                if E(k, 2) >= 1000
                    tc.verifyError(@() run_case(C(k, :)), ids(E(k, 2)), msg);
                    continue
                end
                [A, info] = run_case(C(k, :));
                iv = [info.A_ref_db, info.A_fs_db, info.d_km, info.delta_h_m, info.d_hzn_m, ...
                    info.h_e_m, info.theta_hzn_rad, info.N_s];
                tc.verifyEqual(A, E(k, 4), 'RelTol', 1e-12, 'AbsTol', 1e-9, msg);
                tc.verifyEqual(info.mode, E(k, 16), msg);
                tc.verifyEqual(double(info.warnings), E(k, 3), msg);
                tc.verifyEqual(iv, E(k, 5:15), 'RelTol', 1e-9, 'AbsTol', 1e-9, msg);
            end
        end

        function vector_distance_equals_scalar(tc)
            d = [0.5 3 30 150 600];
            R = [10 50 90];
            [L, info] = itm_area_rev1(30, 10, d, 90, 2700, R, tx_siting=1, validity="off");
            tc.verifySize(L, [5 3]);
            tc.verifySize(info, [1 5]);
            for k = 1:numel(d)
                tc.verifyEqual(L(k, :), itm_area_rev1(30, 10, d(k), 90, 2700, R, tx_siting=1, validity="off"));
            end
        end

        function output_shape_follows_inputs(tc)
            L = itm_area_rev1(30, 10, 50, 90, 2700, [10; 50; 90], confidence=[10 50 90]);
            tc.verifySize(L, [3 3]);
            tc.verifyTrue(all(diff(L, 1, 1) > 0, 'all'));      % loss rises with reliability
        end

        function siting_raises_effective_height(tc)
            [~, i0] = itm_area_rev1(10, 10, 50, 200, 1000, 50);
            [~, i1] = itm_area_rev1(10, 10, 50, 200, 1000, 50, tx_siting=1);
            [~, i2] = itm_area_rev1(10, 10, 50, 200, 1000, 50, tx_siting=2);
            tc.verifyEqual(i0.h_e_m(1), 10);
            tc.verifyGreaterThan(i1.h_e_m(1), i0.h_e_m(1));
            tc.verifyGreaterThan(i2.h_e_m(1), i1.h_e_m(1));
            tc.verifyEqual(i2.h_e_m(2), 10);
        end

        function non_integer_siting_rejected(tc)
            % The C++ takes int siting (1.5 would truncate to 1); this port
            % rejects it, as it rejects non-integer climate and mdvar.
            tc.verifyError(@() itm_area_rev1(30, 10, 50, 90, 2700, 50, tx_siting=1.5), 'itm:InvalidTxSiting');
            tc.verifyError(@() itm_area_rev1(30, 10, 50, 90, 2700, 50, rx_siting=0.5), 'itm:InvalidRxSiting');
        end

        function default_mdvar_matches_13_at_location_50(tc)
            R = [1 10 50 90 99];
            L3 = itm_area_rev1(30, 10, 80, 90, 2700, R);
            L13 = itm_area_rev1(30, 10, 80, 90, 2700, R, mdvar=13);
            tc.verifyEqual(L3, L13, 'AbsTol', 1e-5);
            Lloc = itm_area_rev1(30, 10, 80, 90, 2700, 50, location=90);
            tc.verifyGreaterThan(Lloc, L3(3));                 % mdvar 3 keeps location variability
            tc.verifyEqual(itm_area_rev1(30, 10, 80, 90, 2700, 50, location=90, mdvar=13), ...
                L13(3), 'AbsTol', 1e-5);                       % mdvar 13 ignores it
        end

        function validity_distance(tc)
            tc.verifyError(@() itm_area_rev1(30, 10, 0.5, 90, 2700, 50), 'itm:validity:Distance');
            tc.verifyWarning(@() itm_area_rev1(30, 10, 0.5, 90, 2700, 50, validity="warn"), 'itm:validity:Distance');
            L = itm_area_rev1(30, 10, 0.5, 90, 2700, 50, validity="off");
            tc.verifyTrue(isfinite(L));
        end

        function point_to_point_unchanged(tc)
            % The area branch shares the core; a flat point-to-point path
            % still gives the NTIA C++ value from the point-to-point tests.
            C = readmatrix(fullfile(tc.ref_dir, 'rand_cases.csv'));
            E = readmatrix(fullfile(tc.ref_dir, 'rand_expected.csv'));
            L = readlines(fullfile(tc.ref_dir, 'rand_pfls.csv'));
            c = C(1, :);
            p = str2double(split(L(c(13) + 1), ','));
            A = itm_p2p_rev1(c(1), c(2), p, c(5), c(10), 'confidence', c(12), 'location', c(11), ...
                'climate', c(3), 'N_0', c(4), 'polarization', c(6), 'epsilon', c(7), 'sigma', c(8), ...
                'mdvar', c(9), 'validity', 'off');
            tc.verifyEqual(A, E(1, 4), 'RelTol', 1e-12);
        end
    end
end

function [A, info] = run_case(c)
% c: h_tx,h_rx,tx_siting,rx_siting,d_km,delta_h,climate,N_0,f,pol,eps,sigma,mdvar,time,location,situation
% TLS mapping: reliability = time, confidence = situation
[A, info] = itm_area_rev1(c(1), c(2), c(5), c(6), c(9), c(14), 'confidence', c(16), 'location', c(15), ...
    'tx_siting', c(3), 'rx_siting', c(4), 'climate', c(7), 'N_0', c(8), 'polarization', c(10), ...
    'epsilon', c(11), 'sigma', c(12), 'mdvar', c(13), 'validity', 'off');
end
