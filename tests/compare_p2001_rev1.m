function [T, p2001_funcs] = compare_p2001_rev1(p2001_folder, options)
%COMPARE_P2001_REV1 Time one link through ITM and through ITU-R P.2001.
%   [T, p2001_funcs] = COMPARE_P2001_REV1(p2001_folder) runs the same link
%   (Washington to Baltimore, 38 km, 2700 MHz, 30 m and 10 m antennas)
%   through itm_pathloss_rev1 and p2001_rev1 from nicklasorte/itu_p2001,
%   each with its own terrain handler, and returns:
%     T            wall time per link for each model: cold (new process,
%                  tiles cached on disk), warm with 1 percentage, warm with
%                  1,000 percentages, and the core model alone on a fixed
%                  profile
%     p2001_funcs  profiler breakdown of the warm P.2001 call (share of
%                  time per function), for comparison with
%                  profile_one_link_rev1
%
%   P.2001 is a much larger model than ITM (ducting and layer reflection,
%   sporadic-E, troposcatter, rain and gas attenuation, all combined per
%   time percentage), so it is expected to cost more per link; the
%   comparison shows how much, and where each spends its time.
%
%   Name-value options:
%     runs  timed repetitions (20)

arguments
    p2001_folder (1,1) string {mustBeFolder}
    options.runs (1,1) double {mustBeInteger, mustBePositive} = 20
end

addpath(fileparts(fileparts(mfilename('fullpath'))));
addpath(p2001_folder);
tx = [38.8895, -77.0353, 30];
rx = [39.0458, -76.6413, 10];
f_mhz = 2700;
p1000 = linspace(0.1, 99.9, 1000);

% Warm both terrain caches (downloads tiles on the first run only)
[~, itm_info] = itm_pathloss_rev1(tx, rx, f_mhz, 50);
[~, p_info] = p2001_rev1(tx, rx, f_mhz, 50);

model = ["ITM v1.4 (matlab_itm)"; "ITU-R P.2001-6 (itu_p2001)"];
cold_ms = zeros(2, 1);
clear functions %#ok<CLFUNC> new-process conditions
t0 = tic; itm_pathloss_rev1(tx, rx, f_mhz, 50); cold_ms(1) = 1e3 * toc(t0);
clear functions %#ok<CLFUNC>
t0 = tic; p2001_rev1(tx, rx, f_mhz, 50); cold_ms(2) = 1e3 * toc(t0);

warm_1_ms = 1e3 * [median_time(@() itm_pathloss_rev1(tx, rx, f_mhz, 50), options.runs)
    median_time(@() p2001_rev1(tx, rx, f_mhz, 50), options.runs)];
warm_1000_ms = 1e3 * [median_time(@() itm_pathloss_rev1(tx, rx, f_mhz, p1000), options.runs)
    median_time(@() p2001_rev1(tx, rx, f_mhz, p1000), max(3, round(options.runs / 4)))];

% Core model alone on its own fixed profile (no terrain, no lookups)
prof = p_info.profile;
core_1_ms = 1e3 * [median_time(@() itm_p2p_rev1(tx(3), rx(3), itm_info.pfl, f_mhz, 50, ...
        climate=itm_info.climate, N_0=itm_info.N_0), options.runs)
    median_time(@() p2001_profile_rev1(prof.d_km, prof.h_m, prof.zone, f_mhz / 1000, 50, ...
        tx(1), tx(2), rx(1), rx(2), tx(3), rx(3)), options.runs)];

profile_points = [numel(itm_info.pfl) - 2; numel(prof.d_km)];
T = table(model, profile_points, cold_ms, warm_1_ms, warm_1000_ms, core_1_ms);

% Where P.2001 spends a warm call
n_prof = options.runs;
profile clear
profile on
for k = 1:n_prof
    p2001_rev1(tx, rx, f_mhz, 50);
end
profile off
p = profile('info');
ft = p.FunctionTable;
name = string({ft.FunctionName})';
total_ms = 1e3 * [ft.TotalTime]' / n_prof;
top = total_ms(name == "p2001_rev1");
share_pct = 100 * total_ms / top;
calls_per_link = [ft.NumCalls]' / n_prof;
p2001_funcs = sortrows(table(name, total_ms, share_pct, calls_per_link), 'total_ms', 'descend');
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
