function [A_db, info] = itm_area_rev1(h_tx_m, h_rx_m, d_km, delta_h_m, f_mhz, reliability, options)
%ITM_AREA_REV1 NTIA Irregular Terrain Model (ITM) v1.4, area mode.
%   A_db = ITM_AREA_REV1(h_tx_m, h_rx_m, d_km, delta_h_m, f_mhz, reliability)
%   returns the basic transmission loss, in dB, with no terrain profile.
%   Area mode estimates the horizon geometry from the path distance, the
%   terrain irregularity parameter delta_h, and how carefully each terminal
%   is sited, so it needs no terrain data and runs offline.
%
%   The computation is a line-by-line port of the NTIA/ITS C++ reference
%   implementation (https://github.com/NTIA/itm, ITM v1.4, ITM_AREA_TLS_Ex
%   and ITM_AREA_CR_Ex, InitializeArea). It shares private/itm_p2p_core.m
%   with itm_p2p_rev1. Results match the C++ to floating-point precision;
%   see tests/test_itm_area_rev1.m.
%
%   Inputs:
%     h_tx_m       Structural height of the transmitter above ground (m)
%     h_rx_m       Structural height of the receiver above ground (m)
%     d_km         Path distance (km), > 0. A vector gives one row of the
%                  output per distance.
%     delta_h_m    Terrain irregularity parameter (m), >= 0: the
%                  interdecile range of terrain heights. Typical values
%                  (NTIA Report 82-100): 0 water or very smooth plains,
%                  30 smooth plains, 90 average terrain and rolling plains,
%                  200 hills, 500 mountains, 700 rugged mountains.
%     f_mhz        Frequency (MHz), 20 to 20000
%     reliability  Time percentage, 0 < reliability < 100
%
%   Name-value options:
%     tx_siting    Siting criteria of the transmitter (0): 0 random,
%                  1 careful, 2 very careful. Careful and very careful
%                  siting raise the effective height on rough terrain
%                  [Algorithm, Eqn 3.2].
%     rx_siting    Siting criteria of the receiver (0)
%     confidence   Situation percentage, 0 < confidence < 100 (50). Any
%                  size compatible with reliability under implicit
%                  expansion.
%     location     Location percentage (50). ITM_AREA_CR holds location at
%                  50; set it for TLS-style area predictions (with an mdvar
%                  below 10, which keeps location variability).
%     climate      Radio climate code 1-7 (5, continental temperate); see
%                  itm_p2p_rev1
%     N_0          Surface refractivity, N-units (301). Area mode uses it
%                  directly as N_s (system elevation 0).
%     polarization 0 horizontal, 1 vertical (1)
%     epsilon      Ground relative permittivity (25)
%     sigma        Ground conductivity, S/m (0.02)
%     mdvar        Mode of variability (3): 0 single message, 1 accidental,
%                  2 mobile, 3 broadcast; add 10 to remove location
%                  variability, add 20 to remove situation variability.
%                  The default keeps location variability, unlike
%                  itm_p2p_rev1 (13); at location = 50 the two agree to
%                  within 10^-5 dB.
%     validity     "error", "warn", or "off" ("error"), as in
%                  itm_p2p_rev1: paths shorter than 1 km or longer than
%                  2000 km raise itm:validity:Distance, and inputs near
%                  their limits raise itm:validity:Caution.
%
%   Outputs:
%     A_db   Basic transmission loss (dB). For a scalar d_km, the size of
%            reliability .* confidence. For a vector d_km, numel(d_km) rows,
%            one column per element of reliability .* confidence.
%     info   Struct (one element per distance) of ITM intermediate values,
%            as in itm_p2p_rev1: A_fs_db, A_ref_db, d_km, delta_h_m,
%            d_hzn_m, h_e_m, theta_hzn_rad, N_s, mode, mode_name, warnings,
%            warning_messages, A_ref_undefined, and lines. In area mode
%            h_e_m, d_hzn_m, and theta_hzn_rad are the InitializeArea
%            estimates, and elevation_deg is theta_hzn_rad in degrees.
%
%   Errors use identifiers of the form itm:<Name> and quote the C++ error
%   code, for example itm:InvalidDeltaH (1018).
%
%   Example:
%     d = (1:100)';                               % 1 to 100 km
%     L = itm_area_rev1(30, 10, d, 90, 2700, [10 50 90], tx_siting=1);
%     plot(d, L)
%
%   See also itm_p2p_rev1, itm_pathloss_rev1.

arguments
    h_tx_m (1,1) double {mustBeReal, mustBeFinite}
    h_rx_m (1,1) double {mustBeReal, mustBeFinite}
    d_km double {mustBeVector, mustBeReal, mustBeFinite}
    delta_h_m (1,1) double {mustBeReal, mustBeFinite}
    f_mhz (1,1) double {mustBeReal, mustBeFinite}
    reliability double {mustBeReal, mustBeFinite, mustBeNonempty}
    options.tx_siting (1,1) double {mustBeReal, mustBeFinite} = 0
    options.rx_siting (1,1) double {mustBeReal, mustBeFinite} = 0
    options.confidence double {mustBeReal, mustBeFinite, mustBeNonempty} = 50
    options.location (1,1) double {mustBeReal, mustBeFinite} = 50
    options.climate (1,1) double {mustBeReal, mustBeFinite} = 5
    options.N_0 (1,1) double {mustBeReal, mustBeFinite} = 301
    options.polarization (1,1) double {mustBeReal, mustBeFinite} = 1
    options.epsilon (1,1) double {mustBeReal, mustBeFinite} = 25
    options.sigma (1,1) double {mustBeReal, mustBeFinite} = 0.02
    options.mdvar (1,1) double {mustBeReal, mustBeFinite} = 3
    options.validity (1,1) string {mustBeMember(options.validity, ["error", "warn", "off"])} = "error"
end

want_info = nargout > 1;
geom = struct('d_km', d_km(1), 'delta_h_m', delta_h_m, 'siting', [options.tx_siting, options.rx_siting]);
z = itm_percentiles(reliability, options.confidence, options.location);
for k = numel(d_km):-1:1                  % backward: preallocates A_db and info
    geom.d_km = d_km(k);
    [A, ik, wbits] = itm_p2p_core(h_tx_m, h_rx_m, geom, f_mhz, reliability, options.confidence, ...
        options.location, options.climate, options.N_0, options.polarization, options.epsilon, ...
        options.sigma, options.mdvar, want_info, z);
    itm_validity(wbits, d_km(k), options.validity);
    if isscalar(d_km)
        A_db = A;
    else
        A_db(k, :) = A(:).';
    end
    if want_info
        info(k) = ik;
    end
end
if want_info
    info = reshape(info, size(d_km));
end
end
