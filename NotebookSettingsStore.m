classdef NotebookSettingsStore < SettingsStore
% Stores settings for the collection of notebooks located on this system.
%
% These notebooks may be located at different paths, but the deployed site
% folders for each notebook will be symlinked into a commonDeployRoot directory,
% where an index html file will be generated with links to each notebook.
% MatNote static methods handle symlinking into commonDeployRoot and generating
% the index file. 
%
% The utility functions provided are used to create and remove notebooks from 
% the collection. 
%
% You should create an instance of this class when first installing MatNote,
% set the values of the publically settable properties below, and call
% .saveSettings(path) where path is a folder on the path where the mat file
% containing the settings will be stored and read.
%

    properties
        % default folder where new notebook data folders will be created
        % unless manually overriden when calling createNotebook
        % This CANNOT be the same as commonDeployRoot as this will lead to naming
        % collisions
        defaultNotebookDataRoot = '~/notebooks/data';

        % common folder where the generated html site with all notebooks within
        % will be rooted. 
        % Deployed sites for each notebook will be symlinked inside here
        % allowing a common access point for all notebooks in this NotebookSettingsStore
        % at commonDeployRoot/index.html
        commonDeployRoot = '~/notebooks'

    end

    properties(Hidden)
        notebookMap 
    end

    properties(Dependent, Transient)
        nNotebooks
    end

    methods(Access=protected)
        % initialize default settings map
        function setDefaults(obj)
            obj.notebookMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
    end

    methods(Static)
        % where to store the settings file
        function name = getMatFileName() 
            name = 'notebookSettings';
        end
    end

    methods
        % number of notebooks whose settings are stored
        function n = get.nNotebooks(obj)
            n = obj.notebookMap.Count;
        end
        
        % return a list of all notebooks whose settings are stored
        function list = getListNotebooks(obj)
            list = obj.notebookMap.keys;
        end

        % does this settings store contain settings for this notebook? 
        % pass either a NotebookSettings object or the name as char
        function tf = hasNotebook(obj, nameOrSettings)
            if isa(nameOrSettings, 'NotebookSettings')
                name = nameOrSettings.name;
            elseif ischar(nameOrSettings)
                name = nameOrSettings;
            else
                error('.hasNotebook(arg): arg must be char name or NotebookSettings');
            end
            tf = obj.notebookMap.isKey(name);
        end

        function nb = createNotebook(obj, name, varargin)
            p = inputParser;
            p.addRequired(name, @(x) ischar(x) && ~isempty(x));
            p.addParamValue('path', '', @ischar);
            p.parse(name, varargin{:});

            path = p.Results.path;
            if isempty(path)
                % use default path by appending name onto defaultRootPath
                path = GetFullPath(fullfile(obj.defaultNotebookDataRoot, name));
                fprintf('Using default path %s\n', path);
            end

            mkdirRecursive(path);

            ns = NotebookSettings();
            ns.name = name;
            ns.path = path;

            obj.setNotebook(ns);
            obj.saveSettings();

            nb = Notebook(name);
            MatNote.initNotebookSite(nb); 
        end

        % add or update the info for notebook with name settings.name
        function setNotebook(obj, settings)
            p = inputParser;
            p.addRequired('settings', @(x) isa(x, 'NotebookSettings'));
            p.parse(settings);

            name = settings.name;

            if obj.hasNotebook(name)
                fprintf('Warning: overwriting existing notebook settings for %s\n', name);
            end

            obj.notebookMap(name) = settings;
        end

        % get setttings for notebook with name
        function ns = getNotebook(obj, name)
            if ~obj.hasNotebook(name)
                error('Notebook with name %s not found', name);
            end

            ns = obj.notebookMap(name);
        end

        % remove the settings for notebook
        % pass either a NotebookSettings object or the name as char
        function removeNotebook(obj, nameOrSettings)
            if isa(nameOrSettings, 'NotebookSettings')
                name = nameOrSettings.name;
            else
                name = nameOrSettings;
            end
            if obj.notebookMap.isKey(name)
                obj.notebookMap.remove(name);
            else
                fprintf('Warning: notebook with name %s not found', name);
            end
        end

        function disp(obj)
            nNotebooks = obj.nNotebooks;
            list = obj.getListNotebooks();
            
            fprintf('NotebookSettingsStore: %d notebooks\n', nNotebooks);
            for i = 1:nNotebooks
                name = list{i};
                settings = obj.getNotebook(name);
                tcprintf('light blue', '\t%s\n', settings.describe());
            end
            fprintf('\n');

            disp@SettingsStore(obj);
        end
    end
end
