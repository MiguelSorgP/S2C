function roiPosition = automaticROI_v3(recordedVideo, showFigure)
% AUTOMATICROI_V3 - Detecta ROI quadrilátera com garantias de transformação projetiva.
%
% Pipeline robusto com fallback gradual:
%   Pipeline Principal (hull → ângulos com separação → PCA → interseção)
%     → Cantos diretos do hull (sem PCA/interseção)
%       → Fallback v2 (extreme points via min/max de x±y)
%         → Bounding box da máscara
%           → ROI central padrão
%
% Propriedades projetivas garantidas:
%   1. Colinearidade       - Lados definidos por equações de reta (ajuste PCA)
%   2. Pontos de Fuga      - Consequência de quadrilátero convexo com lados retos
%   3. Foreshortening      - Preservado naturalmente pela geometria projetiva
%   4. Incidência          - Diagonais se cruzam no centro projetivo
%   5. Razão Cruzada       - Invariante sob homografia (consequência matemática)
%   6. Não-degenerescência - Separação mínima angular entre cantos no hull
%   7. Contenção           - Cantos restritos aos limites da imagem (clamping)
%   8. Área mínima         - ROI cobre fração mínima razoável da máscara
%
% Pipeline:
%   Variância temporal → Otsu → Maior componente → Suavização morfológica →
%   Hull convexo → Ângulos de curvatura → Seleção gulosa com separação →
%   Ajuste PCA (com guarda) → Interseções → Validação geométrica →
%   Fallback gradual se necessário → Ordenação TL/TR/BR/BL
%
% Entradas:
%   recordedVideo - Matriz 4D (altura x largura x canal x frames)
%   showFigure    - Flag para exibir a ROI detectada (padrão: false)
%
% Saídas:
%   roiPosition   - Matriz [4 x 2] com [x, y] dos vértices: [TL; TR; BR; BL]

    if nargin < 2
        showFigure = false;
    end

    [altura, largura, ~, numFrames] = size(recordedVideo);

    % ====================================================================
    % FASE 1: Máscara de Variância Temporal
    % ====================================================================
    sumPixels = zeros(altura, largura);
    sumSqPixels = zeros(altura, largura);

    for t = 1:numFrames
        frameGray = recordedVideo(:,:,1,t);
        sumPixels = sumPixels + frameGray;
        sumSqPixels = sumSqPixels + frameGray.^2;
    end

    meanPixels = sumPixels / numFrames;
    varianceImage = (sumSqPixels / numFrames) - meanPixels.^2;

    maxVar = max(varianceImage(:));
    if maxVar == 0
        warning('automaticROI_v3:zeroVariance', ...
            'Variância zero em todos os pixels. Retornando ROI central padrão.');
        roiPosition = defaultCenterROI(altura, largura);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    varianceNorm = varianceImage / maxVar;
    level = graythresh(varianceNorm);
    threshold = level * maxVar;
    movingPixels = varianceImage > threshold;

    movingPixels = bwareaopen(movingPixels, 50);

    cc = bwconncomp(movingPixels);
    if cc.NumObjects == 0
        warning('automaticROI_v3:noComponent', ...
            'Nenhum componente encontrado. Retornando ROI central padrão.');
        roiPosition = defaultCenterROI(altura, largura);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end
    numPx = cellfun(@numel, cc.PixelIdxList);
    [~, idx] = max(numPx);
    largestComponent = false(size(movingPixels));
    largestComponent(cc.PixelIdxList{idx}) = true;

    % ====================================================================
    % FASE 2: Suavização Morfológica e Envoltória Convexa
    % ====================================================================

    % Fechamento morfológico com raio proporcional à raiz da área da máscara.
    % Preenche buracos e suaviza irregularidades sem alterar a forma global.
    maskArea = sum(largestComponent(:));
    seRadius = max(3, round(sqrt(maskArea) / 40));
    se = strel('disk', seRadius);
    largestComponent = imclose(largestComponent, se);
    largestComponent = imfill(largestComponent, 'holes');

    % Extrai coordenadas de todos os pixels ativos
    [rows, cols] = find(largestComponent);
    if numel(rows) < 3
        warning('automaticROI_v3:tooFewPixels', ...
            'Menos de 3 pixels na máscara. Retornando ROI central padrão.');
        roiPosition = defaultCenterROI(altura, largura);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    % Métricas de referência da máscara para validações posteriores
    maskBBDiag = sqrt((max(cols) - min(cols))^2 + (max(rows) - min(rows))^2);
    maskBBArea = max(1, (max(cols) - min(cols)) * (max(rows) - min(rows)));

    % Envoltória convexa: elimina concavidades e protuberâncias ruidosas
    K = convhull(double(cols), double(rows));
    hull_x = double(cols(K(1:end-1))); % Remove ponto duplicado final
    hull_y = double(rows(K(1:end-1)));
    nHull = length(hull_x);

    if nHull < 4
        % Hull com menos de 4 vértices — vai direto para fallback v2
        warning('automaticROI_v3:degenHull', ...
            'Hull convexo com menos de 4 vértices. Usando fallback v2.');
        roiPosition = fallbackV2WithValidation( ...
            rows, cols, maskBBDiag, maskBBArea, altura, largura);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    % ====================================================================
    % FASE 3: Detecção dos 4 Cantos via Ângulos de Curvatura
    %         com seleção gulosa e separação angular mínima
    % ====================================================================
    % Para cada vértice do hull convexo, calcula o ângulo interior. Os cantos
    % do quadrilátero são os vértices com ângulos mais agudos. A seleção
    % gulosa garante que os 4 cantos estejam bem distribuídos no hull,
    % impedindo que dois cantos fiquem adjacentes (causa de ROIs triangulares).

    interiorAngles = computeHullAngles(hull_x, hull_y, nHull);

    % Seleção gulosa: garante separação mínima entre cantos no hull
    cornerIdx = selectCornersGreedy(interiorAngles, nHull);

    if isempty(cornerIdx)
        % Seleção gulosa falhou — fallback para v2
        warning('automaticROI_v3:greedyFailed', ...
            'Seleção gulosa de cantos falhou. Usando fallback v2.');
        roiPosition = fallbackV2WithValidation( ...
            rows, cols, maskBBDiag, maskBBArea, altura, largura);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    % ====================================================================
    % FASE 4: Ajuste de Retas aos Lados e Interseção → Cantos Refinados
    % ====================================================================
    % Para cada um dos 4 lados (segmento do hull entre cantos consecutivos),
    % ajusta uma reta. Se o segmento tem ≥3 pontos, usa PCA (normal via SVD).
    % Caso contrário, usa a reta direta entre os endpoints (mais estável).
    %
    % Os cantos refinados são as interseções das retas adjacentes, garantindo
    % colinearidade perfeita de cada lado.

    sideLines = struct('a', cell(1,4), 'b', cell(1,4), 'd', cell(1,4));

    for s = 1:4
        s_next = mod(s, 4) + 1;
        idx1 = cornerIdx(s);
        idx2 = cornerIdx(s_next);

        % Coleta os vértices do hull neste segmento (com wrapping circular)
        if idx2 > idx1
            segIndices = idx1:idx2;
        else
            segIndices = [idx1:nHull, 1:idx2];
        end

        seg_x = hull_x(segIndices);
        seg_y = hull_y(segIndices);

        % Guarda: se o segmento tem < 3 pontos, usa reta direta entre endpoints
        if numel(seg_x) < 3
            sideLines(s) = fitLineDirect( ...
                seg_x(1), seg_y(1), seg_x(end), seg_y(end));
        else
            sideLines(s) = fitLinePCA(seg_x, seg_y);
        end
    end

    % Interseção de retas adjacentes → 4 cantos refinados
    % Canto c = interseção do Lado(c-1) com o Lado(c)
    refinedCorners = zeros(4, 2); % [x, y]
    allIntersectionsValid = true;
    for c = 1:4
        s_prev = mod(c - 2, 4) + 1;
        s_curr = c;

        pt = intersectLines(sideLines(s_prev), sideLines(s_curr));
        if isempty(pt)
            % Retas paralelas (degenerado) — marca falha
            allIntersectionsValid = false;
            refinedCorners(c, :) = [hull_x(cornerIdx(c)), hull_y(cornerIdx(c))];
        else
            refinedCorners(c, :) = pt;
        end
    end

    % ====================================================================
    % FASE 5: Validação Geométrica com Fallback Gradual
    % ====================================================================

    % Clamping aos limites da imagem
    refinedCorners = clampToImage(refinedCorners, altura, largura);

    % --- Tentativa 1: Cantos refinados (PCA + interseção) ---
    if allIntersectionsValid && isValidQuad(refinedCorners, maskBBDiag, maskBBArea)
        roiPosition = orderCornersTLTRBRBL(refinedCorners);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    % --- Tentativa 2: Cantos diretos do hull (sem PCA) ---
    warning('automaticROI_v3:refinedFailed', ...
        'Cantos refinados falharam validação. Tentando cantos diretos do hull.');
    hullCorners = clampToImage( ...
        [hull_x(cornerIdx), hull_y(cornerIdx)], altura, largura);
    if isValidQuad(hullCorners, maskBBDiag, maskBBArea)
        roiPosition = orderCornersTLTRBRBL(hullCorners);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    % --- Tentativa 3: Fallback v2 (extreme points via min/max de x±y) ---
    warning('automaticROI_v3:hullCornersFailed', ...
        'Cantos do hull falharam validação. Usando fallback v2 (extreme points).');
    roiPosition = fallbackV2WithValidation( ...
        rows, cols, maskBBDiag, maskBBArea, altura, largura);

    if showFigure
        showResult(recordedVideo, roiPosition, numFrames);
    end
end

% ========================================================================
% FUNÇÕES AUXILIARES (private, dentro do mesmo arquivo)
% ========================================================================

function angles = computeHullAngles(hull_x, hull_y, nHull)
% COMPUTEHULLANGLES - Calcula o ângulo interior em cada vértice do hull convexo.
%
% Para cada vértice, calcula o ângulo formado pelos dois segmentos adjacentes.
% Cantos reais do quadrilátero terão ângulos mais agudos (~π/2), enquanto
% pontos sobre os lados terão ângulos próximos de π (quase colineares).

    angles = zeros(nHull, 1);
    for j = 1:nHull
        jp = mod(j - 2, nHull) + 1; % Vértice anterior
        jn = mod(j, nHull) + 1;     % Vértice seguinte

        v1 = [hull_x(jp) - hull_x(j), hull_y(jp) - hull_y(j)];
        v2 = [hull_x(jn) - hull_x(j), hull_y(jn) - hull_y(j)];

        cosA = dot(v1, v2) / (norm(v1) * norm(v2) + eps);
        cosA = max(-1, min(1, cosA)); % Clamp para evitar erros numéricos
        angles(j) = acos(cosA);
    end
end

function cornerIdx = selectCornersGreedy(interiorAngles, nHull)
% SELECTCORNERSGREEDY - Seleciona 4 cantos com separação mínima no hull.
%
% Primeiro, filtra candidatos válidos: apenas vértices com ângulo interior
% significativamente menor que π (pontos reais de curvatura, não pontos
% colineares sobre lados retos). O limiar adaptativo é a média entre o
% 4º menor ângulo e π — isso garante que apenas vértices com curvatura
% real sejam candidatos, excluindo os ~180° que estão sobre lados.
%
% Depois, usa seleção gulosa com separação mínima decrescente para
% garantir distribuição espacial dos 4 cantos.
%
% Retorna os 4 índices em ordem crescente (ordem do hull), ou [] se falhar.

    [sortedAngles, sortedIdx] = sort(interiorAngles, 'ascend');

    % Limiar de ângulo adaptativo: apenas vértices com curvatura real.
    % O limiar é a média entre o 4º menor ângulo e π (180°).
    % Isso se adapta à geometria: para retângulos quase perfeitos
    % (ângulos ~90°), o limiar fica ~135°; para trapézios mais abertos
    % (ângulos ~135°), fica ~157°. Nunca aceita pontos de ~180°.
    if nHull >= 4
        fourthAngle = sortedAngles(4);
    else
        fourthAngle = sortedAngles(end);
    end
    maxAngleThresh = (fourthAngle + pi) / 2;

    % Filtra apenas candidatos com ângulo abaixo do limiar
    validMask = interiorAngles < maxAngleThresh;
    nValid = sum(validMask);

    if nValid < 4
        % Não há 4 vértices com curvatura suficiente — fallback
        cornerIdx = [];
        return;
    end

    % Reordena apenas os candidatos válidos (por ângulo crescente)
    validIndices = find(validMask);
    [~, reorder] = sort(interiorAngles(validIndices), 'ascend');
    candidateIdx = validIndices(reorder);
    nCandidates = length(candidateIdx);

    % Seleção gulosa com separação mínima decrescente
    minSep = max(1, floor(nHull / 6));

    while minSep >= 1
        selected = [];
        for k = 1:nCandidates
            candidate = candidateIdx(k);
            tooClose = false;
            for m = 1:length(selected)
                % Distância circular no hull
                dist = min(abs(candidate - selected(m)), ...
                           nHull - abs(candidate - selected(m)));
                if dist < minSep
                    tooClose = true;
                    break;
                end
            end
            if ~tooClose
                selected = [selected, candidate]; %#ok<AGROW>
                if length(selected) == 4
                    break;
                end
            end
        end

        if length(selected) == 4
            cornerIdx = sort(selected); % Mantém ordem do hull
            return;
        end

        minSep = floor(minSep / 2);
    end

    % Se mesmo com minSep=1 não conseguiu 4 cantos entre os válidos
    cornerIdx = [];
end

function lineParams = fitLinePCA(x, y)
% FITLINEPCA - Ajusta uma reta a pontos 2D via Análise de Componentes Principais.
% Retorna a equação normal da reta: a*x + b*y = d
%
% A direção de mínima variância (2ª componente do SVD) é a normal da reta.
% Isso é equivalente a minimizar a distância perpendicular total dos pontos
% à reta, sendo mais robusto que uma regressão linear simples.

    pts = [x(:), y(:)];
    centroid = mean(pts, 1);

    if size(pts, 1) < 2
        % Com apenas 1 ponto, retorna reta horizontal passando pelo ponto
        lineParams.a = 0;
        lineParams.b = 1;
        lineParams.d = centroid(2);
        return;
    end

    pts_centered = pts - centroid;
    [~, ~, V] = svd(pts_centered, 'econ');

    % Normal da reta = 2ª coluna de V (direção de mínima variância)
    normal = V(:, 2);
    lineParams.a = normal(1);
    lineParams.b = normal(2);
    lineParams.d = normal(1) * centroid(1) + normal(2) * centroid(2);
end

function lineParams = fitLineDirect(x1, y1, x2, y2)
% FITLINEDIRECT - Reta definida diretamente por dois pontos.
% Retorna a equação normal: a*x + b*y = d
%
% Usada como fallback quando o segmento do hull tem < 3 pontos,
% situação em que o PCA seria instável.

    dx = x2 - x1;
    dy = y2 - y1;

    % Normal perpendicular à direção do segmento
    len = sqrt(dx^2 + dy^2);
    if len < eps
        % Pontos coincidentes — reta horizontal arbitrária
        lineParams.a = 0;
        lineParams.b = 1;
        lineParams.d = y1;
        return;
    end

    lineParams.a = -dy / len;
    lineParams.b = dx / len;
    lineParams.d = lineParams.a * x1 + lineParams.b * y1;
end

function pt = intersectLines(L1, L2)
% INTERSECTLINES - Calcula a interseção de duas retas (a*x + b*y = d).
% Retorna [x, y] ou [] se as retas são paralelas.

    A = [L1.a, L1.b; L2.a, L2.b];
    b_vec = [L1.d; L2.d];

    d = det(A);
    if abs(d) < 1e-10
        pt = []; % Retas paralelas
        return;
    end

    pt = (A \ b_vec)';
end

function corners = clampToImage(corners, altura, largura)
% CLAMPTOIMAGE - Restringe coordenadas dos cantos aos limites da imagem.
% Garante que nenhum canto fique fora dos limites [1, largura] × [1, altura].

    corners(:, 1) = max(1, min(largura, corners(:, 1)));
    corners(:, 2) = max(1, min(altura, corners(:, 2)));
end

function valid = isValidQuad(corners, maskBBDiag, maskBBArea)
% ISVALIDQUAD - Verifica se 4 pontos formam um quadrilátero geometricamente válido.
%
% Critérios (todos devem ser atendidos):
%   1. Convexidade — cross-products com mesmo sinal em todos os vértices
%   2. Lado mínimo — nenhum lado menor que 5% da diagonal do bounding box da máscara
%   3. Área mínima — área do quadrilátero ≥ 10% da área do bounding box da máscara

    valid = false;

    if size(corners, 1) ~= 4
        return;
    end

    % 1. Convexidade
    if ~isConvexQuad(corners)
        return;
    end

    % 2. Lado mínimo (impede lados colapsados → ROI triangular)
    minSideThresh = 0.05 * maskBBDiag;
    for i = 1:4
        i_next = mod(i, 4) + 1;
        sideLen = sqrt((corners(i_next,1) - corners(i,1))^2 + ...
                       (corners(i_next,2) - corners(i,2))^2);
        if sideLen < minSideThresh
            return;
        end
    end

    % 3. Área mínima (impede ROIs degeneradas muito pequenas)
    area = quadArea(corners);
    if area < 0.10 * maskBBArea
        return;
    end

    valid = true;
end

function convex = isConvexQuad(corners)
% ISCONVEXQUAD - Verifica se 4 pontos formam um quadrilátero convexo.
% Calcula o produto cruzado em cada vértice; se todos têm o mesmo sinal,
% o quadrilátero é convexo.

    convex = true;
    n = size(corners, 1);
    if n ~= 4
        convex = false;
        return;
    end

    crossProducts = zeros(n, 1);
    for i = 1:n
        i1 = mod(i, n) + 1;
        i2 = mod(i + 1, n) + 1;

        dx1 = corners(i1, 1) - corners(i, 1);
        dy1 = corners(i1, 2) - corners(i, 2);
        dx2 = corners(i2, 1) - corners(i1, 1);
        dy2 = corners(i2, 2) - corners(i1, 2);

        crossProducts(i) = dx1 * dy2 - dy1 * dx2;
    end

    signs = sign(crossProducts);
    if any(signs == 0)
        convex = false; % Pontos colineares (degenerado)
    else
        convex = all(signs == signs(1));
    end
end

function area = quadArea(corners)
% QUADAREA - Calcula a área de um quadrilátero pelo método Shoelace.

    x = corners(:, 1);
    y = corners(:, 2);
    area = 0.5 * abs(x(1)*y(2) - x(2)*y(1) + ...
                     x(2)*y(3) - x(3)*y(2) + ...
                     x(3)*y(4) - x(4)*y(3) + ...
                     x(4)*y(1) - x(1)*y(4));
end

function corners = extremePointCorners(rows, cols)
% EXTREMEPOINTCORNERS - Encontra 4 cantos via min/max de x±y (lógica do v2).
%
% Esta é a lógica simples e robusta do automaticROI_v2:
%   TL = argmin(x + y)   — mais próximo da origem
%   BR = argmax(x + y)   — mais distante da origem
%   TR = argmax(x - y)   — mais à direita e acima
%   BL = argmin(x - y)   — mais à esquerda e abaixo

    soma = double(cols) + double(rows);
    diff = double(cols) - double(rows);

    [~, idx_tl] = min(soma);
    [~, idx_br] = max(soma);
    [~, idx_tr] = max(diff);
    [~, idx_bl] = min(diff);

    corners = [double(cols(idx_tl)), double(rows(idx_tl));
               double(cols(idx_tr)), double(rows(idx_tr));
               double(cols(idx_br)), double(rows(idx_br));
               double(cols(idx_bl)), double(rows(idx_bl))];
end

function roiPosition = fallbackV2WithValidation(rows, cols, maskBBDiag, maskBBArea, altura, largura)
% FALLBACKV2WITHVALIDATION - Tenta extreme points (v2), depois bounding box.
%
% Hierarquia:
%   1. Extreme points (lógica v2) com validação relaxada
%   2. Bounding box da máscara (sempre válido)

    % --- Tentativa: extreme points (lógica v2) ---
    corners = extremePointCorners(rows, cols);
    corners = clampToImage(corners, altura, largura);

    % Validação relaxada: convexidade + lado mínimo com threshold menor
    if isConvexQuad(corners)
        minSideThresh = 0.03 * maskBBDiag; % Threshold mais relaxado que o pipeline principal
        allSidesOk = true;
        for i = 1:4
            i_next = mod(i, 4) + 1;
            sideLen = sqrt((corners(i_next,1) - corners(i,1))^2 + ...
                           (corners(i_next,2) - corners(i,2))^2);
            if sideLen < minSideThresh
                allSidesOk = false;
                break;
            end
        end
        if allSidesOk
            roiPosition = orderCornersTLTRBRBL(corners);
            return;
        end
    end

    % --- Fallback final: bounding box ---
    warning('automaticROI_v3:v2Failed', ...
        'Fallback v2 (extreme points) também falhou. Usando bounding box.');
    roiPosition = boundingBoxROI(rows, cols);
end

function ordered = orderCornersTLTRBRBL(corners)
% ORDERCORNERSTLTRBRBL - Ordena 4 cantos na sequência TL, TR, BR, BL.
%
% Utiliza as métricas:
%   TL = argmin(x + y)   (mais próximo da origem)
%   BR = argmax(x + y)   (mais distante da origem)
%   TR = argmax(x - y)   (mais à direita e acima)
%   BL = argmin(x - y)   (mais à esquerda e abaixo)
%
% Se a heurística x±y falhar (índices não únicos), usa ordenação angular
% em torno do centroide como fallback.

    x = corners(:, 1);
    y = corners(:, 2);

    soma = x + y;
    diff = x - y;

    [~, idx_tl] = min(soma);
    [~, idx_br] = max(soma);
    [~, idx_tr] = max(diff);
    [~, idx_bl] = min(diff);

    indices = [idx_tl, idx_tr, idx_br, idx_bl];

    if length(unique(indices)) == 4
        % Caso normal: 4 índices distintos
        ordered = [corners(idx_tl, :);
                   corners(idx_tr, :);
                   corners(idx_br, :);
                   corners(idx_bl, :)];
    else
        % Fallback: ordenação angular em torno do centroide
        cx = mean(x);
        cy = mean(y);
        angles = atan2(y - cy, x - cx);
        [~, sortIdx] = sort(angles);
        sorted = corners(sortIdx, :);

        % Identifica TL e rotaciona
        s = sorted(:, 1) + sorted(:, 2);
        [~, ti] = min(s);
        reord = zeros(4, 2);
        for k = 1:4
            reord(k, :) = sorted(mod(ti + k - 2, 4) + 1, :);
        end

        % Garante sentido horário (TL → TR → BR → BL)
        d2 = reord(2, 1) - reord(2, 2);
        d4 = reord(4, 1) - reord(4, 2);
        if d2 < d4
            reord = reord([1, 4, 3, 2], :);
        end

        ordered = reord;
    end
end

function roi = defaultCenterROI(altura, largura)
% DEFAULTCENTERROI - ROI padrão no centro da imagem (40% da dimensão).

    cx = largura / 2;
    cy = altura / 2;
    w = largura * 0.4;
    h = altura * 0.4;
    roi = [cx - w/2, cy - h/2;
           cx + w/2, cy - h/2;
           cx + w/2, cy + h/2;
           cx - w/2, cy + h/2];
end

function roi = boundingBoxROI(rows, cols)
% BOUNDINGBOXROI - ROI baseada no bounding box dos pixels.

    roi = [min(cols), min(rows);
           max(cols), min(rows);
           max(cols), max(rows);
           min(cols), max(rows)];
end

function showResult(recordedVideo, roiPosition, numFrames)
% SHOWRESULT - Exibe o último frame com a ROI sobreposta.

    figure('Name', 'automaticROI_v3 — ROI Detectada', 'NumberTitle', 'off');
    lastFrame = recordedVideo(:, :, :, numFrames);
    imshow(lastFrame, []);
    hold on;

    xc = [roiPosition(:, 1); roiPosition(1, 1)];
    yc = [roiPosition(:, 2); roiPosition(1, 2)];
    plot(xc, yc, 'r-', 'LineWidth', 2);
    plot(roiPosition(:, 1), roiPosition(:, 2), 'go', 'MarkerSize', 8, 'LineWidth', 2);

    labels = {'TL', 'TR', 'BR', 'BL'};
    for k = 1:4
        text(roiPosition(k, 1) + 5, roiPosition(k, 2) - 5, labels{k}, ...
            'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold');
    end
    title('ROI Detectada (v3 — Garantias Projetivas)');
    hold off;
end
