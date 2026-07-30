% LOOP_RECEPCAO_SINCRONIZADO - Script principal para recepção com alinhamento fino por referência (V4D_OCC).
% Este script implementa a cadeia completa de recepção S2C / OCC utilizando
% a nova esteira de sincronização temporal e descarte de quadros de transição:
% 1) Leitura do vídeo capturado em escala de cinza.
% 2) Extração da ROI.
% 3) Média e redução espacial (Mmax x Nmax) antecipada em TODOS os quadros gravados via spatialAveragingROI.
% 4) Sincronização temporal fina por alinhamento com a matriz de referência (V4D_OCC) e descarte de quadros de transição via matchAndAverageReferenceFrames.
% 5) Algoritmo de recepção (OCC-KRF ou OCC-ALS) e decodificação.
% 6) Análise estatística de desempenho (BER, SER, MSE) por simulação Monte Carlo.

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
videoDir = '../28_07';

% 2) Arquivos .mat com os dados do vídeo original
matFileF5 = 'videosGerados\dados_video_Mmax8_Nmax8_M4_N4_F5.mat';
matFileF10 = 'videosGerados\dados_video_Mmax8_Nmax8_M4_N4_F10.mat';
matFiles = {matFileF5, matFileF10};

% 3) Algoritmo de recepção/decodificação:
%    1 = OCC-KRF (Khatri-Rao Factorization)
%    2 = OCC-ALS (Alternating Least Squares)
rxAlgorithm = 1;

% 4) Taxas de quadros
fpsTx = 3;   % Taxa de quadros do vídeo exibido (transmissão)

% 5) Flags de seleção da ROI
%    1 = Seleção automática
%    2 = Usar o vídeo inteiro como ROI
%    3 = Selecionar manualmente
roiFlag = 1;

% 6) Flag para ruído (AWGN)
%    0 = sem ruído
%    1 = com ruído
noiseFlag = 1;

% Parâmetros para o modo avançado (utilizados se noiseFlag == 1):
OnePnDB = -50:2:50;  % Vetor de 1/Pn (dB)
MC = 1000;           % Número de repetições Monte Carlo

% 7) Flag para normalização e remoção de fundo
normFlag = 0;
numBackgroundMultiplier = 15;

% 8) Flag para salvar as imagens da ROI detectada (pasta imagesROI)
salvarImagensROI = false;

% 9) Flag para correção de perspectiva
correcaoPerspectiva = true;

% 10) Caminho para a matriz de calibração da câmera (usada se correcaoPerspectiva = true):
%    String com o caminho do arquivo .m (ex: 'matrizesCalibracao\otsu05\calibracao_20260720_201450_opt.m')
%    '' (vazio) ou false = Mantém a retificação projetiva genérica clássica (sem matriz de calibração)
calibPath = 'matrizesCalibracao\otsu05\calibracao_20260720_201450_opt.m';



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                         PERGUNTAS DO CONSOLE                          %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

choice = input('Deseja seguir a partir de um checkpoint existente? (Sim/Não) [Não]: ', 's');
if isempty(choice), choice = 'Não'; end
if strcmpi(choice, 'Sim') || strcmpi(choice, 's')
    choice = 'Sim';
else
    choice = 'Não';
end

usarCsvRoiChoice = input('Deseja carregar coordenadas de ROI a partir de um arquivo CSV? (Sim/Não) [Não]: ', 's');
if isempty(usarCsvRoiChoice), usarCsvRoiChoice = 'Não'; end
if strcmpi(usarCsvRoiChoice, 'Sim') || strcmpi(usarCsvRoiChoice, 's')
    usarCsvRoi = true;
else
    usarCsvRoi = false;
end

filtrarChoice = input('Deseja filtrar vídeos específicos? (Sim/Não) [Não]: ', 's');
if isempty(filtrarChoice), filtrarChoice = 'Não'; end
if strcmpi(filtrarChoice, 'Sim') || strcmpi(filtrarChoice, 's')
    filtrarVideos = true;
else
    filtrarVideos = false;
end

% Verifica disponibilidade de GPU
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
csvHeader = 'video_name,noiseFlag,normFlag,SER,BER,symbolMSE,symbolNMSE,vertical_dimension,horizontal_dimension,status';

% Verifica se os arquivos .mat necessários existem
for fIdx = 1:numel(matFiles)
    matFileLocalPath = fullfile(scriptDir, matFiles{fIdx});
    if ~exist(matFileLocalPath, 'file')
        error('Arquivo .mat necessário não encontrado: %s', matFileLocalPath);
    end
end

roiTable = [];
if usarCsvRoi
    fprintf('Selecione o arquivo de resultados de ROI (.csv)...\n');
    [csvRoiFile, csvRoiPath] = uigetfile(fullfile(scriptDir, 'resultadosROI', '*.csv'), ...
        'Selecione o arquivo de resultados de ROI (resultados_ROI.csv)');
    if isequal(csvRoiFile, 0)
        error('Seleção do arquivo CSV de ROI cancelada pelo usuário.');
    else
        csvRoiFullPath = fullfile(csvRoiPath, csvRoiFile);
        fprintf('Carregando coordenadas de ROI do arquivo: %s\n', csvRoiFullPath);
        roiTable = readtable(csvRoiFullPath, 'TextType', 'string');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                       INICIALIZAÇÃO DE DIRETÓRIOS                     %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dadosBerDir = fullfile(scriptDir, 'dadosBER');
if ~exist(dadosBerDir, 'dir'), mkdir(dadosBerDir); end

imagesRoiDir = fullfile(scriptDir, 'imagesROI');
if salvarImagensROI && ~exist(imagesRoiDir, 'dir'), mkdir(imagesRoiDir); end

videoFiles = dir(fullfile(videoDir, '*.mp4'));

if filtrarVideos
    videoFiles = selecionarVideosGUI(videoFiles);
end

numVideos = numel(videoFiles);
if numVideos == 0
    error('Nenhum vídeo mp4 encontrado na pasta: %s', videoDir);
end

fprintf('Total de %d vídeos a processar em: %s\n', numVideos, videoDir);

records = {};
if exist(csvPath, 'file')
    fid = fopen(csvPath, 'r');
    headerLine = fgetl(fid);
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
                    rec.noiseFlag = NaN; rec.normFlag = NaN; rec.SER = NaN; rec.BER = NaN;
                    rec.symbolMSE = NaN; rec.symbolNMSE = NaN; rec.vertical_dimension = NaN;
                    rec.horizontal_dimension = NaN; rec.status = parts{end};
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

    info = parseVideoName(vName);
    if info.frames == 5 || ~isempty(strfind(lower(vName), 'f5'))
        matFileLocal = matFileF5;
        matFileLocalPath = fullfile(scriptDir, matFileLocal);
    elseif info.frames == 10 || ~isempty(strfind(lower(vName), 'f10'))
        matFileLocal = matFileF10;
        matFileLocalPath = fullfile(scriptDir, matFileLocal);
    else
        matFileLocal = matFileF5;
        matFileLocalPath = fullfile(scriptDir, matFileLocal);
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

        [recordedVideo, numFrames] = readGrayscaleVideo(vidObj, true);
        fprintf('Total de frames lidos do vídeo: %d\n', numFrames);

        % 2) Seleção da ROI
        if usarCsvRoi
            fprintf('\n--- ROI DO ARQUIVO CSV ---\n');
            idx = find(strcmp(roiTable.video_name, vName));
            if isempty(idx)
                error('Vídeo %s não encontrado no CSV de ROI fornecido.', vName);
            end
            roiPosition_orig = [
                roiTable.x_tl(idx), roiTable.y_tl(idx);
                roiTable.x_tr(idx), roiTable.y_tr(idx);
                roiTable.x_br(idx), roiTable.y_br(idx);
                roiTable.x_bl(idx), roiTable.y_bl(idx)
                ];
        elseif roiFlag == 1
            fprintf('\n--- ROI AUTOMÁTICA ---\n');
            roiPosition_orig = automaticROI_v2(recordedVideo, false, 0.5);
        elseif roiFlag == 2
            fprintf('\n--- ROI = VÍDEO INTEIRO ---\n');
            roiPosition_orig = fullROI(recordedVideo);
        elseif roiFlag == 3
            fprintf('\n--- ROI MANUAL ---\n');
            roiPosition_orig = manualROIfigure(recordedVideo);
        end

        roiPosition = roiPosition_orig;

        % Salva JPEG da ROI se solicitado
        if salvarImagensROI
            if exist(roiImgPath, 'file'), delete(roiImgPath); end
            fig = figure('Visible', 'off');
            imshow(recordedVideo(:, :, :, end), []); hold on;
            if size(roiPosition_orig, 1) == 4
                plot([roiPosition_orig(:, 1); roiPosition_orig(1, 1)], [roiPosition_orig(:, 2); roiPosition_orig(1, 2)], 'r-', 'LineWidth', 2);
            else
                rectangle('Position', roiPosition_orig, 'EdgeColor', 'r', 'LineWidth', 2);
            end
            hold off;
            print(fig, roiImgPath, '-djpeg'); close(fig);
        end

        % 3) Média e Redução Espacial Antecipada em TODOS os frames (spatialAveragingROI)
        fprintf('\n--- REDUÇÃO ESPACIAL ANTECIPADA (Mmax x Nmax = %dx%d) ---\n', Mmax, Nmax);
        resizedVideoAll = spatialAveragingROI(recordedVideo, roiPosition, Mmax, Nmax, correcaoPerspectiva, 'center_mean', calibPath);
        clear recordedVideo;

        % 4) Sincronização Temporal Fina por Referência (V4D_OCC) + Descarte de Quadros de Transição
        fprintf('\n--- SINCRONIZAÇÃO TEMPORAL POR VÍDEO DE REFERÊNCIA (V4D_OCC) ---\n');
        [finalVideo, alignmentInfo] = matchAndAverageReferenceFrames(resizedVideoAll, V4D_OCC, repeatedFrames);
        clear resizedVideoAll;

        V4Daux = finalVideo;
        clear finalVideo;

        % 5) Simulação / Decodificação
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

        % Decodificação clean (sem ruído)
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

        % Monte Carlo sob ruído (se noiseFlag == 1)
        if noiseFlag == 1
            lengthOnePnDB = length(OnePnDB);
            BERvals = zeros(lengthOnePnDB, 1);
            SERvals = zeros(lengthOnePnDB, 1);
            symbolMSEvals = zeros(lengthOnePnDB, 1);
            symbolNMSEvals = zeros(lengthOnePnDB, 1);

            if canUseGPU
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
                    accum_SER = 0; accum_symbolMSE = 0; accum_symbolNMSE = 0;

                    fprintf('  Iniciando Monte Carlo para 1/Pn = %d dB (%d repetições vetorizadas na GPU)...\n', OnePnDB(iPn), MC);

                    for blci = 1:numBlocksI
                        for blcj = 1:numBlocksJ
                            vgray_b = gpuArray(vgray_cell{blci, blcj});
                            vgrayRx_b = gpuArray(vgrayRx_cell{blci, blcj});

                            noise = sqrt(Pn) * randn(M*N, K*F, MC, 'gpuArray');
                            Aux2_all = vgrayRx_b.' + noise;

                            [erro_S_all, ~, Bmod_all, ~] = OCC_Rx(rxAlgorithm, M, N, K, F, scale, vgray_b, Sm_gpu, Aux2_all);

                            block_SER = SER_OCC(Sm_gpu, S0_gpu, S1_gpu, Bmod_all, P, M, N, S);
                            block_symbolMSE = sum((Sm_gpu - Bmod_all).^2, [1, 2]) / numel(Sm_gpu);
                            block_symbolMSE = reshape(block_symbolMSE, 1, MC);

                            accum_SER = accum_SER + sum(block_SER);
                            accum_symbolMSE = accum_symbolMSE + sum(block_symbolMSE);
                            accum_symbolNMSE = accum_symbolNMSE + sum(erro_S_all);

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

                    if BERvals(iPn) == 0
                        fprintf('BER atingiu 0. Interrompendo varredura de SNR.\n');
                        break;
                    end

                    if BERvals(iPn) <= BER_clean, reachedClean = true; end
                    if reachedClean && iPn > 1
                        if BERvals(iPn) >= BERvals(iPn-1)
                            BERvals(iPn+1:end) = BERvals(iPn);
                            break;
                        end
                    end
                end
            else
                % CPU parfor
                try
                    poolObj = gcp('nocreate');
                    if isempty(poolObj), parpool; end
                catch ME
                end

                reachedClean = false;
                for iPn = 1:lengthOnePnDB
                    OnePnLinear = 10^(OnePnDB(iPn)/10);
                    Pn = 1/OnePnLinear;
                    errosTotal = 0; bitsTotal = 0;
                    accum_SER = 0; accum_symbolMSE = 0; accum_symbolNMSE = 0;

                    fprintf('  Iniciando Monte Carlo para 1/Pn = %d dB (%d repetições em paralelo)...\n', OnePnDB(iPn), MC);

                    parfor mcIter = 1:MC
                        Bmod_local = zeros(S*P, M*N);
                        iter_SER = 0; iter_symbolMSE = 0; iter_symbolNMSE = 0;

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

                    if BERvals(iPn) == 0, break; end
                    if BERvals(iPn) <= BER_clean, reachedClean = true; end
                    if reachedClean && iPn > 1
                        if BERvals(iPn) >= BERvals(iPn-1)
                            BERvals(iPn+1:end) = BERvals(iPn);
                            break;
                        end
                    end
                end
            end
        end

        % Salvamento dos Resultados
        matOutFile = fullfile(runDir, [videoBaseName '_resultado_sincronizado.mat']);
        if noiseFlag == 1
            save(matOutFile, 'OnePnDB', 'BERvals', 'SERvals', 'symbolMSEvals', 'symbolNMSEvals', ...
                'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean', 'alignmentInfo');
        else
            save(matOutFile, 'BER_clean', 'SER_mean_clean', 'symbolMSE_mean_clean', 'symbolNMSE_mean_clean', 'alignmentInfo');
        end
        fprintf('Resultados salvos em: %s\n', matOutFile);

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
        rec.SER = NaN; rec.BER = NaN; rec.symbolMSE = NaN; rec.symbolNMSE = NaN;
        rec.vertical_dimension = NaN; rec.horizontal_dimension = NaN; rec.status = 'error';

        if foundIdx > 0
            records{foundIdx} = rec;
        else
            records{end+1} = rec;
        end
    end

    % Atualiza CSV de checkpoint
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

    clear V4Daux Bmod SER symbolMSE symbolNMSE;
end

fprintf('\nProcessamento de todos os vídeos finalizado com sucesso!\n');
