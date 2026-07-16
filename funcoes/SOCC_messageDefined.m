function [msg,S,S0,S1] = SOCC_message(M,N,P,K,K1,modOCC,factor)
% SOCC_MESSAGEDEFINED - Gera uma mensagem de teste estruturada com cabeçalho de metadados e modula os símbolos.
% Esta função cria uma sequência de bits binários que contém um cabeçalho estruturado
% (piloto) composto de:
%   - 9 bits iguais a 1 (sincronização de metadados)
%   - 3 bits de ID do transmissor (0 0 1)
%   - 12 bits para a dimensão vertical da tela
%   - 12 bits para a dimensão horizontal da tela
% A mensagem de controle é injetada no vetor de dados temporais e modulada, 
% inserindo adicionalmente pilotos de escala e permutação na matriz de símbolos S.
%
% Entradas:
%   M, N   - Dimensões espaciais do bloco
%   P      - Fator de sobreamostragem (pulsos por símbolo)
%   K      - Dimensão temporal de codificação (K = K1 * P)
%   K1     - Número de bits por pixel
%   modOCC - Esquema de modulação utilizado (e.g. 'BPPM')
%   factor - Fator de controle de brilho
%
% Saídas:
%   msg    - Matriz de bits estruturados gerados [K1 x M*N]
%   S      - Matriz de símbolos modulados com pilotos inseridos [K x M*N]
%   S0     - Forma de onda de referência para o bit 1
%   S1     - Forma de onda de referência para o bit 0

% Header com 9 bits todos iguais a 1
header = ones(1, 9);

% ID com 3 bits fixos
id = [0 0 1];

% Valores para as dimensões
vertical_dimension_decimal = 240; % Valor da dimensão vertical em decimal
horizontal_dimension_decimal = 240; % Valor da dimensão horizontal em decimal

% Conversão dos valores para binário de 12 bits
vertical_dimension_binary = dec2bin(vertical_dimension_decimal, 12) - '0'; % Converte para vetor de 12 bits
horizontal_dimension_binary = dec2bin(horizontal_dimension_decimal, 12) - '0'; % Converte para vetor de 12 bits

msg = randi([0 1], K1,M*N);
% msg = ones(K1,M*N);
% msg = zeros(K1,M*N);

% Convertendo a matriz em um vetor
vector = msg(:);

% Definindo o conteúdo a ser inserido
content = [header, id, vertical_dimension_binary, horizontal_dimension_binary];

% Calculando o índice inicial e final
start_idx = M * N + 1; % Ajuste para começar na segunda linha
end_idx = start_idx + length(content) - 1; % Índice final

% Substituindo os valores no vetor
vector(start_idx:end_idx) = content;

% Reconstruindo a matriz com as dimensões originais (linha a linha)
msg = reshape(vector, M*N, K1)'; % Transpondo após organizar linha a linha

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
