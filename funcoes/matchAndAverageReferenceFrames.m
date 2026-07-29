function [finalVideo, alignmentInfo] = matchAndAverageReferenceFrames(resizedVideo, V_ref, repeatedFrames, startFrameCoarse, endFrameCoarse)
% MATCHANDAVERAGEREFERENCEFRAMES - Sincronização temporal fina e descarte de quadros de transição por comparação com o vídeo original de referência.
%
% Entradas:
%   resizedVideo       - Matriz 4D [Mmax x Nmax x 1 x numCamFrames] do vídeo gravado reduzido espacialmente.
%   V_ref              - Matriz 3D [Mmax x Nmax x Ntx] ou 4D [Mmax x Nmax x 1 x Ntx] contendo os quadros originais transmitidos (V4D_OCC).
%   repeatedFrames     - Número nominal de repetições por frame (fpsRx / fpsTx, ex: 10).
%   startFrameCoarse   - (Opcional) Índice inicial aproximado da transmissão.
%   endFrameCoarse     - (Opcional) Índice final aproximado da transmissão.
%
% Saídas:
%   finalVideo         - Matriz 4D [Mmax x Nmax x 1 x Ntx] com os quadros perfeitamente alinhados e integrados por média.
%   alignmentInfo      - Estrutura com diagnóstico do alinhamento (frames mantidos, similaridade, etc.).

if nargin < 3 || isempty(repeatedFrames)
    repeatedFrames = 10;
end

% Ajusta dimensões de V_ref para [Mmax x Nmax x Ntx]
if ndims(V_ref) == 4
    V_ref_3d = squeeze(V_ref);
else
    V_ref_3d = V_ref;
end

Mmax = size(resizedVideo, 1);
Nmax = size(resizedVideo, 2);
numCamFrames = size(resizedVideo, 4);
Ntx = size(V_ref_3d, 3);

% Converte para double
resizedVideo_dbl = double(resizedVideo);
V_ref_dbl = double(V_ref_3d);

% 1. Normalização Z-Score por quadro (evita variações de brilho e offset da câmera)
Y_norm = zeros(Mmax * Nmax, numCamFrames);
for t = 1:numCamFrames
    frame = resizedVideo_dbl(:, :, 1, t);
    mu = mean(frame(:));
    sig = std(frame(:));
    if sig < 1e-6, sig = 1e-6; end
    Y_norm(:, t) = (frame(:) - mu) / sig;
end

V_norm = zeros(Mmax * Nmax, Ntx);
for k = 1:Ntx
    frame = V_ref_dbl(:, :, k);
    mu = mean(frame(:));
    sig = std(frame(:));
    if sig < 1e-6, sig = 1e-6; end
    V_norm(:, k) = (frame(:) - mu) / sig;
end

% 2. Matriz de similaridade por Correção Cruzada Normalizada (NCC)
% S(t, k) in [-1, 1]
S = (Y_norm' * V_norm) / (Mmax * Nmax);

% 3. Definição da janela de busca temporal com margem de segurança
searchMargin = round(3 * repeatedFrames); % Margem de 3 blocos para trás/frente

if nargin >= 4 && ~isempty(startFrameCoarse) && ~isempty(endFrameCoarse)
    tStart = max(1, startFrameCoarse - searchMargin);
    tEnd   = min(numCamFrames, endFrameCoarse + searchMargin);
else
    % Estimação grosseira se não fornecida: busca pico do 1º quadro e pico do último
    [~, bestStart] = max(S(:, 1));
    [~, bestEnd]   = max(S(:, Ntx));
    
    if bestEnd <= bestStart
        bestEnd = min(numCamFrames, bestStart + Ntx * repeatedFrames);
    end
    
    tStart = max(1, bestStart - searchMargin);
    tEnd   = min(numCamFrames, bestEnd + searchMargin);
end

tIndices = tStart:tEnd;
T_search = length(tIndices);

if T_search < Ntx
    warning('Janela de busca (%d frames) é menor que Ntx (%d frames). Ajustando limites.', T_search, Ntx);
    tStart = 1;
    tEnd = numCamFrames;
    tIndices = tStart:tEnd;
    T_search = length(tIndices);
end

% 4. Alinhamento Cronológico Monotônico via Programação Dinâmica (Viterbi)
% D(i, k) armazena a melhor pontuação acumulada para a sub-sequência tIndices(1:i) terminando no quadro de ref k
D = -inf(T_search, Ntx);
backtrack = zeros(T_search, Ntx);

% Condições iniciais no 1º quadro de busca (permite iniciar em k=1)
D(1, 1) = S(tIndices(1), 1);

for i = 2:T_search
    t = tIndices(i);
    for k = 1:Ntx
        % Transições permitidas: k (permanecer no mesmo frame) ou k-1 (avançar para o próximo frame)
        prev_same = D(i-1, k);
        if k > 1
            prev_next = D(i-1, k-1);
        else
            prev_next = -inf;
        end
        
        if prev_same >= prev_next
            D(i, k) = prev_same + S(t, k);
            backtrack(i, k) = k;
        else
            D(i, k) = prev_next + S(t, k);
            backtrack(i, k) = k - 1;
        end
    end
end

% Reconstrução do caminho ótimo (backtracking)
k_opt = zeros(T_search, 1);
% Encontra o melhor ponto de término no último quadro da janela de busca
[~, best_k_final] = max(D(T_search, :));
current_k = best_k_final;

for i = T_search:-1:1
    k_opt(i) = current_k;
    if i > 1
        current_k = backtrack(i, current_k);
        if current_k < 1, current_k = 1; end
    end
end

% Mapeia os índices globais da câmera para cada frame de referência k
matchedCamFrames = cell(Ntx, 1);
for i = 1:T_search
    t_global = tIndices(i);
    k_ref = k_opt(i);
    if k_ref >= 1 && k_ref <= Ntx
        matchedCamFrames{k_ref}(end+1) = t_global;
    end
end

% 5. Descarte de Quadros de Transição e Média dos Quadros Limpos
finalVideo = zeros(Mmax, Nmax, 1, Ntx);
framesCountPerRef = zeros(Ntx, 1);
avgSimPerRef = zeros(Ntx, 1);

thresholdRatio = 0.85; % Limiar de corte de transição (retém apenas frames com >=85% da melhor similaridade)

for k = 1:Ntx
    camIdxs = matchedCamFrames{k};
    
    if isempty(camIdxs)
        % Fallback de segurança: se nenhum frame foi associado, pega o frame com maior similaridade global para k
        [~, best_t] = max(S(tIndices, k));
        camIdxs = tIndices(best_t);
        warning('Quadro de referência k=%d sem associação direta. Usando fallback no frame t=%d.', k, camIdxs);
    end
    
    sims = S(camIdxs, k);
    maxSim = max(sims);
    
    % Retém apenas quadros sem borramento/transição (alta similaridade)
    if maxSim > 0
        cleanMask = (sims >= thresholdRatio * maxSim);
    else
        cleanMask = true(size(sims));
    end
    
    cleanCamIdxs = camIdxs(cleanMask);
    
    % Se a filtragem remover todos, usa os 50% centrais do bloco de frames
    if isempty(cleanCamIdxs)
        nIdx = length(camIdxs);
        midStart = max(1, floor(nIdx * 0.25));
        midEnd   = min(nIdx, ceil(nIdx * 0.75));
        cleanCamIdxs = camIdxs(midStart:midEnd);
    end
    
    % Calcula a média apenas dos quadros limpos
    framesToAverage = resizedVideo_dbl(:, :, 1, cleanCamIdxs);
    finalVideo(:, :, 1, k) = mean(framesToAverage, 4);
    
    framesCountPerRef(k) = length(cleanCamIdxs);
    avgSimPerRef(k) = mean(S(cleanCamIdxs, k));
end

% Informações de alinhamento para diagnóstico
alignmentInfo = struct();
alignmentInfo.startCamFrame = tIndices(1);
alignmentInfo.endCamFrame = tIndices(end);
alignmentInfo.framesCountPerRef = framesCountPerRef;
alignmentInfo.avgSimPerRef = avgSimPerRef;
alignmentInfo.matchedCamFrames = matchedCamFrames;

fprintf('Sincronização por Referência Concluída: %d quadros reconstruídos de %d quadros gravados.\n', Ntx, numCamFrames);
fprintf('Média de quadros limpos mantidos por símbolo: %.2f quadros (min: %d, max: %d).\n', ...
    mean(framesCountPerRef), min(framesCountPerRef), max(framesCountPerRef));

end
