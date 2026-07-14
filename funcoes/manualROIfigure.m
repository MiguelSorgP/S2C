function roiPosition = manualROIfigure(recordedVideo)
    % MANUALROI Permite seleção manual de uma região de interesse (ROI)
    %   roiPosition = MANUALROI(recordedVideo) exibe o primeiro frame do vídeo
    %   e permite que o usuário desenhe e confirme um retângulo para definir
    %   a região de interesse.
    %
    %   Entradas:
    %       recordedVideo - Matriz 4D com os frames do vídeo (altura x largura x canal x frames)
    %
    %   Saídas:
    %       roiPosition - Vetor [x y largura altura] com as coordenadas da ROI selecionada
    
    % Cria a figura e eixos
    fig = figure('Name', 'Seleção da ROI', 'NumberTitle', 'off');
    ax  = axes('Parent', fig);
    
    % Acessa o primeiro frame (normalizado)
    firstFrame = recordedVideo(:,:,1,1) / 255;
    
    % Exibe o frame em escala de cinza
    imshow(firstFrame, 'Parent', ax);
    title(ax, 'Selecione a ROI e clique duas vezes para confirmar');
    
    % Desenha o retângulo interativo
    h = drawrectangle(ax, 'Label', 'ROI', 'Color', [1 0 0]);
    addlistener(h, 'ROIClicked', @(src,evt) doubleClickCallback(src,evt));
    
    % Espera confirmação por duplo clique
    uiwait(fig);
    
    % Armazena a posição FINAL
    roiPosition = h.Position;  % [x y largura altura]
    close(fig);
    
    % Calcula margem de 10%
    x    = roiPosition(1);
    y    = roiPosition(2);
    w    = roiPosition(3);
    hgt  = roiPosition(4);
    mX   = 0.1 * w;
    mY   = 0.1 * hgt;
    [imgH, imgW] = size(firstFrame);
    x0 = max(1,           floor(x - mX));
    y0 = max(1,           floor(y - mY));
    x1 = min(imgW,        ceil(x + w + mX));
    y1 = min(imgH,        ceil(y + hgt + mY));
    roiCrop = firstFrame(y0:y1, x0:x1);
    
    % Exibe apenas a ROI selecionada com borda vermelha e legenda em inglês
    figure;
    imshow(roiCrop, []);
    hold on;
    
    x_rel = x - x0 + 1;
    y_rel = y - y0 + 1;
    % Desenha borda vermelha ao redor da ROI original dentro do recorte
    rectangle('Position', [x_rel, y_rel, w, hgt], 'EdgeColor', 'r', 'LineWidth', 2);
    hold off;
    title('Selected ROI');
end
