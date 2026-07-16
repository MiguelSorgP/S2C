function croppedVideo = cropVideoFrames(recordedVideo, roiPosition, numFrames)
% CROPVIDEOFRAMES - Recorta a região de interesse (ROI) retangular de todos os frames do vídeo.
% Esta função extrai a sub-imagem correspondente à ROI retangular de cada quadro do vídeo original
% de forma sequencial ao longo do tempo.
%
% Entradas:
%   recordedVideo - Matriz 4D com os frames do vídeo original (altura x largura x canal x frames)
%   roiPosition   - Vetor [x y largura altura] com as coordenadas da ROI retangular
%   numFrames     - Número de frames a serem processados
%
% Saídas:
%   croppedVideo  - Matriz 4D com os frames recortados na dimensão da ROI (alturaROI x larguraROI x 1 x numFrames)
    
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
