%% generate_pnp_publication_figures.m
% MATLAB script to process PnP positioning results and generate 8
% high-quality, publication-ready figures for articles/dissertation.
%
% Figure 1: 2D Spatial Performance (Position Map + Discrete Bubble Error Map)
% Figure 2: Error Analysis vs. Depth (Boxplot of 3D Error + Grouped MAE Bar Chart)
% Figure 3: Error Analysis vs. Lateral Position X (Boxplot of 3D Error + Grouped MAE Bar Chart)
% Figure 4: Symmetrized Error Analysis vs. Absolute Lateral Offset |X| (Boxplot + Grouped MAE)
% Figure 5: Symmetrized Error Analysis vs. |X| per Depth Level (Subplots per Depth, Grouped MAE)
% Figure 6: Symmetrized 3D Error Boxplots vs. |X| per Depth Level (Subplots per Depth, Boxplot)
% Figure 7: 3D Error vs. Absolute Lateral Offset |X| Line Plot Grouped by Depth Y Curves
% Figure 8: Cumulative Error Distribution Function (CDF for X, Y, Z, and 3D Errors)

clear; clc; close all;

%% 1. Import Data
csvPath = fullfile('resultadosPnP', 'resultados_PnP_Kvideo1.csv');

if ~exist(csvPath, 'file')
    % Search fallback in subdirectories
    csvFiles = dir(fullfile('**', 'resultados_PnP*.csv'));
    if ~isempty(csvFiles)
        csvPath = fullfile(csvFiles(1).folder, csvFiles(1).name);
    else
        error('CSV file not found! Please check the path: %s', csvPath);
    end
end

opts = detectImportOptions(csvPath);
data = readtable(csvPath, opts);

%% 2. Extract Coordinates & Convert to Centimeters (cm)
% World Ground Truth (m -> cm)
X_real = data.x_position * 100; % Lateral (cm)
Y_real = data.y_position * 100; % Depth (cm)
Z_real = data.z_position * 100; % Height (cm)

% PnP Estimated Coordinates (m -> cm)
X_est  = data.pnp_builtin_x * 100; % Lateral X
Y_est  = data.pnp_builtin_z * 100; % Depth Y (PnP Z-axis is World Depth Y)
Z_est  = data.pnp_builtin_y * 100; % Height Z (PnP Y-axis is World Height Z)

% Positioning Errors (cm)
err_X  = abs(X_real - X_est);
err_Y  = abs(Y_real - Y_est);
err_Z  = abs(Z_real - Z_est);
err_3D = sqrt(err_X.^2 + err_Y.^2 + err_Z.^2);

numRecordings = height(data);

%% 3. Color Palette Definition
colorGT  = [0.10, 0.35, 0.80]; % Dark Blue for Ground Truth
colorEst = [0.85, 0.15, 0.15]; % Red for Estimated
colorX   = [0.23, 0.51, 0.96]; % Blue
colorY   = [0.02, 0.71, 0.83]; % Cyan
colorZ   = [0.06, 0.73, 0.51]; % Green
color3D  = [0.85, 0.20, 0.20]; % Dark Red

%% =========================================================================
%% FIGURE 1: 2D Spatial Performance Map & Discrete Error Grid
%% =========================================================================
hFig1 = figure('Name', 'Fig1_Spatial_Performance_2D', 'Units', 'pixels', 'Position', [100, 50, 850, 820]);

% --- Subplot (a): X x Y Spatial Position Map ---
subplot(2, 1, 1);
hold on;
for i = 1:numRecordings
    plot([X_real(i), X_est(i)], [Y_real(i), Y_est(i)], ':', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.8, 'HandleVisibility', 'off');
end
hGT  = plot(X_real, Y_real, 'o', 'MarkerFaceColor', colorGT, 'MarkerEdgeColor', 'k', 'MarkerSize', 5.5);
hEst = plot(X_est, Y_est, 'x', 'Color', colorEst, 'LineWidth', 1.5, 'MarkerSize', 6.5);

xlabel('Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Depth Distance Y (cm)', 'FontSize', 10.5);
title('(a) Ground Truth vs. Estimated Positions (X-Y Plane)', 'FontSize', 11, 'FontWeight', 'bold');
legend([hGT, hEst], {'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
xlim([min([X_real; X_est]) - 6, max([X_real; X_est]) + 6]);
ylim([min([Y_real; Y_est]) - 10, max([Y_real; Y_est]) + 15]);
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Discrete Bubble Error Grid ---
subplot(2, 1, 2);
bubbleSizes = 35 + (err_3D / max(err_3D)) * 110; % Dynamic bubble size based on 3D error

scatter(X_real, Y_real, bubbleSizes, err_3D, 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2]);
colormap(gca, turbo);
c = colorbar('Location', 'eastoutside');
c.Label.String = '3D Error (cm)';
c.Label.FontSize = 10;

xlabel('Real Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
title('(b) Discrete Spatial Distribution of 3D Error', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
xlim([min(X_real) - 6, max(X_real) + 6]);
ylim([min(Y_real) - 10, max(Y_real) + 15]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% FIGURE 2: Error Analysis vs. Depth (Boxplot & Grouped MAE)
%% =========================================================================
hFig2 = figure('Name', 'Fig2_Error_Analysis_vs_Depth', 'Units', 'pixels', 'Position', [150, 100, 850, 750]);

unique_Y_m = sort(unique(data.y_position));
numDepths  = length(unique_Y_m);

% --- Subplot (a): Boxplot of 3D Error per Depth ---
subplot(2, 1, 1);
boxplot(err_3D, Y_real/100, 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Depth Distance Y (m)', 'FontSize', 10.5);
ylabel('3D Positioning Error (cm)', 'FontSize', 10.5);
title('(a) 3D Error Dispersion across Depths', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
ylim([0, max(err_3D) * 1.15]);
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Grouped Bar Chart (MAE per Axis vs. Depth) ---
subplot(2, 1, 2);
mae_X_depth  = zeros(numDepths, 1);
mae_Y_depth  = zeros(numDepths, 1);
mae_Z_depth  = zeros(numDepths, 1);
mae_3D_depth = zeros(numDepths, 1);

for i = 1:numDepths
    idx = (abs(data.y_position - unique_Y_m(i)) < 1e-4);
    mae_X_depth(i)  = mean(err_X(idx));
    mae_Y_depth(i)  = mean(err_Y(idx));
    mae_Z_depth(i)  = mean(err_Z(idx));
    mae_3D_depth(i) = mean(err_3D(idx));
end

b2 = bar(unique_Y_m, [mae_X_depth, mae_Y_depth, mae_Z_depth, mae_3D_depth], 'grouped');
b2(1).FaceColor = colorX;
b2(2).FaceColor = colorY;
b2(3).FaceColor = colorZ;
b2(4).FaceColor = color3D;

xlabel('Real Depth Distance Y (m)', 'FontSize', 10.5);
ylabel('Mean Absolute Error (cm)', 'FontSize', 10.5);
title('(b) Mean Error per Axis vs. Depth Distance', 'FontSize', 11, 'FontWeight', 'bold');
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_Y_m, 'FontSize', 9.5);
ylim([0, max([mae_X_depth; mae_Y_depth; mae_Z_depth; mae_3D_depth]) * 1.15]);

%% =========================================================================
%% FIGURE 3: Error Analysis vs. Lateral Position X (Boxplot & Grouped MAE)
%% =========================================================================
hFig3 = figure('Name', 'Fig3_Error_Analysis_vs_Lateral_X', 'Units', 'pixels', 'Position', [175, 125, 850, 750]);

unique_X_m = sort(unique(data.x_position));
numXPos    = length(unique_X_m);

% --- Subplot (a): Boxplot of 3D Error per Lateral Position X ---
subplot(2, 1, 1);
boxplot(err_3D, X_real/100, 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Lateral Position X (m)', 'FontSize', 10.5);
ylabel('3D Positioning Error (cm)', 'FontSize', 10.5);
title('(a) 3D Error Dispersion across Lateral Positions X', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
ylim([0, max(err_3D) * 1.15]);
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Grouped Bar Chart (MAE per Axis vs. Lateral Position X) ---
subplot(2, 1, 2);
mae_X_Xpos  = zeros(numXPos, 1);
mae_Y_Xpos  = zeros(numXPos, 1);
mae_Z_Xpos  = zeros(numXPos, 1);
mae_3D_Xpos = zeros(numXPos, 1);

for i = 1:numXPos
    idx = (abs(data.x_position - unique_X_m(i)) < 1e-4);
    mae_X_Xpos(i)  = mean(err_X(idx));
    mae_Y_Xpos(i)  = mean(err_Y(idx));
    mae_Z_Xpos(i)  = mean(err_Z(idx));
    mae_3D_Xpos(i) = mean(err_3D(idx));
end

b3 = bar(unique_X_m, [mae_X_Xpos, mae_Y_Xpos, mae_Z_Xpos, mae_3D_Xpos], 'grouped');
b3(1).FaceColor = colorX;
b3(2).FaceColor = colorY;
b3(3).FaceColor = colorZ;
b3(4).FaceColor = color3D;

xlabel('Real Lateral Position X (m)', 'FontSize', 10.5);
ylabel('Mean Absolute Error (cm)', 'FontSize', 10.5);
title('(b) Mean Error per Axis vs. Lateral Position X', 'FontSize', 11, 'FontWeight', 'bold');
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_X_m, 'FontSize', 9.5);
ylim([0, max([mae_X_Xpos; mae_Y_Xpos; mae_Z_Xpos; mae_3D_Xpos]) * 1.15]);

%% =========================================================================
%% FIGURE 4: Symmetrized Error Analysis vs. Absolute Lateral Offset |X|
%% =========================================================================
hFig4 = figure('Name', 'Fig4_Error_Analysis_vs_Abs_Lateral_X', 'Units', 'pixels', 'Position', [200, 150, 850, 750]);

abs_X_m        = round(abs(data.x_position), 4);
unique_abs_X_m = sort(unique(abs_X_m));
numAbsXPos     = length(unique_abs_X_m);

% --- Subplot (a): Boxplot of 3D Error per Absolute Lateral Offset |X| ---
subplot(2, 1, 1);
boxplot(err_3D, round(abs(X_real)/100, 4), 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Absolute Lateral Offset |X| (m)', 'FontSize', 10.5);
ylabel('3D Positioning Error (cm)', 'FontSize', 10.5);
title('(a) 3D Error Dispersion across Symmetrized Lateral Offsets |X|', 'FontSize', 11, 'FontWeight', 'bold');
grid on; box on;
ylim([0, max(err_3D) * 1.15]);
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Grouped Bar Chart (MAE per Axis vs. |X|) ---
subplot(2, 1, 2);
mae_X_absX  = zeros(numAbsXPos, 1);
mae_Y_absX  = zeros(numAbsXPos, 1);
mae_Z_absX  = zeros(numAbsXPos, 1);
mae_3D_absX = zeros(numAbsXPos, 1);

for i = 1:numAbsXPos
    idx = (abs(abs_X_m - unique_abs_X_m(i)) < 1e-4);
    mae_X_absX(i)  = mean(err_X(idx));
    mae_Y_absX(i)  = mean(err_Y(idx));
    mae_Z_absX(i)  = mean(err_Z(idx));
    mae_3D_absX(i) = mean(err_3D(idx));
end

b4 = bar(unique_abs_X_m, [mae_X_absX, mae_Y_absX, mae_Z_absX, mae_3D_absX], 'grouped');
b4(1).FaceColor = colorX;
b4(2).FaceColor = colorY;
b4(3).FaceColor = colorZ;
b4(4).FaceColor = color3D;

xlabel('Real Absolute Lateral Offset |X| (m)', 'FontSize', 10.5);
ylabel('Mean Absolute Error (cm)', 'FontSize', 10.5);
title('(b) Symmetrized Mean Error per Axis vs. Absolute Lateral Offset |X|', 'FontSize', 11, 'FontWeight', 'bold');
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_abs_X_m, 'FontSize', 9.5);
ylim([0, max([mae_X_absX; mae_Y_absX; mae_Z_absX; mae_3D_absX]) * 1.15]);

%% =========================================================================
%% FIGURE 5: Symmetrized Error Analysis vs. |X| per Depth Level (Subplots per Depth)
%% =========================================================================
hFig5 = figure('Name', 'Fig5_Error_Analysis_vs_Abs_Lateral_X_per_Depth', 'Units', 'pixels', 'Position', [220, 50, 980, 880]);

nRows = ceil(numDepths / 2);
nCols = 2;

% Pre-calculate MAEs and global max for uniform Y scaling across subplots
maxMAE_global = 0;
mae_by_depth = cell(numDepths, 1);

for k = 1:numDepths
    idxK = (abs(data.y_position - unique_Y_m(k)) < 1e-4);
    maeK = zeros(numAbsXPos, 4);
    for i = 1:numAbsXPos
        idxKI = idxK & (abs(abs_X_m - unique_abs_X_m(i)) < 1e-4);
        if any(idxKI)
            maeK(i, 1) = mean(err_X(idxKI));
            maeK(i, 2) = mean(err_Y(idxKI));
            maeK(i, 3) = mean(err_Z(idxKI));
            maeK(i, 4) = mean(err_3D(idxKI));
        end
    end
    mae_by_depth{k} = maeK;
    maxMAE_global = max(maxMAE_global, max(maeK(:)));
end

for k = 1:numDepths
    subplot(nRows, nCols, k);
    bk = bar(unique_abs_X_m, mae_by_depth{k}, 'grouped');
    bk(1).FaceColor = colorX;
    bk(2).FaceColor = colorY;
    bk(3).FaceColor = colorZ;
    bk(4).FaceColor = color3D;

    title(sprintf('Depth Y = %.2f m', unique_Y_m(k)), 'FontSize', 10, 'FontWeight', 'bold');
    grid on; box on;
    set(gca, 'XTick', unique_abs_X_m, 'FontSize', 8.5);
    ylim([0, maxMAE_global * 1.15]);

    if mod(k, nCols) == 1
        ylabel('MAE (cm)', 'FontSize', 9);
    end
    if k > (nRows - 1) * nCols
        xlabel('Absolute Offset |X| (m)', 'FontSize', 9);
    end

    if k == 1
        legend({'X-axis', 'Y-axis', 'Z-axis', '3D Error'}, ...
            'Location', 'northeast', 'FontSize', 7.5);
    end
end

%% =========================================================================
%% FIGURE 6: Symmetrized 3D Error Boxplots vs. |X| per Depth Level (8 Subplots)
%% =========================================================================
hFig6 = figure('Name', 'Fig6_3D_Error_Boxplots_vs_Abs_Lateral_X_per_Depth', 'Units', 'pixels', 'Position', [240, 50, 980, 880]);

for k = 1:numDepths
    idxK = (abs(data.y_position - unique_Y_m(k)) < 1e-4);
    subplot(nRows, nCols, k);
    boxplot(err_3D(idxK), abs_X_m(idxK), 'Widths', 0.35, 'Symbol', 'r+');

    title(sprintf('Depth Y = %.2f m', unique_Y_m(k)), 'FontSize', 10, 'FontWeight', 'bold');
    grid on; box on;
    ylim([0, max(err_3D) * 1.15]);
    set(gca, 'FontSize', 8.5);

    if mod(k, nCols) == 1
        ylabel('3D Error (cm)', 'FontSize', 9);
    end
    if k > (nRows - 1) * nCols
        xlabel('Absolute Offset |X| (m)', 'FontSize', 9);
    end
end

%% =========================================================================
%% FIGURE 7: 3D Error vs. Absolute Lateral Offset |X| Grouped by Depth Curves
%% =========================================================================
hFig7 = figure('Name', 'Fig7_LinePlot_Error_vs_AbsX_by_Depth', 'Units', 'pixels', 'Position', [250, 150, 850, 520]);

numDepths  = length(unique_Y_m);
numAbsXPos = length(unique_abs_X_m);
mae_curves_inv = zeros(numAbsXPos, numDepths);

for k = 1:numDepths
    idxK = (abs(data.y_position - unique_Y_m(k)) < 1e-4);
    for i = 1:numAbsXPos
        idxKI = idxK & (abs(abs_X_m - unique_abs_X_m(i)) < 1e-4);
        if any(idxKI)
            mae_curves_inv(i, k) = mean(err_3D(idxKI));
        end
    end
end

depthColors  = lines(numDepths);
markersList  = {'o-', 's--', '^:', 'd-.', 'v-', '>-', '<--', 'p:'};
depthLabels  = cell(numDepths, 1);

hold on;
for k = 1:numDepths
    depthLabels{k} = sprintf('Depth Y = %.2f m', unique_Y_m(k));
    mStyle = markersList{mod(k-1, length(markersList)) + 1};
    plot(unique_abs_X_m, mae_curves_inv(:, k), mStyle, ...
        'Color', depthColors(k, :), 'LineWidth', 1.8, ...
        'MarkerSize', 6.5, 'MarkerFaceColor', depthColors(k, :));
end
hold off;

xlabel('Real Absolute Lateral Offset |X| (m)', 'FontSize', 11);
ylabel('3D Positioning Error (cm)', 'FontSize', 11);
title('3D Positioning Error vs. Absolute Lateral Offset |X| Grouped by Depth Y', ...
    'FontSize', 12, 'FontWeight', 'bold');
legend(depthLabels, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_abs_X_m, 'FontSize', 9.5);
xlim([min(unique_abs_X_m) - 0.02, max(unique_abs_X_m) + 0.02]);
ylim([0, max(mae_curves_inv(:)) * 1.15]);

%% =========================================================================
%% FIGURE 8: Cumulative Error Distribution Function (CDF)
%% =========================================================================
hFig8 = figure('Name', 'Fig8_Error_CDF', 'Units', 'pixels', 'Position', [270, 175, 750, 480]);

[f3D, x3D] = ecdf(err_3D);
[fX,  xX]  = ecdf(err_X);
[fY,  xY]  = ecdf(err_Y);
[fZ,  xZ]  = ecdf(err_Z);

plot(x3D, f3D * 100, '-',  'Color', color3D, 'LineWidth', 2.2); hold on;
plot(fX,  fX,  '--'); % dummy for plot line order
delete(gca().Children(1));

plot(xX,  fX  * 100, '--', 'Color', colorX,  'LineWidth', 1.6);
plot(xY,  fY  * 100, '-.', 'Color', colorY,  'LineWidth', 1.6);
plot(xZ,  fZ  * 100, ':',  'Color', colorZ,  'LineWidth', 1.8);

xlabel('Absolute Error Threshold (cm)', 'FontSize', 11);
ylabel('Cumulative Percentage of Samples (%)', 'FontSize', 11);
title('Cumulative Error Distribution Function (CDF)', 'FontSize', 12, 'FontWeight', 'bold');
legend({'3D Total Error', 'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)'}, ...
    'Location', 'southeast', 'FontSize', 10);
grid on; box on;
xlim([0, max(err_3D) * 1.05]);
ylim([0, 102]);
set(gca, 'FontSize', 9.5);


%% =========================================================================
%% Console Summary Table Generation
%% =========================================================================
fprintf('\n=======================================================\n');
fprintf('                 PnP ERROR SUMMARY TABLE               \n');
fprintf('=======================================================\n');
fprintf('Metric          | X (cm)   | Y (cm)   | Z (cm)   | 3D (cm) \n');
fprintf('-------------------------------------------------------\n');
fprintf('MAE (Mean)      | %7.2f  | %7.2f  | %7.2f  | %7.2f\n', mean(err_X), mean(err_Y), mean(err_Z), mean(err_3D));
fprintf('Std Deviation   | %7.2f  | %7.2f  | %7.2f  | %7.2f\n', std(err_X), std(err_Y), std(err_Z), std(err_3D));
fprintf('Max Error       | %7.2f  | %7.2f  | %7.2f  | %7.2f\n', max(err_X), max(err_Y), max(err_Z), max(err_3D));
fprintf('90th Percentile | %7.2f  | %7.2f  | %7.2f  | %7.2f\n', prctile(err_X,90), prctile(err_Y,90), prctile(err_Z,90), prctile(err_3D,90));
fprintf('=======================================================\n\n');