function T = benchmark_itm_rev1()
%BENCHMARK_ITM_REV1 Time the workloads a compiled ITM app runs.
%   T = BENCHMARK_ITM_REV1() returns a table of median times. Terrain tiles
%   for the Washington-Baltimore area must be cached (run the network tests
%   or itm_setup_rev1(region=[38 40 -78 -76]) once).
%
%   Workloads:
%     cold_first_call   first itm_pathloss_rev1 call after clear functions
%                       (maps load and tile decode), as in a new app process
%     core_1_rel        itm_p2p_rev1, 1,278-point profile, 1 reliability
%     core_1000_rel     same, 1,000 reliabilities
%     link_warm         itm_pathloss_rev1, one link, tiles in memory
%     links_50x1000     itm_pathloss_rev1, 50 links x 1,000 reliabilities
%     core_1e6_rel      itm_p2p_rev1, 1,000,000 reliabilities
%     links_50x1e5      itm_pathloss_rev1, 50 links x 100,000 reliabilities
%     selftest_offline  itm_selftest_rev1(network=false)

addpath(fileparts(fileparts(mfilename('fullpath'))));
tx = [38.8895, -77.0353, 30];
rx = [39.0458, -76.6413, 10];
rel = linspace(0.1, 99.9, 1000);
rel_big = 0.001 + 99.998 * rand(RandStream('mrg32k3a', 'Seed', 5), 1e6, 1);
rs = RandStream('mrg32k3a', 'Seed', 3);
txs = [38.75 + 0.5 * rand(rs, 50, 1), -77.2 + 0.5 * rand(rs, 50, 1), 20 + 20 * rand(rs, 50, 1)];

clear functions %#ok<CLFUNC> measure a fresh process
t0 = tic;
[~, info] = itm_pathloss_rev1(tx, rx, 2700, 50);
cold = toc(t0);
pfl = info.pfl;

name = ["cold_first_call"; "core_1_rel"; "core_1000_rel"; "link_warm"; "links_50x1000"; ...
    "core_1e6_rel"; "links_50x1e5"; "selftest_offline"];
seconds = [cold
    timeit(@() itm_p2p_rev1(30, 10, pfl, 2700, 50))
    timeit(@() itm_p2p_rev1(30, 10, pfl, 2700, rel))
    timeit(@() itm_pathloss_rev1(tx, rx, 2700, 50))
    median_time(@() itm_pathloss_rev1(txs, rx, 2700, rel), 3)
    median_time(@() itm_p2p_rev1(30, 10, pfl, 2700, rel_big), 3)
    median_time(@() itm_pathloss_rev1(txs, rx, 2700, rel_big(1:1e5)), 3)
    median_time(@() itm_selftest_rev1(network=false), 1)];
T = table(name, seconds);
T.ms = 1e3 * T.seconds;
end

function t = median_time(f, n)
f();                                  % warm up
ts = zeros(n, 1);
for k = 1:n
    t0 = tic;
    f();
    ts(k) = toc(t0);
end
t = median(ts);
end
