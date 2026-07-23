function [roiPosition, resultsStruct] = automaticROI_thresholds(recordedVideo, showFigure, saveDir, videoBaseName)
% AUTOMATICROI_THRESHOLDS - Compara múltiplos métodos de limiarização para a detecção automática da ROI.
% Esta função analisa a variância temporal das intensidades de pixels e testam diferentes
% algoritmos de limiarização para binarizar a imagem de variância e extrair os 4 cantos extremos.
%
% Métodos testados:
%   1. Otsu Padrão (Otsu Standard)
%   2. Otsu Modificado (Fator de Escala 0.75)
%   3. Algoritmo do Triângulo (Triangle Thresholding - Zack et al.)
%   4. Máxima Entropia (Método de Kapur)
%   5. Limiarização Adaptativa Local (adaptthresh - Gaussian)
%   6. Limiarização Local de Sauvola (Sauvola)
%
% Entradas:
%   recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%   showFigure    - Flag booleano para exibir graficamente as etapas para CADA método (padrão: true)
%   saveDir       - (Opcional) Diretório raiz de destino para salvar as imagens de etapas (ex: imagesROI/thresholds_...)
%   videoBaseName - (Opcional) Nome base do vídeo atual para salvar a imagem (.jpg)
%
% Saídas:
%   roiPosition   - Matriz [4 x 2] contendo as coordenadas [x, y] dos 4 vértices do método padrão (Otsu)
%                   na ordem: [Top-Left; Top-Right; Bottom-Right; Bottom-Left].
%   resultsStruct - Struct contendo os resultados detalhados (ROI, limiar, mascara) de cada método.

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

    % Define a lista de métodos a serem avaliados
    % Estrutura: {TagStruct, NomeExibição, FunçãoBinarizacao, FunçãoCalculaNivel}
    methodDefs = {
        'Otsu_Padrao',              'Otsu Padrão',              @(img) img > graythresh(img),                                @(img) graythresh(img);
        'Otsu_Modificado',          'Otsu Modificado (0.75x)',   @(img) img > (0.75 * graythresh(img)),                       @(img) 0.75 * graythresh(img);
        'Triangulo',                'Algoritmo do Triângulo',   @(img) img > triangleThreshold(img),                         @(img) triangleThreshold(img);
        'Kapur',                    'Máxima Entropia (Kapur)',  @(img) img > kapurThreshold(img),                            @(img) kapurThreshold(img);
        'Adaptativo_adaptthresh',   'Adaptativo (adaptthresh)', @(img) imbinarize(img, adaptthresh(img, 0.5, 'Statistic', 'gaussian')), @(img) mean(adaptthresh(img, 0.5, 'Statistic', 'gaussian'), 'all');
        'Adaptativo_Sauvola',       'Adaptativo (Sauvola)',     @(img) sauvolaThreshold(img, 15, 0.2, 0.5),                  @(img) NaN;
    };

    numMethods = size(methodDefs, 1);
    resultsStruct = struct();

    fprintf('=========================================================================\n');
    fprintf(' Avaliando %d métodos de limiarização na variância temporal...\n', numMethods);
    fprintf('=========================================================================\n');

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
            roiPosition = roiPos; % Retorno principal como Otsu Padrão
        end

        fprintf(' [%d/%d] %-25s | Limiar: %6.3f | Detectou ROI: %s\n', ...
            m, numMethods, methodName, levelVal, string(success));

        % Exibe/salva a figura com as 6 etapas para o método atual
        shouldCreateFig = showFigure || ~isempty(saveDir);
        if shouldCreateFig
            figTitle = sprintf('Detecção ROI - Método: %s', methodName);
            if showFigure
                figVis = 'on';
            else
                figVis = 'off';
            end

            fig = figure('Name', figTitle, 'NumberTitle', 'off', ...
                'Position', [100 + (m-1)*25, 100 + (m-1)*25, 1200, 700], ...
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

% =========================================================================
% FUNÇÕES AUXILIARES DE LIMIARIZAÇÃO
% =========================================================================

function level = triangleThreshold(img)
% TRIANGLETHRESHOLD - Algoritmo do Triângulo (Zack et al. 1977)
    [counts, ~] = imhist(img, 256);
    
    [h1_peak, peakIdx] = max(counts);
    nzBins = find(counts > 0);
    
    if isempty(nzBins)
        level = 0;
        return;
    end
    
    minIdx = nzBins(1);
    maxIdx = nzBins(end);
    
    % Determina para qual lado estender a linha de referência do histograma
    if (maxIdx - peakIdx) >= (peakIdx - minIdx)
        b1 = peakIdx; h1 = counts(peakIdx);
        b2 = maxIdx;  h2 = counts(maxIdx);
        searchBins = b1:b2;
    else
        b1 = minIdx;  h1 = counts(minIdx);
        b2 = peakIdx; h2 = counts(peakIdx);
        searchBins = b1:b2;
    end
    
    A = double(h1 - h2);
    B = double(b2 - b1);
    C = double(b1*h2 - b2*h1);
    denom = sqrt(A^2 + B^2);
    
    if denom == 0
        level = graythresh(img);
        return;
    end
    
    distances = zeros(size(searchBins));
    for i = 1:length(searchBins)
        bx = double(searchBins(i));
        by = double(counts(bx));
        distances(i) = abs(A*bx + B*by + C) / denom;
    end
    
    [~, maxDistIdx] = max(distances);
    bestBin = searchBins(maxDistIdx);
    level = (bestBin - 1) / 255;
end

function level = kapurThreshold(img)
% KAPURTHRESHOLD - Máxima Entropia de Kapur
    [counts, ~] = imhist(img, 256);
    totalPixels = sum(counts);
    if totalPixels == 0
        level = 0;
        return;
    end
    p = counts / totalPixels;
    
    maxEntropy = -inf;
    bestT = 128;
    epsVal = 1e-12;
    
    for T = 1:255
        w0 = sum(p(1:T));
        w1 = sum(p(T+1:256));
        
        if w0 < epsVal || w1 < epsVal
            continue;
        end
        
        p0 = p(1:T) / w0;
        p1 = p(T+1:256) / w1;
        
        p0_nz = p0(p0 > 0);
        p1_nz = p1(p1 > 0);
        
        h0 = -sum(p0_nz .* log(p0_nz));
        h1 = -sum(p1_nz .* log(p1_nz));
        
        totEntropy = h0 + h1;
        
        if totEntropy > maxEntropy
            maxEntropy = totEntropy;
            bestT = T;
        end
    end
    
    level = (bestT - 1) / 255;
end

function bw = sauvolaThreshold(img, windowSize, k, R)
% SAUVOLATHRESHOLD - Limiarização Adaptativa Local de Sauvola
    if nargin < 2, windowSize = 15; end
    if nargin < 3, k = 0.2; end
    if nargin < 4, R = 0.5; end
    
    h = ones(windowSize, windowSize) / (windowSize^2);
    meanImg = filter2(h, img, 'same');
    meanSqImg = filter2(h, img.^2, 'same');
    varImg = max(0, meanSqImg - meanImg.^2);
    stdImg = sqrt(varImg);
    
    threshold = meanImg .* (1 + k * (stdImg / R - 1));
    bw = img > threshold;
end
