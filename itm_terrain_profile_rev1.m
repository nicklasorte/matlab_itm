function [pfl, info] = itm_terrain_profile_rev1(lat1_deg, lon1_deg, lat2_deg, lon2_deg, options)
%ITM_TERRAIN_PROFILE_REV1 ITM terrain profiles (PFL) along WGS84 geodesics.
%   pfl = ITM_TERRAIN_PROFILE_REV1(lat1, lon1, lat2, lon2) samples terrain
%   from point 1 (TX) to point 2 (RX) at equal steps along the WGS84
%   geodesic and returns it in ITM PFL format, [np; xi_m; z_0; ...; z_np].
%   The step is the largest value not exceeding spacing_m that divides the
%   path into whole intervals.
%
%   The inputs can be vectors (one element per path, or scalars that
%   expand). For N > 1 paths, pfl is an N-by-1 cell array of profiles. All
%   paths are sampled in a single pass over the terrain tiles.
%
%   Name-value options:
%     spacing_m    Target point spacing (30 m, the native DEM resolution)
%     max_points   Cap on profile points per path (Inf). Use 1501 to match
%                  the WInnForum CBRS reference model for long paths.
%     source, terrain_dir, download, cache_gb
%                  Passed to itm_terrain_elevation_rev1
%
%   info (struct array, one per path) returns the path length, initial
%   azimuth, geodesic midpoint, sample coordinates, and terrain source per
%   point.
%
%   See also itm_terrain_elevation_rev1, itm_p2p_rev1, itm_pathloss_rev1.

arguments
    lat1_deg double {mustBeVector, mustBeReal, mustBeFinite, mustBeInRange(lat1_deg, -90, 90)}
    lon1_deg double {mustBeVector, mustBeReal, mustBeFinite}
    lat2_deg double {mustBeVector, mustBeReal, mustBeFinite, mustBeInRange(lat2_deg, -90, 90)}
    lon2_deg double {mustBeVector, mustBeReal, mustBeFinite}
    options.spacing_m (1,1) double {mustBeReal, mustBePositive, mustBeFinite} = 30
    options.max_points (1,1) double {mustBeReal, mustBeGreaterThanOrEqual(options.max_points, 2)} = Inf
    options.source (1,1) string {mustBeMember(options.source, ["auto", "usgs3dep", "usgs3dep13", "copernicus", "copernicus90"])} = "auto"
    options.terrain_dir (1,1) string = itm_default_terrain_dir()
    options.download (1,1) logical = true
    options.cache_gb double {mustBePositive} = []
end

% Expand scalars so every input has one element per path
n_paths = max([numel(lat1_deg), numel(lon1_deg), numel(lat2_deg), numel(lon2_deg)]);
lat1 = expand(lat1_deg, n_paths); lon1 = expand(lon1_deg, n_paths);
lat2 = expand(lat2_deg, n_paths); lon2 = expand(lon2_deg, n_paths);

ellipsoid = itm_wgs84();
[d_m, az] = itm_geodesic_inverse(lat1, lon1, lat2, lon2);   % same result alone or in a batch
if any(d_m < 1)
    k = find(d_m < 1, 1);
    error('itm:terrain:ZeroDistance', ...
        'Path %d: TX and RX are %.3g m apart; ITM needs distinct terminals.', k, d_m(k));
end
n_pts = max(min(ceil(d_m / options.spacing_m) + 1, floor(options.max_points)), 2);

% Equally spaced points along each geodesic, for every path in one call:
% reckon solves the direct geodesic problem from the TX along the initial
% azimuth (track2 gives the same points but solves the inverse problem
% again for each path).
% Indexing a scalar by a column vector gives a row, so force columns.
col = @(v) reshape(v, [], 1);
path_id = repelem((1:n_paths)', n_pts);
step = d_m ./ (n_pts - 1);
first = cumsum([1; n_pts(1:end - 1)]);
k_in_path = (1:sum(n_pts))' - col(first(path_id));
% The path midpoints ride along in the same call (one extra point per
% path), so itm_pathloss_rev1 doesn't solve the geodesic again for them.
[lat_r, lon_r] = reckon([col(lat1(path_id)); lat1], [col(lon1(path_id)); lon1], ...
    [k_in_path .* col(step(path_id)); d_m / 2], [col(az(path_id)); az], ellipsoid);
n_tot = sum(n_pts);
lat_cat = lat_r(1:n_tot);
lon_cat = lon_r(1:n_tot);
lat_mid = lat_r(n_tot + 1:end);
lon_mid = lon_r(n_tot + 1:end);
% End exactly on the RX coordinates, as track2 does
last = cumsum(n_pts);
lat_cat(last) = lat2;
lon_cat(last) = lon2;
lat_all = mat2cell(lat_cat, n_pts, 1);
lon_all = mat2cell(lon_cat, n_pts, 1);
elev_args = {'source', options.source, 'terrain_dir', options.terrain_dir, 'download', options.download};
if ~isempty(options.cache_gb)
    elev_args = [elev_args, {'cache_gb', options.cache_gb}];
end
[z_cat, zinfo] = itm_terrain_elevation_rev1(lat_cat, lon_cat, elev_args{:});

% Split back into per-path PFL vectors
z_all = mat2cell(z_cat, n_pts, 1);
src_all = mat2cell(zinfo.source_code, n_pts, 1);
pfl = cell(n_paths, 1);
info = struct('distance_m', num2cell(d_m), 'azimuth_deg', num2cell(az), ...
    'midpoint_deg', num2cell([lat_mid, lon_mid], 2), 'spacing_m', num2cell(d_m ./ (n_pts - 1)), ...
    'lat_deg', lat_all, 'lon_deg', lon_all, 'elevation_m', z_all, 'source_code', src_all);
for k = 1:n_paths
    pfl{k} = [n_pts(k) - 1; d_m(k) / (n_pts(k) - 1); z_all{k}];
end
[info.source_names] = deal(zinfo.source_names);
[info.tiles] = deal(zinfo.tiles);
if n_paths == 1
    pfl = pfl{1};
end
end

function v = expand(v, n)
v = v(:);
if isscalar(v)
    v = repmat(v, n, 1);
elseif numel(v) ~= n
    error('itm:terrain:SizeMismatch', ...
        'Path inputs must be scalars or vectors of the same length (%d).', n);
end
end
