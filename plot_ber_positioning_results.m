%% plot_ber_positioning_results.m
% MATLAB script to process Bit Error Rate (BER) simulation results and generate
% 8 high-quality, publication-ready figures relating BER with spatial coordinates
% (Depth Y, Lateral Position X, Absolute Offset |X|, 2D spatial maps, CDF, boxplots, etc.).
%
% Isolates a fixed 1/Pn (dB) noise level (user-defined or automatically selected)
% and excludes recordings that did not achieve BER = 0 without noise (e.g. 3y_5x_0z_f5_dark).

clear; clc; close all;

%% 1. Configuration & Setup
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

% Target directory containing .mat simulation result files
targetDir = fullfile(scriptDir, 'dadosBER', '29_07_2026_12_36');

if ~exist(targetDir, 'dir')
    % Fallback search in subdirectories if default does not exist
    fallbackDir = fullfile(scriptDir, 'dadosBER');
    if exist(fallbackDir, 'dir')
        targetDir = fallbackDir;
    else
        targetDir = scriptDir;
    end
end

% -------------------------------------------------------------------------
% USER CONFIGURATION: Fixed 1/Pn (dB) noise level & Logarithmic Scaling
%   - targetOnePnDB : 'auto' or a numeric scalar in dB (e.g., -28, 12, 15)
%   - useLogScale   : true (default) for log10 scale, false for linear scale
%   - minBERFloor   : 'auto' (dynamic non-zero floor based on data) or numeric (e.g., 1e-5)
% -------------------------------------------------------------------------
targetOnePnDB = -28;   % Options: 'auto' or numeric scalar (e.g., -28)
useLogScale   = true;  % Set true to plot BER in logarithmic scale (log10)
minBERFloor   = 'auto';% Options: 'auto' or numeric scalar (e.g., 1e-5)

%% 2. Real Spatial Distance Mappings (from dadosROI.m)
% Map 'y' key (e.g., 1y -> 1) to real depth Y in meters
y_map = [
    1, 0.75;
    2, 1.00;
    3, 1.25;
    4, 1.50;
    5, 1.75;
    6, 2.00;
    7, 2.25;
    8, 2.50
    ];

% Map 'x' key (e.g., 1x -> 1) to real lateral position X in meters
x_map = [
    1,  0.350;
    2,  0.175;
    3,  0.000;
    4, -0.175;
    5, -0.350
    ];

% Map 'z' key (e.g., 0z -> 0) to real height Z in meters
z_map = [
    0, -0.114;
    1,  0.126
    ];

%% 3. Scan & Filter Files
matFiles = dir(fullfile(targetDir, '*.mat'));
if isempty(matFiles)
    error('No .mat simulation files found in directory: %s', targetDir);
end

% Check if checkpoint CSV exists to pre-identify invalid recordings
checkpointFile = fullfile(targetDir, 'checkpoint_dadosBER.csv');
invalidVideosCSV = {};
if exist(checkpointFile, 'file')
    opts = detectImportOptions(checkpointFile);
    opts.VariableNamingRule = 'preserve';
    chkData = readtable(checkpointFile, opts);
    if ismember('video_name', chkData.Properties.VariableNames) && ismember('BER', chkData.Properties.VariableNames)
        badIdx = chkData.BER > 1e-4; % Baseline BER > 0
        invalidVideosCSV = chkData.video_name(badIdx);
    end
end

fprintf('=======================================================\n');
fprintf('       PROCESSING BER SPATIAL RESULTS DATASET          \n');
fprintf('=======================================================\n');
fprintf('Target Folder: %s\n', targetDir);

% Load valid MAT files
validFiles = {};
fileDataList = {};

for i = 1:length(matFiles)
    fName = matFiles(i).name;
    filePath = fullfile(targetDir, fName);

    info = parseVideoName(fName);
    if ~info.is_valid
        continue;
    end

    % Check if excluded by checkpoint CSV
    [~, baseVName, ~] = fileparts(fName);
    baseVNameClean = regexprep(baseVName, '_resultado$', '');
    if any(contains(invalidVideosCSV, baseVNameClean))
        fprintf('  [EXCLUDED] %s -> Failed zero-noise BER check in CSV.\n', fName);
        continue;
    end

    try
        matData = load(filePath);
    catch
        warning('Could not load file: %s', fName);
        continue;
    end

    % Validate required fields
    if ~isfield(matData, 'OnePnDB') || ~isfield(matData, 'BERvals')
        continue;
    end

    % Exclude curves that did not reach BER = 0 without added noise (baseline check)
    if matData.BERvals(end) > 1e-4 || matData.BERvals(1) > 0.45
        fprintf('  [EXCLUDED] %s -> Baseline BER (%.4f) did not reach 0.\n', fName, matData.BERvals(end));
        continue;
    end

    % Map keys to real physical coordinates (meters)
    y_idx = find(abs(y_map(:, 1) - info.y_key) < 1e-4, 1);
    x_idx = find(abs(x_map(:, 1) - info.x_key) < 1e-4, 1);
    z_idx = find(abs(z_map(:, 1) - info.z_key) < 1e-4, 1);

    if isempty(y_idx) || isempty(x_idx) || isempty(z_idx)
        warning('Spatial mapping failed for keys: y=%.1f, x=%.1f, z=%.1f in %s', info.y_key, info.x_key, info.z_key, fName);
        continue;
    end

    itemData.fName      = fName;
    itemData.y_real_m   = y_map(y_idx, 2);
    itemData.x_real_m   = x_map(x_idx, 2);
    itemData.z_real_m   = z_map(z_idx, 2);
    itemData.abs_x_m    = abs(itemData.x_real_m);
    itemData.OnePnDB    = matData.OnePnDB(:);
    itemData.BERvals    = matData.BERvals(:);

    validFiles{end+1}   = fName; %#ok<AGROW>
    fileDataList{end+1} = itemData; %#ok<AGROW>
end

numValid = length(fileDataList);
if numValid == 0
    error('No valid dataset recordings passed filtering criteria.');
end
fprintf('Total valid recordings retained: %d (Excluded invalid/corrupted curves).\n', numValid);

%% 4. Determine Operating Point 1/Pn (dB)
allOnePn = [];
for k = 1:numValid
    allOnePn = unique([allOnePn; fileDataList{k}.OnePnDB]);
end
allOnePn = sort(allOnePn);

if ischar(targetOnePnDB) || (isstring(targetOnePnDB) && strcmpi(targetOnePnDB, 'auto'))
    bestOnePn = allOnePn(1);
    maxScore = -1;

    for idxP = 1:length(allOnePn)
        pnVal = allOnePn(idxP);
        bersAtPn = zeros(numValid, 1);
        for k = 1:numValid
            bersAtPn(k) = interp1(fileDataList{k}.OnePnDB, fileDataList{k}.BERvals, pnVal, 'linear', 'extrap');
        end
        bersAtPn = max(0, bersAtPn);
        meanBER = mean(bersAtPn);
        stdBER  = std(bersAtPn);

        if meanBER > 1e-4 && meanBER < 0.20
            score = stdBER * (meanBER^0.3);
            if score > maxScore
                maxScore = score;
                bestOnePn = pnVal;
            end
        end
    end
    selectedOnePnDB = bestOnePn;
    fprintf('Auto-selected 1/Pn operating point: %.2f dB.\n', selectedOnePnDB);
else
    selectedOnePnDB = double(targetOnePnDB);
    fprintf('User-selected 1/Pn operating point: %.2f dB.\n', selectedOnePnDB);
end

%% 5. Extract BER Values at Selected 1/Pn (dB)
X_real_cm = zeros(numValid, 1);
Y_real_cm = zeros(numValid, 1);
abs_X_cm  = zeros(numValid, 1);
BER_eval  = zeros(numValid, 1);

for k = 1:numValid
    item = fileDataList{k};
    X_real_cm(k) = item.x_real_m * 100; % Convert meters to cm for plotting
    Y_real_cm(k) = item.y_real_m * 100;
    abs_X_cm(k)  = item.abs_x_m * 100;

    % Interpolate BER at target 1/Pn dB
    valBER = interp1(item.OnePnDB, item.BERvals, selectedOnePnDB, 'linear', 'extrap');
    BER_eval(k) = max(0, valBER); % Ensure non-negative
end

% Determine non-zero lower bound floor for log scale (for zero BER values)
nonZeroBERs = BER_eval(BER_eval > 0);
if ischar(minBERFloor) || (isstring(minBERFloor) && strcmpi(minBERFloor, 'auto'))
    if ~isempty(nonZeroBERs)
        % Set floor 1 decade below minimum non-zero BER in dataset
        effectiveFloor = 10^(floor(log10(min(nonZeroBERs))) - 1);
    else
        effectiveFloor = 1e-5;
    end
else
    effectiveFloor = double(minBERFloor);
end

% Log-scale bounded BER for plots
if useLogScale
    if any(BER_eval == 0)
        BER_plot = max(effectiveFloor, BER_eval);
    else
        BER_plot = BER_eval;
    end
    fprintf('Log scale active: BER floor set to %.1e (auto-determined: %d).\n', ...
        effectiveFloor, ischar(minBERFloor) || (isstring(minBERFloor) && strcmpi(minBERFloor, 'auto')));
else
    effectiveFloor = 0;
    BER_plot = BER_eval;
end

% Helper function for dynamic lower axis limit in log plots
getLogYMin = @(vals) 10^(floor(log10(max(1e-12, min(vals(vals > 0))))));

unique_Y_cm     = sort(unique(Y_real_cm));
unique_X_cm     = sort(unique(X_real_cm));
unique_abs_X_cm = sort(unique(abs_X_cm));
numDepths       = length(unique_Y_cm);
numXPos         = length(unique_X_cm);
numAbsXPos      = length(unique_abs_X_cm);

%% 6. Color Palette & Aesthetic Setup
colorGT  = [0.10, 0.35, 0.80]; % Dark Blue
colorEst = [0.85, 0.15, 0.15]; % Red
colorX   = [0.23, 0.51, 0.96]; % Blue
colorY   = [0.02, 0.71, 0.83]; % Cyan
colorBER = [0.85, 0.20, 0.20]; % Dark Red

%% =========================================================================
%% FIGURE 1: 2D Spatial BER Map (Scatter & Interpolated Heatmap)
%% =========================================================================
hFig1 = figure('Name', sprintf('Fig1_Spatial_BER_2D_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [100, 50, 850, 820], 'Color', [1 1 1]);

% --- Subplot (a): Discrete Spatial Bubble BER Map ---
subplot(2, 1, 1);
minBubble = 35; maxBubble = 150;
if useLogScale
    logBER_eval = log10(BER_plot);
    if max(logBER_eval) > min(logBER_eval)
        bubbleSizes = minBubble + ((logBER_eval - min(logBER_eval)) / (max(logBER_eval) - min(logBER_eval))) * (maxBubble - minBubble);
    else
        bubbleSizes = repmat(60, numValid, 1);
    end
    scatter(X_real_cm, Y_real_cm, bubbleSizes, BER_plot, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);
    try set(gca, 'ColorScale', 'log'); catch; end
else
    if max(BER_eval) > min(BER_eval)
        bubbleSizes = minBubble + ((BER_eval - min(BER_eval)) / (max(BER_eval) - min(BER_eval))) * (maxBubble - minBubble);
    else
        bubbleSizes = repmat(60, numValid, 1);
    end
    scatter(X_real_cm, Y_real_cm, bubbleSizes, BER_eval, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);
end

colormap(gca, turbo);
c1 = colorbar('Location', 'eastoutside');
c1.Label.String = sprintf('BER at 1/P_n = %.1f dB', selectedOnePnDB);
c1.Label.FontSize = 10; c1.Label.FontWeight = 'bold';

xlabel('Real Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
title(sprintf('(a) Discrete Spatial BER Map (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
xlim([min(X_real_cm) - 6, max(X_real_cm) + 6]);
ylim([min(Y_real_cm) - 10, max(Y_real_cm) + 15]);
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Interpolated 2D Spatial Heatmap ---
subplot(2, 1, 2);
[gridX, gridY] = meshgrid(linspace(min(X_real_cm), max(X_real_cm), 100), ...
    linspace(min(Y_real_cm), max(Y_real_cm), 100));

if useLogScale
    gridBER = griddata(X_real_cm, Y_real_cm, log10(BER_plot), gridX, gridY, 'v4');
    contourf(gridX, gridY, 10.^gridBER, 20, 'LineColor', 'none');
    try set(gca, 'ColorScale', 'log'); catch; end
else
    gridBER = griddata(X_real_cm, Y_real_cm, BER_eval, gridX, gridY, 'v4');
    gridBER = max(0, gridBER);
    contourf(gridX, gridY, gridBER, 20, 'LineColor', 'none');
end

hold on;
plot(X_real_cm, Y_real_cm, 'k+', 'LineWidth', 1.2, 'MarkerSize', 6);
colormap(gca, turbo);
c2 = colorbar('Location', 'eastoutside');
c2.Label.String = sprintf('BER at 1/P_n = %.1f dB', selectedOnePnDB);
c2.Label.FontSize = 10; c2.Label.FontWeight = 'bold';

xlabel('Real Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
title(sprintf('(b) Interpolated Spatial BER Heatmap (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
xlim([min(X_real_cm) - 6, max(X_real_cm) + 6]);
ylim([min(Y_real_cm) - 10, max(Y_real_cm) + 15]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% FIGURE 2: BER Analysis vs. Depth Y (Boxplot & Grouped Bar Chart)
%% =========================================================================
hFig2 = figure('Name', sprintf('Fig2_BER_vs_Depth_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [150, 100, 850, 750], 'Color', [1 1 1]);

% --- Subplot (a): Boxplot of BER per Depth ---
subplot(2, 1, 1);
boxplot(BER_plot, Y_real_cm/100, 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Depth Distance Y (m)', 'FontSize', 10.5);
ylabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title(sprintf('(a) BER Dispersion across Depths Y (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin(BER_plot), max(BER_plot) * 2.5]);
else
    ylim([0, max(BER_eval) * 1.15 + 1e-5]);
end
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Bar Chart of Mean & Peak BER per Depth ---
subplot(2, 1, 2);
mean_BER_depth = zeros(numDepths, 1);
max_BER_depth  = zeros(numDepths, 1);

for i = 1:numDepths
    idx = (abs(Y_real_cm - unique_Y_cm(i)) < 1e-4);
    if useLogScale
        mean_BER_depth(i) = max(effectiveFloor, mean(BER_eval(idx)));
        max_BER_depth(i)  = max(effectiveFloor, max(BER_eval(idx)));
    else
        mean_BER_depth(i) = mean(BER_eval(idx));
        max_BER_depth(i)  = max(BER_eval(idx));
    end
end

b2 = bar(unique_Y_cm/100, [mean_BER_depth, max_BER_depth], 'grouped');
b2(1).FaceColor = colorY;
b2(2).FaceColor = colorBER;

xlabel('Real Depth Distance Y (m)', 'FontSize', 10.5);
ylabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title('(b) Mean and Peak BER vs. Depth Distance Y', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Mean BER', 'Peak BER'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_Y_cm/100, 'FontSize', 9.5);
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin([mean_BER_depth; max_BER_depth]), max([mean_BER_depth; max_BER_depth]) * 2.5]);
else
    ylim([0, max([mean_BER_depth; max_BER_depth]) * 1.15 + 1e-5]);
end

%% =========================================================================
%% FIGURE 3: BER Analysis vs. Lateral Position X (Boxplot & Grouped Bar Chart)
%% =========================================================================
hFig3 = figure('Name', sprintf('Fig3_BER_vs_Lateral_X_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [175, 125, 850, 750], 'Color', [1 1 1]);

% --- Subplot (a): Boxplot of BER per Lateral Position X ---
subplot(2, 1, 1);
boxplot(BER_plot, X_real_cm/100, 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Lateral Position X (m)', 'FontSize', 10.5);
ylabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title(sprintf('(a) BER Dispersion across Lateral Positions X (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin(BER_plot), max(BER_plot) * 2.5]);
else
    ylim([0, max(BER_eval) * 1.15 + 1e-5]);
end
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Bar Chart of Mean & Peak BER per Lateral Position X ---
subplot(2, 1, 2);
mean_BER_Xpos = zeros(numXPos, 1);
max_BER_Xpos  = zeros(numXPos, 1);

for i = 1:numXPos
    idx = (abs(X_real_cm - unique_X_cm(i)) < 1e-4);
    if useLogScale
        mean_BER_Xpos(i) = max(effectiveFloor, mean(BER_eval(idx)));
        max_BER_Xpos(i)  = max(effectiveFloor, max(BER_eval(idx)));
    else
        mean_BER_Xpos(i) = mean(BER_eval(idx));
        max_BER_Xpos(i)  = max(BER_eval(idx));
    end
end

b3 = bar(unique_X_cm/100, [mean_BER_Xpos, max_BER_Xpos], 'grouped');
b3(1).FaceColor = colorX;
b3(2).FaceColor = colorBER;

xlabel('Real Lateral Position X (m)', 'FontSize', 10.5);
ylabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title('(b) Mean and Peak BER vs. Lateral Position X', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Mean BER', 'Peak BER'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_X_cm/100, 'FontSize', 9.5);
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin([mean_BER_Xpos; max_BER_Xpos]), max([mean_BER_Xpos; max_BER_Xpos]) * 2.5]);
else
    ylim([0, max([mean_BER_Xpos; max_BER_Xpos]) * 1.15 + 1e-5]);
end

%% =========================================================================
%% FIGURE 4: Symmetrized BER Analysis vs. Absolute Offset |X|
%% =========================================================================
hFig4 = figure('Name', sprintf('Fig4_BER_vs_Abs_Lateral_X_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [200, 150, 850, 750], 'Color', [1 1 1]);

% --- Subplot (a): Boxplot of BER per Absolute Lateral Offset |X| ---
subplot(2, 1, 1);
boxplot(BER_plot, abs_X_cm/100, 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Absolute Lateral Offset |X| (m)', 'FontSize', 10.5);
ylabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title(sprintf('(a) BER Dispersion across Symmetrized Offsets |X| (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin(BER_plot), max(BER_plot) * 2.5]);
else
    ylim([0, max(BER_eval) * 1.15 + 1e-5]);
end
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Bar Chart of Mean & Peak BER vs. |X| ---
subplot(2, 1, 2);
mean_BER_absX = zeros(numAbsXPos, 1);
max_BER_absX  = zeros(numAbsXPos, 1);

for i = 1:numAbsXPos
    idx = (abs(abs_X_cm - unique_abs_X_cm(i)) < 1e-4);
    if useLogScale
        mean_BER_absX(i) = max(effectiveFloor, mean(BER_eval(idx)));
        max_BER_absX(i)  = max(effectiveFloor, max(BER_eval(idx)));
    else
        mean_BER_absX(i) = mean(BER_eval(idx));
        max_BER_absX(i)  = max(BER_eval(idx));
    end
end

b4 = bar(unique_abs_X_cm/100, [mean_BER_absX, max_BER_absX], 'grouped');
b4(1).FaceColor = colorX;
b4(2).FaceColor = colorBER;

xlabel('Real Absolute Lateral Offset |X| (m)', 'FontSize', 10.5);
ylabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title('(b) Symmetrized Mean and Peak BER vs. Absolute Lateral Offset |X|', 'FontSize', 11, 'FontWeight', 'bold');
legend({'Mean BER', 'Peak BER'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_abs_X_cm/100, 'FontSize', 9.5);
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin([mean_BER_absX; max_BER_absX]), max([mean_BER_absX; max_BER_absX]) * 2.5]);
else
    ylim([0, max([mean_BER_absX; max_BER_absX]) * 1.15 + 1e-5]);
end

%% =========================================================================
%% FIGURE 5: Symmetrized BER Analysis vs. |X| per Depth Level (Subplots Grid)
%% =========================================================================
hFig5 = figure('Name', sprintf('Fig5_BER_vs_AbsX_per_Depth_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [220, 50, 980, 880], 'Color', [1 1 1]);

nRows = ceil(numDepths / 2);
nCols = 2;

if useLogScale
    maxBER_global = max(BER_plot);
else
    maxBER_global = max(BER_eval);
end

for k = 1:numDepths
    idxK = (abs(Y_real_cm - unique_Y_cm(k)) < 1e-4);
    berK = zeros(numAbsXPos, 1);
    for i = 1:numAbsXPos
        idxKI = idxK & (abs(abs_X_cm - unique_abs_X_cm(i)) < 1e-4);
        if any(idxKI)
            if useLogScale
                berK(i) = max(effectiveFloor, mean(BER_eval(idxKI)));
            else
                berK(i) = mean(BER_eval(idxKI));
            end
        end
    end

    subplot(nRows, nCols, k);
    bk = bar(unique_abs_X_cm/100, berK, 'FaceColor', colorBER);

    title(sprintf('Depth Y = %.2f m', unique_Y_cm(k)/100), 'FontSize', 10, 'FontWeight', 'bold');
    grid on; box on;
    set(gca, 'XTick', unique_abs_X_cm/100, 'FontSize', 8.5);
    if useLogScale
        set(gca, 'YScale', 'log');
        ylim([getLogYMin(BER_plot), maxBER_global * 2.5]);
    else
        ylim([0, maxBER_global * 1.15 + 1e-5]);
    end

    if mod(k, nCols) == 1
        ylabel('Mean BER', 'FontSize', 9);
    end
    if k > (nRows - 1) * nCols
        xlabel('Absolute Offset |X| (m)', 'FontSize', 9);
    end
end

%% =========================================================================
%% FIGURE 6: Line Plot of BER vs. Absolute Offset |X| Grouped by Depth Curves
%% =========================================================================
hFig6 = figure('Name', sprintf('Fig6_LinePlot_BER_vs_AbsX_by_Depth_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [250, 150, 850, 520], 'Color', [1 1 1]);

ber_curves = zeros(numAbsXPos, numDepths);
for k = 1:numDepths
    idxK = (abs(Y_real_cm - unique_Y_cm(k)) < 1e-4);
    for i = 1:numAbsXPos
        idxKI = idxK & (abs(abs_X_cm - unique_abs_X_cm(i)) < 1e-4);
        if any(idxKI)
            if useLogScale
                ber_curves(i, k) = max(effectiveFloor, mean(BER_eval(idxKI)));
            else
                ber_curves(i, k) = mean(BER_eval(idxKI));
            end
        end
    end
end

depthColors = lines(numDepths);
markersList = {'o-', 's--', '^:', 'd-.', 'v-', '>-', '<--', 'p:'};
depthLabels = cell(numDepths, 1);

hold on;
for k = 1:numDepths
    depthLabels{k} = sprintf('Depth Y = %.2f m', unique_Y_cm(k)/100);
    mStyle = markersList{mod(k-1, length(markersList)) + 1};
    if useLogScale
        semilogy(unique_abs_X_cm/100, ber_curves(:, k), mStyle, ...
            'Color', depthColors(k, :), 'LineWidth', 1.8, ...
            'MarkerSize', 6.5, 'MarkerFaceColor', depthColors(k, :));
    else
        plot(unique_abs_X_cm/100, ber_curves(:, k), mStyle, ...
            'Color', depthColors(k, :), 'LineWidth', 1.8, ...
            'MarkerSize', 6.5, 'MarkerFaceColor', depthColors(k, :));
    end
end
hold off;

xlabel('Real Absolute Lateral Offset |X| (m)', 'FontSize', 11);
ylabel('Bit Error Rate (BER)', 'FontSize', 11);
title(sprintf('BER vs. Absolute Lateral Offset |X| Grouped by Depth Y (1/P_n = %.1f dB)', selectedOnePnDB), ...
    'FontSize', 12, 'FontWeight', 'bold');
legend(depthLabels, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_abs_X_cm/100, 'FontSize', 9.5);
unique_abs_X_m_val = unique_abs_X_cm/100;
xlim([min(unique_abs_X_m_val) - 0.02, max(unique_abs_X_m_val) + 0.02]);
if useLogScale
    set(gca, 'YScale', 'log');
    ylim([getLogYMin(ber_curves), max(ber_curves(:)) * 2.5]);
else
    ylim([0, max(ber_curves(:)) * 1.15 + 1e-5]);
end

%% =========================================================================
%% FIGURE 7: Cumulative BER Distribution Function (CDF)
%% =========================================================================
hFig7 = figure('Name', sprintf('Fig7_BER_CDF_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [270, 175, 750, 480], 'Color', [1 1 1]);

[fBER, xBER] = ecdf(BER_eval);

if useLogScale
    semilogx(max(effectiveFloor, xBER), fBER * 100, '-', 'Color', colorBER, 'LineWidth', 2.2);
    xlim([getLogYMin(BER_plot), max(BER_plot) * 1.5]);
else
    plot(xBER, fBER * 100, '-', 'Color', colorBER, 'LineWidth', 2.2);
    xlim([0, max(BER_eval) * 1.05 + 1e-5]);
end

xlabel('Bit Error Rate (BER) Threshold', 'FontSize', 11);
ylabel('Cumulative Percentage of Spatial Locations (%)', 'FontSize', 11);
title(sprintf('Cumulative BER Distribution Function (CDF at 1/P_n = %.1f dB)', selectedOnePnDB), ...
    'FontSize', 12, 'FontWeight', 'bold');
grid on; box on;
ylim([0, 102]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% FIGURE 8: 3D Surface Plot of BER Topography BER(X, Y)
%% =========================================================================
hFig8 = figure('Name', sprintf('Fig8_3D_Surface_BER_%.1fdB', selectedOnePnDB), ...
    'Units', 'pixels', 'Position', [290, 200, 850, 600], 'Color', [1 1 1]);

if useLogScale
    gridBER_plot = max(effectiveFloor, 10.^gridBER);
    surf(gridX, gridY, gridBER_plot, 'EdgeColor', 'interp', 'FaceAlpha', 0.85);
    try set(gca, 'ZScale', 'log', 'ColorScale', 'log'); catch; end
else
    surf(gridX, gridY, gridBER, 'EdgeColor', 'interp', 'FaceAlpha', 0.85);
end

colormap(gca, turbo);
c3 = colorbar('Location', 'eastoutside');
c3.Label.String = sprintf('BER at 1/P_n = %.1f dB', selectedOnePnDB);
c3.Label.FontSize = 10; c3.Label.FontWeight = 'bold';

xlabel('Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Depth Distance Y (cm)', 'FontSize', 10.5);
zlabel('Bit Error Rate (BER)', 'FontSize', 10.5);
title(sprintf('3D Spatial Topography of BER (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 12, 'FontWeight', 'bold');
grid on; box on;
view([-37.5, 30]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% Console Summary Table Generation
%% =========================================================================
fprintf('\n=======================================================\n');
fprintf('        BER SPATIAL SUMMARY TABLE (1/Pn = %.1f dB)      \n', selectedOnePnDB);
fprintf('=======================================================\n');
fprintf('Metric / Grouping      | Mean BER   | Std BER    | Max BER    | 90th Pct  \n');
fprintf('-------------------------------------------------------\n');
fprintf('Overall Dataset        | %10.6f | %10.6f | %10.6f | %10.6f\n', ...
    mean(BER_eval), std(BER_eval), max(BER_eval), prctile(BER_eval, 90));
fprintf('-------------------------------------------------------\n');
fprintf('--- Breakdown by Depth Y ---\n');
for i = 1:numDepths
    idx = (abs(Y_real_cm - unique_Y_cm(i)) < 1e-4);
    subBER = BER_eval(idx);
    fprintf('Depth Y = %5.2f m      | %10.6f | %10.6f | %10.6f | %10.6f\n', ...
        unique_Y_cm(i)/100, mean(subBER), std(subBER), max(subBER), prctile(subBER, 90));
end
fprintf('-------------------------------------------------------\n');
fprintf('--- Breakdown by Absolute Offset |X| ---\n');
for i = 1:numAbsXPos
    idx = (abs(abs_X_cm - unique_abs_X_cm(i)) < 1e-4);
    subBER = BER_eval(idx);
    fprintf('Offset |X| = %5.3f m   | %10.6f | %10.6f | %10.6f | %10.6f\n', ...
        unique_abs_X_cm(i)/100, mean(subBER), std(subBER), max(subBER), prctile(subBER, 90));
end
fprintf('=======================================================\n\n');
