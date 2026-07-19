function mudarPerspectivaVideo(videoInputPath, videoOutputPath)
% MUDARPERSPECTIVAVIDEO Permite ajustar a perspectiva de um vídeo interativamente.
%
%   Uso:
%       mudarPerspectivaVideo() - Abre caixa de seleção de vídeo e inicia GUI.
%       mudarPerspectivaVideo(videoInputPath) - Abre GUI para o vídeo especificado.
%       mudarPerspectivaVideo(videoInputPath, videoOutputPath) - Executa com os caminhos fornecidos.

% Se não passar argumentos ou se estiver vazio, pede para o usuário selecionar o arquivo de vídeo
if nargin < 1 || isempty(videoInputPath)
    [file, path] = uigetfile({'*.mp4;*.avi;*.mkv;*.mov', 'Vídeos (*.mp4, *.avi, *.mkv, *.mov)'; '*.*', 'Todos os Arquivos (*.*)'}, 'Selecione o vídeo original');
    if isequal(file, 0)
        disp('Seleção de vídeo cancelada pelo usuário.');
        return;
    end
    videoInputPath = fullfile(path, file);
end

% Configurar a leitura do vídeo original
videoIn = VideoReader(videoInputPath);
largura = videoIn.Width;
altura = videoIn.Height;
taxaQuadros = videoIn.FrameRate;

% Carregar o primeiro frame para calibração e visualização interativa
firstFrame = readFrame(videoIn);

% Definir o caminho de saída inteligente (sufixo _perspectiva com incremento)
if nargin < 2 || isempty(videoOutputPath)
    [dirPath, name, ext] = fileparts(videoInputPath);
    if isempty(dirPath)
        dirPath = pwd;
    end
    baseName = [name, '_perspectiva'];
    videoOutputPath = fullfile(dirPath, [baseName, ext]);
else
    [dirPath, name, ext] = fileparts(videoOutputPath);
    if isempty(dirPath)
        dirPath = pwd;
    end
    baseName = name;
end

% Lógica para incremento caso o arquivo já exista (ex: _1, _2...)
if exist(videoOutputPath, 'file')
    counter = 1;
    while true
        videoOutputPath = fullfile(dirPath, sprintf('%s_%d%s', baseName, counter, ext));
        if ~exist(videoOutputPath, 'file')
            break;
        end
        counter = counter + 1;
    end
end

% Valores padrão das variáveis de controle da câmera virtual
pitchVal = 0;
yawVal = 0;
rollVal = 0;
zoomVal = 1.0;
shiftXVal = 0;
shiftYVal = 0;

% Pontos originais (os 4 cantos da tela original)
pontosOriginais = [
    1,       1;
    largura, 1;
    largura, altura;
    1,       altura
];

% Inicializar pontos novos com base nos valores padrão do modelo de projeção
pontosNovos = calcularPontosProj();

% Criar a figura da interface gráfica centralizada na tela
screenSize = get(0, 'ScreenSize');
figWidth = 1100;
figHeight = 700;
figX = (screenSize(3) - figWidth) / 2;
figY = (screenSize(4) - figHeight) / 2;

fig = figure('Name', 'Calibração de Perspectiva do Vídeo', ...
             'NumberTitle', 'off', ...
             'MenuBar', 'none', ...
             'ToolBar', 'none', ...
             'Position', [figX, figY, figWidth, figHeight], ...
             'Color', [0.18, 0.18, 0.2], ...
             'Resize', 'on');

% Eixo Esquerdo: Imagem Original + Cantos
axIn = axes('Parent', fig, ...
            'Position', [0.03, 0.35, 0.44, 0.60], ...
            'Color', [0.12, 0.12, 0.12]);
imshow(firstFrame, 'Parent', axIn);
axis(axIn, 'image', 'off');
hold(axIn, 'on');
title(axIn, 'Imagem Original: Arraste os cantos coloridos para ajuste fino manual', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

% Eixo Direito: Preview da Transformação
axOut = axes('Parent', fig, ...
             'Position', [0.53, 0.35, 0.44, 0.60], ...
             'Color', [0.12, 0.12, 0.12]);
hImgOut = imshow(firstFrame, 'Parent', axOut);
axis(axOut, 'image', 'off');
title(axOut, 'Visualização da Perspectiva Projetada (Saída)', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');

% Desenhar linhas tracejadas conectando os cantos
hLines = plot(axIn, [pontosNovos(:,1); pontosNovos(1,1)], [pontosNovos(:,2); pontosNovos(1,2)], 'y--', 'LineWidth', 2);

% Desenhar os 4 cantos coloridos interativos com etiquetas (SE, SD, ID, IE)
hPoints = zeros(4, 1);
hTexts = zeros(4, 1);
colors = [
    1 0.2 0.2; % Vermelho (Superior-Esquerdo - SE)
    0.2 1 0.2; % Verde (Superior-Direito - SD)
    0.2 0.2 1; % Azul (Inferior-Direito - ID)
    1 1 0.2    % Amarelo (Inferior-Esquerdo - IE)
];
labels = {'SE', 'SD', 'ID', 'IE'};

for i = 1:4
    hPoints(i) = plot(axIn, pontosNovos(i, 1), pontosNovos(i, 2), 'o', ...
        'MarkerSize', 10, ...
        'MarkerEdgeColor', 'w', ...
        'MarkerFaceColor', colors(i, :), ...
        'LineWidth', 1.5, ...
        'ButtonDownFcn', @(src, event) iniciarArrastar(i));
        
    hTexts(i) = text(pontosNovos(i, 1), pontosNovos(i, 2) - altura*0.03, labels{i}, ...
        'Color', 'w', ...
        'BackgroundColor', colors(i, :), ...
        'FontSize', 9, ...
        'FontWeight', 'bold', ...
        'Parent', axIn, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom');
end

% Configurar a área de visualização do tamanho de saída
visaoSaida = imref2d([altura, largura]);

% Painel de controle inferior para os sliders de perspectiva
pnlControles = uipanel('Parent', fig, ...
                       'Position', [0.03, 0.02, 0.94, 0.28], ...
                       'BackgroundColor', [0.22, 0.22, 0.25], ...
                       'ForegroundColor', 'w', ...
                       'Title', ' Controles de Câmera Virtual & Projeção ', ...
                       'FontWeight', 'bold', ...
                       'FontSize', 10);

% Criar os controles deslizantes (sliders) e rótulos (labels)
[sldPitch, lblPitch] = criarControleSlider(pnlControles, 0.02, 0.14, 0.68, 0.11, 0.25, 0.20, 'Pitch (Tilt): 0.0°', -60, 60, 0, 'pitch');
[sldYaw,   lblYaw]   = criarControleSlider(pnlControles, 0.02, 0.14, 0.38, 0.11, 0.25, 0.20, 'Yaw (Pan): 0.0°', -60, 60, 0, 'yaw');
[sldRoll,  lblRoll]  = criarControleSlider(pnlControles, 0.02, 0.14, 0.08, 0.11, 0.25, 0.20, 'Roll (Giro): 0.0°', -60, 60, 0, 'roll');

[sldZoom,   lblZoom]   = criarControleSlider(pnlControles, 0.44, 0.58, 0.68, 0.13, 0.25, 0.20, 'Zoom: 1.00x', 0.3, 3.0, 1.0, 'zoom');
[sldShiftX, lblShiftX] = criarControleSlider(pnlControles, 0.44, 0.58, 0.38, 0.13, 0.25, 0.20, 'Deslocamento X: 0 px', -largura/2, largura/2, 0, 'shiftX');
[sldShiftY, lblShiftY] = criarControleSlider(pnlControles, 0.44, 0.58, 0.08, 0.13, 0.25, 0.20, 'Deslocamento Y: 0 px', -altura/2, altura/2, 0, 'shiftY');

% Botões de ação do painel lateral
uicontrol('Parent', pnlControles, ...
          'Style', 'pushbutton', ...
          'String', 'Redefinir Sliders', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.68, 0.12, 0.20], ...
          'BackgroundColor', [0.35, 0.35, 0.38], ...
          'ForegroundColor', 'w', ...
          'FontWeight', 'bold', ...
          'Callback', @btnResetCallback);
                 
uicontrol('Parent', pnlControles, ...
          'Style', 'pushbutton', ...
          'String', 'Confirmar e Processar', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.38, 0.12, 0.20], ...
          'BackgroundColor', [0.15, 0.55, 0.15], ...
          'ForegroundColor', 'w', ...
          'FontWeight', 'bold', ...
          'Callback', @btnConfirmCallback);
                   
uicontrol('Parent', pnlControles, ...
          'Style', 'pushbutton', ...
          'String', 'Cancelar', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.08, 0.12, 0.20], ...
          'BackgroundColor', [0.55, 0.15, 0.15], ...
          'ForegroundColor', 'w', ...
          'FontWeight', 'bold', ...
          'Callback', @btnCancelCallback);

% Configurar variáveis de controle e interações com o mouse
set(fig, 'CloseRequestFcn', @closeFigCallback);
activePointIdx = 0;
processVideo = false;

% Atualizar a exibição para o estado inicial
atualizarVisualizacao();

% Bloquear execução do MATLAB enquanto o usuário ajusta a perspectiva
uiwait(fig);

% Prosseguir com o processamento do vídeo apenas se o usuário tiver confirmado
if ~processVideo
    disp('Processamento cancelado pelo usuário.');
    return;
end

% Configurar a gravação do novo vídeo de saída
videoOut = VideoWriter(videoOutputPath, 'MPEG-4');
videoOut.FrameRate = taxaQuadros;
videoOut.Quality = 95;
open(videoOut);

% Calcular a matriz final de transformação (homografia)
tform = fitgeotrans(pontosOriginais, pontosNovos, 'projective');

disp(['Iniciando processamento dos frames do vídeo: ', videoInputPath]);
disp(['Destino do vídeo gerado: ', videoOutputPath]);

% Configurar barra de progresso nativa do MATLAB
hWait = waitbar(0, 'Processando os frames do vídeo...', 'Name', 'Processando Vídeo');
videoIn.CurrentTime = 0;
totalFrames = round(videoIn.FrameRate * videoIn.Duration);
frameCounter = 0;

try
    while hasFrame(videoIn)
        frameOriginal = readFrame(videoIn);
        
        % Aplicar a transformação geométrica de perspectiva calibrada
        frameTransformado = imwarp(frameOriginal, tform, 'OutputView', visaoSaida, 'FillValues', 0);
        
        % Gravar o frame processado no novo arquivo de vídeo
        writeVideo(videoOut, frameTransformado);
        
        frameCounter = frameCounter + 1;
        if mod(frameCounter, 10) == 0 && ~isempty(hWait) && ishandle(hWait)
            progresso = min(frameCounter / totalFrames, 1.0);
            waitbar(progresso, hWait, sprintf('Processando: %.1f%% (%d/%d frames)', progresso * 100, frameCounter, totalFrames));
        end
    end
catch ME
    disp('Ocorreu um erro durante o processamento do vídeo:');
    disp(ME.message);
end

% Fechar a barra de progresso e finalizar a escrita do vídeo
if ~isempty(hWait) && ishandle(hWait)
    close(hWait);
end
close(videoOut);
disp(['Vídeo processado com sucesso e salvo em: ', videoOutputPath]);


% ================= FUNÇÕES INTERNAS ANINHADAS (NESTED) =================

    function ptsNovos = calcularPontosProj()
        % Converte ângulos de graus para radianos
        rx = deg2rad(pitchVal);
        ry = deg2rad(yawVal);
        rz = deg2rad(rollVal);
        
        % Matrizes de rotação 3D para o plano
        Rx = [1, 0, 0; 0, cos(rx), sin(rx); 0, -sin(rx), cos(rx)];
        Ry = [cos(ry), 0, -sin(ry); 0, 1, 0; sin(ry), 0, cos(ry)];
        Rz = [cos(rz), -sin(rz), 0; sin(rz), cos(rz), 0; 0, 0, 1];
        
        R = Rz * Ry * Rx;
        
        % Coordenadas centralizadas dos 4 cantos da imagem de entrada
        pts = [
            -(largura-1)/2, -(altura-1)/2, 0;
             (largura-1)/2, -(altura-1)/2, 0;
             (largura-1)/2,  (altura-1)/2, 0;
            -(largura-1)/2,  (altura-1)/2, 0
        ]';
        
        % Aplicar rotação 3D aos pontos do plano
        ptsRot = R * pts;
        
        % Distância focal e câmera virtual
        D = max(largura, altura);
        f = D * zoomVal;
        
        ptsNovos = zeros(4, 2);
        for k = 1:4
            X = ptsRot(1, k) + shiftXVal;
            Y = ptsRot(2, k) + shiftYVal;
            Z = D + ptsRot(3, k);
            
            % Garantir que os pontos não fiquem atrás do plano de corte da câmera
            if Z < 10
                Z = 10;
            end
            
            % Projeção perspectiva para coordenadas de pixel na tela
            ptsNovos(k, 1) = f * X / Z + (largura+1)/2;
            ptsNovos(k, 2) = f * Y / Z + (altura+1)/2;
        end
    end

    function [sld, lbl] = criarControleSlider(parent, xLbl, xSld, y, wLbl, wSld, h, nome, minVal, maxVal, valPadrao, callbackType)
        % Cria o texto descritivo e o slider correspondente
        lbl = uicontrol('Parent', parent, ...
                        'Style', 'text', ...
                        'String', nome, ...
                        'Units', 'normalized', ...
                        'Position', [xLbl, y, wLbl, h], ...
                        'BackgroundColor', [0.22, 0.22, 0.25], ...
                        'ForegroundColor', 'w', ...
                        'HorizontalAlignment', 'left', ...
                        'FontSize', 9);
        sld = uicontrol('Parent', parent, ...
                        'Style', 'slider', ...
                        'Min', minVal, ...
                        'Max', maxVal, ...
                        'Value', valPadrao, ...
                        'Units', 'normalized', ...
                        'Position', [xSld, y, wSld, h], ...
                        'Callback', @(src, event) sliderCallback(src, event, callbackType));
    end

    function sliderCallback(src, ~, type)
        % Atualiza os valores das variáveis com base na ação do usuário nos sliders
        val = get(src, 'Value');
        switch type
            case 'pitch'
                pitchVal = val;
                lblPitch.String = sprintf('Pitch (Tilt): %.1f°', val);
            case 'yaw'
                yawVal = val;
                lblYaw.String = sprintf('Yaw (Pan): %.1f°', val);
            case 'roll'
                rollVal = val;
                lblRoll.String = sprintf('Roll (Giro): %.1f°', val);
            case 'zoom'
                zoomVal = val;
                lblZoom.String = sprintf('Zoom: %.2fx', val);
            case 'shiftX'
                shiftXVal = val;
                lblShiftX.String = sprintf('Deslocamento X: %.0f px', val);
            case 'shiftY'
                shiftYVal = val;
                lblShiftY.String = sprintf('Deslocamento Y: %.0f px', val);
        end
        
        % Recalcular pontos com base no modelo 3D atualizado
        pontosNovos = calcularPontosProj();
        atualizarVisualizacao();
    end

    function atualizarVisualizacao()
        % 1. Atualizar posições das linhas e marcadores no painel esquerdo
        set(hLines, 'XData', [pontosNovos(:,1); pontosNovos(1,1)], 'YData', [pontosNovos(:,2); pontosNovos(1,2)]);
        for k = 1:4
            set(hPoints(k), 'XData', pontosNovos(k, 1), 'YData', pontosNovos(k, 2));
            set(hTexts(k), 'Position', [pontosNovos(k, 1), pontosNovos(k, 2) - altura*0.03, 0]);
        end
        
        % 2. Calcular a projeção e atualizar o preview no painel direito
        try
            tform = fitgeotrans(pontosOriginais, pontosNovos, 'projective');
            framePreview = imwarp(firstFrame, tform, 'OutputView', visaoSaida, 'FillValues', 0);
            set(hImgOut, 'CData', framePreview);
        catch
            % Silencia exceções se o usuário arrastar os cantos para uma posição inválida/colinear
        end
    end

    function btnResetCallback(~, ~)
        % Reseta todos os parâmetros para a configuração padrão da câmera
        pitchVal = 0;
        yawVal = 0;
        rollVal = 0;
        zoomVal = 1.0;
        shiftXVal = 0;
        shiftYVal = 0;
        
        set(sldPitch, 'Value', 0);
        set(sldYaw, 'Value', 0);
        set(sldRoll, 'Value', 0);
        set(sldZoom, 'Value', 1.0);
        set(sldShiftX, 'Value', 0);
        set(sldShiftY, 'Value', 0);
        
        lblPitch.String = 'Pitch (Tilt): 0.0°';
        lblYaw.String = 'Yaw (Pan): 0.0°';
        lblRoll.String = 'Roll (Giro): 0.0°';
        lblZoom.String = 'Zoom: 1.00x';
        lblShiftX.String = 'Deslocamento X: 0 px';
        lblShiftY.String = 'Deslocamento Y: 0 px';
        
        pontosNovos = calcularPontosProj();
        atualizarVisualizacao();
    end

    function btnConfirmCallback(~, ~)
        processVideo = true;
        close(fig);
    end

    function btnCancelCallback(~, ~)
        processVideo = false;
        close(fig);
    end

    function closeFigCallback(~, ~)
        delete(fig);
    end

    function iniciarArrastar(idx)
        % Registra callbacks para captura de mouse durante o arrasto manual do canto
        activePointIdx = idx;
        set(fig, 'WindowButtonMotionFcn', @arrastar);
        set(fig, 'WindowButtonUpFcn', @pararArrastar);
    end

    function arrastar(~, ~)
        if activePointIdx == 0, return; end
        
        % Determina as coordenadas do ponteiro no sistema de eixos da imagem original
        coords = get(axIn, 'CurrentPoint');
        x = coords(1, 1);
        y = coords(1, 2);
        
        % Limitar as coordenadas aos limites aproximados da imagem (+/- 20% de margem)
        x = max(1 - largura*0.2, min(largura*1.2, x));
        y = max(1 - altura*0.2, min(altura*1.2, y));
        
        pontosNovos(activePointIdx, :) = [x, y];
        atualizarVisualizacao();
    end

    function pararArrastar(~, ~)
        % Desliga a captura de mouse após soltar o botão
        activePointIdx = 0;
        set(fig, 'WindowButtonMotionFcn', '');
        set(fig, 'WindowButtonUpFcn', '');
    end

end