function [erro_S, erro_V, Bmod, Cmod] = OCC_Rx(rxAlgorithm, M, N, K, F, scale, vgray, S, Aux2)
% OCC_Rx: Optical Camera Communication Receiver
% Supports both OCC-KRF and OCC-ALS algorithms.
%
% Inputs:
%   rxAlgorithm : 1 for OCC-KRF, 2 for OCC-ALS
%   M, N        : Spatial dimensions of each block
%   K           : Number of temporal subframes (K = S*P)
%   F           : Number of video frames
%   scale       : Spatial scale factor
%   vgray       : True video matrix [F, M*N] (used for error and scaling)
%   S           : True symbols matrix [K, M*N] (used for error calculation)
%   Aux2        : Received signal matrix [K*F, M*N] (2D) or [K*F, M*N, MC] (3D)
%
% Outputs:
%   erro_S      : Symbol MSE error
%   erro_V      : Video MSE error
%   Bmod        : Estimated symbols after permutation and scale correction
%   Cmod        : Estimated video after permutation and scale correction

MD = size(Aux2, 1);
MC = size(Aux2, 3);

% Set ALS parameters
Nitmax = 200;      % Maximum iterations for ALS convergence
rel_error = 1e-5;  % Relative error threshold for early stop

if rxAlgorithm == 1
    %% ==================== ALGORITMO OCC-KRF ====================
    if MC > 1
        Aux3 = permute(Aux2, [2, 1, 3]); % size [M*N, K*F, MC]
        [C, B] = KRF_OCC(Aux3, K, F);    % B: [K, M*N, MC], C: [M*N, F, MC]

        Bmod = B ./ B(1, :, :);

        C_transposed = permute(C, [2, 1, 3]); % size [F, M*N, MC]
        C_first_col = permute(C(:, 1, :), [2, 1, 3]); % size [1, M*N, MC]
        scaling = vgray(1, :) ./ C_first_col; % size [1, M*N, MC]
        Cmod = C_transposed .* scaling; % size [F, M*N, MC]

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
    % Verify if page-wise operations are supported (requires R2020b+ for pagemtimes, R2022a+ for pagemldivide)
    useVectorized = (MC > 1) && exist('pagemtimes', 'builtin') && exist('pagemldivide', 'builtin');

    if useVectorized
        % --- CAMINHO ACELERADO POR GPU/VETORIZADO ---
        % Reconstruct underlying tensor mode-1 unfolding to other mode unfoldings
        % Aux2 has size [MD, K*F, MC]
        Y_mode1 = permute(Aux2, [2, 1, 3]); % size [K*F, MD, MC]
        T_unv = reshape(Y_mode1, K, F, MD, MC); % size [K, F, MD, MC]
        Y_tensor = permute(T_unv, [3, 1, 2, 4]); % size [MD, K, F, MC]

        X1 = Y_mode1; % size [K*F, MD, MC]
        X2 = reshape(permute(Y_tensor, [3, 1, 2, 4]), F * MD, K, MC); % size [F*MD, K, MC]
        X3 = reshape(Y_tensor, MD * K, F, MC); % size [MD*K, F, MC]

        % Initialization (using target device, e.g. GPU if Aux2 is gpuArray)
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

            % Convergence check
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
        C_all = permute(Cchap, [2, 1, 3]); % size [MD, F, MC]

    else
        % --- CAMINHO SEQUENCIAL DE BACKUP (CPU/VERSÕES ANTIGAS) ---
        B_all = zeros(K, MD, MC, 'like', Aux2);
        C_all = zeros(MD, F, MC, 'like', Aux2);

        for mc = 1:MC
            Aux2_mc = Aux2(:, :, mc); % size [MD, K*F]
            Y_mode1_mc = Aux2_mc.'; % size [K*F, MD]
            T_unv = reshape(Y_mode1_mc, K, F, MD); % size [K, F, MD]
            Y_tensor = permute(T_unv, [3, 1, 2]); % size [MD, K, F]

            X1 = Y_mode1_mc;
            X2 = reshape(permute(Y_tensor, [3, 1, 2]), F * MD, K);
            X3 = reshape(Y_tensor, MD * K, F);

            Achap = eye(MD, 'like', Aux2);
            Bchap = ones(K, MD, 'like', Aux2);
            Cchap = ones(F, MD, 'like', Aux2);

            err_prev = 1;
            for nit = 1:Nitmax
                % Update B
                M_B = (Achap.'*Achap) .* (Cchap.'*Cchap);
                K_AC = khatri(Achap, Cchap);
                V_B = K_AC.' * X2;
                Bchap = (M_B \ V_B).';

                % Update C
                M_C = (Bchap.'*Bchap) .* (Achap.'*Achap);
                K_BA = khatri(Bchap, Achap);
                V_C = K_BA.' * X3;
                Cchap = (M_C \ V_C).';

                % Update A
                M_A = (Cchap.'*Cchap) .* (Bchap.'*Bchap);
                K_CB = khatri(Cchap, Bchap);
                V_A = K_CB.' * X1;
                Achap = (M_A \ V_A).';

                % Check convergence
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

    % --- AMBIGUITY RESOLUTION FOR OCC-ALS ---
    % Resolve column scale and permutation ambiguities for all MC runs.
    % Since this is done once after loop, a simple CPU/GPU loop over MC is fast.
    Bmod = zeros(size(B_all), 'like', Aux2);
    Cmod = zeros(F, MD, MC, 'like', Aux2);

    for mc = 1:MC
        B_mc = B_all(:, :, mc); % [K, MD]
        C_mc = C_all(:, :, mc); % [MD, F]

        % Sort columns by the ratio of the first two lines to resolve permutation
        ratio = B_mc(1, :) ./ B_mc(2, :);
        [~, I] = sort(ratio, 'descend');

        B_perm = B_mc(:, I);
        C_perm = C_mc(I, :);

        % Scale normalization using first row of B and first frame of C (known pilots)
        deltaB = B_perm(1, :);
        Bmod_mc = B_perm ./ deltaB;

        C_transposed = C_perm.'; % [F, MD]
        scaling = vgray(1, :) ./ C_perm(:, 1).';
        Cmod_mc = C_transposed .* scaling;

        Bmod(:, :, mc) = Bmod_mc;
        Cmod(:, :, mc) = Cmod_mc;
    end

    % Compute reconstruction errors
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
% Vectorized page-wise Khatri-Rao product
% A: [I, R, MC]
% B: [J, R, MC]
% C: [J*I, R, MC]
[I, R, MC] = size(A);
[J, ~, ~] = size(B);
A_expanded = reshape(A, 1, I, R, MC);
B_expanded = reshape(B, J, 1, R, MC);
C = reshape(B_expanded .* A_expanded, J * I, R, MC);
end
