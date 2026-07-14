function [timeCroppedVideo, startManual, endManual] = selectFramesManually(croppedVideo, startManual, endManual)
    % SELECTFRAMESMANUALLY Seleciona um intervalo específico de frames manualmente
    %   [timeCroppedVideo, startManual, endManual] = SELECTFRAMESMANUALLY(croppedVideo, startManual, endManual)
    %   extrai um subconjunto de frames de um vídeo com base em índices fornecidos manualmente.
    %
    %   Entradas:
    %       croppedVideo - Matriz 4D com os frames do vídeo recortado
    %       startManual - Índice do primeiro frame a ser selecionado
    %       endManual - Índice do último frame a ser selecionado
    %
    %   Saídas:
    %       timeCroppedVideo - Matriz 4D com os frames selecionados
    %       startManual - Índice ajustado do primeiro frame selecionado
    %       endManual - Índice ajustado do último frame selecionado
    
    % Verifica limites usando as dimensões do vídeo recortado
    if endManual > size(croppedVideo, 4)
        warning('Índice final manual maior que numFrames. Ajustado para o último frame.');
        endManual = size(croppedVideo, 4);
    end
    if startManual < 1
        warning('Índice inicial manual menor que 1. Ajustado para 1.');
        startManual = 1;
    end
    
    fprintf('Usando croppedVideo(:,:,:, %d:%d)\n', startManual, endManual);
    timeCroppedVideo = croppedVideo(:,:,:, startManual:endManual);
end
