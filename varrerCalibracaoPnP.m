% VARRERCALIBRACAOPNP - Varredura/Otimização dos Parâmetros de Calibração (Matriz K e distCoeffs)
%
% Este script carrega os dados de detecção de ROI do arquivo resultados_ROI.csv escolhido pelo usuário,
% realiza uma varredura/otimização usando a função builtin 'fminsearch' do MATLAB para encontrar
% a matriz de calibração K ótima e os coeficientes de distorção de lente que minimizam o erro médio
% de posicionamento 3D em relação ao ground truth.
%
% Ao final, gera um relatório em arquivo Markdown (.md) contendo a matriz ótima, os coeficientes ótimos,
% o erro inicial vs. o erro ótimo e o código MATLAB formatado para substituição direta no resolverPnP.m.

clear; clc; close all;

%% =========================================================================
%% 1. CONFIGURAÇÕES DE OTIMIZAÇÃO, TOLERÂNCIA E ITERAÇÕES
%% =========================================================================
% Altere os valores abaixo conforme a necessidade de precisão ou velocidade:

% 1. NÚMERO MÁXIMO DE ITERAÇÕES DO ALGORITMO (MaxIter)
%    Descrição: Define a quantidade máxima de passos que o método de Nelder-Mead (fminsearch)
%               pode realizar durante a varredura/otimização.
%    Efeito:    Valores maiores (ex: 5000 a 10000) permitem uma busca mais longa e minuciosa.
%               Valores menores (ex: 500 a 1000) tornam a execução mais rápida, mas a otimização
%               pode ser interrompida antes de atingir o mínimo global.
max_iterations = 10000;

% 2. NÚMERO MÁXIMO DE AVALIAÇÕES DA FUNÇÃO OBJETIVO (MaxFunEvals)
%    Descrição: Define o número máximo de vezes que a função de cálculo do erro 3D (avaliarCalibracao)
%               pode ser testada pelo MATLAB.
%    Efeito:    Como cada iteração testa múltiplos pontos (vértices do Simplex), este número
%               deve ser tipicamente de 2x a 3x maior que max_iterations (ex: 5000 a 15000).
max_fun_evals = 30000;

% 3. TOLERÂNCIA DA FUNÇÃO OBJETIVO (TolFun - Erro 3D em Metros)
%    Descrição: Critério de parada baseado na variação do valor do erro 3D médio.
%    Efeito:    Se a diferença no erro médio 3D entre duas iterações consecutivas for menor que TolFun
%               (ex: 1e-6 m = 0.001 mm), o MATLAB considera que o erro estabilizou e encerra a busca.
%               Valores menores (ex: 1e-8) exigem maior precisão numérica e mais tempo.
%               Valores maiores (ex: 1e-4) encerram a otimização mais cedo.
tol_fun = 1e-9;

% 4. TOLERÂNCIA NAS VARIÁVEIS / PARÂMETROS (TolX)
%    Descrição: Critério de parada baseado no tamanho do ajuste dos parâmetros [fx, fy, cx, cy, k1..k3].
%    Efeito:    Se a variação nos valores dos próprios parâmetros de calibração em uma iteração
%               for menor que TolX, o algoritmo conclui que os parâmetros já convergiram.
tol_x = 1e-9;

% 5. ITERAÇÕES DE CORREÇÃO DE DISTORÇÃO DE LENTE (MaxUndistortIter)
%    Descrição: Número de iterações do algoritmo de ponto fixo usado para remover a distorção
%               radial e tangencial de cada ponto pixel.
%    Efeito:    Valores entre 15 e 30 garantem precisão sub-pixel na remoção da distorção.
max_undistort_iter = 50;

%% =========================================================================
%% 2. SELEÇÃO DO ARQUIVO DE ENTRADA (resultados_ROI.csv)
%% =========================================================================
scriptPath = fileparts(mfilename('fullpath'));
if isempty(scriptPath)
    scriptPath = pwd;
end

[fileName, filePath] = uigetfile('*.csv', 'Selecione o arquivo CSV de entrada (resultados_ROI.csv)', scriptPath);
if isequal(fileName, 0) || isequal(filePath, 0)
    disp('Seleção de arquivo cancelada pelo usuário. Encerrando script.');
    return;
end
csvInputPath = fullfile(filePath, fileName);

if ~exist(csvInputPath, 'file')
    error('Arquivo de entrada não encontrado: %s', csvInputPath);
end

%% 3. Configurações Físicas e Parâmetros Iniciais de Calibração
% Tela quadrada de 24,03 cm x 24,03 cm
lado_m = 0.2403;
meio_lado = lado_m / 2;

worldPoints3D = [
    -meio_lado,  meio_lado, 0;  % Top-Left (TL)
    meio_lado,  meio_lado, 0;  % Top-Right (TR)
    meio_lado, -meio_lado, 0;  % Bottom-Right (BR)
    -meio_lado, -meio_lado, 0   % Bottom-Left (BL)
    ];
worldPoints2D = worldPoints3D(:, 1:2);

% Parâmetros Iniciais (Do resolverPnP.m)
% K_init = [fx, 0, cx; 0, fy, cy; 0, 0, 1]
K_init = [871.0972,        0, 640;
    0, 876.3460, 360;
    0,        0,   1];

% Coeficientes de Distorção Iniciais: [k1, k2, p1, p2, k3]
distCoeffs_init = [0.14557, -0.27056, 0.00633, -0.01086, 0.17090];

% Vetor inicial de otimização: p = [fx, fy, cx, cy, k1, k2, p1, p2, k3]
p_init = [K_init(1,1), K_init(2,2), K_init(1,3), K_init(2,3), distCoeffs_init];

%% 4. Carregar Dados do CSV
fprintf('Carregando dados de ROI de: %s\n', csvInputPath);
opts = detectImportOptions(csvInputPath);
opts.VariableNamingRule = 'preserve';
data = readtable(csvInputPath, opts);
numRows = height(data);
fprintf('Total de amostras carregadas: %d\n\n', numRows);

%% 5. Avaliar Desempenho Inicial
fprintf('====================================================\n');
fprintf('AVALIAÇÃO DOS PARÂMETROS INICIAIS DE CALIBRAÇÃO\n');
fprintf('====================================================\n');
[erroInicialMedio3D, errosIniciaisDet] = avaliarCalibracao(p_init, data, worldPoints2D, max_undistort_iter);

fprintf('Matriz K Inicial:\n');
disp(K_init);
fprintf('Distortion Coeffs Iniciais: [%.5f, %.5f, %.5f, %.5f, %.5f]\n', distCoeffs_init);
fprintf('Erro Médio 3D Inicial: %.4f m (%.2f cm)\n', erroInicialMedio3D, erroInicialMedio3D * 100);
fprintf('  -> Erro Médio em X (eixo horizontal):    %.4f m (%.2f cm)\n', errosIniciaisDet.mean_x, errosIniciaisDet.mean_x * 100);
fprintf('  -> Erro Médio em Y (eixo vertical):      %.4f m (%.2f cm)\n', errosIniciaisDet.mean_y, errosIniciaisDet.mean_y * 100);
fprintf('  -> Erro Médio em Z (profundidade):       %.4f m (%.2f cm)\n', errosIniciaisDet.mean_z, errosIniciaisDet.mean_z * 100);
fprintf('====================================================\n\n');

%% 6. Varredura / Otimização (fminsearch - Builtin MATLAB)
fprintf('Iniciando otimização/varredura com método builtin do MATLAB (fminsearch)...\n');
fprintf('Configurações ativas: MaxIter=%d | MaxFunEvals=%d | TolFun=%.1e | TolX=%.1e\n', ...
    max_iterations, max_fun_evals, tol_fun, tol_x);
fprintf('Aguarde, calculando os parâmetros ótimos...\n\n');

% Configuração das opções do fminsearch com os parâmetros definidos no início
options = optimset(...
    'Display', 'iter', ...
    'MaxIter', max_iterations, ...
    'MaxFunEvals', max_fun_evals, ...
    'TolFun', tol_fun, ...
    'TolX', tol_x ...
    );

% Função objetivo a ser minimizada (Retorna apenas o erro médio 3D)
funObjetivo = @(p) avaliarCalibracao(p, data, worldPoints2D, max_undistort_iter);

% Execução da varredura/otimização
[p_opt, erroOptimoMedio3D, exitFlag, output] = fminsearch(funObjetivo, p_init, options);

%% 7. Processar Parâmetros Ótimos
K_opt = [p_opt(1),        0, p_opt(3);
    0, p_opt(2), p_opt(4);
    0,        0,        1];
distCoeffs_opt = p_opt(5:9);

[erroOptimoMedio3D, errosOptimosDet] = avaliarCalibracao(p_opt, data, worldPoints2D, max_undistort_iter);

melhoriaPct = ((erroInicialMedio3D - erroOptimoMedio3D) / erroInicialMedio3D) * 100;

fprintf('\n====================================================\n');
fprintf('RESULTADOS DA VARREDURA / OTIMIZAÇÃO\n');
fprintf('====================================================\n');
fprintf('Matriz K Ótima:\n');
disp(K_opt);
fprintf('Distortion Coeffs Ótimos: [%.5f, %.5f, %.5f, %.5f, %.5f]\n', distCoeffs_opt);
fprintf('Erro Médio 3D Inicial: %.4f m (%.2f cm)\n', erroInicialMedio3D, erroInicialMedio3D * 100);
fprintf('Erro Médio 3D Ótimo:   %.4f m (%.2f cm)\n', erroOptimoMedio3D, erroOptimoMedio3D * 100);
fprintf('Redução de Erro 3D:    %.2f%%\n', melhoriaPct);
fprintf('  -> Erro Ótimo em X: %.4f m (%.2f cm)\n', errosOptimosDet.mean_x, errosOptimosDet.mean_x * 100);
fprintf('  -> Erro Ótimo em Y: %.4f m (%.2f cm)\n', errosOptimosDet.mean_y, errosOptimosDet.mean_y * 100);
fprintf('  -> Erro Ótimo em Z: %.4f m (%.2f cm)\n', errosOptimosDet.mean_z, errosOptimosDet.mean_z * 100);
fprintf('====================================================\n\n');

%% 8. Salvar Matriz de Calibração Ótima na pasta matrizesCalibracao
calibDir = fullfile(scriptPath, 'matrizesCalibracao');
if ~exist(calibDir, 'dir')
    mkdir(calibDir);
end

baseCalibName = 'calibracao_otima';
ext = '.m';
calibFilePath = fullfile(calibDir, [baseCalibName, ext]);
counter = 1;

while exist(calibFilePath, 'file')
    calibFilePath = fullfile(calibDir, sprintf('%s_%d%s', baseCalibName, counter, ext));
    counter = counter + 1;
end

fid = fopen(calibFilePath, 'wt', 'native', 'UTF-8');
if fid ~= -1
    fprintf(fid, '%% --- PARÂMETROS DE CALIBRAÇÃO ÓTIMOS (GERADO AUTOMATICAMENTE) ---\n');
    fprintf(fid, '%% Data de geração: %s\n', datestr(now, 'dd/mm/yyyy HH:MM:SS'));
    fprintf(fid, '%% Arquivo de origem: %s\n', fileName);
    fprintf(fid, '%% Erro Médio 3D Inicial: %.4f m (%.2f cm)\n', erroInicialMedio3D, erroInicialMedio3D * 100);
    fprintf(fid, '%% Erro Médio 3D Ótimo:   %.4f m (%.2f cm)\n', erroOptimoMedio3D, erroOptimoMedio3D * 100);
    fprintf(fid, '%% Redução do Erro 3D:    %.2f%%\n\n', melhoriaPct);

    fprintf(fid, '%% Matriz Intrínseca da Câmera (K)\n');
    fprintf(fid, 'K = [\n');
    fprintf(fid, '    %12.6f, %12.6f, %12.6f;\n', K_opt(1,1), K_opt(1,2), K_opt(1,3));
    fprintf(fid, '    %12.6f, %12.6f, %12.6f;\n', K_opt(2,1), K_opt(2,2), K_opt(2,3));
    fprintf(fid, '    %12.6f, %12.6f, %12.6f\n', K_opt(3,1), K_opt(3,2), K_opt(3,3));
    fprintf(fid, '];\n\n');

    fprintf(fid, '%% Coeficientes de Distorção da Lente [k1, k2, p1, p2, k3]\n');
    fprintf(fid, 'distCoeffs = [%.6f, %.6f, %.6f, %.6f, %.6f];\n', distCoeffs_opt);

    fclose(fid);
    fprintf('Matriz de calibração ótima salva com sucesso em:\n%s\n', calibFilePath);
else
    warning('Não foi possível salvar o arquivo de calibração em: %s', calibFilePath);
end

%% ================= FUNÇÕES AUXILIARES =================

function [meanError3D, details] = avaliarCalibracao(params, data, worldPoints2D, maxUndistortIter)
% AVALIARCALIBRACAO Calcula o erro médio de posicionamento 3D para um conjunto de parâmetros.
fx = params(1);
fy = params(2);
cx = params(3);
cy = params(4);
distCoeffs = params(5:9);

K = [fx, 0, cx; 0, fy, cy; 0, 0, 1];

numRows = height(data);
erros3D = zeros(numRows, 1);
errosX  = zeros(numRows, 1);
errosY  = zeros(numRows, 1);
errosZ  = zeros(numRows, 1);

% Posições Ground Truth do CSV:
% x_position -> eixo X horizontal da câmera
% z_position -> eixo Y vertical da câmera
% y_position -> eixo Z de profundidade da câmera
x_gt = data.x_position;
y_gt = data.z_position;
z_gt = data.y_position;

x_tl = data.x_tl; y_tl = data.y_tl;
x_tr = data.x_tr; y_tr = data.y_tr;
x_br = data.x_br; y_br = data.y_br;
x_bl = data.x_bl; y_bl = data.y_bl;

for i = 1:numRows
    imgPtsDist = [
        x_tl(i), y_tl(i);
        x_tr(i), y_tr(i);
        x_br(i), y_br(i);
        x_bl(i), y_bl(i)
        ];

    imgPtsUndist = zeros(4, 2);
    for ptIdx = 1:4
        [xu, yu] = undistort_point_iterative(imgPtsDist(ptIdx, 1), imgPtsDist(ptIdx, 2), K, distCoeffs, maxUndistortIter);
        imgPtsUndist(ptIdx, :) = [xu, yu];
    end

    [~, t_c] = solve_pnp_planar_custom(worldPoints2D, imgPtsUndist);

    ex = t_c(1) - x_gt(i);
    ey = t_c(2) - y_gt(i);
    ez = t_c(3) - z_gt(i);

    errosX(i)  = abs(ex);
    errosY(i)  = abs(ey);
    errosZ(i)  = abs(ez);
    erros3D(i) = sqrt(ex^2 + ey^2 + ez^2);
end

meanError3D = mean(erros3D);

if nargout > 1
    details.mean_x = mean(errosX);
    details.mean_y = mean(errosY);
    details.mean_z = mean(errosZ);
end
end

function [xu_norm, yu_norm] = undistort_point_iterative(u, v, K, distCoeffs, maxIter)
fx = K(1, 1);
fy = K(2, 2);
cx = K(1, 3);
cy = K(2, 3);

k1 = distCoeffs(1);
k2 = distCoeffs(2);
p1 = distCoeffs(3);
p2 = distCoeffs(4);
k3 = distCoeffs(5);

xd = (u - cx) / fx;
yd = (v - cy) / fy;

xu = xd;
yu = yd;

for iter = 1:maxIter
    r2 = xu^2 + yu^2;
    radial = 1 + k1*r2 + k2*r2^2 + k3*r2^3;
    dx = 2*p1*xu*yu + p2*(r2 + 2*xu^2);
    dy = p1*(r2 + 2*yu^2) + 2*p2*xu*yu;
    xu = (xd - dx) / radial;
    yu = (yd - dy) / radial;
end

xu_norm = xu;
yu_norm = yu;
end

function [R, tvec] = solve_pnp_planar_custom(worldPoints2D, imagePointsNorm)
H = estimate_homography_dlt(worldPoints2D, imagePointsNorm);
h1 = H(:, 1);
h2 = H(:, 2);
h3 = H(:, 3);

scale = 2 / (norm(h1) + norm(h2));
r1 = scale * h1;
r2 = scale * h2;
tvec = scale * h3;

if tvec(3) < 0
    r1 = -r1;
    r2 = -r2;
    tvec = -tvec;
end

r3 = cross(r1, r2);
R_init = [r1, r2, r3];

[UR, ~, VR] = svd(R_init);
R = UR * VR';

if det(R) < 0
    UR(:, 3) = -UR(:, 3);
    R = UR * VR';
end
end

function H = estimate_homography_dlt(ptsWorld, ptsImg)
meanW = mean(ptsWorld, 1);
distW = mean(sqrt(sum((ptsWorld - meanW).^2, 2)));
scaleW = sqrt(2) / distW;
T_W = [scaleW, 0, -scaleW * meanW(1);
    0, scaleW, -scaleW * meanW(2);
    0, 0, 1];

meanI = mean(ptsImg, 1);
distI = mean(sqrt(sum((ptsImg - meanI).^2, 2)));
scaleI = sqrt(2) / distI;
T_I = [scaleI, 0, -scaleI * meanI(1);
    0, scaleI, -scaleI * meanI(2);
    0, 0, 1];

ptsW_h = [ptsWorld, ones(size(ptsWorld, 1), 1)]';
ptsI_h = [ptsImg, ones(size(ptsImg, 1), 1)]';

ptsW_norm = (T_W * ptsW_h)';
ptsI_norm = (T_I * ptsI_h)';

numPts = size(ptsWorld, 1);
A = zeros(2 * numPts, 9);
for i = 1:numPts
    X = ptsW_norm(i, 1); Y = ptsW_norm(i, 2);
    x = ptsI_norm(i, 1); y = ptsI_norm(i, 2);

    A(2*i-1, :) = [X, Y, 1, 0, 0, 0, -x*X, -x*Y, -x];
    A(2*i, :)   = [0, 0, 0, X, Y, 1, -y*X, -y*Y, -y];
end

[~, ~, V] = svd(A);
H_norm = reshape(V(:, end), 3, 3)';

H = T_I \ H_norm * T_W;
if H(3,3) ~= 0
    H = H / H(3,3);
end
end
