function [msg,S,S0,S1] = SOCC_message(M,N,P,K,K1,modOCC,factor)

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
