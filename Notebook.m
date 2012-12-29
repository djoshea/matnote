classdef Notebook < handle

    properties(SetAccess=private)
        settings % NotebookSettings instance

        pageCurrent = ''; % name of current page
    end

    properties(Constant, Hidden)
        CONTENT_DIR = 'content';
        DEPLOY_DIR = 'deploy';
        FIGURE_DIR_SUFFIX = '_figures';
    end

    properties(Dependent)
        name
        path
        contentPath
    end

    methods % Dependent properties implementation
        function name = get.name(nb)
            name = nb.settings.name;
        end
        function path = get.path(nb)
            path = nb.settings.path;
        end

        function path = get.contentPath(nb)
            path = fullfile(nb.settings.path, Notebook.CONTENT_DIR);
        end
    end

    methods % Constructor
        function nb = Notebook(nameOrSettings)
            % provide a notebook name --> settings looked up in NotebookSettingsStore
            % provide settings --> use those settings
            if nargin == 0
                printError();
            end
            if ischar(nameOrSettings)
                nss = NotebookSettingsStore();
                settings = nss.getNotebook(nameOrSettings);
            elseif isa(nameOrSettings, 'NotebookSettings')
                settings = nameOrSettings;
            else
                printError();
            end

            nb.settings = settings;
            nb.createPaths();

            function printError()
                error('Usage: Notebook(name or NotebookSettings instance)');
            end
        end

        % mkdir all paths needed by the notebook
        function createPaths(nb)
            if ~exist(nb.path, 'dir')
                debug('Creating %s\n', nb.path);
                mkdirRecursive(nb.path);
            end
            if ~exist(nb.contentPath, 'dir')
                debug('Creating %s\n', nb.contentPath);
                mkdirRecursive(nb.contentPath);
            end
        end
    end

    methods % Page switching and initialization
        % this is called whenever you write to a notebook before calling setPage
        function setPageDefault(nb)
            nb.setPageToday();
        end
        
        % use a page titled with today's date
        function setPageToday(nb)
            name = sprintf('%s', datestr(now, 'yyyy.mm.dd'));

            nb.setPage(name);
        end

        % use a page with a specific topical name
        % if the page exists already, it will be appended on to
        function setPage(nb, name)
            nb.pageCurrent = name;

            % check whether file already exists for status message
            file = nb.getFilePageYaml();
            if exist(file, 'file')
                appendStr = ' [appending]';
            else
                appendStr = '';
            end
            debug('Current page is %s at %s%s\n', nb.pageCurrent, file, appendStr);

            % generate yaml file in case it doesn't exist
            nb.createPageYaml();
            nb.writeSessionStart();
            
            % generate html file which references yaml file
            nb.writePageHtml();

            % make figures folder
            mkdirRecursive(nb.getPathFigures());
        end
    end
    
    methods % Page-relative directory and file lookup
        function fname = getFilePageYaml(nb)
            file = sprintf('%s.data.yaml', nb.pageCurrent);
            fname = fullfile(nb.contentPath, file);
        end

        function fname = getFilePageHtml(nb)
            file = sprintf('%s.html', nb.pageCurrent);
            fname = fullfile(nb.contentPath, file);
        end

        % get path for figures relative to content path, useful
        % for writing relative urls to the yaml file
        function relPath = getContentRelativePathFigures(nb)
            relPath = sprintf('%s%s', nb.pageCurrent, nb.FIGURE_DIR_SUFFIX);
        end

        % get path for figures for current page
        function path = getPathFigures(nb)
            relPath = nb.getContentRelativePathFigures();
            path = fullfile(nb.contentPath, relPath);
        end


        function createPageYaml(nb)
            fnamePageYaml = nb.getFilePageYaml();
            fhPageYaml = fopen(fnamePageYaml, 'a');
            if fhPageYaml == -1
                error('Could not open file %s', fhPageYaml);
            end
            fclose(fhPageYaml);
        end

        function writePageHtml(nb)
            fnamePageHtml = nb.getFilePageHtml();
            fhPageHtml = fopen(fnamePageHtml, 'w');
            if fhPageHtml == -1
                error('Could not open file %s', fhPageHtml);
            end

            % TODO write the html file here!
            
            fclose(fhPageHtml);
        end
    end

    methods % Write generic entry to current page
        function writeEntry(nb, data)
            if isempty(nb.pageCurrent)
                nb.setPageDefault();
            end

            fname = nb.getFilePageYaml();
            data.timestamp = datestr(now, 'yyyy.mm.dd HH:MM:SS');
            
            WriteYaml(fname, data, 0, 'append', true);
        end

        function writeSessionStart(nb)
            data.type = 'sessionStart';
            nb.writeEntry(data);
        end
    end

    methods % Write entry shortcuts
        function writeSection(nb, name, varargin)
            data.type = 'section';
            data.name = name;

            nb.writeEntry(data);
        end

        function writeNote(nb, text) 
            data.type = 'note';
            data.text = text;

            nb.writeEntry(data);
        end

        function writeFigure(nb, varargin)
            p = inputParser;
            p.addOptional('hFig', gcf, @ishandle);
            p.addParamValue('name', '', @ischar);
            p.addParamValue('caption', '', @ischar);
            p.parse(varargin{:});

            hFig = p.Results.hFig;
            name = p.Results.name;
            caption = p.Results.caption;

            if isempty(name)
                % no name provided, default to figure title
                ca = get(hFig, 'currentAxes');
                hTitle = get(ca, 'Title');
                if ~isempty(hTitle)
                    name = get(hTitle, 'String');
                end

                if isempty(name)
                    error('Please provide figure name as writeFigure(hFig, name) or give the plot a title()');
                end
            end

            if isempty(caption)
                caption = input('Figure caption (optional): ', 's');
            end

            % extensions
            exts = nb.settings.figureExtensions;
            nExts = length(exts);

            % directory where to place the figures
            relPath = nb.getContentRelativePathFigures();
            figPath = nb.getPathFigures();

            relFileList = cell(nExts, 1);

            % numerical suffix to append to name
            suffixNum = 0;

            % first build up the list of figure names
            % check for existence, first with no suffix, then with an increasing
            % numerical suffix
            while true
                success = false(nExts, 1);
                if suffixNum == 0
                    suffixStr = '';
                else
                    suffixStr = sprintf('_%03d', suffix);
                end

                for i = 1:nExts
                    ext = exts{i};
                    file = sprintf('%s%s.%s', name, suffixStr, ext);
                    % track both relative and full figure paths
                    relFileList{i} = fullfile(relPath, file);
                    fileList{i} = fullfile(figPath, file);
                    success(i) = true;

                    if exist(fileList{i}, 'file')
                        % increment the numerical suffix and try again
                        suffix = suffix + 1;
                        break;
                    end
                end

                if all(success)
                    break;
                end
            end

            % now that we've determined the suffixStr, save figure as extensions
            success = false(nExts, 1);
            for i = 1:nExts
                ext = exts{i};
                fileName = fileList{i};
                switch ext
                    case 'fig'
                        try 
                            saveas(hFig, fileName);
                            success(i) = true;
                        catch exc
                            tcprintf('light red', 'WARNING: Error saving as fig\n');
                            tcprintf('light red', exc.getReport());
                            fprintf('\n');
                        end
                    case 'svg'
                        try
                            plot2svg(fileName, hFig);
                            success(i) = true;
                        catch exc
                            tcprintf('light red', 'WARNING: Error saving to svg\n');
                            tcprintf('light red', exc.getReport());
                            fprintf('\n');
                        end
                    otherwise 
                        try
                            exportfig(hFig, fileName, 'format', ext, 'resolution', 300);
                            success(i) = true;
                        catch exc
                            tcprintf('light red', 'WARNING: Error saving to %s', ext);
                            tcprintf('light red', exc.getReport());
                            fprintf('\n');
                        end
                end
            end

            % save the entry to the yaml file
            for i = 1:nExts
                ext = exts{i};
                % relative path to file
                figures(i).relFile = relFileList{i};
                % is this the image file to embed?
                figures(i).ext = ext;
            end

            data.type = 'figure';
            data.name = name;
            data.caption = caption;
            data.figures = figures;

            nb.writeEntry(data);
        end
    end

end
