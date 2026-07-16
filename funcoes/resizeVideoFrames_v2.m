function resizedVideo = resizeVideoFrames_v2(timeCroppedVideo, Mmax, Nmax, method)
% RESIZEVIDEOFRAMES_V2 - Redimensiona todos os frames usando média de miolo de bloco (center_mean) ou imresize.
% Esta versão aprimorada permite redimensionar o vídeo utilizando o método especial 'center_mean'.
% Esse método divide o quadro em blocos Mmax x Nmax, localiza o centro (miolo) de cada bloco
% (correspondente ao centro geométrico de cada LED da tela) e calcula a média das intensidades
% de pixels nessa área central limpa, evitando efeitos de borramento nas bordas dos blocos.
%
% Entradas:
%   timeCroppedVideo - Matriz 4D com os frames do vídeo a serem redimensionados
%   Mmax             - Altura desejada em pixels (blocos)
%   Nmax             - Largura desejada em pixels (blocos)
%   method           - Método de redimensionamento ('center_mean' ou métodos do imresize como 'nearest')
%
% Saídas:
%   resizedVideo     - Matriz 4D com os frames redimensionados (Mmax x Nmax x 1 x NoF_efetivo)

% Se o método for 'center_mean', usa amostragem do miolo de cada bloco
if nargin < 4
    method = 'nearest';
end

NoF_efetivo = size(timeCroppedVideo, 4);
resizedVideo = zeros(Mmax, Nmax, 1, NoF_efetivo);

if strcmp(method, 'center_mean')
    [H, W, ~, ~] = size(timeCroppedVideo);
    blockH = H / Mmax; % ex: 100 pixels
    blockW = W / Nmax; % ex: 100 pixels
    
    % Define o tamanho do "miolo" a considerar (ex: 40% central do bloco)
    cropRatio = 0.4;
    marginH = floor(blockH * (1 - cropRatio) / 2);
    marginW = floor(blockW * (1 - cropRatio) / 2);
    
    for ii = 1:NoF_efetivo
        frame = timeCroppedVideo(:,:,1,ii);
        for r = 1:Mmax
            for c = 1:Nmax
                % Delimita apenas o centro do LED
                rStart = round((r-1)*blockH + 1 + marginH);
                rEnd   = round(r*blockH - marginH);
                cStart = round((c-1)*blockW + 1 + marginW);
                cEnd   = round(c*blockW - marginW);
                
                % Tira a média apenas da região limpa do símbolo
                resizedVideo(r, c, 1, ii) = mean2(frame(rStart:rEnd, cStart:cEnd));
            end
        end
    end
else
    % Caminho padrão usando imresize do MATLAB
    for ii = 1:NoF_efetivo
        resizedVideo(:,:,1,ii) = imresize(timeCroppedVideo(:,:,1,ii), [Mmax, Nmax], method);
    end
end
end
