function [recordedVideo, numFrames] = readGrayscaleVideo(vidObj, useGPU)
% READGRAYSCALEVIDEO - Lê os frames de um arquivo de vídeo e os converte para escala de cinza.
% Esta função lê sequencialmente todos os frames do objeto de vídeo (VideoReader),
% converte-os para escala de cinza 2D e pré-aloca a matriz 4D resultante com precisão
% single para otimização de RAM/VRAM. Suporta execução com aceleração por GPU se solicitado.
%
% Entradas:
%   vidObj - Objeto de vídeo MATLAB (VideoReader)
%   useGPU - Opcional. Flag booleana para forçar processamento na GPU (padrão: false)
%
% Saídas:
%   recordedVideo - Matriz 4D [altura x largura x 1 x numFrames] em precisão single
%   numFrames     - Número de frames lidos e decodificados com sucesso
    
    if nargin < 2
        useGPU = false;
    end
    
    % Se o usuário solicitou GPU, valida se há hardware compatível disponível
    if useGPU
        try
            gpuDeviceCount;
            if gpuDeviceCount == 0
                warning('GPU solicitada, mas nenhum dispositivo compatível foi detectado. Usando CPU.');
                useGPU = false;
            end
        catch
            warning('Falha ao detectar GPU. Usando CPU.');
            useGPU = false;
        end
    end
    
    % Lê o primeiro frame para obter as dimensões
    firstFrame = readFrame(vidObj);
    [altura, largura, ~] = size(firstFrame);
    
    % Reseta o vídeo para o início
    vidObj.CurrentTime = 0;
    NoF = vidObj.NumFrames;
    
    % Tenta alocar a matriz 4D diretamente em single (e no dispositivo correto)
    try
        if useGPU
            recordedVideo = gpuArray.zeros(altura, largura, 1, NoF, 'single');
        else
            recordedVideo = zeros(altura, largura, 1, NoF, 'single');
        end
    catch ME
        if useGPU
            warning('Falha ao pré-alocar matriz na GPU (VRAM possivelmente insuficiente). Usando CPU. Detalhes: %s', ME.message);
            useGPU = false;
            recordedVideo = zeros(altura, largura, 1, NoF, 'single');
        else
            rethrow(ME);
        end
    end
    
    numFrames = 0;
    lastReportedPercent = -1;
    
    while hasFrame(vidObj)
        fAux = readFrame(vidObj);
        numFrames = numFrames + 1;
        
        if useGPU
            try
                % Converte na GPU e armazena
                fAux_gpu = gpuArray(fAux);
                recordedVideo(:,:,1,numFrames) = single(rgb2gray(fAux_gpu));
            catch ME
                warning('Falha ao processar frame %d na GPU. Continuando na CPU a partir deste ponto. Detalhes: %s', numFrames, ME.message);
                useGPU = false;
                recordedVideo = gather(recordedVideo); % Traz tudo para a CPU
                recordedVideo(:,:,1,numFrames) = single(rgb2gray(fAux));
            end
        else
            % Processamento otimizado na CPU (evitando im2double redundante)
            recordedVideo(:,:,1,numFrames) = single(rgb2gray(fAux));
        end
        
        % Verifica se atingiu um marco de 10%
        percentComplete = floor((numFrames / NoF) * 100);
        if mod(percentComplete, 10) == 0 && percentComplete ~= lastReportedPercent
            fprintf('%d%% concluído (%d frames de %d)\n', percentComplete, numFrames, NoF);
            lastReportedPercent = percentComplete;
        end
    end
    
    % Garante que não exceda NoF
    numFrames = min(numFrames, NoF);
    
    % Corta frames excedentes se houver divergência entre hasFrame e NumFrames
    if numFrames < NoF
        recordedVideo = recordedVideo(:,:,1,1:numFrames);
    end
    
    % Se terminou de processar na GPU, traz de volta para CPU para manter compatibilidade
    if useGPU
        recordedVideo = gather(recordedVideo);
    end
end
