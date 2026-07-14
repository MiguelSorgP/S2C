function [msg,S,S0,S1] = SOCC_message(M,N,P,K,K1,modOCC,factor)

 msg = randi([0 1], K1,M*N);
    
    
    
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
