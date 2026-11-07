classdef test_app_rev1 < matlab.unittest.TestCase
    %TEST_APP_REV1 Checks the deployable self-test and the app around it.
    %   Run: runtests('tests/test_app_rev1.m')

    methods (TestClassSetup)
        function add_path(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end
    end

    methods (Test)
        function selftest_offline_passes(tc)
            [ok, T] = itm_selftest_rev1(network=false);
            tc.verifyTrue(ok, strjoin(T.name(T.status == "FAIL") + ": " + T.detail(T.status == "FAIL"), newline));
            tc.verifyEqual(nnz(T.status == "PASS"), 7);
            tc.verifyEqual(nnz(T.status == "SKIP"), 3);
        end

        function selftest_progress_called_per_check(tc)
            rows = {};
            itm_selftest_rev1(network=false, progress=@(r) store(r));
            tc.verifyNumElements(rows, 10);
            function store(r)
                rows{end + 1} = r;
            end
        end

        function app_button_reports_result(tc)
            app = itm_app_rev1();
            tc.addTeardown(@() delete(app.figure));
            app.network.Value = false;
            passed = app.run();
            tc.verifyTrue(passed);
            tc.verifyTrue(startsWith(app.status.Value{1}, 'PASSED'));
            tc.verifySize(app.table.Data, [10 4]);
            tc.verifyEqual(app.button.Enable, matlab.lang.OnOffSwitchState.on);
        end
    end
end
