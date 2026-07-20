% DADOSROI - Processamento e mapeamento das coordenadas das ROIs extraídas dos vídeos.
% Este script varre uma pasta de vídeos gravados, realiza a detecção de ROI
% (automática ou manual) para cada vídeo, calcula as métricas geométricas de distorção
% da ROI e mapeia as chaves do nome do vídeo para posições espaciais (x, y, z)
% e distância euclidiana real 3D, salvando todos os dados em um arquivo CSV.

clc;
clear all;
close all;

% Configura os caminhos relativos à localização do script
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

% Diretório contendo os vídeos
videoDir = '../gravacoes_17_07';


videoFiles = dir(fullfile(videoDir, '*.mp4'));
numVideos = numel(videoFiles);

% Modo de Detecção de ROI:
% 1 = Automático (padrão)
% 2 = Manual (interativo, inicializado com detecção automática)
roiDetectionMode = 1;

% Flag para salvar as imagens da ROI detectada (pasta imagesROI)
% true  = Cria a pasta e salva as imagens de ROI (.jpg) para verificação visual
% false = Desativa o salvamento das imagens de ROI
salvarImagensROI = true;

% ==========================================
% MAPEAR PARA y_position E x_position
% Deixe estes mapeamentos aqui para fácil modificação
% ==========================================
y_map = [
    1.60, 1.596;
    1.2, 1.200;
    1.8, 1.800;
    2.4, 2.400;
    1.90, 1.896;
    2.20, 2.196;
    2.50, 2.496;
    2.80, 2.796;
    3.10, 3.096;
    3.40, 3.396
    ];

x_map = [
    1,  0.60;
    2,  0.315;
    3,  0.0;
    4, -0.315;
    5, -0.60
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

% Pasta de imagens ROI
if salvarImagensROI
    folderName = datestr(now, 'dd_mm_yyyy_HH_MM');
    imagesRoiDir = fullfile(scriptDir, 'imagesROI', folderName);
    imagesRoiNoZoomDir = fullfile(imagesRoiDir, 'noZoom');
    imagesRoiZoomDir = fullfile(imagesRoiDir, 'zoom');
    if ~exist(imagesRoiNoZoomDir, 'dir')
        mkdir(imagesRoiNoZoomDir);
    end
    if ~exist(imagesRoiZoomDir, 'dir')
        mkdir(imagesRoiZoomDir);
    end
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

% Escreve o cabeçalho no CSV
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

    % Extrai metadados do nome do arquivo
    tokens = regexp(vName, '^([\d\.]+)-(\d+)-f(\d+)(?:_dark)?\.mp4$', 'tokens');
    if ~isempty(tokens)
        y_key = str2double(tokens{1}{1});
        x_key = str2double(tokens{1}{2});
        frames = str2double(tokens{1}{3});

        % Busca y_position no mapa correspondente
        y_idx = find(abs(y_map(:, 1) - y_key) < 1e-4, 1);
        if ~isempty(y_idx)
            y_position = y_map(y_idx, 2);
        else
            y_position = NaN;
            warning('y_key %f not found in y_map for video %s', y_key, vName);
        end

        % Busca x_position no mapa correspondente
        x_idx = find(abs(x_map(:, 1) - x_key) < 1e-4, 1);
        if ~isempty(x_idx)
            x_position = x_map(x_idx, 2);
        else
            x_position = NaN;
            warning('x_key %f not found in x_map for video %s', x_key, vName);
        end

        % z_position = -0.13185;
        z_position = 0.10395;

        % Calcula a distância euclidiana 3D
        if ~isnan(x_position) && ~isnan(y_position)
            distance = sqrt(x_position^2 + y_position^2 + z_position^2);
        else
            distance = NaN;
        end
    else
        warning('Filename %s does not match expected pattern dist-pos-f[5|10].mp4', vName);
        y_position = NaN;
        x_position = NaN;
        % z_position = -0.13185;
        z_position = 0.10395;
        distance = NaN;
        frames = NaN;
    end

    try
        % 1) Lê o vídeo
        vidObj = VideoReader(videoFile);
        vidObj.CurrentTime = 0;

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj,true);
        fprintf('Total frames read: %d\n', numFrames);

        % 2) Detecção da ROI
        if roiDetectionMode == 1
            fprintf('Running automatic ROI detection...\n');
            roiPosition = automaticROI_v3(recordedVideo, false);
        elseif roiDetectionMode == 2
            fprintf('Running automatic ROI detection for pre-filling...\n');
            autoRoiPosition = automaticROI_v3(recordedVideo, false);

            fprintf('Opening manual ROI selection with 4-point precision...\n');
            roiPosition = manualQuadROI(recordedVideo, autoRoiPosition);
        else
            error('Invalid roiDetectionMode. Must be 1 (automatic) or 2 (manual).');
        end

        % Vértices
        x_tl = roiPosition(1, 1); y_tl = roiPosition(1, 2);
        x_tr = roiPosition(2, 1); y_tr = roiPosition(2, 2);
        x_br = roiPosition(3, 1); y_br = roiPosition(3, 2);
        x_bl = roiPosition(4, 1); y_bl = roiPosition(4, 2);

        % Alturas (Esquerda e Direita)
        left_height = abs(y_bl - y_tl);
        right_height = abs(y_br - y_tr);

        % Larguras (Superior e Inferior)
        top_width = abs(x_tr - x_tl);
        bottom_width = abs(x_br - x_bl);

        % Diferenças
        height_diff = abs(left_height - right_height);
        width_diff = abs(top_width - bottom_width);

        % Diferenças de coordenadas (para medir inclinação mesmo que alturas/larguras sejam iguais)
        x_coord_diff = abs(x_tl - x_bl);
        y_coord_diff = abs(y_tl - y_tr);

        % Salva um JPEG da ROI silenciosamente (sem exibir a figura na tela)
        if salvarImagensROI
            [~, videoBaseName, ~] = fileparts(vName);
            roiImgPath = fullfile(imagesRoiNoZoomDir, [videoBaseName '.jpg']);
            if exist(roiImgPath, 'file')
                delete(roiImgPath);
            end
            fig = figure('Visible', 'off');
            lastFrame = recordedVideo(:, :, :, end);
            imshow(lastFrame, []);
            hold on;
            if size(roiPosition, 1) == 4 && size(roiPosition, 2) == 2
                x_coords = [roiPosition(:, 1); roiPosition(1, 1)];
                y_coords = [roiPosition(:, 2); roiPosition(1, 2)];
                plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
            else
                rectangle('Position', roiPosition, 'EdgeColor', 'r', 'LineWidth', 2);
            end
            hold off;
            print(fig, roiImgPath, '-djpeg');
            close(fig);
            fprintf('Imagem da ROI salva com sucesso em: %s\n', roiImgPath);

            % --- SALVAR IMAGEM COM ZOOM ---
            roiZoomImgPath = fullfile(imagesRoiZoomDir, [videoBaseName '.jpg']);
            if exist(roiZoomImgPath, 'file')
                delete(roiZoomImgPath);
            end

            % Obter dimensões da imagem
            [img_h, img_w, ~] = size(lastFrame);

            % Calcular limites da ROI
            if size(roiPosition, 1) == 4 && size(roiPosition, 2) == 2
                x_min = min(roiPosition(:, 1));
                x_max = max(roiPosition(:, 1));
                y_min = min(roiPosition(:, 2));
                y_max = max(roiPosition(:, 2));
            else
                x_min = roiPosition(1);
                y_min = roiPosition(2);
                x_max = x_min + roiPosition(3);
                y_max = y_min + roiPosition(4);
            end
            roi_width = x_max - x_min;
            roi_height = y_max - y_min;

            % Adicionar margem de 10%
            margin_x = 0.10 * roi_width;
            margin_y = 0.10 * roi_height;

            x_min_idx = max(1, floor(x_min - margin_x));
            x_max_idx = min(img_w, ceil(x_max + margin_x));
            y_min_idx = max(1, floor(y_min - margin_y));
            y_max_idx = min(img_h, ceil(y_max + margin_y));

            % Recortar a imagem
            croppedFrame = lastFrame(y_min_idx:y_max_idx, x_min_idx:x_max_idx, :);

            % Ajustar coordenadas para a imagem recortada
            roiPositionCropped = roiPosition;
            if size(roiPosition, 1) == 4 && size(roiPosition, 2) == 2
                roiPositionCropped(:, 1) = roiPosition(:, 1) - x_min_idx + 1;
                roiPositionCropped(:, 2) = roiPosition(:, 2) - y_min_idx + 1;
            else
                roiPositionCropped(1) = roiPosition(1) - x_min_idx + 1;
                roiPositionCropped(2) = roiPosition(2) - y_min_idx + 1;
            end

            % Desenhar a ROI com linha mais fina no frame recortado
            figZoom = figure('Visible', 'off');
            imshow(croppedFrame, []);
            hold on;
            if size(roiPositionCropped, 1) == 4 && size(roiPositionCropped, 2) == 2
                x_coords_cropped = [roiPositionCropped(:, 1); roiPositionCropped(1, 1)];
                y_coords_cropped = [roiPositionCropped(:, 2); roiPositionCropped(1, 2)];
                plot(x_coords_cropped, y_coords_cropped, 'r-', 'LineWidth', 0.5);
            else
                rectangle('Position', roiPositionCropped, 'EdgeColor', 'r', 'LineWidth', 0.5);
            end
            hold off;
            print(figZoom, roiZoomImgPath, '-djpeg');
            close(figZoom);
            fprintf('Imagem da ROI com zoom salva com sucesso em: %s\n', roiZoomImgPath);
        end

        % Anexa os resultados no arquivo CSV
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

        % Anexa marcador de erro no CSV se o parser funcionou
        fid = fopen(csvPath, 'a');
        if fid ~= -1
            fprintf(fid, '%s,%.4f,%.4f,%.5f,%.5f,%d,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', ...
                vName, y_position, x_position, z_position, distance, frames);
            fclose(fid);
        end
    end

    % Limpa as variáveis para liberar memória
    clear recordedVideo vidObj roiPosition;
end

fprintf('\nProcessing of all videos completed!\n');
