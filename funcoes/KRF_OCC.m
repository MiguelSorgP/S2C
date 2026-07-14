function [A2aux,A1aux] = KRF_OCC(Y,K1,K2)
% Y can be of size [K1*K2, M_krf] or [K1*K2, M_krf, MC]

if ndims(Y) == 3
    [~, M_krf, MC] = size(Y);
else
    [~, M_krf] = size(Y);
    MC = 1;
end

if exist('pagesvd', 'builtin') || exist('pagesvd', 'file')
    % Vectorized version using pagesvd (CPU and GPU)
    Y_3d = reshape(Y, K1, K2, M_krf * MC);
    [U, Xi, V] = pagesvd(Y_3d, 'econ');
    
    s = sqrt(Xi(1, 1, :)); % size [1, 1, M_krf * MC]
    s_vec = reshape(s, 1, M_krf * MC); % size [1, M_krf * MC]
    
    U1 = reshape(U(:, 1, :), K1, M_krf * MC); % size [K1, M_krf * MC]
    A1 = (s_vec .* U1).'; % size [M_krf * MC, K1]
    
    V1 = reshape(V(:, 1, :), K2, M_krf * MC); % size [K2, M_krf * MC]
    A2 = conj(V1) .* s_vec; % size [K2, M_krf * MC]
    
    if MC > 1
        % A1aux: [K1, M_krf, MC]
        A1aux = reshape(A1.', K1, M_krf, MC);
        % A2aux: [M_krf, K2, MC] (transposed page-wise)
        A2aux = permute(reshape(A2, K2, M_krf, MC), [2, 1, 3]);
    else
        A1aux = A1.';
        A2aux = A2.';
    end
else
    % Fallback loop (compatible with older MATLAB versions)
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
