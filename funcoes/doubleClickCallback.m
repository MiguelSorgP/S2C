function doubleClickCallback(src, evt)
% DOUBLECLICKCALLBACK - Função de callback para evento de clique duplo na ROI.
% Esta função retoma a execução do programa principal (uiresume) assim que o usuário
% clica duas vezes sobre o retângulo de ROI desenhado na tela interativa.
%
% Entradas:
%   src - Objeto fonte do evento (drawrectangle)
%   evt - Dados do evento contendo o tipo de seleção (SelectionType)

    if strcmp(evt.SelectionType, 'double')
        uiresume;
    end
end
