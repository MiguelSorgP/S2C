function [S,S0,S1] = BPPM(msg,P,M,N,K)

S0 = [0.001;ones(P-1,1)];
S1 = [ones(floor(P/2),1);0.001;ones(ceil(P/2)-1,1)];

for mn = 1:M*N
    for k = 1:K
                
        if msg(k,mn)==1
            S((k-1)*P+1:k*P,mn) = S0;   % Símbolo S0.
        elseif  msg(k,mn)==0
            S((k-1)*P+1:k*P,mn) = S1;  % Símbolo S1.
        end
               
    end
end
