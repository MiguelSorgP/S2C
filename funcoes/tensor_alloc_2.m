function y = tensor_alloc_2(x,org,posA)
%
% Changes the ordering of vector x to y
% org = [N P F K] -> [1 2 3 4]
% posA  is the new ordering

if size(posA)~=size(unique(posA)),
    disp('Error! Verify position')
end

%3rd order vectorized tensor
if length(org)==3
    
    pos(1) = org(posA(1));
    pos(2) = org(posA(2));
    pos(3)= org(posA(3));
    T = eye(3); T = T(posA,:);
    
    for k=1:org(3)
        for j=1:org(2)
            for i=1:org(1)
                %y_a -> a(1)a(2)a(3) a(1)<A(1)
                a = T*[i;j;k]; % Rotacao dos indices
                y((a(3)-1)*pos(1)*pos(2)+(a(2)-1)*pos(1)+a(1),1) = x((k-1)*org(1)*org(2)+(j-1)*org(1)+i,1);
            end
        end
    end
    
    
end

%4th order vectorized tensor
if length(org)==4
    
    pos(1) = org(posA(1));
    pos(2) = org(posA(2));
    pos(3)= org(posA(3));
    pos(4) = org(posA(4));
    T = eye(4); T = T(posA,:);
    
    for l=1:org(4)
        for k=1:org(3)
            for j=1:org(2)
                for i=1:org(1)
                    %y_a -> a(1)a(2)a(3) a(1)<A(1)
                    a = T*[i;j;k;l]; % Rotacao dos indices
                    y((a(4)-1)*pos(1)*pos(2)*pos(3)+(a(3)-1)*pos(1)*pos(2)+(a(2)-1)*pos(1)+a(1),1) = x((l-1)*org(1)*org(2)*org(3)+(k-1)*org(1)*org(2)+(j-1)*org(1)+i,1);
                end
            end
        end
    end
    
end

if length(org)==5
    
    pos(1) = org(posA(1));
    pos(2) = org(posA(2));
    pos(3)= org(posA(3));
    pos(4) = org(posA(4));
    pos(5) = org(posA(5));
    T = eye(5); T = T(posA,:);
    
    for f=1:org(5)
    for l=1:org(4)
        for k=1:org(3)
            for j=1:org(2)
                for i=1:org(1)
                    a = T*[i;j;k;l;f]; % Rotacao dos indices
                    y((a(5)-1)*pos(1)*pos(2)*pos(3)*pos(4)+(a(4)-1)*pos(1)*pos(2)*pos(3)+(a(3)-1)*pos(1)*pos(2)+(a(2)-1)*pos(1)+a(1),1) = x((f-1)*org(1)*org(2)*org(3)*org(4)+(l-1)*org(1)*org(2)*org(3)+(k-1)*org(1)*org(2)+(j-1)*org(1)+i,1);
                end
            end
        end
    end
    end
end
