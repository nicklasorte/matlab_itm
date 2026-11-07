function N_0 = itm_surface_refractivity_rev1(lat_deg, lon_deg)
%ITM_SURFACE_REFRACTIVITY_REV1 ITU-R P.452 sea-level surface refractivity.
%   N_0 = ITM_SURFACE_REFRACTIVITY_REV1(lat_deg, lon_deg) returns the
%   average annual sea-level surface refractivity N0 (N-units) from the
%   ITU-R P.452-16 data file N050.TXT (1.5 degree grid), bilinearly
%   interpolated from the four surrounding grid points. This matches the
%   WInnForum CBRS reference model (refractivity.py). ITM converts N_0 to
%   the surface refractivity N_s using the terrain height of the path.
%
%   See also itm_radio_climate_rev1, itm_pathloss_rev1.

arguments
    lat_deg double {mustBeReal, mustBeFinite, mustBeInRange(lat_deg, -90, 90)}
    lon_deg double {mustBeReal, mustBeFinite}
end

persistent grid
if isempty(grid)
    grid = readmatrix(itm_data_path('N050.TXT'), 'FileType', 'text');
    if ~isequal(size(grid), [121 241])
        error('itm:DataFileCorrupt', 'N050.TXT must be 121 x 241; read %d x %d.', size(grid));
    end
end

% Grid: rows 90 N to 90 S, columns 0 to 360 E, 1.5 degree spacing.
% Explicit bilinear form copied from refractivity.py; interp2 would also
% work but this keeps the edge clamping identical to the reference.
lon_deg = mod(lon_deg, 360);
lat_deg = lat_deg + zeros(size(lon_deg));
lon_deg = lon_deg + zeros(size(lat_deg));
row = (90.0 - lat_deg) / 1.5;
col = lon_deg / 1.5;
irow = min(floor(row), 119);
icol = min(floor(col), 239);
a_r = row - irow;
a_c = col - icol;
idx = @(r, c) sub2ind([121 241], r + 1, c + 1);
r00 = grid(idx(irow, icol));
r01 = grid(idx(irow, icol + 1));
r10 = grid(idx(irow + 1, icol));
r11 = grid(idx(irow + 1, icol + 1));
N_0 = r11 .* a_r .* a_c + r00 .* (1 - a_r) .* (1 - a_c) + r01 .* (1 - a_r) .* a_c + r10 .* a_r .* (1 - a_c);
end
