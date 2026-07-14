% Implementation of the Khatri-Rao matrix product
% obs: The Khatri-Rao matrix product is 
% defined as column-wise Kronecker product
function C= khatri(A,B)

if size(A,2)~=size(B,2)
    error('Matrices A and B must have the same number of columns')
end

K=size(A,2); 
for i=1:K
    C(:,i)= kron(A(:,i),B(:,i));
end
