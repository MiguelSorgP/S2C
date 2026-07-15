function videoFilesSelected = selecionarVideosGUI(videoFiles)
    % SELECIONARVIDEOSGUI Abre uma interface gráfica para selecionar os vídeos a serem processados.
    %
    %   Entrada:
    %       videoFiles - Struct array contendo a lista completa de vídeos (.mp4)
    %
    %   Saída:
    %       videoFilesSelected - Struct array contendo apenas os vídeos selecionados pelo usuário.

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
    uniqueFreqs = {};
    hasLight = false;
    hasDark = false;
    
    % Parse dos nomes dos vídeos
    for i = 1:n
        fName = names{i};
        [~, cleaned, ~] = fileparts(fName);
        
        isDark = ~isempty(strfind(lower(cleaned), '_dark'));
        if isDark
            hasDark = true;
        else
            hasLight = true;
        end
        
        cleaned = strrep(cleaned, '_dark', '');
        cleaned = strrep(cleaned, '_DARK', '');
        
        parts = strsplit(cleaned, '-');
        if numel(parts) >= 3
            uniqueDists{end+1} = parts{1};
            uniquePos{end+1} = parts{2};
            uniqueFreqs{end+1} = parts{3};
        end
    end
    
    % Ordena e remove duplicados
    uniqueDists = unique(uniqueDists);
    if ~isempty(uniqueDists)
        distNums = cellfun(@str2double, uniqueDists);
        distNums(isnan(distNums)) = Inf;
        [~, idx] = sort(distNums);
        uniqueDists = uniqueDists(idx);
    end
    
    uniquePos = unique(uniquePos);
    if ~isempty(uniquePos)
        posNums = cellfun(@str2double, uniquePos);
        posNums(isnan(posNums)) = Inf;
        [~, idx] = sort(posNums);
        uniquePos = uniquePos(idx);
    end
    
    uniqueFreqs = unique(uniqueFreqs);
    if ~isempty(uniqueFreqs)
        [~, idx] = sort(uniqueFreqs);
        uniqueFreqs = uniqueFreqs(idx);
    end
    
    % Mapeamento amigável para posições laterais (semelhante ao plotar_Figuras.m)
    posNames = containers.Map({'1', '2', '3', '4', '5'}, ...
        {'Esquerda (1)', 'Intermed. Esq. (2)', 'Centro (3)', 'Intermed. Dir. (4)', 'Direita (5)'});
    
    % Componentes da GUI que serão acessados nas funções internas
    distCheckBoxes = cell(1, length(uniqueDists));
    posCheckBoxes = cell(1, length(uniquePos));
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
    
    glLeft = uigridlayout(pnlLeft, [5, 1]);
    glLeft.RowHeight = {'1.8x', '1.6x', '1x', 60, 45};
    glLeft.Padding = [10 10 10 10];
    glLeft.RowSpacing = 10;
    
    % 1) Painel de Distâncias
    pnlDist = uipanel(glLeft, 'Title', 'Distâncias', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    numDistRows = max(1, ceil(length(uniqueDists)/2));
    glDist = uigridlayout(pnlDist, [numDistRows, 2]);
    glDist.Padding = [8 8 8 8];
    glDist.RowSpacing = 5;
    glDist.ColumnSpacing = 8;
    for d = 1:length(uniqueDists)
        distVal = uniqueDists{d};
        distCheckBoxes{d} = uicheckbox(glDist, ...
            'Text', [distVal ' m'], ...
            'Value', true, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 2) Painel de Posições
    pnlPos = uipanel(glLeft, 'Title', 'Posições Laterais', 'FontWeight', 'bold', 'BackgroundColor', [0.96 0.96 0.98]);
    numPosRows = max(1, ceil(length(uniquePos)/2));
    glPos = uigridlayout(pnlPos, [numPosRows, 2]);
    glPos.Padding = [8 8 8 8];
    glPos.RowSpacing = 5;
    glPos.ColumnSpacing = 8;
    for p = 1:length(uniquePos)
        posVal = uniquePos{p};
        if isKey(posNames, posVal)
            posText = posNames(posVal);
        else
            posText = ['Pos ' posVal];
        end
        posCheckBoxes{p} = uicheckbox(glPos, ...
            'Text', posText, ...
            'Value', true, ...
            'Tag', posVal, ...
            'ValueChangedFcn', @(src, event) applyFilters());
    end
    
    % 3) Painel de Frequências
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
    
    % 4) Painel de Condições de Iluminação
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
    
    % 5) Botões de Controle Geral dos Filtros
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
                'CellEditCallback', @(src, event) updateCount(src, lblCount));
            
    glControls = uigridlayout(glRight, [1, 3]);
    glControls.ColumnWidth = {150, 150, '1x'};
    glControls.Padding = [0 0 0 0];
    glControls.ColumnSpacing = 10;
    
    uibutton(glControls, ...
             'Text', 'Selecionar Todos', ...
             'ButtonPushedFcn', @(src, event) selectAllTable(t, lblCount));
         
    uibutton(glControls, ...
             'Text', 'Desmarcar Todos', ...
             'ButtonPushedFcn', @(src, event) deselectAllTable(t, lblCount));
         
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
                txt = distCheckBoxes{dIdx}.Text;
                val = strrep(txt, ' m', '');
                checkedDists{end+1} = val;
            end
        end
        
        checkedPos = {};
        for pIdx = 1:numel(posCheckBoxes)
            if posCheckBoxes{pIdx}.Value
                checkedPos{end+1} = posCheckBoxes{pIdx}.Tag;
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
            [~, cleaned, ~] = fileparts(vName);
            
            isDark = ~isempty(strfind(lower(cleaned), '_dark'));
            cleaned = strrep(cleaned, '_dark', '');
            cleaned = strrep(cleaned, '_DARK', '');
            
            parts = strsplit(cleaned, '-');
            if numel(parts) >= 3
                dVal = parts{1};
                pVal = parts{2};
                fVal = parts{3};
                
                matchDist = ismember(dVal, checkedDists);
                matchPos = ismember(pVal, checkedPos);
                matchFreq = ismember(fVal, checkedFreqs);
                if isDark
                    matchLight = checkedDark;
                else
                    matchLight = checkedLight;
                end
                
                tData.Selecionar(rowIdx) = matchDist && matchPos && matchFreq && matchLight;
            else
                % Se o arquivo não segue o padrão de nomenclatura, mantém a regra de luz
                if isDark
                    tData.Selecionar(rowIdx) = checkedDark;
                else
                    tData.Selecionar(rowIdx) = checkedLight;
                end
            end
        end
        t.Data = tData;
        updateCount(t, lblCount);
    end

    function setAllFilters(val)
        for dIdx = 1:numel(distCheckBoxes)
            distCheckBoxes{dIdx}.Value = val;
        end
        for pIdx = 1:numel(posCheckBoxes)
            posCheckBoxes{pIdx}.Value = val;
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
        tableData = tableObj.Data;
        numSelected = sum(tableData.Selecionar);
        total = size(tableData, 1);
        labelObj.Text = sprintf('Selecionados: %d de %d', numSelected, total);
    end

    function selectAllTable(tableObj, labelObj)
        tableObj.Data.Selecionar(:) = true;
        updateCount(tableObj, labelObj);
    end

    function deselectAllTable(tableObj, labelObj)
        tableObj.Data.Selecionar(:) = false;
        updateCount(tableObj, labelObj);
    end

    function confirmSelection(figHandle)
        uiresume(figHandle);
    end
end
