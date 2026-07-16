function [msg_hat, header_hat, id_hat, vertical_dimension, horizontal_dimension] = decode_msg(Bmod, S0, S1, P, M, N, S)
% DECODE_MSG - Decodifica a mensagem binária a partir da matriz de símbolos estimados (Bmod).
% Esta função executa a decodificação de máxima verossimilhança por distância euclidiana
% mínima entre os símbolos recebidos de Bmod e os formatos de pulso BPPM de referência (S0, S1).
% Em seguida, extrai os metadados contidos na mensagem de controle estruturada:
%   - Cabeçalho de sincronização (9 bits)
%   - ID do transmissor (3 bits)
%   - Dimensão vertical em pixels (12 bits)
%   - Dimensão horizontal em pixels (12 bits)
% Converte os metadados de volta para valores decimais na CPU.

    %
    % Entradas:
    % Bmod: Matriz de símbolos estimados, dimensão: (S*P) x (M*N)
    %       Aqui S é o número de bits por linha/pixel e P é o número de pulsos por símbolo.
    % S0, S1: Formas de onda usadas para representar bit 1 (S0) e bit 0 (S1).
    % P: Número de amostras/pulsos por símbolo.
    % M, N: Dimensões espaciais do bloco.
    % S: Número de bits (K1 no código original) por coluna da mensagem.
    %
    % Saídas:
    % msg_hat: Mensagem decodificada (S x M*N), cada elemento é 0 ou 1.
    % header_hat: Vetor com os bits do cabeçalho recuperado (9 bits).
    % id_hat: Vetor com os bits do ID (3 bits).
    % vertical_dimension: Dimensão vertical em decimal (recuperada a partir de 12 bits).
    % horizontal_dimension: Dimensão horizontal em decimal (recuperada a partir de 12 bits).
    %
    % Observação:
    % A mensagem original foi construída assim:
    % - msg com dimensão (S x M*N)
    % - Vetor linearizado: vector = msg(:)
    % - Conteúdo extra (header, id, dimensões) foi inserido a partir do índice M*N+1 no vetor linear.
    %
    % Assim, para decodificar:
    % 1) Extrair cada bit comparando o bloco de P amostras em Bmod com S0 e S1.
    % 2) Reconstruir msg_hat (S x M*N).
    % 3) Linearizar de forma consistente e extrair header, id e dimensões.
    %
    % Layout do conteúdo extra no transmissor:
    % header: 9 bits de valor '1'
    % id: 3 bits (0 0 1)
    % vertical_dimension_binary: 12 bits
    % horizontal_dimension_binary: 12 bits
    % Tudo isso inserido após os primeiros M*N bits da mensagem.
    %
    % Total de bits extra = 9 + 3 + 12 + 12 = 36 bits.
    %
    % Portanto:
    % vector_hat(M*N+1 : M*N+9) = header
    % vector_hat(M*N+10 : M*N+12) = id
    % vector_hat(M*N+13 : M*N+24) = vertical_dimension_binary (12 bits)
    % vector_hat(M*N+25 : M*N+36) = horizontal_dimension_binary (12 bits)

    % Número total de colunas
    num_cols = M*N; 
    
    % Decodificação vetorizada:
    Bmod_reshaped = reshape(Bmod, P, S, num_cols);
    dist0 = sum((Bmod_reshaped - S0).^2, 1);
    dist1 = sum((Bmod_reshaped - S1).^2, 1);
    msg_hat = reshape(dist0 < dist1, S, num_cols);
    
    % Agora precisamos extrair as informações do cabeçalho, ID e dimensões.
    % A mensagem final no transmissor foi:
    % vector = msg(:) antes da inserção
    %
    % vector(M*N+1 : M*N+9) = header
    % vector(M*N+10 : M*N+12) = id
    % vector(M*N+13 : M*N+24) = vertical_dimension_binary (12 bits)
    % vector(M*N+25 : M*N+36) = horizontal_dimension_binary (12 bits)
    %
    % Para manter a coerência da indexação, precisamos linearizar msg_hat da mesma forma que msg foi linearizado no transmissor.
    %
    %
    % Então para linearizar de volta da mesma forma, fazemos:
    vector_hat = msg_hat'; % Agora dimensão (M*N x S)
    vector_hat = vector_hat(:); % lineariza coluna a coluna, mesma ordem que foi gerado no transmissor
    
    start_idx = M*N + 1;
    header_hat = vector_hat(start_idx : start_idx+8); % 9 bits de header
    id_hat = vector_hat(start_idx+9 : start_idx+11);  % 3 bits de ID
    
    vertical_dimension_binary = vector_hat(start_idx+12 : start_idx+23); % 12 bits verticais
    horizontal_dimension_binary = vector_hat(start_idx+24 : start_idx+35); % 12 bits horizontais
    
    % Garante que os dados para conversão de texto estão na CPU
    v_bin_cpu = gather(vertical_dimension_binary');
    h_bin_cpu = gather(horizontal_dimension_binary');
    
    % Conversão dos valores binários de volta para decimais
    vertical_dimension = bin2dec(num2str(v_bin_cpu));
    horizontal_dimension = bin2dec(num2str(h_bin_cpu));
    
end
