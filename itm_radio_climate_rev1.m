function climate = itm_radio_climate_rev1(lat_deg, lon_deg)
%ITM_RADIO_CLIMATE_REV1 ITU-R P.617 radio climate code for ITM.
%   climate = ITM_RADIO_CLIMATE_REV1(lat_deg, lon_deg) returns the ITM radio
%   climate code (1-7) at each point, from the ITU-R P.617-3 radio-climatic
%   zone map (TropoClim.txt, 0.5 degree grid). The point is rounded to the
%   nearest grid point, and sea (code 0 in the file) is returned as 7,
%   maritime temperate over sea. This matches the WInnForum CBRS reference
%   model (tropoclim.py).
%
%   Codes: 1 equatorial, 2 continental subtropical, 3 maritime subtropical,
%   4 desert, 5 continental temperate, 6 maritime temperate over land,
%   7 maritime temperate over sea.
%
%   For a path, itm_pathloss_rev1 uses the climate at the path midpoint;
%   when the midpoint is over sea (7), it uses the minimum of the two
%   terminal climates.
%
%   See also itm_surface_refractivity_rev1, itm_pathloss_rev1.

arguments
    lat_deg double {mustBeReal, mustBeFinite, mustBeInRange(lat_deg, -90, 90)}
    lon_deg double {mustBeReal, mustBeFinite}
end

maps = itm_maps();          % repo data, app bundle, cache, or ITU download
grid = maps.TropoClim;

lon_deg = mod(lon_deg + 180, 360) - 180;          % wrap to [-180, 180)
lat_deg = lat_deg + zeros(size(lon_deg));
lon_deg = lon_deg + zeros(size(lat_deg));
irow = floor((89.75 - lat_deg) / 0.5 + 0.5);      % row 0 is 89.75 N
icol = floor((lon_deg + 179.75) / 0.5 + 0.5);     % column 0 is 179.75 W
irow = min(max(irow, 0), 359);
icol = mod(icol, 720);
climate = grid(sub2ind([360 720], irow + 1, icol + 1));
climate(climate == 0) = 7;
end
