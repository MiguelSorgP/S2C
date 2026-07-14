function [erro_S,erro_V,Bmod,Cmod] = OCC_Rx_Miguel(M,N,K,F,scale,vgray,S,Aux2)  
%% Algoritmo(s) de estimação dos parâmetros do vídeo.
% Aux2 can be [K*F, M*N] (2D) or [K*F, M*N, MC] (3D)

if ndims(Aux2) == 3
    [~, M_cols, MC] = size(Aux2);
else
    [~, M_cols] = size(Aux2);
    MC = 1;
end

if MC > 1
    Aux3 = permute(Aux2, [2, 1, 3]); % size [M*N, K*F, MC]
    [C, B] = KRF_OCC(Aux3, K, F);    % B: [S*P, M*N, MC], C: [M*N, F, MC]
    
    Bmod = B ./ B(1, :, :);
    
    C_transposed = permute(C, [2, 1, 3]); % size [F, M*N, MC]
    C_first_col = permute(C(:, 1, :), [2, 1, 3]); % size [1, M*N, MC]
    scaling = vgray(1, :) ./ C_first_col; % size [1, M*N, MC]
    Cmod = C_transposed .* scaling; % size [F, M*N, MC]
    
    erro_S = reshape(sum((S - Bmod).^2, [1, 2]) ./ sum(S.^2, 'all'), 1, MC);
    erro_V = reshape(sum((vgray - Cmod).^2, [1, 2]) ./ sum(vgray.^2, 'all'), 1, MC);
else
    Aux3 = (Aux2.');
    [C, B] = KRF_OCC(Aux3, K, F);   % Algoritmo 2 (KRF)
    
    Bmod = B ./ B(1, :);
    Cmod = (C.') .* (vgray(1, :) ./ C(:, 1).');
    
    erro_S = (norm(S-Bmod,'fro'))^2/(norm(S,'fro'))^2;
    erro_V = (norm(vgray-Cmod,'fro'))^2/(norm(vgray,'fro'))^2;
end
end
