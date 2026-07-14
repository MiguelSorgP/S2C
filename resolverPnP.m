%% Resolução do Problema PnP (Perspective-n-Point) com Dados de ROI e Calibração
% Autor: Antigravity
% Data: 2026-06-19
%
% Este script carrega os dados de detecção de ROI em pixels do arquivo 'resultados_ROI_v3.csv',
% aplica a correção de distorção de lente baseada nos parâmetros obtidos na calibração,
% estima a pose 3D da câmera em relação ao alvo (PnP) usando dois métodos:
%   1) Um solver customizado de homografia planar por DLT (sem dependência de toolboxes).
%   2) O solver nativo do MATLAB (Image/Computer Vision Toolbox), se disponível.
% Compara os resultados com as distâncias físicas reais registradas e plota os gráficos comparativos.

clear; clc; close all;

%% 1. Configurações e Parâmetros de Calibração
% Determinar caminhos de arquivo baseados na localização do script
scriptPath = fileparts(mfilename('fullpath'));
if isempty(scriptPath)
    scriptPath = pwd;
end

% Abrir tela de seleção para o usuário escolher o arquivo CSV de entrada
[fileName, filePath] = uigetfile('*.csv', 'Selecione o arquivo CSV de entrada (resultados_ROI.csv)', scriptPath);
if isequal(fileName,0) || isequal(filePath,0)
    disp('Seleção de arquivo cancelada pelo usuário. Encerrando script.');
    return;
end
csvInputPath = fullfile(filePath, fileName);

% Pasta de saída (cria se não existir)
outputDir = fullfile(scriptPath, 'resultadosPnP');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Determinar nome de arquivo único para não substituir o último arquivo
baseName = 'resultados_PnP';
ext = '.csv';
csvOutputPath = fullfile(outputDir, [baseName, ext]);
counter = 1;
suffix = '';
while exist(csvOutputPath, 'file')
    suffix = sprintf('_%d', counter);
    csvOutputPath = fullfile(outputDir, [baseName, suffix, ext]);
    counter = counter + 1;
end


% Verificar se o arquivo de entrada existe
if ~exist(csvInputPath, 'file')
    error('Arquivo de entrada não encontrado: %s\nPor favor, execute o script no diretório correto ou verifique o caminho.', csvInputPath);
end

% --- Parâmetros Intrínsecos da Câmera (Matriz K) ---
% Do arquivo dadosCalibracao.md:
% K = [871.0972, 0, 584.7885; 0, 876.3460, 369.9214; 0, 0, 1]
K = [871.0972,        0, 584.7885;
    0, 876.3460, 369.9214;
    0,        0,        1];

% Coeficientes de Distorção da Lente: [k1, k2, p1, p2, k3]
distCoeffs = [0.14557, -0.27056, 0.00633, -0.01086, 0.17090];

% --- Dimensões Físicas do Alvo (ROI) ---
% Tela quadrada de 24,03 cm x 24,03 cm. A origem (0,0,0) está no centro da ROI.
% As coordenadas 3D (X, Y, Z) dos 4 cantos no referencial do mundo (em metros):
% Z = 0 porque o alvo é plano.
lado_m = 0.2403;
meio_lado = lado_m / 2;

worldPoints3D = [
    -meio_lado,  meio_lado, 0;  % Top-Left (TL)
    meio_lado,  meio_lado, 0;  % Top-Right (TR)
    meio_lado, -meio_lado, 0;  % Bottom-Right (BR)
    -meio_lado, -meio_lado, 0   % Bottom-Left (BL)
    ];

% Pontos 2D no plano do mundo para homografia (X, Y)
worldPoints2D = worldPoints3D(:, 1:2);

%% 2. Carregar Dados da ROI
fprintf('Carregando dados de: %s\n', csvInputPath);
opts = detectImportOptions(csvInputPath);
opts.VariableNamingRule = 'preserve';
data = readtable(csvInputPath, opts);

numRows = height(data);
fprintf('Total de registros encontrados: %d\n', numRows);

%% 3. Inicializar Vetores para Resultados do PnP
% Custom Solver
pnp_custom_tx = zeros(numRows, 1);
pnp_custom_ty = zeros(numRows, 1);
pnp_custom_tz = zeros(numRows, 1);
pnp_custom_dist = zeros(numRows, 1);

% Built-in Solver (caso disponível)
pnp_builtin_tx = zeros(numRows, 1);
pnp_builtin_ty = zeros(numRows, 1);
pnp_builtin_tz = zeros(numRows, 1);
pnp_builtin_dist = zeros(numRows, 1);

% Configurar uso do solver nativo
use_built_in = false;
if exist('estimateWorldCameraPose', 'file') || exist('estimateCameraPose', 'file')
    try
        % Configuração de intrinsics para versões recentes ou antigas do MATLAB
        K_matlab = K'; % MATLAB usa pós-multiplicação, então transpõe K
        radialDist = [distCoeffs(1), distCoeffs(2), distCoeffs(5)]; % [k1, k2, k3]
        tangentialDist = [distCoeffs(3), distCoeffs(4)]; % [p1, p2]

        if exist('cameraIntrinsics', 'file')
            intrinsics = cameraIntrinsics([K(1,1), K(2,2)], [K(1,3), K(2,3)], [720, 1280], ...
                'RadialDistortion', radialDist, 'TangentialDistortion', tangentialDist);
            use_built_in = true;
            fprintf('>> Solver nativo do MATLAB (cameraIntrinsics + estimateWorldCameraPose) ativado.\n');
        elseif exist('cameraParameters', 'file')
            cameraParams = cameraParameters('IntrinsicMatrix', K_matlab, ...
                'RadialDistortion', radialDist, 'TangentialDistortion', tangentialDist);
            use_built_in = true;
            fprintf('>> Solver nativo do MATLAB (cameraParameters) ativado.\n');
        end
    catch ME
        fprintf('>> Erro ao configurar solver nativo (%s). Usando apenas solver customizado.\n', ME.message);
        use_built_in = false;
    end
else
    fprintf('>> Solver nativo do MATLAB não disponível. Usando solver customizado.\n');
end

%% 4. Processar Linha por Linha
fprintf('Processando estimativas de pose...\n');
for i = 1:numRows
    % Extrair pontos de imagem distorcidos (em pixels) para a linha corrente
    u_tl = data.x_tl(i); v_tl = data.y_tl(i);
    u_tr = data.x_tr(i); v_tr = data.y_tr(i);
    u_br = data.x_br(i); v_br = data.y_br(i);
    u_bl = data.x_bl(i); v_bl = data.y_bl(i);

    imagePointsDistorted = [
        u_tl, v_tl;  % Top-Left
        u_tr, v_tr;  % Top-Right
        u_br, v_br;  % Bottom-Right
        u_bl, v_bl   % Bottom-Left
        ];

    % --- CORREÇÃO DE DISTORÇÃO ---
    % Aplicar correção iterativa customizada para os 4 pontos
    imagePointsUndistorted = zeros(4, 2);
    for ptIdx = 1:4
        [xu_norm, yu_norm] = undistort_point_iterative(...
            imagePointsDistorted(ptIdx, 1), ...
            imagePointsDistorted(ptIdx, 2), ...
            K, distCoeffs);
        % Guardar os pontos normalizados sem distorção
        imagePointsUndistorted(ptIdx, :) = [xu_norm, yu_norm];
    end

    % --- SOLVER CUSTOMIZADO (Homografia Planar via DLT + Decomposição) ---
    [R_c, t_c] = solve_pnp_planar_custom(worldPoints2D, imagePointsUndistorted);

    % t_c é a posição do alvo no sistema de coordenadas da câmera (em metros)
    % Z_cam é o eixo óptico (profundidade), X_cam é horizontal, Y_cam é vertical
    pnp_custom_tx(i) = t_c(1);
    pnp_custom_ty(i) = t_c(2);
    pnp_custom_tz(i) = t_c(3);
    pnp_custom_dist(i) = norm(t_c);

    % --- SOLVER NATIVO DO MATLAB ---
    if use_built_in
        try
            % O solver nativo espera pontos em pixels distorcidos, pois ele faz a correção interna
            if exist('cameraIntrinsics', 'file')
                % R2020b+ usa estimateWorldCameraPose
                [worldPose, ~] = estimateWorldCameraPose(imagePointsDistorted, worldPoints3D, intrinsics, ...
                    'MaxReprojectionError', 10, 'Confidence', 99);
                % worldPose armazena a pose da câmera em relação ao mundo.
                % O vetor de translação da câmera em relação ao mundo é worldPose.Translation.
                % A translação do alvo em relação à câmera é t_c_builtin = -R_c_builtin * C_world
                % Onde R_c_builtin = worldPose.Rotation (ou worldPose.R') e C_world = worldPose.Translation
                R_cam = worldPose.Rotation;
                t_cam = worldPose.Translation;
                t_target_cam = -R_cam * t_cam';
            else
                % Versões anteriores
                [worldRot, worldTrans] = estimateWorldCameraPose(imagePointsDistorted, worldPoints3D, cameraParams);
                t_target_cam = -worldRot * worldTrans';
            end

            pnp_builtin_tx(i) = t_target_cam(1);
            pnp_builtin_ty(i) = t_target_cam(2);
            pnp_builtin_tz(i) = t_target_cam(3);
            pnp_builtin_dist(i) = norm(t_target_cam);
        catch
            % Fallback caso o estimador do MATLAB divirja ou falhe em alguma linha específica
            pnp_builtin_tx(i) = pnp_custom_tx(i);
            pnp_builtin_ty(i) = pnp_custom_ty(i);
            pnp_builtin_tz(i) = pnp_custom_tz(i);
            pnp_builtin_dist(i) = pnp_custom_dist(i);
        end
    end
end

%% 5. Mapear e Adicionar Resultados à Tabela de Dados
% O setup experimental define:
%   - Distância 3D real = 'distance' no CSV
%   - Distância horizontal real = 'x_position' no CSV
%   - Distância de profundidade real (perpendicular) = 'y_position' no CSV
%   - Distância vertical real = 'z_position' no CSV (constante -0.13185 m)
%
% No sistema da câmera:
%   - Z_pnp é o eixo óptico perpendicular (profundidade). Corresponde a 'y_position'.
%   - X_pnp é o eixo horizontal (esquerda-direita). Corresponde a 'x_position'.
%   - Y_pnp é o eixo vertical (cima-baixo). Corresponde a 'z_position'.

% Adicionar as estimativas customizadas
data.pnp_custom_x = pnp_custom_tx;
data.pnp_custom_y = pnp_custom_ty;
data.pnp_custom_z = pnp_custom_tz;
data.pnp_custom_distance = pnp_custom_dist;

% Erro absoluto e percentual de distância
data.error_dist_abs = abs(data.pnp_custom_distance - data.distance);
data.error_dist_pct = (data.error_dist_abs ./ data.distance) * 100;

% Erro de profundidade perpendicular (Z_pnp vs y_position)
data.error_depth_abs = abs(data.pnp_custom_z - data.y_position);

% Erros absolutos por coordenada (X, Y, Z) no referencial da câmera (Customizado)
data.error_x_abs = abs(data.pnp_custom_x - data.x_position);
data.error_y_abs = abs(data.pnp_custom_y - data.z_position);
data.error_z_abs = abs(data.pnp_custom_z - data.y_position); % Equivalente a error_depth_abs

if use_built_in
    data.pnp_builtin_x = pnp_builtin_tx;
    data.pnp_builtin_y = pnp_builtin_ty;
    data.pnp_builtin_z = pnp_builtin_tz;
    data.pnp_builtin_distance = pnp_builtin_dist;

    % Erros absolutos por coordenada para o solver nativo do MATLAB
    data.error_builtin_dist_abs = abs(data.pnp_builtin_distance - data.distance);
    data.error_builtin_x_abs = abs(data.pnp_builtin_x - data.x_position);
    data.error_builtin_y_abs = abs(data.pnp_builtin_y - data.z_position);
    data.error_builtin_z_abs = abs(data.pnp_builtin_z - data.y_position);
end


%% 6. Salvar Tabela com Resultados
writetable(data, csvOutputPath);
fprintf('\nResultados salvos com sucesso em: %s\n', csvOutputPath);



%% ================= FUNÇÕES AUXILIARES =================

function [xu_norm, yu_norm] = undistort_point_iterative(u, v, K, distCoeffs)
% UNDISTORT_POINT_ITERATIVE Corrige a distorção da lente de um ponto pixel
% usando busca por ponto fixo e retorna as coordenadas normalizadas (Z=1).
%
% Entradas:
%   u, v       - Coordenadas do ponto na imagem em pixels (distorcido)
%   K          - Matriz intrínseca [3x3]
%   distCoeffs - Vetor de distorção [k1, k2, p1, p2, k3]
%
% Saídas:
%   xu_norm, yu_norm - Coordenadas normalizadas sem distorção (eixo óptico)

fx = K(1, 1);
fy = K(2, 2);
cx = K(1, 3);
cy = K(2, 3);

k1 = distCoeffs(1);
k2 = distCoeffs(2);
p1 = distCoeffs(3);
p2 = distCoeffs(4);
k3 = distCoeffs(5);

% 1. Converter pixels distorcidos para coordenadas normalizadas distorcidas
xd = (u - cx) / fx;
yd = (v - cy) / fy;

% 2. Resolver iterativamente para estimar as coordenadas normais sem distorção
% Usando o algoritmo de ponto fixo (como feito na implementação do OpenCV)
xu = xd;
yu = yd;

for iter = 1:20
    r2 = xu^2 + yu^2;
    radial = 1 + k1*r2 + k2*r2^2 + k3*r2^3;

    % Componentes da distorção tangencial
    dx = 2*p1*xu*yu + p2*(r2 + 2*xu^2);
    dy = p1*(r2 + 2*yu^2) + 2*p2*xu*yu;

    % Atualização do ponto fixo
    xu = (xd - dx) / radial;
    yu = (yd - dy) / radial;
end

xu_norm = xu;
yu_norm = yu;
end

function [R, tvec] = solve_pnp_planar_custom(worldPoints2D, imagePointsNorm)
% SOLVE_PNP_PLANAR_CUSTOM Resolve o PnP para alvos planares estimando a
% homografia entre o plano Z=0 do mundo e a imagem normalizada sem distorção,
% decompondo-a para encontrar R (rotação) e tvec (translação).
%
% Entradas:
%   worldPoints2D   - Coordenadas [4x2] do quadrado no mundo (metros)
%   imagePointsNorm - Coordenadas [4x2] normalizadas sem distorção na imagem
%
% Saídas:
%   R    - Matriz de Rotação 3D [3x3] da câmera para o alvo
%   tvec - Vetor de Translação 3D [3x1] (posição do centro do alvo na câmera)

% 1. Estimar a homografia normalizada H_norm usando DLT com normalização
H = estimate_homography_dlt(worldPoints2D, imagePointsNorm);

% H mapeia pontos do mundo [X; Y; 1] para a imagem normalizada [x_norm; y_norm; 1]
% Então H_norm = [r1, r2, tvec]
h1 = H(:, 1);
h2 = H(:, 2);
h3 = H(:, 3);

% 2. Decompor colunas para recuperar rotação e translação
% Fator de escala lambda baseado na ortogonalidade e norma unitária de r1 e r2
scale = 2 / (norm(h1) + norm(h2));

r1 = scale * h1;
r2 = scale * h2;
tvec = scale * h3;

% Garantir que o vetor de translação aponte para a frente da câmera (profundidade positiva)
if tvec(3) < 0
    r1 = -r1;
    r2 = -r2;
    tvec = -tvec;
end

% r3 é ortogonal a r1 e r2
r3 = cross(r1, r2);

% Construir a matriz de rotação inicial
R_init = [r1, r2, r3];

% 3. Projetar R_init na variedade SO(3) usando SVD para garantir ortogonalidade perfeita
[UR, ~, VR] = svd(R_init);
R = UR * VR';

% Garantir determinante +1 (evitar reflexões)
if det(R) < 0
    UR(:, 3) = -UR(:, 3);
    R = UR * VR';
end
end

function H = estimate_homography_dlt(ptsWorld, ptsImg)
% ESTIMATE_HOMOGRAPHY_DLT Calcula a homografia 3x3 entre pontos 2D usando DLT
% com normalização de coordenadas para estabilidade numérica.

% 1. Normalização dos pontos do mundo
meanW = mean(ptsWorld, 1);
distW = mean(sqrt(sum((ptsWorld - meanW).^2, 2)));
scaleW = sqrt(2) / distW;
T_W = [scaleW, 0, -scaleW * meanW(1);
    0, scaleW, -scaleW * meanW(2);
    0, 0, 1];

% 2. Normalização dos pontos da imagem
meanI = mean(ptsImg, 1);
distI = mean(sqrt(sum((ptsImg - meanI).^2, 2)));
scaleI = sqrt(2) / distI;
T_I = [scaleI, 0, -scaleI * meanI(1);
    0, scaleI, -scaleI * meanI(2);
    0, 0, 1];

% Aplicar transformações
ptsW_h = [ptsWorld, ones(size(ptsWorld, 1), 1)]';
ptsI_h = [ptsImg, ones(size(ptsImg, 1), 1)]';

ptsW_norm = (T_W * ptsW_h)';
ptsI_norm = (T_I * ptsI_h)';

% 3. Construir a matriz A para A * h = 0
numPts = size(ptsWorld, 1);
A = zeros(2 * numPts, 9);
for i = 1:numPts
    X = ptsW_norm(i, 1); Y = ptsW_norm(i, 2);
    x = ptsI_norm(i, 1); y = ptsI_norm(i, 2);

    A(2*i-1, :) = [X, Y, 1, 0, 0, 0, -x*X, -x*Y, -x];
    A(2*i, :)   = [0, 0, 0, X, Y, 1, -y*X, -y*Y, -y];
end

% Resolver usando SVD
[~, ~, V] = svd(A);
H_norm = reshape(V(:, end), 3, 3)';

% 4. Desnormalizar a homografia
H = T_I \ H_norm * T_W;

% Dividir pelo último elemento para H(3,3) ser aproximadamente 1 (ou manter a escala padrão)
if H(3,3) ~= 0
    H = H / H(3,3);
end
end
