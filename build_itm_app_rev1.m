function results = build_itm_app_rev1(output_dir)
%BUILD_ITM_APP_REV1 Compile the ITM command-line app with MATLAB Compiler.
%   results = BUILD_ITM_APP_REV1(output_dir) builds itm_cli_rev1 as a
%   standalone application that runs on the free MATLAB Runtime. The ITU
%   data files (data/TropoClim.txt, data/N050.TXT) are packaged into the
%   app, so it never downloads them. ITU forbids redistributing these maps:
%   keep the app inside your organization. Terrain tiles are not packaged:
%   the app downloads them on demand to the user's tile cache (see
%   itm_terrain_elevation_rev1), or reads a pre-filled cache
%   (itm_setup_rev1) named by the MATLAB_ITM_CACHE environment variable.
%
%   To compile your own app instead, add these files to it: every
%   itm_*_rev1.m function, the private folder, and the data folder.
%
%   Required products (from matlab.codetools.requiredFilesAndProducts):
%   MATLAB and Mapping Toolbox.

arguments
    output_dir (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'build')
end

root = fileparts(mfilename('fullpath'));
opts = compiler.build.StandaloneApplicationOptions(fullfile(root, 'itm_cli_rev1.m'), ...
    'OutputDir', output_dir, ...
    'ExecutableName', 'itm_cli', ...
    'AdditionalFiles', {fullfile(root, 'data'), fullfile(root, 'private')}, ...
    'Verbose', 'off');
results = compiler.build.standaloneApplication(opts);
fprintf('Built %s\n', strjoin(string(results.Files), ', '));
end
