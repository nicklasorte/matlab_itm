function e = itm_wgs84()
%ITM_WGS84 WGS84 reference ellipsoid in meters, built once per session.
%   wgs84Ellipsoid('meter') takes about 1.5 ms per call because setting
%   LengthUnit searches a units graph; the object never changes, so it is
%   cached.

persistent cached
if isempty(cached)
    cached = wgs84Ellipsoid('meter');
end
e = cached;
end
