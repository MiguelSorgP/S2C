%% analise_correlacao_ber_posicionamento.m
% MATLAB script to evaluate the correlation between Bit Error Rate (BER)
% and PnP 3D Positioning Error across spatial camera recordings.
%
% This script loads datasets from:
%   1. BER simulation MAT files (dadosBER)
%   2. PnP positioning CSV results (resultadosPnP)
%
% Performs:
%   - Data matching by clean video identifier and spatial coordinates.
%   - Computation of Pearson (r), Spearman (rho), and Kendall (tau) correlations.
%   - Calculation of p-values and linear regression R^2 metrics.
%   - Generation of 5 publication-ready figures including scatter plots,
%     spatial comparison maps, depth-segregated scatters, a correlation matrix heatmap,
%     and standalone log10(BER) vs 3D error scatter plot.

clear; clc; close all;

%% 1. Path Setup & Configuration
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

% Noise level operating point for BER evaluation (in dB)
targetOnePnDB = -28;    % Options: 'auto' or numeric scalar in dB (e.g. -28)
useLogScale   = true;   % Use log scale for BER when plotting/analyzing
minBERFloor   = 'auto'; % Floor for zero-BER values in log plots

% Data paths
csvPath   = fullfile(scriptDir, 'resultadosPnP', 'resultados_PnP_Kvideo1.csv');
targetDir = fullfile(scriptDir, 'dadosBER', '29_07_2026_12_36');

if ~exist(csvPath, 'file')
    csvFiles = dir(fullfile(scriptDir, '**', 'resultados_PnP*.csv'));
    if ~isempty(csvFiles)
        csvPath = fullfile(csvFiles(1).folder, csvFiles(1).name);
    else
        error('PnP CSV results file not found at: %s', csvPath);
    end
end

if ~exist(targetDir, 'dir')
    fallbackDir = fullfile(scriptDir, 'dadosBER');
    if exist(fallbackDir, 'dir')
        targetDir = fallbackDir;
    else
        targetDir = scriptDir;
    end
end

fprintf('=======================================================\n');
fprintf('  BER vs POSITIONING ERROR CORRELATION ANALYSIS        \n');
fprintf('=======================================================\n');
fprintf('PnP CSV Source : %s\n', csvPath);
fprintf('BER MAT Folder : %s\n', targetDir);

%% 2. Load PnP Positioning Data
optsPnP = detectImportOptions(csvPath);
optsPnP.VariableNamingRule = 'preserve';
pnpTable = readtable(csvPath, optsPnP);

% Convert coordinates and calculate errors (in cm)
X_real_pnp = pnpTable.x_position * 100;
Y_real_pnp = pnpTable.y_position * 100;
Z_real_pnp = pnpTable.z_position * 100;

X_est_pnp  = pnpTable.pnp_builtin_x * 100;
Y_est_pnp  = pnpTable.pnp_builtin_z * 100; % PnP Z axis maps to World Depth Y
Z_est_pnp  = pnpTable.pnp_builtin_y * 100; % PnP Y axis maps to World Height Z

err_X_pnp  = abs(X_real_pnp - X_est_pnp);
err_Y_pnp  = abs(Y_real_pnp - Y_est_pnp);
err_Z_pnp  = abs(Z_real_pnp - Z_est_pnp);
err_3D_pnp = sqrt(err_X_pnp.^2 + err_Y_pnp.^2 + err_Z_pnp.^2);

% Extract video identifiers
pnpVideoNames = pnpTable.video_name;
numPnP = height(pnpTable);

%% 3. Load & Filter BER Data
matFiles = dir(fullfile(targetDir, '*.mat'));
if isempty(matFiles)
    error('No .mat files found in target folder: %s', targetDir);
end

% Check checkpoint CSV for zero-noise exclusions
checkpointFile = fullfile(targetDir, 'checkpoint_dadosBER.csv');
invalidVideosCSV = {};
if exist(checkpointFile, 'file')
    optsChk = detectImportOptions(checkpointFile);
    optsChk.VariableNamingRule = 'preserve';
    chkData = readtable(checkpointFile, optsChk);
    if ismember('video_name', chkData.Properties.VariableNames) && ismember('BER', chkData.Properties.VariableNames)
        badIdx = chkData.BER > 1e-4;
        invalidVideosCSV = chkData.video_name(badIdx);
    end
end

% Mappings from key to physical coordinates (meters)
y_map = [1, 0.75; 2, 1.00; 3, 1.25; 4, 1.50; 5, 1.75; 6, 2.00; 7, 2.25; 8, 2.50];
x_map = [1, 0.350; 2, 0.175; 3, 0.000; 4, -0.175; 5, -0.350];
z_map = [0, -0.114; 1, 0.126];

fileDataList = {};
for i = 1:length(matFiles)
    fName = matFiles(i).name;
    filePath = fullfile(targetDir, fName);
    info = parseVideoName(fName);
    if ~info.is_valid, continue; end
    
    [~, baseVName, ~] = fileparts(fName);
    baseVNameClean = regexprep(baseVName, '(_resultado|_sincronizado|_fundo)$', '');
    
    if any(contains(invalidVideosCSV, baseVNameClean))
        continue;
    end
    
    try
        matData = load(filePath);
    catch
        continue;
    end
    
    if ~isfield(matData, 'OnePnDB') || ~isfield(matData, 'BERvals')
        continue;
    end
    
    % Zero-noise validation check
    if matData.BERvals(end) > 1e-4 || matData.BERvals(1) > 0.45
        continue;
    end
    
    y_idx = find(abs(y_map(:, 1) - info.y_key) < 1e-4, 1);
    x_idx = find(abs(x_map(:, 1) - info.x_key) < 1e-4, 1);
    z_idx = find(abs(z_map(:, 1) - info.z_key) < 1e-4, 1);
    if isempty(y_idx) || isempty(x_idx) || isempty(z_idx), continue; end
    
    itemData.fName        = fName;
    itemData.cleanID      = baseVNameClean;
    itemData.y_real_m     = y_map(y_idx, 2);
    itemData.x_real_m     = x_map(x_idx, 2);
    itemData.z_real_m     = z_map(z_idx, 2);
    itemData.abs_x_m      = abs(itemData.x_real_m);
    itemData.OnePnDB      = matData.OnePnDB(:);
    itemData.BERvals      = matData.BERvals(:);
    
    fileDataList{end+1}   = itemData; %#ok<AGROW>
end

numValidBER = length(fileDataList);
fprintf('Valid BER recordings loaded: %d\n', numValidBER);

%% 4. Operating Point 1/Pn (dB) Selection
allOnePn = [];
for k = 1:numValidBER
    allOnePn = unique([allOnePn; fileDataList{k}.OnePnDB]);
end
allOnePn = sort(allOnePn);

if ischar(targetOnePnDB) || (isstring(targetOnePnDB) && strcmpi(targetOnePnDB, 'auto'))
    bestOnePn = allOnePn(1);
    maxScore = -1;
    for idxP = 1:length(allOnePn)
        pnVal = allOnePn(idxP);
        bersAtPn = zeros(numValidBER, 1);
        for k = 1:numValidBER
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
else
    selectedOnePnDB = double(targetOnePnDB);
end
fprintf('Selected 1/Pn operating point: %.2f dB\n', selectedOnePnDB);

%% 5. Match Datasets (Pair BER and PnP per Recording)
matched_ID      = {};
matched_X_cm    = [];
matched_Y_cm    = [];
matched_Z_cm    = [];
matched_absX_cm = [];
matched_BER     = [];
matched_errX    = [];
matched_errY    = [];
matched_errZ    = [];
matched_err3D   = [];

for k = 1:numValidBER
    berItem = fileDataList{k};
    
    % Interpolate BER value at target operating point
    berVal = max(0, interp1(berItem.OnePnDB, berItem.BERvals, selectedOnePnDB, 'linear', 'extrap'));
    
    % Match with PnP CSV table by clean name or spatial coordinates
    matchIdx = [];
    for i = 1:numPnP
        pnpCleanName = regexprep(pnpVideoNames{i}, '(\.mp4|_resultado|_sincronizado)$', '');
        if strcmpi(pnpCleanName, berItem.cleanID) || contains(pnpCleanName, berItem.cleanID) || contains(berItem.cleanID, pnpCleanName)
            matchIdx = i;
            break;
        end
    end
    
    % Fallback spatial coordinate matching if name match failed
    if isempty(matchIdx)
        for i = 1:numPnP
            if abs(X_real_pnp(i)/100 - berItem.x_real_m) < 1e-3 && ...
               abs(Y_real_pnp(i)/100 - berItem.y_real_m) < 1e-3
                matchIdx = i;
                break;
            end
        end
    end
    
    if ~isempty(matchIdx)
        matched_ID{end+1, 1}     = berItem.cleanID; %#ok<AGROW>
        matched_X_cm(end+1, 1)    = berItem.x_real_m * 100; %#ok<AGROW>
        matched_Y_cm(end+1, 1)    = berItem.y_real_m * 100; %#ok<AGROW>
        matched_Z_cm(end+1, 1)    = berItem.z_real_m * 100; %#ok<AGROW>
        matched_absX_cm(end+1, 1) = berItem.abs_x_m * 100; %#ok<AGROW>
        matched_BER(end+1, 1)     = berVal; %#ok<AGROW>
        
        matched_errX(end+1, 1)    = err_X_pnp(matchIdx); %#ok<AGROW>
        matched_errY(end+1, 1)    = err_Y_pnp(matchIdx); %#ok<AGROW>
        matched_errZ(end+1, 1)    = err_Z_pnp(matchIdx); %#ok<AGROW>
        matched_err3D(end+1, 1)   = err_3D_pnp(matchIdx); %#ok<AGROW>
    end
end

N_matched = length(matched_BER);
if N_matched == 0
    error('Could not pair any BER recording with PnP CSV entries.');
end
fprintf('Successfully matched BER and PnP data for %d recordings.\n', N_matched);

% Effective floor for log BER visualization/analysis
nonZeroBERs = matched_BER(matched_BER > 0);
if ischar(minBERFloor) || (isstring(minBERFloor) && strcmpi(minBERFloor, 'auto'))
    if ~isempty(nonZeroBERs)
        effectiveFloor = 10^(floor(log10(min(nonZeroBERs))) - 1);
    else
        effectiveFloor = 1e-5;
    end
else
    effectiveFloor = double(minBERFloor);
end
matched_logBER = log10(max(effectiveFloor, matched_BER));

%% 6. Statistical Correlation Analysis
% Helper function for correlation metrics
calcCorr = @(x, y) struct(...
    'pearson_r', corr(x, y, 'Type', 'Pearson'), ...
    'pearson_p', getPVal(x, y, 'Pearson'), ...
    'spearman_rho', corr(x, y, 'Type', 'Spearman'), ...
    'spearman_p', getPVal(x, y, 'Spearman'), ...
    'kendall_tau', corr(x, y, 'Type', 'Kendall'), ...
    'kendall_p', getPVal(x, y, 'Kendall'), ...
    'r_squared', (corr(x, y, 'Type', 'Pearson'))^2 ...
);

% Pairwise correlation testing
c_BER_err3D   = calcCorr(matched_BER, matched_err3D);
c_logBER_3D   = calcCorr(matched_logBER, matched_err3D);
c_BER_errY    = calcCorr(matched_BER, matched_errY);
c_BER_errX    = calcCorr(matched_BER, matched_errX);
c_BER_errZ    = calcCorr(matched_BER, matched_errZ);
c_BER_Yreal   = calcCorr(matched_BER, matched_Y_cm);
c_err3D_Yreal = calcCorr(matched_err3D, matched_Y_cm);
c_BER_absX    = calcCorr(matched_BER, matched_absX_cm);
c_err3D_absX  = calcCorr(matched_err3D, matched_absX_cm);

%% 7. Console Summary Table Output
fprintf('\n=========================================================================================\n');
fprintf('                 CORRELATION STATISTICAL SUMMARY (BER vs POSITIONING ERROR)               \n');
fprintf('=========================================================================================\n');
fprintf('%-24s | Pearson r (p-val)   | Spearman rho (p-val)| Kendall tau (p-val)  | R^2    \n', 'Variable Pair');
fprintf('-----------------------------------------------------------------------------------------\n');
printCorrRow('BER vs 3D Error', c_BER_err3D);
printCorrRow('log10(BER) vs 3D Error', c_logBER_3D);
printCorrRow('BER vs Y Depth Error', c_BER_errY);
printCorrRow('BER vs X Lateral Error', c_BER_errX);
printCorrRow('BER vs Z Height Error', c_BER_errZ);
printCorrRow('BER vs Real Depth Y', c_BER_Yreal);
printCorrRow('3D Error vs Real Depth Y', c_err3D_Yreal);
printCorrRow('BER vs Abs Offset |X|', c_BER_absX);
printCorrRow('3D Error vs Abs Offset |X|', c_err3D_absX);
fprintf('=========================================================================================\n\n');

%% 8. Color Palette Definitions
colorGT  = [0.10, 0.35, 0.80]; % Blue
colorEst = [0.85, 0.15, 0.15]; % Red
color3D  = [0.85, 0.20, 0.20]; % Dark Red
colorX   = [0.23, 0.51, 0.96]; % Light Blue
colorY   = [0.02, 0.71, 0.83]; % Cyan

%% =========================================================================
%% FIGURE 1: Scatter Plots with Linear Regression & Correlation Annotations
%% =========================================================================
hFig1 = figure('Name', 'Fig1_Scatter_BER_vs_Positioning_Error', ...
    'Units', 'pixels', 'Position', [100, 80, 950, 780], 'Color', [1 1 1]);

% --- Subplot (a): Linear BER vs 3D Positioning Error ---
subplot(2, 2, 1);
scatter(matched_BER, matched_err3D, 55, color3D, 'filled', 'MarkerEdgeColor', 'k');
hold on;
pFit1 = polyfit(matched_BER, matched_err3D, 1);
xFit1 = linspace(min(matched_BER), max(matched_BER), 100);
plot(xFit1, polyval(pFit1, xFit1), 'r--', 'LineWidth', 1.8);
xlabel('Bit Error Rate (BER)', 'FontSize', 10);
ylabel('3D Positioning Error (cm)', 'FontSize', 10);
title('(a) BER vs. 3D Positioning Error', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
txt1 = sprintf('Pearson r = %.3f (p=%.3f)\nSpearman \\rho = %.3f (p=%.3f)\nR^2 = %.3f', ...
    c_BER_err3D.pearson_r, c_BER_err3D.pearson_p, ...
    c_BER_err3D.spearman_rho, c_BER_err3D.spearman_p, c_BER_err3D.r_squared);
annotation('textbox', [0.15 0.75 0.18 0.12], 'String', txt1, 'FitBoxToText', 'on', ...
    'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], 'FontSize', 8.5);

% --- Subplot (b): log10(BER) vs 3D Positioning Error ---
subplot(2, 2, 2);
scatter(matched_logBER, matched_err3D, 55, [0.4 0.2 0.7], 'filled', 'MarkerEdgeColor', 'k');
hold on;
pFit2 = polyfit(matched_logBER, matched_err3D, 1);
xFit2 = linspace(min(matched_logBER), max(matched_logBER), 100);
plot(xFit2, polyval(pFit2, xFit2), 'm--', 'LineWidth', 1.8);
xlabel('log_{10}(BER)', 'FontSize', 10);
ylabel('3D Positioning Error (cm)', 'FontSize', 10);
title('(b) log_{10}(BER) vs. 3D Positioning Error', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
txt2 = sprintf('Pearson r = %.3f (p=%.3f)\nSpearman \\rho = %.3f (p=%.3f)\nR^2 = %.3f', ...
    c_logBER_3D.pearson_r, c_logBER_3D.pearson_p, ...
    c_logBER_3D.spearman_rho, c_logBER_3D.spearman_p, c_logBER_3D.r_squared);
annotation('textbox', [0.59 0.75 0.18 0.12], 'String', txt2, 'FitBoxToText', 'on', ...
    'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], 'FontSize', 8.5);

% --- Subplot (c): BER vs Y Depth Error ---
subplot(2, 2, 3);
scatter(matched_BER, matched_errY, 55, colorY, 'filled', 'MarkerEdgeColor', 'k');
hold on;
pFit3 = polyfit(matched_BER, matched_errY, 1);
plot(xFit1, polyval(pFit3, xFit1), 'c--', 'LineWidth', 1.8);
xlabel('Bit Error Rate (BER)', 'FontSize', 10);
ylabel('Y Depth Error (cm)', 'FontSize', 10);
title('(c) BER vs. Y Depth Error', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
txt3 = sprintf('Pearson r = %.3f (p=%.3f)\nSpearman \\rho = %.3f (p=%.3f)\nR^2 = %.3f', ...
    c_BER_errY.pearson_r, c_BER_errY.pearson_p, ...
    c_BER_errY.spearman_rho, c_BER_errY.spearman_p, c_BER_errY.r_squared);
annotation('textbox', [0.15 0.27 0.18 0.12], 'String', txt3, 'FitBoxToText', 'on', ...
    'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], 'FontSize', 8.5);

% --- Subplot (d): BER vs X Lateral Error ---
subplot(2, 2, 4);
scatter(matched_BER, matched_errX, 55, colorX, 'filled', 'MarkerEdgeColor', 'k');
hold on;
pFit4 = polyfit(matched_BER, matched_errX, 1);
plot(xFit1, polyval(pFit4, xFit1), 'b--', 'LineWidth', 1.8);
xlabel('Bit Error Rate (BER)', 'FontSize', 10);
ylabel('X Lateral Error (cm)', 'FontSize', 10);
title('(d) BER vs. X Lateral Error', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
txt4 = sprintf('Pearson r = %.3f (p=%.3f)\nSpearman \\rho = %.3f (p=%.3f)\nR^2 = %.3f', ...
    c_BER_errX.pearson_r, c_BER_errX.pearson_p, ...
    c_BER_errX.spearman_rho, c_BER_errX.spearman_p, c_BER_errX.r_squared);
annotation('textbox', [0.59 0.27 0.18 0.12], 'String', txt4, 'FitBoxToText', 'on', ...
    'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], 'FontSize', 8.5);

%% =========================================================================
%% FIGURE 2: Dual 2D Spatial Map Comparison (BER vs 3D Positioning Error)
%% =========================================================================
hFig2 = figure('Name', 'Fig2_Spatial_Dual_Comparison_Map', ...
    'Units', 'pixels', 'Position', [150, 100, 880, 820], 'Color', [1 1 1]);

% --- Subplot (a): 2D Spatial Distribution of BER ---
subplot(2, 1, 1);
sizesBER = 35 + (matched_BER / max(max(matched_BER), 1e-6)) * 120;
scatter(matched_X_cm, matched_Y_cm, sizesBER, matched_BER, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);
colormap(gca, turbo);
c1 = colorbar('Location', 'eastoutside');
c1.Label.String = sprintf('BER at 1/P_n = %.1f dB', selectedOnePnDB);
c1.Label.FontSize = 10; c1.Label.FontWeight = 'bold';
xlabel('Real Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
title(sprintf('(a) Spatial BER Map (1/P_n = %.1f dB)', selectedOnePnDB), 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
xlim([min(matched_X_cm) - 6, max(matched_X_cm) + 6]);
ylim([min(matched_Y_cm) - 10, max(matched_Y_cm) + 15]);

% --- Subplot (b): 2D Spatial Distribution of 3D Positioning Error ---
subplot(2, 1, 2);
sizesErr = 35 + (matched_err3D / max(matched_err3D)) * 120;
scatter(matched_X_cm, matched_Y_cm, sizesErr, matched_err3D, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);
colormap(gca, turbo);
c2 = colorbar('Location', 'eastoutside');
c2.Label.String = '3D Positioning Error (cm)';
c2.Label.FontSize = 10; c2.Label.FontWeight = 'bold';
xlabel('Real Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
title('(b) Spatial 3D Positioning Error Map (cm)', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
xlim([min(matched_X_cm) - 6, max(matched_X_cm) + 6]);
ylim([min(matched_Y_cm) - 10, max(matched_Y_cm) + 15]);

%% =========================================================================
%% FIGURE 3: Depth-Segregated Correlation Scatters
%% =========================================================================
hFig3 = figure('Name', 'Fig3_Correlation_per_Depth_Subplots', ...
    'Units', 'pixels', 'Position', [200, 60, 960, 850], 'Color', [1 1 1]);

uniqueDepths_cm = sort(unique(matched_Y_cm));
numD = length(uniqueDepths_cm);
nRows = ceil(numD / 2);
nCols = 2;

for d = 1:numD
    idxD = (abs(matched_Y_cm - uniqueDepths_cm(d)) < 1e-4);
    subBER  = matched_BER(idxD);
    subErr  = matched_err3D(idxD);
    
    subplot(nRows, nCols, d);
    scatter(subBER, subErr, 60, color3D, 'filled', 'MarkerEdgeColor', 'k');
    hold on;
    if length(subBER) >= 2 && (max(subBER) - min(subBER)) > 1e-8
        pD = polyfit(subBER, subErr, 1);
        xD = linspace(min(subBER), max(subBER), 50);
        plot(xD, polyval(pD, xD), 'r--', 'LineWidth', 1.5);
        rD = corr(subBER, subErr, 'Type', 'Pearson');
    else
        rD = NaN;
    end
    
    title(sprintf('Depth Y = %.2f m (r = %.2f)', uniqueDepths_cm(d)/100, rD), ...
        'FontSize', 10, 'FontWeight', 'bold');
    xlabel('BER', 'FontSize', 9);
    ylabel('3D Error (cm)', 'FontSize', 9);
    grid on; box on;
end

%% =========================================================================
%% FIGURE 4: Correlation Matrix Heatmap
%% =========================================================================
hFig4 = figure('Name', 'Fig4_Correlation_Matrix_Heatmap', ...
    'Units', 'pixels', 'Position', [250, 150, 820, 650], 'Color', [1 1 1]);

varNames = {'BER', 'log10(BER)', 'Err X', 'Err Y', 'Err Z', 'Err 3D', 'Depth Y', 'Abs X'};
varData  = [matched_BER, matched_logBER, matched_errX, matched_errY, matched_errZ, matched_err3D, matched_Y_cm, matched_absX_cm];
numVars  = length(varNames);

corrMatrix = corr(varData, 'Type', 'Pearson');

imagesc(corrMatrix);
colormap(cool);
c3 = colorbar;
c3.Label.String = 'Pearson Correlation Coefficient (r)';
c3.Label.FontSize = 10; c3.Label.FontWeight = 'bold';
caxis([-1, 1]);

set(gca, 'XTick', 1:numVars, 'XTickLabel', varNames, 'FontSize', 9.5);
set(gca, 'YTick', 1:numVars, 'YTickLabel', varNames, 'FontSize', 9.5);
xtickangle(45);
title('Pairwise Pearson Correlation Matrix Heatmap', 'FontSize', 12, 'FontWeight', 'bold');

% Annotate heatmap values
for row = 1:numVars
    for col = 1:numVars
        val = corrMatrix(row, col);
        if abs(val) > 0.5
            textColor = 'k';
        else
            textColor = 'w';
        end
        text(col, row, sprintf('%.2f', val), 'HorizontalAlignment', 'center', ...
            'Color', textColor, 'FontWeight', 'bold', 'FontSize', 9);
    end
end

%% =========================================================================
%% FIGURE 5: Standalone Scatter Plot - log10(BER) vs 3D Positioning Error (Fig 1b)
%% =========================================================================
hFig5 = figure('Name', 'Fig5_Scatter_logBER_vs_3D_Positioning_Error', ...
    'Units', 'pixels', 'Position', [300, 150, 680, 520], 'Color', [1 1 1]);

scatter(matched_logBER, matched_err3D, 65, [0.4 0.2 0.7], 'filled', 'MarkerEdgeColor', 'k');
hold on;
pFit5 = polyfit(matched_logBER, matched_err3D, 1);
xFit5 = linspace(min(matched_logBER), max(matched_logBER), 100);
plot(xFit5, polyval(pFit5, xFit5), 'm--', 'LineWidth', 2.0);
xlabel('log_{10}(BER)', 'FontSize', 11);
ylabel('3D Positioning Error (cm)', 'FontSize', 11);
title('log_{10}(BER) vs. 3D Positioning Error', 'FontSize', 12, 'FontWeight', 'bold');
grid on; box on;

txt5 = sprintf('Pearson r = %.3f (p=%.3f)\nSpearman \\rho = %.3f (p=%.3f)\nR^2 = %.3f', ...
    c_logBER_3D.pearson_r, c_logBER_3D.pearson_p, ...
    c_logBER_3D.spearman_rho, c_logBER_3D.spearman_p, c_logBER_3D.r_squared);
annotation('textbox', [0.18 0.73 0.25 0.14], 'String', txt5, 'FitBoxToText', 'on', ...
    'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], 'FontSize', 9.5);

%% =========================================================================
%% Helper Output Functions
%% =========================================================================
function pVal = getPVal(x, y, typeStr)
    try
        [~, pVal] = corr(x, y, 'Type', typeStr);
    catch
        pVal = NaN;
    end
end

function printCorrRow(labelStr, cStruct)
    fprintf('%-24s | %6.3f (p=%5.3f) | %6.3f (p=%5.3f) | %6.3f (p=%5.3f) | %6.3f \n', ...
        labelStr, cStruct.pearson_r, cStruct.pearson_p, ...
        cStruct.spearman_rho, cStruct.spearman_p, ...
        cStruct.kendall_tau, cStruct.kendall_p, ...
        cStruct.r_squared);
end
