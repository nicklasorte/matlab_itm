classdef test_deploy_rev1 < matlab.unittest.TestCase
    %TEST_DEPLOY_REV1 Build the self-test app and run the compiled binary.
    %   Builds itm_app_rev1 with build_itm_app_rev1 (MATLAB Compiler) into a
    %   temporary folder, then runs the executable outside MATLAB with
    %   --selftest, using this MATLAB installation as the runtime. The
    %   compiled app must exit with status 0 and print PASSED. This is the
    %   check that every file the code opens at run time was packaged.
    %
    %   Takes 1 to 2 minutes. Tag "Compile"; skip it with
    %     import matlab.unittest.selectors.HasTag
    %     run(testsuite('tests').selectIf(~HasTag('Compile')))
    %
    %   Run: runtests('tests/test_deploy_rev1.m')

    methods (TestClassSetup)
        function add_path(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end
    end

    methods (Test, TestTags = {'Compile'})
        function compiled_app_passes_selftest(tc)
            tc.assumeTrue(license('test', 'Compiler') && ~isempty(ver('compiler')), ...
                'MATLAB Compiler is not installed.');
            out = string(tempname);
            tc.addTeardown(@() rmdir(out, 's'));
            build_itm_app_rev1(output_dir=out);

            [status, text] = run_compiled(out, "--selftest --offline");
            tc.verifyEqual(status, 0, "Compiled app failed:" + newline + text);
            tc.verifyTrue(contains(text, "PASSED"), text);
            tc.verifyTrue(contains(text, "740 cases"), "Reference cases missing from the app:" + newline + text);

            % With network: terrain downloads into an empty cache work from
            % the compiled app
            cache = fullfile(out, "cache");
            [status, text] = run_compiled(out, "--selftest", "MATLAB_ITM_CACHE=" + cache);
            tc.verifyEqual(status, 0, "Compiled app (network) failed:" + newline + text);
            tc.verifyTrue(contains(text, "PASSED"), text);
        end
    end
end

function [status, text] = run_compiled(out, args, env)
% Runs the built executable with this MATLAB as its runtime
if nargin < 3
    env = "";
end
if ispc
    exe = fullfile(out, "itm_app.exe");
    prefix = "";
    if strlength(env) > 0
        prefix = "set """ + env + """ && ";
    end
    cmd = prefix + """" + exe + """ " + args;
else
    script = fullfile(out, "run_itm_app.sh");
    cmd = env + " """ + script + """ """ + matlabroot + """ " + args;
end
[status, text] = system(cmd + " 2>&1");
text = string(text);
end
