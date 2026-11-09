function loss_db = itm_cli_rev1(tx_lat, tx_lon, tx_h_m, rx_lat, rx_lon, rx_h_m, f_mhz, varargin)
%ITM_CLI_REV1 Command-line entry point for a compiled ITM app.
%   loss_db = ITM_CLI_REV1(tx_lat, tx_lon, tx_h_m, rx_lat, rx_lon, rx_h_m, f_mhz, reliability)
%   computes ITM point-to-point path loss with itm_pathloss_rev1 and prints
%   a table. Every argument may be text, as a compiled app passes them;
%   reliability may be a list such as "1,10,50,90,99" (default "50").
%
%   loss_db = ITM_CLI_REV1(..., "--offline") uses only cached terrain tiles
%   and ITU maps and never downloads: a missing tile is an error
%   (itm:terrain:TileMissing) rather than a network attempt. The flag may
%   come before or after reliability. Setting the environment variable
%   MATLAB_ITM_OFFLINE=1 has the same effect.
%
%   Compiled usage (after build_itm_app_rev1):
%     itm_cli_rev1 38.8895 -77.0353 30 39.0458 -76.6413 10 2700 1,10,50,90,99
%     itm_cli_rev1 38.8895 -77.0353 30 39.0458 -76.6413 10 2700 50 --offline
%
%   See also itm_pathloss_rev1, build_itm_app_rev1.

arguments
    tx_lat
    tx_lon
    tx_h_m
    rx_lat
    rx_lon
    rx_h_m
    f_mhz
end
arguments (Repeating)
    varargin
end

reliability = "50"; offline = getenv('MATLAB_ITM_OFFLINE') == "1";
for k = 1:numel(varargin)
    a = varargin{k};
    if (isstring(a) || ischar(a)) && startsWith(string(a), "--")
        if strcmpi(string(a), "--offline")
            offline = true;
        else
            error('itm:cli:BadArgument', 'Unknown option %s. The only option is --offline.', a);
        end
    else
        reliability = a;
    end
end
if offline
    % Also keeps the ITU maps from downloading (itm_maps reads this variable)
    old = getenv('MATLAB_ITM_OFFLINE');
    restore = onCleanup(@() setenv('MATLAB_ITM_OFFLINE', old));
    setenv('MATLAB_ITM_OFFLINE', '1');
end

tx = [num(tx_lat), num(tx_lon), num(tx_h_m)];
rx = [num(rx_lat), num(rx_lon), num(rx_h_m)];
f = num(f_mhz);
if isstring(reliability) || ischar(reliability)
    rel = str2double(split(string(reliability), ","))';
else
    rel = reliability(:)';
end
if any(isnan([tx rx f rel]))
    error('itm:cli:BadArgument', 'All arguments must be numeric.');
end

[loss_db, info] = itm_pathloss_rev1(tx, rx, f, rel, download=~offline);

fprintf('ITM v1.4 point-to-point (MATLAB port)\n');
fprintf('Path %.3f km, climate %d, N_0 %.1f, mode %s, %d profile points at %.1f m\n', ...
    info.d_km, info.climate, info.N_0, info.mode_name, info.pfl(1) + 1, info.pfl(2));
fprintf('Terrain tiles: %s\n', strjoin(info.profile.tiles, ', '));
fprintf('%14s %16s\n', 'Reliability %', 'Path loss (dB)');
fprintf('%14g %16.2f\n', [rel; loss_db(:)']);
end

function v = num(x)
if isstring(x) || ischar(x)
    v = str2double(x);
else
    v = double(x);
end
end
