function info = parseVideoName(vName)
% PARSEVIDEONAME - Extrai metadados do nome do arquivo do vídeo ou resultado .mat
%
% Exemplo de uso:
%   info = parseVideoName('1y_4x_0z_f5_dark_v1.mp4')
%   info = parseVideoName('1.60-1-f5_dark')
%
% Retorna uma estrutura:
%   - is_valid: true se casar com o formato novo ou legado, false caso contrário
%   - format: 'new', 'old', ou 'unknown'
%   - y_key: valor numérico da chave y (ou NaN)
%   - x_key: valor numérico da chave x (ou NaN)
%   - z_key: valor numérico da chave z (ou NaN)
%   - frames: número de quadros (numérico ou NaN)
%   - is_dark: boolean (true se dark, false se light/normal)
%   - suffix: sufixo de identificação adicional (ex: 'v1', 'v2' ou '')
%   - y_key_str: representação string da chave y (ex: '1y', 'NaN')
%   - x_key_str: representação string da chave x (ex: '1x', 'NaN')
%   - z_key_str: representação string da chave z (ex: '0z', 'NaN')
%   - frames_str: representação string de frames (ex: 'f5', 'NaN')

    % Pega apenas o nome do arquivo, removendo diretórios
    if ischar(vName) || isstring(vName)
        [~, cleaned, ~] = fileparts(vName);
        cleaned = char(cleaned);
    else
        cleaned = '';
    end
    
    % Remove extensões adicionais se houver (como .mat de arquivos de resultado)
    cleaned = regexprep(cleaned, '(_resultado|_fundo)$', '', 'ignorecase');
    cleaned = regexprep(cleaned, '\.mat$', '', 'ignorecase');
    
    % Inicializa campos com valores padrão
    info.is_valid = false;
    info.format = 'unknown';
    info.y_key = NaN;
    info.x_key = NaN;
    info.z_key = NaN;
    info.frames = NaN;
    info.is_dark = false;
    info.suffix = '';
    info.y_key_str = 'NaN';
    info.x_key_str = 'NaN';
    info.z_key_str = 'NaN';
    info.frames_str = 'NaN';
    
    if isempty(cleaned)
        return;
    end
    
    % Verifica se contém '_dark' (case insensitive)
    % Se contiver, sinaliza e remove para simplificar o resto do parsing
    isDark = false;
    if ~isempty(regexpi(cleaned, '_dark'))
        isDark = true;
        cleaned = regexprep(cleaned, '_dark', '', 'ignorecase');
    end
    info.is_dark = isDark;
    
    % 1. Tenta o novo formato: ex: 1y_4x_0z_f5_v1 ou 1y_4x_0z_f5
    % Regex da parte base: ^([\d\.]+)y_([\d\.]+)x_([\d\.]+)z_f(\d+)
    [matchStart, matchEnd] = regexp(cleaned, '^([\d\.]+)y_([\d\.]+)x_([\d\.]+)z_f(\d+)', 'start', 'end');
    
    if ~isempty(matchStart)
        tokens_new = regexp(cleaned, '^([\d\.]+)y_([\d\.]+)x_([\d\.]+)z_f(\d+)', 'tokens');
        info.is_valid = true;
        info.format = 'new';
        info.y_key = str2double(tokens_new{1}{1});
        info.x_key = str2double(tokens_new{1}{2});
        info.z_key = str2double(tokens_new{1}{3});
        info.frames = str2double(tokens_new{1}{4});
        
        info.y_key_str = [tokens_new{1}{1} 'y'];
        info.x_key_str = [tokens_new{1}{2} 'x'];
        info.z_key_str = [tokens_new{1}{3} 'z'];
        info.frames_str = ['f' tokens_new{1}{4}];
        
        % O que restar após o casamento base é o sufixo
        remainder = cleaned(matchEnd+1:end);
        % Remove underscores no início/fim
        remainder = regexprep(remainder, '^_+|_+$', '');
        info.suffix = remainder;
        return;
    end
    
    % 2. Tenta o formato legado: ex: 1.60-1-f5
    % Regex: ^([\d\.]+)-(\d+)-f(\d+)$
    tokens_old = regexp(cleaned, '^([\d\.]+)-(\d+)-f(\d+)$', 'tokens');
    
    if ~isempty(tokens_old)
        info.is_valid = true;
        info.format = 'old';
        info.y_key = str2double(tokens_old{1}{1});
        info.x_key = str2double(tokens_old{1}{2});
        info.z_key = 0; % Z não existia, mapeia para chave 0 por retrocompatibilidade
        info.frames = str2double(tokens_old{1}{3});
        
        info.y_key_str = [tokens_old{1}{1} 'y'];
        info.x_key_str = [tokens_old{1}{2} 'x'];
        info.z_key_str = '0z';
        info.frames_str = ['f' tokens_old{1}{3}];
        return;
    end
end
