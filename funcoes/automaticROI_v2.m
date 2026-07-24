function roiPosition = automaticROI_v2(recordedVideo, showFigure, otsuScaleFactor)
% AUTOMATICROI_V2 - Detecta automaticamente uma ROI quadrilátera encontrando os 4 cantos extremos.
% Esta função analisa a variância temporal das intensidades de pixels e detecta os
% quatro cantos extremos da tela do transmissor, mesmo que ela esteja inclinada
% (distorção de perspectiva). Os cantos são encontrados minimizando/maximizando
% somas e diferenças de coordenadas (x + y e x - y).
%
% Entradas:
%   recordedVideo   - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%   showFigure      - Flag booleano para exibir graficamente cada etapa do método e a ROI detectada (padrão: false)
%   otsuScaleFactor - Fator de escala multiplicativo aplicado ao limiar ótimo de Otsu (padrão: 1)
%
% Saídas:
%   roiPosition   - Matriz [4 x 2] contendo as coordenadas [x, y] dos 4 vértices
%                   na ordem: [Top-Left; Top-Right; Bottom-Right; Bottom-Left].

    if nargin < 2 || isempty(showFigure)
        showFigure = false;
    end

    if nargin < 3 || isempty(otsuScaleFactor)
        otsuScaleFactor = 1;
    end

    % Obtém as dimensões do vídeo 4D
    [altura, largura, ~, numFrames] = size(recordedVideo);
    
    % Inicializa matrizes 2D para soma e soma dos quadrados
    sumPixels = zeros(altura, largura);
    sumSqPixels = zeros(altura, largura);
    
    % Processa cada frame incrementalmente
    for t = 1:numFrames
        frameGray = double(recordedVideo(:,:,1,t));
        sumPixels = sumPixels + frameGray;
        sumSqPixels = sumSqPixels + frameGray.^2;
    end
    
    % Calcula a média e a variância
    meanPixels = sumPixels / numFrames;
    varianceImage = (sumSqPixels / numFrames) - (meanPixels).^2;
    
    % Normaliza a variância e aplica thresholding de Otsu
    maxVar = max(varianceImage(:));
    if maxVar == 0
        varianceNorm = varianceImage;
        threshold = 0;
        level = 0;
    else
        varianceNorm = varianceImage / maxVar;
        level = graythresh(varianceNorm) * otsuScaleFactor;
        threshold = level * maxVar;
    end
    
    % Etapa 2: Binarização por limiarização de Otsu
    movingPixelsInitial = varianceImage > threshold;

    % Etapa 3: Remove pequenas áreas (ruído) com morfologia
    movingPixels = bwareaopen(movingPixelsInitial, 50);
    
    % Etapa 4: Encontra o maior componente conectado
    cc = bwconncomp(movingPixels);
    if cc.NumObjects == 0
        error('Nenhum componente conectado encontrado. Ajuste o limiar ou verifique os frames.');
    end
    numPixels = cellfun(@numel, cc.PixelIdxList);
    [~, idx] = max(numPixels);
    largestComponent = false(size(movingPixels));
    largestComponent(cc.PixelIdxList{idx}) = true;
    
    % ====================================================================
    % == ENCONTRAR OS 4 CANTOS EXTREMOS ==
    % ====================================================================

    % 1. Encontra as coordenadas (row, col) de todos os pixels na máscara
    %    (Nota: 'col' é 'x', 'row' é 'y')
    [rows, cols] = find(largestComponent);
    if isempty(rows)
        error('Nenhum pixel em movimento detectado após filtragem.');
    end
    
    % 2. Calcula as métricas de soma e diferença
    % (Lembre-se: x = cols, y = rows)
    soma_coords = cols + rows;
    diff_coords = cols - rows;
    
    % 3. Encontra os índices (idx) dos pontos extremos
    
    % Canto Top-Left (TL): min(x + y)
    [~, idx_tl] = min(soma_coords);
    
    % Canto Bottom-Right (BR): max(x + y)
    [~, idx_br] = max(soma_coords);
    
    % Canto Top-Right (TR): max(x - y)
    [~, idx_tr] = max(diff_coords);
    
    % Canto Bottom-Left (BL): min(x - y)
    [~, idx_bl] = min(diff_coords);

    % 4. Coleta os vértices [x, y] (ou seja, [col, row])
    v_tl = [cols(idx_tl), rows(idx_tl)]; % Superior-Esquerdo (Top-Left)
    v_tr = [cols(idx_tr), rows(idx_tr)]; % Superior-Direito (Top-Right)
    v_br = [cols(idx_br), rows(idx_br)]; % Inferior-Direito (Bottom-Right)
    v_bl = [cols(idx_bl), rows(idx_bl)]; % Inferior-Esquerdo (Bottom-Left)
    
    % 5. Define a posição da ROI
    % Retorna na ordem: TL, TR, BR, BL (sentido horário)
    roiPosition = [v_tl;
                   v_tr;
                   v_br;
                   v_bl];

    % Exibe a figura com a visualização de cada etapa do método
    if showFigure
        figure('Name', 'Etapas da Detecção Automática da ROI (v2)', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 700]);
        
        % 1. Variância Temporal Normalizada
        subplot(2, 3, 1);
        imshow(varianceNorm, []);
        title('1. Variância Temporal');
        colorbar;
        
        % 2. Mascara Binária Inicial (Otsu)
        subplot(2, 3, 2);
        imshow(movingPixelsInitial);
        title(sprintf('2. Limiar de Otsu (Nível = %.3f)', level));
        
        % 3. Filtragem Morfológica (Remoção de Ruído)
        subplot(2, 3, 3);
        imshow(movingPixels);
        title('3. Remoção de Ruído (bwareaopen)');
        
        % 4. Maior Componente Conectado
        subplot(2, 3, 4);
        imshow(largestComponent);
        title('4. Maior Componente Conectado');
        
        % 5. Detecção dos 4 Cantos Extremos
        subplot(2, 3, 5);
        imshow(largestComponent);
        hold on;
        x_coords = [roiPosition(:, 1); roiPosition(1, 1)];
        y_coords = [roiPosition(:, 2); roiPosition(1, 2)];
        plot(x_coords, y_coords, 'r--', 'LineWidth', 1.5);
        
        c_colors = {'r', 'g', 'b', 'm'};
        c_labels = {'TL', 'TR', 'BR', 'BL'};
        for i = 1:4
            plot(roiPosition(i, 1), roiPosition(i, 2), 'o', 'MarkerSize', 8, ...
                'MarkerFaceColor', c_colors{i}, 'MarkerEdgeColor', 'w');
            text(roiPosition(i, 1) + 5, roiPosition(i, 2) + 5, c_labels{i}, ...
                'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold');
        end
        title('5. Cantos Extremos na Máscara');
        hold off;
        
        % 6. Resultado Final no Último Quadro
        subplot(2, 3, 6);
        lastFrame = recordedVideo(:, :, :, numFrames);
        imshow(lastFrame, []);
        hold on;
        plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
        plot(roiPosition(:, 1), roiPosition(:, 2), 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        for i = 1:4
            text(roiPosition(i, 1) + 5, roiPosition(i, 2) + 5, c_labels{i}, ...
                'Color', 'cyan', 'FontSize', 10, 'FontWeight', 'bold');
        end
        title('6. ROI Final no Quadro');
        hold off;
    end
end

