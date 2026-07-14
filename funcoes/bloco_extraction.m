function [vgray,V4D_gray] = bloco_extraction(V4D,M,N,F,blci,blcj)
        for f = 1:F
        
            
            V4D_gray(:,:,f) = V4D((blci-1)*M+1:blci*M,(blcj-1)*N+1:blcj*N,:,f);
            
            vgray(f,:) = vec(V4D_gray(:,:,f));
            
            if f==1
                vgray(f,:)=ones(1,M*N);
            end
            
        end
        
end
