% LOOP_IOU - Script para avaliação do desempenho de detecção de ROI em condições de ruído.
% Este script realiza simulações Monte Carlo adicionando ruído Gaussiano AWGN
% temporal nos pixels de vídeo capturados. Ele calcula a variância de cada pixel e,
% em seguida, aplica a segmentação por limiarização de Otsu e morfologia matemática
% para encontrar a ROI ruidosa. Em seguida, calcula a métrica de Interseção sobre
% União (IoU) entre a ROI ruidosa estimada e a ROI limpa de referência carregada do
% CSV ou selecionada manualmente, traçando uma curva de acurácia de detecção em
% função do nível de ruído (1/Pn).

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

% 1) Diretório contendo as gravações de vídeo
videoDir = '../gravacoes_07_07';


% 2) Flags de seleção da ROI
%    1 = Selecionar manualmente via drawrectangle
%    2 = Usar o vídeo inteiro como ROI (nenhum recorte)
%    3 = Seleção automática (detecta a região que varia) - RECOMENDADO PARA AUTOMATIZAÇÃO
%    4 = ROI estática fixa de teste
roiFlag = 3;

% Flag para carregar coordenadas de ROI a partir de um arquivo CSV de resultados (ex: resultados_ROI.csv)
%    true  = Abre uma janela de seleção para selecionar o CSV e usa suas coordenadas
%    false = Usa as opções de detecção/seleção normais do roiFlag
usarCsvRoi = true;

% 3) Parâmetros para a simulação com ruído (AWGN):
OnePnDB_base = -45:0.2:50;  % Vetor de 1/Pn (dB)
MC = 100;           % Número de repetições Monte Carlo (pode ser diminuído para teste)

% 4) Flag e lista para filtrar vídeos específicos
filtrarVideos = true;
videosParaProcessar = { ...
    '1.60-1-f5_dark.mp4', ...
    '1.60-3-f5_dark.mp4', ...
    '1.60-5-f5_dark.mp4', ...
    '1.90-1-f5_dark.mp4', ...
    '1.90-3-f5_dark.mp4', ...
    '1.90-5-f5_dark.mp4', ...
    '2.20-1-f5_dark.mp4', ...
    '2.20-3-f5_dark.mp4', ...
    '2.20-5-f5_dark.mp4', ...
    '2.50-1-f5_dark.mp4', ...
    '2.50-3-f5_dark.mp4', ...
    '2.50-5-f5_dark.mp4', ...
    '2.80-1-f5_dark.mp4', ...
    '2.80-3-f5_dark.mp4', ...
    '2.80-5-f5_dark.mp4', ...
    '3.10-1-f5_dark.mp4', ...
    '3.10-3-f5_dark.mp4', ...
    '3.10-5-f5_dark.mp4', ...
    '3.40-1-f5_dark.mp4', ...
    '3.40-3-f5_dark.mp4', ...
    '3.40-5-f5_dark.mp4' ...
    };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                         GERENCIAMENTO DO CHECKPOINT                   %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Pergunta se deseja seguir um checkpoint existente
choice = input('Deseja seguir a partir de um checkpoint existente? (Sim/Não) [Não]: ', 's');
if isempty(choice)
    choice = 'Não';
end
if strcmpi(choice, 'Sim') || strcmpi(choice, 's')
    choice = 'Sim';
else
    choice = 'Não';
end

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
csvHeader = 'video_name,status';

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

% Lista todos os vídeos na pasta de gravacoes/
videoFiles = dir(fullfile(videoDir, '*.mp4'));

% Filtragem de vídeos:
if filtrarVideos
    keepIdx = ismember({videoFiles.name}, videosParaProcessar);
    videoFiles = videoFiles(keepIdx);
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
                rec.status = parts{end};
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

    videoFile = fullfile(videoDir, vName);
    [~, videoBaseName, ~] = fileparts(vName);

    try
        % 1) Leitura do vídeo
        vidObj = VideoReader(videoFile);
        vidObj.CurrentTime = 0;

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj,true);
        fprintf('Total de frames lidos do vídeo: %d\n', numFrames);
        recordedVideo = single(recordedVideo); % Converte para single precision para economizar memória (RAM e VRAM)
        [altura, largura, ~, ~] = size(recordedVideo);

        % 2) Seleção da ROI Limpa
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

            roiPosition_orig_clean = [
                x_tl, y_tl;
                x_tr, y_tr;
                x_br, y_br;
                x_bl, y_bl
                ];
            fprintf('Coordenadas de ROI carregadas com sucesso a partir do CSV.\n');
        elseif roiFlag == 1
            fprintf('\n--- ROI MANUAL ---\n');
            roiPosition_orig_clean = manualROIfigure(recordedVideo);
        elseif roiFlag == 2
            fprintf('\n--- ROI = VÍDEO INTEIRO ---\n');
            roiPosition_orig_clean = fullROI(recordedVideo);
        elseif roiFlag == 3
            fprintf('\n--- ROI AUTOMÁTICA ---\n');
            roiPosition_orig_clean = automaticROI_v2(recordedVideo, false);
        elseif roiFlag == 4
            roiPosition_orig_clean = [438.523696203079, 600.600218915312, 50.1333354146174, 51.8509657500218];
        else
            error('Valor de roiFlag inválido!');
        end

        % Computa a máscara binária da ROI limpa
        if numel(roiPosition_orig_clean) == 4
            x_c = roiPosition_orig_clean(1);
            y_c = roiPosition_orig_clean(2);
            w_c = roiPosition_orig_clean(3);
            h_c = roiPosition_orig_clean(4);
            vertices_clean = [x_c, y_c; x_c+w_c, y_c; x_c+w_c, y_c+h_c; x_c, y_c+h_c];
        else
            vertices_clean = roiPosition_orig_clean;
        end
        mask_clean = poly2mask(vertices_clean(:, 1), vertices_clean(:, 2), altura, largura);

        % Calcular a variância limpa do vídeo
        variance_clean = var(recordedVideo, 0, 4);
        variance_clean = variance_clean(:, :, 1, 1);

        % Simulação para obter IoU sob varredura de ruído
        OnePnDB = OnePnDB_base;
        lengthOnePnDB = length(OnePnDB);
        IoUvals = zeros(lengthOnePnDB, MC);

        % Detecta se há GPU disponível e compatível com gpuArray
        try
            gpuDeviceCount;
            canUseGPU = (gpuDeviceCount > 0);
        catch
            canUseGPU = false;
        end
        if canUseGPU
            fprintf('GPU detectada. Usando aceleração por GPU para geração de ruído e cálculo da variância.\n');
        else
            fprintf('GPU não detectada ou indisponível. Usando processador principal (CPU).\n');
        end

        % Se GPU estiver ativa, tenta enviar a variância limpa para a GPU
        variance_clean_gpu = [];
        if canUseGPU
            try
                variance_clean_gpu = gpuArray(variance_clean);
            catch ME
                canUseGPU = false;
                fprintf('  Falha ao enviar variância para a GPU. Revertendo para CPU. Detalhes: %s\n', ME.message);
            end
        end

        for iPn = 1:lengthOnePnDB
            OnePnLinear = 10^(OnePnDB(iPn)/10);
            Pn = 1/OnePnLinear;
            iou_temp = zeros(1, MC);

            fprintf('  Iniciando cálculo de IoU para 1/Pn = %d dB (%d repetições)...\n', OnePnDB(iPn), MC);

            reportStep = max(1, round(MC / 10));
            if canUseGPU
                for mcIter = 1:MC
                    iou_temp(mcIter) = run_mc_iteration(variance_clean_gpu, Pn, numFrames, mask_clean, altura, largura, true);
                    if mod(mcIter, reportStep) == 0 || mcIter == MC
                        fprintf('    Progresso Monte Carlo: %d%% (%d/%d repetições concluídas).\n', round(mcIter/MC*100), mcIter, MC);
                    end
                end
            else
                for mcIter = 1:MC
                    iou_temp(mcIter) = run_mc_iteration(variance_clean, Pn, numFrames, mask_clean, altura, largura, false);
                    if mod(mcIter, reportStep) == 0 || mcIter == MC
                        fprintf('    Progresso Monte Carlo: %d%% (%d/%d repetições concluídas).\n', round(mcIter/MC*100), mcIter, MC);
                    end
                end
            end

            IoUvals(iPn, :) = iou_temp;
            fprintf('  Mean IoU acumulado em 1/Pn [dB] %d dB = %.6f\n', OnePnDB(iPn), mean(iou_temp));

            if mean(iou_temp) >= 0.99
                fprintf('Mean IoU atingiu 0.99. Interrompendo varredura de 1/Pn.\n');
                break;
            end
        end

        % Salvamento dos Resultados em arquivo .mat único
        matOutFile = fullfile(runDir, [videoBaseName '_resultado.mat']);

        % Trunca os vetores para o tamanho real processado
        if exist('iPn', 'var') && iPn > 0
            OnePnDB_save = OnePnDB(1:iPn);
            IoUvals_save = IoUvals(1:iPn, :);
        else
            OnePnDB_save = OnePnDB;
            IoUvals_save = IoUvals;
        end

        % Valores dummy/placeholder para compatibilidade com o plot_ber_gui_Completo
        BERvals = NaN(size(OnePnDB_save));
        SERvals = NaN(size(OnePnDB_save));
        symbolMSEvals = NaN(size(OnePnDB_save));
        symbolNMSEvals = NaN(size(OnePnDB_save));
        BER_clean = NaN;
        SER_mean_clean = NaN;
        symbolMSE_mean_clean = NaN;
        symbolNMSE_mean_clean = NaN;
        startFrame_clean = 1;
        endFrame_clean = numFrames;

        % Para salvar com os nomes corretos esperados pelo GUI:
        OnePnDB = OnePnDB_save;
        IoUvals = IoUvals_save;

        save(matOutFile, 'OnePnDB', 'IoUvals', 'roiPosition_orig_clean', ...
            'BERvals', 'SERvals', 'symbolMSEvals', 'symbolNMSEvals', ...
            'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean', ...
            'startFrame_clean', 'endFrame_clean');

        fprintf('Resultados de processamento salvos em: %s\n', matOutFile);

        rec = struct();
        rec.video_name = vName;
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
        fprintf(fid, '%s,%s\n', ...
            records{r}.video_name, ...
            records{r}.status);
    end
    fclose(fid);

    % Limpeza de variáveis para liberar memória
    clear recordedVideo IoUvals;
end

fprintf('\nProcessamento de todos os vídeos finalizado!\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                         FUNÇÕES LOCAIS OTIMIZADAS                     %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function iou_iter = run_mc_iteration(variance_clean, Pn, numFrames, mask_clean, altura, largura, useGPU)
try
    % 1) Calcular a imagem de variância ruidosa usando modelo matemático 2D
    varianceImage = calculateVarianceImage(variance_clean, Pn, numFrames, useGPU);

    % 2) Detectar a ROI a partir da imagem de variância
    roiPosition_orig_noisy = automaticROI_from_variance(varianceImage);

    % 3) Gerar a máscara da ROI ruidosa
    if numel(roiPosition_orig_noisy) == 4
        x_n = roiPosition_orig_noisy(1);
        y_n = roiPosition_orig_noisy(2);
        w_n = roiPosition_orig_noisy(3);
        h_n = roiPosition_orig_noisy(4);
        vertices_noisy = [x_n, y_n; x_n+w_n, y_n; x_n+w_n, y_n+h_n; x_n, y_n+h_n];
    else
        vertices_noisy = roiPosition_orig_noisy;
    end
    mask_noisy = poly2mask(vertices_noisy(:, 1), vertices_noisy(:, 2), altura, largura);

    % 4) Calcular IoU
    intersection = sum(mask_clean & mask_noisy, 'all');
    union_val = sum(mask_clean | mask_noisy, 'all');
    if union_val == 0
        iou_iter = 0;
    else
        iou_iter = intersection / union_val;
    end
catch
    % Se falhar na detecção devido a ruído excessivo, assume IoU = 0 em vez de travar
    iou_iter = 0;
end
end

function varianceImage = calculateVarianceImage(variance_clean, Pn, numFrames, useGPU)
% Simulação direta 2D usando a distribuição exata da variância amostral
% sob ruído branco Gaussiano:
% s^2_y = (Pn / T) * ( (Z1 + sqrt(T * s^2_x / Pn))^2 + W )
% onde W ~ chi2(T-2) e Z1 ~ N(0,1).
% Usamos a aproximação normal de alta qualidade para W: W ~ max(0, (T-2) + sqrt(2*(T-2))*Z2)

if useGPU
    try
        Z1 = gpuArray.randn(size(variance_clean), 'single');
        Z2 = gpuArray.randn(size(variance_clean), 'single');

        W = (numFrames - 2) + sqrt(2 * (numFrames - 2)) * Z2;
        W = max(W, 0);

        lambda = numFrames * max(variance_clean, 0) / Pn;
        varianceImage = (Pn / numFrames) * ( (Z1 + sqrt(lambda)).^2 + W );
        varianceImage = gather(varianceImage);
    catch
        % Fallback para CPU em caso de erro na GPU
        Z1 = randn(size(variance_clean), 'single');
        Z2 = randn(size(variance_clean), 'single');
        W = (numFrames - 2) + sqrt(2 * (numFrames - 2)) * Z2;
        W = max(W, 0);
        lambda = numFrames * max(variance_clean, 0) / Pn;
        varianceImage = (Pn / numFrames) * ( (Z1 + sqrt(lambda)).^2 + W );
    end
else
    Z1 = randn(size(variance_clean), 'single');
    Z2 = randn(size(variance_clean), 'single');
    W = (numFrames - 2) + sqrt(2 * (numFrames - 2)) * Z2;
    W = max(W, 0);
    lambda = numFrames * max(variance_clean, 0) / Pn;
    varianceImage = (Pn / numFrames) * ( (Z1 + sqrt(lambda)).^2 + W );
end
end

function roiPosition = automaticROI_from_variance(varianceImage)
% Normaliza a variância e aplica thresholding de Otsu
varianceNorm = varianceImage / max(varianceImage(:));
level = graythresh(varianceNorm);
threshold = level * max(varianceImage(:));
movingPixels = varianceImage > threshold;

% Remove pequenas áreas (ruído) com morfologia
movingPixels = bwareaopen(movingPixels, 50);

% Encontra o maior componente conectado
cc = bwconncomp(movingPixels);
if cc.NumObjects == 0
    error('Nenhum componente conectado encontrado. Ajuste o limiar ou verifique os frames.');
end
numPixels = cellfun(@numel, cc.PixelIdxList);
[~, idx] = max(numPixels);
largestComponent = false(size(movingPixels));
largestComponent(cc.PixelIdxList{idx}) = true;

% Encontra as coordenadas (row, col) de todos os pixels na máscara
[rows, cols] = find(largestComponent);
if isempty(rows)
    error('Nenhum pixel em movimento detectado após filtragem.');
end

% Calcula as métricas de soma e diferença
soma_coords = cols + rows;
diff_coords = cols - rows;

% Encontra os índices dos pontos extremos
[~, idx_tl] = min(soma_coords);
[~, idx_br] = max(soma_coords);
[~, idx_tr] = max(diff_coords);
[~, idx_bl] = min(diff_coords);

v_tl = [cols(idx_tl), rows(idx_tl)]; % Superior-Esquerdo (Top-Left)
v_tr = [cols(idx_tr), rows(idx_tr)]; % Superior-Direito (Top-Right)
v_br = [cols(idx_br), rows(idx_br)]; % Inferior-Direito (Bottom-Right)
v_bl = [cols(idx_bl), rows(idx_bl)]; % Inferior-Esquerdo (Bottom-Left)

roiPosition = [v_tl;
    v_tr;
    v_br;
    v_bl];
end
