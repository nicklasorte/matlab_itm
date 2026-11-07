function [dBloss, prop_mode, elev_deg, err_msg] = itm_p2p_mechanism_rev1(sim_array_list_bs, sim_pt, reliability, confidence, FreqMHz, Tpol, options)
%ITM_P2P_MECHANISM_REV1 Drop-in replacement for ITMP2P_mechanism_rev4_embed_height (SEADLib), in MATLAB.
%   [dBloss, prop_mode] = ITM_P2P_MECHANISM_REV1(sim_array_list_bs, sim_pt,
%       reliability, confidence, FreqMHz, Tpol)
%   takes the inputs of ITMP2P_mechanism_rev4_embed_height in
%   nicklasorte/general_terrestrial_pathloss, without the app handle and
%   the parallel flag, and runs ITM v1.4 in MATLAB instead of SEADLib.dll.
%   No .NET assembly, no C:\USGS terrain folder, and no TropoClim.mat or
%   data_N050.mat on the path: terrain downloads and caches automatically,
%   and the ITU maps ship with this repository.
%
%   Inputs (same as the SEADLib mechanism):
%     sim_array_list_bs  N-by-3 [lat_deg, lon_deg, height_m] of each
%                        transmitter (base station), height above ground
%     sim_pt             [lat_deg, lon_deg, height_m] of the receiver
%     reliability        time percentages, 0 < reliability < 100 (percent,
%                        not fractions; SEADLib took reliability/100)
%     confidence         confidence percentage, 0 < confidence < 100
%     FreqMHz            frequency (MHz)
%     Tpol               polarization: 0 horizontal, 1 vertical
%
%   Outputs:
%     dBloss     N-by-numel(reliability) basic transmission loss (dB)
%     prop_mode  N-by-1 propagation mode, the SEADLib/ITM 1.2.2 codes:
%                0 line of sight, 5 single-horizon diffraction, 6
%                single-horizon troposcatter, 9 double-horizon diffraction,
%                10 double-horizon troposcatter. (The comment in
%                ITMP2P_mechanism_rev4 swaps 5 and 9; ITMDLL.cpp adds 1 for
%                diffraction to 4, single horizon, or 8, double horizon.)
%     elev_deg   N-by-2 elevation angles [TX, RX] in degrees, positive up
%     err_msg    N-by-1 strings, empty for links that succeeded
%
%   Defaults match the SEADLib mechanism: epsilon 25, sigma 0.02 S/m,
%   mdvar 13 (broadcast point-to-point), radio climate as the lower of the
%   two terminal climates (ITU-R P.617), and N_0 at the path midpoint (ITU-R
%   P.452).
%
%   Differences from the SEADLib mechanism, by design:
%     - Failures are loud. SEADLib errors became 1000 dB and prop_mode 999,
%       climate errors became climate 5, refractivity errors became 301
%       N-units, and infinite losses became 1 or 999 dB, each silently. Here
%       a failure raises an error that names the link. With
%       OnError="nan", the link gets NaN loss and NaN prop_mode, and the
%       reason is in err_msg.
%     - Paths outside 1 to 2000 km raise itm:validity:Distance unless
%       validity="warn" or "off" (see itm_p2p_rev1).
%     - ITM v1.4 (NTIA, 2019) instead of the ITM 1.2.2 inside SEADLib, and
%       USGS 3DEP 1" terrain at 30 m spacing (Copernicus outside the U.S.)
%       instead of the C:\USGS tiles. Expect small differences in loss.
%
%   Name-value options:
%     OnError         "error" (default) or "nan"
%     climate_rule    "endpoints" (default, as SEADLib) or "midpoint"
%                     (WInnForum); see itm_pathloss_rev1
%     validity        "error" (default), "warn", or "off"
%     terrain_source, terrain_dir, download, spacing_m
%                     passed to itm_pathloss_rev1
%
%   Example:
%     bs = [38.90 -77.03 30; 38.95 -76.90 25];
%     [L, mode] = itm_p2p_mechanism_rev1(bs, [39.05 -76.64 10], [1 50 99], 50, 3550, 1)
%
%   See also itm_pathloss_rev1, itm_p2p_rev1.

arguments
    sim_array_list_bs (:,3) double {mustBeReal, mustBeFinite, mustBeNonempty}
    sim_pt (1,3) double {mustBeReal, mustBeFinite}
    reliability double {mustBeReal, mustBeFinite, mustBeNonempty}
    confidence (1,1) double {mustBeReal, mustBeFinite}
    FreqMHz (1,1) double {mustBeReal, mustBeFinite}
    Tpol (1,1) double {mustBeMember(Tpol, [0 1])}
    options.OnError (1,1) string {mustBeMember(options.OnError, ["error", "nan"])} = "error"
    options.climate_rule (1,1) string {mustBeMember(options.climate_rule, ["midpoint", "endpoints"])} = "endpoints"
    options.validity (1,1) string {mustBeMember(options.validity, ["error", "warn", "off"])} = "error"
    options.terrain_source (1,1) string = "auto"
    options.terrain_dir (1,1) string = itm_default_terrain_dir()
    options.download (1,1) logical = true
    options.spacing_m (1,1) double {mustBePositive} = 30
end

n = size(sim_array_list_bs, 1);
rel = reliability(:).';
args = {'confidence', confidence, 'polarization', Tpol, 'epsilon', 25, 'sigma', 0.02, 'mdvar', 13, ...
    'climate_rule', options.climate_rule, 'validity', options.validity, ...
    'terrain_source', options.terrain_source, 'terrain_dir', options.terrain_dir, ...
    'download', options.download, 'spacing_m', options.spacing_m};
err_msg = strings(n, 1);

try
    [L, ~, elev_deg, prop_mode] = itm_pathloss_rev1(sim_array_list_bs, sim_pt, FreqMHz, rel, args{:});
    dBloss = reshape(L, n, numel(rel));
catch err
    if options.OnError == "error"
        rethrow(err);
    end
    % One link at a time, so one bad link doesn't cost the others
    dBloss = NaN(n, numel(rel));
    prop_mode = NaN(n, 1);
    elev_deg = NaN(n, 2);
    for k = 1:n % only after a batch failure
        try
            [L, ~, elev_deg(k, :), prop_mode(k)] = itm_pathloss_rev1(sim_array_list_bs(k, :), sim_pt, ...
                FreqMHz, rel, args{:});
            dBloss(k, :) = L(:).';
        catch link_err
            err_msg(k) = string(link_err.identifier) + ": " + string(link_err.message);
        end
    end
    failed = strlength(err_msg) > 0;
    if any(failed)
        warning('itm:mechanism:Failed', '%d of %d links failed and are NaN; see err_msg. First: %s', ...
            nnz(failed), n, err_msg(find(failed, 1)));
    end
end
end
