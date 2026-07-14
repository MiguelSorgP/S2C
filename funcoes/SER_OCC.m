function SER = SER_OCC(S,S0,S1,Bmod,P,M,N,K1)
% S: [K1*P, M*N]
% S0: [P, 1]
% S1: [P, 1]
% Bmod: [K1*P, M*N] or [K1*P, M*N, MC]

if ndims(Bmod) == 3
    MC = size(Bmod, 3);
else
    MC = 1;
end

S_reshaped = reshape(S, P, K1, M*N);
Soriginal = S_reshaped(:, 2:end, :); % size [P, K1-1, M*N]

Bmod_reshaped = reshape(Bmod, P, K1, M*N, MC);
Sestim_all = Bmod_reshaped(:, 2:end, :, :); % size [P, K1-1, M*N, MC]

% S0 and S1 have size [P, 1]. They broadcast automatically.
e1_all = sum((Sestim_all - S0).^2, 1) ./ sum(Sestim_all.^2, 1);
e2_all = sum((Sestim_all - S1).^2, 1) ./ sum(Sestim_all.^2, 1);

is_true_S1 = (Soriginal(1, :, :) == S1(1)); % size [1, K1-1, M*N]
is_decoded_S1 = (e1_all > e2_all); % size [1, K1-1, M*N, MC]

symbol_error = (is_decoded_S1 ~= is_true_S1); % size [1, K1-1, M*N, MC]

SER = sum(symbol_error, [2, 3]) / ((K1-1) * M * N); % size [1, 1, MC]
SER = reshape(SER, 1, MC);
end
