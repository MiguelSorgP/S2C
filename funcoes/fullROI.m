function roiPosition = fullROI(recordedVideo)
% FULLROI - Define a região de interesse (ROI) cobrindo a imagem/vídeo por completo.
% Esta função retorna as coordenadas de um retângulo que engloba toda a resolução
% espacial do sensor (imagem completa), servindo como caso de teste sem recorte de ROI.
%
% Entradas:
%   recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%
% Saídas:
%   roiPosition   - Vetor [x y largura altura] com as coordenadas da ROI correspondendo à tela cheia
    
    % Acessa o primeiro frame diretamente do array 4D
    firstFrame = recordedVideo(:,:,1,1);  % Primeiro frame
    
    % Obtém as dimensões do vídeo diretamente do frame
    [altura, largura] = size(firstFrame);
    
    % Define a ROI como o vídeo inteiro (x=1, y=1, largura, altura)
    roiPosition = [1, 1, largura, altura];
end
