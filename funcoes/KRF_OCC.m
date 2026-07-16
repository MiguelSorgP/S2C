function [A2aux,A1aux] = KRF_OCC(Y,K1,K2)
% KRF_OCC - Fatoração do Produto de Khatri-Rao (LSKRF) para receptores OCC.
% Executa a decomposição cega não-iterativa baseada em SVD pixel a pixel do produto
% de Khatri-Rao aproximado para separar o fator temporal de codificação (símbolos)
% do fator temporal do vídeo original. Suporta aceleração por GPU/Vetorização 3D
% nativa via 'pagesvd' para processar múltiplos experimentos Monte Carlo em paralelo.
%
% Entradas:
%   Y     - Matriz ou tensor com as observações do canal sem efeito espacial (dimensão KF x MN ou KF x MN x MC)
%   K1    - Dimensão temporal de codificação (K = S * P)
%   K2    - Dimensão temporal do vídeo original (F)
%
% Saídas:
%   A2aux - Matriz/Tensor estimado do vídeo reconstruído (dimensão MN x F ou MN x F x MC)
%   A1aux - Matriz/Tensor estimado dos símbolos reconstruídos (dimensão K x MN ou K x MN x MC)

% Y pode ter dimensão [K1*K2, M_krf] ou [K1*K2, M_krf, MC]

if ndims(Y) == 3
    [~, M_krf, MC] = size(Y);
else
    [~, M_krf] = size(Y);
    MC = 1;
end

if exist('pagesvd', 'builtin') || exist('pagesvd', 'file')
    % Versão vetorizada usando pagesvd (CPU e GPU)
    Y_3d = reshape(Y, K1, K2, M_krf * MC);
    [U, Xi, V] = pagesvd(Y_3d, 'econ');
    
    s = sqrt(Xi(1, 1, :)); % tamanho [1, 1, M_krf * MC]
    s_vec = reshape(s, 1, M_krf * MC); % tamanho [1, M_krf * MC]
    
    U1 = reshape(U(:, 1, :), K1, M_krf * MC); % tamanho [K1, M_krf * MC]
    A1 = (s_vec .* U1).'; % tamanho [M_krf * MC, K1]
    
    V1 = reshape(V(:, 1, :), K2, M_krf * MC); % tamanho [K2, M_krf * MC]
    A2 = conj(V1) .* s_vec; % tamanho [K2, M_krf * MC]
    
    if MC > 1
        % A1aux: [K1, M_krf, MC]
        A1aux = reshape(A1.', K1, M_krf, MC);
        % A2aux: [M_krf, K2, MC] (transposto por página)
        A2aux = permute(reshape(A2, K2, M_krf, MC), [2, 1, 3]);
    else
        A1aux = A1.';
        A2aux = A2.';
    end
else
    % Loop de fallback (compatível com versões antigas do MATLAB)
    if MC > 1
        A1aux = zeros(K1, M_krf, MC, 'like', Y);
        A2aux = zeros(M_krf, K2, MC, 'like', Y);
        for mc = 1:MC
            A1_m = zeros(M_krf, K1, 'like', Y);
            A2_m = zeros(K2, M_krf, 'like', Y);
            Y_mc = Y(:,:,mc);
            for m = 1:M_krf
               Yunv = reshape(Y_mc(:,m),K1,K2);
               [U,Xi,V] = svd(Yunv);
               A1_m(m,:) = sqrt(Xi(1,1))*(U(:,1).');
               A2_m(:,m) = (V(:,1)')*sqrt(Xi(1,1)); 
            end
            A1aux(:,:,mc) = A1_m.';
            A2aux(:,:,mc) = A2_m.';
        end
    else
        A1 = zeros(M_krf, K1, 'like', Y);
        A2 = zeros(K2, M_krf, 'like', Y);
        for m=1:M_krf
           Yunv = reshape(Y(:,m),K1,K2);
           [U,Xi,V] = svd(Yunv);
           A1(m,:) = sqrt(Xi(1,1))*(U(:,1).');
           A2(:,m) = (V(:,1)')*sqrt(Xi(1,1)); 
        end
        A1aux = A1.';
        A2aux = A2.';
    end
end
end
