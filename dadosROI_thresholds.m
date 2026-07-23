% DADOSROI_THRESHOLDS - Teste e comparação de métodos de limiarização na detecção automática de ROI.
% Este script varre a mesma pasta de vídeos gravados do dadosROI.m, realiza a detecção
% automática de ROI testando múltiplos métodos de limiarização (Otsu Padrão, Otsu Modificado,
% Triângulo, Kapur, Adaptativo, Sauvola) e salva um CSV resultados_ROI_<sufixo>.csv para cada método.

clc;
clear all;
close all;

% Configura os caminhos relativos à localização do script
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

% Diretório contendo os vídeos (mesma pasta do dadosROI.m)
videoDir = '../gravacoes_antigas';

videoFiles = dir(fullfile(videoDir, '*.mp4'));
numVideos = numel(videoFiles);

% Flag para salvar as imagens da ROI detectada (pasta imagesROI)
salvarImagensROI = true;

% ==========================================
% MAPEAR PARA y_position, x_position E z_position
% ==========================================
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

x_map = [
    1,  0.350;
    2,  0.175;
    3,  0.0;
    4, -0.175;
    5, -0.350
    ];

z_map = [
    0, -0.114;
    1,  0.126
    ];
% ==========================================

if numVideos == 0
    error('No MP4 videos found in: %s', videoDir);
end

fprintf('Total of %d videos found in: %s\n', numVideos, videoDir);

% Diretório de saída para os CSVs
outputDir = fullfile(scriptDir, 'resultadosROI');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Pasta de imagens ROI (sem zoom/noZoom; subpastas por método)
if salvarImagensROI
    folderName = datestr(now, 'dd_mm_yyyy_HH_MM');
    imagesRoiDir = fullfile(scriptDir, 'imagesROI', ['thresholds_' folderName]);
    if ~exist(imagesRoiDir, 'dir')
        mkdir(imagesRoiDir);
    end
else
    imagesRoiDir = '';
end

% Cabeçalho dos arquivos CSV no formato padrão do dadosROI.m
csvHeader = 'video_name,y_position,x_position,z_position,distance,frames,x_tl,y_tl,x_tr,y_tr,x_br,y_br,x_bl,y_bl,left_height,right_height,top_width,bottom_width,height_difference,width_difference,x_coordinate_difference,y_coordinate_difference';

% Conjunto de arquivos CSV inicializados para este processamento
initializedCsvs = struct();

for i = 1:numVideos
    vName = videoFiles(i).name;
    videoFile = fullfile(videoDir, vName);
    [~, videoBaseName, ~] = fileparts(vName);

    fprintf('\n===========================================================================\n');
    fprintf('Processing video [%d of %d]: %s\n', i, numVideos, vName);
    fprintf('===========================================================================\n');

    % 1) Extrai metadados do nome do arquivo (y_position, x_position, z_position, distance, frames)
    info = parseVideoName(vName);

    y_key = info.y_key;
    x_key = info.x_key;
    z_key = info.z_key;
    frames = info.frames;

    y_position = NaN;
    x_position = NaN;
    z_position = NaN;
    distance = NaN;

    if info.is_valid
        if ~isnan(y_key)
            y_idx = find(abs(y_map(:, 1) - y_key) < 1e-4, 1);
            if ~isempty(y_idx), y_position = y_map(y_idx, 2); end
        end
        if ~isnan(x_key)
            x_idx = find(abs(x_map(:, 1) - x_key) < 1e-4, 1);
            if ~isempty(x_idx), x_position = x_map(x_idx, 2); end
        end
        if ~isnan(z_key)
            z_idx = find(abs(z_map(:, 1) - z_key) < 1e-4, 1);
            if ~isempty(z_idx), z_position = z_map(z_idx, 2); end
        end
        if ~isnan(x_position) && ~isnan(y_position) && ~isnan(z_position)
            distance = sqrt(x_position^2 + y_position^2 + z_position^2);
        end
    end

    try
        % 2) Lê o vídeo
        vidObj = VideoReader(videoFile);
        vidObj.CurrentTime = 0;

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj, true);
        fprintf('Total frames read: %d\n', numFrames);

        % 3) Detecção da ROI testando todos os limiares
        fprintf('Running multi-threshold automatic ROI detection...\n');
        [~, resultsStruct] = automaticROI_thresholds(recordedVideo, false, imagesRoiDir, videoBaseName);

        % 4) Para cada método, salva o resultado em seu respectivo arquivo CSV resultados_ROI_<sufixo>.csv
        methodFields = fieldnames(resultsStruct);
        for k = 1:numel(methodFields)
            mField = methodFields{k};
            mRes = resultsStruct.(mField);

            methodName = mRes.name;
            success = mRes.success;
            roiPos = mRes.roiPosition;

            % Define o caminho do CSV específico para este método (ex: resultados_ROI_Otsu_Padrao.csv)
            methodCsvPath = fullfile(outputDir, sprintf('resultados_ROI_%s.csv', mField));

            % Inicializa o arquivo (escreve o cabeçalho) na primeira ocorrência
            if ~isfield(initializedCsvs, mField)
                fid = fopen(methodCsvPath, 'w');
                if fid ~= -1
                    fprintf(fid, '%s\n', csvHeader);
                    fclose(fid);
                end
                initializedCsvs.(mField) = true;
            end

            if success && ~any(isnan(roiPos(:)))
                x_tl = roiPos(1, 1); y_tl = roiPos(1, 2);
                x_tr = roiPos(2, 1); y_tr = roiPos(2, 2);
                x_br = roiPos(3, 1); y_br = roiPos(3, 2);
                x_bl = roiPos(4, 1); y_bl = roiPos(4, 2);

                left_height = abs(y_bl - y_tl);
                right_height = abs(y_br - y_tr);
                top_width = abs(x_tr - x_tl);
                bottom_width = abs(x_br - x_bl);

                height_diff = abs(left_height - right_height);
                width_diff = abs(top_width - bottom_width);
                x_coord_diff = abs(x_tl - x_bl);
                y_coord_diff = abs(y_tl - y_tr);
            else
                x_tl=NaN; y_tl=NaN; x_tr=NaN; y_tr=NaN;
                x_br=NaN; y_br=NaN; x_bl=NaN; y_bl=NaN;
                left_height=NaN; right_height=NaN; top_width=NaN; bottom_width=NaN;
                height_diff=NaN; width_diff=NaN; x_coord_diff=NaN; y_coord_diff=NaN;
            end

            % Escreve a linha no CSV específico do método no formato padrão do dadosROI.m
            fid = fopen(methodCsvPath, 'a');
            if fid ~= -1
                fprintf(fid, '%s,%.4f,%.4f,%.5f,%.5f,%.0f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
                    vName, y_position, x_position, z_position, distance, frames, ...
                    x_tl, y_tl, x_tr, y_tr, x_br, y_br, x_bl, y_bl, ...
                    left_height, right_height, top_width, bottom_width, ...
                    height_diff, width_diff, ...
                    x_coord_diff, y_coord_diff);
                fclose(fid);
            end
        end

        fprintf('Resultados de todos os métodos salvos nos CSVs individuais para o vídeo %s.\n', vName);

    catch ME
        fprintf('ERROR processing video %s:\n%s\n', vName, ME.message);
    end

    % Limpa memória
    clear recordedVideo vidObj;
end

fprintf('\nProcessamento de todos os vídeos finalizado com sucesso!\n');
