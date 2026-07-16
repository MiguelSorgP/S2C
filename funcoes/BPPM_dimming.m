function [S,S0,S1] = BPPM_dimming(msg,P,M,N,K,factor)
% BPPM_DIMMING - Gerador de Sinais Modulados por BPPM com controle de brilho (dimming).
% Esta função modula uma sequência de bits em formas de onda BPPM e aplica
% um fator de brilho (dimming offset) ao nível mínimo de pulso das formas
% de onda S0 e S1 para ajustar o nível médio de iluminação da tela.
%
% Entradas:
%   msg    - Matriz contendo a mensagem binária (bits) [K x M*N]
%   P      - Fator de sobreamostragem (número de subquadros/pulsos por símbolo)
%   M,N    - Dimensões espaciais do bloco
%   K      - Número de bits por pixel
%   factor - Fator de brilho adicionado ao nível de pulso baixo (0.001)
%
% Saídas:
%   S      - Matriz de símbolos modulados gerados [K*P x M*N]
%   S0     - Forma de onda de referência modificada para o bit 1
%   S1     - Forma de onda de referência modificada para o bit 0

S0 = [0.001+factor;ones(P-1,1)];
S1 = [ones(floor(P/2),1);0.001+factor;ones(ceil(P/2)-1,1)];

for mn = 1:M*N
    for k = 1:K
                
        if msg(k,mn)==1
            S((k-1)*P+1:k*P,mn) = S0;   % Símbolo S0.
        elseif  msg(k,mn)==0
            S((k-1)*P+1:k*P,mn) = S1;  % Símbolo S1.
        end
               
    end
end
