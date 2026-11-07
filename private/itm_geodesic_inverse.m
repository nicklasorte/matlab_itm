function [d_m, az] = itm_geodesic_inverse(lat1, lon1, lat2, lon2)
%ITM_GEODESIC_INVERSE WGS84 geodesic length and initial azimuth, batch-independent.
%   [d_m, az] = ITM_GEODESIC_INVERSE(lat1, lon1, lat2, lon2) returns
%   distance(lat1, lon1, lat2, lon2, wgs84Ellipsoid) for column vectors.
%   distance takes a different code path for scalar inputs than for
%   vectors, and the two can differ by about 1e-8 m and 1e-9 degrees. ITM
%   is discontinuous (horizon picks, fit boundaries), so on a short path
%   that can change the loss by 0.1 dB. A single path is therefore padded
%   to two elements, so every link uses the vector path and gets the same
%   result alone or in any batch (vector results don't depend on length;
%   checked in tests/test_robustness_rev1).

n = numel(lat1);
if n == 1
    [d_m, az] = distance([lat1; lat1], [lon1; lon1], [lat2; lat2], [lon2; lon2], itm_wgs84());
    d_m = d_m(1);
    az = az(1);
else
    [d_m, az] = distance(lat1, lon1, lat2, lon2, itm_wgs84());
end
end
