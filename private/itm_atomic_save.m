function itm_atomic_save(file_name, data)
%ITM_ATOMIC_SAVE Save a struct to a .mat file without exposing a partial file.
%   Writes to a uniquely named temporary file in the same folder, then
%   renames it into place with java.nio.file.Files.move (ATOMIC_MOVE). An
%   existing file is kept (first writer wins), since any process can
%   rebuild the cache. movefile is not used: it deletes then copies, so a
%   reader in another process can see a missing or partial file.
%   Adapted from p2001_atomic_save_rev1 in nicklasorte/itu_p2001.

if isfile(file_name)
    return
end
[folder, name] = fileparts(file_name);
[~, token] = fileparts(tempname);
tmp = fullfile(folder, [char(name) '_' token '.part.mat']);
save(tmp, '-struct', 'data');
try
    if isfile(file_name)
        delete(tmp);
        return
    end
    opts = javaArray('java.nio.file.CopyOption', 1);
    opts(1) = java.nio.file.StandardCopyOption.ATOMIC_MOVE;
    java.nio.file.Files.move(java.io.File(tmp).toPath(), java.io.File(char(file_name)).toPath(), opts);
catch err
    if isfile(tmp)
        delete(tmp);
    end
    if ~isfile(file_name)
        error('itm:cache:SaveFailed', 'Cannot write %s: %s', file_name, err.message);
    end
end
end
