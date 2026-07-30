% GERAR_FIGURAS_ROI_ANTIGAS - Processa vídeos antigos da pasta ../gravacoes_antigas
% Executa automaticROI_v2 com otsuScaleFactor = 1 e salva 4 figuras por vídeo:
%   1. Original Frame (último quadro)
%   2. Norm. Variance (Variância temporal normalizada)
%   3. Detected ROI (in red, full frame)
%   4. Detected ROI (in red, zoom in roi, com 10% de margem)
%
% As figuras são salvas nos formatos .fig, .jpeg, .eps e .pdf em subpastas dedicadas:
%   - figuras_ROI_antigas/fig/
%   - figuras_ROI_antigas/jpeg/
%   - figuras_ROI_antigas/eps/
%   - figuras_ROI_antigas/pdf/

clc;
clear;
close all;

% Configura o caminho relativo à localização do script e adiciona a pasta 'funcoes'
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

% Diretório contendo os vídeos antigos
videoDir = fullfile(scriptDir, '..', 'gravacoes_antigas');

% Lista dos vídeos solicitados
videoList = { ...
    '1m_left_lightsON_video1.mp4';
    '1m_mid_lightsOFF_video3.mp4';
    '1m_mid_lightsON_video1.mp4';
    '1m_right_lightsON_video5.mp4';
    '3m_left_lightsOFF_video1.mp4';
    '3m_mid_lightsOFF_video2.mp4';
    '3m_mid_lightsON_video5.mp4';
    '3m_right_lightsOFF_video2.mp4';
    '3m_right_lightsON_video1.mp4' ...
};

numVideos = numel(videoList);

% Diretório principal de saída e subpastas para cada formato
outputDir  = fullfile(scriptDir, 'figuras_ROI_antigas');
subDirFig  = fullfile(outputDir, 'fig');
subDirJpeg = fullfile(outputDir, 'jpeg');
subDirEps  = fullfile(outputDir, 'eps');
subDirPdf  = fullfile(outputDir, 'pdf');

if ~exist(subDirFig, 'dir'),  mkdir(subDirFig);  end
if ~exist(subDirJpeg, 'dir'), mkdir(subDirJpeg); end
if ~exist(subDirEps, 'dir'),  mkdir(subDirEps);  end
if ~exist(subDirPdf, 'dir'),  mkdir(subDirPdf);  end

fprintf('Iniciando processamento de %d vídeos da pasta: %s\n', numVideos, videoDir);
fprintf('As figuras salvas serão armazenadas nas subpastas de: %s\n\n', outputDir);

otsuScaleFactor = 1;

for i = 1:numVideos
    vName = videoList{i};
    videoPath = fullfile(videoDir, vName);
    [~, videoBaseName, ~] = fileparts(vName);
    
    fprintf('===========================================================================\n');
    fprintf('Processando vídeo [%d de %d]: %s\n', i, numVideos, vName);
    fprintf('===========================================================================\n');
    
    if ~exist(videoPath, 'file')
        warning('Arquivo de vídeo não encontrado: %s. Pulando...', videoPath);
        continue;
    end
    
    try
        % 1. Carrega o vídeo em escala de cinza
        vidObj = VideoReader(videoPath);
        vidObj.CurrentTime = 0;
        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj, false);
        fprintf('Total de frames lidos: %d\n', numFrames);
        
        % 2. Executa a detecção de ROI com automaticROI_v2 (otsuScaleFactor = 1)
        fprintf('Executando automaticROI_v2 com otsuScaleFactor = %.1f...\n', otsuScaleFactor);
        roiPosition = automaticROI_v2(recordedVideo, false, otsuScaleFactor);
        
        % 3. Calcula a variância temporal normalizada
        [altura, largura, ~, NoF] = size(recordedVideo);
        sumPixels = zeros(altura, largura);
        sumSqPixels = zeros(altura, largura);
        for t = 1:NoF
            frameGray = double(recordedVideo(:,:,1,t));
            sumPixels = sumPixels + frameGray;
            sumSqPixels = sumSqPixels + frameGray.^2;
        end
        meanPixels = sumPixels / NoF;
        varianceImage = (sumSqPixels / NoF) - (meanPixels).^2;
        maxVar = max(varianceImage(:));
        if maxVar == 0
            varianceNorm = varianceImage;
        else
            varianceNorm = varianceImage / maxVar;
        end
        
        % Obtém o último frame do vídeo
        lastFrame = recordedVideo(:,:,1,end);
        
        % -------------------------------------------------------------------
        % Figura 1: Original Frame (sem título)
        % -------------------------------------------------------------------
        fig1 = figure('Name', sprintf('Original Frame - %s', videoBaseName), 'Visible', 'off');
        imshow(lastFrame, []);
        baseName1 = sprintf('%s_1_OriginalFrame', videoBaseName);
        salvarEmFormatos(fig1, baseName1, subDirFig, subDirJpeg, subDirEps, subDirPdf);
        close(fig1);
        fprintf('  [1/4] Salvo Original Frame (.fig, .jpeg, .eps, .pdf ajustado)\n');
        
        % -------------------------------------------------------------------
        % Figura 2: Norm. Variance (sem título, sem colorbar)
        % -------------------------------------------------------------------
        fig2 = figure('Name', sprintf('Norm Variance - %s', videoBaseName), 'Visible', 'off');
        imshow(varianceNorm, []);
        baseName2 = sprintf('%s_2_NormVariance', videoBaseName);
        salvarEmFormatos(fig2, baseName2, subDirFig, subDirJpeg, subDirEps, subDirPdf);
        close(fig2);
        fprintf('  [2/4] Salvo Norm. Variance (.fig, .jpeg, .eps, .pdf ajustado)\n');
        
        % -------------------------------------------------------------------
        % Figura 3: Detected ROI (in red, full frame, apenas a ROI em vermelho)
        % -------------------------------------------------------------------
        fig3 = figure('Name', sprintf('Detected ROI Full Frame - %s', videoBaseName), 'Visible', 'off');
        imshow(lastFrame, []);
        hold on;
        x_coords = [roiPosition(:, 1); roiPosition(1, 1)];
        y_coords = [roiPosition(:, 2); roiPosition(1, 2)];
        plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
        hold off;
        baseName3 = sprintf('%s_3_DetectedROI_FullFrame', videoBaseName);
        salvarEmFormatos(fig3, baseName3, subDirFig, subDirJpeg, subDirEps, subDirPdf);
        close(fig3);
        fprintf('  [3/4] Salvo Detected ROI (Full Frame) (.fig, .jpeg, .eps, .pdf ajustado)\n');
        
        % -------------------------------------------------------------------
        % Figura 4: Detected ROI (in red, zoom in roi, com 10% de margem, apenas a ROI em vermelho)
        % -------------------------------------------------------------------
        fig4 = figure('Name', sprintf('Detected ROI Zoom - %s', videoBaseName), 'Visible', 'off');
        
        % Limites da ROI
        x_min = min(roiPosition(:, 1));
        x_max = max(roiPosition(:, 1));
        y_min = min(roiPosition(:, 2));
        y_max = max(roiPosition(:, 2));
        roi_w = x_max - x_min;
        roi_h = y_max - y_min;
        
        % Margem de 10%
        margin_x = 0.10 * roi_w;
        margin_y = 0.10 * roi_h;
        
        x_min_idx = max(1, floor(x_min - margin_x));
        x_max_idx = min(largura, ceil(x_max + margin_x));
        y_min_idx = max(1, floor(y_min - margin_y));
        y_max_idx = min(altura, ceil(y_max + margin_y));
        
        croppedFrame = lastFrame(y_min_idx:y_max_idx, x_min_idx:x_max_idx);
        
        roiCropped = roiPosition;
        roiCropped(:, 1) = roiPosition(:, 1) - x_min_idx + 1;
        roiCropped(:, 2) = roiPosition(:, 2) - y_min_idx + 1;
        
        imshow(croppedFrame, []);
        hold on;
        x_coords_crop = [roiCropped(:, 1); roiCropped(1, 1)];
        y_coords_crop = [roiCropped(:, 2); roiCropped(1, 2)];
        plot(x_coords_crop, y_coords_crop, 'r-', 'LineWidth', 1.5);
        hold off;
        baseName4 = sprintf('%s_4_DetectedROI_Zoom', videoBaseName);
        salvarEmFormatos(fig4, baseName4, subDirFig, subDirJpeg, subDirEps, subDirPdf);
        close(fig4);
        fprintf('  [4/4] Salvo Detected ROI (Zoom 10%% Margin) (.fig, .jpeg, .eps, .pdf ajustado)\n');
        
    catch ME
        fprintf('ERRO ao processar o vídeo %s: %s\n', vName, ME.message);
    end
    
    % Limpeza de memória
    clear recordedVideo vidObj roiPosition;
end

fprintf('\nProcessamento de todos os vídeos concluído com sucesso!\n');

% =========================================================================
% Função auxiliar para salvar a figura nos 4 formatos solicitados
% =========================================================================
function salvarEmFormatos(fig, baseName, dirFig, dirJpeg, dirEps, dirPdf)
    % 1. Salva formato MATLAB .fig
    savefig(fig, fullfile(dirFig, [baseName '.fig']));
    
    % 2. Salva formato JPEG .jpeg
    saveas(fig, fullfile(dirJpeg, [baseName '.jpeg']));
    
    % 3. Salva formato EPS .eps
    saveas(fig, fullfile(dirEps, [baseName '.eps']), 'epsc');
    
    % 4. Salva formato PDF .pdf ajustado sem margens brancas da folha de papel
    pdfPath = fullfile(dirPdf, [baseName '.pdf']);
    try
        % exportgraphics (MATLAB R2020a+) recorta automaticamente a área útil da figura sem margem de página
        exportgraphics(fig, pdfPath);
    catch
        % Fallback para versões mais antigas do MATLAB: ajusta as dimensões da folha ao tamanho exato da figura
        fig.PaperPositionMode = 'auto';
        figPos = fig.PaperPosition;
        fig.PaperSize = [figPos(3), figPos(4)];
        print(fig, pdfPath, '-dpdf');
    end
end
