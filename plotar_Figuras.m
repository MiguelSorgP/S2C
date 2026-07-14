function plotar_Figuras(initialDir)
% PLOTAR_FIGURAS - Graphical user interface to visualize and compare OCC simulation metrics and noise histograms.

% 1) Setup paths relative to script location
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
defaultDir = fullfile(scriptDir, 'dadosBER');
if ~exist(defaultDir, 'dir')
    defaultDir = scriptDir;
end

% Ask user to choose the folder containing the .mat files
if nargin < 1 || isempty(initialDir)
    dadosBerDir = uigetdir(defaultDir, 'Select the folder containing the simulation .mat files');
    if isequal(dadosBerDir, 0)
        % User cancelled
        return;
    end
else
    dadosBerDir = initialDir;
end

% 2) Scan chosen folder for result files (*.mat)
matFiles = dir(fullfile(dadosBerDir, '*.mat'));
fileNames = {matFiles.name};

% If no files are found, notify the user and abort
if isempty(fileNames)
    figErr = uifigure('Name', 'Data Error', 'Position', [200 200 400 150]);
    uialert(figErr, ...
        ['No .mat files were found in the selected folder!' ...
        char(10) char(10) 'Make sure to choose a folder containing the simulation files.'], ...
        'Files Not Found', ...
        'Icon', 'error');
    return;
end

% Parse files to extract unique distances, positions, and frequencies
uniqueDists = {};
uniquePos = {};
uniqueFreqs = {};

for i = 1:length(fileNames)
    fName = fileNames{i};
    % Remove extension and suffix to get parameters
    cleaned = strrep(fName, '_resultado.mat', '');
    cleaned = strrep(cleaned, '_fundo.mat', '');
    cleaned = strrep(cleaned, '.mat', '');
    cleaned = strrep(cleaned, '_dark', '');
    cleaned = strrep(cleaned, '_DARK', '');
    parts = strsplit(cleaned, '-');
    if length(parts) >= 3
        uniqueDists{end+1} = parts{1};
        uniquePos{end+1} = parts{2};
        uniqueFreqs{end+1} = parts{3};
    end
end

uniqueDists = unique(uniqueDists);
% Sort distances numerically
distNums = cellfun(@str2double, uniqueDists);
[~, idx] = sort(distNums);
uniqueDists = uniqueDists(idx);

uniquePos = unique(uniquePos);
% Sort positions numerically
posNums = cellfun(@str2double, uniquePos);
[~, idx] = sort(posNums);
uniquePos = uniquePos(idx);

uniqueFreqs = unique(uniqueFreqs);
% Sort frequencies
[~, idx] = sort(uniqueFreqs);
uniqueFreqs = uniqueFreqs(idx);

% Arrays to store checkbox component handles
distCheckBoxes = cell(1, length(uniqueDists));
posCheckBoxes = cell(1, length(uniquePos));
freqCheckBoxes = cell(1, length(uniqueFreqs));

% 3) Create Main UI Figure
fig = uifigure('Name', 'OCC BER Curve Viewer', ...
    'Position', [150 150 820 650], ...
    'Color', [0.96 0.96 0.98], ...
    'Resize', 'on');

% Grid layout (2 rows, 2 columns)
% Row 1 (Folder selection): 45 pixels
% Row 2 (Main panels): Weight 1 (remaining space)
% Column 1 (Selection Panel): 340 pixels
% Column 2 (List and Options): Weight 1 (remaining space)
gl = uigridlayout(fig, [2, 2]);
gl.ColumnWidth = {340, '1x'};
gl.RowHeight = {45, '1x'};
gl.Padding = [15 15 15 15];
gl.ColumnSpacing = 15;
gl.RowSpacing = 10;

% --- TOP PANEL: FOLDER SELECTION DISPLAY ---
pnlFolder = uipanel(gl, ...
    'Title', 'Active Folder', ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [0.2 0.2 0.2], ...
    'BackgroundColor', [0.96 0.96 0.98]);
pnlFolder.Layout.Row = 1;
pnlFolder.Layout.Column = [1 2];

glFolder = uigridlayout(pnlFolder, [1, 2]);
glFolder.ColumnWidth = {'1x', 150};
glFolder.Padding = [10 2 10 2];
glFolder.ColumnSpacing = 10;
glFolder.RowSpacing = 0;

lblFolder = uilabel(glFolder, ...
    'Text', dadosBerDir, ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'FontColor', [0.3 0.3 0.3]);

btnChangeFolder = uibutton(glFolder, ...
    'Text', 'Select Folder...', ...
    'FontSize', 11, ...
    'ButtonPushedFcn', @(src, event) changeFolderCallback());

% --- LEFT PANEL: SELECTION CRITERIA (CHECKBOXES) ---
pnlLeft = uipanel(gl, ...
    'Title', 'Selection Criteria', ...
    'FontSize', 12, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [0.2 0.2 0.2], ...
    'BackgroundColor', [0.96 0.96 0.98]);
pnlLeft.Layout.Row = 2;
pnlLeft.Layout.Column = 1;

% Inner grid layout for Selection Criteria panel
glLeft = uigridlayout(pnlLeft, [5, 1]);
glLeft.RowHeight = {'1.8x', '1.6x', '1x', 60, 45};
glLeft.Padding = [10 10 10 10];
glLeft.RowSpacing = 10;

% 3.1) Distances Panel
pnlDist = uipanel(glLeft, ...
    'Title', 'Distances', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.96 0.96 0.98]);
numDistRows = max(1, ceil(length(uniqueDists)/2));
glDist = uigridlayout(pnlDist, [numDistRows, 2]);
glDist.Padding = [8 8 8 8];
glDist.RowSpacing = 5;
glDist.ColumnSpacing = 8;

for d = 1:length(uniqueDists)
    distVal = uniqueDists{d};
    distCheckBoxes{d} = uicheckbox(glDist, ...
        'Text', [distVal ' m'], ...
        'Value', true, ...
        'ValueChangedFcn', @(src, event) updateSelectedFiles());
end

% 3.2) Positions Panel
pnlPos = uipanel(glLeft, ...
    'Title', 'Positions', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.96 0.96 0.98]);

% Map position numbers to friendly text in English
posNames = containers.Map({'1', '2', '3', '4', '5'}, ...
    {'Left (1)', 'Intermed. Left (2)', 'Center (3)', 'Intermed. Right (4)', 'Right (5)'});

numPosRows = max(1, ceil(length(uniquePos)/2));
glPos = uigridlayout(pnlPos, [numPosRows, 2]);
glPos.Padding = [8 8 8 8];
glPos.RowSpacing = 5;
glPos.ColumnSpacing = 8;

for p = 1:length(uniquePos)
    posVal = uniquePos{p};
    if isKey(posNames, posVal)
        posText = posNames(posVal);
    else
        posText = ['Pos ' posVal];
    end
    posCheckBoxes{p} = uicheckbox(glPos, ...
        'Text', posText, ...
        'Value', true, ...
        'ValueChangedFcn', @(src, event) updateSelectedFiles());
end

% 3.3) Frequencies Panel
pnlFreq = uipanel(glLeft, ...
    'Title', 'Frequencies (F)', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.96 0.96 0.98]);
numFreqRows = max(1, ceil(length(uniqueFreqs)/2));
glFreq = uigridlayout(pnlFreq, [numFreqRows, 2]);
glFreq.Padding = [8 8 8 8];
glFreq.RowSpacing = 5;
glFreq.ColumnSpacing = 8;

for f = 1:length(uniqueFreqs)
    freqVal = uniqueFreqs{f};
    freqCheckBoxes{f} = uicheckbox(glFreq, ...
        'Text', upper(freqVal), ...
        'Value', true, ...
        'ValueChangedFcn', @(src, event) updateSelectedFiles());
end

% 3.4) Lighting Condition Panel
pnlLightCond = uipanel(glLeft, ...
    'Title', 'Lighting Condition', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.96 0.96 0.98]);
glLightCond = uigridlayout(pnlLightCond, [1, 2]);
glLightCond.Padding = [8 8 8 8];
glLightCond.RowSpacing = 5;
glLightCond.ColumnSpacing = 8;

chkLight = uicheckbox(glLightCond, ...
    'Text', 'Light (no _dark)', ...
    'Value', true, ...
    'ValueChangedFcn', @(src, event) updateSelectedFiles());

chkDark = uicheckbox(glLightCond, ...
    'Text', 'Dark (with _dark)', ...
    'Value', true, ...
    'ValueChangedFcn', @(src, event) updateSelectedFiles());

% 3.5) Global Selection Buttons
glGlobalButtons = uigridlayout(glLeft, [1, 2]);
glGlobalButtons.ColumnWidth = {'1x', '1x'};
glGlobalButtons.Padding = [0 0 0 0];
glGlobalButtons.ColumnSpacing = 10;

btnSelectAll = uibutton(glGlobalButtons, ...
    'Text', 'Select All', ...
    'FontSize', 11, ...
    'ButtonPushedFcn', @(src, event) setAllCheckboxes(true));

btnClearAll = uibutton(glGlobalButtons, ...
    'Text', 'Clear All', ...
    'FontSize', 11, ...
    'ButtonPushedFcn', @(src, event) setAllCheckboxes(false));


% --- RIGHT PANEL: SELECTED CURVES PREVIEW & OPTIONS ---
pnlRight = uipanel(gl, ...
    'Title', 'Curves to Plot (Preview)', ...
    'FontSize', 12, ...
    'FontWeight', 'bold', ...
    'ForegroundColor', [0.2 0.2 0.2], ...
    'BackgroundColor', [0.96 0.96 0.98]);
pnlRight.Layout.Row = 2;
pnlRight.Layout.Column = 2;

glRight = uigridlayout(pnlRight, [5, 1]);
glRight.RowHeight = {25, '1x', 40, 40, 50};
glRight.Padding = [10 10 10 10];
glRight.RowSpacing = 8;

uilabel(glRight, ...
    'Text', 'The following curves match your criteria and will be plotted:', ...
    'FontSize', 11, ...
    'FontWeight', 'bold');

% Read-only preview listbox of matched files
lstFiles = uilistbox(glRight, ...
    'Items', {}, ...
    'Multiselect', 'off', ...
    'FontSize', 11);

% Additional options (legend formatting, grid)
glOptions = uigridlayout(glRight, [1, 2]);
glOptions.ColumnWidth = {'1x', '1x'};
glOptions.Padding = [0 0 0 0];

chkLegendClean = uicheckbox(glOptions, ...
    'Text', 'Format legend names (Readable)', ...
    'Value', true, ...
    'FontSize', 11);

chkGridOn = uicheckbox(glOptions, ...
    'Text', 'Enable Minor Grid', ...
    'Value', true, ...
    'FontSize', 11);

% Metric selection dropdown
glMetric = uigridlayout(glRight, [1, 2]);
glMetric.ColumnWidth = {90, '1x'};
glMetric.Padding = [0 0 0 0];

uilabel(glMetric, ...
    'Text', 'Select Metric:', ...
    'FontSize', 11, ...
    'FontWeight', 'bold');

ddMetric = uidropdown(glMetric, ...
    'Items', {'BER', 'SER', 'Symbol MSE', 'Symbol NMSE', 'IoU', 'Histogram'}, ...
    'ItemsData', {'BERvals', 'SERvals', 'symbolMSEvals', 'symbolNMSEvals', 'IoUvals', 'Histogram'}, ...
    'Value', 'BERvals', ...
    'FontSize', 11);

% Main Action Button: Generate Plot
btnPlot = uibutton(glRight, ...
    'Text', 'Generate Plot', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.00 0.45 0.74], ... % Premium blue
    'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(src, event) plotCurves());

% Initialize selection
updateSelectedFiles();


% --- CALLBACK AND HELPER FUNCTIONS ---

% Callback to change active folder and restart GUI
    function changeFolderCallback()
        newDir = uigetdir(dadosBerDir, 'Select the folder containing the simulation .mat files');
        if ischar(newDir) || isstring(newDir)
            close(fig);
            plotar_Figuras(newDir);
        end
    end

% Toggles all checkboxes to true or false
    function setAllCheckboxes(val)
        for d_idx = 1:length(distCheckBoxes)
            distCheckBoxes{d_idx}.Value = val;
        end
        for p_idx = 1:length(posCheckBoxes)
            posCheckBoxes{p_idx}.Value = val;
        end
        for f_idx = 1:length(freqCheckBoxes)
            freqCheckBoxes{f_idx}.Value = val;
        end
        chkLight.Value = val;
        chkDark.Value = val;
        updateSelectedFiles();
    end

% Dynamically updates the list of matched files based on checked options
    function updateSelectedFiles()
        % Gather checked distances
        selectedDists = {};
        for d_idx = 1:length(distCheckBoxes)
            if distCheckBoxes{d_idx}.Value
                selectedDists{end+1} = uniqueDists{d_idx}; %#ok<AGROW>
            end
        end
        
        % Gather checked positions
        selectedPos = {};
        for p_idx = 1:length(posCheckBoxes)
            if posCheckBoxes{p_idx}.Value
                selectedPos{end+1} = uniquePos{p_idx}; %#ok<AGROW>
            end
        end
        
        % Gather checked frequencies
        selectedFreqs = {};
        for f_idx = 1:length(freqCheckBoxes)
            if freqCheckBoxes{f_idx}.Value
                selectedFreqs{end+1} = uniqueFreqs{f_idx}; %#ok<AGROW>
            end
        end
        
        % Filter files
        matchedFiles = {};
        for idx_file = 1:length(fileNames)
            fName = fileNames{idx_file};
            
            % Check lighting condition of the file
            isDarkFile = contains(fName, '_dark', 'IgnoreCase', true);
            lightingMatch = (isDarkFile && chkDark.Value) || (~isDarkFile && chkLight.Value);
            if ~lightingMatch
                continue;
            end
            
            cleaned = strrep(fName, '_resultado.mat', '');
            cleaned = strrep(cleaned, '_fundo.mat', '');
            cleaned = strrep(cleaned, '.mat', '');
            cleaned = strrep(cleaned, '_dark', '');
            cleaned = strrep(cleaned, '_DARK', '');
            parts = strsplit(cleaned, '-');
            if length(parts) >= 3
                distVal = parts{1};
                posVal = parts{2};
                freqVal = parts{3};
                
                if any(strcmp(distVal, selectedDists)) && ...
                        any(strcmp(posVal, selectedPos)) && ...
                        any(strcmp(freqVal, selectedFreqs))
                    matchedFiles{end+1} = fName; %#ok<AGROW>
                end
            end
        end
        
        lstFiles.Items = matchedFiles;
    end

% Loads data and plots all matched curves or noise histograms
    function plotCurves()
        selected = lstFiles.Items;
        if isempty(selected)
            uialert(fig, ...
                'Please select criteria that match at least one data file.', ...
                'No Selection', ...
                'Icon', 'warning');
            return;
        end
        
        selectedMetric = ddMetric.Value;
        metricIdx = strcmp(ddMetric.ItemsData, selectedMetric);
        metricName = ddMetric.Items{metricIdx};
        
        % Open a new default MATLAB figure (independent window)
        figPlot = figure('Name', sprintf('%s Comparison', metricName), ...
            'NumberTitle', 'off', ...
            'Color', [1 1 1]);
        hold on;
        grid on;
        
        % Premium color palette
        colors = [
            0.0000 0.4470 0.7410;  % Blue
            0.8500 0.3250 0.0980;  % Orange
            0.4660 0.6740 0.1880;  % Green
            0.4940 0.1840 0.5560;  % Purple
            0.9290 0.6940 0.1250;  % Golden Yellow
            0.3010 0.7450 0.9330;  % Light Blue
            0.6350 0.0780 0.1840;  % Dark Red
            0.2500 0.2500 0.2500;  % Dark Gray
            0.0000 0.5000 0.0000;  % Forest Green
            0.7500 0.0000 0.7500;  % Magenta
            0.0000 0.7500 0.7500;  % Cyan
            0.6000 0.2000 0.0000   % Brown
            ];
        
        numCurves = length(selected);
        plotHandles = [];
        legendLabels = {};
        
        if strcmp(selectedMetric, 'Histogram')
            % --- PLOTTING BACKGROUND NOISE HISTOGRAMS ---
            for k = 1:numCurves
                fName = selected{k};
                filePath = fullfile(dadosBerDir, fName);
                
                try
                    matData = load(filePath);
                catch ME
                    close(figPlot);
                    uialert(fig, sprintf('Could not load the file: %s. Error: %s', fName, ME.message), ...
                        'Read Error', 'Icon', 'error');
                    return;
                end
                
                % Validate presence of backgroundNoise
                if ~isfield(matData, 'backgroundNoise')
                    close(figPlot);
                    uialert(fig, sprintf('The file %s does not contain the "backgroundNoise" variable required for the histogram. Make sure to enable normalization (normFlag) in the script.', fName), ...
                        'Missing Variable', 'Icon', 'error');
                    return;
                end
                
                noiseData = double(matData.backgroundNoise(:));
                muVal = mean(noiseData);
                sigmaVal = std(noiseData);
                
                colorIdx = mod(k-1, size(colors, 1)) + 1;
                curveColor = colors(colorIdx, :);
                
                % Legend formatting
                cleaned = strrep(fName, '_resultado.mat', '');
                cleaned = strrep(cleaned, '_fundo.mat', '');
                cleaned = strrep(cleaned, '.mat', '');
                cleaned = strrep(cleaned, '_dark', '');
                cleaned = strrep(cleaned, '_DARK', '');
                parts = strsplit(cleaned, '-');
                
                if chkLegendClean.Value && length(parts) >= 3
                    distStr = parts{1};
                    posCode = parts{2};
                    rateStr = upper(parts{3});
                    
                    switch posCode
                        case '1'
                            posName = 'Left';
                        case '2'
                            posName = 'Intermed. Left';
                        case '3'
                            posName = 'Center';
                        case '4'
                            posName = 'Intermed. Right';
                        case '5'
                            posName = 'Right';
                        otherwise
                            posName = ['Position ' posCode];
                    end
                    isDarkFile = contains(fName, '_dark', 'IgnoreCase', true);
                    if isDarkFile
                        lightStr = 'Dark';
                    else
                        lightStr = 'Light';
                    end
                    legendLabel = sprintf('%s m - %s - %s (%s) (\\mu=%.2f, \\sigma=%.2f)', distStr, posName, rateStr, lightStr, muVal, sigmaVal);
                else
                    legendLabel = sprintf('%s (\\mu=%.2f, \\sigma=%.2f)', strrep(fName, '_', '\_'), muVal, sigmaVal);
                end
                
                % Draw histogram
                hHist = histogram(noiseData, 'Normalization', 'pdf', ...
                    'FaceColor', curveColor, ...
                    'EdgeColor', curveColor, ...
                    'FaceAlpha', 0.20, ...
                    'EdgeAlpha', 0.50);
                
                plotHandles(end+1) = hHist; %#ok<AGROW>
                legendLabels{end+1} = legendLabel; %#ok<AGROW>
                
                % Draw manual Gaussian fit
                x_fit = linspace(min(noiseData), max(noiseData), 300);
                y_fit = (1 / (sigmaVal * sqrt(2 * pi))) * exp(-0.5 * ((x_fit - muVal) / sigmaVal).^2);
                plot(x_fit, y_fit, ...
                    'Color', curveColor, ...
                    'LineWidth', 2.0, ...
                    'HandleVisibility', 'off');
            end
            
            xlabel('Noise Amplitude (Gray Level)', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Probability Density Function (PDF)', 'FontSize', 12, 'FontWeight', 'bold');
            title('Comparison of Background Noise PDF & Gaussian Fit', 'FontSize', 14, 'FontWeight', 'bold');
            
        else
            % --- PLOTTING KPI CURVES VS 1/Pn (dB) ---
            markers = {'o', 's', 'd', '^', 'v', 'p', 'h', 'x', '+', '*', '<', '>'};
            lineStyles = {'-', '--', '-.', ':'};
            
            for k = 1:numCurves
                fName = selected{k};
                filePath = fullfile(dadosBerDir, fName);
                
                try
                    matData = load(filePath);
                catch ME
                    close(figPlot);
                    uialert(fig, sprintf('Could not load the file: %s. Error: %s', fName, ME.message), ...
                        'Read Error', 'Icon', 'error');
                    return;
                end
                
                % Validate presence of OnePnDB and the selected KPI
                if ~isfield(matData, 'OnePnDB') || ~isfield(matData, selectedMetric)
                    close(figPlot);
                    uialert(fig, sprintf('The file %s does not contain the required variables ("OnePnDB" and "%s"). Verify if the simulation was run with noise.', fName, selectedMetric), ...
                        'Missing Variables', 'Icon', 'error');
                    return;
                end
                
                xData = matData.OnePnDB;
                yData = matData.(selectedMetric);
                if strcmp(selectedMetric, 'IoUvals')
                    yData = mean(yData, 2);
                end
                
                % Handle early termination in Monte Carlo (if BER reached 0)
                if isfield(matData, 'BERvals')
                    firstZeroIdx = find(matData.BERvals == 0, 1);
                    if ~isempty(firstZeroIdx)
                        validLen = firstZeroIdx;
                    else
                        validLen = length(xData);
                    end
                    xData = xData(1:min(validLen, length(xData)));
                    yData = yData(1:min(validLen, length(yData)));
                end
                
                if length(xData) ~= length(yData)
                    close(figPlot);
                    uialert(fig, sprintf('Incompatible dimensions of OnePnDB and %s in file %s.', selectedMetric, fName), ...
                        'Data Error', 'Icon', 'error');
                    return;
                end
                
                colorIdx = mod(k-1, size(colors, 1)) + 1;
                markerIdx = mod(k-1, length(markers)) + 1;
                lineStyleIdx = mod(k-1, length(lineStyles)) + 1;
                
                curveColor = colors(colorIdx, :);
                curveMarker = markers{markerIdx};
                curveStyle = lineStyles{lineStyleIdx};
                
                % Plot in semilogarithmic Y scale or linear scale
                if strcmp(selectedMetric, 'IoUvals')
                    h = plot(xData, yData, ...
                        'Color', curveColor, ...
                        'Marker', curveMarker, ...
                        'LineStyle', curveStyle, ...
                        'LineWidth', 1.8, ...
                        'MarkerSize', 7, ...
                        'MarkerFaceColor', curveColor);
                else
                    h = semilogy(xData, yData, ...
                        'Color', curveColor, ...
                        'Marker', curveMarker, ...
                        'LineStyle', curveStyle, ...
                        'LineWidth', 1.8, ...
                        'MarkerSize', 7, ...
                        'MarkerFaceColor', curveColor);
                end
                
                plotHandles(end+1) = h; %#ok<AGROW>
                
                % Legend formatting
                cleaned = strrep(fName, '_resultado.mat', '');
                cleaned = strrep(cleaned, '_fundo.mat', '');
                cleaned = strrep(cleaned, '.mat', '');
                cleaned = strrep(cleaned, '_dark', '');
                cleaned = strrep(cleaned, '_DARK', '');
                parts = strsplit(cleaned, '-');
                
                if chkLegendClean.Value && length(parts) >= 3
                    distStr = parts{1};
                    posCode = parts{2};
                    rateStr = upper(parts{3});
                    
                    switch posCode
                        case '1'
                            posName = 'Left';
                        case '2'
                            posName = 'Intermed. Left';
                        case '3'
                            posName = 'Center';
                        case '4'
                            posName = 'Intermed. Right';
                        case '5'
                            posName = 'Right';
                        otherwise
                            posName = ['Position ' posCode];
                    end
                    isDarkFile = contains(fName, '_dark', 'IgnoreCase', true);
                    if isDarkFile
                        lightStr = 'Dark';
                    else
                        lightStr = 'Light';
                    end
                    legendLabels{end+1} = sprintf('%s m - %s - %s (%s)', distStr, posName, rateStr, lightStr); %#ok<AGROW>
                else
                    legendLabels{end+1} = strrep(fName, '_', '\_'); %#ok<AGROW>
                end
            end
            
            xlabel('1/P_n (dB)', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel(metricName, 'FontSize', 12, 'FontWeight', 'bold');
            title(sprintf('%s Performance vs. 1/P_n (dB)', metricName), 'FontSize', 14, 'FontWeight', 'bold');
            
            ax = gca;
            if strcmp(selectedMetric, 'IoUvals')
                ax.YScale = 'linear';
            else
                ax.YScale = 'log';
            end
        end
        
        ax = gca;
        % Enable minor grid if requested
        if chkGridOn.Value
            ax.YMinorGrid = 'on';
            ax.XMinorGrid = 'on';
            ax.MinorGridColor = [0.3 0.3 0.3];
            ax.MinorGridAlpha = 0.08;
        end
        
        ax.GridColor = [0.2 0.2 0.2];
        ax.GridAlpha = 0.15;
        ax.FontSize = 10;
        
        if ~isempty(legendLabels) && ~isempty(plotHandles)
            legend(plotHandles, legendLabels, 'Location', 'best', 'FontSize', 10);
        end
        
        hold off;
    end
end
