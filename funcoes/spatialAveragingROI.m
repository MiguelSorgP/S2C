function resizedVideo = spatialAveragingROI(recordedVideo, roiPosition, Mmax, Nmax, correcaoPerspectiva, method, calibPath)
% SPATIALAVERAGINGROI - Realiza a extração da ROI e a média/redução espacial (Mmax x Nmax)
% de todos os quadros da gravação antes do processamento temporal.
%
% Entradas:
%   recordedVideo       - Matriz 4D [H x W x 1 x numFrames] do vídeo lido da gravação.
%   roiPosition         - Posição da ROI (matriz 4x2 de vértices ou vetor [x y w h]).
%   Mmax                - Altura do vídeo original em blocos/pixels (ex: 8).
%   Nmax                - Largura do vídeo original em blocos/pixels (ex: 8).
%   correcaoPerspectiva - Booleano indicando se aplica transformação projetiva 2D.
%   method              - Método de amostragem espacial ('center_mean' ou 'nearest').
%   calibPath           - (Opcional) Caminho para a matriz de calibração (.m).
%
% Saídas:
%   resizedVideo        - Matriz 4D [Mmax x Nmax x 1 x numFrames] espacialmente reduzida.

if nargin < 5
    correcaoPerspectiva = false;
end
if nargin < 6
    method = 'center_mean';
end
if nargin < 7
    calibPath = '';
end

numFrames = size(recordedVideo, 4);

% 1. Determina o tipo de ROI e aplica Crop ou Correção de Perspectiva
isPerfectRectangle = true;
if size(roiPosition, 1) == 4 && size(roiPosition, 2) == 2
    if correcaoPerspectiva
        tol = 0;
        isPerfectRectangle = (abs(roiPosition(1,2) - roiPosition(2,2)) <= tol) && ...
                             (abs(roiPosition(4,2) - roiPosition(3,2)) <= tol) && ...
                             (abs(roiPosition(1,1) - roiPosition(4,1)) <= tol) && ...
                             (abs(roiPosition(2,1) - roiPosition(3,1)) <= tol);
        if isPerfectRectangle
            x_coord = min(roiPosition(:, 1));
            y_coord = min(roiPosition(:, 2));
            w_coord = max(roiPosition(:, 1)) - x_coord + 1;
            h_coord = max(roiPosition(:, 2)) - y_coord + 1;
            roiPosition = [x_coord, y_coord, w_coord, h_coord];
        end
    else
        x_coord = min(roiPosition(:, 1));
        y_coord = min(roiPosition(:, 2));
        w_coord = max(roiPosition(:, 1)) - x_coord + 1;
        h_coord = max(roiPosition(:, 2)) - y_coord + 1;
        roiPosition = [x_coord, y_coord, w_coord, h_coord];
        isPerfectRectangle = true;
    end
end

if isPerfectRectangle
    fprintf('Realizando crop da ROI e redução espacial para %dx%d...\n', Mmax, Nmax);
    croppedVideo = cropVideoFrames(recordedVideo, roiPosition, numFrames);
else
    fprintf('Realizando correção de perspectiva e redução espacial para %dx%d...\n', Mmax, Nmax);
    croppedVideo = correctPerspective(recordedVideo, roiPosition, numFrames, calibPath);
end

% 2. Aplica a redução espacial imediatamente (gera [Mmax x Nmax x 1 x numFrames])
resizedVideo = resizeVideoFrames_v2(croppedVideo, Mmax, Nmax, method);

end

