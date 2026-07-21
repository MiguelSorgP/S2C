function videoFilesSelected = selecionarVideosGUI(videoFiles)
% SELECIONARVIDEOSGUI - Interface gráfica interativa para seleção e filtragem de vídeos gravados.
% Esta função abre uma interface gráfica baseada em App Designer (uifigure e uigridlayout)
% para que o usuário possa selecionar interativamente quais arquivos de vídeo da pasta
% de gravações deseja processar. Permite filtrar vídeos em lote por distância física,
% posição lateral da tela, taxa de amostragem/frames (f5/f10), e iluminação (com/sem luz).
%
% Entradas:
%   videoFiles - Struct array com os metadados dos vídeos encontrados (saída da função dir)
%
% Saídas:
%   videoFilesSelected - Struct array contendo apenas os vídeos selecionados pelo usuário

    names = {videoFiles.name}';
    n = numel(names);
    if n == 0
        videoFilesSelected = videoFiles([]);
        return;
    end
    
    % Inicializa tabela de dados com todos selecionados por padrão
    % Usamos Nome_do_Video para evitar problemas de compatibilidade de nomes de variáveis em tabelas MATLAB
    data = table(true(n, 1), names, 'VariableNames', {'Selecionar', 'Nome_do_Video'});
    
    % Parâmetros para os filtros
    uniqueDists = {};
    uniquePos = {};
    uniqueZ = {};
    uniqueFreqs = {};
    hasLight = false;
    hasDark = false;
    
    % Parse dos nomes dos vídeos
    for i = 1:n
        fName = names{i};
        info = parseVideoName(fName);
        
        if info.is_dark
            hasDark = true;
        else
            hasLight = true;
        end
        
        uniqueDists{end+1} = info.y_key_str;
        uniquePos{end+1} = info.x_key_str;
        uniqueZ{end+1} = info.z_key_str;
        uniqueFreqs{end+1} = info.frames_str;
    end
    
    % Ordena e remove duplicados
    uniqueDists = unique(uniqueDists);
    uniqueDists = sortKeysWithSuffix(uniqueDists);
    
    uniquePos = unique(uniquePos);
    uniquePos = sortKeysWithSuffix(uniquePos);
    
    uniqueZ = unique(uniqueZ);
    uniqueZ = sortKeysWithSuffix(uniqueZ);
    
    uniqueFreqs = unique(uniqueFreqs);
    uniqueFreqs = sortKeysWithSuffix(uniqueFreqs);
    
    % Mapeamento amigável para posições laterais (semelhante ao plotar_Figuras.m)
    posNames = containers.Map({'1', '2', '3', '4', '5'}, ...
        {'Esquerda (1)', 'Intermed. Esq. (2)', 'Centro (3)', 'Intermed. Dir. (4)', 'Direita (5)'});
    
    % Componentes da GUI que serão acessados nas funções internas
    distCheckBoxes = cell(1, length(uniqueDists));
    posCheckBoxes = cell(1, length(uniquePos));
    zCheckBoxes = cell(1, length(uniqueZ));
    freqCheckBoxes = cell(1, length(uniqueFreqs));
    chkLight = [];
    chkDark = [];
    t = [];
    lblCount = [];
    
    % Criação da Figura Principal
    screenSize = get(0, 'ScreenSize');
    figWidth = 950;
    figHeight = 650;
    figX = (screenSize(3) - figWidth) / 2;
    figY = (screenSize(4) - figHeight) / 2;
    
    fig = uifigure('Name', 'Filtro e Seleção de Vídeos para Processamento', ...
                   'Position', [figX, figY, figWidth, figHeight], ...
                   'Resize', 'off');
               
    % Grid Principal (3 linhas, 2 colunas)
    mainGrid = uigridlayout(fig, [3, 2]);
    mainGrid.ColumnWidth = {320, '1x'};
    mainGrid.RowHeight = {40, '1x', 60};
    mainGrid.Padding = [15 15 15 15];
    mainGrid.ColumnSpacing = 15;
    mainGrid.RowSpacing = 10;
    
    % Título
    lblTitle = uilabel(mainGrid, ...
                       'Text', 'Selecionar Vídeos para Processamento', ...
                       'FontSize', 16, ...
                       'FontWeight', 'bold', ...
                       'HorizontalAlignment', 'center');
    lblTitle.Layout.Row = 1;
    lblTitle.Layout.Column = [1 2];
    
    % --- PAINEL ESQUERDO: FILTROS DE SELEÇÃO ---
    pnlLeft = uipanel(mainGrid, ...
                      'Title', 'Filtros de Seleção', ...
                      'FontSize', 12, ...
                      'FontWeight', 'bold', ...
                      'BackgroundColor', [0.96 0.96 0.98]);
    pnlLeft.Layout.Row = 2;
    pnlLeft.Layout.Column = 1;
    
    glLeft = uigridlayout(pnlLeft, [6, 1]);
    glLeft.RowHeight = {'1.6x', '1.4x', '1.2x', '1x', 60, 45};
    glLeft.Padding = [10 10 10 10];
    glLeft.RowSpacing = 10;
    
    % 1) Painel de Distâncias (Y)
    pnlDist = uipanel(glLeft, 'Title', 'Distâncias (Y)', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    numDistRows = max(1, ceil(length(uniqueDists)/2));
    glDist = uigridlayout(pnlDist, [numDistRows, 2]);
    glDist.Padding = [8 8 8 8];
    glDist.RowSpacing = 5;
    glDist.ColumnSpacing = 8;
    for d = 1:length(uniqueDists)
        distVal = uniqueDists{d};
        if endsWith(distVal, 'y')
            distText = distVal;
        else
            distText = [distVal ' m'];
        end
        distCheckBoxes{d} = uicheckbox(glDist, ...
            'Text', distText, ...
            'Value', true, ...
            'Tag', distVal, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 2) Painel de Posições (X)
    pnlPos = uipanel(glLeft, 'Title', 'Posições Laterais (X)', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    numPosRows = max(1, ceil(length(uniquePos)/2));
    glPos = uigridlayout(pnlPos, [numPosRows, 2]);
    glPos.Padding = [8 8 8 8];
    glPos.RowSpacing = 5;
    glPos.ColumnSpacing = 8;
    for p = 1:length(uniquePos)
        posVal = uniquePos{p};
        posValClean = regexprep(posVal, '[^\d\.]', '');
        if isKey(posNames, posValClean)
            posText = posNames(posValClean);
        else
            posText = ['Pos ' posVal];
        end
        posCheckBoxes{p} = uicheckbox(glPos, ...
            'Text', posText, ...
            'Value', true, ...
            'Tag', posVal, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 3) Painel de Alturas (Z)
    pnlZ = uipanel(glLeft, 'Title', 'Alturas (Z)', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    numZRows = max(1, ceil(length(uniqueZ)/2));
    glZ = uigridlayout(pnlZ, [numZRows, 2]);
    glZ.Padding = [8 8 8 8];
    glZ.RowSpacing = 5;
    glZ.ColumnSpacing = 8;
    for z = 1:length(uniqueZ)
        zVal = uniqueZ{z};
        zCheckBoxes{z} = uicheckbox(glZ, ...
            'Text', zVal, ...
            'Value', true, ...
            'Tag', zVal, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 4) Painel de Frequências (F)
    pnlFreq = uipanel(glLeft, 'Title', 'Frequências (F)', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    numFreqRows = max(1, ceil(length(uniqueFreqs)/2));
    glFreq = uigridlayout(pnlFreq, [numFreqRows, 2]);
    glFreq.Padding = [8 8 8 8];
    glFreq.RowSpacing = 5;
    glFreq.ColumnSpacing = 8;
    for f = 1:length(uniqueFreqs)
        freqVal = uniqueFreqs{f};
        freqCheckBoxes{f} = uicheckbox(glFreq, ...
            'Text', upper(freqVal), ...
            'Value', true, ...
            'Tag', freqVal, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 5) Painel de Condições de Iluminação
    pnlLightCond = uipanel(glLeft, 'Title', 'Condição de Iluminação', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    glLightCond = uigridlayout(pnlLightCond, [1, 2]);
    glLightCond.Padding = [8 8 8 8];
    glLightCond.RowSpacing = 5;
    glLightCond.ColumnSpacing = 8;
    
    if hasLight
        chkLight = uicheckbox(glLightCond, ...
            'Text', 'Luz Acesa', ...
            'Value', true, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    if hasDark
        chkDark = uicheckbox(glLightCond, ...
            'Text', 'Luz Apagada', ...
            'Value', true, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 6) Botões de Controle Geral dos Filtros
    glGlobalButtons = uigridlayout(glLeft, [1, 2]);
    glGlobalButtons.ColumnWidth = {'1x', '1x'};
    glGlobalButtons.Padding = [0 0 0 0];
    glGlobalButtons.ColumnSpacing = 10;
    
    uibutton(glGlobalButtons, ...
        'Text', 'Marcar Todos Filtros', ...
        'FontSize', 11, ...
        'ButtonPushedFcn', @(src, event) setAllFilters(true));
    
    uibutton(glGlobalButtons, ...
        'Text', 'Limpar Filtros', ...
        'FontSize', 11, ...
        'ButtonPushedFcn', @(src, event) setAllFilters(false));
    
    % --- PAINEL DIREITO: TABELA E SELEÇÃO DE VÍDEOS ---
    pnlRight = uipanel(mainGrid, ...
                       'Title', 'Vídeos Selecionados (Lista)', ...
                       'FontSize', 12, ...
                       'FontWeight', 'bold', ...
                       'BackgroundColor', [0.96 0.96 0.98]);
    pnlRight.Layout.Row = 2;
    pnlRight.Layout.Column = 2;
    
    glRight = uigridlayout(pnlRight, [2, 1]);
    glRight.RowHeight = {'1x', 40};
    glRight.Padding = [10 10 10 10];
    glRight.RowSpacing = 10;
    
    t = uitable(glRight, ...
                'Data', data, ...
                'ColumnEditable', [true, false], ...
                'ColumnWidth', {80, 480}, ...
                'ColumnName', {'Selecionar', 'Nome do Vídeo'}, ...
                'CellEditCallback', @updateCount);
            
    glControls = uigridlayout(glRight, [1, 3]);
    glControls.ColumnWidth = {150, 150, '1x'};
    glControls.Padding = [0 0 0 0];
    glControls.ColumnSpacing = 10;
    
    uibutton(glControls, ...
             'Text', 'Selecionar Todos', ...
             'ButtonPushedFcn', @selectAllTable);
         
    uibutton(glControls, ...
             'Text', 'Desmarcar Todos', ...
             'ButtonPushedFcn', @deselectAllTable);
         
    lblCount = uilabel(glControls, ...
                       'Text', sprintf('Selecionados: %d de %d', n, n), ...
                       'HorizontalAlignment', 'right', ...
                       'FontSize', 12, ...
                       'FontWeight', 'bold');
                   
    % --- PAINEL INFERIOR: BOTÃO CONFIRMAR ---
    glBottom = uigridlayout(mainGrid, [1, 3]);
    glBottom.Layout.Row = 3;
    glBottom.Layout.Column = [1 2];
    glBottom.ColumnWidth = {'1x', 200, '1x'};
    glBottom.Padding = [0 0 0 0];
    
    uibutton(glBottom, ...
              'Text', 'Confirmar Seleção', ...
              'BackgroundColor', [0.12, 0.53, 0.90], ...
              'FontColor', [1, 1, 1], ...
              'FontWeight', 'bold', ...
              'FontSize', 14, ...
              'ButtonPushedFcn', @(btn, event) confirmSelection(fig));
          
    % Bloqueia a execução até interação
    uiwait(fig);
    
    % Se a janela foi fechada pelo 'X'
    if ~isvalid(fig)
        error('Seleção de vídeos cancelada pelo usuário.');
    end
    
    % Pega a seleção final
    finalData = t.Data;
    selectedIndices = finalData.Selecionar;
    close(fig);
    videoFilesSelected = videoFiles(selectedIndices);
    
    % --- Funções Aninhadas (Callbacks) ---
    
    function applyFilters()
        checkedDists = {};
        for dIdx = 1:numel(distCheckBoxes)
            if distCheckBoxes{dIdx}.Value
                checkedDists{end+1} = distCheckBoxes{dIdx}.Tag;
            end
        end
        
        checkedPos = {};
        for pIdx = 1:numel(posCheckBoxes)
            if posCheckBoxes{pIdx}.Value
                checkedPos{end+1} = posCheckBoxes{pIdx}.Tag;
            end
        end

        checkedZ = {};
        for zIdx = 1:numel(zCheckBoxes)
            if zCheckBoxes{zIdx}.Value
                checkedZ{end+1} = zCheckBoxes{zIdx}.Tag;
            end
        end
        
        checkedFreqs = {};
        for fIdx = 1:numel(freqCheckBoxes)
            if freqCheckBoxes{fIdx}.Value
                checkedFreqs{end+1} = freqCheckBoxes{fIdx}.Tag;
            end
        end
        
        checkedLight = true;
        if hasLight && isvalid(chkLight)
            checkedLight = chkLight.Value;
        end
        
        checkedDark = true;
        if hasDark && isvalid(chkDark)
            checkedDark = chkDark.Value;
        end
        
        tData = t.Data;
        for rowIdx = 1:size(tData, 1)
            vName = tData.Nome_do_Video{rowIdx};
            info = parseVideoName(vName);
            
            matchDist = ismember(info.y_key_str, checkedDists);
            matchPos = ismember(info.x_key_str, checkedPos);
            matchZ = ismember(info.z_key_str, checkedZ);
            matchFreq = ismember(info.frames_str, checkedFreqs);
            if info.is_dark
                matchLight = checkedDark;
            else
                matchLight = checkedLight;
            end
            
            tData.Selecionar(rowIdx) = matchDist && matchPos && matchZ && matchFreq && matchLight;
        end
        t.Data = tData;
        updateCount();
    end

    function setAllFilters(val)
        for dIdx = 1:numel(distCheckBoxes)
            distCheckBoxes{dIdx}.Value = val;
        end
        for pIdx = 1:numel(posCheckBoxes)
            posCheckBoxes{pIdx}.Value = val;
        end
        for zIdx = 1:numel(zCheckBoxes)
            zCheckBoxes{zIdx}.Value = val;
        end
        for fIdx = 1:numel(freqCheckBoxes)
            freqCheckBoxes{fIdx}.Value = val;
        end
        if hasLight && isvalid(chkLight)
            chkLight.Value = val;
        end
        if hasDark && isvalid(chkDark)
            chkDark.Value = val;
        end
        applyFilters();
    end

    function updateCount(tableObj, labelObj)
        if nargin < 1 || isempty(tableObj) || ~isa(tableObj, 'matlab.ui.control.Table')
            tableObj = t;
        end
        if nargin < 2 || isempty(labelObj) || ~isa(labelObj, 'matlab.ui.control.Label')
            labelObj = lblCount;
        end
        if isempty(tableObj) || ~isvalid(tableObj) || isempty(labelObj) || ~isvalid(labelObj)
            return;
        end
        tableData = tableObj.Data;
        numSelected = sum(tableData.Selecionar);
        total = size(tableData, 1);
        labelObj.Text = sprintf('Selecionados: %d de %d', numSelected, total);
    end

    function selectAllTable(~, ~)
        if isempty(t) || ~isvalid(t)
            return;
        end
        t.Data.Selecionar(:) = true;
        updateCount();
    end

    function deselectAllTable(~, ~)
        if isempty(t) || ~isvalid(t)
            return;
        end
        t.Data.Selecionar(:) = false;
        updateCount();
    end

    function confirmSelection(figHandle)
        uiresume(figHandle);
    end
end
