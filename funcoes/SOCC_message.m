function [msg,S,S0,S1] = SOCC_message(M,N,P,K,K1,modOCC,factor)
% SOCC_MESSAGE - Gera uma mensagem aleatória e modula os símbolos com inserção de pilotos.
% Esta função cria uma sequência de bits pseudo-aleatória de informação para cada pixel
% da tela e executa a modulação correspondente (como BPPM). Também insere pilotos físicos
% conhecidos nas duas primeiras linhas da matriz de símbolos S para permitir que o receptor
% resolva as ambiguidades de escala (primeira linha preenchida com uns) e permutação
% (segunda linha preenchida com uma rampa crescente de valores).
%
% Entradas:
%   M, N   - Dimensões espaciais do bloco
%   P      - Fator de sobreamostragem (pulsos por símbolo)
%   K      - Dimensão temporal de codificação (K = K1 * P)
%   K1     - Número de bits por pixel
%   modOCC - Nome do esquema de modulação utilizado (e.g. 'BPPM')
%   factor - Fator de controle de brilho (offset)
%
% Saídas:
%   msg    - Matriz de bits gerados aleatoriamente [K1 x M*N]
%   S      - Matriz de símbolos modulados com pilotos inseridos [K x M*N]
%   S0     - Forma de onda de referência para o bit 1
%   S1     - Forma de onda de referência para o bit 0

 msg = randi([0 1], K1,M*N);
    
    
    
    %% Matriz S com blocos de símbolos
    
    S = ones(K,M*N);
    
    factor = 0; % nível de sinal em nível baixo, 0<=factor<=1
    
    if modOCC == 'BPPM', [S,S0,S1] = BPPM(msg,P,M,N,K1);
    elseif modOCC == 'BPPM_dim',[S,S0,S1] = BPPM_dimming(msg,P,M,N,K1,factor);
    elseif modOCC == 'OOK', [S,S0,S1] = OOK_OCC(msg,P,M,N,K1);
    elseif modOCC == 'OOK_dim',[S,S0,S1] = OOK_dimming_OCC(msg,P,M,N,K1,factor);
    end
    
    S(1,:) = ones(1,M*N);
    %S(1,:) = 1:-1/(M*N):1/(M*N);
    S(2,:) = 1/(M*N):1/(M*N):1;
    
end
