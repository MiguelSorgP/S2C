% VEC - Operador de vetorização de matrizes.
% Transforma uma matriz bidimensional em um único vetor coluna
% empilhando suas colunas sequencialmente.
%
% Entradas:
%   A - Matriz de dimensão [M x N]
%
% Saídas:
%   a - Vetor coluna resultante de dimensão [M*N x 1]
function a= vec(A)
a=A(:);
