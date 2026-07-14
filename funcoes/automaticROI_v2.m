function roiPosition = automaticROI_v2(recordedVideo, showFigure)
    % AUTOMATICROI_CORNERS Detecta uma ROI em quadrilátero
    %   encontrando os 4 pontos extremos da região de maior movimento.
    %
    %   Saídas:
    %       roiPosition - Matriz 4x2 com os vértices do quadrilátero [x, y],
    %                     na ordem: [Top-Left; Top-Right; Bottom-Right; Bottom-Left].
    %

    if nargin < 2
        showFigure = false;
    end


    % Obtém as dimensões do vídeo 4D
    [altura, largura, ~, numFrames] = size(recordedVideo);
    
    % Inicializa matrizes 2D para soma e soma dos quadrados
    sumPixels = zeros(altura, largura);
    sumSqPixels = zeros(altura, largura);
    
    % Processa cada frame incrementalmente
    for t = 1:numFrames
        frameGray = recordedVideo(:,:,1,t);
        sumPixels = sumPixels + frameGray;
        sumSqPixels = sumSqPixels + frameGray.^2;
    end
    
    % Calcula a média e a variância
    meanPixels = sumPixels / numFrames;
    varianceImage = (sumSqPixels / numFrames) - (meanPixels).^2;
    
    % Normaliza a variância e aplica thresholding de Otsu
    varianceNorm = varianceImage / max(varianceImage(:));
    level = graythresh(varianceNorm);
    threshold = level * max(varianceImage(:));
    movingPixels = varianceImage > threshold;

    % Remove pequenas áreas (ruído) com morfologia
    movingPixels = bwareaopen(movingPixels, 50);
    
    % Encontra o maior componente conectado
    cc = bwconncomp(movingPixels);
    if cc.NumObjects == 0
        error('Nenhum componente conectado encontrado. Ajuste o limiar ou verifique os frames.');
    end
    numPixels = cellfun(@numel, cc.PixelIdxList);
    [~, idx] = max(numPixels);
    largestComponent = false(size(movingPixels));
    largestComponent(cc.PixelIdxList{idx}) = true;
    
    % ====================================================================
    % == INÍCIO DA NOVA LÓGICA (Encontrar os 4 cantos extremos) ==
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
    
    v_tl = [cols(idx_tl), rows(idx_tl)]; % Top-Left
    v_tr = [cols(idx_tr), rows(idx_tr)]; % Top-Right
    v_br = [cols(idx_br), rows(idx_br)]; % Bottom-Right
    v_bl = [cols(idx_bl), rows(idx_bl)]; % Bottom-Left
    
    % 5. Define a posição da ROI
    % Retorna na ordem: TL, TR, BR, BL (sentido horário)
    roiPosition = [v_tl;
                   v_tr;
                   v_br;
                   v_bl];
                   
    % Opcional: Se os pontos não estiverem únicos (ex: um quadrado perfeito)
    % podemos forçar a unicidade, embora para dados reais seja improvável.
    % Esta função é mais simples e assume que os 4 cantos são distintos.

    % Exibe a figura mostrando o último quadro com a ROI detectada em vermelho
    if showFigure
        figure('Name', 'Último Quadro - ROI Detectada', 'NumberTitle', 'off');
        lastFrame = recordedVideo(:, :, :, numFrames);
        imshow(lastFrame, []);
        hold on;
        % Desenha o quadrilátero da ROI em vermelho
        % roiPosition é uma matriz 4x2: [TL; TR; BR; BL]
        % Para fechar o quadrilátero, repetimos o primeiro ponto no final
        x_coords = [roiPosition(:, 1); roiPosition(1, 1)];
        y_coords = [roiPosition(:, 2); roiPosition(1, 2)];
        plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
        title('Último Quadro com a ROI Detectada (em vermelho)');
        hold off;
    end
end
