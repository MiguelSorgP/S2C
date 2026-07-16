function roiPosition = manualQuadROI(recordedVideo, autoRoiPosition)
% MANUALQUADROI - Interface para seleção manual de ROI em quadrilátero de 4 pontos.
% Esta função abre uma interface gráfica (GUI) mostrando o primeiro frame do vídeo
% e permite que o usuário movimente livremente quatro vértices (inicializados a
% partir da detecção automática). Garante restrição à grade de pixels (snap to grid)
% e retorna as coordenadas ajustadas finais na ordem correta.
%
% Entradas:
%   recordedVideo   - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
%   autoRoiPosition - Matriz 4x2 [x, y] com os 4 vértices iniciais da detecção automática
%
% Saídas:
%   roiPosition     - Matriz 4x2 [x, y] com os 4 vértices ajustados finais
    
    % Cria a figura e eixos
    fig = figure('Name', 'Seleção Manual da ROI (4 Pontos)', 'NumberTitle', 'off');
    ax  = axes('Parent', fig);
    
    % Acessa o primeiro frame (normalizado)
    firstFrame = recordedVideo(:,:,1,1) / 255;
    
    % Exibe o frame em escala de cinza
    imshow(firstFrame, 'Parent', ax);
    title(ax, 'Ajuste os 4 pontos da ROI e clique no botão "Confirmar ROI"');
    
    % Define os limites da imagem inteira como o ponto de restauração do zoom (reset)
    resetplotview(ax, 'InitializeCurrentView');
    
    % Configura o zoom inicial na ROI automática mais 10% de folga (margem)
    xs = autoRoiPosition(:, 1);
    ys = autoRoiPosition(:, 2);
    x_min = min(xs);
    x_max = max(xs);
    y_min = min(ys);
    y_max = max(ys);
    
    w = x_max - x_min;
    h = y_max - y_min;
    margin_x = 0.10 * w;
    margin_y = 0.10 * h;
    
    [imgH, imgW] = size(firstFrame);
    xlim_val = [max(1, x_min - margin_x), min(imgW, x_max + margin_x)];
    ylim_val = [max(1, y_min - margin_y), min(imgH, y_max + margin_y)];
    
    xlim(ax, xlim_val);
    ylim(ax, ylim_val);
    
    % Desenha o polígono interativo (inicializado com a ROI automática)
    h_poly = drawpolygon(ax, 'Position', autoRoiPosition, 'Label', 'ROI', 'Color', [1 0 0]);
    
    % Adiciona listener para garantir que os pontos só se movem na grade de pixels (snap to grid)
    addlistener(h_poly, 'MovingROI', @(src, evt) snapToGrid(src, evt));
    addlistener(h_poly, 'ROIMoved', @(src, evt) snapToGrid(src, evt));
    
    % Adiciona o botão de confirmação
    btnConfirm = uicontrol(fig, 'Style', 'pushbutton', ...
        'String', 'Confirmar ROI', ...
        'Units', 'normalized', ...
        'Position', [0.02 0.02 0.15 0.06], ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.6 0.2], ...
        'ForegroundColor', [1 1 1], ...
        'Callback', @(src, evt) uiresume(fig));
    
    % Adiciona o botão de Reset Zoom (Zoom Out Total)
    btnZoom = uicontrol(fig, 'Style', 'pushbutton', ...
        'String', 'Zoom Out Total', ...
        'Units', 'normalized', ...
        'Position', [0.18 0.02 0.15 0.06], ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.2 0.6], ...
        'ForegroundColor', [1 1 1], ...
        'Callback', @(src, evt) resetZoomCallback(ax, imgW, imgH));
    
    % Espera confirmação pelo clique no botão
    uiwait(fig);
    
    % Armazena a posição FINAL
    rawPosition = h_poly.Position;
    close(fig);
    
    % Garante que temos exatamente 4 pontos
    if size(rawPosition, 1) ~= 4
        warning('O número de pontos foi alterado. Forçando a manter apenas 4 pontos.');
        if size(rawPosition, 1) > 4
            rawPosition = rawPosition(1:4, :);
        else
            rawPosition = [rawPosition; autoRoiPosition(size(rawPosition, 1)+1:end, :)];
        end
    end
    
    % Assegura o arredondamento final dos pixels e limites da imagem
    roiPosition = round(rawPosition);
    roiPosition(:, 1) = min(max(roiPosition(:, 1), 1), imgW);
    roiPosition(:, 2) = min(max(roiPosition(:, 2), 1), imgH);
end

function snapToGrid(src, evt)
    % Obtém a posição atual do evento (ou do objeto se indisponível) e arredonda para pixels
    if nargin > 1 && isprop(evt, 'CurrentPosition')
        roundedPos = round(evt.CurrentPosition);
    else
        roundedPos = round(src.Position);
    end
    if ~isequal(src.Position, roundedPos)
        src.Position = roundedPos;
    end
end

function resetZoomCallback(ax, imgW, imgH)
    xlim(ax, [0.5, imgW + 0.5]);
    ylim(ax, [0.5, imgH + 0.5]);
end
