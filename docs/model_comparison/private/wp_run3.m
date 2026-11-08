function r = wp_run3(prof, f_mhz, htx, hrx, p)
%WP_RUN3 ITM v1.4, P.452-18, and P.2001-6 on one terrain profile.
%   r = WP_RUN3(prof, f_mhz, htx, hrx, p) runs the three models on the same
%   profile, as make_wp_figures_rev1 does (its local function run3), so the
%   differences are the models, not the terrain.
%     prof   struct: d_km, h_m, zone (P.2001 zones: 1 sea, 3 coastal land,
%            4 inland), tx and rx ([lat lon]), mid ([lat lon])
%     p      time percentages (loss not exceeded for p % of the time)
%   ITM: radio climate and N_0 at the path midpoint (WInnForum rule; the
%   lower terminal climate when the midpoint is over water), confidence
%   50 %, validity checks off. P.452 runs for 0.001 % to 50 % and for
%   100 MHz and above only; NaN elsewhere.

pfl = [numel(prof.d_km) - 1; prof.d_km(end) * 1e3 / (numel(prof.d_km) - 1); prof.h_m(:)];
c = itm_radio_climate_rev1(prof.mid(1), prof.mid(2));
if c == 7
    c = min(itm_radio_climate_rev1(prof.tx(1), prof.tx(2)), itm_radio_climate_rev1(prof.rx(1), prof.rx(2)));
end
n0 = itm_surface_refractivity_rev1(prof.mid(1), prof.mid(2));
[L, info] = itm_p2p_rev1(htx, hrx, pfl, f_mhz, p, climate=c, N_0=n0, validity="off");
r.itm.Lb = L(:)';
r.itm.info = info;
r.itm.mech = info.mode_code;
r.itm.climate = c;
r.itm.N_0 = n0;

ok = p >= 0.001 & p <= 50 & f_mhz >= 100;          % P.452-18 starts at 100 MHz
r.p452.Lb = NaN(size(p));
r.p452.info = [];
if any(ok)
    z = 2 * ones(size(prof.zone));
    z(prof.zone == 1) = 3;
    z(prof.zone == 3) = 1;
    [Lb, info452] = p452_p2p_rev1(prof.d_km, prof.h_m, [], z, htx, hrx, f_mhz / 1000, p(ok), ...
        tx_deg=prof.tx, rx_deg=prof.rx, validity="off");
    r.p452.Lb(ok) = Lb(:)';
    r.p452.info = info452;
end

pr = struct('d_km', prof.d_km(:), 'h_m', prof.h_m(:), 'zone', prof.zone(:));
[lb, ~, ~, mech] = p2001_rev1([prof.tx htx], [prof.rx hrx], f_mhz, p(:), Profile=pr, ...
    Validity="off", InfoDetail="brief");
r.p2001.Lb = lb(:)';
r.p2001.mech = mech(:)';
end
