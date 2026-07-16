% KHATRI - Calcula o produto de Khatri-Rao entre duas matrizes.
% O produto de Khatri-Rao consiste no produto de Kronecker coluna a coluna
% entre duas matrizes que possuem o mesmo número de colunas.
%
% Entradas:
%   A - Matriz de dimensão [I x K]
%   B - Matriz de dimensão [J x K]
%
% Saídas:
%   C - Matriz resultante de dimensão [I*J x K]
function C= khatri(A,B)

if size(A,2)~=size(B,2)
    error('Matrices A and B must have the same number of columns')
end

K=size(A,2); 
for i=1:K
    C(:,i)= kron(A(:,i),B(:,i));
end
