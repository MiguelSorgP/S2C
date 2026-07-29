function correctedVideo = correctPerspective(recordedVideo, roiPosition, numFrames, calibPath)
% CORRECTPERSPECTIVE - Aplica homografia projetiva 2D para corrigir distorções de perspectiva.
% Esta função retifica geometricamente a região inclinada definida pela ROI quadrilátera
% (os 4 cantos da tela), mapeando-a de volta para um retângulo perfeito de destino.
% Se um caminho de matriz de calibração (calibPath) for fornecido, realiza a desdistorção
% óptica da lente da câmera antes da interpolação projetiva.
%
% Entradas:
%   recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%   roiPosition   - Matriz 4x2 com as coordenadas [x, y] dos 4 vértices
%                   na ordem: [Top-Left; Top-Right; Bottom-Right; Bottom-Left].
%   numFrames     - Número de frames a serem processados
%   calibPath     - (Opcional) Caminho para o arquivo .m da matriz de calibração da câmera.
%                   Se vazio, false ou não informado, aplica retificação genérica clássica.
%
% Saídas:
%   correctedVideo - Matriz 4D com os frames corrigidos e retificados

if nargin < 4
    calibPath = '';
end

% Verificar se um caminho válido de calibração foi fornecido
usarCalibracao = false;
if ~isempty(calibPath) && ~(islogical(calibPath) && ~calibPath)
    if ischar(calibPath) || isstring(calibPath)
        calibPathStr = char(calibPath);
        if exist(calibPathStr, 'file')
            usarCalibracao = true;
        else
            warning('Arquivo de calibração não encontrado: %s. Usando retificação genérica.', calibPathStr);
        end
    end
end

intrinsicsObj = [];
roiPositionProc = roiPosition;

if usarCalibracao
    K = [];
    distCoeffs = [];
    try
        run(calibPathStr);
    catch ME
        warning('Erro ao carregar matriz de calibração (%s). Usando retificação genérica.', ME.message);
        usarCalibracao = false;
    end
    
    if usarCalibracao && exist('K', 'var') && exist('distCoeffs', 'var') && ~isempty(K) && ~isempty(distCoeffs)
        H_img = size(recordedVideo, 1);
        W_img = size(recordedVideo, 2);
        
        radialDist = [distCoeffs(1), distCoeffs(2), distCoeffs(5)];
        tangentialDist = [distCoeffs(3), distCoeffs(4)];
        focalLength = [K(1,1), K(2,2)];
        principalPoint = [K(1,3), K(2,3)];
        
        if exist('cameraIntrinsics', 'file')
            intrinsicsObj = cameraIntrinsics(focalLength, principalPoint, [H_img, W_img], ...
                'RadialDistortion', radialDist, 'TangentialDistortion', tangentialDist);
            roiPositionProc = undistortPoints(roiPosition, intrinsicsObj);
            fprintf('>> Aplicando desdistorção de lente (cameraIntrinsics) + retificação de perspectiva...\n');
        elseif exist('cameraParameters', 'file')
            K_matlab = K';
            intrinsicsObj = cameraParameters('IntrinsicMatrix', K_matlab, ...
                'RadialDistortion', radialDist, 'TangentialDistortion', tangentialDist);
            roiPositionProc = undistortPoints(roiPosition, intrinsicsObj);
            fprintf('>> Aplicando desdistorção de lente (cameraParameters) + retificação de perspectiva...\n');
        else
            usarCalibracao = false;
            fprintf('>> Toolbox de visão computacional (undistortImage) não disponível. Mantendo retificação genérica.\n');
        end
    else
        usarCalibracao = false;
    end
end

if ~usarCalibracao
    fprintf('>> Aplicando retificação de perspectiva genérica (sem matriz de calibração)...\n');
end

% Extrai os vértices (desdistorcidos se calibração ativa, ou originais se genérico)
v_tl = roiPositionProc(1, :);
v_tr = roiPositionProc(2, :);
v_br = roiPositionProc(3, :);
v_bl = roiPositionProc(4, :);

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
tform = fitgeotrans(roiPositionProc, fixedPoints, 'projective');

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
    
    frameOriginal = recordedVideo(:,:,1,k);
    
    if usarCalibracao && ~isempty(intrinsicsObj)
        frameProcessado = undistortImage(frameOriginal, intrinsicsObj);
    else
        frameProcessado = frameOriginal;
    end
    
    % Aplica a interpolação projetiva
    correctedVideo(:,:,1,k) = imwarp(frameProcessado, tform, 'OutputView', visaoSaida, 'FillValues', 0);
end
end

