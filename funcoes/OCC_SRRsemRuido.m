function [Erro,erro_S,erro_V,Bmod,Cmod,Amod,Aux2] = OCC_SRRsemRuido(flag,M,N,K,F,scale,mascara1,vgray,S,H,SNR)
% OCC_SRRSEMRUIDO - Simulador de transmissão e recepção OCC sem adição de ruído de canal.
% Simula o processo de transmissão e recepção de vídeo modulado com símbolos BPPM
% para validação matemática limpa do sistema, sem aplicar ruído de canal ou borramento,
% permitindo validar as estimativas dos algoritmos de recepção (ALS e KRF) e a
% eliminação das ambiguidades inerentes de permutação e escala.
%
% Entradas:
%   flag      - Seleção do algoritmo (1 = OCC-KRF, 2 = OCC-ALS)
%   M, N      : Dimensões espaciais do bloco original
%   K         - Número de subquadros temporais (K = S * P)
%   F         - Número de frames do vídeo original
%   scale     - Fator de escala espacial
%   mascara1  - Filtro de degradação espacial (ignorado)
%   vgray     - Matriz do vídeo original real [F, M*N]
%   S         - Matriz de símbolos originais real [K, M*N]
%   H         - Matriz de degradação inicial ou conhecida
%   SNR       - SNR de teste (ignorado neste script sem ruído)
%
% Saídas:
%   Erro      - Vetor de erro por iteração (no caso do ALS)
%   erro_S    - Erro quadrático médio final dos símbolos
%   erro_V    - Erro quadrático médio final do vídeo
%   Bmod      - Símbolos estimados após correção de permutação e escala
%   Cmod      - Vídeo estimado após correção de permutação e escala
%   Amod      - Matriz de degradação estimada corrigida
%   Aux2      - Matriz do vídeo recebido degradado

Nitmax = 1000;

Erro = zeros(Nitmax,1);


    %% Matriz X de vídeos
    y = ones((scale^2)*M*N,K,F);
    x = ones(M*N,K,F);
    
        
        %% Construção do tensor OCC transmitido
        
       
        
        for f = 1:F
            
            for k = 1:K
                
                
                
                aux = diag(vgray(f,:))*(S(k,:).');
                Aux_noiseless = reshape(aux,[M N]);
                
                
                
                % Vídeo não degradado
                x(:,k,f) = aux;
                
                % comentei
                % Aux2 = imfilter(Aux_noiseless, mascara1,'conv','same');
                %Aux2 = Aux_noiseless;
                
                
                
                
                %%%%% Interpolação para baixa resolução (LR)
                
                % Aux3 = imresize(Aux2,scale,'nearest'); % Decimação
                
                % comentei
                % Aux3 = imresize(Aux2,scale,'bilinear');
                %Aux3 = imresize(Aux2,scale,'bicubic');
                %Aux3 = imresize(Aux2,scale,'lanczos3');
                
                % comentei
                % Aux3_noise = awgn(Aux3,SNR,'measured');
                
                % Correção de gama
                %gamma =0.45;
                gamma = 1; % Sem correção de gama
                
                % comentei
                % Aux6_noise = 255*imadjust(Aux3_noise/255, [],[], gamma);
                
                % adicionei
                Aux6_noise = Aux_noiseless;
                
                %y(:,k,f) = vec(Aux3_noise);
                y(:,k,f) = vec(Aux6_noise);
                
            end
            
            
            
            
        end
        
        
        V4D_OCC_OOK = reshape(y,scale*M,scale*N,K,F);
        Aux  = reshape(y,scale*scale*M*N*K,F);
        Aux2 = reshape(y,scale*scale*M*N,F*K);
        
        Aux4 = reshape(x,M*N,F*K);
        
        
        % Correção de inversão de gama
        Aux = 255*imadjust(Aux/255, [],[], 1/gamma);
        
        
        %% Algoritmo(s) de estimação dos parâmetros do vídeo.
        
        %disp('Iniciando algoritmo PARAFAC-ALS...')
        if flag == 2
            %tic
            %disp('Iniciando algoritmo OCC-ALS...')
            [e,A,B,C] = ALS_OCC(Aux,H,S,vgray,Nitmax,1e-5);  % Algoritmo 1 (ALS)
            %disp('Fim do PARAFAC-ALS...')
            %toc
            
            Erro(:,1) = e;
            %Nit = nit;
            
            
        end
        
        
        if flag == 1
            %disp('Iniciando algoritmo OCC-KRF...')
            %tic
            Aux3 = (Aux2.')*pinv(H);
            %Aux3  = Aux2.';
            [C,B] = KRF_OCC(Aux3,K,F);   % Algoritmo 2 (KRF)
            %disp('Fim do PARAFAC-KRF...')
            %toc
            
            Amod = H;
            
        end
        
        
        if flag == 3
            B = Aux2.';
            C = randn(M*N,F);
            
        end
        
        if flag == 4
            B = randn(K,M*N);
            C = Aux2;
            
        end
        
        
        %clear Aux Aux2
        
        % Eliminação de fatores de ambiguidade do vídeo
        
        deltaB = inv(diag(B(1,:))); % Primeira linha dos símbolos
        
        deltaC = inv(diag(C(:,1))); % Primeira linha do vídeo
        
        
        if flag == 2
            
            [~,I] = sort(B(1,:)./B(2,:),'descend');
            perm = eye(M*N);
            perm(:,:) = perm(:,I);
            
            
            %perm = eye(M*N);
            
        else
            perm = eye(M*N);
        end
        
        
        Bmod = B*deltaB*perm; % Primeira linha de S conhecida
        %Cmod = (C.')*diag(B(1,:)); % KRF
        
        Cmod = (C.')*deltaC*diag(vgray(1,:))*perm; % ALS (conhecida primeira linha do vídeo)
        
        % deltaB*deltaC*deltaA = Eye --> deltaA = inv(deltaB*deltaC)
        
        
        % Erro de reconstrução de imagem com outro algoritmo
        
        if scale == 1
            AuxInt = squeeze(y(:,1,:)).';
        else
            for f=1:F
                Aux5 = reshape(squeeze(y(:,1,f)),M*scale,N*scale);
                Aux10 = imresize(Aux5,1/scale); %
                AuxInt(f,:) = vec(Aux10);
            end
        end
        erro_V_matrix = (norm(vgray-AuxInt,'fro'))^2/(norm(vgray,'fro'))^2;
        
        if flag==2
            
        Amod = A*inv(deltaB*deltaC)*perm; % ALS
        
        end
        
        
        erro_S = (norm(S-Bmod,'fro'))^2/(norm(S,'fro'))^2;
        erro_V = (norm(vgray-Cmod,'fro'))^2/(norm(vgray,'fro'))^2;
        
end
