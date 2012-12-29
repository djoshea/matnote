classdef MatNoteTools  

    methods(Static)
        % create a hyde site for the current notebook
        % by copying from the siteTemplate folder
        % we only copy the non-content pages one by one so that we will not
        % overwrite any existing content if the site is already existing
        function initSite(nb)
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
        function generateSite(nb)
            cmd = sprintf('hyde --sitepath %s gen', nb.path);
            debug('Running %s\n', cmd);
            [status result] = unix(cmd);            

            if status
                fprintf(result);
                fprintf('\n');
                error('Could not generate site: hyde gen error');
            else
                fprintf(result);
            end
        end

        % symlink the deployed site into the common 
        function deploySite(nb)
            % symlink the deploy directory for this notebook into the 
            % commonDeployRoot as the name of the notebook
            dest = fullfile(NotebookSettingsStore.commonDeployRoot, nb.name);
            src = fullfile(nb.path, Notebook.DEPLOY_DIR); 

            debug('Symlinking notebook deploy: %s -> %s\n', src, dest);
            makeSymLink(src, dest);
            
            % regenerate the notebook index page to include this notebook
        end
    end

    methods(Static) % Methods for generating notebook index site at commonDeployRoot
        % create the hyde site skeleton for the outer site that links to each notebooks
        % content
        function initNotebookIndexSite()
            templateName = 'notebookIndexTemplate';
            name = 'notebookIndex';

            nss = NotebookSettingsStore();
            templateDir = fullfile(pathToThisFile(), templateName);
            dest = nss.commonDeployRoot;

            debug('Initializing notebookIndex site at %s\n', dest); 
            copyfile(templateDir, dest, 'f');
            movefile(templateName, name, 'f');
        end

        % generate the index page which links to all notebooks
        function generateNotebookIndexFile(nb)
            nss = NotebookSettingsStore();
            fname = fullpath(nss.commonDeployRoot, 'index.html');
            debug('Generating notebookIndex index.html at %s\n', fname);
            notebookNames = nss.listNotebooks(); 
            
            fid = fopen(fname, 'w'); 
            fprintf(fid, '---\n');
            fprintf(fid, 'extends: notebookIndex.j2\n');
            fprintf(fid, 'created: %s\n', datestr(now, 'yyyy.mm.dd HH:MM:SS'));
            fprintf(fid, 'notebooks:\n');

            for i = 1:length(notebookNames)
                fprintf(fid, '-\n');
                fprintf(fid, '  name: %s\n', notebookNames{i});
                fprintf(fid, '  url: %s/index.html\n', notebookNames{i});
            end

            fprintf(fid, '---\n');
        end

    end

end
