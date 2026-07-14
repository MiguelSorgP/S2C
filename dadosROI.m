clc;
clear all;
close all;

% Setup paths relative to script location
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

% Directory containing videos
% videoDir = fullfile(scriptDir, 'gravacoes_15_06');
videoDir = 'G:\Meu Drive\Mestrado\ArtigosEmAndamento\IEEEacess2026\Dados_Gravacoes_15_06\dadosLuzesApagadas\gravacoes_07_07';

videoFiles = dir(fullfile(videoDir, '*.mp4'));
numVideos = numel(videoFiles);

% ==========================================
% MAP FOR y_position AND x_position
% Leave these maps here for easy modification
% ==========================================
y_map = [
    1.60, 1.596;
    1.90, 1.896;
    2.20, 2.196;
    2.50, 2.496;
    2.80, 2.796;
    3.10, 3.096;
    3.40, 3.396
    ];

x_map = [
    1,  0.63;
    2,  0.315;
    3,  0.0;
    4, -0.315;
    5, -0.63
    ];
% ==========================================

if numVideos == 0
    error('No MP4 videos found in: %s', videoDir);
end

fprintf('Total of %d videos found in: %s\n', numVideos, videoDir);

% Output folder (creates it if it does not exist)
outputDir = fullfile(scriptDir, 'resultadosROI');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Determine unique CSV filename to avoid overwriting
baseName = 'resultados_ROI';
ext = '.csv';
csvPath = fullfile(outputDir, [baseName, ext]);
counter = 1;
while exist(csvPath, 'file')
    csvPath = fullfile(outputDir, sprintf('%s_%d%s', baseName, counter, ext));
    counter = counter + 1;
end
csvHeader = 'video_name,y_position,x_position,z_position,distance,frames,x_tl,y_tl,x_tr,y_tr,x_br,y_br,x_bl,y_bl,left_height,right_height,top_width,bottom_width,height_difference,width_difference,x_coordinate_difference,y_coordinate_difference';

% Write header to CSV
fid = fopen(csvPath, 'w');
if fid == -1
    error('Could not create output CSV file: %s', csvPath);
end
fprintf(fid, '%s\n', csvHeader);
fclose(fid);

for i = 1:numVideos
    vName = videoFiles(i).name;
    videoFile = fullfile(videoDir, vName);

    fprintf('\n===========================================================================\n');
    fprintf('Processing video [%d of %d]: %s\n', i, numVideos, vName);
    fprintf('===========================================================================\n');

    % Parse metadata from filename
    tokens = regexp(vName, '^([\d\.]+)-(\d+)-f(\d+)(?:_dark)?\.mp4$', 'tokens');
    if ~isempty(tokens)
        y_key = str2double(tokens{1}{1});
        x_key = str2double(tokens{1}{2});
        frames = str2double(tokens{1}{3});

        % Lookup y_position
        y_idx = find(abs(y_map(:, 1) - y_key) < 1e-4, 1);
        if ~isempty(y_idx)
            y_position = y_map(y_idx, 2);
        else
            y_position = NaN;
            warning('y_key %f not found in y_map for video %s', y_key, vName);
        end

        % Lookup x_position
        x_idx = find(abs(x_map(:, 1) - x_key) < 1e-4, 1);
        if ~isempty(x_idx)
            x_position = x_map(x_idx, 2);
        else
            x_position = NaN;
            warning('x_key %f not found in x_map for video %s', x_key, vName);
        end

        z_position = -0.13185;

        % Calculate distance
        if ~isnan(x_position) && ~isnan(y_position)
            distance = sqrt(x_position^2 + y_position^2 + z_position^2);
        else
            distance = NaN;
        end
    else
        warning('Filename %s does not match expected pattern dist-pos-f[5|10].mp4', vName);
        y_position = NaN;
        x_position = NaN;
        z_position = -0.13185;
        distance = NaN;
        frames = NaN;
    end

    try
        % 1) Read video
        vidObj = VideoReader(videoFile);
        vidObj.CurrentTime = 0;

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj,true);
        fprintf('Total frames read: %d\n', numFrames);

        % 2) Automatic ROI Detection
        fprintf('Running automatic ROI detection...\n');
        roiPosition = automaticROI_v2(recordedVideo, false);

        % Vertices
        x_tl = roiPosition(1, 1); y_tl = roiPosition(1, 2);
        x_tr = roiPosition(2, 1); y_tr = roiPosition(2, 2);
        x_br = roiPosition(3, 1); y_br = roiPosition(3, 2);
        x_bl = roiPosition(4, 1); y_bl = roiPosition(4, 2);

        % Heights (Left and Right)
        left_height = abs(y_bl - y_tl);
        right_height = abs(y_br - y_tr);

        % Widths (Top and Bottom)
        top_width = abs(x_tr - x_tl);
        bottom_width = abs(x_br - x_bl);

        % Differences
        height_diff = abs(left_height - right_height);
        width_diff = abs(top_width - bottom_width);

        % Coordinate differences (to measure skew/tilt even if height/width differences are 0)
        x_coord_diff = abs(x_tl - x_bl);
        y_coord_diff = abs(y_tl - y_tr);

        % Append results to CSV
        fid = fopen(csvPath, 'a');
        if fid ~= -1
            fprintf(fid, '%s,%.4f,%.4f,%.5f,%.5f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
                vName, y_position, x_position, z_position, distance, frames, ...
                x_tl, y_tl, x_tr, y_tr, x_br, y_br, x_bl, y_bl, ...
                left_height, right_height, top_width, bottom_width, ...
                height_diff, width_diff, ...
                x_coord_diff, y_coord_diff);
            fclose(fid);
            fprintf('Successfully saved results for %s\n', vName);
        else
            warning('Could not open CSV file to append results.');
        end

    catch ME
        fprintf('ERROR processing video %s:\n%s\n', vName, ME.message);

        % Append error placeholder to CSV if parser succeeded
        fid = fopen(csvPath, 'a');
        if fid ~= -1
            fprintf(fid, '%s,%.4f,%.4f,%.5f,%.5f,%d,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', ...
                vName, y_position, x_position, z_position, distance, frames);
            fclose(fid);
        end
    end

    % Clear variables to free memory
    clear recordedVideo vidObj roiPosition;
end

fprintf('\nProcessing of all videos completed!\n');
