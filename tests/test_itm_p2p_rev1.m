classdef test_itm_p2p_rev1 < matlab.unittest.TestCase
    %TEST_ITM_P2P_REV1 Verifies the ITM core against NTIA reference results.
    %   1. NTIA's published command-line example (pfl.txt) and its
    %      reliability-by-confidence table.
    %   2. NTIA's p2p.csv / pfls.csv test cases.
    %   3. 740 randomized cases (155 profiles, all mdvar values, all three
    %      propagation modes) with expected values from the NTIA C++ ITM
    %      v1.4 built from https://github.com/NTIA/itm. Regenerate with
    %      tests/reference/generator (see the README there).
    %   4. Vectorization, output shape, monotonicity, and error handling.
    %
    %   Run: runtests('tests/test_itm_p2p_rev1.m')

    properties
        ref_dir
        cases
        expected
        profiles
    end

    methods (TestClassSetup)
        function load_reference(tc)
            here = fileparts(mfilename('fullpath'));
            addpath(fileparts(here));
            tc.ref_dir = fullfile(here, 'reference');
            tc.cases = readmatrix(fullfile(tc.ref_dir, 'rand_cases.csv'));
            tc.expected = readmatrix(fullfile(tc.ref_dir, 'rand_expected.csv'));
            tc.profiles = read_profiles(fullfile(tc.ref_dir, 'rand_pfls.csv'));
        end
    end

    methods (Test)
        function ntia_published_example(tc)
            % cmd_examples/o_p2pcr.txt and o_p2pcr_tbl.txt (ITMDrvr v1.4.0)
            pfl = read_ntia_pfl(fullfile(tc.ref_dir, 'ntia_example_pfl.txt'));
            args = {'climate', 5, 'N_0', 301, 'polarization', 1, 'epsilon', 15, 'sigma', 0.005, 'mdvar', 1};
            [L, info] = itm_p2p_rev1(15, 3, pfl, 3500, [10; 65; 90], 'confidence', [10 60 90], args{:});
            published = [110.9 117.2 129.1; 110.9 117.4 129.2; 110.9 117.5 129.3];
            tc.verifyEqual(round(L, 1), published);
            [L50, i50] = itm_p2p_rev1(15, 3, pfl, 3500, 50, args{:});
            tc.verifyEqual(round(L50, 1), 114.5);
            tc.verifyEqual(round(i50.d_km, 3), 3.635);
            tc.verifyEqual(round(1000 * i50.theta_hzn_rad, 3), [-1.949 -0.856]);
            tc.verifyEqual(round(i50.d_hzn_m), [14868 6494]);
            tc.verifyEqual(round(i50.h_e_m, 1), [15.0 3.0]);
            tc.verifyEqual(round(i50.N_s, 1), 251.5);
            tc.verifyEqual(round(i50.delta_h_m, 1), 3.2);
            tc.verifyEqual(i50.mode, 1);
            tc.verifyEqual(info.warnings, zeros(3, 'uint32'));
        end

        function ntia_p2p_csv(tc)
            % NTIA p2p.csv: TLS inputs and published A__db (2 decimals)
            T = readtable(fullfile(tc.ref_dir, 'ntia_p2p.csv'));
            P = read_profiles(fullfile(tc.ref_dir, 'ntia_pfls.csv'));
            for k = 1:height(T)
                r = T(k, :);
                A = itm_p2p_rev1(r.h_tx__meter, r.h_rx__meter, P{k}, r.f__mhz, r.time, ...
                    'confidence', r.situation, 'location', r.location, 'climate', r.climate, ...
                    'N_0', r.N_0, 'polarization', r.pol, 'epsilon', r.epsilon, 'sigma', r.sigma, ...
                    'mdvar', r.mdvar, 'validity', 'off');
                tc.verifyEqual(A, r.A__db, 'AbsTol', 0.005, sprintf('p2p.csv row %d', k));
            end
        end

        function matches_cpp_reference(tc)
            C = tc.cases;
            E = tc.expected;
            n = size(C, 1);
            A = zeros(n, 1); W = zeros(n, 1); M = zeros(n, 1); IV = zeros(n, 11);
            for k = 1:n
                [A(k), info] = run_case(C(k, :), tc.profiles);
                W(k) = double(info.warnings);
                M(k) = info.mode;
                IV(k, :) = [info.A_ref_db, info.A_fs_db, info.d_km, info.delta_h_m, info.d_hzn_m, ...
                    info.h_e_m, info.theta_hzn_rad, info.N_s];
            end
            tc.verifyEqual(A, E(:, 4), 'AbsTol', 1e-9, 'Basic transmission loss vs C++');
            tc.verifyEqual(M, E(:, 16), 'Propagation mode vs C++');
            tc.verifyEqual(W, E(:, 3), 'Warning flags vs C++');
            tc.verifyEqual(IV, E(:, 5:15), 'RelTol', 1e-9, 'AbsTol', 1e-9, 'Intermediate values vs C++');
        end

        function reliability_vector_equals_scalar(tc)
            % Sweep rows share inputs except time; one vector call must
            % equal both the scalar calls and the C++ results.
            C = tc.cases;
            key = C(:, [1:9 11 12 13]);
            [g, ~, idx] = unique(key, 'rows', 'stable');
            groups = find(accumarray(idx, 1) >= 5);
            tc.assertGreaterThanOrEqual(numel(groups), 20);
            for gi = groups'
                rows = find(idx == gi);
                c = C(rows(1), :);
                rel = C(rows, 10);
                Lv = itm_p2p_rev1(c(1), c(2), tc.profiles{c(13) + 1}, c(5), rel, ...
                    'confidence', c(12), 'location', c(11), 'climate', c(3), 'N_0', c(4), ...
                    'polarization', c(6), 'epsilon', c(7), 'sigma', c(8), 'mdvar', c(9), 'validity', 'off');
                Ls = arrayfun(@(r) run_case(C(r, :), tc.profiles), rows);
                tc.verifyEqual(Lv, Ls, 'AbsTol', 1e-12);
                tc.verifyEqual(Lv, tc.expected(rows, 4), 'AbsTol', 1e-9);
            end
            tc.verifyNotEmpty(g);
        end

        function output_shape_follows_inputs(tc)
            pfl = flat_profile(20e3, 100);
            rel = [1 10 50 90 99];
            tc.verifySize(itm_p2p_rev1(30, 10, pfl, 2700, rel), [1 5]);
            tc.verifySize(itm_p2p_rev1(30, 10, pfl, 2700, rel'), [5 1]);
            tc.verifySize(itm_p2p_rev1(30, 10, pfl, 2700, reshape(1:12, 3, 4) * 8), [3 4]);
            T = itm_p2p_rev1(30, 10, pfl, 2700, rel', 'confidence', [10 50 90], 'mdvar', 3);
            tc.verifySize(T, [5 3]);
            for j = 1:3
                tc.verifyEqual(T(:, j), itm_p2p_rev1(30, 10, pfl, 2700, rel', ...
                    'confidence', 50 + 40 * (j - 2), 'mdvar', 3), 'AbsTol', 1e-12);
            end
            tc.verifyError(@() itm_p2p_rev1(30, 10, pfl, 2700, [1 2 3], 'confidence', [1 2]), ...
                'itm:SizeMismatch');
        end

        function large_reliability_array(tc)
            % 100,000 Monte Carlo reliabilities in one call equal the
            % scalar calls, for every mode of variability
            rs = RandStream('mrg32k3a', 'Seed', 11);
            rel = 0.001 + 99.998 * rand(rs, 1e5, 1);
            pick = randperm(rs, 1e5, 25);
            c = tc.cases(500, :);
            pfl = tc.profiles{c(13) + 1};
            for mdvar = [0 1 2 3 13 23 33]
                L = itm_p2p_rev1(c(1), c(2), pfl, c(5), rel, climate=c(3), N_0=c(4), mdvar=mdvar, validity="off");
                tc.verifySize(L, size(rel));
                for k = pick
                    tc.verifyEqual(L(k), itm_p2p_rev1(c(1), c(2), pfl, c(5), rel(k), climate=c(3), ...
                        N_0=c(4), mdvar=mdvar, validity="off"), 'AbsTol', 1e-12, sprintf('mdvar %d, element %d', mdvar, k));
                end
            end
        end

        function single_message_mode_fills_output(tc)
            % mdvar 0 ignores time: a reliability array still returns one
            % value per element (all equal), not a scalar
            pfl = flat_profile(20e3, 100);
            L = itm_p2p_rev1(30, 10, pfl, 2700, [1 10 50 90 99], mdvar=0);
            tc.verifySize(L, [1 5]);
            tc.verifyEqual(L, repmat(L(1), 1, 5));
            [~, info] = itm_p2p_rev1(30, 10, pfl, 2700, [1 10 50 90 99], mdvar=0);
            tc.verifySize(info.warnings, [1 5]);
        end

        function loss_increases_with_reliability(tc)
            % Higher reliability means a loss exceeded less often: larger.
            rel = [0.1 1 5 10 30 50 70 90 95 99 99.9];
            for k = 1:3:size(tc.cases, 1)
                c = tc.cases(k, :);
                L = itm_p2p_rev1(c(1), c(2), tc.profiles{c(13) + 1}, c(5), rel, ...
                    'climate', c(3), 'N_0', c(4), 'polarization', c(6), 'epsilon', c(7), ...
                    'sigma', c(8), 'mdvar', 13, 'validity', 'off');
                tc.verifyGreaterThanOrEqual(diff(L), -1e-9, sprintf('case %d', k));
            end
        end

        function line_of_sight_near_free_space(tc)
            % Short, high, flat path: median loss within a few dB of FSPL
            pfl = flat_profile(2e3, 20);
            [L, info] = itm_p2p_rev1(50, 50, pfl, 1000, 50);
            fspl = 32.45 + 20 * log10(1000) + 20 * log10(2);
            tc.verifyEqual(info.A_fs_db, fspl, 'AbsTol', 1e-9);
            tc.verifyEqual(info.mode, 1);
            tc.verifyLessThan(abs(L - fspl), 6);
        end

        function invalid_inputs_error(tc)
            pfl = flat_profile(10e3, 100);
            f = @(varargin) itm_p2p_rev1(varargin{:});
            tc.verifyError(@() f(30, 10, pfl, 2700, 0), 'itm:InvalidReliability');
            tc.verifyError(@() f(30, 10, pfl, 2700, [50 100]), 'itm:InvalidReliability');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'confidence', 0), 'itm:InvalidConfidence');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'location', 100), 'itm:InvalidLocation');
            tc.verifyError(@() f(0.4, 10, pfl, 2700, 50), 'itm:InvalidTxHeight');
            tc.verifyError(@() f(30, 3001, pfl, 2700, 50), 'itm:InvalidRxHeight');
            tc.verifyError(@() f(30, 10, pfl, 19, 50), 'itm:InvalidFrequency');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'climate', 8), 'itm:InvalidClimate');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'N_0', 249), 'itm:InvalidRefractivity');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'polarization', 2), 'itm:InvalidPolarization');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'epsilon', 0.5), 'itm:InvalidEpsilon');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'sigma', 0), 'itm:InvalidSigma');
            tc.verifyError(@() f(30, 10, pfl, 2700, 50, 'mdvar', 4), 'itm:InvalidMdvar');
            tc.verifyError(@() f(30, 10, pfl(1:end - 1), 2700, 50), 'itm:InvalidProfile');
            tc.verifyError(@() f(30, 10, [0; 100; 5], 2700, 50), 'itm:InvalidProfile');
        end

        function warnings_reported(tc)
            pfl = flat_profile(500, 10);             % 0.5 km: short-path warning
            [~, info] = itm_p2p_rev1(30, 10, pfl, 2700, [0.01 50], validity="off");
            tc.verifyTrue(all(bitand(info.warnings, uint32(hex2dec('0040'))) > 0));
            tc.verifyTrue(bitand(info.warnings(1), uint32(hex2dec('2000'))) > 0);   % extreme z
            tc.verifyFalse(bitand(info.warnings(2), uint32(hex2dec('2000'))) > 0);
            tc.verifyTrue(any(contains(info.warning_messages, 'Path distance is small')));
        end
    end
end

function [A, info] = run_case(c, profiles)
[A, info] = itm_p2p_rev1(c(1), c(2), profiles{c(13) + 1}, c(5), c(10), 'confidence', c(12), ...
    'location', c(11), 'climate', c(3), 'N_0', c(4), 'polarization', c(6), 'epsilon', c(7), ...
    'sigma', c(8), 'mdvar', c(9), 'validity', 'off');
end

function P = read_profiles(file)
lines = readlines(file);
lines = lines(strlength(strtrim(lines)) > 2);
P = cell(numel(lines), 1);
for k = 1:numel(lines)
    P{k} = str2double(split(lines(k), ','));
end
end

function pfl = read_ntia_pfl(file)
v = str2double(split(strjoin(readlines(file), ','), ','));
pfl = v(~isnan(v));
end

function pfl = flat_profile(d_m, xi_m)
np = round(d_m / xi_m);
pfl = [np; xi_m; zeros(np + 1, 1)];
end
