classdef NotebookSettings < handle
% Stores settings for a particular named notebook
% These are stored in aggregate using the NotebookSettingsStore class
% as a lookup table by name

    properties
        % name of the notebook, used as the key in NotebookSettingsStore
        name

        % path to store the full path to notebook resources
        path

        figureExtensions = {'png', 'svg', 'fig'};
    end

    methods
        function str = describe(ns)
            str = sprintf('Notebook %s at %s', ns.name, ns.path);
        end

        function disp(ns)
            tcprintf('light blue', '%s\n', ns.describe());

            disp@handle(ns);
        end
    end
end
