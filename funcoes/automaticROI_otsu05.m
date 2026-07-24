function [roiPosition, resultsStruct] = automaticROI_otsu05(recordedVideo, showFigure, saveDir, videoBaseName)
% AUTOMATICROI_OTSU05 - Detecção automática da ROI utilizando Otsu com escala 0.5.
% Esta função analisa a variância temporal das intensidades de pixels e aplica
% o algoritmo de Otsu com fator de escala 0.5 para binarizar a imagem de variância
% e extrair os 4 cantos extremos da ROI.
%
% Entradas:
%   recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%   showFigure    - Flag booleano para exibir graficamente as etapas (padrão: true)
%   saveDir       - (Opcional) Diretório raiz de destino para salvar as imagens de etapas
%   videoBaseName - (Opcional) Nome base do vídeo atual para salvar a imagem (.jpg)
%
% Saídas:
%   roiPosition   - Matriz [4 x 2] contendo as coordenadas [x, y] dos 4 vértices
%                   na ordem: [Top-Left; Top-Right; Bottom-Right; Bottom-Left].
%   resultsStruct - Struct contendo os resultados detalhados (ROI, limiar, mascara).

    if nargin < 2
        showFigure = true;
    end
    if nargin < 3
        saveDir = '';
    end
    if nargin < 4
        videoBaseName = '';
    end

    % Obtém as dimensões do vídeo 4D
    [altura, largura, ~, numFrames] = size(recordedVideo);
    
    % Inicializa matrizes 2D para soma e soma dos quadrados (Variância Temporal)
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
    
    % Normaliza a variância para o intervalo [0, 1]
    maxVar = max(varianceImage(:));
    if maxVar == 0
        varianceNorm = varianceImage;
    else
        varianceNorm = varianceImage / maxVar;
    end

    % Define o método Otsu com escala 0.5
    methodDefs = {
        'Otsu_Escala_05', 'Otsu Modificado (0.50x)', @(img) img > (0.50 * graythresh(img)), @(img) 0.50 * graythresh(img);
    };

    numMethods = size(methodDefs, 1);
    resultsStruct = struct();

    for m = 1:numMethods
        fieldTag    = methodDefs{m, 1};
        methodName  = methodDefs{m, 2};
        binFn       = methodDefs{m, 3};
        levelFn     = methodDefs{m, 4};

        % 1. Binarização Inicial
        try
            movingPixelsInitial = binFn(varianceNorm);
            levelVal = levelFn(varianceNorm);
        catch ME
            warning('Erro ao executar binarizacao para o metodo %s: %s', methodName, ME.message);
            movingPixelsInitial = false(size(varianceNorm));
            levelVal = NaN;
        end

        % 2. Filtragem Morfológica (Remoção de Ruído)
        movingPixels = bwareaopen(movingPixelsInitial, 50);

        % 3. Encontra o maior componente conectado
        cc = bwconncomp(movingPixels);
        success = true;
        
        if cc.NumObjects == 0
            warning('Método [%s]: Nenhum componente conectado encontrado.', methodName);
            success = false;
            largestComponent = false(size(movingPixels));
            roiPos = NaN(4, 2);
        else
            numPixels = cellfun(@numel, cc.PixelIdxList);
            [~, idx] = max(numPixels);
            largestComponent = false(size(movingPixels));
            largestComponent(cc.PixelIdxList{idx}) = true;

            % 4. Encontrar os 4 Cantos Extremos
            [rows, cols] = find(largestComponent);
            soma_coords = cols + rows;
            diff_coords = cols - rows;

            [~, idx_tl] = min(soma_coords); % Top-Left (min x+y)
            [~, idx_br] = max(soma_coords); % Bottom-Right (max x+y)
            [~, idx_tr] = max(diff_coords); % Top-Right (max x-y)
            [~, idx_bl] = min(diff_coords); % Bottom-Left (min x-y)

            v_tl = [cols(idx_tl), rows(idx_tl)];
            v_tr = [cols(idx_tr), rows(idx_tr)];
            v_br = [cols(idx_br), rows(idx_br)];
            v_bl = [cols(idx_bl), rows(idx_bl)];

            roiPos = [v_tl; v_tr; v_br; v_bl];
        end

        % Armazena no struct de resultados
        resultsStruct.(fieldTag).name = methodName;
        resultsStruct.(fieldTag).level = levelVal;
        resultsStruct.(fieldTag).roiPosition = roiPos;
        resultsStruct.(fieldTag).success = success;

        if m == 1
            roiPosition = roiPos;
        end

        fprintf(' [Otsu Escala 0.5] Limiar: %6.3f | Detectou ROI: %s\n', levelVal, string(success));

        % Exibe/salva a figura com as etapas
        shouldCreateFig = showFigure || ~isempty(saveDir);
        if shouldCreateFig
            figTitle = sprintf('Detecção ROI - Método: %s', methodName);
            if showFigure
                figVis = 'on';
            else
                figVis = 'off';
            end

            fig = figure('Name', figTitle, 'NumberTitle', 'off', ...
                'Position', [100, 100, 1200, 700], ...
                'Visible', figVis);

            % 1. Variância Temporal Normalizada
            subplot(2, 3, 1);
            imshow(varianceNorm, []);
            title('1. Variância Temporal');
            colorbar;

            % 2. Máscara Binária Inicial
            subplot(2, 3, 2);
            imshow(movingPixelsInitial);
            if isnan(levelVal)
                title(sprintf('2. Binarização\n(%s)', methodName), 'Interpreter', 'none');
            else
                title(sprintf('2. Binarização (%s)\n(Nível = %.3f)', methodName, levelVal), 'Interpreter', 'none');
            end

            % 3. Remoção de Ruído
            subplot(2, 3, 3);
            imshow(movingPixels);
            title('3. Remoção de Ruído (bwareaopen)');

            % 4. Maior Componente Conectado
            subplot(2, 3, 4);
            imshow(largestComponent);
            title('4. Maior Componente Conectado');

            % 5. Cantos Extremos na Máscara
            subplot(2, 3, 5);
            imshow(largestComponent);
            hold on;
            if success
                x_coords = [roiPos(:, 1); roiPos(1, 1)];
                y_coords = [roiPos(:, 2); roiPos(1, 2)];
                plot(x_coords, y_coords, 'r--', 'LineWidth', 1.5);

                c_colors = {'r', 'g', 'b', 'm'};
                c_labels = {'TL', 'TR', 'BR', 'BL'};
                for iCorner = 1:4
                    plot(roiPos(iCorner, 1), roiPos(iCorner, 2), 'o', 'MarkerSize', 8, ...
                        'MarkerFaceColor', c_colors{iCorner}, 'MarkerEdgeColor', 'w');
                    text(roiPos(iCorner, 1) + 5, roiPos(iCorner, 2) + 5, c_labels{iCorner}, ...
                        'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold');
                end
            end
            title('5. Cantos Extremos na Máscara');
            hold off;

            % 6. Resultado Final no Quadro
            subplot(2, 3, 6);
            lastFrame = recordedVideo(:, :, :, numFrames);
            imshow(lastFrame, []);
            hold on;
            if success
                plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
                plot(roiPos(:, 1), roiPos(:, 2), 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
                for iCorner = 1:4
                    text(roiPos(iCorner, 1) + 5, roiPos(iCorner, 2) + 5, c_labels{iCorner}, ...
                        'Color', 'cyan', 'FontSize', 10, 'FontWeight', 'bold');
                end
            end
            title('6. ROI Final no Quadro');
            hold off;

            % Salva a imagem da figura completa no diretório do método se saveDir for especificado
            if ~isempty(saveDir) && ~isempty(videoBaseName)
                methodSubDir = fullfile(saveDir, fieldTag);
                if ~exist(methodSubDir, 'dir')
                    mkdir(methodSubDir);
                end
                imgPath = fullfile(methodSubDir, [videoBaseName, '.jpg']);
                if exist(imgPath, 'file')
                    delete(imgPath);
                end
                print(fig, imgPath, '-djpeg', '-r150');
                fprintf('   [Imagem salva] %s\n', imgPath);
            end

            if ~showFigure
                close(fig);
            end
        end
    end
end
