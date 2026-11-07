function app = itm_app_rev1(mode)
%ITM_APP_REV1 Self-test app for the ITM port, for MATLAB and MATLAB Runtime.
%   app = ITM_APP_REV1() opens a window with a Run self-test button, a
%   status box that reads PASSED or FAILED, and a table of every check
%   (see itm_selftest_rev1). It is the entry point that
%   build_itm_app_rev1 compiles, so the same checks run on a computer that
%   has only the MATLAB Runtime.
%
%   ITM_APP_REV1("--selftest") runs the checks without a window, prints
%   them, and (in a compiled app) exits with status 0 when they pass and
%   1 when they fail. Use it to verify an installation from a script:
%     itm_app --selftest
%   Add "--offline" to skip the checks that download terrain.
%
%   app is a struct of the UI handles. app.run() runs the self-test as if
%   the button were pressed, which the test suite uses.
%
%   The app is a programmatic uifigure (an .m file) rather than an App
%   Designer .mlapp, so changes stay readable in git.
%
%   See also itm_selftest_rev1, build_itm_app_rev1.

arguments (Repeating)
    mode (1,1) string
end
modes = [mode{:}];
if any(modes == "--selftest")
    app = headless(~any(modes == "--offline"));
    return
end

fig = uifigure('Name', 'ITM v1.4 point-to-point: self-test', 'Position', [100 100 900 560]);
grid = uigridlayout(fig, [4 1], 'RowHeight', {'fit', 'fit', 'fit', '1x'}, 'Padding', [16 16 16 16]);

title_lbl = uilabel(grid, 'Text', 'ITM v1.4 point-to-point (MATLAB port)', ...
    'FontSize', 18, 'FontWeight', 'bold');
title_lbl.Layout.Row = 1;

controls = uigridlayout(grid, [1 3], 'ColumnWidth', {160, 'fit', '1x'}, 'Padding', [0 0 0 0]);
controls.Layout.Row = 2;
run_btn = uibutton(controls, 'Text', 'Run self-test', 'FontSize', 14, 'FontWeight', 'bold');
net_box = uicheckbox(controls, 'Text', 'Include network checks (terrain downloads)', 'Value', true);
info_lbl = uilabel(controls, 'Text', sprintf('Terrain cache: %s', itm_default_terrain_dir()), ...
    'FontColor', [0.36 0.36 0.34], 'HorizontalAlignment', 'right');
info_lbl.Layout.Column = 3;

status_box = uitextarea(grid, 'Value', {'Not run yet. Press Run self-test.'}, 'Editable', 'off', ...
    'FontSize', 16, 'FontWeight', 'bold');
status_box.Layout.Row = 3;

log_table = uitable(grid, 'ColumnName', {'Check', 'Result', 'Detail', 'Seconds'}, ...
    'ColumnWidth', {260, 60, '1x', 60}, 'RowName', {}, 'Data', cell(0, 4));
log_table.Layout.Row = 4;

app = struct('figure', fig, 'button', run_btn, 'network', net_box, ...
    'status', status_box, 'table', log_table, 'run', @run_tests);
run_btn.ButtonPushedFcn = @(~, ~) run_tests();

if isdeployed
    waitfor(fig);     % keep a compiled app open until its window closes
end

    function passed = run_tests()
        run_btn.Enable = 'off';
        log_table.Data = cell(0, 4);
        removeStyle(log_table);
        set_status(sprintf('Running... (started %s)', char(datetime('now', 'Format', 'HH:mm:ss'))), ...
            [0.95 0.95 0.93], [0.12 0.12 0.12]);
        drawnow;
        try
            [passed, T] = itm_selftest_rev1('network', net_box.Value, 'progress', @add_row);
            n_pass = nnz(T.status == "PASS");
            n_fail = nnz(T.status == "FAIL");
            n_skip = nnz(T.status == "SKIP");
            msg = sprintf('%d passed, %d failed, %d skipped, %.1f s total', n_pass, n_fail, ...
                n_skip, sum(T.seconds));
            if passed
                set_status({['PASSED: all checks succeeded.  ' msg]}, [0.85 0.95 0.86], [0.0 0.36 0.0]);
            else
                failed = T.name(T.status == "FAIL");
                set_status([{['FAILED: ' msg]}; cellstr("  " + failed)], [0.99 0.88 0.88], [0.62 0.0 0.0]);
            end
        catch err
            passed = false;
            set_status({'FAILED: the self-test could not run.'; err.message}, ...
                [0.99 0.88 0.88], [0.62 0.0 0.0]);
        end
        run_btn.Enable = 'on';
    end

    function add_row(row)
        log_table.Data(end + 1, :) = {char(row.name), char(row.status), char(row.detail), ...
            round(row.seconds, 2)};
        r = size(log_table.Data, 1);
        color = containers.Map({'PASS', 'FAIL', 'SKIP'}, {[0.0 0.45 0.0], [0.7 0.0 0.0], [0.45 0.45 0.42]});
        addStyle(log_table, uistyle('FontColor', color(char(row.status)), 'FontWeight', 'bold'), ...
            'cell', [r 2]);
        scroll(log_table, 'bottom');
        drawnow;
    end

    function set_status(text, bg, fg)
        status_box.Value = text;
        status_box.BackgroundColor = bg;
        status_box.FontColor = fg;
    end
end

function passed = headless(network)
fprintf('ITM v1.4 point-to-point (MATLAB port): self-test\n');
[passed, T] = itm_selftest_rev1('network', network, 'progress', ...
    @(r) fprintf('  %-4s  %-42s  %s\n', r.status, r.name, r.detail));
if passed
    fprintf('PASSED: %d passed, %d skipped\n', nnz(T.status == "PASS"), nnz(T.status == "SKIP"));
else
    fprintf('FAILED: %d failed\n', nnz(T.status == "FAIL"));
end
if isdeployed
    exit(double(~passed));
end
end
