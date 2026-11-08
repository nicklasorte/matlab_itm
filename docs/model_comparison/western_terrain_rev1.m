function W = western_terrain_rev1(options)
%WESTERN_TERRAIN_REV1 The real-terrain comparison repeated on western U.S. terrain.
%   W = WESTERN_TERRAIN_REV1() draws 20 links in each of three western
%   regions with the same rules as the paper's 60 eastern links
%   (make_wp_figures_rev1, E7):
%     front range         Colorado Front Range and Rocky Mountain foothills
%     basin and range     north-central Nevada
%     southern california Los Angeles basin and the Transverse Ranges
%   Each link starts at a uniformly random point in its region's box, runs
%   in a random direction for a length drawn log-uniformly from 10 km to
%   150 km, with a transmitting antenna 10 m to 100 m and a receiving antenna
%   2 m to 30 m above ground (uniform). The models run on each link's 30 m
%   terrain profile (USGS 3DEP 1 arc-second; wp_terrain_profile) with
%   wp_run3, at options.Freq (3000 MHz) and 1, 10, and 50 % of time.
%
%   Writes to options.OutDir (chart_data/):
%     western_links.csv  one row per link: region, endpoints, length,
%                        heights, ITM delta h, ITM mode code and class at
%                        50 %, free-space loss, and each model's loss at 1,
%                        10, and 50 %
%   and runs diffraction_decomposition_rev1 on the same links (Tag "_west"),
%   which writes figures/table_diffraction_terms_west.csv with ITM's
%   smooth-earth weight w and the other diffraction terms.
%
%   Options: Freq (3000), NumLinksPerRegion (20), Seed (8), OutDir,
%   P2001Dir, P452Dir, Download (true: fetch missing terrain tiles).

arguments
    options.Freq (1,1) double = 3000
    options.NumLinksPerRegion (1,1) double {mustBeInteger, mustBePositive} = 20
    options.Seed (1,1) double = 8
    options.OutDir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'chart_data')
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
    options.Download (1,1) logical = true %#ok<INUSA> tiles download on first use in itm_terrain_profile_rev1
end
wp_setup(options.P2001Dir, options.P452Dir);
regions = struct('name', {"front range", "basin and range", "southern california"}, ...
    'box', {[39.2 40.6 -106.2 -105.1], [38.6 40.2 -118.6 -116.4], [33.9 34.7 -118.9 -117.2]});
rs = RandStream('mrg32k3a', 'Seed', options.Seed);
P = [1 10 50];
cls = containers.Map('KeyType', 'double', 'ValueType', 'char');
for c = 0, cls(c) = 'LOS'; end
for c = [4 5 8 9], cls(c) = 'Diffraction'; end
for c = [6 10], cls(c) = 'Troposcatter'; end
rows = {};
for g = 1:numel(regions)
    b = regions(g).box;
    for j = 1:options.NumLinksPerRegion
        tx = [b(1) + diff(b(1:2)) * rand(rs), b(3) + diff(b(3:4)) * rand(rs)];
        len = exp(log(10) + (log(150) - log(10)) * rand(rs));
        az = 360 * rand(rs);
        [la2, lo2] = reckon(tx(1), tx(2), len * 1e3, az, wgs84Ellipsoid('meter'));
        htx = 10 + 90 * rand(rs); hrx = 2 + 28 * rand(rs);
        prof = wp_terrain_profile(tx, [la2 lo2]);
        r = wp_run3(prof, options.Freq, htx, hrx, P);
        code = r.itm.mech;
        if isKey(cls, code), c = string(cls(code)); else, c = "Other"; end
        fs = 32.45 + 20 * log10(options.Freq) + 20 * log10(prof.d_km(end));
        rows(end + 1, :) = {g, regions(g).name, tx(1), tx(2), la2, lo2, len, htx, hrx, ...
            r.itm.info.delta_h_m, code, c, nnz(prof.zone == 1) / numel(prof.zone), fs, ...
            r.itm.Lb(1), r.itm.Lb(2), r.itm.Lb(3), r.p452.Lb(1), r.p452.Lb(2), r.p452.Lb(3), ...
            r.p2001.Lb(1), r.p2001.Lb(2), r.p2001.Lb(3)}; %#ok<AGROW>
        fprintf('%s link %2d: %5.1f km, delta h %4.0f m, %s\n', regions(g).name, j, len, r.itm.info.delta_h_m, c);
    end
end
W = cell2table(rows, 'VariableNames', {'region_id', 'region', 'tx_lat', 'tx_lon', 'rx_lat', 'rx_lon', 'length_km', ...
    'tx_h_m', 'rx_h_m', 'delta_h_m', 'itm_mode_code', 'itm_class', 'sea_fraction', 'free_space_db', ...
    'itm_1', 'itm_10', 'itm_50', 'p452_1', 'p452_10', 'p452_50', 'p2001_1', 'p2001_10', 'p2001_50'});
W.freq_mhz = repmat(options.Freq, height(W), 1);
if ~isfolder(options.OutDir), mkdir(options.OutDir); end
writetable(W, fullfile(options.OutDir, 'western_links.csv'));
diffraction_decomposition_rev1('Links', W, 'Freqs', options.Freq, 'Tag', "_west", ...
    'P2001Dir', options.P2001Dir, 'P452Dir', options.P452Dir);
end
