function resizedVideo = resizeVideoFrames(timeCroppedVideo, Mmax, Nmax, method)
% RESIZEVIDEOFRAMES Redimensiona todos os frames de um vídeo para o tamanho especificado
%   resizedVideo = RESIZEVIDEOFRAMES(timeCroppedVideo, Mmax, Nmax) redimensiona
%   todos os frames do vídeo para a resolução especificada usando interpolação
%   do tipo 'nearest'.
%
%   resizedVideo = RESIZEVIDEOFRAMES(timeCroppedVideo, Mmax, Nmax, method) permite
%   especificar o método de interpolação (ex: 'bilinear', 'bicubic').
%
%   Entradas:
%       timeCroppedVideo - Matriz 4D com os frames do vídeo a serem redimensionados
%       Mmax - Altura desejada em pixels
%       Nmax - Largura desejada em pixels
%       method - (Opcional) Método de interpolação (padrão: 'nearest')
%
%   Saídas:
%       resizedVideo - Matriz 4D com os frames redimensionados

% Define o método padrão se não especificado
if nargin < 4
    method = 'nearest';
end

% Obtém o número de frames
NoF_efetivo = size(timeCroppedVideo, 4);

% Pré-aloca a matriz para o vídeo redimensionado
resizedVideo = zeros(Mmax, Nmax, 1, NoF_efetivo);

% Redimensiona cada frame
for ii = 1:NoF_efetivo
    % Verifica se atingiu um marco de 10%
    percentComplete = floor((ii / NoF_efetivo) * 100);
    if mod(percentComplete, 10) == 0 && (ii == 1 || floor(((ii-1) / NoF_efetivo) * 100) < percentComplete)
        fprintf('%d%% concluído (%d frames de %d)\n', percentComplete, ii, NoF_efetivo);
    end
    resizedVideo(:,:,1,ii) = imresize(timeCroppedVideo(:,:,1,ii), [Mmax, Nmax], method);
end
end
