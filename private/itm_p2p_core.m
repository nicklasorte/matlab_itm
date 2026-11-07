function [A_db, info] = itm_p2p_core(h_tx_m, h_rx_m, pfl, f_mhz, reliability, confidence, ...
    location, climate, N_0, polarization, epsilon, sigma, mdvar, want_info, z)
%ITM_P2P_CORE ITM v1.4 point-to-point computation without argument parsing.
%   Called by itm_p2p_rev1 (after its arguments block) and, once per link,
%   by itm_pathloss_rev1, which validates its own inputs once per call.
%   The arguments block costs about 0.4 ms, a fifth of a core call, so
%   skipping it per link matters for many-link runs. Inputs are positional;
%   see itm_p2p_rev1 for their meaning. want_info builds the info struct.
%   The NTIA input checks (ValidateInputs.cpp) still run here on every
%   call. z, optional, holds the percentages already validated and
%   converted to normal deviates by itm_percentiles; itm_pathloss_rev1
%   passes it so a reliability array is converted once, not once per link.

info = [];
pfl = pfl(:);
validate_profile(pfl);

% CR mode maps reliability to time and confidence to situation
% (ITM_P2P_CR calls ITM_P2P_TLS with time = reliability, location = 50,
% situation = confidence).
warnings = validate_inputs(h_tx_m, h_rx_m, climate, N_0, f_mhz, polarization, ...
    epsilon, sigma, mdvar);
if nargin < 15 || isempty(z)
    z = itm_percentiles(reliability, confidence, location);
end
out_size = z.size;

% Terrain-averaged system height over the middle 80 percent of the path
np = fix(pfl(1));
p10 = fix(0.1 * np);
h_acc = cumsum(pfl((p10:np - p10) + 3));     % sequential, like the C++ loop
h_sys_m = h_acc(end) / (np - 2 * p10 + 1);

[Z_g, gamma_e, N_s] = initialize_point_to_point(f_mhz, h_sys_m, N_0, ...
    polarization, epsilon, sigma);

h_m = [h_tx_m, h_rx_m];
[theta_hzn, d_hzn_m, h_e_m, delta_h_m, d_m] = quick_pfl(pfl, gamma_e, h_m);

[A_ref_db, warnings, propmode] = longley_rice(theta_hzn, f_mhz, Z_g, d_hzn_m, h_e_m, ...
    gamma_e, N_s, delta_h_m, h_m, d_m, warnings);

A_fs_db = free_space_loss(d_m, f_mhz);

if want_info
    [V_db, extreme] = variability(z, h_e_m, delta_h_m, f_mhz, d_m, A_ref_db, climate, mdvar);
else
    V_db = variability(z, h_e_m, delta_h_m, f_mhz, d_m, A_ref_db, climate, mdvar);
end
if numel(V_db) ~= prod(out_size)
    % Scalar deviates (for example single-message mode, which ignores
    % time) give one value for every requested percentage
    V_db = V_db + zeros(out_size);
end
A_db = reshape(V_db + A_fs_db, out_size);

if want_info
    extreme = extreme | false(out_size);
    w = uint32(warnings) + zeros(out_size, 'uint32');
    w(extreme) = bitor(w(extreme), uint32(8192));
    mode_names = ["Line of Sight", "Diffraction", "Troposcatter"];
    info = struct( ...
        'A_fs_db', A_fs_db, ...
        'A_ref_db', A_ref_db, ...
        'd_km', d_m / 1000, ...
        'delta_h_m', delta_h_m, ...
        'd_hzn_m', d_hzn_m, ...
        'h_e_m', h_e_m, ...
        'theta_hzn_rad', theta_hzn, ...
        'N_s', N_s, ...
        'mode', propmode, ...
        'mode_name', mode_names(propmode), ...
        'warnings', reshape(w, out_size), ...
        'warning_messages', {warning_messages(bitor(uint32(warnings), uint32(any(extreme(:))) * uint32(8192)))});
end
end


%% ------------------------------------------------------------------------
%  Input validation (ValidateInputs.cpp)
%  ------------------------------------------------------------------------
function validate_profile(pfl)
if ~all(isfinite(pfl))
    error('itm:InvalidProfile', 'pfl must contain only finite values.');
end
if numel(pfl) < 4
    error('itm:InvalidProfile', 'pfl must be [np, xi, z_0, ..., z_np] with np >= 1.');
end
np = pfl(1);
if np < 1 || np ~= fix(np)
    error('itm:InvalidProfile', 'pfl(1) (number of intervals) must be a positive integer.');
end
if pfl(2) <= 0
    error('itm:InvalidProfile', 'pfl(2) (point spacing) must be positive.');
end
if numel(pfl) ~= np + 3
    error('itm:InvalidProfile', ...
        'numel(pfl) is %d but pfl(1) = %d intervals requires %d elements.', numel(pfl), np, np + 3);
end
end

function warnings = validate_inputs(h_tx, h_rx, climate, N_0, f, pol, epsilon, sigma, mdvar)
% Percentages (time, location, situation) are checked in itm_percentiles
warnings = 0;
if h_tx < 1.0 || h_tx > 1000.0
    warnings = bitor(warnings, 1);
end
if h_tx < 0.5 || h_tx > 3000.0
    itm_error(1000);
end
if h_rx < 1.0 || h_rx > 1000.0
    warnings = bitor(warnings, 2);
end
if h_rx < 0.5 || h_rx > 3000.0
    itm_error(1001);
end
if climate < 1 || climate > 7 || climate ~= fix(climate)
    itm_error(1002);
end
if N_0 < 250 || N_0 > 400
    itm_error(1008);
end
if f < 40.0 || f > 10000.0
    warnings = bitor(warnings, 4);
end
if f < 20 || f > 20000
    itm_error(1009);
end
if pol ~= 0 && pol ~= 1
    itm_error(1010);
end
if epsilon < 1
    itm_error(1011);
end
if sigma <= 0
    itm_error(1012);
end
if mdvar < 0 || mdvar > 33 || mdvar ~= fix(mdvar) || mod(mdvar, 10) > 3
    itm_error(1014);
end
end

function itm_error(code)
switch code
    case 1000, id = 'InvalidTxHeight';       msg = 'TX terminal height must be 0.5 to 3000 m.';
    case 1001, id = 'InvalidRxHeight';       msg = 'RX terminal height must be 0.5 to 3000 m.';
    case 1002, id = 'InvalidClimate';        msg = 'Radio climate must be an integer 1 to 7.';
    case 1004, id = 'InvalidLocation';       msg = 'Location percentage must be in (0, 100).';
    case 1006, id = 'InvalidConfidence';     msg = 'Confidence percentage must be in (0, 100).';
    case 1007, id = 'InvalidReliability';    msg = 'Reliability percentage must be in (0, 100).';
    case 1008, id = 'InvalidRefractivity';   msg = 'Refractivity N_0 must be 250 to 400 N-units.';
    case 1009, id = 'InvalidFrequency';      msg = 'Frequency must be 20 to 20000 MHz.';
    case 1010, id = 'InvalidPolarization';   msg = 'Polarization must be 0 (horizontal) or 1 (vertical).';
    case 1011, id = 'InvalidEpsilon';        msg = 'Relative permittivity epsilon must be >= 1.';
    case 1012, id = 'InvalidSigma';          msg = 'Conductivity sigma must be > 0.';
    case 1013, id = 'GroundImpedance';       msg = 'Imaginary part of the ground impedance exceeds the real part.';
    case 1014, id = 'InvalidMdvar';          msg = 'Mode of variability must be 0-3, 10-13, 20-23, or 30-33.';
    case 1016, id = 'EffectiveEarth';        msg = 'Internally computed effective earth radius is out of range.';
    case 1021, id = 'SurfaceRefractivitySmall'; msg = 'Internally computed surface refractivity is below 150 N-units.';
    case 1022, id = 'SurfaceRefractivityLarge'; msg = 'Internally computed surface refractivity is above 400 N-units.';
    otherwise, id = 'Unknown';               msg = 'Unknown ITM error.';
end
error(['itm:' id], 'ITM error %d: %s', code, msg);
end

function msgs = warning_messages(w)
bits = 2 .^ (0:14)';     % 0x0001 ... 0x4000
text = { ...
    'TX terminal height is near its limits', ...
    'RX terminal height is near its limits', ...
    'Frequency is near its limits', ...
    'Path distance is near its upper limit', ...
    'Path distance is large - care must be taken with result', ...
    'Path distance is near its lower limit', ...
    'Path distance is small - care must be taken with result', ...
    'TX horizon angle is large - small angle approximations could break down', ...
    'RX horizon angle is large - small angle approximations could break down', ...
    'TX horizon distance is less than 1/10 of the smooth earth horizon distance', ...
    'RX horizon distance is less than 1/10 of the smooth earth horizon distance', ...
    'TX horizon distance is greater than 3 times the smooth earth horizon distance', ...
    'RX horizon distance is greater than 3 times the smooth earth horizon distance', ...
    'One of the provided variabilities is located far in the tail of its distribution', ...
    'Internally computed surface refractivity value is small - care must be taken with result'};
msgs = text(logical(bitand(uint32(w), uint32(bits))))';
end

%% ------------------------------------------------------------------------
%  Initialization (InitializePointToPoint.cpp)
%  ------------------------------------------------------------------------
function [Z_g, gamma_e, N_s] = initialize_point_to_point(f_mhz, h_sys_m, N_0, pol, epsilon, sigma)
gamma_a = 157e-9;
if h_sys_m == 0.0
    N_s = N_0;
else
    N_s = N_0 * exp(-h_sys_m / 9460.0);
end
gamma_e = gamma_a * (1.0 - 0.04665 * exp(N_s / 179.3));
ep_r = complex(epsilon, 18000 * sigma / f_mhz);
Z_g = sqrt(ep_r - 1.0);
if pol == 1
    Z_g = Z_g / ep_r;
end
end

%% ------------------------------------------------------------------------
%  Terrain processing (QuickPfl.cpp, FindHorizons.cpp, ComputeDeltaH.cpp,
%  LinearLeastSquaresFit.cpp). pfl is 1-based here: C++ pfl[j] is pfl(j+1).
%  ------------------------------------------------------------------------
function [theta_hzn, d_hzn_m, h_e_m, delta_h_m, d_m] = quick_pfl(pfl, gamma_e, h_m)
d_m = pfl(1) * pfl(2);
np = fix(pfl(1));
a_e = 1 / gamma_e;
[theta_hzn, d_hzn_m] = find_horizons(pfl, a_e, h_m);

d_start_m = min(15.0 * h_m(1), 0.1 * d_hzn_m(1));
d_end_m = d_m - min(15.0 * h_m(2), 0.1 * d_hzn_m(2));
delta_h_m = compute_delta_h(pfl, d_start_m, d_end_m);

h_e_m = zeros(1, 2);
if d_hzn_m(1) + d_hzn_m(2) > 1.5 * d_m
    % Well within line of sight: horizons from the smooth-earth fit
    [fit_tx, fit_rx] = linear_least_squares_fit(pfl, d_start_m, d_end_m);
    h_e_m(1) = h_m(1) + fdim(pfl(3), fit_tx);
    h_e_m(2) = h_m(2) + fdim(pfl(np + 3), fit_rx);
    d_hzn_m = sqrt(2.0 * h_e_m * a_e) .* exp(-0.07 * sqrt(delta_h_m ./ max(h_e_m, 5.0)));
    combined = d_hzn_m(1) + d_hzn_m(2);
    if combined <= d_m
        h_e_m = h_e_m * (d_m / combined)^2;
        d_hzn_m = sqrt(2.0 * h_e_m * a_e) .* exp(-0.07 * sqrt(delta_h_m ./ max(h_e_m, 5.0)));
    end
    q = sqrt(2.0 * h_e_m * a_e);
    theta_hzn = (0.65 * delta_h_m * (q ./ d_hzn_m - 1.0) - 2.0 * h_e_m) ./ q;
else
    [fit_tx, ~] = linear_least_squares_fit(pfl, d_start_m, 0.9 * d_hzn_m(1));
    h_e_m(1) = h_m(1) + fdim(pfl(3), fit_tx);
    [~, fit_rx] = linear_least_squares_fit(pfl, d_m - 0.9 * d_hzn_m(2), d_end_m);
    h_e_m(2) = h_m(2) + fdim(pfl(np + 3), fit_rx);
end
end

function [theta_hzn, d_hzn_m] = find_horizons(pfl, a_e, h_m)
% Vectorized horizon search. Distances use cumsum, which adds in sequence
% exactly like the C++ loop (d += xi); k*xi rounds differently, and
% downstream integer truncation (for example 0.9*d_hzn/xi) is sensitive
% to that last bit. max() returns the first maximum, matching the C++
% strict > comparison.
np = fix(pfl(1));
xi = pfl(2);
d_m = pfl(1) * pfl(2);
z_tx = pfl(3) + h_m(1);
z_rx = pfl(np + 3) + h_m(2);
theta_hzn = [(z_rx - z_tx) / d_m - d_m / (2 * a_e), -(z_rx - z_tx) / d_m - d_m / (2 * a_e)];
d_hzn_m = [d_m, d_m];
if np < 2
    return
end
d_tx = cumsum(repmat(xi, np - 1, 1));
d_rx = cumsum([d_m; repmat(-xi, np - 1, 1)]);
d_rx = d_rx(2:end);
z = pfl((1:np - 1)' + 3);
[theta_tx, i_tx] = max((z - z_tx) ./ d_tx - d_tx / (2 * a_e));
[theta_rx, i_rx] = max(-(z_rx - z) ./ d_rx - d_rx / (2 * a_e));
if theta_tx > theta_hzn(1)
    theta_hzn(1) = theta_tx;
    d_hzn_m(1) = d_tx(i_tx);
end
if theta_rx > theta_hzn(2)
    theta_hzn(2) = theta_rx;
    d_hzn_m(2) = d_rx(i_rx);
end
end

function delta_h_m = compute_delta_h(pfl, d_start_m, d_end_m)
% Terrain irregularity: interdecile range of the profile about a linear
% fit, over n evenly spaced resampled points.
np = fix(pfl(1));
x_start = d_start_m / pfl(2);
x_end = d_end_m / pfl(2);
if x_end - x_start < 2.0
    delta_h_m = 0;
    return
end
p10 = fix(0.1 * (x_end - x_start + 8.0));
p10 = min(max(4, p10), 25);
n = 10 * p10 - 5;
p90 = n - p10;
np_s = n - 1;
% Resample the profile at n evenly spaced points. The C++ steps a
% fractional position x_start by `step` and, after each step, decrements
% it by 1 (advancing the profile index i) while it is positive. All but
% the last decrement are exact, and IEEE subtraction rounds the same exact
% result, so one subtraction of m = ceil(x_start) reproduces the inner
% loop bit for bit. The outer recurrence (at most 245 steps) stays a loop
% because each step's rounding depends on the previous position.
s = zeros(n + 2, 1);
s(1) = np_s;
s(2) = 1.0;
step = (x_end - x_start) / np_s;
i = fix(x_start);
x_start = x_start - double(single(i + 1.0));   % C++ casts (i + 1.0) to float
idx = zeros(n, 1);
pos = zeros(n, 1);
for j = 1:n
    if x_start > 0.0
        m = min(ceil(x_start), np - 1 - i);
        if m > 0
            x_start = x_start - m;
            i = i + m;
        end
    end
    idx(j) = i;
    pos(j) = x_start;
    x_start = x_start + step;
end
z_hi = pfl(idx + 4);
s(3:n + 2) = z_hi + (z_hi - pfl(idx + 3)) .* pos;
[fit_y1, fit_y2] = linear_least_squares_fit(s, 0.0, np_s);
fit_y2 = (fit_y2 - fit_y1) / np_s;
fit_line = cumsum([fit_y1; repmat(fit_y2, n - 1, 1)]);   % C++: y += fit_y2
diffs = s(3:n + 2) - fit_line;
sorted = sort(diffs, 'descend');      % nth_element with std::greater
q10 = sorted(p10);
q90 = sorted(p90 + 1);
delta_h_d_m = q10 - q90;
delta_h_m = delta_h_d_m / (1.0 - 0.8 * exp(-(d_end_m - d_start_m) / 50e3));
end

function [fit_y1, fit_y2] = linear_least_squares_fit(pfl, d_start, d_end)
% Least-squares line through pfl elevations between d_start and d_end,
% evaluated at the two profile ends (trapezoidal end weights, as in C++).
np = fix(pfl(1));
i_start = fix(fdim(d_start / pfl(2), 0.0));
i_end = np - fix(fdim(np, d_end / pfl(2)));
if i_end <= i_start
    i_start = fix(fdim(i_start, 1.0));
    i_end = np - fix(fdim(np, i_end + 1.0));
end
x_length = i_end - i_start;
mid_shifted_end = i_end - 0.5 * x_length;
y_s = pfl(i_start + 3);
y_e = pfl(i_end + 3);
inner = pfl((i_start + 1:i_end - 1) + 3);
m = -0.5 * x_length + (1:x_length - 1)';
% cumsum(...)(end) adds in the same order as the C++ loop; sum() may not.
acc_y = cumsum([0.5 * (y_s + y_e); inner]);
acc_s = cumsum([0.5 * (y_s - y_e) * (-0.5 * x_length); inner .* m]);
sum_y = acc_y(end);
scaled_sum_y = acc_s(end);
sum_y = sum_y / x_length;
scaled_sum_y = scaled_sum_y * 12.0 / ((x_length * x_length + 2.0) * x_length);
fit_y1 = sum_y - scaled_sum_y * mid_shifted_end;
fit_y2 = sum_y + scaled_sum_y * (np - mid_shifted_end);
end

function v = fdim(x, y)
% C fdim: positive difference
v = max(x - y, 0);
end

%% ------------------------------------------------------------------------
%  Reference attenuation (LongleyRice.cpp)
%  ------------------------------------------------------------------------
function [A_ref_db, warnings, propmode] = longley_rice(theta_hzn, f_mhz, Z_g, d_hzn_m, h_e_m, ...
    gamma_e, N_s, delta_h_m, h_m, d_m, warnings)
a_e = 1 / gamma_e;
d_hzn_s = sqrt(2.0 * h_e_m * a_e);
d_sML = d_hzn_s(1) + d_hzn_s(2);
d_ML = d_hzn_m(1) + d_hzn_m(2);
theta_los = -max(theta_hzn(1) + theta_hzn(2), -d_ML / a_e);

if abs(theta_hzn(1)) > 200e-3, warnings = bitor(warnings, 128); end
if abs(theta_hzn(2)) > 200e-3, warnings = bitor(warnings, 256); end
if d_hzn_m(1) < 0.1 * d_hzn_s(1), warnings = bitor(warnings, 512); end
if d_hzn_m(2) < 0.1 * d_hzn_s(2), warnings = bitor(warnings, 1024); end
if d_hzn_m(1) > 3.0 * d_hzn_s(1), warnings = bitor(warnings, 2048); end
if d_hzn_m(2) > 3.0 * d_hzn_s(2), warnings = bitor(warnings, 4096); end

if N_s < 150, itm_error(1021); end
if N_s > 400, itm_error(1022); end
if N_s < 250, warnings = bitor(warnings, 16384); end
if a_e < 4000000 || a_e > 13333333, itm_error(1016); end
if real(Z_g) <= abs(imag(Z_g)), itm_error(1013); end

d_3 = max(d_sML, d_ML + 5.0 * (a_e^2 / f_mhz)^(1.0 / 3.0));
d_4 = d_3 + 10.0 * (a_e^2 / f_mhz)^(1.0 / 3.0);
A_3 = diffraction_loss(d_3, d_hzn_m, h_e_m, Z_g, a_e, delta_h_m, h_m, theta_los, d_sML, f_mhz);
A_4 = diffraction_loss(d_4, d_hzn_m, h_e_m, Z_g, a_e, delta_h_m, h_m, theta_los, d_sML, f_mhz);
M_d = (A_4 - A_3) / (d_4 - d_3);
A_d0 = A_3 - M_d * d_3;

d_min = abs(h_e_m(1) - h_e_m(2)) / 200e-3;
if d_m < d_min,   warnings = bitor(warnings, 32); end
if d_m < 1e3,     warnings = bitor(warnings, 64); end
if d_m > 1000e3,  warnings = bitor(warnings, 8); end
if d_m > 2000e3,  warnings = bitor(warnings, 16); end

if d_m < d_sML
    % Line-of-sight region
    A_sML = d_sML * M_d + A_d0;
    d_0 = 0.04 * f_mhz * h_e_m(1) * h_e_m(2);
    if A_d0 >= 0.0
        d_0 = min(d_0, 0.5 * d_ML);
        d_1 = d_0 + 0.25 * (d_ML - d_0);
    else
        d_1 = max(-A_d0 / M_d, 0.25 * d_ML);
    end
    A_1 = line_of_sight_loss(d_1, h_e_m, Z_g, delta_h_m, M_d, A_d0, d_sML, f_mhz);
    flag = false;
    kHat_1 = 0;
    kHat_2 = 0;
    if d_0 < d_1
        A_0 = line_of_sight_loss(d_0, h_e_m, Z_g, delta_h_m, M_d, A_d0, d_sML, f_mhz);
        q = log(d_sML / d_0);
        kHat_2 = max(0.0, ((d_sML - d_0) * (A_1 - A_0) - (d_1 - d_0) * (A_sML - A_0)) / ...
            ((d_sML - d_0) * log(d_1 / d_0) - (d_1 - d_0) * q));
        flag = A_d0 > 0.0 || kHat_2 > 0.0;
        if flag
            kHat_1 = (A_sML - A_0 - kHat_2 * q) / (d_sML - d_0);
            if kHat_1 < 0.0
                kHat_1 = 0.0;
                kHat_2 = fdim(A_sML, A_0) / q;
                if kHat_2 == 0.0
                    kHat_1 = M_d;
                end
            end
        end
    end
    if ~flag
        kHat_1 = fdim(A_sML, A_1) / (d_sML - d_1);
        kHat_2 = 0.0;
        if kHat_1 == 0.0
            kHat_1 = M_d;
        end
    end
    A_o = A_sML - kHat_1 * d_sML - kHat_2 * log(d_sML);
    A_ref_db = A_o + kHat_1 * d_m + kHat_2 * log(d_m);
    propmode = 1;
else
    % Transhorizon: diffraction or troposcatter
    d_5 = d_ML + 200e3;
    d_6 = d_ML + 400e3;
    h0 = -1;
    [A_6, h0] = troposcatter_loss(d_6, theta_hzn, d_hzn_m, h_e_m, a_e, N_s, f_mhz, theta_los, h0);
    A_5 = troposcatter_loss(d_5, theta_hzn, d_hzn_m, h_e_m, a_e, N_s, f_mhz, theta_los, h0);
    if A_5 < 1000.0
        M_s = (A_6 - A_5) / 200e3;
        d_x = max(max(d_sML, d_ML + 1.088 * (a_e^2 / f_mhz)^(1.0 / 3.0) * log(f_mhz)), ...
            (A_5 - A_d0 - M_s * d_5) / (M_d - M_s));
        A_s0 = (M_d - M_s) * d_x + A_d0;
    else
        M_s = M_d;
        A_s0 = A_d0;
        d_x = 10e6;
    end
    if d_m > d_x
        A_ref_db = M_s * d_m + A_s0;
        propmode = 3;
    else
        A_ref_db = M_d * d_m + A_d0;
        propmode = 2;
    end
end
A_ref_db = max(A_ref_db, 0.0);
end

function A_d = diffraction_loss(d_m, d_hzn_m, h_e_m, Z_g, a_e, delta_h_m, h_m, theta_los, d_sML, f_mhz)
A_k = knife_edge_diffraction(d_m, f_mhz, a_e, theta_los, d_hzn_m);
A_se = smooth_earth_diffraction(d_m, f_mhz, a_e, theta_los, d_hzn_m, h_e_m, Z_g);
delta_h_dsML = terrain_roughness(d_sML, delta_h_m);
sigma_h_d = sigma_h_function(delta_h_dsML);
A_fo = min(15.0, 5 * log10(1.0 + 1e-5 * h_m(1) * h_m(2) * f_mhz * sigma_h_d));
delta_h_d = terrain_roughness(d_m, delta_h_m);
q = h_m(1) * h_m(2);
qk = h_e_m(1) * h_e_m(2) - q;
q = q + 10.0;                                   % point-to-point mode
term1 = sqrt(1.0 + qk / q);
d_ML = d_hzn_m(1) + d_hzn_m(2);
q = (term1 + (-theta_los * a_e + d_ML) / d_m) * min(delta_h_d * f_mhz / 47.7, 6283.2);
w = 25.1 / (25.1 + sqrt(q));
A_d = w * A_se + (1.0 - w) * A_k + A_fo;
end

function A_k = knife_edge_diffraction(d_m, f_mhz, a_e, theta_los, d_hzn_m)
d_ML = d_hzn_m(1) + d_hzn_m(2);
theta_nlos = d_m / a_e - theta_los;
d_nlos = d_m - d_ML;
v_1 = 0.0795775 * (f_mhz / 47.7) * theta_nlos^2 * d_hzn_m(1) * d_nlos / (d_nlos + d_hzn_m(1));
v_2 = 0.0795775 * (f_mhz / 47.7) * theta_nlos^2 * d_hzn_m(2) * d_nlos / (d_nlos + d_hzn_m(2));
A_k = fresnel_integral(v_1) + fresnel_integral(v_2);
end

function A = fresnel_integral(v2)
if v2 < 5.76
    A = 6.02 + 9.11 * sqrt(v2) - 1.27 * v2;
else
    A = 12.953 + 10 * log10(v2);
end
end

function A_se = smooth_earth_diffraction(d_m, f_mhz, a_e, theta_los, d_hzn_m, h_e_m, Z_g)
a_0 = 6370e3;
THIRD = 1.0 / 3.0;
theta_nlos = d_m / a_e - theta_los;
d_ML = d_hzn_m(1) + d_hzn_m(2);
a_m = [(d_m - d_ML) / (d_m / a_e - theta_los), ...
    0.5 * d_hzn_m(1)^2 / h_e_m(1), ...
    0.5 * d_hzn_m(2)^2 / h_e_m(2)];
d_km = [(a_m(1) * theta_nlos) / 1000.0, d_hzn_m(1) / 1000.0, d_hzn_m(2) / 1000.0];
C_0 = ((4.0 / 3.0) * a_0 ./ a_m).^THIRD;
K = 0.017778 * C_0 * f_mhz^(-THIRD) / abs(Z_g);
B_0 = 1.607 - K;
x_km = zeros(1, 3);
x_km(2) = B_0(2) * C_0(2)^2 * f_mhz^THIRD * d_km(2);
x_km(3) = B_0(3) * C_0(3)^2 * f_mhz^THIRD * d_km(3);
x_km(1) = B_0(1) * C_0(1)^2 * f_mhz^THIRD * d_km(1) + x_km(2) + x_km(3);
F_x_1 = height_function(x_km(2), K(2));
F_x_2 = height_function(x_km(3), K(3));
G_x = 0.05751 * x_km(1) - 10.0 * log10(x_km(1));
A_se = G_x - F_x_1 - F_x_2 - 20;
end

function result = height_function(x_km, K)
if x_km < 200.0
    w = -log(K);
    if K < 1e-5 || x_km * w^3 > 5495.0
        result = -117.0;
        if x_km > 1.0
            result = 17.372 * log(x_km) + result;
        end
    else
        result = 2.5e-5 * x_km^2 / K - 8.686 * w - 15.0;
    end
else
    result = 0.05751 * x_km - 4.343 * log(x_km);
    if x_km < 2000
        w = 0.0134 * x_km * exp(-0.005 * x_km);
        result = (1.0 - w) * result + w * (17.372 * log(x_km) - 117.0);
    end
end
end

function A_los = line_of_sight_loss(d_m, h_e_m, Z_g, delta_h_m, M_d, A_d0, d_sML, f_mhz)
delta_h_d = terrain_roughness(d_m, delta_h_m);
sigma_h_d = sigma_h_function(delta_h_d);
wn = f_mhz / 47.7;
sin_psi = (h_e_m(1) + h_e_m(2)) / sqrt(d_m^2 + (h_e_m(1) + h_e_m(2))^2);
R_e = (sin_psi - Z_g) / (sin_psi + Z_g) * exp(-min(10.0, wn * sigma_h_d * sin_psi));
q = real(R_e)^2 + imag(R_e)^2;
if q < 0.25 || q < sin_psi
    R_e = R_e * sqrt(sin_psi / q);
end
delta_phi = wn * 2.0 * h_e_m(1) * h_e_m(2) / d_m;
if delta_phi > pi / 2.0
    delta_phi = pi - (pi / 2.0)^2 / delta_phi;
end
rr = complex(cos(delta_phi), -sin(delta_phi)) + R_e;
A_t = -10 * log10(real(rr)^2 + imag(rr)^2);
A_d = M_d * d_m + A_d0;
w = 1 / (1 + f_mhz * delta_h_m / max(10e3, d_sML));
A_los = w * A_t + (1 - w) * A_d;
end

function [A_scat, h0] = troposcatter_loss(d_m, theta_hzn, d_hzn_m, h_e_m, a_e, N_s, f_mhz, theta_los, h0)
wn = f_mhz / 47.7;
if h0 > 15.0
    H_0 = h0;
else
    ad = d_hzn_m(1) - d_hzn_m(2);
    rr = h_e_m(2) / h_e_m(1);
    if ad < 0.0
        ad = -ad;
        rr = 1.0 / rr;
    end
    theta = theta_hzn(1) + theta_hzn(2) + d_m / a_e;
    r_1 = 2.0 * wn * theta * h_e_m(1);
    r_2 = 2.0 * wn * theta * h_e_m(2);
    if r_1 < 0.2 && r_2 < 0.2
        A_scat = 1001;     % C++ returns without updating h0
        return
    end
    s = (d_m - ad) / (d_m + ad);
    q = min(max(0.1, rr / s), 10.0);
    s = max(0.1, s);
    h_0_m = (d_m - ad) * (d_m + ad) * theta * 0.25 / d_m;
    Z_0 = 1.7556e3;
    Z_1 = 8.0e3;
    eta_s = (h_0_m / Z_0) * (1.0 + (0.031 - N_s * 2.32e-3 + N_s^2 * 5.67e-6) * ...
        exp(-(min(1.7, h_0_m / Z_1))^6));
    H_00 = (h0_function(r_1, eta_s) + h0_function(r_2, eta_s)) / 2;
    Delta_H_0 = min(H_00, 6.0 * (0.6 - log10(max(eta_s, 1.0))) * log10(s) * log10(q));
    H_0 = H_00 + Delta_H_0;
    H_0 = max(H_0, 0.0);
    if eta_s < 1.0
        H_0 = eta_s * H_0 + (1.0 - eta_s) * 10 * log10(((1.0 + sqrt(2) / r_1) * (1.0 + sqrt(2) / r_2))^2 * ...
            (r_1 + r_2) / (r_1 + r_2 + 2 * sqrt(2)));
    end
    if H_0 > 15.0 && h0 >= 0.0
        H_0 = h0;
    end
end
h0 = H_0;
th = d_m / a_e - theta_los;
D_0 = 40e3;
H = 47.7;
A_scat = f_function(th * d_m) + 10 * log10(wn * H * th^4) - 0.1 * (N_s - 301.0) * exp(-th * d_m / D_0) + H_0;
end

function F_0 = f_function(td)
a = [133.4, 104.6, 71.8];
b = [0.332e-3, 0.212e-3, 0.157e-3];
c = [-10, -2.5, 5];
if td <= 10e3
    i = 1;
elseif td <= 70e3
    i = 2;
else
    i = 3;
end
F_0 = a(i) + b(i) * td + c(i) * log10(td);
end

function result = h0_function(r, eta_s)
eta_s = min(max(eta_s, 1), 5);
i = fix(eta_s);
q = eta_s - i;
result = h0_curve(i, r);
if q ~= 0.0
    result = (1.0 - q) * result + q * h0_curve(i + 1, r);
end
end

function h = h0_curve(j, r)
% j is 1-based (C++ index j - 1)
a = [25.0, 80.0, 177.0, 395.0, 705.0];
b = [24.0, 45.0, 68.0, 80.0, 105.0];
h = 10 * log10(1 + a(j) * (1 / r)^4 + b(j) * (1.0 / r)^2);
end

function v = terrain_roughness(d_m, delta_h_m)
v = delta_h_m * (1.0 - 0.8 * exp(-d_m / 50e3));
end

function v = sigma_h_function(delta_h_m)
v = 0.78 * delta_h_m * exp(-0.5 * delta_h_m^0.25);
end

function A = free_space_loss(d_m, f_mhz)
A = 32.45 + 20.0 * log10(f_mhz) + 20.0 * log10(d_m / 1000.0);
end

%% ------------------------------------------------------------------------
%  Variability (Variability.cpp), vectorized over time and situation
%  ------------------------------------------------------------------------
function [result, extreme] = variability(z, h_e_m, delta_h_m, f_mhz, d_m, A_ref_db, climate, mdvar)
% Vectorized over the deviates in z (see itm_percentiles). Scalars stay
% scalars and implicit expansion forms the output, which gives the same
% values as expanding every array to the output size first.
all_year = [ ...
    -9.67,   -0.62,    1.26,   -9.21,   -0.62,   -0.39,      3.15; ...
    12.7,     9.19,   15.5,     9.05,    9.19,    2.86,   857.9; ...
    144.9e3, 228.9e3, 262.6e3,  84.1e3, 228.9e3, 141.7e3, 2222.e3; ...
    190.3e3, 205.2e3, 185.2e3, 101.1e3, 205.2e3, 315.9e3,  164.8e3; ...
    133.8e3, 143.6e3,  99.8e3,  98.6e3, 143.6e3, 167.4e3,  116.3e3];
bsm1 = [2.13, 2.66, 6.11, 1.98, 2.68, 6.86, 8.51];
bsm2 = [159.5, 7.67, 6.65, 13.11, 7.16, 10.38, 169.8];
xsm1 = [762.2e3, 100.4e3, 138.2e3, 139.1e3, 93.7e3, 187.8e3, 609.8e3];
xsm2 = [123.6e3, 172.5e3, 242.2e3, 132.7e3, 186.8e3, 169.6e3, 119.9e3];
xsm3 = [94.5e3, 136.4e3, 178.6e3, 193.5e3, 133.5e3, 108.9e3, 106.6e3];
bsp1 = [2.11, 6.87, 10.08, 3.68, 4.75, 8.58, 8.43];
bsp2 = [102.3, 15.53, 9.60, 159.3, 8.12, 13.97, 8.19];
xsp1 = [636.9e3, 138.7e3, 165.3e3, 464.4e3, 93.2e3, 216.0e3, 136.2e3];
xsp2 = [134.8e3, 143.7e3, 225.7e3, 93.1e3, 135.9e3, 152.0e3, 188.5e3];
xsp3 = [95.6e3, 98.6e3, 129.7e3, 94.2e3, 113.4e3, 122.7e3, 122.9e3];
C_D = [1.224, 0.801, 1.380, 1.000, 1.224, 1.518, 1.518];
z_D = [1.282, 2.161, 1.282, 20.0, 1.282, 1.282, 1.282];
bfm1 = [1.0, 1.0, 1.0, 1.0, 0.92, 1.0, 1.0];
bfm2 = [0.0, 0.0, 0.0, 0.0, 0.25, 0.0, 0.0];
bfm3 = [0.0, 0.0, 0.0, 0.0, 1.77, 0.0, 0.0];
bfp1 = [1.0, 0.93, 1.0, 0.93, 0.93, 1.0, 1.0];
bfp2 = [0.0, 0.31, 0.0, 0.19, 0.31, 0.0, 0.0];
bfp3 = [0.0, 2.00, 0.0, 1.79, 2.00, 0.0, 0.0];
a_9000 = 9000e3;
THIRD = 1.0 / 3.0;

z_T = z.T;
z_S = z.S;
z_L = z.L;

c = climate;
wn = f_mhz / 47.7;
d_ex = sqrt(2 * a_9000 * h_e_m(1)) + sqrt(2 * a_9000 * h_e_m(2)) + (575.7e12 / wn)^THIRD;
if d_m < d_ex
    d_e = 130e3 * d_m / d_ex;
else
    d_e = 130e3 + d_m - d_ex;
end

mdvar_internal = mdvar;
plus20 = mdvar_internal >= 20;
if plus20
    mdvar_internal = mdvar_internal - 20;
    sigma_S = 0.0;
else
    sigma_S = 5.0 + 3.0 * exp(-d_e / 100e3);
end
plus10 = mdvar_internal >= 10;
if plus10
    mdvar_internal = mdvar_internal - 10;
end

V_med = curve(all_year(1, c), all_year(2, c), all_year(3, c), all_year(4, c), all_year(5, c), d_e);

switch mdvar_internal
    case 0                       % single message
        z_T = z_S;
        z_L = z_S;
    case 1                       % accidental
        z_L = z_S;
    case 2                       % mobile
        z_L = z_T;
end
if nargout > 1
    extreme = abs(z_T) > 3.10 | abs(z_L) > 3.10 | abs(z_S) > 3.10;
end

if plus10
    sigma_L = 0.0;
else
    delta_h_d = terrain_roughness(d_m, delta_h_m);
    sigma_L = 10.0 * wn * delta_h_d / (wn * delta_h_d + 13.0);
end
Y_L = sigma_L * z_L;

q = log(0.133 * wn);
g_minus = bfm1(c) + bfm2(c) / ((bfm3(c) * q)^2 + 1.0);
g_plus = bfp1(c) + bfp2(c) / ((bfp3(c) * q)^2 + 1.0);
sigma_T_minus = curve(bsm1(c), bsm2(c), xsm1(c), xsm2(c), xsm3(c), d_e) * g_minus;
sigma_T_plus = curve(bsp1(c), bsp2(c), xsp1(c), xsp2(c), xsp3(c), d_e) * g_plus;
sigma_TD = C_D(c) * sigma_T_plus;
tgtd = (sigma_T_plus - sigma_TD) * z_D(c);

% Three-way selection without logical-index assignment (single-threaded
% and slow on large arrays). The masks are 0 or 1 and disjoint, x*1 and
% x*0 are exact, and adding exact zeros changes nothing, so each element
% equals the C++ branch it falls in, bit for bit. The upper branch divides
% by max(z_T, z_D), which equals z_T where that branch is selected and
% avoids Inf*0 = NaN at z_T = 0 (reliability 50) elsewhere.
lower = z_T < 0.0;
upper = z_T > z_D(c);
middle = ~(lower | upper);
sigma_T = sigma_T_minus .* lower + sigma_T_plus .* middle + ...
    (sigma_TD + tgtd ./ max(z_T, z_D(c))) .* upper;
Y_T = sigma_T .* z_T;

Y_S_temp = sigma_S^2 + Y_T.^2 ./ (7.8 + z_S.^2) + Y_L.^2 ./ (24.0 + z_S.^2);
switch mdvar_internal
    case 0
        Y_R = zeros(size(z_T));
        Y_S = sqrt(sigma_T.^2 + sigma_L^2 + Y_S_temp) .* z_S;
    case 1
        Y_R = Y_T;
        Y_S = sqrt(sigma_L^2 + Y_S_temp) .* z_S;
    case 2
        Y_R = sqrt(sigma_T.^2 + sigma_L^2) .* z_T;
        Y_S = sqrt(Y_S_temp) .* z_S;
    otherwise                    % broadcast
        Y_R = Y_T + Y_L;
        Y_S = sqrt(Y_S_temp) .* z_S;
end

result = A_ref_db - V_med - Y_R - Y_S;
neg = result < 0.0;
result(neg) = result(neg) .* (29.0 - result(neg)) ./ (29.0 - 10.0 * result(neg));
end

function v = curve(c1, c2, x1, x2, x3, d_e)
v = (c1 + c2 / (1.0 + ((d_e - x2) / x3)^2)) * ((d_e / x1)^2) / (1.0 + ((d_e / x1)^2));
end
