function sortedList = sortKeysWithSuffix(list)
% SORTKEYSWITHSUFFIX - Ordena uma lista (cell array de strings) que contem sufixos.
%
% Remove caracteres não numéricos temporariamente para ordenação numérica.
% Coloca NaNs/desconhecidos ao final da lista.

    if isempty(list)
        sortedList = list;
        return;
    end
    
    % Converte para cell se for string array
    if ~iscell(list)
        list = cellstr(list);
    end
    
    n = numel(list);
    nums = zeros(n, 1);
    for k = 1:n
        valStr = list{k};
        % Remove qualquer coisa que não seja dígito ou ponto decimal
        cleaned = regexprep(valStr, '[^\d\.]', '');
        if isempty(cleaned)
            nums(k) = Inf; % Vai para o final
        else
            valNum = str2double(cleaned);
            if isnan(valNum)
                nums(k) = Inf;
            else
                nums(k) = valNum;
            end
        end
    end
    
    [~, idx] = sort(nums);
    sortedList = list(idx);
end
