function [erro_S, erro_V, Bmod, Cmod] = OCC_Rx(rxAlgorithm, M, N, K, F, scale, vgray, S, Aux2)
% OCC_RX - Gerenciador principal de recepção física para Screen-to-Camera (S2C).
% Esta função executa a decodificação dos símbolos de informação e a reconstrução
% do vídeo transmitido a partir dos quadros recebidos. Suporta dois algoritmos:
%   1) OCC-KRF: Algoritmo cego baseado na Fatoração de Khatri-Rao não-iterativa por SVD.
%   2) OCC-ALS: Algoritmo semi-cego baseado em Mínimos Quadrados Alternados iterativo.
% O script resolve as ambiguidades inerentes de escala e permutação de colunas da
% decomposição PARAFAC usando pilotos físicos e calcula as métricas de erro SER e MSE.
% Implementa aceleração por GPU/paralelização vetorizada 3D.
%
% Entradas:
%   rxAlgorithm : Algoritmo (1 para OCC-KRF, 2 para OCC-ALS)
%   M, N        : Dimensões espaciais de cada bloco
%   K           : Número de subquadros temporais de codificação (K = S*P)
%   F           : Número de frames do vídeo original
%   scale       : Fator de escala espacial
%   vgray       : Matriz do vídeo original real [F, M*N] (para erro e escala)
%   S           : Matriz de símbolos originais real [K, M*N] (para cálculo de erro)
%   Aux2        : Sinal recebido [K*F, M*N] (2D) ou [K*F, M*N, MC] (3D)
%
% Saídas:
%   erro_S      : Erro quadrático médio (MSE) dos símbolos
%   erro_V      : Erro quadrático médio (MSE) do vídeo
%   Bmod        : Símbolos estimados após correção de permutação e escala
%   Cmod        : Vídeo estimado após correção de permutação e escala

MD = size(Aux2, 1);
MC = size(Aux2, 3);

% Define parâmetros do ALS
Nitmax = 200;      % Máximo de iterações para convergência do ALS
rel_error = 1e-5;  % Limiar de erro relativo para parada precoce

if rxAlgorithm == 1
    %% ==================== ALGORITMO OCC-KRF ====================
    if MC > 1
        Aux3 = permute(Aux2, [2, 1, 3]); % tamanho [M*N, K*F, MC]
        [C, B] = KRF_OCC(Aux3, K, F);    % B: [K, M*N, MC], C: [M*N, F, MC]

        Bmod = B ./ B(1, :, :);

        C_transposed = permute(C, [2, 1, 3]); % tamanho [F, M*N, MC]
        C_first_col = permute(C(:, 1, :), [2, 1, 3]); % tamanho [1, M*N, MC]
        scaling = vgray(1, :) ./ C_first_col; % tamanho [1, M*N, MC]
        Cmod = C_transposed .* scaling; % tamanho [F, M*N, MC]

        erro_S = reshape(sum((S - Bmod).^2, [1, 2]) ./ sum(S.^2, 'all'), 1, MC);
        erro_V = reshape(sum((vgray - Cmod).^2, [1, 2]) ./ sum(vgray.^2, 'all'), 1, MC);
    else
        Aux3 = (Aux2.');
        [C, B] = KRF_OCC(Aux3, K, F);   % B: [K, M*N], C: [M*N, F]

        Bmod = B ./ B(1, :);
        Cmod = (C.') .* (vgray(1, :) ./ C(:, 1).');

        erro_S = (norm(S-Bmod,'fro'))^2/(norm(S,'fro'))^2;
        erro_V = (norm(vgray-Cmod,'fro'))^2/(norm(vgray,'fro'))^2;
    end

elseif rxAlgorithm == 2
    %% ==================== ALGORITMO OCC-ALS ====================
    % Verifica se operações em lote (page-wise) são suportadas (requer R2020b+ para pagemtimes, R2022a+ para pagemldivide)
    useVectorized = (MC > 1) && exist('pagemtimes', 'builtin') && exist('pagemldivide', 'builtin');

    if useVectorized
        % --- CAMINHO ACELERADO POR GPU/VETORIZADO ---
        % Reconstrução do desdobramento no Modo 1 para os outros desdobramentos de modo
        % Aux2 tem dimensão [MD, K*F, MC]
        Y_mode1 = permute(Aux2, [2, 1, 3]); % tamanho [K*F, MD, MC]
        T_unv = reshape(Y_mode1, K, F, MD, MC); % tamanho [K, F, MD, MC]
        Y_tensor = permute(T_unv, [3, 1, 2, 4]); % tamanho [MD, K, F, MC]

        X1 = Y_mode1; % tamanho [K*F, MD, MC]
        X2 = reshape(permute(Y_tensor, [3, 1, 2, 4]), F * MD, K, MC); % tamanho [F*MD, K, MC]
        X3 = reshape(Y_tensor, MD * K, F, MC); % tamanho [MD*K, F, MC]

        % Inicialização (usando o dispositivo alvo, ex: GPU se Aux2 for um gpuArray)
        Achap = repmat(eye(MD, 'like', Aux2), [1, 1, MC]);
        Bchap = ones(K, MD, MC, 'like', Aux2);
        Cchap = ones(F, MD, MC, 'like', Aux2);

        err_prev = ones(1, 1, MC, 'like', Aux2);

        for nit = 1:Nitmax
            % 1. Update Bchap (Symbols)
            Achap_t_Achap = pagemtimes(Achap, 'transpose', Achap, 'none');
            Cchap_t_Cchap = pagemtimes(Cchap, 'transpose', Cchap, 'none');
            M_B = Achap_t_Achap .* Cchap_t_Cchap;

            K_AC = khatri_page(Achap, Cchap);
            V_B = pagemtimes(K_AC, 'transpose', X2, 'none');

            Bchap_t = pagemldivide(M_B, V_B);
            Bchap = permute(Bchap_t, [2, 1, 3]);

            % 2. Update Cchap (Video)
            Bchap_t_Bchap = pagemtimes(Bchap, 'transpose', Bchap, 'none');
            M_C = Bchap_t_Bchap .* Achap_t_Achap;

            K_BA = khatri_page(Bchap, Achap);
            V_C = pagemtimes(K_BA, 'transpose', X3, 'none');

            Cchap_t = pagemldivide(M_C, V_C);
            Cchap = permute(Cchap_t, [2, 1, 3]);

            % 3. Update Achap (Degradation)
            Cchap_t_Cchap = pagemtimes(Cchap, 'transpose', Cchap, 'none');
            M_A = Cchap_t_Cchap .* Bchap_t_Bchap;

            K_CB = khatri_page(Cchap, Bchap);
            V_A = pagemtimes(K_CB, 'transpose', X1, 'none');

            Achap_t = pagemldivide(M_A, V_A);
            Achap = permute(Achap_t, [2, 1, 3]);

            % Verificação de convergência
            Yr = pagemtimes(K_BA, 'none', Cchap, 'transpose');
            norm_Yo = sqrt(sum(X3.^2, [1, 2]));
            norm_Yr = sqrt(sum(Yr.^2, [1, 2]));
            Yo_normed = X3 ./ norm_Yo;
            Yr_normed = Yr ./ norm_Yr;

            err_curr = sum((Yr_normed - Yo_normed).^2, [1, 2]);

            rel_change = max(abs(err_prev - err_curr) ./ err_prev, [], 'all');
            if rel_change < rel_error
                break;
            end
            err_prev = err_curr;
        end

        B_all = Bchap;
        C_all = permute(Cchap, [2, 1, 3]); % tamanho [MD, F, MC]

    else
        % --- CAMINHO SEQUENCIAL DE BACKUP (CPU/VERSÕES ANTIGAS) ---
        B_all = zeros(K, MD, MC, 'like', Aux2);
        C_all = zeros(MD, F, MC, 'like', Aux2);

        for mc = 1:MC
            Aux2_mc = Aux2(:, :, mc); % tamanho [MD, K*F]
            Y_mode1_mc = Aux2_mc.'; % tamanho [K*F, MD]
            T_unv = reshape(Y_mode1_mc, K, F, MD); % tamanho [K, F, MD]
            Y_tensor = permute(T_unv, [3, 1, 2]); % tamanho [MD, K, F]

            X1 = Y_mode1_mc;
            X2 = reshape(permute(Y_tensor, [3, 1, 2]), F * MD, K);
            X3 = reshape(Y_tensor, MD * K, F);

            Achap = eye(MD, 'like', Aux2);
            Bchap = ones(K, MD, 'like', Aux2);
            Cchap = ones(F, MD, 'like', Aux2);

            err_prev = 1;
            for nit = 1:Nitmax
                % Atualização de B
                M_B = (Achap.'*Achap) .* (Cchap.'*Cchap);
                K_AC = khatri(Achap, Cchap);
                V_B = K_AC.' * X2;
                Bchap = (M_B \ V_B).';

                % Atualização de C
                M_C = (Bchap.'*Bchap) .* (Achap.'*Achap);
                K_BA = khatri(Bchap, Achap);
                V_C = K_BA.' * X3;
                Cchap = (M_C \ V_C).';

                % Atualização de A
                M_A = (Cchap.'*Cchap) .* (Bchap.'*Bchap);
                K_CB = khatri(Cchap, Bchap);
                V_A = K_CB.' * X1;
                Achap = (M_A \ V_A).';

                % Verifica convergência
                Yr = K_BA * Cchap.';
                norm_Yo = norm(X3, 'fro');
                norm_Yr = norm(Yr, 'fro');
                err_curr = (norm(Yr/norm_Yr - X3/norm_Yo, 'fro'))^2;

                if abs(err_prev - err_curr)/err_prev < rel_error
                    break;
                end
                err_prev = err_curr;
            end

            B_all(:, :, mc) = Bchap;
            C_all(:, :, mc) = Cchap.';
        end
    end

    % --- RESOLUÇÃO DE AMBIGUIDADES PARA OCC-ALS ---
    % Resolve as ambiguidades de escala e permutação de colunas para todas as realizações Monte Carlo.
    % Como isto é feito após o loop principal, uma iteração simples sobre MC é rápida.
    Bmod = zeros(size(B_all), 'like', Aux2);
    Cmod = zeros(F, MD, MC, 'like', Aux2);

    for mc = 1:MC
        B_mc = B_all(:, :, mc); % [K, MD]
        C_mc = C_all(:, :, mc); % [MD, F]

        % Ordena as colunas pela razão entre as duas primeiras linhas para resolver a permutação
        ratio = B_mc(1, :) ./ B_mc(2, :);
        [~, I] = sort(ratio, 'descend');

        B_perm = B_mc(:, I);
        C_perm = C_mc(I, :);

        % Normalização de escala usando primeira linha de B e primeiro frame de C (pilotos conhecidos)
        deltaB = B_perm(1, :);
        Bmod_mc = B_perm ./ deltaB;

        C_transposed = C_perm.'; % [F, MD]
        scaling = vgray(1, :) ./ C_perm(:, 1).';
        Cmod_mc = C_transposed .* scaling;

        Bmod(:, :, mc) = Bmod_mc;
        Cmod(:, :, mc) = Cmod_mc;
    end

    % Calcula os erros de reconstrução
    if MC > 1
        erro_S = reshape(sum((S - Bmod).^2, [1, 2]) ./ sum(S.^2, 'all'), 1, MC);
        erro_V = reshape(sum((vgray - Cmod).^2, [1, 2]) ./ sum(vgray.^2, 'all'), 1, MC);
    else
        erro_S = (norm(S - Bmod, 'fro'))^2 / (norm(S, 'fro'))^2;
        erro_V = (norm(vgray - Cmod, 'fro'))^2 / (norm(vgray, 'fro'))^2;
    end

else
    error('Unknown rxAlgorithm: %d', rxAlgorithm);
end

end

%% ==================== LOCAL HELPER FUNCTIONS ====================
function C = khatri_page(A, B)
% Produto de Khatri-Rao vetorizado em lote de matrizes (page-wise)
% A: [I, R, MC]
% B: [J, R, MC]
% C: [J*I, R, MC]
[I, R, MC] = size(A);
[J, ~, ~] = size(B);
A_expanded = reshape(A, 1, I, R, MC);
B_expanded = reshape(B, J, 1, R, MC);
C = reshape(B_expanded .* A_expanded, J * I, R, MC);
end
