function t = wp_itm_terms(pfl, f, h_m, N_0, info, pol)
%WP_ITM_TERMS ITM v1.4 diffraction terms for a path, from ITM's own equations.
%   t = WP_ITM_TERMS(pfl, f, h_m, N_0, info) recomputes, for the profile pfl
%   (ITM format), frequency f (MHz), structural heights h_m ([tx rx], m),
%   surface refractivity N_0, and the info struct itm_p2p_rev1 returned for
%   the same inputs, ITM's diffraction terms at d_3 (A_k3, A_se3, w3, A_fo,
%   A_d3) and at the path's own distance (A_k_at_d, A_se_at_d, w_at_d,
%   A_d_at_d; NaN within the actual horizons), plus the ablations used in
%   the paper. It checks that the recomputed reference attenuation equals
%   ITM's to 1e-9 dB. Same equations as private/itm_p2p_core.m
%   (initialize_point_to_point, longley_rice, diffraction_loss,
%   smooth_earth_diffraction); epsilon 25, sigma 0.02.
%   pol: 1 vertical (default) or 0 horizontal.
np = fix(pfl(1));
p10 = fix(0.1 * np);
h_acc = cumsum(pfl((p10:np - p10) + 3));
h_sys = h_acc(end) / (np - 2 * p10 + 1);
N_s = N_0 * exp(-h_sys / 9460.0);
gamma_e = 157e-9 * (1.0 - 0.04665 * exp(N_s / 179.3));
if nargin < 6, pol = 1; end
ep_r = complex(25, 18000 * 0.02 / f);
Z_g = sqrt(ep_r - 1.0);
if pol == 1, Z_g = Z_g / ep_r; end
a_e = 1 / gamma_e;
d_m = info.d_km * 1e3;
d_hzn = info.d_hzn_m;
h_e = info.h_e_m;
dh = info.delta_h_m;
theta_hzn = info.theta_hzn_rad;
d_sML = sum(sqrt(2.0 * h_e * a_e));
d_ML = sum(d_hzn);
theta_los = -max(sum(theta_hzn), -d_ML / a_e);
t.d_ML = d_ML; t.d_sML = d_sML;
t.d_3 = max(d_sML, d_ML + 5.0 * (a_e^2 / f)^(1 / 3));
d_4 = t.d_3 + 10.0 * (a_e^2 / f)^(1 / 3);
t.theta_nlos_mrad = 1e3 * (t.d_3 / a_e - theta_los);

opts = {'two', true};
[A3, c3] = dl(t.d_3, opts{:});
A4 = dl(d_4, opts{:});
t.A_k3 = c3.A_k; t.A_se3 = c3.A_se; t.w3 = c3.w; t.A_fo = c3.A_fo; t.A_d3 = A3;
t.v1 = c3.v1; t.v2 = c3.v2;
t.A_ref = line_or_los(A3, A4);
check = t.A_ref - info.A_ref_db;
if abs(check) > 1e-9
    error('wp:diffraction:check', 'Recomputed ITM A_ref differs from ITM by %g dB.', check);
end
% Ablations
[a3, ~] = dl(t.d_3, 'two', false); a4 = dl(d_4, 'two', false);
t.A_ref_single = line_or_los(a3, a4);
[a3, ~] = dl(t.d_3, 'two', true, 'clutter', false); a4 = dl(d_4, 'two', true, 'clutter', false);
t.A_ref_noclutter = line_or_los(a3, a4);
if d_m > d_ML
    [t.A_d_at_d, cd] = dl(d_m, 'two', true);
    t.A_all = dl(d_m, 'two', false, 'clutter', false);
    t.A_k_at_d = cd.A_k; t.A_se_at_d = cd.A_se; t.w_at_d = cd.w;
else
    t.A_d_at_d = NaN; t.A_all = NaN; t.A_k_at_d = NaN; t.A_se_at_d = NaN; t.w_at_d = NaN;
end

    function [A, c] = dl(d, varargin)
        o = struct('two', true, 'clutter', true);
        for i = 1:2:numel(varargin), o.(varargin{i}) = varargin{i + 1}; end
        theta_nlos = d / a_e - theta_los;
        d_nlos = d - d_ML;
        c.v1 = 0.0795775 * (f / 47.7) * theta_nlos^2 * d_hzn(1) * d_nlos / (d_nlos + d_hzn(1));
        c.v2 = 0.0795775 * (f / 47.7) * theta_nlos^2 * d_hzn(2) * d_nlos / (d_nlos + d_hzn(2));
        if o.two
            c.A_k = fres(c.v1) + fres(c.v2);
        else
            c.A_k = fres(max(c.v1, c.v2));
        end
        c.A_se = se(d);
        dh_s = dh * (1.0 - 0.8 * exp(-d_sML / 50e3));
        sh = 0.78 * dh_s * exp(-0.5 * dh_s^0.25);
        c.A_fo = min(15.0, 5 * log10(1.0 + 1e-5 * h_m(1) * h_m(2) * f * sh));
        if ~o.clutter, c.A_fo = 0; end
        dh_d = dh * (1.0 - 0.8 * exp(-d / 50e3));
        q = h_m(1) * h_m(2);
        qk = h_e(1) * h_e(2) - q;
        q = q + 10.0;
        q = (sqrt(1.0 + qk / q) + (-theta_los * a_e + d_ML) / d) * min(dh_d * f / 47.7, 6283.2);
        c.w = 25.1 / (25.1 + sqrt(q));
        A = c.w * c.A_se + (1.0 - c.w) * c.A_k + c.A_fo;
    end

    function A_se = se(d)
        a_0 = 6370e3;
        theta_nlos = d / a_e - theta_los;
        a_m = [(d - d_ML) / (d / a_e - theta_los), 0.5 * d_hzn(1)^2 / h_e(1), 0.5 * d_hzn(2)^2 / h_e(2)];
        dk = [(a_m(1) * theta_nlos) / 1000.0, d_hzn(1) / 1000.0, d_hzn(2) / 1000.0];
        C_0 = ((4.0 / 3.0) * a_0 ./ a_m).^(1 / 3);
        K = 0.017778 * C_0 * f^(-1 / 3) / abs(Z_g);
        B_0 = 1.607 - K;
        x = zeros(1, 3);
        x(2) = B_0(2) * C_0(2)^2 * f^(1 / 3) * dk(2);
        x(3) = B_0(3) * C_0(3)^2 * f^(1 / 3) * dk(3);
        x(1) = B_0(1) * C_0(1)^2 * f^(1 / 3) * dk(1) + x(2) + x(3);
        A_se = 0.05751 * x(1) - 10.0 * log10(x(1)) - hf(x(2), K(2)) - hf(x(3), K(3)) - 20;
    end

    function A = line_or_los(A3, A4)
        % longley_rice L391-466 with the diffraction loss from A3, A4
        M_d = (A4 - A3) / (d_4 - t.d_3);
        A_d0 = A3 - M_d * t.d_3;
        if d_m < d_sML
            A = los_region(M_d, A_d0);
        else
            A = trans_horizon(M_d, A_d0);
        end
        A = max(A, 0);
    end

    function A = trans_horizon(M_d, A_d0)
        d_5 = d_ML + 200e3; d_6 = d_ML + 400e3;
        [A_6, h0] = tropo(d_6, -1); A_5 = tropo(d_5, h0);
        if A_5 < 1000
            M_s = (A_6 - A_5) / 200e3;
            d_x = max(max(d_sML, d_ML + 1.088 * (a_e^2 / f)^(1 / 3) * log(f)), (A_5 - A_d0 - M_s * d_5) / (M_d - M_s));
            A_s0 = (M_d - M_s) * d_x + A_d0;
        else
            M_s = M_d; A_s0 = A_d0; d_x = 10e6;
        end
        if d_m > d_x
            A = M_s * d_m + A_s0;
        else
            A = M_d * d_m + A_d0;
        end
    end

    function A = los_region(M_d, A_d0)
        A_sML = d_sML * M_d + A_d0;
        d_0 = 0.04 * f * h_e(1) * h_e(2);
        if A_d0 >= 0
            d_0 = min(d_0, 0.5 * d_ML); d_1 = d_0 + 0.25 * (d_ML - d_0);
        else
            d_1 = max(-A_d0 / M_d, 0.25 * d_ML);
        end
        A_1 = los_loss(d_1, M_d, A_d0);
        flag = false; k1 = 0; k2 = 0;
        if d_0 < d_1
            A_0 = los_loss(d_0, M_d, A_d0);
            q = log(d_sML / d_0);
            k2 = max(0, ((d_sML - d_0) * (A_1 - A_0) - (d_1 - d_0) * (A_sML - A_0)) / ((d_sML - d_0) * log(d_1 / d_0) - (d_1 - d_0) * q));
            flag = A_d0 > 0 || k2 > 0;
            if flag
                k1 = (A_sML - A_0 - k2 * q) / (d_sML - d_0);
                if k1 < 0
                    k1 = 0; k2 = max(A_sML - A_0, 0) / q;
                    if k2 == 0, k1 = M_d; end
                end
            end
        end
        if ~flag
            k1 = max(A_sML - A_1, 0) / (d_sML - d_1); k2 = 0;
            if k1 == 0, k1 = M_d; end
        end
        A_o = A_sML - k1 * d_sML - k2 * log(d_sML);
        A = A_o + k1 * d_m + k2 * log(d_m);
    end

    function A_los = los_loss(d, M_d, A_d0)
        dh_d = dh * (1.0 - 0.8 * exp(-d / 50e3));
        sh = 0.78 * dh_d * exp(-0.5 * dh_d^0.25);
        wn = f / 47.7;
        sin_psi = (h_e(1) + h_e(2)) / sqrt(d^2 + (h_e(1) + h_e(2))^2);
        R_e = (sin_psi - Z_g) / (sin_psi + Z_g) * exp(-min(10.0, wn * sh * sin_psi));
        q = real(R_e)^2 + imag(R_e)^2;
        if q < 0.25 || q < sin_psi, R_e = R_e * sqrt(sin_psi / q); end
        dphi = wn * 2.0 * h_e(1) * h_e(2) / d;
        if dphi > pi / 2, dphi = pi - (pi / 2)^2 / dphi; end
        rr = complex(cos(dphi), -sin(dphi)) + R_e;
        A_t = -10 * log10(real(rr)^2 + imag(rr)^2);
        A_d = M_d * d + A_d0;
        w = 1 / (1 + f * dh / max(10e3, d_sML));
        A_los = w * A_t + (1 - w) * A_d;
    end

    function [A, h0] = tropo(d, h0)
        wn = f / 47.7;
        ad = d_hzn(1) - d_hzn(2); rr = h_e(2) / h_e(1);
        if ad < 0, ad = -ad; rr = 1 / rr; end
        theta = theta_hzn(1) + theta_hzn(2) + d / a_e;
        r1 = 2 * wn * theta * h_e(1); r2 = 2 * wn * theta * h_e(2);
        if h0 > 15
            H_0 = h0;
        else
            if r1 < 0.2 && r2 < 0.2, A = 1001; return, end
            s = (d - ad) / (d + ad);
            q = min(max(0.1, rr / s), 10.0); s = max(0.1, s);
            h_0 = (d - ad) * (d + ad) * theta * 0.25 / d;
            eta = (h_0 / 1.7556e3) * (1 + (0.031 - N_s * 2.32e-3 + N_s^2 * 5.67e-6) * exp(-(min(1.7, h_0 / 8e3))^6));
            H_00 = (h0f(r1, eta) + h0f(r2, eta)) / 2;
            H_0 = max(H_00 + min(H_00, 6 * (0.6 - log10(max(eta, 1))) * log10(s) * log10(q)), 0);
            if eta < 1
                H_0 = eta * H_0 + (1 - eta) * 10 * log10(((1 + sqrt(2) / r1) * (1 + sqrt(2) / r2))^2 * (r1 + r2) / (r1 + r2 + 2 * sqrt(2)));
            end
            if H_0 > 15 && h0 >= 0, H_0 = h0; end
        end
        h0 = H_0;
        th = d / a_e - theta_los;
        A = ff(th * d) + 10 * log10(wn * 47.7 * th^4) - 0.1 * (N_s - 301) * exp(-th * d / 40e3) + H_0;
    end
end

function A = fres(v2)
if v2 < 5.76
    A = 6.02 + 9.11 * sqrt(v2) - 1.27 * v2;
else
    A = 12.953 + 10 * log10(v2);
end
end

function r = hf(x, K)
if x < 200
    w = -log(K);
    if K < 1e-5 || x * w^3 > 5495
        r = -117;
        if x > 1, r = 17.372 * log(x) + r; end
    else
        r = 2.5e-5 * x^2 / K - 8.686 * w - 15;
    end
else
    r = 0.05751 * x - 4.343 * log(x);
    if x < 2000
        w = 0.0134 * x * exp(-0.005 * x);
        r = (1 - w) * r + w * (17.372 * log(x) - 117);
    end
end
end

function F0 = ff(td)
a = [133.4, 104.6, 71.8]; b = [0.332e-3, 0.212e-3, 0.157e-3]; c = [-10, -2.5, 5];
if td <= 10e3, i = 1; elseif td <= 70e3, i = 2; else, i = 3; end
F0 = a(i) + b(i) * td + c(i) * log10(td);
end

function h = h0f(r, eta)
eta = min(max(eta, 1), 5);
i = fix(eta);
q = eta - i;
h = h0c(i, r);
if q ~= 0, h = (1 - q) * h + q * h0c(i + 1, r); end
end

function h = h0c(j, r)
a = [25.0, 80.0, 177.0, 395.0, 705.0];
b = [24.0, 45.0, 68.0, 80.0, 105.0];
h = 10 * log10(1 + a(j) * (1 / r)^4 + b(j) * (1 / r)^2);
end

%% ------------------------------------------------------------------------
