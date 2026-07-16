function [e,Achap,Bchap,Caux] = ALS_OCC(X3,A,B,C,Nit,rel_error)
% ALS_OCC - Algoritmo iterativo Mínimos Quadrados Alternados (ALS) para decomposição PARAFAC.
% Realiza o ajuste do modelo tensorial de terceira ordem (degradação A, símbolos B e vídeo C)
% a partir do tensor de observações X3 (Modo 3 desdobrado), utilizando atualizações iterativas
% de mínimos quadrados para aproximar as matrizes de fatores dos modos espacial, temporal e de codificação.
%
% Entradas:
%   X3        - Matriz do tensor de recepção desdobrada no Modo 3 (dimensão MNF x K)
%   A         - Estimativa inicial da matriz de degradação espacial (dimensão MN x JL)
%   B         - Estimativa inicial da matriz de símbolos codificados (dimensão K x JL)
%   C         - Estimativa inicial da matriz do vídeo original (dimensão F x JL)
%   Nit       - Número máximo de iterações permitidas
%   rel_error - Tolerância para erro relativo para critério de parada
%
% Saídas:
%   e         - Vetor contendo o erro quadrático médio em cada iteração
%   Achap     - Matriz de degradação estimada corrigida
%   Bchap     - Matriz de símbolos estimada corrigida
%   Caux      - Matriz do vídeo original estimada (transposta para dimensão JL x F)

% A é a matriz de degradação
% B é a matriz de símbolos
% C é a matriz de vídeo

MD =size(A,1);
K = size(B,1);
F = size(C,1);

e = zeros(Nit,1);
Achap = A.*(1+1*rand(size(A)));
Bchap = B.*(1+1*rand(size(B)));
Cchap = C.*(1+1*rand(size(C)));

x3 = vec(X3); % fmdjm1 % Desdobramento no Modo 3


x2 = tensor_alloc_2(x3,[MD K F],[3 1 2]); % x2 = fm1mdj
X2 = reshape(x2,F*MD,K); % X2 = Fm1md_j % Desdobramento no Modo 2

x1 = tensor_alloc_2(x3,[MD K F],[2 3 1]); % x1 = fjm1_md
X1 = reshape(x1,K*F,MD); % X1 = Fjm1_md % Desdobramento no Modo 1

err=1;
nit = 1;
flag_err=1;


Yr = khatri(Bchap,Achap)*Cchap.'; Yr = Yr/norm(Yr,'fro');
Yo = X3; Yo = Yo/norm(Yo,'fro');   %MNK x F



err = (norm(Yr-Yo,'fro')/norm(Yo,'fro')).^2;

e(1) = err;

Achap = A+0.1*randn(size(A)); %% Teste para A conhecido
%Achap = randn(size(A));
Bchap = B;
%Bchap = B+0.01*randn(size(B));
Cchap = C;

elapsedTime = 0;

while (nit < Nit) && (flag_err>rel_error)
    %while (nit < Nit)
tic    
    
    nit = nit+1;
    
   % Bchap= (pinv(khatri(Achap,Cchap))*X2).';
   % Cchap= (pinv(khatri(Bchap,Achap))*X3).';
   % Achap= (pinv(khatri(Cchap,Bchap))*X1).'; 
    
  
  Bchap = (inv((Achap.'*Achap).*(Cchap.'*Cchap))*(khatri(Achap,Cchap).')*X2).';
  %Cchap = (inv((Bchap.'*Bchap).*(Achap.'*Achap))*(khatri(Bchap,Achap).')*X3).';
  Achap = (inv((Cchap.'*Cchap).*(Bchap.'*Bchap))*(khatri(Cchap,Bchap).')*X1).';
elapsedTime = toc+elapsedTime ;
    
    Yr = khatri(Bchap,Achap)*Cchap.'; Yr = Yr/norm(Yr,'fro');
    
    err = (norm(Yr-Yo,'fro')/norm(Yo,'fro')).^2;
    e(nit)=err;
    
    flag_err = (e(nit-1)-e(nit))/e(nit-1);
    
end




Caux = Cchap.';

e(nit:Nit,1)=err;
