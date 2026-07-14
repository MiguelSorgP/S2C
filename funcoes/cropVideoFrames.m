function croppedVideo = cropVideoFrames(recordedVideo, roiPosition, numFrames)
    % CROPVIDEOFRAMES Recorta a região de interesse de todos os frames do vídeo
    %   croppedVideo = CROPVIDEOFRAMES(recordedVideo, roiPosition, numFrames)
    %   recorta a região de interesse especificada em roiPosition
    %   de cada frame do vídeo.
    %
    %   Entradas:
    %       recordedVideo - Matriz 4D com os frames do vídeo original
    %       roiPosition - Vetor [x y largura altura] com as coordenadas da ROI
    %       numFrames - Número de frames a serem processados
    %
    %   Saídas:
    %       croppedVideo - Matriz 4D com os frames recortados
    
    % Recorta o primeiro frame para obter as dimensões da ROI
    firstFrameCropped = imcrop(recordedVideo(:,:,1,1), roiPosition);
    [alturaROI, larguraROI] = size(firstFrameCropped);
    
    % Pré-aloca a matriz para o vídeo recortado
    croppedVideo = zeros(alturaROI, larguraROI, 1, numFrames);
    
    % Recorta cada frame
    for k = 1:numFrames
        % Verifica se atingiu um marco de 10%
        percentComplete = floor((k / numFrames) * 100);
        if mod(percentComplete, 10) == 0 && (k == 1 || floor(((k-1) / numFrames) * 100) < percentComplete)
            fprintf('%d%% concluído (%d frames de %d)\n', percentComplete, k, numFrames);
        end
        croppedVideo(:,:,1,k) = imcrop(recordedVideo(:,:,:,k), roiPosition);
    end
end
