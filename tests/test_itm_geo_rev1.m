classdef test_itm_geo_rev1 < matlab.unittest.TestCase
    %TEST_ITM_GEO_REV1 Verifies climate, refractivity, terrain, and the wrapper.
    %   Offline tests compare the ITU-R lookups with the WInnForum CBRS
    %   reference implementation (tropoclim.py, refractivity.py) and check
    %   the wrapper's plumbing with supplied profiles. Tests tagged
    %   "Network" download USGS 3DEP and Copernicus tiles; they are
    %   filtered (not failed) when the tile servers are unreachable.
    %
    %   Run: runtests('tests/test_itm_geo_rev1.m')
    %   Offline only:
    %     import matlab.unittest.selectors.HasTag
    %     s = testsuite('tests/test_itm_geo_rev1.m'); run(s.selectIf(~HasTag('Network')))

    properties
        ref_dir
        tmp_dir
    end

    methods (TestClassSetup)
        function setup(tc)
            here = fileparts(mfilename('fullpath'));
            addpath(fileparts(here));
            tc.ref_dir = fullfile(here, 'reference');
        end
    end

    methods (TestMethodSetup)
        function make_tmp(tc)
            tc.tmp_dir = string(tempname);
            mkdir(tc.tmp_dir);
            tc.addTeardown(@() rmdir(tc.tmp_dir, 's'));
        end
    end

    methods (Test)
        function climate_matches_winnforum(tc)
            % tropoclim_test.py assertions
            tc.verifyEqual(itm_radio_climate_rev1(90, 0), 7);
            tc.verifyEqual(itm_radio_climate_rev1(50, -90), 5);
            tc.verifyEqual(itm_radio_climate_rev1(40, -120), 4);
            tc.verifyEqual(itm_radio_climate_rev1(0, 20), 1);
            tc.verifyEqual(itm_radio_climate_rev1(-30, -20), 7);
            % 309 points evaluated with tropoclim.py on the same data file
            T = readtable(fullfile(tc.ref_dir, 'itu_lookup_expected.csv'));
            tc.verifyEqual(itm_radio_climate_rev1(T.lat, T.lon), T.climate);
        end

        function refractivity_matches_winnforum(tc)
            tc.verifyEqual(itm_surface_refractivity_rev1([90 90 90], [0 91 155.4]), ...
                [317.248 317.248 317.248], 'AbsTol', 1e-9);
            T = readtable(fullfile(tc.ref_dir, 'itu_lookup_expected.csv'));
            tc.verifyEqual(itm_surface_refractivity_rev1(T.lat, T.lon), T.N_0, 'AbsTol', 1e-8);
        end

        function lookups_are_vectorized(tc)
            lat = [10 20; 30 40];
            lon = [-100 50; 120 -10];
            c = itm_radio_climate_rev1(lat, lon);
            n = itm_surface_refractivity_rev1(lat, lon);
            tc.verifySize(c, [2 2]);
            tc.verifySize(n, [2 2]);
            for k = 1:4
                tc.verifyEqual(c(k), itm_radio_climate_rev1(lat(k), lon(k)));
                tc.verifyEqual(n(k), itm_surface_refractivity_rev1(lat(k), lon(k)), 'AbsTol', 1e-12);
            end
            % Longitude wraps
            tc.verifyEqual(itm_radio_climate_rev1(40, -120), itm_radio_climate_rev1(40, 240));
            tc.verifyEqual(itm_surface_refractivity_rev1(40, -120), ...
                itm_surface_refractivity_rev1(40, 240), 'AbsTol', 1e-12);
        end

        function wrapper_matches_core_with_supplied_profile(tc)
            tx = [38.8895, -77.0353, 30];
            rx = [39.0458, -76.6413, 10];
            pfl = [400; 95.75; 20 + 15 * sin((0:400)' / 25)];
            rel = [1 10 50 90 99];
            [L, info] = itm_pathloss_rev1(tx, rx, 2700, rel, pfl=pfl);
            clim = itm_radio_climate_rev1(info.midpoint_deg(1), info.midpoint_deg(2));
            N_0 = itm_surface_refractivity_rev1(info.midpoint_deg(1), info.midpoint_deg(2));
            tc.verifyEqual(info.climate, clim);
            tc.verifyEqual(info.N_0, N_0);
            ref = itm_p2p_rev1(30, 10, pfl, 2700, rel, climate=clim, N_0=N_0, ...
                epsilon=25, sigma=0.02, polarization=1, mdvar=13, confidence=50);
            tc.verifyEqual(L, ref, 'AbsTol', 1e-12);
            % Overrides pass through
            L2 = itm_pathloss_rev1(tx, rx, 2700, rel, pfl=pfl, climate=5, N_0=301, ...
                polarization="horizontal", epsilon=15, sigma=0.005, mdvar=3, confidence=90);
            ref2 = itm_p2p_rev1(30, 10, pfl, 2700, rel, climate=5, N_0=301, ...
                polarization=0, epsilon=15, sigma=0.005, mdvar=3, confidence=90);
            tc.verifyEqual(L2, ref2, 'AbsTol', 1e-12);
        end

        function multi_link_equals_single_links(tc)
            rx = [39.0458, -76.6413, 10];
            txs = [38.90 -77.03 30; 38.95 -76.90 25; 39.20 -76.70 40];
            pfls = {[300; 100; zeros(301, 1)]; [200; 90; linspace(0, 80, 201)']; ...
                [150; 120; 50 * rand(151, 1)]};
            rel = [1 10 50 90 99];
            L = itm_pathloss_rev1(txs, rx, 2700, rel, pfl=pfls);
            tc.verifySize(L, [3 5]);
            for k = 1:3
                tc.verifyEqual(L(k, :), itm_pathloss_rev1(txs(k, :), rx, 2700, rel, pfl=pfls{k}), ...
                    'AbsTol', 1e-12);
            end
        end

        function offline_mode_fails_loudly(tc)
            tc.verifyError(@() itm_terrain_elevation_rev1(38.9, -77.0, terrain_dir=tc.tmp_dir, ...
                download=false), 'itm:terrain:TileMissing');
        end

        function maps_folder_override(tc)
            % MATLAB_ITM_MAPS_DIR takes the ITU text files from another folder
            here = fileparts(fileparts(mfilename('fullpath')));
            copyfile(fullfile(here, 'data', 'TropoClim.txt'), tc.tmp_dir);
            copyfile(fullfile(here, 'data', 'N050.TXT'), tc.tmp_dir);
            old = getenv('MATLAB_ITM_MAPS_DIR');
            tc.addTeardown(@() setenv('MATLAB_ITM_MAPS_DIR', old));
            setenv('MATLAB_ITM_MAPS_DIR', tc.tmp_dir);
            tc.verifyEqual(itm_radio_climate_rev1(38.9, -77.0), 6);
            tc.verifyEqual(itm_surface_refractivity_rev1(90, 0), 317.248, 'AbsTol', 1e-9);
            setenv('MATLAB_ITM_MAPS_DIR', fullfile(tc.tmp_dir, 'missing'));
            tc.verifyError(@() itm_radio_climate_rev1(38.9, -77.0), 'itm:maps:NotInFolder');
        end

        function setup_without_region(tc)
            old = getenv('MATLAB_ITM_CACHE');
            tc.addTeardown(@() setenv('MATLAB_ITM_CACHE', old));
            T = itm_setup_rev1(cache_dir=tc.tmp_dir);
            tc.verifyEqual(height(T), 0);
            tc.verifyEqual(string(getenv('MATLAB_ITM_CACHE')), tc.tmp_dir);
            tc.verifyError(@() itm_setup_rev1(region=[40 39 -77 -76]), 'itm:setup:Region');
        end

        function zero_length_path_errors(tc)
            tc.verifyError(@() itm_terrain_profile_rev1(38.9, -77, 38.9, -77, ...
                terrain_dir=tc.tmp_dir, download=false), 'itm:terrain:ZeroDistance');
        end
    end

    methods (Test, TestTags = {'Network'})
        function profile_from_3dep(tc)
            tc.assume_network();
            tx = [38.8895, -77.0353];
            rx = [39.0458, -76.6413];
            [pfl, info] = itm_terrain_profile_rev1(tx(1), tx(2), rx(1), rx(2));
            d = distance(tx(1), tx(2), rx(1), rx(2), wgs84Ellipsoid('meter'));
            tc.verifyEqual(pfl(1) * pfl(2), d, 'RelTol', 1e-9);     % sub-millimeter
            tc.verifyLessThanOrEqual(pfl(2), 30);
            tc.verifyEqual(numel(pfl), pfl(1) + 3);
            tc.verifyTrue(all(info.source_code == 1), 'Whole path is inside 3DEP');
            tc.verifyTrue(all(pfl(3:end) > -10 & pfl(3:end) < 200), 'DC-Baltimore terrain range');
            tc.verifyEqual(pfl(3), info.elevation_m(1));
        end

        function copernicus_fills_outside_3dep(tc)
            tc.assume_network();
            [z, info] = itm_terrain_elevation_rev1([51.50; 36.50], [-0.12; -30.50]);
            tc.verifyEqual(info.source_code, uint8([2; 0]));     % London: Copernicus, Atlantic: none
            tc.verifyGreaterThan(z(1), -5);
            tc.verifyLessThan(z(1), 60);
            tc.verifyEqual(z(2), 0);
        end

        function glo90_source(tc)
            tc.assume_network();
            [z, info] = itm_terrain_elevation_rev1(51.50, -0.12, source="copernicus90");
            tc.verifyEqual(info.source_code, uint8(3));
            tc.verifyGreaterThan(z, -5);
            tc.verifyLessThan(z, 60);
        end

        function batched_profiles_equal_single(tc)
            tc.assume_network();
            lat1 = [38.90; 38.95]; lon1 = [-77.03; -76.90];
            [P, I] = itm_terrain_profile_rev1(lat1, lon1, 39.0458, -76.6413);
            tc.verifySize(P, [2 1]);
            for k = 1:2
                tc.verifyEqual(P{k}, itm_terrain_profile_rev1(lat1(k), lon1(k), 39.0458, -76.6413));
                tc.verifyEqual(I(k).distance_m, P{k}(1) * P{k}(2), 'RelTol', 1e-9);
            end
        end

        function end_to_end_pathloss(tc)
            tc.assume_network();
            tx = [38.8895, -77.0353, 30];
            rx = [39.0458, -76.6413, 10];
            rel = [1 10 50 90 99];
            [L, info] = itm_pathloss_rev1(tx, rx, 2700, rel);
            tc.verifySize(L, [1 5]);
            tc.verifyGreaterThanOrEqual(diff(L), 0);
            tc.verifyGreaterThan(L(3), info.A_fs_db - 10);       % physical floor
            tc.verifyEqual(L, itm_p2p_rev1(30, 10, info.pfl, 2700, rel, climate=info.climate, ...
                N_0=info.N_0), 'AbsTol', 1e-12);
        end

        function concurrent_downloads_share_folder(tc)
            % Two workers fetch the same tile into one empty folder at once.
            tc.assume_network();
            pool = gcp('nocreate');
            tc.assumeNotEmpty(pool, 'No parallel pool; start one with parpool(2) to run this test.');
            here = fileparts(fileparts(mfilename('fullpath')));
            parfevalOnAll(pool, @addpath, 0, here);
            d = tc.tmp_dir;
            f(1) = parfeval(pool, @itm_terrain_elevation_rev1, 2, 38.5, -76.5, terrain_dir=d);
            f(2) = parfeval(pool, @itm_terrain_elevation_rev1, 2, 38.5, -76.5, terrain_dir=d);
            [z1, ~] = fetchOutputs(f(1));
            [z2, ~] = fetchOutputs(f(2));
            tc.verifyEqual(z1, z2);
            tc.verifyEmpty(dir(fullfile(d, '**', '*.part')), 'No temporary files left');
            tc.verifyNumElements(dir(fullfile(d, 'usgs3dep', '*.tif')), 1);
        end
    end

    methods
        function assume_network(tc)
            try
                r = matlab.net.http.RequestMessage('HEAD');
                resp = send(r, matlab.net.URI( ...
                    'https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1/TIFF/current/n39w077/USGS_1_n39w077.tif'));
                ok = resp.StatusCode == matlab.net.http.StatusCode.OK;
            catch
                ok = false;
            end
            tc.assumeTrue(ok, 'USGS 3DEP tile server unreachable');
        end
    end
end
