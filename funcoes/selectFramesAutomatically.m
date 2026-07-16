function [timeCroppedVideo, startFrame, endFrame] = selectFramesAutomatically(croppedVideo, desiredTotalFrames, repeatedFrames)
% SELECTFRAMESAUTOMATICALLY - Sincronização temporal e seleção automática de frames.
% Esta função analisa a variação temporal de pixels para detectar o início e o fim da
% transmissão (Downlink). Em seguida, executa um algoritmo de alinhamento de fase fina
% (Phase Alignment) baseado no período de repetição de quadros (repeatedFrames) para
% selecionar o melhor ponto de amostragem temporal para posterior processamento.
%
% Entradas:
%   croppedVideo       - Matriz 4D com os frames do vídeo recortado
%   desiredTotalFrames - Número total de frames nominal do bloco de vídeo original
%   repeatedFrames     - Número de vezes que cada frame é duplicado na gravação
%
% Saídas:
%   timeCroppedVideo   - Matriz 4D com o bloco sincronizado temporalmente
%   startFrame         - Índice inicial de frame selecionado
%   endFrame           - Índice final de frame selecionado
    
    % Inicializa a matriz de diferenças entre frames consecutivos
    frameDiff = zeros(size(croppedVideo, 4) - 1, 1);
    
    % Calcula as diferenças entre frames consecutivos
    for i = 1:(size(croppedVideo, 4) - 1)
        % Calcula a diferença absoluta entre o frame atual e o próximo
        diffVal = abs(croppedVideo(:,:,1,i+1) - croppedVideo(:,:,1,i));
        frameDiff(i) = sum(diffVal(:));
    end
    
    % Normaliza as diferenças
    if max(frameDiff) > 0
        frameDiffNorm = frameDiff / max(frameDiff);
    else
        frameDiffNorm = zeros(size(frameDiff));
    end
    
    % Limiar de variação significativa
    largeVarThreshold = 0.20; 
    candidateIndices = find(frameDiffNorm > largeVarThreshold);
    
    % Define o frame final com base na variação (detecção grosseira)
    if isempty(candidateIndices)
        warning('Nenhuma variação significativa encontrada. Usando todo o vídeo.');
        endFrame = size(croppedVideo, 4);
        startFrame = endFrame - (desiredTotalFrames - 1);
        if startFrame < 1, startFrame = 1; end
    else
        endTransition = candidateIndices(end) + repeatedFrames;
        roughStart = endTransition - desiredTotalFrames + 1;
        
        % Sincronização Fina por Alinhamento de Fase (Phase Alignment)
        R = repeatedFrames;
        
        % Janela de avaliação interna para evitar efeitos de borda
        w_start = roughStart + 10;
        w_end = roughStart + desiredTotalFrames - 11;
        
        % Garante limites válidos para a janela
        w_start = max(1, w_start);
        w_end = min(length(frameDiff), w_end);
        
        sumDiff = zeros(R, 1);
        for p = 0:(R-1)
            t_indices = w_start:w_end;
            % Seleciona índices que NÃO correspondem a transições
            non_trans_t = t_indices(mod(t_indices - p, R) ~= 0);
            sumDiff(p+1) = sum(frameDiff(non_trans_t));
        end
        
        [~, min_idx] = min(sumDiff);
        p_trans = min_idx - 1;
        
        % O startFrame sincronizado deve satisfazer: mod(startFrame - 1, R) == p_trans
        target_mod = mod(p_trans + 1, R);
        
        % Encontra o startFrame mais próximo de roughStart que obedece ao padrão de fase
        candidates = (roughStart - R) : (roughStart + R);
        [~, best_idx] = min(abs(candidates - roughStart) + (mod(candidates, R) ~= target_mod) * 1e6);
        startFrame = candidates(best_idx);
        
        if startFrame < 1
            startFrame = 1;
        end
        
        endFrame = startFrame + desiredTotalFrames - 1;
        if endFrame > size(croppedVideo, 4)
            endFrame = size(croppedVideo, 4);
            startFrame = endFrame - (desiredTotalFrames - 1);
            if startFrame < 1, startFrame = 1; end
        end
    end
    
    % Exibe os frames selecionados
    fprintf('Frames de interesse (Sincronizados): startFrame=%d, endFrame=%d (total=%d)\n', ...
        startFrame, endFrame, endFrame - startFrame + 1);
        
    % Seleciona os frames de interesse do vídeo recortado
    if endFrame >= startFrame
        timeCroppedVideo = croppedVideo(:,:,:, startFrame:endFrame);
    else
        timeCroppedVideo = croppedVideo;
    end
end
