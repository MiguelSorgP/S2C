function [S,S0,S1] = BPPM(msg,P,M,N,K)
% BPPM - Gerador de Sinais Modulados por BPPM (Binary Pulse Position Modulation).
% Esta função modula uma sequência de bits em formas de onda BPPM específicas.
% O bit 1 é associado à forma de onda S0 e o bit 0 à forma de onda S1,
% expandindo a dimensão temporal de acordo com o fator de sobreamostragem (pulsos por bit P).
%
% Entradas:
%   msg - Matriz contendo a mensagem binária (bits) [K x M*N]
%   P   - Fator de sobreamostragem (número de subquadros/pulsos por símbolo)
%   M,N - Dimensões espaciais do bloco
%   K   - Número de bits por pixel
%
% Saídas:
%   S   - Matriz de símbolos modulados gerados [K*P x M*N]
%   S0  - Forma de onda de referência para o bit 1
%   S1  - Forma de onda de referência para o bit 0

S0 = [0.001;ones(P-1,1)];
S1 = [ones(floor(P/2),1);0.001;ones(ceil(P/2)-1,1)];

for mn = 1:M*N
    for k = 1:K
                
        if msg(k,mn)==1
            S((k-1)*P+1:k*P,mn) = S0;   % Símbolo S0.
        elseif  msg(k,mn)==0
            S((k-1)*P+1:k*P,mn) = S1;  % Símbolo S1.
        end
               
    end
end
