function [vgray,V4D_gray] = bloco_extraction(V4D,M,N,F,blci,blcj)
% BLOCO_EXTRACTION - Extrai blocos espaciais do vídeo e insere o piloto de escala no frame 1.
% Esta função extrai uma sub-região espacial (bloco M x N) de um vídeo 3D ou 4D (V4D)
% ao longo de F frames, vetoriza cada quadro do bloco e injeta o piloto físico de escala
% (vetor de uns) no primeiro frame (f == 1). Isso é feito para resolver a ambiguidade
% de escala inerente da decomposição PARAFAC no receptor.
%
% Entradas:
%   V4D  - Tensor do vídeo original de dimensões [Mmax x Nmax x 1 x F]
%   M, N - Dimensões espaciais do bloco a ser extraído
%   F    - Número total de frames
%   blci - Índice da linha do bloco na tela
%   blcj - Índice da coluna do bloco na tela
%
% Saídas:
%   vgray      - Matriz contendo os frames do bloco vetorizados [F x M*N]
%   V4D_gray   - Tensor contendo os quadros do bloco recortado [M x N x F]
        for f = 1:F
        
            
            V4D_gray(:,:,f) = V4D((blci-1)*M+1:blci*M,(blcj-1)*N+1:blcj*N,:,f);
            
            vgray(f,:) = vec(V4D_gray(:,:,f));
            
            if f==1
                vgray(f,:)=ones(1,M*N);
            end
            
        end
        
end
