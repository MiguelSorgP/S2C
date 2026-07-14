function roiPosition = automaticROI(recordedVideo)
    % AUTOMATICROI Detecta automaticamente uma região de interesse baseada na variância temporal
    %   roiPosition = AUTOMATICROI(recordedVideo) analisa todos os frames do
    %   vídeo para identificar a região com maior movimento, retornando
    %   as coordenadas da ROI que engloba esta região.
    %
    %   Entradas:
    %       recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
    %
    %   Saídas:
    %       roiPosition - Vetor [x y largura altura] com as coordenadas da ROI detectada
    
    % Obtém as dimensões do vídeo 4D
    [altura, largura, ~, numFrames] = size(recordedVideo);
    
    % Inicializa matrizes 2D para soma e soma dos quadrados
    sumPixels = zeros(altura, largura);
    sumSqPixels = zeros(altura, largura);
    
    % Processa cada frame incrementalmente
    for t = 1:numFrames
        % Acessa diretamente o frame no formato 4D (já em escala de cinza [0..255])
        frameGray = recordedVideo(:,:,1,t);
        
        % Mantém precisão original (mesmo comportamento que double(frameGray))
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
    
    % fprintf('\nlevel: %d\n', level);
    % fprintf('\nthreshold: %d\n', threshold);
    
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
    
    % Encontra as coordenadas do retângulo envolvente
    [rows, cols] = find(largestComponent);
    if isempty(rows)
        error('Nenhum pixel em movimento detectado após filtragem.');
    end
    minRow = min(rows);
    maxRow = max(rows);
    minCol = min(cols);
    maxCol = max(cols);
    
    % Define a posição da ROI
    roiPosition = [minCol, minRow, maxCol - minCol + 1, maxRow - minRow + 1];
end
