function run_3ghz_rev1(options)
%RUN_3GHZ_REV1 Run every MATLAB analysis behind the 3 GHz working paper, in order.
%   RUN_3GHZ_REV1() runs, serially, and writes CSV results to figures/ and
%   chart_data/ (the Python scripts then only draw figures from them):
%     1  make_wp_figures_rev1(Freqs=3000)  smooth earth, knife edge, the 60
%                                          real-terrain links, resolution,
%                                          archetypes, sweeps, radials
%     2  diffraction_decomposition_rev1    ITM's diffraction terms, ablation
%     3  export_deep_dive_data_rev1        the model results as CSV
%     4  sensitivity_rev1                  model settings on the 60 links
%     5  grid_separation_rev1, DC and LA   single-entry 100 km grids
%     6  uncertainty_rev1                  bootstrap intervals
%     7  paper_numbers_3ghz_rev1           every number the text quotes
%   The ITU-R databank comparison (compare_dbsg3_rev1) is separate; its
%   tables are inputs to steps 6 and 7.
%
%   Options: Models (true: run steps 1 and 2; false starts at step 3 from
%   the saved results), Grid (true), P2001Dir, P452Dir.

arguments
    options.Models (1,1) logical = true
    options.Grid (1,1) logical = true
    options.P2001Dir (1,1) string = ""
    options.P452Dir (1,1) string = ""
end
d = {'P2001Dir', options.P2001Dir, 'P452Dir', options.P452Dir};
if options.Models
    make_wp_figures_rev1('Freqs', 3000, d{:});
    diffraction_decomposition_rev1(d{:});
end
export_deep_dive_data_rev1();
sensitivity_rev1(d{:});
if options.Grid
    grid_separation_rev1('Site', "dc", d{:});
    grid_separation_rev1('Site', "la", d{:});
end
uncertainty_rev1();
paper_numbers_3ghz_rev1();
end
