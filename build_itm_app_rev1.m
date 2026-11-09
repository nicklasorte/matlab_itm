function results = build_itm_app_rev1(options)
%BUILD_ITM_APP_REV1 Compile the ITM app with MATLAB Compiler.
%   results = BUILD_ITM_APP_REV1() builds itm_app_rev1, the self-test app,
%   as a standalone application for the free MATLAB Runtime, in the build
%   folder of this repository.
%
%   The build packages everything the code opens by name at run time,
%   which dependency analysis can't find on its own:
%     data/             ITU-R TropoClim.txt and N050.TXT
%     private/          helper functions
%     tests/reference/  NTIA and C++ reference cases for the self-test
%   ITU forbids redistributing its maps: keep the app inside your
%   organization. Terrain tiles aren't packaged; the app downloads them to
%   the cache on demand (C:\propagation_cache\matlab_itm on Windows,
%   ~/.matlab_itm elsewhere),
%   or reads a cache filled by itm_setup_rev1
%   (set MATLAB_ITM_CACHE and MATLAB_ITM_OFFLINE=1 on offline machines).
%
%   Name-value options:
%     entry       "app" (default) for itm_app_rev1, or "cli" for
%                 itm_cli_rev1, a command-line path-loss tool
%     output_dir  Build folder (<repo>/build/<entry>)
%     installer   Also build an installer that downloads the MATLAB
%                 Runtime on the target computer (false)
%
%   Compiled apps are platform-specific: build on Windows for Windows.
%   The target computer needs the MATLAB Runtime for the release used to
%   build (R2025b), which the installer can fetch.
%   Required products: MATLAB and Mapping Toolbox.

arguments
    options.entry (1,1) string {mustBeMember(options.entry, ["app", "cli"])} = "app"
    options.output_dir (1,1) string = ""
    options.installer (1,1) logical = false
end

root = fileparts(mfilename('fullpath'));
if strlength(options.output_dir) == 0
    options.output_dir = fullfile(root, 'build', options.entry);
end
extra = {fullfile(root, 'data'), fullfile(root, 'private'), fullfile(root, 'tests', 'reference')};

if options.entry == "app"
    opts = compiler.build.StandaloneApplicationOptions(fullfile(root, 'itm_app_rev1.m'), ...
        'OutputDir', options.output_dir, 'ExecutableName', 'itm_app', ...
        'AdditionalFiles', extra, 'Verbose', 'off');
else
    opts = compiler.build.StandaloneApplicationOptions(fullfile(root, 'itm_cli_rev1.m'), ...
        'OutputDir', options.output_dir, 'ExecutableName', 'itm_cli', ...
        'AdditionalFiles', extra, 'Verbose', 'off');
end
results = compiler.build.standaloneApplication(opts);
fprintf('Built %s\n', strjoin(string(results.Files), ', '));

if options.installer
    compiler.package.installer(results, 'OutputDir', fullfile(options.output_dir, 'installer'), ...
        'RuntimeDelivery', 'web', 'ApplicationName', "ITM " + options.entry);
    fprintf('Installer in %s\n', fullfile(options.output_dir, 'installer'));
end
end
