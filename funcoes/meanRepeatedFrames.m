function finalVideo = meanRepeatedFrames(resizedVideo, repeatedFrames)
% MEANREPEATEDFRAMES - Downsampling temporal integrando (por média) quadros repetidos.
% Devido à maior taxa de amostragem na recepção em comparação com a transmissão
% (fpsRx > fpsTx), cada frame transmitido aparece repetido por repeatedFrames na gravação.
% Esta função calcula a média aritmética ao longo do tempo de cada bloco de frames
% repetidos adjacentes, reduzindo o ruído temporal (filtro de média móvel decantadora)
% e restaurando a dimensão temporal original nominal de K*F frames.
%
% Entradas:
%   resizedVideo   - Matriz 4D com os frames do vídeo redimensionados [Mmax x Nmax x 1 x numFrames]
%   repeatedFrames - Fator de sobreamostragem temporal (número de repetições por frame)
%
% Saídas:
%   finalVideo     - Matriz 4D contendo os frames decimados/integrados por média [Mmax x Nmax x 1 x numNewFrames]
    
    % Calcula o número de frames no vídeo final
    numNewFrames = floor(size(resizedVideo,4) / repeatedFrames);
    
    % Obtém as dimensões dos frames
    Mmax = size(resizedVideo, 1);
    Nmax = size(resizedVideo, 2);
    
    % Pré-aloca a matriz para o vídeo final
    finalVideo = zeros(Mmax, Nmax, 1, numNewFrames);
    
    % Calcula a média de cada bloco de frames
    for jj = 1:numNewFrames
        idxStart = (jj-1)*repeatedFrames + 1;
        idxEnd   = jj*repeatedFrames;
        framesToAverage = resizedVideo(:,:,:, idxStart:idxEnd);
        finalVideo(:,:,:, jj) = mean(framesToAverage, 4);
    end
end
