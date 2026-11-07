function itm_publish_file(tmp, dst)
%ITM_PUBLISH_FILE Rename a finished temporary file into place atomically.
%   The first writer wins: if dst already exists, tmp is deleted and the
%   existing file is kept. java.nio.file.Files.move with ATOMIC_MOVE is
%   used because movefile deletes then copies, so a reader in another
%   process could see a missing or partial file.

if isfile(dst)
    delete(tmp);
    return
end
try
    opts = javaArray('java.nio.file.CopyOption', 1);
    opts(1) = java.nio.file.StandardCopyOption.ATOMIC_MOVE;
    java.nio.file.Files.move(java.io.File(char(tmp)).toPath(), java.io.File(char(dst)).toPath(), opts);
catch
    if isfile(tmp)
        delete(tmp);       % another process published first, or no JVM
    end
end
end
