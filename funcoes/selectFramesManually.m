function [timeCroppedVideo, startManual, endManual] = selectFramesManually(croppedVideo, startManual, endManual)
% SELECTFRAMESMANUALLY - Recorta temporalmente o vídeo com base em índices manuais.
% Esta função extrai um intervalo contíguo de frames do vídeo gravado a partir de
% índices fornecidos manualmente pelo usuário, aplicando verificações de limites.
%
% Entradas:
%   croppedVideo - Matriz 4D com os frames do vídeo recortado
%   startManual  - Índice manual de frame inicial desejado
%   endManual    - Índice manual de frame final desejado
%
% Saídas:
%   timeCroppedVideo - Matriz 4D com os frames recortados no intervalo desejado
%   startManual      - Índice ajustado de frame inicial
%   endManual        - Índice ajustado de frame final
    
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
