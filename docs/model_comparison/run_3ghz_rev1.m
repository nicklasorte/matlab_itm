function run_3ghz_rev1(options)
%RUN_3GHZ_REV1 Rerun the working paper's model calculations at 3 GHz only.
%   RUN_3GHZ_REV1() runs, serially, at 3000 MHz:
%     make_wp_figures_rev1(Freqs=3000)      smooth earth, knife edge, the 60
%                                           real-terrain links, resolution,
%                                           archetypes, sweeps, radials
%     diffraction_decomposition_rev1        ITM's diffraction terms and the
%                                           ablation
%     export_wp_chart_data_rev1             chart_data/*.csv
%   and writes everything to figures/ and chart_data/, replacing the
%   three-frequency results (which stay in git history). The ITU-R databank
%   comparison is measured data and is not rerun.
%
%   With Push=true it commits the outputs to branch wp-3ghz and pushes,
%   writing a log line per stage to figures/run_3ghz_log.txt.

arguments
    options.Push (1,1) logical = true
    options.Freq (1,1) double = 3000
end
here = fileparts(mfilename('fullpath'));
logf = fullfile(here, 'figures', 'run_3ghz_log.txt');
note = @(s) fprintf(fopen(logf, 'a'), '%s  %s\n', datestr(now, 31), s); %#ok<TNOW1,DATST>
fclose('all');
note(sprintf('start, %g MHz', options.Freq)); fclose('all');
try
    t = tic;
    make_wp_figures_rev1(Freqs=options.Freq);
    note(sprintf('make_wp_figures_rev1 done in %.0f s', toc(t))); fclose('all');
    t = tic;
    diffraction_decomposition_rev1();
    note(sprintf('diffraction_decomposition_rev1 done in %.0f s', toc(t))); fclose('all');
    export_wp_chart_data_rev1();
    note('export_wp_chart_data_rev1 done'); fclose('all');
catch err
    note(['ERROR: ' err.identifier ' ' err.message]); fclose('all');
    for k = 1:min(numel(err.stack), 6)
        note(sprintf('  at %s line %d', err.stack(k).name, err.stack(k).line)); fclose('all');
    end
end
if options.Push
    root = fileparts(fileparts(here));
    cmd = sprintf(['cd "%s" && git checkout -q -B wp-3ghz && git add -A docs/model_comparison/figures ' ...
        'docs/model_comparison/chart_data && git commit -q -m "3 GHz rerun outputs" ; git push -q -f origin wp-3ghz'], root);
    system(cmd);
end
end
