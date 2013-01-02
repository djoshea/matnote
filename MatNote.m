classdef MatNote  

    methods(Static)
        % generate everything: all notebooks and the notebook index site 
        function generate()
            MatNote.generateNotebookIndexSite();

            nss = NotebookSettingsStore();
            list = nss.getListNotebooks();
            for i = 1:length(list)
                nb = Notebook(list{i});
                nb.generate();
            end
        end

        function update()
            MatNote.initNotebookIndexSite();
            MatNote.generateNotebookIndexSite();

            nss = NotebookSettingsStore();
            list = nss.getListNotebooks();
            for i = 1:length(list)
                nb = Notebook(list{i});
                nb.update();
            end
        end

        % view notebook index root in browser
        function view()
            nss = NotebookSettingsStore();
            fname = fullfile(GetFullPath(nss.commonDeployRoot), 'index.html');
            MatNote.viewInBrowser(fname);
        end

    end

    methods(Static) % Shortcuts to notebook management functions in NotebookSettingsStore

        % Installation script that interactively prompts for settings and
        % ends with a working install
        function install(varargin)
            p = inputParser;
            p.addParamValue('settingsPath', '', @ischar);
            p.addParamValue('defaultNotebookDataRoot', '', @ischar);
            p.addParamValue('commonDeployRoot', '', @ischar);
            p.parse(varargin{:});

            nss = NotebookSettingsStore();

            % get a valid commonDeployRoot
            while true
                current = p.Results.commonDeployRoot;
                nss.commonDeployRoot = GetFullPath(...
                    requestIfBlank(current, ...
                    nss.commonDeployRoot, 'Common generated html root'));
                try
                    mkdirRecursive(nss.commonDeployRoot);
                    break;
                catch
                    fprintf('Could not create directory %s', nss.defaultNotebookDataRoot);
                    current = '';
                end
            end

            % get a valid defaultNotebookDataRoot 
            while true
                current = p.Results.defaultNotebookDataRoot;
                nss.defaultNotebookDataRoot = GetFullPath(...
                    requestIfBlank(current, ...
                    nss.defaultNotebookDataRoot, 'Default notebook data root'));

                % check ~= commonDeployRoot 
                if strcmp(nss.defaultNotebookDataRoot, nss.commonDeployRoot)
                    fprintf('Error: cannot be the same as commonDeployRoot\n');
                    current = '';
                    continue;
                end

                try
                    mkdirRecursive(nss.defaultNotebookDataRoot);
                    break;
                catch
                    fprintf('Could not create directory %s\n', nss.defaultNotebookDataRoot);
                end
            end

            % get list of folders on path
            pathStr = path();
            split = regexp(pathStr, '(?<dir>[^:]*):*', 'names');
            pathDirs = {split.dir};
            
            if ismember(pwd, pathDirs)
                default = pwd;
            else
                default = pathDirs{1};
            end

            while true
                current = p.Results.settingsPath;
                settingsPath = GetFullPath(...
                    requestIfBlank(current, default, ...
                    'Settings .mat file location (on path)'));

                if ~ismember(settingsPath, pathDirs)
                    fprintf('Error: settings .mat file be on the MATLAB path\n');
                    continue;
                end
                break;
            end

            nss.saveSettings(settingsPath);

            fprintf('MatNote successfully installed.\n');
            MatNote.help();

            % utility for prompting the user to type in values
            function value = requestIfBlank(current, default, prompt)
                if ~isempty(current)
                    value = current;
                else
                    promptFull = sprintf('%s [press return for %s]:\n> ', prompt, default);
                    value = input(promptFull, 's'); 
                    if isempty(value)
                        % user just pressed return
                        value = default;
                    end
                end
            end
        end

        function help()
            tcprintf('light yellow', 'Welcome to MatNote!\n\n');

            fprintf('Install or adjust settings interactively: \n');
            tcprintf('light blue', '\tMatNote.install()\n');

            fprintf('Create a new notebook: \n');
            tcprintf('light blue', '\tMatNote.createNotebook(name)\n');

            fprintf('Create a new page in a notebook: \n');
            tcprintf('light blue', '\tnb = Notebook(name);\n');
            tcprintf('light blue', '\tnb.setPage(pageName);');
            fprintf(' %% topical page by name\n');
            tcprintf('light blue', '\tnb.setPageToday(pageName);');
            fprintf(' %% page named by today''s date\n');

            fprintf('Create a new note in a notebook page: \n');
            tcprintf('light blue', '\tnb.writeSection(sectionName, subtitle);\n');
            tcprintf('light blue', '\tnb.writeNote(noteText);\n');
            tcprintf('light blue', '\tnb.writeFigure(figH, figName);\n');

            fprintf('Access MatNote settings:\n');
            tcprintf('light blue', '\tnss = NotebookSettingsStore();\n');
            tcprintf('light blue', '\tnss.commonDeployRoot = ''/path/to/newRoot'';\n');
            tcprintf('light blue', '\tnss.saveSettings()\n');
            fprintf('\n');
        end

        function nb = createNotebook(varargin)
            nss = NotebookSettingsStore();
            ns = nss.createNotebook(varargin{:});
            nss.saveSettings();

            nb = Notebook(ns.name);
        end

        function removeNotebook(varargin)
            nss = NotebookSettingsStore();
            nss.removeNotebook(varargin{:});
            nss.saveSettings();
        end

        function names = listNotebooks(varargin)
            nss = NotebookSettingsStore();
            names = nss.getListNotebooks(varargin{:});
            nss.saveSettings();
        end
    end

    methods(Static) % Notebook-specific hyde site generation
        % create a hyde site for the current notebook
        % by copying from the siteTemplate folder
        % we only copy the non-content pages one by one so that we will not
        % overwrite any existing content if the site is already existing
        function initNotebookSite(nb)
            debug('Initializing notebook site at %s\n', nb.path);
            mkdirRecursive(nb.path); 
            mkdirRecursive(nb.contentPath);
           
            tDir = fullfile(pathToThisFile(), 'siteTemplate');

            % copy content/media
            copyfile(fullfile(tDir, 'content', 'media'), fullfile(nb.contentPath, 'media'), 'f');
            
            % copy layout
            copyfile(fullfile(tDir, 'layout'), fullfile(nb.path, 'layout'), 'f');

            % copy yaml
            copyfile(fullfile(tDir, 'info.yaml'), fullfile(nb.path, 'info.yaml'), 'f');
            copyfile(fullfile(tDir, 'site.yaml'), fullfile(nb.path, 'site.yaml'), 'f');
        end

        % generate the deployed html site for the current network 
        % essentially call `hyde gen` within the site directory
        function generateNotebookSite(nb)
            contentDir = fullfile(nb.contentPath);
            if ~exist(contentDir, 'dir')
                MatNote.initNotebookSite(nb);
            end

            debug('Generating site for notebook %s at %s\n', nb.name, nb.path);

            cmd = sprintf('hyde --sitepath %s gen', nb.path);
            [status result] = unix(cmd);            

            if status
                fprintf(result);
                fprintf('\n');
                error('Could not generate site: hyde gen error');
            end

            MatNote.deployNotebookSite(nb);
        end

        % symlink the deployed site into the common 
        function deployNotebookSite(nb)
            % symlink the deploy directory for this notebook into the 
            % commonDeployRoot as the name of the notebook
            ns = NotebookSettingsStore();
            dest = GetFullPath(fullfile(ns.commonDeployRoot, nb.name));
            src = GetFullPath(fullfile(nb.path, Notebook.DEPLOY_DIR)); 

            debug('Deploying notebook %s to %s\n', nb.name, dest);
            if exist(dest, 'file')
                return;
            end
            makeSymLink(src, dest);
            
            % regenerate the notebook index page to include this notebook
        end
    end

    methods(Static) % Methods for generating notebook index site at commonDeployRoot
        % get the location where the hyde site for the notebook index site will
        % be located
        function path = getNotebookIndexSiteDataFolder()
            nss = NotebookSettingsStore();
            path = fullfile(nss.commonDeployRoot, 'notebookIndex');
        end
        
        % create the hyde site skeleton for the outer site that links to each notebooks
        % content
        function initNotebookIndexSite()
            templateName = 'notebookIndexTemplate';
            templateDir = fullfile(pathToThisFile(), templateName);
            dest = MatNote.getNotebookIndexSiteDataFolder();

            debug('Initializing notebookIndex site at %s\n', dest); 
            mkdirRecursive(dest);
            copyfile(templateDir, dest, 'f');
        end

        % generate the index page which links to all notebooks
        function generateNotebookIndexFile()
            nss = NotebookSettingsStore();
            dest = fullfile(MatNote.getNotebookIndexSiteDataFolder(), 'content');

            if ~exist(dest, 'dir')
                MatNote.initNotebookIndexSite();
            end

            fname = fullfile(dest, 'index.html');
            debug('Generating notebookIndex file at %s\n', fname);

            notebookNames = nss.getListNotebooks(); 
            
            fid = fopen(fname, 'w'); 
            fprintf(fid, '---\n');
            fprintf(fid, 'extends: notebookIndex.j2\n');
            fprintf(fid, 'created: %s\n', datestr(now, 'yyyy.mm.dd HH:MM:SS'));

            if ~isempty(notebookNames)
                fprintf(fid, 'notebooks:\n');

                for i = 1:length(notebookNames)
                    fprintf(fid, '-\n');
                    fprintf(fid, '  name: %s\n', notebookNames{i});
                    fprintf(fid, '  url: %s/index.html\n', notebookNames{i});
                end
            end

            fprintf(fid, '---\n');
        end

        % call hyde gen on the notebookIndex site
        % deploy inside commonDeployRoot
        function generateNotebookIndexSite()
            MatNote.generateNotebookIndexFile();

            nss = NotebookSettingsStore();
            sitePath = MatNote.getNotebookIndexSiteDataFolder;
            deploy = nss.commonDeployRoot;

            debug('Generating notebookIndexSite at %s\n', sitePath);
            cmd = sprintf('hyde --sitepath "%s" gen --deploy "%s"', sitePath, deploy);
            
            %debug('Running %s', cmd);
            [status result] = unix(cmd);            

            if status
                fprintf(result);
                fprintf('\n');
                error('Could not generate notebookIndex site: hyde gen error');
            end
        end

    end

    methods(Static) % Miscellaneous utilities 
        function removeTrailingDashes(fname)
            scriptName = fullfile(pathToThisFile(), 'removeTrailingDashes.sh');
            cmd = sprintf('sh "%s" "%s"', scriptName, fname);
            %debug('Running %s\n', cmd);
            system(cmd);
        end 

        % utility for opening a file in the browser
        function viewInBrowser(fname)
            if ismac
                cmd = sprintf('open "%s"', fname);
                system(cmd);
            elseif isunix
                % TODO figure out how to use default browser reliably
                % for now just open firefox
                cmd = sprintf('export LD_LIBRARY_PATH=/usr/lib/firefox && export DISPLAY=:0.0 && firefox "%s"', fname);
                unix(cmd);
            else
                winopen(fname);
            end
        end
    end
end
