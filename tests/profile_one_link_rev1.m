function [stages, funcs] = profile_one_link_rev1(options)
%PROFILE_ONE_LINK_REV1 Time one link through every stage, terrain included.
%   [stages, funcs] = PROFILE_ONE_LINK_REV1() runs one itm_pathloss_rev1
%   link (Washington to Baltimore, 38 km, 2700 MHz) and returns:
%     stages  wall time of each stage, measured without the profiler:
%             geodesic sampling, terrain elevation, climate and
%             refractivity, ITM core, and the full call, for a warm link
%             (tiles in memory) and a cold link (new process: maps and
%             tiles loaded from disk, tiles already downloaded)
%     funcs   per-function breakdown of the warm full call from the MATLAB
%             profiler: total and self time per call. The profiler adds
%             overhead, so use the share column rather than absolute times.
%
%   Name-value options:
%     n_rel   number of reliabilities (1)
%     runs    timed repetitions per stage (30)
%
%   Tiles for the Washington-Baltimore area must be cached once (any
%   network test, or itm_setup_rev1(region=[38 40 -78 -76])).

arguments
    options.n_rel (1,1) double {mustBeInteger, mustBePositive} = 1
    options.runs (1,1) double {mustBeInteger, mustBePositive} = 30
end

addpath(fileparts(fileparts(mfilename('fullpath'))));
tx = [38.8895, -77.0353, 30];
rx = [39.0458, -76.6413, 10];
f_mhz = 2700;
rel = linspace(0.1, 99.9, options.n_rel);
if options.n_rel == 1
    rel = 50;
end

% Cold: a new process, with tiles and decoded caches already on disk
clear functions %#ok<CLFUNC> drop every persistent cache
t0 = tic;
[~, info] = itm_pathloss_rev1(tx, rx, f_mhz, rel);
cold_total = toc(t0);

% Inputs for the individual stages, taken from the real call
lat = info.profile.lat_deg;
lon = info.profile.lon_deg;
mid = info.midpoint_deg;
pfl = info.pfl;
E = wgs84Ellipsoid('meter');
n_pts = numel(lat);

stage_fns = {
    "Geodesic: distance + reckon (profile points)", @() geodesic(tx, rx, n_pts, E)
    "Terrain: elevation at profile points", @() itm_terrain_elevation_rev1(lat, lon)
    "Climate and N0 lookups (midpoint)", @() lookups(mid)
    "ITM core (itm_p2p_rev1)", @() itm_p2p_rev1(tx(3), rx(3), pfl, f_mhz, rel, ...
        climate=info.climate, N_0=info.N_0)
    "Full call (itm_pathloss_rev1)", @() itm_pathloss_rev1(tx, rx, f_mhz, rel)};
n = size(stage_fns, 1);
warm_ms = zeros(n, 1);
for k = 1:n
    warm_ms(k) = 1e3 * median_time(stage_fns{k, 2}, options.runs);
end

% Cold stages: the pieces that load from disk in a new process
clear functions %#ok<CLFUNC>
t0 = tic; itm_radio_climate_rev1(mid(1), mid(2)); cold_maps = toc(t0);
t0 = tic; itm_terrain_elevation_rev1(lat, lon); cold_terrain = toc(t0);
cold_ms = [NaN; 1e3 * cold_terrain; 1e3 * cold_maps; NaN; 1e3 * cold_total];

stage = [stage_fns{:, 1}]';
stages = table(stage, warm_ms, cold_ms);
stages.Properties.Description = sprintf('%d profile points, %d reliabilities', n_pts, numel(rel));

% Per-function breakdown of the warm full call
itm_pathloss_rev1(tx, rx, f_mhz, rel);
n_prof = max(20, options.runs);
profile clear
profile on
for k = 1:n_prof
    itm_pathloss_rev1(tx, rx, f_mhz, rel);
end
profile off
p = profile('info');
ft = p.FunctionTable;
name = string({ft.FunctionName})';
total_ms = 1e3 * [ft.TotalTime]' / n_prof;
self_ms = zeros(numel(ft), 1);
for k = 1:numel(ft)
    child = 0;
    if ~isempty(ft(k).Children)
        child = sum([ft(k).Children.TotalTime]);
    end
    self_ms(k) = 1e3 * (ft(k).TotalTime - child) / n_prof;
end
calls_per_link = [ft.NumCalls]' / n_prof;
top = total_ms(name == "itm_pathloss_rev1");
share_pct = 100 * total_ms / top;
funcs = table(name, total_ms, self_ms, share_pct, calls_per_link);
funcs = sortrows(funcs, 'total_ms', 'descend');
end

function geodesic(tx, rx, n_pts, E)
[d, az] = distance(tx(1), tx(2), rx(1), rx(2), E);
reckon(repmat(tx(1), n_pts, 1), repmat(tx(2), n_pts, 1), linspace(0, d, n_pts)', ...
    repmat(az, n_pts, 1), E);
end

function lookups(mid)
itm_radio_climate_rev1(mid(1), mid(2));
itm_surface_refractivity_rev1(mid(1), mid(2));
end

function t = median_time(f, n)
f();
ts = zeros(n, 1);
for k = 1:n
    t0 = tic;
    f();
    ts(k) = toc(t0);
end
t = median(ts);
end
