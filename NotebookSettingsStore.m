classdef NotebookSettingsStore < SettingsStore

    properties
        notebookMap 

        defaultPathRoot = '~/notebooks';
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

        function ns = createNotebook(obj, name, varargin)
            p = inputParser;
            p.addRequired(name, @(x) ischar(x) && ~isempty(x));
            p.addParamValue('path', '', @ischar);
            p.parse(name, varargin{:});

            path = p.Results.path;
            if isempty(path)
                % use default path by appending name onto defaultRootPath
                path = GetFullPath(fullfile(obj.defaultPathRoot, name));
                fprintf('Using default path %s\n', path);
            end

            mkdirRecursive(path);
            
            ns = NotebookSettings();
            ns.name = name;
            ns.path = path;

            obj.setNotebook(ns);
        end

        % add or update the info for notebook with name settings.name
        function setNotebook(obj, settings)
            p = inputParser;
            p.addRequired('settings', @(x) isa(x, 'NotebookSettings'));
            p.parse(settings);

            name = settings.name;

            if obj.hasNotebook(name)
                fprintf('Warning: overwriting existing notebook settings for %s', name);
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
            if tf.notebookMap.isKey(name)
                obj.notebookMap.removeKey(name);
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

            fprintf('\nDefault path root: %s\n', obj.defaultPathRoot);
            fprintf('\n');
        end
    end
end
