function SER = SER_OCC(S,S0,S1,Bmod,P,M,N,K1)
% SER_OCC - Calcula a taxa de erro de símbolo (SER - Symbol Error Rate).
% Esta função calcula o SER comparando a matriz de símbolos estimados Bmod
% com a matriz original de símbolos transmitidos S. Desconsidera o primeiro
% símbolo (piloto) de cada coluna na avaliação da taxa de erro e realiza a
% classificação por distância euclidiana mínima.
%
% Entradas:
%   S     - Matriz de símbolos originais [K1*P x M*N]
%   S0    - Forma de onda de referência para bit 1 [P x 1]
%   S1    - Forma de onda de referência para bit 0 [P x 1]
%   Bmod  - Matriz de símbolos estimados [K1*P x M*N] (2D) ou [K1*P x M*N x MC] (3D)
%   P     - Fator de sobreamostragem (pulsos por símbolo)
%   M, N  - Dimensões espaciais do bloco
%   K1    - Número de bits por pixel
%
% Saídas:
%   SER   - Vetor de taxas de erro de símbolo [1 x MC]

% S: [K1*P, M*N]
% S0: [P, 1]
% S1: [P, 1]
% Bmod: [K1*P, M*N] ou [K1*P, M*N, MC]

if ndims(Bmod) == 3
    MC = size(Bmod, 3);
else
    MC = 1;
end

S_reshaped = reshape(S, P, K1, M*N);
Soriginal = S_reshaped(:, 2:end, :); % tamanho [P, K1-1, M*N]

Bmod_reshaped = reshape(Bmod, P, K1, M*N, MC);
Sestim_all = Bmod_reshaped(:, 2:end, :, :); % tamanho [P, K1-1, M*N, MC]

% S0 e S1 possuem dimensão [P, 1]. O broadcasting é automático.
e1_all = sum((Sestim_all - S0).^2, 1) ./ sum(Sestim_all.^2, 1);
e2_all = sum((Sestim_all - S1).^2, 1) ./ sum(Sestim_all.^2, 1);

is_true_S1 = (Soriginal(1, :, :) == S1(1)); % tamanho [1, K1-1, M*N]
is_decoded_S1 = (e1_all > e2_all); % tamanho [1, K1-1, M*N, MC]

symbol_error = (is_decoded_S1 ~= is_true_S1); % tamanho [1, K1-1, M*N, MC]

SER = sum(symbol_error, [2, 3]) / ((K1-1) * M * N); % tamanho [1, 1, MC]
SER = reshape(SER, 1, MC);
end
