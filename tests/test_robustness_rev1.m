classdef test_robustness_rev1 < matlab.unittest.TestCase
    %TEST_ROBUSTNESS_REV1 Parallel use, shared caches, and edge geography.
    %   Conditions a compiled Monte Carlo deployment meets that the other
    %   suites don't: links evaluated on parallel workers, several processes
    %   writing the same decoded-tile cache, a damaged cache file, paths
    %   across the antimeridian, high-latitude Copernicus tiles, and points
    %   exactly on tile boundaries.
    %
    %   Tags: "Network" (downloads tiles on the first run), "Parallel"
    %   (needs a pool: parpool(2)). Without a pool, parallel tests are
    %   reported as incomplete, not failed.
    %
    %   Run: runtests('tests/test_robustness_rev1.m')

    properties
        tmp_dir
    end

    methods (TestClassSetup)
        function add_path(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end
    end

    methods (TestMethodSetup)
        function make_tmp(tc)
            tc.tmp_dir = string(tempname);
            mkdir(tc.tmp_dir);
            tc.addTeardown(@() rmdir(tc.tmp_dir, 's'));
            % Isolate from tiles another tool (itu_p2001) has cached
            old = getenv('ITU_P2001_CACHE');
            tc.addTeardown(@() setenv('ITU_P2001_CACHE', old));
            setenv('ITU_P2001_CACHE', char(fullfile(tc.tmp_dir, 'no_p2001')));
        end
    end

    methods (Test, TestTags = {'Network', 'Parallel'})
        function parfor_matches_serial(tc)
            % Each worker builds its own maps, tile, and path caches; the
            % losses must not depend on which worker ran a link.
            pool = tc.need_pool();
            tc.need_network();
            here = fileparts(fileparts(mfilename('fullpath')));
            parfevalOnAll(pool, @addpath, 0, here);
            rs = RandStream('mrg32k3a', 'Seed', 21);
            n = 12;
            txs = [38.6 + 0.8 * rand(rs, n, 1), -77.3 + 0.8 * rand(rs, n, 1), 10 + 40 * rand(rs, n, 1)];
            rx = [39.0458, -76.6413, 10];
            rel = [1 10 50 90 99];
            serial = itm_pathloss_rev1(txs, rx, 2700, rel);
            par = zeros(n, numel(rel));
            parfor k = 1:n
                par(k, :) = itm_pathloss_rev1(txs(k, :), rx, 2700, rel);
            end
            tc.verifyEqual(par, serial, 'AbsTol', 1e-12, 'parfor single-link calls');
            f = parfeval(pool, @itm_pathloss_rev1, 1, txs, rx, 2700, rel);
            tc.verifyEqual(fetchOutputs(f), serial, 'AbsTol', 1e-12, 'batch call on a worker');
        end

        function concurrent_decoded_cache_writes(tc)
            % Two workers decode the same tile into an empty cache at once;
            % the decoded cache must end up complete and correct.
            pool = tc.need_pool();
            src = tc.cached_tile('USGS_1_n39w077.tif');
            dir_ = tc.tile_folder_with(src);
            here = fileparts(fileparts(mfilename('fullpath')));
            parfevalOnAll(pool, @addpath, 0, here);
            parfevalOnAll(pool, @setenv, 0, 'ITU_P2001_CACHE', char(fullfile(tc.tmp_dir, 'no_p2001')));
            parfevalOnAll(pool, @clear, 0, 'functions');
            [la, lo] = tc.points(38, -77, 5000);
            f(1) = parfeval(pool, @itm_terrain_elevation_rev1, 1, la, lo, 'terrain_dir', dir_, 'download', false);
            f(2) = parfeval(pool, @itm_terrain_elevation_rev1, 1, la, lo, 'terrain_dir', dir_, 'download', false);
            z1 = fetchOutputs(f(1));
            z2 = fetchOutputs(f(2));
            tc.verifyEqual(z1, z2);
            tc.verifyEmpty(dir(fullfile(dir_, '**', '*.part*')), 'temporary files left behind');
            z_file = fullfile(dir_, 'usgs3dep', 'USGS_1_n39w077.tif.zcache');
            tc.verifyTrue(isfile(z_file), 'decoded cache not written');
            % A fresh process reading the cache gets the same values
            clear functions %#ok<CLFUNC>
            setenv('ITU_P2001_CACHE', char(fullfile(tc.tmp_dir, 'no_p2001')));
            tc.verifyEqual(itm_terrain_elevation_rev1(la, lo, terrain_dir=dir_, download=false), z1);
        end
    end

    methods (Test, TestTags = {'Network'})
        function truncated_cache_is_detected_and_rewritten(tc)
            % fread pads a short last column with zeros, so a cache cut off
            % mid-column could pass a size check; the byte count must catch
            % it, and the cache must be rewritten.
            src = tc.cached_tile('USGS_1_n39w077.tif');
            dir_ = tc.tile_folder_with(src);
            [la, lo] = tc.points(38, -77, 5000);
            clear functions %#ok<CLFUNC>
            z_ref = itm_terrain_elevation_rev1(la, lo, terrain_dir=dir_, download=false);
            z_file = fullfile(dir_, 'usgs3dep', 'USGS_1_n39w077.tif.zcache');
            full_bytes = dir(z_file).bytes;
            for cut = [4, 4 * 1000, floor(full_bytes / 2)]       % inside the last column, and more
                bytes = read_bytes(z_file);
                write_bytes(z_file, bytes(1:end - cut));
                clear functions %#ok<CLFUNC>
                z = itm_terrain_elevation_rev1(la, lo, terrain_dir=dir_, download=false);
                tc.verifyEqual(z, z_ref, sprintf('truncated by %d bytes', cut));
                tc.verifyEqual(dir(z_file).bytes, full_bytes, 'cache not rewritten');
                % restore the full file for the next cut
                clear functions %#ok<CLFUNC>
                itm_terrain_elevation_rev1(la, lo, terrain_dir=dir_, download=false);
            end
            % Garbage in the reference file is also recovered from
            fid = fopen(fullfile(dir_, 'usgs3dep', 'USGS_1_n39w077.tif.rcache.mat'), 'w');
            fwrite(fid, uint8(1:100));
            fclose(fid);
            clear functions %#ok<CLFUNC>
            tc.verifyEqual(itm_terrain_elevation_rev1(la, lo, terrain_dir=dir_, download=false), z_ref);
        end

        function antimeridian_path(tc)
            % Taveuni, Fiji: the path crosses 180 degrees longitude
            tc.need_network();
            tx = [-16.80, 179.95, 30];
            rx = [-16.86, -179.94, 10];
            [pfl, info] = itm_terrain_profile_rev1(tx(1), tx(2), rx(1), rx(2));
            d = distance(tx(1), tx(2), rx(1), rx(2), wgs84Ellipsoid('meter'));
            tc.verifyEqual(pfl(1) * pfl(2), d, 'RelTol', 1e-9);
            tc.verifyLessThan(d, 20e3, 'Path went the long way around the globe');
            tc.verifyTrue(all(abs(info.lon_deg) <= 180));
            tc.verifyTrue(any(info.lon_deg > 0) && any(info.lon_deg < 0), 'Path should cross 180');
            tc.verifyTrue(all(isfinite(pfl)));
            tc.verifyTrue(all(pfl(3:end) >= -5 & pfl(3:end) < 1300));
            L = itm_pathloss_rev1(tx, rx, 2700, [10 50 90]);
            tc.verifyTrue(all(isfinite(L)) && all(diff(L) >= 0));
        end

        function high_latitude_copernicus(tc)
            % Tromso, Norway (69.6 N): Copernicus tiles there have fewer
            % columns per degree of longitude
            tc.need_network();
            [la, lo] = tc.points(69, 18, 3000);
            [z, info] = itm_terrain_elevation_rev1(la, lo);
            tc.verifyTrue(all(info.source_code == 2 | info.source_code == 0));
            [Z, R] = readgeoraster(info.tiles(1), 'OutputType', 'single');
            tc.verifyLessThan(R.RasterSize(2), R.RasterSize(1), 'expected a narrower high-latitude tile');
            lac = min(max(la, R.LatitudeLimits(1)), R.LatitudeLimits(2));
            loc = min(max(lo, R.LongitudeLimits(1)), R.LongitudeLimits(2));
            ref = double(geointerp(Z, R, lac, loc, 'linear'));
            ok = ~isnan(ref);
            tc.verifyEqual(z(ok), ref(ok), 'RelTol', 3e-7, 'AbsTol', 1e-5);
            [~, pinfo] = itm_terrain_profile_rev1(69.65, 18.96, 69.75, 19.30);
            tc.verifyTrue(all(isfinite(pinfo.elevation_m)));
        end

        function points_on_tile_boundaries(tc)
            % Exactly on integer latitude and longitude (tile edges and a
            % corner shared by four tiles), elevation must be continuous
            tc.need_network();
            e = 1e-9;
            lat = [39, 39 - e, 39 + e, 38.5, 38.5, 38.5, 39, 39 - e, 39 + e];
            lon = [-76.5, -76.5, -76.5, -77, -77 - e, -77 + e, -77, -77 + e, -77 - e];
            z = itm_terrain_elevation_rev1(lat, lon);
            tc.verifyTrue(all(isfinite(z)));
            tc.verifyLessThan(abs(z(1) - z(2:3)), 0.5, 'north-south tile edge');
            tc.verifyLessThan(abs(z(4) - z(5:6)), 0.5, 'east-west tile edge');
            tc.verifyLessThan(abs(z(7) - z(8:9)), 0.5, 'four-tile corner');
            % A profile that starts and ends exactly on tile corners
            pfl = itm_terrain_profile_rev1(39, -77, 38, -76);
            tc.verifyTrue(all(isfinite(pfl)));
        end
    end

    methods
        function pool = need_pool(tc)
            pool = gcp('nocreate');
            tc.assumeNotEmpty(pool, 'No parallel pool; start one with parpool(2).');
        end

        function need_network(tc)
            try
                r = matlab.net.http.RequestMessage('HEAD');
                resp = send(r, matlab.net.URI( ...
                    'https://copernicus-dem-30m.s3.amazonaws.com/tileList.txt'));
                ok = resp.StatusCode == matlab.net.http.StatusCode.OK;
            catch
                ok = false;
            end
            tc.assumeTrue(ok, 'Tile servers unreachable');
        end

        function src = cached_tile(tc, name)
            % A tile from this tool's default cache, downloaded if needed
            tc.need_network();
            [~, info] = itm_terrain_elevation_rev1(38.5, -76.5, source="usgs3dep");
            src = info.tiles(endsWith(info.tiles, name));
            tc.assumeNotEmpty(src, 'Tile not available');
            src = src(1);
        end

        function d = tile_folder_with(tc, src)
            % Fresh terrain folder holding only a copy of the GeoTIFF
            d = fullfile(tc.tmp_dir, 'terrain');
            mkdir(fullfile(d, 'usgs3dep'));
            copyfile(src, fullfile(d, 'usgs3dep'));
        end

        function [la, lo] = points(~, lat0, lon0, n)
            rs = RandStream('mrg32k3a', 'Seed', lat0 * 1000 + abs(lon0));
            la = lat0 + 0.999 * rand(rs, n, 1);
            lo = lon0 + 0.999 * rand(rs, n, 1);
        end
    end
end

function b = read_bytes(f)
fid = fopen(f, 'r');
b = fread(fid, Inf, '*uint8');
fclose(fid);
end

function write_bytes(f, b)
fid = fopen(f, 'w');
fwrite(fid, b, 'uint8');
fclose(fid);
end
