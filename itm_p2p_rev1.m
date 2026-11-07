function [A_db, info] = itm_p2p_rev1(h_tx_m, h_rx_m, pfl, f_mhz, reliability, options)
%ITM_P2P_REV1 NTIA Irregular Terrain Model (ITM) v1.4, point-to-point mode.
%   A_db = ITM_P2P_REV1(h_tx_m, h_rx_m, pfl, f_mhz, reliability) returns the
%   basic transmission loss, in dB, for each reliability percentage. The
%   output has the same size as reliability. The link geometry is computed
%   once and only the variability step is evaluated per reliability value.
%
%   The computation is in private/itm_p2p_core.m. It is a line-by-line port of the NTIA/ITS C++ reference
%   implementation (https://github.com/NTIA/itm, ITM v1.4, ITM_P2P_CR and
%   ITM_P2P_TLS). Results match the C++ to floating-point precision; see
%   tests/test_itm_p2p_rev1.m.
%
%   Inputs:
%     h_tx_m       Structural height of the transmitter above ground (m)
%     h_rx_m       Structural height of the receiver above ground (m)
%     pfl          Terrain profile in ITM PFL format, from TX to RX:
%                  [np, xi_m, z_0, z_1, ..., z_np], where np is the number
%                  of intervals, xi_m is the point spacing (m), and z_k is
%                  the terrain elevation (m). numel(pfl) must be np + 3.
%     f_mhz        Frequency (MHz), 20 to 20000
%     reliability  Time percentage, 0 < reliability < 100, any size
%
%   Name-value options (defaults follow NTIA and WInnForum practice):
%     confidence   Situation percentage, 0 < confidence < 100 (50). Any
%                  size compatible with reliability under implicit
%                  expansion: a column of reliabilities and a row of
%                  confidences returns a reliability-by-confidence table.
%     location     Location percentage (50). Point-to-point CR mode holds
%                  location at 50; set it only to reproduce TLS runs.
%     climate      Radio climate code 1-7 (5, continental temperate):
%                  1 equatorial, 2 continental subtropical, 3 maritime
%                  subtropical, 4 desert, 5 continental temperate,
%                  6 maritime temperate over land, 7 maritime temperate
%                  over sea
%     N_0          Sea-level surface refractivity, N-units (301)
%     polarization 0 horizontal, 1 vertical (1)
%     epsilon      Ground relative permittivity (25)
%     sigma        Ground conductivity, S/m (0.02)
%     mdvar        Mode of variability (13): 0 single message, 1
%                  accidental, 2 mobile, 3 broadcast; add 10 to remove
%                  location variability, add 20 to remove situation
%                  variability
%
%   Outputs:
%     A_db   Basic transmission loss (dB), size of reliability .* confidence
%     info   Struct of ITM intermediate values: A_fs_db, A_ref_db, d_km,
%            delta_h_m, d_hzn_m, h_e_m, theta_hzn_rad, N_s, mode,
%            mode_name, warnings (bitmask per output element, uint32) and
%            warning_messages (cell array of unique warnings)
%
%   Errors use identifiers of the form itm:<Name> and quote the C++ error
%   code, for example itm:InvalidReliability (1007).
%
%   Example:
%     pfl = [100, 100, zeros(1, 101)];          % 10 km flat path
%     L = itm_p2p_rev1(30, 10, pfl, 2700, [1 10 50 90 99])
%
%   See also itm_pathloss_rev1, itm_terrain_profile_rev1.

arguments
    h_tx_m (1,1) double {mustBeReal, mustBeFinite}
    h_rx_m (1,1) double {mustBeReal, mustBeFinite}
    pfl double {mustBeVector, mustBeReal, mustBeFinite}
    f_mhz (1,1) double {mustBeReal, mustBeFinite}
    reliability double {mustBeReal, mustBeFinite, mustBeNonempty}
    options.confidence double {mustBeReal, mustBeFinite, mustBeNonempty} = 50
    options.location (1,1) double {mustBeReal, mustBeFinite} = 50
    options.climate (1,1) double {mustBeReal, mustBeFinite} = 5
    options.N_0 (1,1) double {mustBeReal, mustBeFinite} = 301
    options.polarization (1,1) double {mustBeReal, mustBeFinite} = 1
    options.epsilon (1,1) double {mustBeReal, mustBeFinite} = 25
    options.sigma (1,1) double {mustBeReal, mustBeFinite} = 0.02
    options.mdvar (1,1) double {mustBeReal, mustBeFinite} = 13
end

[A_db, info] = itm_p2p_core(h_tx_m, h_rx_m, pfl, f_mhz, reliability, options.confidence, ...
    options.location, options.climate, options.N_0, options.polarization, options.epsilon, ...
    options.sigma, options.mdvar, nargout > 1);
end
