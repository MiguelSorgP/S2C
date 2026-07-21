% DADOSROI_COMPARE - Processamento e comparação dos métodos de detecção de ROI: automaticROI_v2 e automaticROI_v3.
% Este script varre uma pasta de vídeos gravados, realiza a detecção de ROI
% usando tanto automaticROI_v2 quanto automaticROI_v3 para cada vídeo, calcula as métricas
% geométricas de distorção da ROI e salva os resultados em dois arquivos CSV separados
% (resultados_ROI_v2.csv e resultados_ROI_v3.csv).
% Além disso, salva imagens individuais em pastas _v2 e _v3 e imagens lado a lado na pasta _compare.

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
videoDir = '../gravacoes_20_07';

videoFiles = dir(fullfile(videoDir, '*.mp4'));
numVideos = numel(videoFiles);

% Flag para salvar as imagens da ROI detectada (pasta imagesROI)
% true  = Cria as pastas e salva as imagens de ROI (.jpg) para verificação visual e comparação
% false = Desativa o salvamento das imagens de ROI
salvarImagensROI = true;

% ==========================================
% MAPEAR PARA y_position, x_position E z_position
% Deixe estes mapeamentos aqui para fácil modificação
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

% Configuração das pastas de imagens ROI
if salvarImagensROI
    folderTimestamp = datestr(now, 'dd_mm_yyyy_HH_MM');
    
    % Pasta para automaticROI_v2
    imagesRoiDir_v2 = fullfile(scriptDir, 'imagesROI', [folderTimestamp '_v2']);
    imagesRoiNoZoomDir_v2 = fullfile(imagesRoiDir_v2, 'noZoom');
    imagesRoiZoomDir_v2 = fullfile(imagesRoiDir_v2, 'zoom');
    if ~exist(imagesRoiNoZoomDir_v2, 'dir'), mkdir(imagesRoiNoZoomDir_v2); end
    if ~exist(imagesRoiZoomDir_v2, 'dir'), mkdir(imagesRoiZoomDir_v2); end

    % Pasta para automaticROI_v3
    imagesRoiDir_v3 = fullfile(scriptDir, 'imagesROI', [folderTimestamp '_v3']);
    imagesRoiNoZoomDir_v3 = fullfile(imagesRoiDir_v3, 'noZoom');
    imagesRoiZoomDir_v3 = fullfile(imagesRoiDir_v3, 'zoom');
    if ~exist(imagesRoiNoZoomDir_v3, 'dir'), mkdir(imagesRoiNoZoomDir_v3); end
    if ~exist(imagesRoiZoomDir_v3, 'dir'), mkdir(imagesRoiZoomDir_v3); end

    % Pasta para comparação (_compare)
    imagesRoiDir_compare = fullfile(scriptDir, 'imagesROI', [folderTimestamp '_compare']);
    imagesRoiNoZoomDir_compare = fullfile(imagesRoiDir_compare, 'noZoom');
    imagesRoiZoomDir_compare = fullfile(imagesRoiDir_compare, 'zoom');
    if ~exist(imagesRoiNoZoomDir_compare, 'dir'), mkdir(imagesRoiNoZoomDir_compare); end
    if ~exist(imagesRoiZoomDir_compare, 'dir'), mkdir(imagesRoiZoomDir_compare); end
end

% Determinar nomes dos dois arquivos CSV para evitar sobrescrever
baseName = 'resultados_ROI';
ext = '.csv';

csvPath_v2 = fullfile(outputDir, [baseName '_v2' ext]);
csvPath_v3 = fullfile(outputDir, [baseName '_v3' ext]);

counter = 1;
while exist(csvPath_v2, 'file') || exist(csvPath_v3, 'file')
    csvPath_v2 = fullfile(outputDir, sprintf('%s_%d_v2%s', baseName, counter, ext));
    csvPath_v3 = fullfile(outputDir, sprintf('%s_%d_v3%s', baseName, counter, ext));
    counter = counter + 1;
end

csvHeader = 'video_name,y_position,x_position,z_position,distance,frames,x_tl,y_tl,x_tr,y_tr,x_br,y_br,x_bl,y_bl,left_height,right_height,top_width,bottom_width,height_difference,width_difference,x_coordinate_difference,y_coordinate_difference';

% Escreve os cabeçalhos nos dois arquivos CSV
fid_v2 = fopen(csvPath_v2, 'w');
if fid_v2 == -1, error('Could not create output CSV file: %s', csvPath_v2); end
fprintf(fid_v2, '%s\n', csvHeader);
fclose(fid_v2);

fid_v3 = fopen(csvPath_v3, 'w');
if fid_v3 == -1, error('Could not create output CSV file: %s', csvPath_v3); end
fprintf(fid_v3, '%s\n', csvHeader);
fclose(fid_v3);

% Processamento dos vídeos
for i = 1:numVideos
    vName = videoFiles(i).name;
    videoFile = fullfile(videoDir, vName);

    fprintf('\n===========================================================================\n');
    fprintf('Processing video [%d of %d]: %s\n', i, numVideos, vName);
    fprintf('===========================================================================\n');

    % Extrai metadados do nome do arquivo usando o parser unificado
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
    else
        warning('Nome de arquivo %s nao segue os padroes esperados. Metadados espaciais serao definidos como NaN.', vName);
    end

    try
        % 1) Lê o vídeo
        vidObj = VideoReader(videoFile);
        vidObj.CurrentTime = 0;

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj, true);
        fprintf('Total frames read: %d\n', numFrames);

        % 2) Executa detecção com automaticROI_v2
        fprintf('Running automaticROI_v2...\n');
        roiPosition_v2 = automaticROI_v2(recordedVideo, false);
        m_v2 = calcularMetricasROI(roiPosition_v2);
        salvarNoCSV(csvPath_v2, vName, y_position, x_position, z_position, distance, frames, m_v2);

        % 3) Executa detecção com automaticROI_v3
        fprintf('Running automaticROI_v3...\n');
        roiPosition_v3 = automaticROI_v3(recordedVideo, false);
        m_v3 = calcularMetricasROI(roiPosition_v3);
        salvarNoCSV(csvPath_v3, vName, y_position, x_position, z_position, distance, frames, m_v3);

        % 4) Salvar Imagens ROI (v2, v3 e compare)
        if salvarImagensROI
            [~, videoBaseName, ~] = fileparts(vName);
            lastFrame = recordedVideo(:, :, :, end);

            % Imagens v2
            salvarImagemROIIndividual(lastFrame, roiPosition_v2, fullfile(imagesRoiNoZoomDir_v2, [videoBaseName '.jpg']), false);
            salvarImagemROIIndividual(lastFrame, roiPosition_v2, fullfile(imagesRoiZoomDir_v2, [videoBaseName '.jpg']), true);

            % Imagens v3
            salvarImagemROIIndividual(lastFrame, roiPosition_v3, fullfile(imagesRoiNoZoomDir_v3, [videoBaseName '.jpg']), false);
            salvarImagemROIIndividual(lastFrame, roiPosition_v3, fullfile(imagesRoiZoomDir_v3, [videoBaseName '.jpg']), true);

            % Imagens de Comparação (Lado a Lado)
            salvarImagemROIComparacao(lastFrame, roiPosition_v2, roiPosition_v3, fullfile(imagesRoiNoZoomDir_compare, [videoBaseName '.jpg']), false);
            salvarImagemROIComparacao(lastFrame, roiPosition_v2, roiPosition_v3, fullfile(imagesRoiZoomDir_compare, [videoBaseName '.jpg']), true);
        end

    catch ME
        fprintf('ERROR processing video %s:\n%s\n', vName, ME.message);

        % Anexa marcador de erro nos CSVs
        salvarErroCSV(csvPath_v2, vName, y_position, x_position, z_position, distance, frames);
        salvarErroCSV(csvPath_v3, vName, y_position, x_position, z_position, distance, frames);
    end

    % Limpa as variáveis para liberar memória
    clear recordedVideo vidObj roiPosition_v2 roiPosition_v3;
end

fprintf('\nProcessing of all videos completed!\n');
fprintf('CSV v2 saved to: %s\n', csvPath_v2);
fprintf('CSV v3 saved to: %s\n', csvPath_v3);

% ==========================================
% FUNÇÕES AUXILIARES LOCAIS
% ==========================================

function m = calcularMetricasROI(roiPosition)
    m.x_tl = roiPosition(1, 1); m.y_tl = roiPosition(1, 2);
    m.x_tr = roiPosition(2, 1); m.y_tr = roiPosition(2, 2);
    m.x_br = roiPosition(3, 1); m.y_br = roiPosition(3, 2);
    m.x_bl = roiPosition(4, 1); m.y_bl = roiPosition(4, 2);

    m.left_height  = abs(m.y_bl - m.y_tl);
    m.right_height = abs(m.y_br - m.y_tr);
    m.top_width    = abs(m.x_tr - m.x_tl);
    m.bottom_width = abs(m.x_br - m.x_bl);

    m.height_diff  = abs(m.left_height - m.right_height);
    m.width_diff   = abs(m.top_width - m.bottom_width);

    m.x_coord_diff = abs(m.x_tl - m.x_bl);
    m.y_coord_diff = abs(m.y_tl - m.y_tr);
end

function salvarNoCSV(csvPath, vName, y_pos, x_pos, z_pos, dist, frames, m)
    fid = fopen(csvPath, 'a');
    if fid ~= -1
        fprintf(fid, '%s,%.4f,%.4f,%.5f,%.5f,%.0f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
            vName, y_pos, x_pos, z_pos, dist, frames, ...
            m.x_tl, m.y_tl, m.x_tr, m.y_tr, m.x_br, m.y_br, m.x_bl, m.y_bl, ...
            m.left_height, m.right_height, m.top_width, m.bottom_width, ...
            m.height_diff, m.width_diff, ...
            m.x_coord_diff, m.y_coord_diff);
        fclose(fid);
    else
        warning('Could not open CSV file %s to append results.', csvPath);
    end
end

function salvarErroCSV(csvPath, vName, y_pos, x_pos, z_pos, dist, frames)
    fid = fopen(csvPath, 'a');
    if fid ~= -1
        fprintf(fid, '%s,%.4f,%.4f,%.5f,%.5f,%.0f,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN\n', ...
            vName, y_pos, x_pos, z_pos, dist, frames);
        fclose(fid);
    end
end

function desenharROI(roiPos, colorStr, lineWidth)
    if size(roiPos, 1) == 4 && size(roiPos, 2) == 2
        x_coords = [roiPos(:, 1); roiPos(1, 1)];
        y_coords = [roiPos(:, 2); roiPos(1, 2)];
        plot(x_coords, y_coords, [colorStr '-'], 'LineWidth', lineWidth);
    else
        rectangle('Position', roiPos, 'EdgeColor', colorStr, 'LineWidth', lineWidth);
    end
end

function salvarImagemROIIndividual(lastFrame, roiPos, savePath, isZoom)
    if exist(savePath, 'file')
        delete(savePath);
    end
    [img_h, img_w, ~] = size(lastFrame);

    if isZoom
        if size(roiPos, 1) == 4 && size(roiPos, 2) == 2
            x_min = min(roiPos(:, 1)); x_max = max(roiPos(:, 1));
            y_min = min(roiPos(:, 2)); y_max = max(roiPos(:, 2));
        else
            x_min = roiPos(1); y_min = roiPos(2);
            x_max = x_min + roiPos(3); y_max = y_min + roiPos(4);
        end
        roi_w = x_max - x_min;
        roi_h = y_max - y_min;

        margin_x = 0.10 * roi_w;
        margin_y = 0.10 * roi_h;

        x_min_idx = max(1, floor(x_min - margin_x));
        x_max_idx = min(img_w, ceil(x_max + margin_x));
        y_min_idx = max(1, floor(y_min - margin_y));
        y_max_idx = min(img_h, ceil(y_max + margin_y));

        frameToDraw = lastFrame(y_min_idx:y_max_idx, x_min_idx:x_max_idx, :);

        roiPosDraw = roiPos;
        if size(roiPos, 1) == 4 && size(roiPos, 2) == 2
            roiPosDraw(:, 1) = roiPos(:, 1) - x_min_idx + 1;
            roiPosDraw(:, 2) = roiPos(:, 2) - y_min_idx + 1;
        else
            roiPosDraw(1) = roiPos(1) - x_min_idx + 1;
            roiPosDraw(2) = roiPos(2) - y_min_idx + 1;
        end
        lw = 0.5;
    else
        frameToDraw = lastFrame;
        roiPosDraw = roiPos;
        lw = 2;
    end

    fig = figure('Visible', 'off');
    imshow(frameToDraw, []);
    hold on;
    desenharROI(roiPosDraw, 'r', lw);
    hold off;
    print(fig, savePath, '-djpeg');
    close(fig);
end

function salvarImagemROIComparacao(lastFrame, roiPos_v2, roiPos_v3, savePath, isZoom)
    if exist(savePath, 'file')
        delete(savePath);
    end
    [img_h, img_w, ~] = size(lastFrame);

    if isZoom
        if size(roiPos_v2, 1) == 4 && size(roiPos_v2, 2) == 2
            x_min2 = min(roiPos_v2(:, 1)); x_max2 = max(roiPos_v2(:, 1));
            y_min2 = min(roiPos_v2(:, 2)); y_max2 = max(roiPos_v2(:, 2));
        else
            x_min2 = roiPos_v2(1); y_min2 = roiPos_v2(2);
            x_max2 = x_min2 + roiPos_v2(3); y_max2 = y_min2 + roiPos_v2(4);
        end

        if size(roiPos_v3, 1) == 4 && size(roiPos_v3, 2) == 2
            x_min3 = min(roiPos_v3(:, 1)); x_max3 = max(roiPos_v3(:, 1));
            y_min3 = min(roiPos_v3(:, 2)); y_max3 = max(roiPos_v3(:, 2));
        else
            x_min3 = roiPos_v3(1); y_min3 = roiPos_v3(2);
            x_max3 = x_min3 + roiPos_v3(3); y_max3 = y_min3 + roiPos_v3(4);
        end

        x_min = min(x_min2, x_min3); x_max = max(x_max2, x_max3);
        y_min = min(y_min2, y_min3); y_max = max(y_max2, y_max3);
        roi_w = x_max - x_min;
        roi_h = y_max - y_min;

        margin_x = 0.10 * roi_w;
        margin_y = 0.10 * roi_h;

        x_min_idx = max(1, floor(x_min - margin_x));
        x_max_idx = min(img_w, ceil(x_max + margin_x));
        y_min_idx = max(1, floor(y_min - margin_y));
        y_max_idx = min(img_h, ceil(y_max + margin_y));

        frameToDraw = lastFrame(y_min_idx:y_max_idx, x_min_idx:x_max_idx, :);

        roiPosDraw_v2 = roiPos_v2;
        roiPosDraw_v3 = roiPos_v3;

        if size(roiPos_v2, 1) == 4 && size(roiPos_v2, 2) == 2
            roiPosDraw_v2(:, 1) = roiPos_v2(:, 1) - x_min_idx + 1;
            roiPosDraw_v2(:, 2) = roiPos_v2(:, 2) - y_min_idx + 1;
        else
            roiPosDraw_v2(1) = roiPos_v2(1) - x_min_idx + 1;
            roiPosDraw_v2(2) = roiPos_v2(2) - y_min_idx + 1;
        end

        if size(roiPos_v3, 1) == 4 && size(roiPos_v3, 2) == 2
            roiPosDraw_v3(:, 1) = roiPos_v3(:, 1) - x_min_idx + 1;
            roiPosDraw_v3(:, 2) = roiPos_v3(:, 2) - y_min_idx + 1;
        else
            roiPosDraw_v3(1) = roiPos_v3(1) - x_min_idx + 1;
            roiPosDraw_v3(2) = roiPos_v3(2) - y_min_idx + 1;
        end
        lw = 0.5;
    else
        frameToDraw = lastFrame;
        roiPosDraw_v2 = roiPos_v2;
        roiPosDraw_v3 = roiPos_v3;
        lw = 2;
    end

    fig = figure('Visible', 'off');

    subplot(1, 2, 1);
    imshow(frameToDraw, []);
    hold on;
    desenharROI(roiPosDraw_v2, 'r', lw);
    hold off;
    title('automaticROI\_v2', 'FontSize', 10);

    subplot(1, 2, 2);
    imshow(frameToDraw, []);
    hold on;
    desenharROI(roiPosDraw_v3, 'r', lw);
    hold off;
    title('automaticROI\_v3', 'FontSize', 10);

    print(fig, savePath, '-djpeg');
    close(fig);
end
