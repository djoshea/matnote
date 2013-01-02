function setPathMatNote()
    % requires matlab-utils to be on the path already
    matNoteRoot = pathToThisFile(); 
    fprintf('Path: Adding matNote at %s\n', matNoteRoot);

    addpath(matNoteRoot);
    addpath(fullfile(matNoteRoot, 'YAMLMatlab_0.4.3'));
end
