function wp_save_fig(fig, out, name)
%WP_SAVE_FIG Light theme, white background, 200 dpi PNG, then close.
if exist('theme', 'file') || exist('theme', 'builtin')
    theme(fig, 'light');
end
set(fig, 'Color', 'w');
exportgraphics(fig, fullfile(out, name + ".png"), 'Resolution', 200);
close(fig);
end
