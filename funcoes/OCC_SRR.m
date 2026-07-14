function [Erro,erro_S,erro_V,Bmod,Cmod,Amod,Aux2] = OCC_SRR(flag,M,N,K,F,scale,mascara1,vgray,S,H,SNR)

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
                
                
                
                % Undegraded video
                x(:,k,f) = aux;
                
                
                
                Aux2 = imfilter(Aux_noiseless, mascara1,'conv','same');
                %Aux2 = Aux_noiseless;
                
                
                
                
                %%%%%Interpolation to LR
                
                %Aux3 = imresize(Aux2,scale,'nearest'); %Decimation
                Aux3 = imresize(Aux2,scale,'bilinear');
                %Aux3 = imresize(Aux2,scale,'bicubic');
                %Aux3 = imresize(Aux2,scale,'lanczos3');
                
                Aux3_noise = awgn(Aux3,SNR,'measured');
                
                
                %Gamma correction
                %gamma =0.45;
                gamma = 1; % Without Gamma Correction
                
                Aux6_noise = 255*imadjust(Aux3_noise/255, [],[], gamma);
                
                
                %y(:,k,f) = vec(Aux3_noise);
                y(:,k,f) = vec(Aux6_noise);
                
            end
            
            
            
            
        end
        
        
        V4D_OCC_OOK = reshape(y,scale*M,scale*N,K,F);
        Aux  = reshape(y,scale*scale*M*N*K,F);
        Aux2 = reshape(y,scale*scale*M*N,F*K);
        
        Aux4 = reshape(x,M*N,F*K);
        
        
        %Gamma inversion correction
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
