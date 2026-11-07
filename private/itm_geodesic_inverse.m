function [d_m, az] = itm_geodesic_inverse(lat1, lon1, lat2, lon2)
%ITM_GEODESIC_INVERSE WGS84 geodesic length and initial azimuth, per path.
%   [d_m, az] = ITM_GEODESIC_INVERSE(lat1, lon1, lat2, lon2) returns
%   distance(..., wgs84Ellipsoid) for each path in its own call. MATLAB's
%   geodesic routines iterate until every element of an array converges,
%   so a path's result in a shared call depends on the other paths in it
%   (about 1e-8 m). ITM is discontinuous (horizon picks, fit boundaries),
%   so on a short path that once changed the loss by 0.09 dB between a
%   single call and a batch. Per-path calls cost about 0.1 ms each.

n = numel(lat1);
d_m = zeros(n, 1);
az = zeros(n, 1);
E = itm_wgs84();
for k = 1:n
    [d_m(k), az(k)] = distance(lat1(k), lon1(k), lat2(k), lon2(k), E);
end
end
