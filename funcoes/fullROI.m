function roiPosition = fullROI(recordedVideo)
    % FULLROI Define a região de interesse (ROI) como o vídeo inteiro
    %   roiPosition = FULLROI(recordedVideo) define a ROI para cobrir o vídeo
    %   completo, usando as dimensões do primeiro frame.
    %
    %   Entradas:
    %       recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
    %
    %   Saídas:
    %       roiPosition - Vetor [x y largura altura] com as coordenadas da ROI completa
    
    % Acessa o primeiro frame diretamente do array 4D
    firstFrame = recordedVideo(:,:,1,1);  % Primeiro frame
    
    % Obtém as dimensões do vídeo diretamente do frame
    [altura, largura] = size(firstFrame);
    
    % Define a ROI como o vídeo inteiro (x=1, y=1, largura, altura)
    roiPosition = [1, 1, largura, altura];
end
