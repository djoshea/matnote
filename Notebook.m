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

    methods % Hyde generation shortcuts
        function update(nb)
            MatNote.initNotebookSite(nb);
            nb.generate();
        end
        
        function generate(nb)
            nb.generatePageIndex();
            MatNote.generateNotebookSite(nb);
        end
    end

    methods % Page Index generation

        % list all pages in this notebook
        function pages = getListPages(nb)
            % list all pages for this notebook by finding all .html files
            % in the directory, excluding those below
            excluded = {'index.html'};
            search = fullfile(nb.contentPath, '*.html');
            pages = dir(search);
            exclude = ismember({pages.name}, excluded);
            pages = pages(~exclude);
        end

        % return the datenum timestamp when this notebook was last modified
        % calculated as the most recent modification date of all pages within
        function ts = getLastModified(nb)
            pages = nb.getListPages;
            tsList = [pages.datenum];
            ts = max(tsList);
        end

        % get the filename where this notebook's page index is generated
        function file = getFilePageIndex(nb)
            path = nb.contentPath;
            file = fullfile(path, 'index.html');
        end

        % generate the notebook's page index file
        function generatePageIndex(nb)
            fname = nb.getFilePageIndex();
            debug('Generating page index at %s\n', fname);

            pages = nb.getListPages();

            fid = fopen(fname, 'w');
            if fid == -1
                error('Could not open file %s\n', fname);
            end

            fprintf(fid, '---\n');
            fprintf(fid, 'extends: notebook.j2\n');
            fprintf(fid, 'notebook: %s\n', nb.name);

            % print list of pages as yaml array
            if ~isempty(pages)
                fprintf(fid, 'pages:\n');

                for i = 1:length(pages)
                    page = pages(i);
                    [~, nameNoExt] = fileparts(page.name);
                    fprintf(fid, '  - name: %s\n', nameNoExt);
                    fprintf(fid, '    url: %s\n', page.name);
                    fprintf(fid, '    modified: %s\n', datestr(page.datenum));
                end
            end

            fprintf(fid, '---');
            fclose(fid);
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
            oldPage = nb.pageCurrent;

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
            if ~exist(file, 'file')
                nb.createPageYaml();
                
                % make figures folder
                mkdirRecursive(nb.getPathFigures());
            end

            nb.writeSessionStart();
        end
    end
    
    methods % Page-relative directory and file lookup
        function fname = getFilePageYaml(nb)
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
            if exist(fnamePageYaml, 'file')
                return;
            end
            debug('Creating page at %s\n', fnamePageYaml);
            fid = fopen(fnamePageYaml, 'w');
            if fid == -1
                error('Could not open file %s', fid);
            end

            % write header to page yaml
            fprintf(fid, '---\n');
            fprintf(fid, 'extends: page.j2\n');
            fprintf(fid, 'notebook: %s\n', nb.name);
            fprintf(fid, 'page: %s\n', nb.pageCurrent);
            fprintf(fid, 'created: %s\n', datestr(now, 'yyyy.mm.dd HH:MM:SS'));
            fprintf(fid, 'entries:\n');
            fprintf(fid, '---\n');

            fclose(fid);
        end

    end

    methods % Write generic entry to current page
        function writeEntry(nb, data)
            if isempty(nb.pageCurrent)
                nb.setPageDefault();
            end
            if ~isfield(data, 'timestamp')
                data.timestamp = datestr(now, 'yyyy.mm.dd HH:MM:SS');
            end

            % check for yaml file for page, initialize it if missing
            fname = nb.getFilePageYaml();
            if ~exist(fname, 'file')
                nb.createPageYaml();
            end

            % remove --- at end of file so we can append new yaml data
            MatNote.removeTrailingDashes(fname);

            % open yaml file for page
            fid = fopen(fname, 'a');
            if fid == -1
                error('Could not open file %s', fname);
            end

            % write new yaml data for entry, use WriteYaml to handle escaping, nesting, etc.
            % write struct as another element of the entries array
            yamlText = char(WriteYaml('', data));
            
            NEWLINE = char(10);
            wroteDash = false;
            remain = yamlText;
            while ~isempty(strtrim(remain)) && ...
                  ~strcmp(strtrim(remain), NEWLINE)
                [token remain] = strtok(remain, NEWLINE);
                if remain(1) == NEWLINE
                    remain = remain(2:end);
                end
                if wroteDash
                    prefix = '  ';
                else
                    prefix = '- ';
                    wroteDash = true;
                end
                
                fprintf(fid, '%s%s\n', prefix, token);
                
                if isempty(remain)
                    break;
                end
            end
            fprintf(fid, '---');
            fclose(fid);
        end

        function writeSessionStart(nb)
            data.type = 'sessionStart';
            nb.writeEntry(data);
        end
    end

    methods % Write entry shortcuts
        function writeSection(nb, name, subtitle)
            if nargin < 2
                name = input('Section name: ', 's');
            end
            if nargin < 3
                subtitle = input('Section subtitle: ', 's');
            end
            data.type = 'section';
            data.name = name;
            data.subtitle = subtitle;

            nb.writeEntry(data);
        end

        function writeNote(nb, text) 
            if nargin < 2 
                text = input('Note text: ', 's');
            end
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
                    name = input('Figure name: ', 's');
                end
            end

            if isempty(caption)
                caption = input('Figure caption (optional): ', 's');
            end

            % have to set a page now in order to save the figures in the right place
            if isempty(nb.pageCurrent)
                nb.setPageDefault();
            end

            % extensions
            exts = nb.settings.figureExtensions;
            nExts = length(exts);

            % directory where to place the figures
            relPath = nb.getContentRelativePathFigures();
            figPath = nb.getPathFigures();
            suffixNum = 0;
            while true 
                success = false(nExts, 1);
                if suffixNum == 0
                    suffixStr = '';
                else
                    suffixStr = sprintf('_%03d', suffixNum);
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
                        suffixNum = suffixNum + 1;
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
                debug('Saving figure as %s\n', fileName);
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
                figures(i).url = relFileList{i};
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
