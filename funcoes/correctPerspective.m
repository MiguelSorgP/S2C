function correctedVideo = correctPerspective(recordedVideo, roiPosition, numFrames)
% CORRECTPERSPECTIVE Corrige a perspectiva de um quadrilátero e recorta a região.
%
%   Entradas:
%       recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%       roiPosition   - Matriz 4x2 com os vértices [x, y] da ROI quadrilátero,
%                       na ordem: [Top-Left; Top-Right; Bottom-Right; Bottom-Left].
%       numFrames     - Número de frames a serem processados
%
%   Saídas:
%       correctedVideo - Matriz 4D com os frames corrigidos e recortados

% Extrai os vértices
v_tl = roiPosition(1, :);
v_tr = roiPosition(2, :);
v_br = roiPosition(3, :);
v_bl = roiPosition(4, :);

% Calcula a largura e a altura do retângulo de destino (usando a máxima das distâncias)
w_top = norm(v_tr - v_tl);
w_bottom = norm(v_br - v_bl);
h_left = norm(v_bl - v_tl);
h_right = norm(v_br - v_tr);

W = round(max(w_top, w_bottom));
H = round(max(h_left, h_right));

% Define os pontos de destino no retângulo retificado
fixedPoints = [
    1, 1;
    W, 1;
    W, H;
    1, H
];

% Calcula a transformação projetiva (homografia)
tform = fitgeotrans(roiPosition, fixedPoints, 'projective');

% Define a referência espacial de saída para que a imagem resultante seja de tamanho H x W
visaoSaida = imref2d([H, W]);

% Pré-aloca a matriz para o vídeo com perspectiva corrigida
correctedVideo = zeros(H, W, 1, numFrames);

% Aplica a transformação a cada frame
for k = 1:numFrames
    % Verifica se atingiu um marco de 10%
    percentComplete = floor((k / numFrames) * 100);
    if mod(percentComplete, 10) == 0 && (k == 1 || floor(((k-1) / numFrames) * 100) < percentComplete)
        fprintf('%d%% concluído (%d frames de %d)\n', percentComplete, k, numFrames);
    end
    
    % Aplica a interpolação projetiva
    frameOriginal = recordedVideo(:,:,1,k);
    correctedVideo(:,:,1,k) = imwarp(frameOriginal, tform, 'OutputView', visaoSaida, 'FillValues', 0);
end
end
