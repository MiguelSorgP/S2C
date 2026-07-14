function finalVideo = meanRepeatedFrames(resizedVideo, repeatedFrames)
    % MEANREPEATEDFRAMES Calcula a média de blocos de frames consecutivos
    %   finalVideo = MEANREPEATEDFRAMES(resizedVideo, repeatedFrames) calcula
    %   a média de cada bloco de 'repeatedFrames' frames consecutivos,
    %   criando um novo vídeo com menor número de frames.
    %
    %   Entradas:
    %       resizedVideo - Matriz 4D com os frames do vídeo redimensionado
    %       repeatedFrames - Número de frames consecutivos a serem combinados
    %
    %   Saídas:
    %       finalVideo - Matriz 4D com os frames resultantes da média
    
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
