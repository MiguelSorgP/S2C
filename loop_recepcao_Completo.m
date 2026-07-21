% LOOP_RECEPCAO_COMPLETO - Script principal para recepção, processamento e decodificação de vídeos S2C.
% Este script implementa a cadeia completa de recepção de comunicações ópticas por câmera (OCC)
% baseada em tela (Screen-to-Camera). O fluxo consiste em:
% 1) Leitura de vídeo capturado pela câmera em escala de cinza.
% 2) Extração da ROI correspondente à tela do transmissor (manual, automática ou via CSV).
% 3) Correção geométrica de distorção de perspectiva (homografia 2D).
% 4) Sincronização temporal fina por alinhamento de fase e busca de transições.
% 5) Média de frames repetidos para downsampling temporal de fpsRx para fpsTx.
% 6) Execução do algoritmo de recepção (OCC-KRF ou OCC-ALS) para estimar símbolos purificados.
% 7) Decodificação de bits por distância euclidiana mínima e extração de metadados.
% 8) Análise estatística de desempenho (BER, SER, MSE) por simulação de Monte Carlo sob ruído AWGN
%    usando paralelização vetorizada 3D em GPU ou CPU com parfor.

clc;
clear all;
close all;

% Configura os caminhos relativos à localização do script
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'funcoes'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                         PARÂMETROS CONFIGURÁVEIS                      %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1) Diretório dos vídeos
videoDir = '../gravacoes_20_07';

% 2) Arquivos .mat com os dados do vídeo original
matFileF5 = 'videosGerados\dados_video_Mmax8_Nmax8_M4_N4_F5.mat';
matFileF10 = 'videosGerados\dados_video_Mmax8_Nmax8_M4_N4_F10.mat';
matFiles = {matFileF5, matFileF10};

% 3) Algoritmo de recepção/decodificação:
%    1 = OCC-KRF (Khatri-Rao Factorization, direto, rápido, não-iterativo)
%    2 = OCC-ALS (Alternating Least Squares, iterativo, estimativa conjunta de canal e vídeo)
rxAlgorithm = 1;

% 4) Taxas de quadros
fpsTx = 3;   % Taxa de quadros do vídeo exibido (transmissão)

% 5) Flags de seleção da ROI
%    1 = Seleção automática (detecta a região que varia) - RECOMENDADO PARA AUTOMATIZAÇÃO
%    2 = Usar o vídeo inteiro como ROI (nenhum recorte)
%    3 = Selecionar manualmente via drawrectangle
roiFlag = 1;

% 6) Flags de seleção dos quadros de interesse
%    1 = Automática (usa variação temporal para detectar o final do vídeo e definir start/end frames)
%    2 = Nenhum corte (usa o vídeo inteiro do começo ao fim)
framesFlag = 1;

% 7) Flag para ruído (AWGN)
%    0 = sem ruído
%    1 = com ruído
noiseFlag = 1; % Modifique aqui para 1 para rodar com ruído e Monte Carlo

% Parâmetros para o modo avançado (utilizados se noiseFlag == 1):
OnePnDB = -50:2:50;  % Vetor de 1/Pn (dB)
MC = 1000;           % Número de repetições Monte Carlo (pode ser diminuído para teste)

% 8) Flag para normalização e remoção de fundo (v3_norm)
%    0 = Sem normalização / remoção de fundo
%    1 = Com normalização / remoção de fundo e salvamento dos dados para histograma
normFlag = 0;

% Multiplicador para o número de frames de fundo (usado se normFlag == 1)
% Determina a quantidade de frames iniciais a serem usados como imagem de fundo médio (multiplicado por repeatedFrames)
numBackgroundMultiplier = 15;

% 9) Flag para salvar as imagens da ROI detectada (pasta imagesROI)
%    true  = Cria a pasta e salva as imagens de ROI (.jpg) para verificação visual
%    false = Desativa o salvamento das imagens de ROI
salvarImagensROI = false;

% 10) Flag para correção de perspectiva:
%    true  = Ativa (se a ROI não for um retângulo perfeito, aplica a correção de perspectiva)
%    false = Desativada (sempre usa crop normal, convertendo ROIs poligonais em retângulos envolventes)
correcaoPerspectiva = false;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                         PERGUNTAS DO CONSOLE                          %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 1) Pergunta se deseja seguir um checkpoint existente
choice = input('Deseja seguir a partir de um checkpoint existente? (Sim/Não) [Não]: ', 's');
if isempty(choice)
    choice = 'Não';
end
if strcmpi(choice, 'Sim') || strcmpi(choice, 's')
    choice = 'Sim';
else
    choice = 'Não';
end

% 2) Pergunta se deseja carregar coordenadas de ROI a partir de um arquivo CSV de resultados (ex: resultados_ROI.csv)
%    true  = Abre uma janela de seleção para selecionar o CSV e usa suas coordenadas
%    false = Usa as opções de detecção/seleção normais do roiFlag
usarCsvRoiChoice = input('Deseja carregar coordenadas de ROI a partir de um arquivo CSV? (Sim/Não) [Não]: ', 's');
if isempty(usarCsvRoiChoice)
    usarCsvRoiChoice = 'Não';
end
if strcmpi(usarCsvRoiChoice, 'Sim') || strcmpi(usarCsvRoiChoice, 's')
    usarCsvRoi = true;
else
    usarCsvRoi = false;
end

% 3) Pergunta se deseja filtrar vídeos específicos
%    false = Processa todos os vídeos .mp4 da pasta de gravacoes
%    true  = Abre uma interface gráfica para selecionar os vídeos interativamente
filtrarChoice = input('Deseja filtrar vídeos específicos? (Sim/Não) [Não]: ', 's');
if isempty(filtrarChoice)
    filtrarChoice = 'Não';
end
if strcmpi(filtrarChoice, 'Sim') || strcmpi(filtrarChoice, 's')
    filtrarVideos = true;
else
    filtrarVideos = false;
end


% Verifica se a GPU está disponível e se pode ser usada
try
    canUseGPU = (gpuDeviceCount > 0);
catch
    canUseGPU = false;
end
if canUseGPU
    fprintf('GPU detectada com sucesso! Aceleração por GPU ativa.\n');
else
    fprintf('GPU não detectada ou indisponível. Usando processamento paralelo na CPU.\n');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                         GERENCIAMENTO DO CHECKPOINT                   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(choice, 'Sim')
    % Abre caixa de diálogo para selecionar o arquivo de checkpoint (.csv)
    [chkFile, chkPath] = uigetfile(fullfile(scriptDir, 'dadosBER', '**', 'checkpoint_dadosBER.csv'), ...
        'Selecione o arquivo de checkpoint (checkpoint_dadosBER.csv)');
    if isequal(chkFile, 0)
        fprintf('Seleção cancelada pelo usuário. Criando nova pasta de resultados...\n');
        folderName = datestr(now, 'dd_mm_yyyy_HH_MM');
        runDir = fullfile(scriptDir, 'dadosBER', folderName);
        if ~exist(runDir, 'dir'), mkdir(runDir); end
        isCheckpoint = false;
    else
        runDir = chkPath;
        isCheckpoint = true;
        fprintf('Continuando a partir do checkpoint: %s\n', runDir);
    end
else
    folderName = datestr(now, 'dd_mm_yyyy_HH_MM');
    runDir = fullfile(scriptDir, 'dadosBER', folderName);
    if ~exist(runDir, 'dir'), mkdir(runDir); end
    isCheckpoint = false;
end

csvPath = fullfile(runDir, 'checkpoint_dadosBER.csv');
% Header unificado incluindo campos de ruído e normalização
csvHeader = 'video_name,noiseFlag,normFlag,SER,BER,symbolMSE,symbolNMSE,vertical_dimension,horizontal_dimension,status';

% Verifica se os arquivos .mat necessários existem
for fIdx = 1:numel(matFiles)
    matFileLocal = matFiles{fIdx};
    matFileLocalPath = fullfile(scriptDir, matFileLocal);

    if ~exist(matFileLocalPath, 'file')
        error('Arquivo .mat necessário não encontrado: %s', matFileLocalPath);
    end
end

% Inicialização e leitura do arquivo CSV de ROI (resultados_ROI.csv)
roiTable = [];
if usarCsvRoi
    fprintf('Selecione o arquivo de resultados de ROI (.csv)...\n');
    [csvRoiFile, csvRoiPath] = uigetfile(fullfile(scriptDir, 'resultadosROI', '*.csv'), ...
        'Selecione o arquivo de resultados de ROI (resultados_ROI.csv)');
    if isequal(csvRoiFile, 0)
        error('Seleção do arquivo CSV de ROI cancelada pelo usuário. O script não pode continuar com usarCsvRoi = true.');
    else
        csvRoiFullPath = fullfile(csvRoiPath, csvRoiFile);
        fprintf('Carregando coordenadas de ROI do arquivo: %s\n', csvRoiFullPath);
        roiTable = readtable(csvRoiFullPath, 'TextType', 'string');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                       INICIALIZAÇÃO DE DIRETÓRIOS                     %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Cria a pasta principal dadosBER se não existir
dadosBerDir = fullfile(scriptDir, 'dadosBER');
if ~exist(dadosBerDir, 'dir')
    mkdir(dadosBerDir);
end

% Pasta de imagens ROI
imagesRoiDir = fullfile(scriptDir, 'imagesROI');
if salvarImagensROI && ~exist(imagesRoiDir, 'dir')
    mkdir(imagesRoiDir);
end

% Lista todos os vídeos na pasta de gravacoes/
videoFiles = dir(fullfile(videoDir, '*.mp4'));


% Filtragem de teste recomendada pelo usuário via Interface Gráfica:
if filtrarVideos
    videoFiles = selecionarVideosGUI(videoFiles);
end

numVideos = numel(videoFiles);

if numVideos == 0
    error('Nenhum vídeo mp4 encontrado na pasta: %s', videoDir);
end

fprintf('Total de %d vídeos a processar em: %s\n', numVideos, videoDir);

% Lê o arquivo de checkpoint se já existir
records = {};
if exist(csvPath, 'file')
    fid = fopen(csvPath, 'r');
    headerLine = fgetl(fid); % ignora o cabeçalho
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            parts = strsplit(line, ',');
            if ~isempty(parts)
                rec = struct();
                rec.video_name = parts{1};
                if numel(parts) >= 10
                    rec.noiseFlag = str2double(parts{2});
                    rec.normFlag = str2double(parts{3});
                    rec.SER = str2double(parts{4});
                    rec.BER = str2double(parts{5});
                    rec.symbolMSE = str2double(parts{6});
                    rec.symbolNMSE = str2double(parts{7});
                    rec.vertical_dimension = str2double(parts{8});
                    rec.horizontal_dimension = str2double(parts{9});
                    rec.status = parts{10};
                else
                    % Fallback para formato antigo/legado
                    rec.noiseFlag = NaN;
                    rec.normFlag = NaN;
                    rec.SER = NaN;
                    rec.BER = NaN;
                    rec.symbolMSE = NaN;
                    rec.symbolNMSE = NaN;
                    rec.vertical_dimension = NaN;
                    rec.horizontal_dimension = NaN;
                    rec.status = parts{end};
                end
                records{end+1} = rec;
            end
        end
    end
    fclose(fid);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                           LOOP DE PROCESSAMENTO                       %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i = 1:numVideos
    vName = videoFiles(i).name;

    % Verifica se o vídeo já foi processado com sucesso ('ok')
    isOk = false;
    foundIdx = 0;
    for r = 1:numel(records)
        if strcmp(records{r}.video_name, vName)
            foundIdx = r;
            if strcmp(records{r}.status, 'ok')
                isOk = true;
            end
            break;
        end
    end

    if isOk
        fprintf('\n===========================================================================\n');
        fprintf('Vídeo [%d de %d]: %s já processado com status [ok]. Pulando...\n', i, numVideos, vName);
        fprintf('===========================================================================\n');
        continue;
    end

    fprintf('\n===========================================================================\n');
    fprintf('Iniciando processamento do Vídeo [%d de %d]: %s\n', i, numVideos, vName);
    fprintf('===========================================================================\n');

    % Determina e carrega o arquivo .mat correspondente ao vídeo
    info = parseVideoName(vName);
    if info.frames == 5 || ~isempty(strfind(lower(vName), 'f5'))
        matFileLocal = matFileF5;
        matFileLocalPath = fullfile(scriptDir, matFileLocal);
    elseif info.frames == 10 || ~isempty(strfind(lower(vName), 'f10'))
        matFileLocal = matFileF10;
        matFileLocalPath = fullfile(scriptDir, matFileLocal);
    else
        fprintf('\n[AVISO] Nao foi possivel determinar a frequencia (f5/f10) para o video: %s\n', vName);
        fprintf('Selecione o arquivo de parametros .mat correspondente:\n');
        fprintf('1 - %s (F=5)\n', matFileF5);
        fprintf('2 - %s (F=10)\n', matFileF10);
        fprintf('3 - Escolher outro arquivo .mat interativamente\n');

        userOpt = 0;
        while userOpt ~= 1 && userOpt ~= 2 && userOpt ~= 3
            userOpt = input('Digite sua opcao (1, 2 ou 3): ');
            if isempty(userOpt)
                userOpt = 0;
            end
        end

        if userOpt == 1
            matFileLocal = matFileF5;
            matFileLocalPath = fullfile(scriptDir, matFileLocal);
        elseif userOpt == 2
            matFileLocal = matFileF10;
            matFileLocalPath = fullfile(scriptDir, matFileLocal);
        else
            % Abre interface de selecao de arquivo
            fprintf('Selecione o arquivo .mat de parametros...\n');
            [selFile, selPath] = uigetfile(fullfile(scriptDir, 'videosGerados', '*.mat'), ...
                'Selecione o arquivo de parametros .mat');
            if isequal(selFile, 0)
                error('Selecao de arquivo .mat cancelada. Nao e possivel processar o video %s sem parametros.', vName);
            end
            matFileLocal = selFile;
            matFileLocalPath = fullfile(selPath, selFile);
        end
    end

    fprintf('Carregando arquivo de parâmetros .mat: %s...\n', matFileLocal);
    load(matFileLocalPath, ...
        'Sm','V4D_OCC','V4D','S0','S1', 'F', ...
        'Mmax', 'Nmax', 'S', 'P', 'M', 'N', 'K', ...
        'mask', 'scale', 'flag','msg');

    videoFile = fullfile(videoDir, vName);
    [~, videoBaseName, ~] = fileparts(vName);
    roiImgPath = fullfile(imagesRoiDir, [videoBaseName '.jpg']);

    try
        % 1) Leitura do vídeo
        vidObj = VideoReader(videoFile);
        vidObj.CurrentTime = 0;

        realfpsRx = vidObj.FrameRate;
        fpsRx = round(realfpsRx / fpsTx) * fpsTx;
        repeatedFrames = floor(fpsRx/fpsTx);
        desiredTotalFrames = K * F * repeatedFrames;

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj, true);
        fprintf('Total de frames lidos do vídeo: %d\n', numFrames);

        % 2) Seleção da ROI
        if usarCsvRoi
            fprintf('\n--- ROI DO ARQUIVO CSV ---\n');
            idx = find(strcmp(roiTable.video_name, vName));
            if isempty(idx)
                error('Vídeo %s não encontrado no CSV de ROI fornecido.', vName);
            end

            x_tl = roiTable.x_tl(idx);
            y_tl = roiTable.y_tl(idx);
            x_tr = roiTable.x_tr(idx);
            y_tr = roiTable.y_tr(idx);
            x_br = roiTable.x_br(idx);
            y_br = roiTable.y_br(idx);
            x_bl = roiTable.x_bl(idx);
            y_bl = roiTable.y_bl(idx);

            if isnan(x_tl) || isnan(y_tl) || isnan(x_tr) || isnan(y_tr) || ...
                    isnan(x_br) || isnan(y_br) || isnan(x_bl) || isnan(y_bl)
                error('As coordenadas de ROI para o vídeo %s no CSV contêm valores NaN.', vName);
            end

            roiPosition_orig = [
                x_tl, y_tl;
                x_tr, y_tr;
                x_br, y_br;
                x_bl, y_bl
                ];
            fprintf('Coordenadas de ROI carregadas com sucesso a partir do CSV.\n');
        elseif roiFlag == 1
            fprintf('\n--- ROI AUTOMÁTICA ---\n');
            roiPosition_orig = automaticROI_v3(recordedVideo, false);
        elseif roiFlag == 2
            fprintf('\n--- ROI = VÍDEO INTEIRO ---\n');
            roiPosition_orig = fullROI(recordedVideo);
        elseif roiFlag == 3
            fprintf('\n--- ROI MANUAL ---\n');
            roiPosition_orig = manualROIfigure(recordedVideo);
        else
            error('Valor de roiFlag inválido!');
        end

        roiPosition = roiPosition_orig;

        % Salva um JPEG da ROI silenciosamente (sem exibir a figura na tela)
        if salvarImagensROI
            if exist(roiImgPath, 'file')
                delete(roiImgPath);
            end
            fig = figure('Visible', 'off');
            lastFrame = recordedVideo(:, :, :, end);
            imshow(lastFrame, []);
            hold on;
            if size(roiPosition_orig, 1) == 4 && size(roiPosition_orig, 2) == 2
                x_coords = [roiPosition_orig(:, 1); roiPosition_orig(1, 1)];
                y_coords = [roiPosition_orig(:, 2); roiPosition_orig(1, 2)];
                plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
            else
                rectangle('Position', roiPosition_orig, 'EdgeColor', 'r', 'LineWidth', 2);
            end
            hold off;
            print(fig, roiImgPath, '-djpeg');
            close(fig);
            fprintf('Imagem da ROI salva com sucesso em: %s\n', roiImgPath);
        end

        % 3) Recorta os frames
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
                    fprintf('ROI é retângulo perfeito. Crop normal.\n');
                else
                    fprintf('ROI não é retângulo perfeito. Correção de perspectiva aplicada.\n');
                end
            else
                % Se a correção de perspectiva estiver desativada, converte a ROI poligonal
                % para um retângulo envolvente (bounding box) e realiza o crop normal.
                x_coord = min(roiPosition(:, 1));
                y_coord = min(roiPosition(:, 2));
                w_coord = max(roiPosition(:, 1)) - x_coord + 1;
                h_coord = max(roiPosition(:, 2)) - y_coord + 1;
                roiPosition = [x_coord, y_coord, w_coord, h_coord];
                isPerfectRectangle = true;
                fprintf('Correção de perspectiva desativada. Convertendo ROI poligonal para retângulo envolvente.\n');
            end
        end

        if isPerfectRectangle
            croppedVideo = cropVideoFrames(recordedVideo, roiPosition, numFrames);
        else
            croppedVideo = correctPerspective(recordedVideo, roiPosition, numFrames);
        end

        clear recordedVideo;

        % 4) Seleção dos frames de interesse
        if framesFlag == 1
            [timeCroppedVideo, startFrame, endFrame] = selectFramesAutomatically(croppedVideo, desiredTotalFrames, repeatedFrames);
        elseif framesFlag == 2
            timeCroppedVideo = croppedVideo;
        end

        clear croppedVideo;

        % 4.1) Normalização e Remoção de Fundo (se normFlag ativo)
        if normFlag
            % 1. Convertendo os frames para double para evitar estouro/truncamento de valores negativos
            timeCroppedVideo = double(timeCroppedVideo);

            % 2. Calculando a imagem de fundo médio (média dos primeiros frames pretos do timeCroppedVideo)
            numBackgroundFrames = numBackgroundMultiplier * repeatedFrames;
            if numBackgroundFrames > size(timeCroppedVideo, 4)
                numBackgroundFrames = size(timeCroppedVideo, 4);
            end
            backgroundImage = mean(timeCroppedVideo(:, :, :, 1:numBackgroundFrames), 4);

            % Captura o ruído de fundo (níveis de cinza brutos) antes da subtração
            backgroundNoise = timeCroppedVideo(:, :, :, 1:numBackgroundFrames);

            % 3. Subtraindo a imagem de fundo (broadcasting automático no MATLAB)
            timeCroppedVideo = timeCroppedVideo - backgroundImage;

            % % 4. Normalizando globalmente todo o vídeo recortado para a faixa [0, 1]
            % valMin = min(timeCroppedVideo(:));
            % valMax = max(timeCroppedVideo(:));
            % if valMax > valMin
            %     timeCroppedVideo = (timeCroppedVideo - valMin) / (valMax - valMin);
            % else
            %     warning('Impossível normalizar timeCroppedVideo: valMax == valMin.');
            % end
        end

        % 5) Redimensiona o vídeo
        resizedVideo = resizeVideoFrames_v2(timeCroppedVideo, Mmax, Nmax);
        clear timeCroppedVideo;

        % 6) Média de frames repetidos
        finalVideo = meanRepeatedFrames(resizedVideo, repeatedFrames);
        clear resizedVideo;
        V4Daux = finalVideo;
        clear finalVideo;

        % 7) Simulação / Decodificação
        numBlocksI = Mmax/M;
        numBlocksJ = Nmax/N;
        vgray_cell = cell(numBlocksI, numBlocksJ);
        vgrayRx_cell = cell(numBlocksI, numBlocksJ);
        for blci = 1:numBlocksI
            for blcj = 1:numBlocksJ
                [vgray_cell{blci, blcj}, ~] = bloco_extraction(V4D, M, N, F, blci, blcj);
                [vgrayRx_cell{blci, blcj}, ~] = bloco_extraction(V4Daux, M, N, K*F, blci, blcj);
            end
        end

        % Fluxo clean (decodificação sem ruído para obter métricas de referência)
        fprintf('\n--- Decodificação clean (sem ruído) bloco a bloco ---\n');
        SER_clean_blocks = zeros(numBlocksI, numBlocksJ);
        symbolMSE_clean_blocks = zeros(numBlocksI, numBlocksJ);
        symbolNMSE_clean_blocks = zeros(numBlocksI, numBlocksJ);
        Bmod_clean = zeros(S*P, M*N);

        for blci = 1:numBlocksI
            for blcj = 1:numBlocksJ
                vgray_b = vgray_cell{blci, blcj};
                vgrayRx_b = vgrayRx_cell{blci, blcj};

                Aux2 = vgrayRx_b.';
                [erro_S, ~, Bmod_temp, ~] = OCC_Rx(rxAlgorithm, M, N, K, F, scale, vgray_b, Sm, Aux2);
                Bmod_clean = Bmod_temp;

                SER_clean_blocks(blci, blcj) = SER_clean_blocks(blci, blcj) + SER_OCC(Sm, S0, S1, Bmod_temp, P, M, N, S);
                symbolMSE_clean_blocks(blci, blcj) = (norm(Sm - Bmod_temp, 'fro'))^2 / numel(Sm);
                symbolNMSE_clean_blocks(blci, blcj) = erro_S;
            end
        end

        [msg_hat_clean, header_hat_clean, id_hat_clean, vertical_dimension, horizontal_dimension] = ...
            decode_msg(Bmod_clean, S0, S1, P, M, N, S);

        msg_trimmed = msg(2:end, :);
        msg_hat_trimmed_clean = msg_hat_clean(2:end, :);
        bitErrors_clean = sum(msg_trimmed(:) ~= msg_hat_trimmed_clean(:));
        totalBits_clean = numel(msg_hat_trimmed_clean);

        BER_clean = bitErrors_clean / totalBits_clean;
        SER_mean_clean = mean(SER_clean_blocks(:));
        symbolMSE_mean_clean = mean(symbolMSE_clean_blocks(:));
        symbolNMSE_mean_clean = mean(symbolNMSE_clean_blocks(:));

        fprintf('Resultados Clean - SER Médio: %.6f, BER: %.6f, Symbol MSE: %.6e, Symbol NMSE: %.6f\n', ...
            SER_mean_clean, BER_clean, symbolMSE_mean_clean, symbolNMSE_mean_clean);
        fprintf('Dimensões Decodificadas - Vert: %d, Horiz: %d\n', vertical_dimension, horizontal_dimension);

        % Se noiseFlag == 1, rodar também simulação Monte Carlo para varredura de SNR
        if noiseFlag == 1
            lengthOnePnDB = length(OnePnDB);
            BERvals = zeros(lengthOnePnDB, 1);
            SERvals = zeros(lengthOnePnDB, 1);
            symbolMSEvals = zeros(lengthOnePnDB, 1);
            symbolNMSEvals = zeros(lengthOnePnDB, 1);

            if canUseGPU
                % --- CAMINHO ACELERADO POR GPU ---
                % Transferência de parâmetros comuns à GPU
                Sm_gpu = gpuArray(Sm);
                S0_gpu = gpuArray(S0);
                S1_gpu = gpuArray(S1);
                msg_trimmed = msg(2:end, :);
                totalBits = numel(msg_trimmed);

                reachedClean = false;
                for iPn = 1:lengthOnePnDB
                    OnePnLinear = 10^(OnePnDB(iPn)/10);
                    Pn = 1/OnePnLinear;

                    errosTotal = 0;
                    bitsTotal = totalBits * MC;

                    accum_SER = 0;
                    accum_symbolMSE = 0;
                    accum_symbolNMSE = 0;

                    fprintf('  Iniciando Monte Carlo para 1/Pn = %d dB (%d repetições vetorizadas na GPU)...\n', OnePnDB(iPn), MC);

                    % Para cada bloco, calculamos as métricas de forma vetorizada para todos os MC
                    for blci = 1:numBlocksI
                        for blcj = 1:numBlocksJ
                            vgray_b = gpuArray(vgray_cell{blci, blcj});
                            vgrayRx_b = gpuArray(vgrayRx_cell{blci, blcj});

                            % Adiciona o ruído para todas as iterações MC na GPU de forma vetorizada
                            noise = sqrt(Pn) * randn(M*N, K*F, MC, 'gpuArray');
                            Aux2_all = vgrayRx_b.' + noise; % broadcasting automático

                            % Executa o receptor para todos os MC simultaneamente (KRF ou ALS)
                            [erro_S_all, ~, Bmod_all, ~] = OCC_Rx(rxAlgorithm, M, N, K, F, scale, vgray_b, Sm_gpu, Aux2_all);

                            % SER para todos os MC
                            block_SER = SER_OCC(Sm_gpu, S0_gpu, S1_gpu, Bmod_all, P, M, N, S);

                            % symbolMSE para todos os MC
                            block_symbolMSE = sum((Sm_gpu - Bmod_all).^2, [1, 2]) / numel(Sm_gpu);
                            block_symbolMSE = reshape(block_symbolMSE, 1, MC);

                            accum_SER = accum_SER + sum(block_SER);
                            accum_symbolMSE = accum_symbolMSE + sum(block_symbolMSE);
                            accum_symbolNMSE = accum_symbolNMSE + sum(erro_S_all);

                            % Decodificação e BER do último bloco
                            if blci == numBlocksI && blcj == numBlocksJ
                                Bmod_reshaped = reshape(Bmod_all, P, S, M*N, MC);
                                dist0 = sum((Bmod_reshaped - S0_gpu).^2, 1);
                                dist1 = sum((Bmod_reshaped - S1_gpu).^2, 1);
                                msg_hat_all = reshape(dist0 < dist1, S, M*N, MC);

                                msg_hat_trimmed_all = msg_hat_all(2:end, :, :);
                                bitErrors_all = sum(msg_trimmed ~= msg_hat_trimmed_all, [1, 2]);
                                errosTotal = gather(sum(bitErrors_all));
                            end
                        end
                    end

                    numBlocks = numBlocksI * numBlocksJ;
                    totalSamples = numBlocks * MC;

                    BERvals(iPn) = errosTotal / bitsTotal;
                    SERvals(iPn) = gather(accum_SER) / totalSamples;
                    symbolMSEvals(iPn) = gather(accum_symbolMSE) / totalSamples;
                    symbolNMSEvals(iPn) = gather(accum_symbolNMSE) / totalSamples;

                    fprintf('  BER acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), BERvals(iPn));
                    fprintf('  SER acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), SERvals(iPn));
                    fprintf('  Symbol NMSE acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), symbolNMSEvals(iPn));

                    if BERvals(iPn) == 0
                        fprintf('BER atingiu 0. Interrompendo varredura de SNR.\n');
                        break;
                    end

                    if BERvals(iPn) <= BER_clean
                        reachedClean = true;
                    end

                    if reachedClean && iPn > 1
                        if BERvals(iPn) >= BERvals(iPn-1)
                            fprintf('BER atingiu o BER clean (%.6f) e parou de diminuir (atual: %.6f, anterior: %.6f). Interrompendo varredura de SNR e preenchendo o restante.\n', BER_clean, BERvals(iPn), BERvals(iPn-1));
                            BERvals(iPn+1:end) = BERvals(iPn);
                            break;
                        end
                    end
                end
            else
                % --- CAMINHO DE BACKUP NA CPU (PARFOR ORIGINAL) ---
                % Abre o pool de processamento paralelo se necessário
                try
                    poolObj = gcp('nocreate');
                    if isempty(poolObj)
                        fprintf('Inicializando o pool de processamento paralelo...\n');
                        parpool;
                    end
                catch ME
                    fprintf('Aviso: Não foi possível iniciar o pool paralelo. O parfor rodará de forma sequencial ou com configurações padrão.\n');
                    fprintf('Erro: %s\n', ME.message);
                end

                reachedClean = false;
                for iPn = 1:lengthOnePnDB
                    OnePnLinear = 10^(OnePnDB(iPn)/10);
                    Pn = 1/OnePnLinear;
                    errosTotal = 0;
                    bitsTotal  = 0;

                    accum_SER = 0;
                    accum_symbolMSE = 0;
                    accum_symbolNMSE = 0;

                    fprintf('  Iniciando Monte Carlo para 1/Pn = %d dB (%d repetições em paralelo)...\n', OnePnDB(iPn), MC);

                    parfor mcIter = 1:MC
                        Bmod_local = zeros(S*P, M*N);
                        iter_SER = 0;
                        iter_symbolMSE = 0;
                        iter_symbolNMSE = 0;

                        for blci = 1:numBlocksI
                            for blcj = 1:numBlocksJ
                                vgray_b = vgray_cell{blci, blcj};
                                vgrayRx_b = vgrayRx_cell{blci, blcj};

                                Aux2 = vgrayRx_b.';
                                Aux2 = Aux2 + sqrt(Pn) * randn(size(Aux2));

                                [erro_S, ~, Bmod_temp, ~] = OCC_Rx(rxAlgorithm, M, N, K, F, scale, vgray_b, Sm, Aux2);
                                Bmod_local = Bmod_temp;

                                block_SER = SER_OCC(Sm, S0, S1, Bmod_temp, P, M, N, S);
                                block_symbolMSE = (norm(Sm - Bmod_temp, 'fro'))^2 / numel(Sm);
                                block_symbolNMSE = erro_S;

                                iter_SER = iter_SER + block_SER;
                                iter_symbolMSE = iter_symbolMSE + block_symbolMSE;
                                iter_symbolNMSE = iter_symbolNMSE + block_symbolNMSE;
                            end
                        end

                        [msg_hat, ~, ~, ~, ~] = decode_msg(Bmod_local, S0, S1, P, M, N, S);
                        msg_trimmed_local = msg(2:end, :);
                        msg_hat_trimmed = msg_hat(2:end, :);
                        bitErrors = sum(msg_trimmed_local(:) ~= msg_hat_trimmed(:));
                        totalBits = numel(msg_hat_trimmed);

                        errosTotal = errosTotal + bitErrors;
                        bitsTotal  = bitsTotal + totalBits;

                        accum_SER = accum_SER + iter_SER;
                        accum_symbolMSE = accum_symbolMSE + iter_symbolMSE;
                        accum_symbolNMSE = accum_symbolNMSE + iter_symbolNMSE;
                    end

                    numBlocks = numBlocksI * numBlocksJ;
                    totalSamples = numBlocks * MC;

                    BERvals(iPn) = errosTotal / bitsTotal;
                    SERvals(iPn) = accum_SER / totalSamples;
                    symbolMSEvals(iPn) = accum_symbolMSE / totalSamples;
                    symbolNMSEvals(iPn) = accum_symbolNMSE / totalSamples;

                    fprintf('  BER acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), BERvals(iPn));
                    fprintf('  SER acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), SERvals(iPn));
                    fprintf('  Symbol NMSE acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), symbolNMSEvals(iPn));

                    if BERvals(iPn) == 0
                        fprintf('BER atingiu 0. Interrompendo varredura de SNR.\n');
                        break;
                    end

                    if BERvals(iPn) <= BER_clean
                        reachedClean = true;
                    end

                    if reachedClean && iPn > 1
                        if BERvals(iPn) >= BERvals(iPn-1)
                            fprintf('BER atingiu o BER clean (%.6f) e parou de diminuir (atual: %.6f, anterior: %.6f). Interrompendo varredura de SNR e preenchendo o restante.\n', BER_clean, BERvals(iPn), BERvals(iPn-1));
                            BERvals(iPn+1:end) = BERvals(iPn);
                            break;
                        end
                    end
                end
            end
        end

        % 8) Salvamento dos Resultados em arquivo .mat único
        matOutFile = fullfile(runDir, [videoBaseName '_resultado.mat']);
        if noiseFlag == 1
            if normFlag
                save(matOutFile, 'OnePnDB', 'BERvals', 'SERvals', 'symbolMSEvals', 'symbolNMSEvals', ...
                    'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean', ...
                    'backgroundImage', 'backgroundNoise', 'repeatedFrames');
            else
                save(matOutFile, 'OnePnDB', 'BERvals', 'SERvals', 'symbolMSEvals', 'symbolNMSEvals', ...
                    'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean');
            end
        else
            if normFlag
                save(matOutFile, 'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean', ...
                    'backgroundImage', 'backgroundNoise', 'repeatedFrames');
            else
                save(matOutFile, 'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean');
            end
        end
        fprintf('Resultados de processamento salvos em: %s\n', matOutFile);

        rec = struct();
        rec.video_name = vName;
        rec.noiseFlag = noiseFlag;
        rec.normFlag = normFlag;
        rec.SER = SER_mean_clean;
        rec.BER = BER_clean;
        rec.symbolMSE = symbolMSE_mean_clean;
        rec.symbolNMSE = symbolNMSE_mean_clean;
        rec.vertical_dimension = vertical_dimension;
        rec.horizontal_dimension = horizontal_dimension;
        rec.status = 'ok';

        if foundIdx > 0
            records{foundIdx} = rec;
        else
            records{end+1} = rec;
        end

    catch ME
        fprintf('ERRO ao processar o vídeo %s:\n%s\n', vName, ME.message);

        rec = struct();
        rec.video_name = vName;
        rec.noiseFlag = noiseFlag;
        rec.normFlag = normFlag;
        rec.SER = NaN;
        rec.BER = NaN;
        rec.symbolMSE = NaN;
        rec.symbolNMSE = NaN;
        rec.vertical_dimension = NaN;
        rec.horizontal_dimension = NaN;
        rec.status = 'error';

        if foundIdx > 0
            records{foundIdx} = rec;
        else
            records{end+1} = rec;
        end
    end

    % Escreve e atualiza o arquivo CSV de checkpoint
    fid = fopen(csvPath, 'w');
    fprintf(fid, '%s\n', csvHeader);
    for r = 1:numel(records)
        fprintf(fid, '%s,%d,%d,%f,%f,%e,%f,%f,%f,%s\n', ...
            records{r}.video_name, ...
            records{r}.noiseFlag, ...
            records{r}.normFlag, ...
            records{r}.SER, ...
            records{r}.BER, ...
            records{r}.symbolMSE, ...
            records{r}.symbolNMSE, ...
            records{r}.vertical_dimension, ...
            records{r}.horizontal_dimension, ...
            records{r}.status);
    end
    fclose(fid);

    % Limpeza de variáveis para liberar memória
    clear V4Daux Bmod SER symbolMSE symbolNMSE backgroundImage backgroundNoise;
end

fprintf('\nProcessamento de todos os vídeos finalizado!\n');
