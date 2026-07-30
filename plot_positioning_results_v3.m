%% plot_positioning_results_v3.m
% MATLAB script to process PnP positioning results and generate 4 publication-ready figures:
%
%  Figure 1: 2D Spatial Performance Maps (X-Y and Y-Z Planes)
%  Figure 2: 3D Positioning Error Analysis vs. Depth Y (Boxplot + Grouped MAE Bar Chart)
%  Figure 3: Cumulative Error Distribution Function (3D Error CDF)
%  Figure 4: 3D Positioning Error Analysis vs. Absolute Lateral Offset |X| (Boxplot + Grouped MAE Bar Chart)
%
% Plus prints the PnP ERROR SUMMARY TABLE to the console.
%
% All titles, labels, legends, and console output are formatted in English.

clear; clc; close all;

%% 1. Set File Paths and Import Data
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
csvPath = fullfile(scriptDir, 'resultadosPnP', 'resultados_PnP_Kvideo1.csv');

if ~exist(csvPath, 'file')
    % Fallback search in subdirectories or local folder
    csvFiles = dir(fullfile(scriptDir, '**', 'resultados_PnP*.csv'));
    if ~isempty(csvFiles)
        csvPath = fullfile(csvFiles(1).folder, csvFiles(1).name);
    else
        error('CSV file not found! Please check path: %s', csvPath);
    end
end

opts = detectImportOptions(csvPath);
data = readtable(csvPath, opts);

numRecordings = height(data);

%% 2. Extract Coordinates & Convert to Centimeters (cm)
% World Ground Truth (m -> cm)
X_real = data.x_position * 100; % Lateral (cm)
Y_real = data.y_position * 100; % Depth (cm)
Z_real = data.z_position * 100; % Height (cm)

% PnP Estimated Coordinates (m -> cm)
X_est  = data.pnp_builtin_x * 100; % Lateral X
Y_est  = data.pnp_builtin_z * 100; % Depth Y (PnP Z-axis is World Depth Y)
Z_est  = data.pnp_builtin_y * 100; % Height Z (PnP Y-axis is World Height Z)

% Absolute Errors per axis & 3D Euclidean Error (cm)
err_X  = abs(X_real - X_est);
err_Y  = abs(Y_real - Y_est);
err_Z  = abs(Z_real - Z_est);
err_3D = sqrt(err_X.^2 + err_Y.^2 + err_Z.^2);

%% 3. Publication Color Palette Definition
colorGT  = [0.10, 0.35, 0.80]; % Dark Blue for Ground Truth
colorEst = [0.85, 0.15, 0.15]; % Red for Estimated
colorX   = [0.23, 0.51, 0.96]; % Blue
colorY   = [0.02, 0.71, 0.83]; % Cyan
colorZ   = [0.06, 0.73, 0.51]; % Green
color3D  = [0.85, 0.20, 0.20]; % Dark Red

%% =========================================================================
%% FIGURE 1: 2D Spatial Performance Maps (X-Y and Y-Z Planes)
%% =========================================================================
hFig1 = figure('Name', 'Fig1_Spatial_Maps_XY_YZ', 'Units', 'pixels', 'Position', [100, 50, 850, 800]);

% --- Subplot (a): X x Y Spatial Position Map ---
subplot(2, 1, 1);
hold on;
for i = 1:numRecordings
    plot([X_real(i), X_est(i)], [Y_real(i), Y_est(i)], ':', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.8, 'HandleVisibility', 'off');
end
hGT_XY  = plot(X_real, Y_real, 'o', 'MarkerFaceColor', colorGT, 'MarkerEdgeColor', 'k', 'MarkerSize', 5.5);
hEst_XY = plot(X_est, Y_est, 'x', 'Color', colorEst, 'LineWidth', 1.5, 'MarkerSize', 6.5);

xlabel('Lateral Position X (cm)', 'FontSize', 10.5);
ylabel('Depth Distance Y (cm)', 'FontSize', 10.5);
title('(a) Ground Truth vs. Estimated Positions (X-Y Plane)', 'FontSize', 11, 'FontWeight', 'bold');
legend([hGT_XY, hEst_XY], {'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
xlim([min([X_real; X_est]) - 6, max([X_real; X_est]) + 6]);
ylim([min([Y_real; Y_est]) - 10, max([Y_real; Y_est]) + 15]);
set(gca, 'FontSize', 9.5);

% --- Subplot (b): Y x Z Spatial Position Map ---
subplot(2, 1, 2);
hold on;
for i = 1:numRecordings
    plot([Y_real(i), Y_est(i)], [Z_real(i), Z_est(i)], ':', 'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.8, 'HandleVisibility', 'off');
end
hGT_YZ  = plot(Y_real, Z_real, 'o', 'MarkerFaceColor', colorGT, 'MarkerEdgeColor', 'k', 'MarkerSize', 5.5);
hEst_YZ = plot(Y_est, Z_est, 'x', 'Color', colorEst, 'LineWidth', 1.5, 'MarkerSize', 6.5);

xlabel('Depth Distance Y (cm)', 'FontSize', 10.5);
ylabel('Height Offset Z (cm)', 'FontSize', 10.5);
title('(b) Ground Truth vs. Estimated Positions (Y-Z Plane)', 'FontSize', 11, 'FontWeight', 'bold');
legend([hGT_YZ, hEst_YZ], {'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
xlim([min([Y_real; Y_est]) - 10, max([Y_real; Y_est]) + 15]);
ylim([min([Z_real; Z_est]) - 5, max([Z_real; Z_est]) + 8]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% FIGURE 2: Error Analysis vs. Depth (Y) - Boxplot & Grouped MAE Bar Chart
%% =========================================================================
hFig2 = figure('Name', 'Fig2_Error_Analysis_vs_Depth', 'Units', 'pixels', 'Position', [150, 80, 850, 750]);

unique_Y_m  = sort(unique(data.y_position));
unique_Y_cm = unique_Y_m * 100;
numDepths   = length(unique_Y_m);

% --- Subplot (a): Boxplot of 3D Error per Depth ---
subplot(2, 1, 1);
boxplot(err_3D, Y_real, 'Widths', 0.35, 'Symbol', 'r+');
xlabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
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

b2 = bar(unique_Y_cm, [mae_X_depth, mae_Y_depth, mae_Z_depth, mae_3D_depth], 'grouped');
b2(1).FaceColor = colorX;
b2(2).FaceColor = colorY;
b2(3).FaceColor = colorZ;
b2(4).FaceColor = color3D;

xlabel('Real Depth Distance Y (cm)', 'FontSize', 10.5);
ylabel('Mean Absolute Error (cm)', 'FontSize', 10.5);
title('(b) Mean Error per Axis vs. Depth Distance', 'FontSize', 11, 'FontWeight', 'bold');
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
set(gca, 'XTick', unique_Y_cm, 'FontSize', 9.5);
ylim([0, max([mae_X_depth; mae_Y_depth; mae_Z_depth; mae_3D_depth]) * 1.15]);

%% =========================================================================
%% FIGURE 3: Cumulative Error Distribution Function (3D Error CDF)
%% =========================================================================
hFig3 = figure('Name', 'Fig3_Cumulative_Error_Distribution_3D', 'Units', 'pixels', 'Position', [200, 120, 750, 480]);

[f3D, x3D] = ecdf(err_3D);

% Plot 3D CDF curve
plot(x3D, f3D * 100, '-', 'Color', color3D, 'LineWidth', 2.2); hold on;

% Highlight 50th (Median) and 90th Percentile indicators (matching Summary Table)
p50_val = prctile(err_3D, 50);
p90_val = prctile(err_3D, 90);

% Ensure unique sample points for interp1 to find exact Y-coordinates on the CDF curve
[x_unique, idx] = unique(x3D);
y_unique = f3D(idx) * 100;
y50_val = interp1(x_unique, y_unique, p50_val);
y90_val = interp1(x_unique, y_unique, p90_val);

line([0, p50_val, p50_val], [y50_val, y50_val, 0], 'Color', [0.4 0.4 0.4], 'LineStyle', '--', 'LineWidth', 1.1);
line([0, p90_val, p90_val], [y90_val, y90_val, 0], 'Color', [0.4 0.4 0.4], 'LineStyle', '--', 'LineWidth', 1.1);

plot(p50_val, y50_val, 'ko', 'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerSize', 5);
plot(p90_val, y90_val, 'ko', 'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerSize', 5);

text(p50_val + max(err_3D)*0.02, y50_val - 5, sprintf('Median: %.2f cm', p50_val), 'FontSize', 9.5, 'Color', [0.2 0.2 0.2]);
text(p90_val + max(err_3D)*0.02, y90_val - 5, sprintf('90th Pct: %.2f cm', p90_val), 'FontSize', 9.5, 'Color', [0.2 0.2 0.2]);

xlabel('3D Positioning Error Threshold (cm)', 'FontSize', 11);
ylabel('Cumulative Percentage of Samples (%)', 'FontSize', 11);
title('Cumulative Error Distribution Function (3D Positioning Error)', 'FontSize', 12, 'FontWeight', 'bold');
legend({'3D Positioning Error'}, 'Location', 'southeast', 'FontSize', 10);
grid on; box on;
xlim([0, max(err_3D) * 1.05]);
ylim([0, 102]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% FIGURE 4: Error Analysis vs. Absolute Lateral Offset |X| (Boxplot & Grouped MAE)
%% =========================================================================
hFig4 = figure('Name', 'Fig4_Error_Analysis_vs_Abs_Lateral_X', 'Units', 'pixels', 'Position', [250, 150, 850, 750]);

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

fprintf('Done! All 4 figures generated successfully.\n');
