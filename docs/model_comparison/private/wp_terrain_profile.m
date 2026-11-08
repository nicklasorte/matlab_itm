function prof = wp_terrain_profile(tx, rx)
%WP_TERRAIN_PROFILE Terrain profile in the struct form wp_run3 takes.
%   prof = WP_TERRAIN_PROFILE([lat lon], [lat lon]) samples USGS 3DEP
%   1-arc-second terrain (Copernicus GLO-30 where 3DEP has no data) at 30 m
%   along the WGS84 geodesic with itm_terrain_profile_rev1, and adds the
%   P.2001 radio-climatic zone at each point. Points with no elevation data
%   are open water (zone 1).
[pfl, info] = itm_terrain_profile_rev1(tx(1), tx(2), rx(1), rx(2));
np = pfl(1);
prof.d_km = (0:np)' * pfl(2) / 1e3;
prof.h_m = pfl(3:end);
prof.zone = p2001_zone_lookup_rev1(info.lat_deg, info.lon_deg);
prof.zone(info.source_code == 0) = 1;
prof.tx = tx;
prof.rx = rx;
prof.mid = info.midpoint_deg;
end
