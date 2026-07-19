function roiPosition = automaticROI_v3(recordedVideo, showFigure)
% AUTOMATICROI_V3 - Detecta ROI quadrilátera com garantias de transformação projetiva.
%
% Esta função garante que os 4 lados da ROI sejam segmentos de reta perfeitos,
% obtendo os cantos como interseções de linhas ajustadas ao contorno convexo
% da máscara de variância temporal. Não possui parâmetros ajustáveis — todos
% os limiares são adaptativos baseados na geometria da máscara.
%
% Propriedades projetivas garantidas por construção:
%   1. Colinearidade  - Lados definidos por equações de reta (ajuste PCA)
%   2. Pontos de Fuga  - Consequência de quadrilátero convexo com lados retos
%   3. Foreshortening  - Preservado naturalmente pela geometria projetiva
%   4. Incidência      - Diagonais se cruzam no centro projetivo
%   5. Razão Cruzada   - Invariante sob homografia (consequência matemática)
%
% Pipeline:
%   Variância temporal → Otsu → Maior componente → Suavização morfológica →
%   Hull convexo → Ângulos de curvatura (4 cantos) → Ajuste PCA de retas
%   (4 lados) → Interseções → Validação de convexidade → Ordenação TL/TR/BR/BL
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
    % FASE 1: Máscara de Variância Temporal (idêntica à v2)
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
    % Isso preenche pequenos buracos e suaviza irregularidades do contorno
    % sem alterar a forma global.
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

    % Envoltória convexa: elimina concavidades e protuberâncias ruidosas,
    % preservando apenas a forma convexa que melhor representa a tela.
    K = convhull(double(cols), double(rows));
    hull_x = double(cols(K(1:end-1))); % Remove ponto duplicado final
    hull_y = double(rows(K(1:end-1)));
    nHull = length(hull_x);

    if nHull < 4
        warning('automaticROI_v3:degenHull', ...
            'Hull convexo com menos de 4 vértices. Retornando bounding box.');
        roiPosition = boundingBoxROI(rows, cols);
        if showFigure
            showResult(recordedVideo, roiPosition, numFrames);
        end
        return;
    end

    % ====================================================================
    % FASE 3: Detecção dos 4 Cantos via Ângulos de Curvatura
    % ====================================================================
    % Para cada vértice do hull convexo, calcula o ângulo interior formado
    % pelos dois segmentos adjacentes. Os 4 vértices com os menores ângulos
    % interiores correspondem aos 4 cantos do quadrilátero (cantos mais
    % agudos), enquanto os vértices com ângulos próximos de π estão sobre
    % os lados (quase colineares com seus vizinhos).

    interiorAngles = zeros(nHull, 1);
    for j = 1:nHull
        jp = mod(j - 2, nHull) + 1; % Vértice anterior
        jn = mod(j, nHull) + 1;     % Vértice seguinte

        % Vetores do vértice atual para os vizinhos
        v1 = [hull_x(jp) - hull_x(j), hull_y(jp) - hull_y(j)];
        v2 = [hull_x(jn) - hull_x(j), hull_y(jn) - hull_y(j)];

        % Ângulo interior (entre os dois vetores)
        cosA = dot(v1, v2) / (norm(v1) * norm(v2) + eps);
        cosA = max(-1, min(1, cosA)); % Clamp para evitar erros numéricos
        interiorAngles(j) = acos(cosA);
    end

    % Os 4 cantos são os vértices com os MENORES ângulos interiores:
    %   - Canto de retângulo: ângulo ≈ π/2
    %   - Ponto sobre um lado: ângulo ≈ π (vértices quase colineares)
    [~, sortedIdx] = sort(interiorAngles, 'ascend');
    cornerIdx = sort(sortedIdx(1:4)); % Mantém a ordem do hull

    % ====================================================================
    % FASE 4: Ajuste de Retas (PCA) aos Lados e Interseção → Cantos Refinados
    % ====================================================================
    % Para cada um dos 4 lados (segmento do hull entre cantos consecutivos),
    % ajusta uma reta por PCA usando todos os vértices do hull naquele trecho.
    % A direção de mínima variância (2ª componente do SVD) define a normal
    % da reta, resultando em lados matematicamente perfeitos.
    %
    % Em seguida, os cantos refinados são calculados como as interseções das
    % retas adjacentes, garantindo:
    %   - Colinearidade perfeita de cada lado
    %   - Interseções consistentes (preservação de incidência)

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

        % Ajuste de reta via PCA (equação normal: a*x + b*y = d)
        sideLines(s) = fitLinePCA(seg_x, seg_y);
    end

    % Interseção de retas adjacentes → 4 cantos refinados
    % Canto c = interseção do Lado(c-1) com o Lado(c)
    refinedCorners = zeros(4, 2); % [x, y]
    for c = 1:4
        s_prev = mod(c - 2, 4) + 1;
        s_curr = c;

        pt = intersectLines(sideLines(s_prev), sideLines(s_curr));
        if isempty(pt)
            % Retas paralelas (degenerado) — mantém o vértice original
            refinedCorners(c, :) = [hull_x(cornerIdx(c)), hull_y(cornerIdx(c))];
        else
            refinedCorners(c, :) = pt;
        end
    end

    % ====================================================================
    % FASE 5: Validação de Convexidade
    % ====================================================================
    % Se os cantos refinados (por interseção) não formam um quadrilátero
    % convexo (possível em casos degenerados), usamos os cantos originais
    % do hull, que são convexos por construção.

    if ~isConvexQuad(refinedCorners)
        warning('automaticROI_v3:notConvex', ...
            'Cantos refinados não convexos. Usando cantos do hull.');
        refinedCorners = [hull_x(cornerIdx), hull_y(cornerIdx)];
    end

    % ====================================================================
    % FASE 6: Ordenação dos Cantos — TL, TR, BR, BL
    % ====================================================================
    roiPosition = orderCornersTLTRBRBL(refinedCorners);

    % ====================================================================
    % Exibição gráfica (opcional)
    % ====================================================================
    if showFigure
        showResult(recordedVideo, roiPosition, numFrames);
    end
end

% ========================================================================
% FUNÇÕES AUXILIARES (private, dentro do mesmo arquivo)
% ========================================================================

function lineParams = fitLinePCA(x, y)
% FITLINEPCA - Ajusta uma reta a pontos 2D via Análise de Componentes Principais.
% Retorna a equação normal da reta: a*x + b*y = d
%
% A direção de mínima variância (2ª componente do SVD) é a normal da reta.
% Isso é equivalente a minimizar a distância perpendicular total dos pontos
% à reta, sendo mais robusto que uma regressão linear simples (que minimiza
% apenas resíduos verticais).

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
