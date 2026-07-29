%% plot_positioning_results.m
% MATLAB script to process PnP positioning results and generate publication-quality figures.
% Reads data from 'resultadosPnP/resultados_PnP.csv' and plots:
%  1. fig:X_Y_Z_SC2P - Coordinates per recording (X, Y, Z) with Real (solid) vs Estimated (dashed).
%  2. MAE vs Depth - Mean Absolute Error per axis vs. Real Depth (Y).
%  3. MAE vs Lateral Position - Mean Absolute Error per axis vs. Real Lateral Position (X).
%  4. MAE vs Height - Mean Absolute Error per axis vs. Real Height (Z).
%  5. fig:combined - 2D Spatial Position Maps stacked vertically (X x Y and Y x Z planes).
%  6. 3D Error vs Real Distance - Mean 3D Error vs. Real Distance (m).
%  7. 3D Error vs Signed Lateral Angle - Mean 3D Error vs. Real Signed Lateral Angle (deg).
%  8. 3D Error vs Absolute Lateral Angle - Mean 3D Error vs. Real Absolute Lateral Angle Magnitude (deg).
%  9. 2D Spatial Error Heatmap - 2D heatmap/contour plot of 3D MAE on ground-truth X-Y plane.
%
% All titles, labels, and legends are formatted in English.

clear; clc; close all;

%% 1. Set File Paths and Import Data
scriptDir = fileparts(mfilename('fullpath'));
csvPath   = 'resultadosPnP\resultados_PnP_1.csv';

if ~exist(csvPath, 'file')
    error('CSV file not found at: %s', csvPath);
end

opts = detectImportOptions(csvPath);
data = readtable(csvPath, opts);

numRecordings = height(data);
recordingIdx  = (1:numRecordings)';

%% 2. Extract Coordinates and Convert to Centimeters (cm)
% World Coordinate System:
%  X_real: Lateral position (m) -> cm
%  Y_real: Depth position (m)   -> cm
%  Z_real: Height position (m)  -> cm
%
% Camera PnP Estimates:
%  pnp_builtin_x -> Est Lateral X (m)
%  pnp_builtin_y -> Est Height Z (m)
%  pnp_builtin_z -> Est Depth Y (m)

X_real = data.x_position * 100; % cm
Y_real = data.y_position * 100; % cm
Z_real = data.z_position * 100; % cm

X_est  = data.pnp_builtin_x * 100; % cm
Y_est  = data.pnp_builtin_z * 100; % cm (PnP Z-axis is world depth Y)
Z_est  = data.pnp_builtin_y * 100; % cm (PnP Y-axis is world height Z)

% Absolute Errors per axis (cm)
err_X  = abs(X_real - X_est);
err_Y  = abs(Y_real - Y_est);
err_Z  = abs(Z_real - Z_est);
err_3D = sqrt(err_X.^2 + err_Y.^2 + err_Z.^2);

%% 3. Color Palette Definition
colorX  = [0.23, 0.51, 0.96]; % Blue
colorY  = [0.02, 0.71, 0.83]; % Cyan
colorZ  = [0.06, 0.73, 0.51]; % Green
color3D = [0.94, 0.27, 0.27]; % Red

colorGT  = [0.10, 0.35, 0.80]; % Dark Blue for Ground Truth
colorEst = [0.85, 0.15, 0.15]; % Red for Estimated

%% =========================================================================
%% Figure 1: fig:X_Y_Z_SC2P (Coordinates per Recording)
%% =========================================================================
hFig1 = figure('Name', 'fig:X_Y_Z_SC2P', 'Units', 'pixels', 'Position', [100, 80, 850, 720]);

% --- Subplot 1: X-axis (Lateral) ---
subplot(3, 1, 1);
plot(recordingIdx, X_real, 'S-', 'Color', colorGT, 'LineWidth', 1.5, 'MarkerSize', 4); hold on;
plot(recordingIdx, X_est, '--', 'Color', colorEst, 'LineWidth', 1.5);
title('X-axis (Lateral Position)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('X Coordinate (cm)', 'FontSize', 10);
legend({'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9);
grid on; box on;
xlim([1, numRecordings]);
minX = min([X_real; X_est]); maxX = max([X_real; X_est]);
ylim([minX - 8, maxX + 8]);
set(gca, 'XTick', 1:5:numRecordings, 'FontSize', 9);

% --- Subplot 2: Y-axis (Depth) ---
subplot(3, 1, 2);
plot(recordingIdx, Y_real, 'S-', 'Color', colorGT, 'LineWidth', 1.5, 'MarkerSize', 4); hold on;
plot(recordingIdx, Y_est, '--', 'Color', colorEst, 'LineWidth', 1.5);
title('Y-axis (Depth Distance)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Y Coordinate (cm)', 'FontSize', 10);
legend({'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9);
grid on; box on;
xlim([1, numRecordings]);
minY = min([Y_real; Y_est]); maxY = max([Y_real; Y_est]);
ylim([minY - 10, maxY + 15]);
set(gca, 'XTick', 1:5:numRecordings, 'FontSize', 9);

% --- Subplot 3: Z-axis (Height) ---
subplot(3, 1, 3);
plot(recordingIdx, Z_real, 'S-', 'Color', colorGT, 'LineWidth', 1.5, 'MarkerSize', 4); hold on;
plot(recordingIdx, Z_est, '--', 'Color', colorEst, 'LineWidth', 1.5);
title('Z-axis (Height Offset)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Recording Index (i)', 'FontSize', 10);
ylabel('Z Coordinate (cm)', 'FontSize', 10);
legend({'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9);
grid on; box on;
xlim([1, numRecordings]);
minZ = min([Z_real; Z_est]); maxZ = max([Z_real; Z_est]);
ylim([minZ - 5, maxZ + 8]);
set(gca, 'XTick', 1:5:numRecordings, 'FontSize', 9);

% Main title removed to prevent clipping in PDF and redundancy with LaTeX caption:
% sgtitle('Real vs. Estimated Coordinates per Recording (SC2P)', 'FontSize', 13, 'FontWeight', 'bold');

%% =========================================================================
%% Figure 2: Mean Absolute Error per Axis vs. Depth (Y)
%% =========================================================================
unique_Y_m = sort(unique(data.y_position));
numDepths  = length(unique_Y_m);

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

hFig2 = figure('Name', 'MAE vs Depth', 'Units', 'pixels', 'Position', [150, 150, 800, 450]);
b2 = bar(unique_Y_m, [mae_X_depth, mae_Y_depth, mae_Z_depth, mae_3D_depth], 'grouped');
b2(1).FaceColor = colorX;
b2(2).FaceColor = colorY;
b2(3).FaceColor = colorZ;
b2(4).FaceColor = color3D;

xlabel('Real Depth Distance Y (m)', 'FontSize', 11);
ylabel('Mean Absolute Error (cm)', 'FontSize', 11);
% Main title removed to prevent clipping in PDF and redundancy with LaTeX caption:
% title('Mean Error per Axis vs. Depth Distance', 'FontSize', 12, 'FontWeight', 'bold');
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Positioning Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 10);
grid on; box on;
maxVal2 = max([mae_X_depth; mae_Y_depth; mae_Z_depth; mae_3D_depth]);
ylim([0, maxVal2 * 1.15]);
set(gca, 'XTick', unique_Y_m, 'FontSize', 9.5);

%% =========================================================================
%% Figure 3: Mean Absolute Error per Axis vs. Lateral Position (X)
%% =========================================================================
unique_X_m = sort(unique(data.x_position));
numLaterals = length(unique_X_m);

mae_X_lat  = zeros(numLaterals, 1);
mae_Y_lat  = zeros(numLaterals, 1);
mae_Z_lat  = zeros(numLaterals, 1);
mae_3D_lat = zeros(numLaterals, 1);

for i = 1:numLaterals
    idx = (abs(data.x_position - unique_X_m(i)) < 1e-4);
    mae_X_lat(i)  = mean(err_X(idx));
    mae_Y_lat(i)  = mean(err_Y(idx));
    mae_Z_lat(i)  = mean(err_Z(idx));
    mae_3D_lat(i) = mean(err_3D(idx));
end

hFig3 = figure('Name', 'MAE vs Lateral Position', 'Units', 'pixels', 'Position', [200, 200, 800, 450]);
b3 = bar(unique_X_m, [mae_X_lat, mae_Y_lat, mae_Z_lat, mae_3D_lat], 'grouped');
b3(1).FaceColor = colorX;
b3(2).FaceColor = colorY;
b3(3).FaceColor = colorZ;
b3(4).FaceColor = color3D;

xlabel('Real Lateral Position X (m)', 'FontSize', 11);
ylabel('Mean Absolute Error (cm)', 'FontSize', 11);
% Main title removed to prevent clipping in PDF and redundancy with LaTeX caption:
% title('Mean Error per Axis vs. Lateral Position', 'FontSize', 12, 'FontWeight', 'bold');
% Placed legend outside or top-center where bars are low so it never covers any bar
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Positioning Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 10);
grid on; box on;
maxVal3 = max([mae_X_lat; mae_Y_lat; mae_Z_lat; mae_3D_lat]);
ylim([0, maxVal3 * 1.15]);
set(gca, 'XTick', unique_X_m, 'FontSize', 9.5);

%% =========================================================================
%% Figure 4: Mean Absolute Error per Axis vs. Height (Z)
%% =========================================================================
unique_Z_m = sort(unique(data.z_position));
numHeights = length(unique_Z_m);

mae_X_hgt  = zeros(numHeights, 1);
mae_Y_hgt  = zeros(numHeights, 1);
mae_Z_hgt  = zeros(numHeights, 1);
mae_3D_hgt = zeros(numHeights, 1);

for i = 1:numHeights
    idx = (abs(data.z_position - unique_Z_m(i)) < 1e-4);
    mae_X_hgt(i)  = mean(err_X(idx));
    mae_Y_hgt(i)  = mean(err_Y(idx));
    mae_Z_hgt(i)  = mean(err_Z(idx));
    mae_3D_hgt(i) = mean(err_3D(idx));
end

hFig4 = figure('Name', 'MAE vs Height', 'Units', 'pixels', 'Position', [250, 250, 750, 450]);
b4 = bar(unique_Z_m, [mae_X_hgt, mae_Y_hgt, mae_Z_hgt, mae_3D_hgt], 'grouped');
b4(1).FaceColor = colorX;
b4(2).FaceColor = colorY;
b4(3).FaceColor = colorZ;
b4(4).FaceColor = color3D;

xlabel('Real Height Z (m)', 'FontSize', 11);
ylabel('Mean Absolute Error (cm)', 'FontSize', 11);
% Main title removed to prevent clipping in PDF and redundancy with LaTeX caption:
% title('Mean Error per Axis vs. Height Offset', 'FontSize', 12, 'FontWeight', 'bold');
legend({'X-axis (Lateral)', 'Y-axis (Depth)', 'Z-axis (Height)', '3D Positioning Error'}, ...
    'Location', 'northeastoutside', 'FontSize', 10);
grid on; box on;
maxVal4 = max([mae_X_hgt; mae_Y_hgt; mae_Z_hgt; mae_3D_hgt]);
ylim([0, maxVal4 * 1.15]);
set(gca, 'XTick', unique_Z_m, 'FontSize', 9.5);

%% =========================================================================
%% Figure 5: fig:combined (2D Spatial Maps stacked vertically)
%% =========================================================================
% Stacked vertically (one below the other) with auto-scaling padding and clean legends
hFig5 = figure('Name', 'fig:combined', 'Units', 'pixels', 'Position', [100, 50, 850, 800]);

% Calculate Auto-Scale Boundaries with 10% padding
minX = min([X_real; X_est]); maxX = max([X_real; X_est]);
minY = min([Y_real; Y_est]); maxY = max([Y_real; Y_est]);
minZ = min([Z_real; Z_est]); maxZ = max([Z_real; Z_est]);

padX = (maxX - minX) * 0.08;
padY = (maxY - minY) * 0.08;
padZ = (maxZ - minZ) * 0.15;

% --- Subplot (a): X x Y Plane (Lateral vs Depth) ---
subplot(2, 1, 1);
hold on;
for i = 1:numRecordings
    plot([X_real(i), X_est(i)], [Y_real(i), Y_est(i)], ':', 'Color', [0.65, 0.65, 0.65], 'LineWidth', 0.9, 'HandleVisibility', 'off');
end
hGT_XY  = plot(X_real, Y_real, 'o', 'MarkerFaceColor', colorGT, 'MarkerEdgeColor', 'k', 'MarkerSize', 5.5);
hEst_XY = plot(X_est, Y_est, 'x', 'Color', colorEst, 'LineWidth', 1.5, 'MarkerSize', 6.5);

xlabel('Lateral Position X (cm)', 'FontSize', 11);
ylabel('Depth Distance Y (cm)', 'FontSize', 11);
title('(a) X \times Y Plane Map', 'FontSize', 12, 'FontWeight', 'bold');
legend([hGT_XY, hEst_XY], {'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
xlim([minX - padX, maxX + padX]);
ylim([minY - padY, maxY + padY]);

% --- Subplot (b): Y x Z Plane (Depth vs Height) ---
subplot(2, 1, 2);
hold on;
for i = 1:numRecordings
    plot([Y_real(i), Y_est(i)], [Z_real(i), Z_est(i)], ':', 'Color', [0.65, 0.65, 0.65], 'LineWidth', 0.9, 'HandleVisibility', 'off');
end
hGT_YZ  = plot(Y_real, Z_real, 'o', 'MarkerFaceColor', colorGT, 'MarkerEdgeColor', 'k', 'MarkerSize', 5.5);
hEst_YZ = plot(Y_est, Z_est, 'x', 'Color', colorEst, 'LineWidth', 1.5, 'MarkerSize', 6.5);

xlabel('Depth Distance Y (cm)', 'FontSize', 11);
ylabel('Height Offset Z (cm)', 'FontSize', 11);
title('(b) Y \times Z Plane Map', 'FontSize', 12, 'FontWeight', 'bold');
legend([hGT_YZ, hEst_YZ], {'Ground Truth', 'Estimated'}, 'Location', 'northeastoutside', 'FontSize', 9.5);
grid on; box on;
xlim([minY - padY, maxY + padY]);
ylim([minZ - padZ, maxZ + padZ]);

% Main title removed to prevent clipping in PDF and redundancy with LaTeX caption:
% sgtitle('Estimated 2D Spatial Position Maps (S2CP)', 'FontSize', 13, 'FontWeight', 'bold');

%% =========================================================================
%% Figure 6: Mean 3D Positioning Error vs. Real Distance
%% =========================================================================
dist_real   = data.distance; % m
unique_dist = sort(unique(dist_real));
numDists    = length(unique_dist);

mae_3D_dist = zeros(numDists, 1);
for i = 1:numDists
    idx = (abs(dist_real - unique_dist(i)) < 1e-4);
    mae_3D_dist(i) = mean(err_3D(idx));
end

% Smooth trend line generation
x_dist_fine   = linspace(min(unique_dist), max(unique_dist), 200);
y_dist_smooth = interp1(unique_dist, smoothdata(mae_3D_dist, 'gaussian', 5), x_dist_fine, 'pchip');

hFig6 = figure('Name', '3D Error vs Real Distance', 'Units', 'pixels', 'Position', [300, 150, 750, 450]);
plot(unique_dist, mae_3D_dist, 'o', 'Color', [0.55, 0.55, 0.55], 'MarkerFaceColor', [0.8, 0.8, 0.8], 'MarkerSize', 5.5); hold on;
plot(x_dist_fine, y_dist_smooth, '-', 'Color', color3D, 'LineWidth', 2.2);
xlabel('Real Distance (m)', 'FontSize', 11);
ylabel('Mean 3D Positioning Error (cm)', 'FontSize', 11);
legend({'Average Points', 'Smoothed Trend'}, 'Location', 'northeast', 'FontSize', 9.5);
grid on; box on;
maxVal6 = max([mae_3D_dist; y_dist_smooth']);
ylim([0, maxVal6 * 1.15]);
xlim([min(unique_dist) - 0.05, max(unique_dist) + 0.05]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% Figure 7: Mean 3D Positioning Error vs. Signed Real Lateral Angle
%% =========================================================================
% Real lateral angle considering only X (lateral) and Y (depth) axes in 2D
lat_angle_real = atan2d(data.x_position, data.y_position); % degrees, signed
unique_angle   = sort(unique(lat_angle_real));
numAngles      = length(unique_angle);

mae_3D_angle = zeros(numAngles, 1);
for i = 1:numAngles
    idx = (abs(lat_angle_real - unique_angle(i)) < 1e-4);
    mae_3D_angle(i) = mean(err_3D(idx));
end

% Smooth trend line generation
x_ang_fine   = linspace(min(unique_angle), max(unique_angle), 200);
y_ang_smooth = interp1(unique_angle, smoothdata(mae_3D_angle, 'gaussian', 3), x_ang_fine, 'pchip');

hFig7 = figure('Name', '3D Error vs Signed Lateral Angle', 'Units', 'pixels', 'Position', [350, 180, 750, 450]);
plot(unique_angle, mae_3D_angle, 's', 'Color', [0.55, 0.55, 0.55], 'MarkerFaceColor', [0.8, 0.8, 0.8], 'MarkerSize', 5.5); hold on;
plot(x_ang_fine, y_ang_smooth, '-', 'Color', color3D, 'LineWidth', 2.2);
xlabel('Real Lateral Angle (\circ)', 'FontSize', 11);
ylabel('Mean 3D Positioning Error (cm)', 'FontSize', 11);
legend({'Average Points', 'Smoothed Trend'}, 'Location', 'northeast', 'FontSize', 9.5);
grid on; box on;
maxVal7 = max([mae_3D_angle; y_ang_smooth']);
ylim([0, maxVal7 * 1.15]);
xlim([min(unique_angle) - 2, max(unique_angle) + 2]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% Figure 8: Mean 3D Positioning Error vs. Absolute Real Lateral Angle
%% =========================================================================
% Absolute magnitude of real lateral angle
abs_lat_angle_real = abs(lat_angle_real); % degrees magnitude
unique_abs_angle   = sort(unique(abs_lat_angle_real));
numAbsAngles       = length(unique_abs_angle);

mae_3D_abs_angle = zeros(numAbsAngles, 1);
for i = 1:numAbsAngles
    idx = (abs(abs_lat_angle_real - unique_abs_angle(i)) < 1e-4);
    mae_3D_abs_angle(i) = mean(err_3D(idx));
end

% Smooth trend line generation
x_abs_ang_fine   = linspace(min(unique_abs_angle), max(unique_abs_angle), 200);
y_abs_ang_smooth = interp1(unique_abs_angle, smoothdata(mae_3D_abs_angle, 'gaussian', 3), x_abs_ang_fine, 'pchip');

hFig8 = figure('Name', '3D Error vs Absolute Lateral Angle', 'Units', 'pixels', 'Position', [400, 210, 750, 450]);
plot(unique_abs_angle, mae_3D_abs_angle, '^', 'Color', [0.55, 0.55, 0.55], 'MarkerFaceColor', [0.8, 0.8, 0.8], 'MarkerSize', 5.5); hold on;
plot(x_abs_ang_fine, y_abs_ang_smooth, '-', 'Color', color3D, 'LineWidth', 2.2);
xlabel('Absolute Real Lateral Angle |\theta| (\circ)', 'FontSize', 11);
ylabel('Mean 3D Positioning Error (cm)', 'FontSize', 11);
legend({'Average Points', 'Smoothed Trend'}, 'Location', 'northeast', 'FontSize', 9.5);
grid on; box on;
maxVal8 = max([mae_3D_abs_angle; y_abs_ang_smooth']);
ylim([0, maxVal8 * 1.15]);
xlim([min(unique_abs_angle) - 1, max(unique_abs_angle) + 1]);
set(gca, 'FontSize', 9.5);

%% =========================================================================
%% Figure 9: 2D Spatial Positioning Error Heatmap (Contour Plot)
%% =========================================================================
% Grid 2D of ground-truth plane: Real Lateral X (horizontal) vs Real Depth Y (vertical).
% Color represents Mean 3D Positioning Error (MAE 3D) in cm.
% Visualizes spatial distribution of error, asymmetry at FOV edges, and distance degradation.

[gridX, gridY] = meshgrid(unique_X_m, unique_Y_m);
gridError_3D   = zeros(length(unique_Y_m), length(unique_X_m));

for i = 1:length(unique_Y_m)
    for j = 1:length(unique_X_m)
        idx = (abs(data.y_position - unique_Y_m(i)) < 1e-4) & ...
            (abs(data.x_position - unique_X_m(j)) < 1e-4);
        if any(idx)
            gridError_3D(i, j) = mean(err_3D(idx));
        else
            gridError_3D(i, j) = NaN;
        end
    end
end

% Interpolate onto a fine 2D mesh for smooth contour visualization
[X_fine, Y_fine] = meshgrid(linspace(min(unique_X_m), max(unique_X_m), 200), ...
    linspace(min(unique_Y_m), max(unique_Y_m), 200));
Z_fine = interp2(gridX, gridY, gridError_3D, X_fine, Y_fine, 'cubic');

hFig9 = figure('Name', '2D Spatial Error Heatmap', 'Units', 'pixels', 'Position', [450, 240, 750, 550]);

% Smooth filled contour map (Heatmap)
[~, hC] = contourf(X_fine, Y_fine, Z_fine, 25, 'LineStyle', 'none');
hold on;

% Overlay subtle contour lines for precise level reading
contour(X_fine, Y_fine, Z_fine, 10, 'LineColor', [0.25, 0.25, 0.25], 'LineWidth', 0.5);

% Overlay the actual ground-truth grid sample points
hPts = plot(gridX(:), gridY(:), 'ko', 'MarkerFaceColor', [0.95, 0.95, 0.95], ...
    'MarkerEdgeColor', 'k', 'MarkerSize', 5.5, 'DisplayName', 'Sampling Locations');

xlabel('Real Lateral Position X (m)', 'FontSize', 11);
ylabel('Real Depth Distance Y (m)', 'FontSize', 11);

% Apply colormap and colorbar
c = colorbar;
c.Label.String = 'Mean 3D Positioning Error (cm)';
c.Label.FontSize = 10.5;
colormap(turbo); % Rich, high-contrast, perceptually continuous colormap

grid on; box on;
xlim([min(unique_X_m) - 0.03, max(unique_X_m) + 0.03]);
ylim([min(unique_Y_m) - 0.05, max(unique_Y_m) + 0.05]);
legend(hPts, {'Sampling Locations'}, 'Location', 'northeast', 'FontSize', 9.5);
set(gca, 'FontSize', 9.5);

fprintf('Done! All figures generated and opened.\n');



